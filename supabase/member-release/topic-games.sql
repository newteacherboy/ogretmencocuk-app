create table if not exists turkce_private.topic_game_catalog(lesson_id text not null references turkce_private.study_catalog(lesson_id),kind text not null check(kind in ('hunt','workshop')),questions jsonb not null,primary key(lesson_id,kind));
create table if not exists turkce_private.topic_game_attempts(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.turkce_profiles(id) on delete cascade,
 lesson_id text not null,kind text not null,questions jsonb not null,next_question int not null default 0,correct int not null default 0,
 started_at timestamptz not null default now(),finished_at timestamptz,last_action_at timestamptz,
 foreign key(lesson_id,kind) references turkce_private.topic_game_catalog(lesson_id,kind)
);
create unique index if not exists topic_game_one_open on turkce_private.topic_game_attempts(user_id,lesson_id,kind) where finished_at is null;
create index if not exists topic_game_owner_time on turkce_private.topic_game_attempts(user_id,started_at desc);
alter table turkce_private.topic_game_catalog enable row level security;
alter table turkce_private.topic_game_attempts enable row level security;
revoke all on turkce_private.topic_game_catalog,turkce_private.topic_game_attempts from public,anon,authenticated;
grant all on turkce_private.topic_game_catalog,turkce_private.topic_game_attempts to service_role;
create or replace function public.turkce_topic_games_request(actor uuid,op text,p jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
declare a turkce_private.topic_game_attempts%rowtype; q jsonb; selected jsonb; prior jsonb; result jsonb; rid uuid; lid text; k text; idx int; good boolean; answer_text text; xp_gain int:=0; gold_gain int:=0; written int; rewards int;
begin
 perform 1 from public.turkce_economy e join public.turkce_profiles u on u.id=e.user_id where e.user_id=actor and not u.disabled for update of e;
 if not found then raise exception 'Aktif öğrenci hesabı gerekli.';end if;
 if op='topic_status' then
  return jsonb_build_object('ok',true,'games',coalesce((select jsonb_agg(x) from(select lesson_id,kind,max(round(correct::numeric/jsonb_array_length(questions)*100)) as score from turkce_private.topic_game_attempts where user_id=actor and next_question=jsonb_array_length(questions) and finished_at is not null group by lesson_id,kind)x),'[]'));
 end if;
 rid:=(p->>'request_id')::uuid;if rid is null then raise exception 'İstek kimliği gerekli.';end if;
 select response into result from turkce_private.requests where user_id=actor and request_id=rid;if found then return result;end if;
 if op='topic_start' then
  lid:=p->>'lesson_id';k:=p->>'kind';
  if not exists(select 1 from turkce_private.topic_game_catalog where lesson_id=lid and kind=k) then raise exception 'Konu oyunu bulunamadı.';end if;
  select * into a from turkce_private.topic_game_attempts where user_id=actor and lesson_id=lid and kind=k and finished_at is null for update;
  if not found then
   perform public.turkce_member_request(actor,'state','{}');
   if (select energy from public.turkce_economy where user_id=actor)<3 then raise exception 'Oyuna başlamak için 3 enerji gerekli.';end if;
   select questions into prior from turkce_private.topic_game_attempts where user_id=actor and lesson_id=lid and kind=k order by started_at desc limit 1;
   select jsonb_agg(x order by position) into selected from (
    select item as x,row_number() over(order by exists(select 1 from jsonb_array_elements(coalesce(prior,'[]')) z where z->>'id'=item->>'id'),random()) as position
    from turkce_private.topic_game_catalog c cross join lateral jsonb_array_elements(c.questions) item where c.lesson_id=lid and c.kind=k
   )s where position<=8;
   if jsonb_array_length(selected)<>8 then raise exception 'Bu konu için yeterli oyun içeriği yok.';end if;
   insert into turkce_private.topic_game_attempts(user_id,lesson_id,kind,questions)values(actor,lid,k,selected) returning * into a;
   update public.turkce_economy set energy=energy-3 where user_id=actor;
  end if;
  -- Choices and tiles are shuffled independently of the hidden answer snapshot.
  result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('attempt_id',a.id,'index',a.next_question,'kind',a.kind,'correct_count',a.correct,'questions',(select jsonb_agg((x-'answer'-'explanation'-'context')||case when a.kind='hunt' then jsonb_build_object('choices',(select jsonb_agg(c order by random()) from jsonb_array_elements(x->'choices')c)) else jsonb_build_object('tiles',(select jsonb_agg(c order by random()) from jsonb_array_elements(x->'tiles')c)) end order by n) from jsonb_array_elements(a.questions) with ordinality s(x,n)));
 elsif op='topic_answer' then
  select * into a from turkce_private.topic_game_attempts where id=(p->>'attempt_id')::uuid and user_id=actor for update;
  if not found then raise exception 'Oyun bulunamadı.';end if;
  idx:=(p->>'index')::int;
  if idx is null or idx<>a.next_question or a.finished_at is not null then raise exception 'Soru sırası değişti. Oyunu yeniden aç.';end if;
  if a.last_action_at>now()-interval '350 milliseconds' then raise exception 'Biraz yavaşlayıp yeniden dene.';end if;
  q:=a.questions->idx;
  if a.kind='hunt' then
   if not exists(select 1 from jsonb_array_elements_text(q->'choices') x where x=p->>'answer') then raise exception 'Bir cevap seç.';end if;
   answer_text:=p->>'answer';
  else
   if jsonb_typeof(p->'answer') is distinct from 'array' or jsonb_array_length(p->'answer')<>(q->>'slots')::int then raise exception 'Tüm parçaları yerleştir.';end if;
   if (select count(distinct x) from jsonb_array_elements_text(p->'answer')x)<>jsonb_array_length(p->'answer') then raise exception 'Aynı parçayı iki kez kullanamazsın.';end if;
   if exists(select 1 from jsonb_array_elements_text(p->'answer') x where not exists(select 1 from jsonb_array_elements(q->'tiles') t where t->>'id'=x)) then raise exception 'Parça bulunamadı.';end if;
   select string_agg(t->>'text',q->>'joiner' order by n) into answer_text from jsonb_array_elements_text(p->'answer') with ordinality s(x,n) join lateral jsonb_array_elements(q->'tiles') t on t->>'id'=x;
  end if;
  good:=answer_text=q->>'answer';a.correct:=a.correct+case when good then 1 else 0 end;a.next_question:=a.next_question+1;
  if a.next_question=jsonb_array_length(a.questions) then
   a.finished_at:=now();
   select count(*) into rewards from public.turkce_reward_ledger where user_id=actor and mode='game' and reward_day=(now() at time zone 'Europe/Istanbul')::date and activity_id like 'topic:%';
   if a.correct::numeric/jsonb_array_length(a.questions)>=.8 and rewards<3 then
    xp_gain:=round(70*a.correct::numeric/jsonb_array_length(a.questions));gold_gain:=round(30*a.correct::numeric/jsonb_array_length(a.questions));
    insert into public.turkce_reward_ledger(user_id,mode,activity_id,xp,gold) values(actor,'game','topic:'||a.lesson_id||':'||a.kind,xp_gain,gold_gain) on conflict do nothing;get diagnostics written=row_count;
    if written=0 then xp_gain:=0;gold_gain:=0;end if;
    update public.turkce_economy set xp=xp+xp_gain,gold=gold+gold_gain where user_id=actor;
   end if;
  end if;
  update turkce_private.topic_game_attempts set next_question=a.next_question,correct=a.correct,finished_at=a.finished_at,last_action_at=now() where id=a.id;
  result:=public.turkce_member_request(actor,'state','{}')||jsonb_build_object('correct',good,'answer',q->>'answer','explanation',q->>'explanation','index',a.next_question,'done',a.finished_at is not null,'correct_count',a.correct,'total',jsonb_array_length(a.questions),'reward',jsonb_build_object('xp',xp_gain,'gold',gold_gain));
 else raise exception 'İşlem bulunamadı.';end if;
 insert into turkce_private.requests(user_id,request_id,response)values(actor,rid,result);
 return result;
end $$;
revoke all on function public.turkce_topic_games_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_topic_games_request(uuid,text,jsonb) to service_role;
