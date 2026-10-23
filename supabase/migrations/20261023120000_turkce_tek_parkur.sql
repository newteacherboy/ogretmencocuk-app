-- Additive namespace: existing English completions, balances and account data remain intact.
create table public.dm_turkce_runs (
 student_id uuid not null references public.students(id) on delete cascade,
 run_id text not null, grade_no int not null check(grade_no between 5 and 8),
 activity_id text not null, reward_no int not null check(reward_no between 290001 and 300000),
 bank_version text not null, deck jsonb not null check(jsonb_typeof(deck)='array' and jsonb_array_length(deck) between 1 and 12),
 answers jsonb not null default '[]', result jsonb,
 created_at timestamptz not null default now(), expires_at timestamptz not null default (now()+interval '1 hour'),
 primary key(student_id,run_id)
);
create table public.dm_turkce_progress (
 student_id uuid not null references public.students(id) on delete cascade,
 activity_id text not null, grade_no int not null check(grade_no between 5 and 8),
 correct int not null, total int not null, completed_at timestamptz not null default now(),
 primary key(student_id,activity_id)
);
create table public.dm_turkce_writing (
 student_id uuid not null references public.students(id) on delete cascade,
 task_id text not null, text text not null check(length(text)<=15000), revision text not null,
 review jsonb, updated_at timestamptz not null default now(), primary key(student_id,task_id)
);
create index dm_turkce_runs_expiry on public.dm_turkce_runs(expires_at);
create index dm_turkce_writing_updated on public.dm_turkce_writing(updated_at desc);
alter table public.dm_turkce_runs enable row level security;
alter table public.dm_turkce_progress enable row level security;
alter table public.dm_turkce_writing enable row level security;
revoke all on public.dm_turkce_runs,public.dm_turkce_progress,public.dm_turkce_writing from public,anon,authenticated;
grant all on public.dm_turkce_runs,public.dm_turkce_progress,public.dm_turkce_writing to service_role;

