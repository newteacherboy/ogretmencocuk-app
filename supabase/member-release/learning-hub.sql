-- Extend only the ledger's reviewed mode-specific limits for first-clear study rewards.
alter table public.turkce_reward_ledger drop constraint if exists turkce_reward_ledger_mode_check;
alter table public.turkce_reward_ledger drop constraint if exists turkce_reward_ledger_xp_check;
alter table public.turkce_reward_ledger drop constraint if exists turkce_reward_ledger_gold_check;
alter table public.turkce_reward_ledger drop constraint if exists turkce_reward_ledger_check;
alter table public.turkce_reward_ledger drop constraint if exists turkce_reward_ledger_check1;
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_mode_check check(mode in ('stop','game','study'));
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_check check(xp>=0 and ((mode='stop' and xp<=140) or (mode='game' and xp<=70) or (mode='study' and xp<=160)));
alter table public.turkce_reward_ledger add constraint turkce_reward_ledger_check1 check(gold>=0 and ((mode='stop' and gold<=80) or (mode='game' and gold<=30) or (mode='study' and gold<=60)));
create unique index if not exists turkce_study_reward_once on public.turkce_reward_ledger(user_id,activity_id) where mode='study';
-- Service-only study and friendship reactions. Identity is verified by turkce-features.
create table if not exists turkce_private.study_catalog(lesson_id text primary key,questions jsonb not null);
create table if not exists turkce_private.study_attempts(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 lesson_id text not null references turkce_private.study_catalog(lesson_id),questions jsonb not null,
 next_question int not null default 0,correct int not null default 0,started_at timestamptz not null default now(),finished_at timestamptz,last_action_at timestamptz
);
create unique index if not exists study_one_open on turkce_private.study_attempts(user_id,lesson_id) where finished_at is null;
create index if not exists study_owner_time on turkce_private.study_attempts(user_id,started_at desc);
create table if not exists turkce_private.activity_likes(
 activity_id bigint not null references public.turkce_activity(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default now(),primary key(activity_id,user_id)
);
alter table turkce_private.study_catalog enable row level security;
alter table turkce_private.study_attempts enable row level security;
alter table turkce_private.activity_likes enable row level security;
revoke all on turkce_private.study_catalog,turkce_private.study_attempts,turkce_private.activity_likes from public,anon,authenticated;
grant all on turkce_private.study_catalog,turkce_private.study_attempts,turkce_private.activity_likes to service_role;
create or replace function public.turkce_features_request(actor uuid,op text,p jsonb default '{}'::jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb; rid uuid; a turkce_private.study_attempts%rowtype; catalog jsonb; selected jsonb; question jsonb; previous jsonb; n int; good boolean; target bigint; activity public.turkce_activity%rowtype; awarded int:=0; coins int:=0; score int;
begin
 perform 1 from public.turkce_economy where user_id=actor for update;
 if not found or not exists(select 1 from public.turkce_profiles where id=actor and not disabled) then raise exception 'Hesabına giriş yap.';end if;
 if op not in ('social','study_status') then
 rid:=(p->>'request_id')::uuid;if rid is null then raise exception 'İstek kimliği gerekli.';end if;
 select response into result from turkce_private.requests where user_id=actor and request_id=rid;if found then return result;end if;
 end if;
 if op='social' then
 result:=jsonb_build_object('ok',true,'feed',coalesce((select jsonb_agg(x order by x.created_at desc) from (
 select t.id::text as id,u.username,t.description,t.kind,t.created_at,
 (select count(*) from turkce_private.activity_likes l where l.activity_id=t.id) as likes,
 exists(select 1 from turkce_private.activity_likes l where l.activity_id=t.id and l.user_id=actor) as liked,
 t.user_id=actor as self
 from public.turkce_activity t join public.turkce_profiles u on u.id=t.user_id
 where t.shared and u.share_activity and not u.disabled and (t.user_id=actor or exists(select 1 from public.turkce_friendships f where f.accepted_at is not null and ((f.requester=actor and f.recipient=t.user_id) or (f.recipient=actor and f.requester=t.user_id))))
 order by t.created_at desc,t.id desc limit 40)x),'[]'::jsonb));
 elsif op='like' then
 target:=(p->>'activity_id')::bigint;
 select t.* into activity from public.turkce_activity t join public.turkce_profiles u on u.id=t.user_id where t.id=target and t.shared and u.share_activity and not u.disabled;
 if not found then raise exception 'Bu paylaşım artık görünmüyor.';end if;
 if activity.user_id<>actor and not exists(select 1 from public.turkce_friendships f where f.accepted_at is not null and ((f.requester=actor and f.recipient=activity.user_id) or (f.recipient=actor and f.requester=activity.user_id))) then raise exception 'Yalnızca arkadaşlarının paylaşımlarını beğenebilirsin.';end if;
 if coalesce((p->>'liked')::boolean,true) then insert into turkce_private.activity_likes(activity_id,user_id) values(target,actor) on conflict do nothing;
 else delete from turkce_private.activity_likes where activity_id=target and user_id=actor;end if;
 result:=jsonb_build_object('ok',true,'id',target::text,'likes',(select count(*) from turkce_private.activity_likes where activity_id=target),'liked',exists(select 1 from turkce_private.activity_likes where activity_id=target and user_id=actor));
 elsif op='study_status' then
 result:=jsonb_build_object('ok',true,'lessons',coalesce((select jsonb_agg(x) from (select lesson_id,max(round(correct::numeric/jsonb_array_length(questions)*100)) as score,count(*) as attempts from turkce_private.study_attempts where user_id=actor and finished_at is not null group by lesson_id)x),'[]'::jsonb));
 elsif op='study_start' then
 select questions into catalog from turkce_private.study_catalog where lesson_id=p->>'lesson_id';if not found then raise exception 'Konu bulunamadı.';end if;
 update turkce_private.study_attempts set finished_at=now() where user_id=actor and lesson_id=p->>'lesson_id' and finished_at is null and started_at<now()-interval '1 day';
 select * into a from turkce_private.study_attempts where user_id=actor and lesson_id=p->>'lesson_id' and finished_at is null for update;
 if not found then
 select questions into previous from turkce_private.study_attempts where user_id=actor and lesson_id=p->>'lesson_id' order by started_at desc limit 1;
 select jsonb_agg(q order by priority,r) into selected from (
 select q,case when exists(select 1 from jsonb_array_elements(coalesce(previous,'[]'::jsonb)) old where old->>'id'=q->>'id') then 1 else 0 end priority,random() r from jsonb_array_elements(catalog) q order by priority,r limit 8)x;
 insert into turkce_private.study_attempts(user_id,lesson_id,questions) values(actor,p->>'lesson_id',selected) returning * into a;
 end if;
 result:=jsonb_build_object('ok',true,'attempt_id',a.id,'index',a.next_question,'correct',a.correct,'questions',(select jsonb_agg(q-'answer'-'explanation' order by x.n) from jsonb_array_elements(a.questions) with ordinality x(q,n)));
 elsif op='study_answer' then
 select * into a from turkce_private.study_attempts where id=(p->>'attempt_id')::uuid and user_id=actor for update;
 if not found then raise exception 'Test bulunamadı.';end if;
 n:=(p->>'index')::int;
 if n is null or n<>a.next_question or a.finished_at is not null then raise exception 'Soru sırası değişti. Konuyu yeniden aç.';end if;
 if now()-a.started_at>interval '1 day' then raise exception 'Testin süresi doldu.';end if;
 if a.last_action_at is not null and now()-a.last_action_at<interval '450 milliseconds' then raise exception 'Soruyu okuyup yeniden dene.';end if;
 question:=a.questions->n;
 if jsonb_typeof(p->'answer')<>'string' or not (question->'choices' @> jsonb_build_array(p->'answer')) then raise exception 'Bir cevap seç.';end if;
 good:=question->'answer'=p->'answer';a.next_question:=a.next_question+1;if good then a.correct:=a.correct+1;end if;
 if a.next_question=jsonb_array_length(a.questions) then
 a.finished_at:=now();score:=round(a.correct::numeric/jsonb_array_length(a.questions)*100);
 if score>=60 and not exists(select 1 from public.turkce_reward_ledger where user_id=actor and mode='study' and activity_id=a.lesson_id) then
 awarded:=round(160*a.correct::numeric/jsonb_array_length(a.questions));coins:=round(60*a.correct::numeric/jsonb_array_length(a.questions));
 insert into public.turkce_reward_ledger(user_id,mode,activity_id,xp,gold) values(actor,'study',a.lesson_id,awarded,coins);
 update public.turkce_economy set xp=xp+awarded,gold=gold+coins,updated_at=now() where user_id=actor;
 insert into public.turkce_activity(user_id,kind,description,shared) select actor,'award','Bir konu testini başarıyla tamamladı.',share_activity from public.turkce_profiles where id=actor;
 end if;
 end if;
 update turkce_private.study_attempts set next_question=a.next_question,correct=a.correct,finished_at=a.finished_at,last_action_at=now() where id=a.id;
 result:=public.turkce_member_request(actor,'state','{}'::jsonb)||jsonb_build_object('ok',true,'correct',good,'answer',question->>'answer','explanation',question->>'explanation','index',a.next_question,'total',jsonb_array_length(a.questions),'correct_count',a.correct,'done',a.finished_at is not null,'reward',jsonb_build_object('xp',awarded,'gold',coins));
 else raise exception 'İşlem bulunamadı.';end if;
 if rid is not null then insert into turkce_private.requests(user_id,request_id,response) values(actor,rid,result);end if;
 return result;
end;$$;
revoke all on function public.turkce_features_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_features_request(uuid,text,jsonb) to service_role;
