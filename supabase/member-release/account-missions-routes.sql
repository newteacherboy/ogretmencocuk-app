-- All new records are private; only the verified Edge dispatcher may call this RPC.
create table if not exists turkce_private.member_preferences(
 user_id uuid primary key references public.turkce_profiles(id) on delete cascade,
 basic_avatar text check(basic_avatar in ('girl','boy')),start_grade int not null default 5 check(start_grade between 5 and 8),onboarding_at timestamptz,updated_at timestamptz not null default now()
);
-- Existing members are not interrupted by a signup-only tutorial.
insert into turkce_private.member_preferences(user_id,start_grade,onboarding_at) select id,grade,now() from public.turkce_profiles on conflict do nothing;
create table if not exists turkce_private.class_route_catalog(grade int not null check(grade between 6 and 8),activity_id text primary key,position int not null,payload jsonb not null,unique(grade,position));
create table if not exists turkce_private.class_route_attempts(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.turkce_profiles(id) on delete cascade,
 activity_id text not null references turkce_private.class_route_catalog(activity_id),questions jsonb not null,next_question int not null default 0,correct int not null default 0,
 started_at timestamptz not null default now(),finished_at timestamptz,last_action_at timestamptz,passed boolean not null default false
);
create unique index if not exists class_route_one_open on turkce_private.class_route_attempts(user_id,activity_id) where finished_at is null;
create index if not exists class_route_owner_time on turkce_private.class_route_attempts(user_id,finished_at);
create table if not exists turkce_private.mission_claims(user_id uuid not null references public.turkce_profiles(id) on delete cascade,period text not null check(period in ('daily','weekly')),period_start date not null,task text not null,claimed_at timestamptz not null default now(),primary key(user_id,period,period_start,task));
alter table turkce_private.member_preferences enable row level security;
alter table turkce_private.class_route_catalog enable row level security;
alter table turkce_private.class_route_attempts enable row level security;
alter table turkce_private.mission_claims enable row level security;
revoke all on turkce_private.member_preferences,turkce_private.class_route_catalog,turkce_private.class_route_attempts,turkce_private.mission_claims from public,anon,authenticated;
grant all on turkce_private.member_preferences,turkce_private.class_route_catalog,turkce_private.class_route_attempts,turkce_private.mission_claims to service_role;
alter table public.turkce_reward_ledger drop constraint turkce_reward_ledger_mode_check;
alter table public.turkce_reward_ledger drop constraint turkce_reward_ledger_check;
alter table public.turkce_reward_ledger drop constraint turkce_reward_ledger_check1;
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_mode_check check(mode in ('stop','game','study','mission'));
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_check check(xp>=0 and ((mode='stop' and xp<=140) or (mode='game' and xp<=70) or (mode in ('study','mission') and xp<=160)));
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_check1 check(gold>=0 and ((mode='stop' and gold<=80) or (mode='game' and gold<=30) or (mode in ('study','mission') and gold<=60)));
create unique index if not exists turkce_mission_reward_once on public.turkce_reward_ledger(user_id,activity_id) where mode='mission';
-- Login names may change; the Auth email stays immutable. Only the server role can resolve it.
grant select(id,email) on auth.users to service_role;
create or replace function public.turkce_login_email(code text) returns text language sql stable security invoker set search_path='' as $$select u.email from public.turkce_profiles p join auth.users u on u.id=p.id where p.username=code and not p.disabled$$;
revoke all on function public.turkce_login_email(text) from public,anon,authenticated;
grant execute on function public.turkce_login_email(text) to service_role;
create or replace function public.turkce_account_request(actor uuid,op text,p jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
#variable_conflict use_variable
declare pref turkce_private.member_preferences%rowtype; result jsonb; rid uuid; grade_no int; avatar text; new_name text; a turkce_private.class_route_attempts%rowtype; c turkce_private.class_route_catalog%rowtype; previous text; q jsonb; total int; idx int; good boolean; xp_gain int:=0; gold_gain int:=0; written int; day date:=(now() at time zone 'Europe/Istanbul')::date; period_start date; period_end timestamptz; period_begin timestamptz; v_period text; tasks jsonb; task jsonb; n_route int; n_study int; n_correct int; n_days int;
begin
 perform 1 from public.turkce_economy where user_id=actor for update;
 if not found or not exists(select 1 from public.turkce_profiles where id=actor and not disabled) then raise exception 'Aktif öğrenci hesabı gerekli.';end if;
 insert into turkce_private.member_preferences(user_id,start_grade) select id,grade from public.turkce_profiles where id=actor on conflict do nothing;
 select * into pref from turkce_private.member_preferences where user_id=actor;
 if op not in ('profile','report','missions','route_status','avatars') then
 rid:=(p->>'request_id')::uuid;if rid is null then raise exception 'İstek kimliği gerekli.';end if;
 select response into result from turkce_private.requests where user_id=actor and request_id=rid;if found then return result;end if;
 end if;
 if op='profile' then
 result:=jsonb_build_object('ok',true,'preferences',to_jsonb(pref)-'user_id','username',(select username from public.turkce_profiles where id=actor));
 elsif op='profile_update' then
 grade_no:=coalesce((p->>'start_grade')::int,pref.start_grade);avatar:=coalesce(p->>'basic_avatar',pref.basic_avatar);
 if grade_no not between 5 and 8 or avatar is null or avatar not in ('girl','boy') then raise exception 'Karakterini ve 5–8. sınıflardan birini seç.';end if;
 update turkce_private.member_preferences set basic_avatar=avatar,start_grade=grade_no,onboarding_at=coalesce(onboarding_at,case when p->>'complete'='true' then now() else null end),updated_at=now() where user_id=actor returning * into pref;
 update public.turkce_profiles set grade=grade_no,updated_at=now() where id=actor;
 if p ? 'basic_avatar' then delete from public.turkce_character_selection where user_id=actor;end if;
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('preferences',to_jsonb(pref)-'user_id');
 elsif op='username' then
 new_name:=p->>'username';
 if new_name is null or new_name !~ '^[a-z0-9][a-z0-9_.]{2,19}$' or new_name in ('admin','administrator','teacher','ogretmen','yonetici','root','support','dijimedu') then raise exception 'Kullanıcı adı 3–20 karakter olmalı. Harf, rakam, nokta veya alt çizgi kullan.';end if;
 if exists(select 1 from public.turkce_profiles where username=new_name and id<>actor) then raise exception 'Bu kullanıcı adı kullanılıyor.';end if;
 update public.turkce_profiles set username=new_name,updated_at=now() where id=actor;
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('username',new_name);
 elsif op='avatars' then
 if jsonb_typeof(p->'usernames') is distinct from 'array' or jsonb_array_length(p->'usernames')>100 then raise exception 'Geçersiz karakter listesi.';end if;
 result:=jsonb_build_object('ok',true,'avatars',coalesce((select jsonb_object_agg(u.username,x.basic_avatar) from public.turkce_profiles u join turkce_private.member_preferences x on x.user_id=u.id where x.basic_avatar is not null and not u.disabled and u.username in(select jsonb_array_elements_text(p->'usernames')) and (u.id=actor or u.join_leagues or exists(select 1 from public.turkce_friendships f where f.accepted_at is not null and ((f.requester=actor and f.recipient=u.id) or (f.recipient=actor and f.requester=u.id))))),'{}'));
 elsif op='route_status' then
 grade_no:=pref.start_grade;
 result:=jsonb_build_object('ok',true,'grade',grade_no,'activities',coalesce((select jsonb_agg(jsonb_build_object('id',activity_id,'position',position,'title',payload->>'title','theme',payload->>'theme') order by position) from turkce_private.class_route_catalog where grade=grade_no),'[]'),'done',coalesce((select jsonb_agg(distinct r.activity_id) from turkce_private.class_route_attempts r join turkce_private.class_route_catalog rc on rc.activity_id=r.activity_id where r.user_id=actor and r.passed and rc.grade=grade_no),'[]'));
 elsif op='route_start' then
 perform public.turkce_member_request(actor,'state','{}');
 select * into c from turkce_private.class_route_catalog where activity_id=p->>'activity_id' and grade=pref.start_grade;
 if not found then raise exception 'Bu durak seçtiğin sınıfa ait değil.';end if;
 select activity_id into previous from turkce_private.class_route_catalog where grade=c.grade and position=c.position-1;
 if previous is not null and not exists(select 1 from turkce_private.class_route_attempts where user_id=actor and activity_id=previous and passed) then raise exception 'Önce önceki durağı tamamla.';end if;
 update turkce_private.class_route_attempts set finished_at=now() where user_id=actor and activity_id=c.activity_id and finished_at is null and started_at<now()-interval '1 day';
 select * into a from turkce_private.class_route_attempts where user_id=actor and activity_id=c.activity_id and finished_at is null for update;
 if not found then
 if (select energy from public.turkce_economy where user_id=actor)<3 then raise exception 'Bu durak için 3 enerji gerekli.';end if;
 update public.turkce_economy set energy=energy-3 where user_id=actor;
 insert into turkce_private.class_route_attempts(user_id,activity_id,questions) values(actor,c.activity_id,c.payload->'questions') returning * into a;
 end if;
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('attempt_id',a.id,'index',a.next_question,'activity',c.payload-'questions','questions',(select jsonb_agg(x.q-'answer'-'explanation' order by x.n) from jsonb_array_elements(a.questions) with ordinality x(q,n)));
 elsif op='route_answer' then
 select * into a from turkce_private.class_route_attempts where id=(p->>'attempt_id')::uuid and user_id=actor for update;
 if not found then raise exception 'Çalışma bulunamadı.';end if;
 idx:=(p->>'index')::int;if idx is null or idx<>a.next_question or a.finished_at is not null then raise exception 'Soru sırası değişti.';end if;
 if now()-a.started_at>interval '1 day' then raise exception 'Çalışmanın süresi doldu.';end if;
 if a.last_action_at is not null and now()-a.last_action_at<interval '450 milliseconds' then raise exception 'Soruyu okuyup yeniden dene.';end if;
 q:=a.questions->idx;if jsonb_typeof(p->'answer')<>'string' or not(q->'choices' @> jsonb_build_array(p->'answer')) then raise exception 'Bir cevap seç.';end if;
 good:=q->'answer'=p->'answer';a.next_question:=a.next_question+1;if good then a.correct:=a.correct+1;end if;total:=jsonb_array_length(a.questions);
 if a.next_question=total then
 a.finished_at:=now();a.passed:=a.correct::numeric/total>=.6;
 if a.passed then
 xp_gain:=round(140*a.correct::numeric/total);gold_gain:=round(80*a.correct::numeric/total);
 insert into public.turkce_reward_ledger(user_id,mode,activity_id,xp,gold) values(actor,'stop','class:'||a.activity_id,xp_gain,gold_gain) on conflict do nothing;get diagnostics written=row_count;
 if written=1 then update public.turkce_economy set xp=xp+xp_gain,gold=gold+gold_gain,updated_at=now() where user_id=actor;
 insert into public.turkce_activity(user_id,kind,description,shared) select actor,'stop','Sınıf parkurunda bir durağı tamamladı.',share_activity from public.turkce_profiles where id=actor;
 else xp_gain:=0;gold_gain:=0;end if;
 end if;
 end if;
 update turkce_private.class_route_attempts set next_question=a.next_question,correct=a.correct,finished_at=a.finished_at,passed=a.passed,last_action_at=now() where id=a.id;
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('correct',good,'answer',q->>'answer','explanation',q->>'explanation','index',a.next_question,'done',a.finished_at is not null,'passed',a.passed,'correct_count',a.correct,'total',total,'reward',jsonb_build_object('xp',xp_gain,'gold',gold_gain));
 elsif op in ('missions','mission_claim') then
 v_period:=coalesce(p->>'period','daily');if v_period not in ('daily','weekly') then raise exception 'Görev dönemi geçersiz.';end if;
 period_start:=case when v_period='daily' then day else date_trunc('week',day::timestamp)::date end;
 period_begin:=period_start::timestamp at time zone 'Europe/Istanbul';period_end:=(period_start+case when v_period='daily' then 1 else 7 end)::timestamp at time zone 'Europe/Istanbul';
 select count(*) into n_route from (select id from public.turkce_attempts where user_id=actor and mode='stop' and last_result->>'done'='true' and finished_at>=period_begin and finished_at<period_end union all select id from turkce_private.class_route_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end)x;
 select count(*) into n_study from turkce_private.study_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end;
 select coalesce(sum(n),0)::int into n_correct from (select correct_first as n from public.turkce_attempts where user_id=actor and last_result->>'done'='true' and finished_at>=period_begin and finished_at<period_end union all select correct from turkce_private.class_route_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end union all select correct from turkce_private.study_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end)x;
 select count(distinct d) into n_days from(select (finished_at at time zone 'Europe/Istanbul')::date d from public.turkce_attempts where user_id=actor and last_result->>'done'='true' and finished_at>=period_begin and finished_at<period_end union all select (finished_at at time zone 'Europe/Istanbul')::date from turkce_private.study_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end union all select (finished_at at time zone 'Europe/Istanbul')::date from turkce_private.class_route_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at>=period_begin and finished_at<period_end)x;
 tasks:=jsonb_build_array(jsonb_build_object('id','route','title',case when v_period='daily' then 'Parkurda bir adım' else 'Haftanın parkur kaşifi' end,'count',n_route,'target',case when v_period='daily' then 1 else 4 end,'xp',case when v_period='daily' then 40 else 120 end,'gold',case when v_period='daily' then 15 else 40 end),jsonb_build_object('id','study','title',case when v_period='daily' then 'Bir konuyu keşfet' else 'Üç konuyla güçlen' end,'count',n_study,'target',case when v_period='daily' then 1 else 3 end,'xp',case when v_period='daily' then 40 else 120 end,'gold',case when v_period='daily' then 15 else 40 end),jsonb_build_object('id',case when v_period='daily' then 'correct' else 'days' end,'title',case when v_period='daily' then 'Sekiz doğruyla parılda' else 'Beş gün birlikte öğrenelim' end,'count',case when v_period='daily' then n_correct else n_days end,'target',case when v_period='daily' then 8 else 5 end,'xp',case when v_period='daily' then 40 else 120 end,'gold',case when v_period='daily' then 20 else 40 end));
 if op='mission_claim' then
 select x into task from jsonb_array_elements(tasks) x where x->>'id'=p->>'task';if not found or (task->>'count')::int<(task->>'target')::int then raise exception 'Önce görevi tamamla.';end if;
 insert into turkce_private.mission_claims(user_id,period,period_start,task) values(actor,v_period,period_start,task->>'id') on conflict do nothing;get diagnostics written=row_count;
 if written=1 then
 xp_gain:=(task->>'xp')::int;gold_gain:=(task->>'gold')::int;
 insert into public.turkce_reward_ledger(user_id,mode,activity_id,xp,gold) values(actor,'mission',v_period||':'||period_start||':'||(task->>'id'),xp_gain,gold_gain);
 update public.turkce_economy set xp=xp+xp_gain,gold=gold+gold_gain,updated_at=now() where user_id=actor;
 end if;
 end if;
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('period',v_period,'start',period_start,'ends_at',period_end,'tasks',(select jsonb_agg(x||jsonb_build_object('claimed',exists(select 1 from turkce_private.mission_claims m where m.user_id=actor and m.period=v_period and m.period_start=period_start and m.task=x->>'id'))) from jsonb_array_elements(tasks) x),'reward',jsonb_build_object('xp',xp_gain,'gold',gold_gain));
 elsif op='report' then
 result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('preferences',to_jsonb(pref)-'user_id','stops',(select count(*) from public.turkce_stop_progress where user_id=actor)+(select count(distinct activity_id) from turkce_private.class_route_attempts where user_id=actor and passed),'study_tests',(select count(*) from turkce_private.study_attempts where user_id=actor and finished_at is not null),'game_runs',(select count(*) from public.turkce_attempts where user_id=actor and mode='game' and finished_at is not null),'subjects',coalesce((select jsonb_agg(x) from(select lesson_id,max(round(correct::numeric/jsonb_array_length(questions)*100)) score from turkce_private.study_attempts where user_id=actor and finished_at is not null group by lesson_id)x),'[]'),'weekly_xp',coalesce((select sum(xp) from public.turkce_reward_ledger where user_id=actor and earned_at>=(date_trunc('week',now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')),0));
 else raise exception 'İşlem bulunamadı.';end if;
 if rid is not null then insert into turkce_private.requests(user_id,request_id,response) values(actor,rid,result);end if;return result;
end;$$;
revoke all on function public.turkce_account_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_account_request(uuid,text,jsonb) to service_role;