create function public.dm_turkce_start(actor uuid,run_key text,grade_no int,activity_key text,previous_key text,reward_no int,bank_version text,tasks jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare r public.dm_turkce_runs; student_class int;
begin
 if run_key !~ '^[a-zA-Z0-9_-]{16,100}$' or grade_no not between 5 and 8 or reward_no not between 290001 and 300000 then raise exception 'Geçersiz Türkçe oturumu';end if;
 select class_no into student_class from public.students where id=actor and role='student' and status='approved' for update;
 if not found then raise exception 'Öğrenci oturumu gerekli';end if;
 if student_class is null or student_class not between 5 and 8 then raise exception 'Önce kişisel bilgilerinden sınıfını seç';end if;
 -- Previous/next grades are labelled review/advanced in the UI, never a second route.
 if previous_key is not null and not exists(select 1 from public.dm_turkce_progress p where p.student_id=actor and p.activity_id=previous_key) then raise exception 'Önce önceki durağı tamamla';end if;
 delete from public.dm_turkce_runs where student_id=actor and expires_at<now()-interval '1 day';
 if not exists(select 1 from public.dm_turkce_runs where student_id=actor and run_id=run_key) and (select count(*) from public.dm_turkce_runs where student_id=actor and created_at>now()-interval '1 hour')>=60 then raise exception 'Çalışma sınırına ulaştın. Biraz sonra tekrar dene';end if;
 insert into public.dm_turkce_runs(student_id,run_id,grade_no,activity_id,reward_no,bank_version,deck)
 values(actor,run_key,grade_no,activity_key,reward_no,bank_version,tasks) on conflict do nothing;
 select * into r from public.dm_turkce_runs where student_id=actor and run_id=run_key;
 if r.activity_id<>activity_key or r.bank_version<>bank_version or r.deck<>tasks or r.expires_at<clock_timestamp() then raise exception 'Oturum değişmiş veya sona ermiş';end if;
 return jsonb_build_object('cursor',jsonb_array_length(r.answers),'answers',r.answers,'result',r.result);
end $$;

create function public.dm_turkce_answer(actor uuid,run_key text,slot_no int,answer_text text,feedback jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare r public.dm_turkce_runs; reply jsonb; answer_list jsonb; right_n int; total_n int; passed bool; energy jsonb; reward jsonb:='{}'; n int; l int; bonus int:=0; v jsonb;
begin
 -- Only the Edge Function service role may call this RPC. It grades the stored deck.
 perform 1 from public.students where id=actor for update;
 select * into r from public.dm_turkce_runs where student_id=actor and run_id=run_key for update;
 if not found or r.expires_at<clock_timestamp() or slot_no is null or slot_no<0 or slot_no>=jsonb_array_length(r.deck) then raise exception 'Oturum sona erdi';end if;
 if slot_no<jsonb_array_length(r.answers) then return r.answers->slot_no;end if;
 if slot_no<>jsonb_array_length(r.answers) then raise exception 'Soruları sırayla yanıtla';end if;
 if not (r.deck->slot_no->'secenekler' ? answer_text) or jsonb_typeof(feedback->'correct') is distinct from 'boolean' then raise exception 'Geçersiz yanıt';end if;
 energy:=public.dm_parkur_question_step(actor,run_key,slot_no+1,(feedback->>'correct')::boolean);
 reply:=feedback||jsonb_build_object('slot',slot_no,'answer',answer_text,'energy',energy);
 answer_list:=r.answers||jsonb_build_array(reply);total_n:=jsonb_array_length(r.deck);
 if jsonb_array_length(answer_list)=total_n then
  select count(*) into right_n from jsonb_array_elements(answer_list) a where (a->>'correct')::boolean;
  passed:=right_n::numeric/total_n>=0.75;
  if passed and not exists(select 1 from public.dm_turkce_progress p where p.student_id=actor and p.activity_id=r.activity_id) then
   insert into public.dm_turkce_progress(student_id,activity_id,grade_no,correct,total) values(actor,r.activity_id,r.grade_no,right_n,total_n);
   -- Compatibility reward IDs are immutable, >290000, and never end in 51–99.
   -- Use the existing economy engine and caps; no client-provided XP/gold.
   reward:=public.dm_game_reward_claim(actor,run_key,'ba',r.grade_no,array[r.reward_no],floor(12.0*right_n/total_n)::int,total_n-right_n,greatest(1,least(86399,extract(epoch from clock_timestamp()-r.created_at))),true,1,1);
   select count(*) into n from public.dm_turkce_progress where student_id=actor;
   select public.dm_student_level(coalesce((value->>'totalXp')::numeric,0)) into l from public.extra_data where student_id=actor and key_name='yo';
   if l>=5 and n%3=0 then
    bonus:=(array[15,20,30,40,50,65,80,100])[least(8,(l-5)/5+1)];
    insert into public.dm_progress_rewards(student_id,kind,reward_key,gold) values(actor,'stop','turkce:'||r.activity_id,bonus) on conflict do nothing;
    if found then v:=public.dm_progress_credit(actor,bonus);else bonus:=0;end if;
    select value into v from public.extra_data where student_id=actor and key_name='yo';
    reward:=reward||jsonb_build_object('gold',coalesce((reward->>'gold')::int,0)+bonus,'yo',v,'stopBonus',bonus);
   end if;
  else reward:=jsonb_build_object('xp',0,'gold',0,'reason',case when passed then 'already_completed' else 'practice' end);end if;
  reply:=reply||jsonb_build_object('result',jsonb_build_object('passed',passed,'correct',right_n,'total',total_n,'reward',reward));
  answer_list:=jsonb_set(answer_list,array[slot_no::text],reply);
 end if;
 update public.dm_turkce_runs set answers=answer_list,result=reply->'result' where student_id=actor and run_id=run_key;
 return reply;
end $$;

create function public.dm_turkce_writing_save(actor uuid,task_key text,writing_text text) returns jsonb
language plpgsql set search_path='' as $$
declare r public.dm_turkce_writing;
begin
 if length(writing_text)>15000 or length(task_key)>150 then raise exception 'Geçersiz yazı';end if;
 perform 1 from public.students where id=actor and role='student' and status='approved' for update;if not found then raise exception 'Öğrenci gerekli';end if;
 insert into public.dm_turkce_writing(student_id,task_id,text,revision) values(actor,task_key,writing_text,md5(writing_text))
 on conflict(student_id,task_id) do update set text=excluded.text,revision=excluded.revision,
 review=case when dm_turkce_writing.revision=excluded.revision then dm_turkce_writing.review else null end,updated_at=now()
 returning * into r;
 return jsonb_build_object('revision',r.revision,'review',r.review,'pending',r.review is null);
end $$;
revoke all on function public.dm_turkce_start(uuid,text,int,text,text,int,text,jsonb),public.dm_turkce_answer(uuid,text,int,text,jsonb),public.dm_turkce_writing_save(uuid,text,text) from public,anon,authenticated;
grant execute on function public.dm_turkce_start(uuid,text,int,text,text,int,text,jsonb),public.dm_turkce_answer(uuid,text,int,text,jsonb),public.dm_turkce_writing_save(uuid,text,text) to service_role;
