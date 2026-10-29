-- Permanent achievements derived exclusively from verified activity receipts.
create table if not exists turkce_private.member_badges (
 user_id uuid not null references public.turkce_profiles(id) on delete cascade,
 badge_id text not null, earned_at timestamptz not null default now(),
 primary key(user_id,badge_id)
);
alter table turkce_private.member_badges enable row level security;
revoke all on turkce_private.member_badges from public,anon,authenticated;
grant all on turkce_private.member_badges to service_role;
create or replace function public.turkce_badges_request(actor uuid,op text,p jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
declare stats jsonb; catalog jsonb; badges jsonb;
begin
 if op<>'badges' then raise exception 'İşlem bulunamadı.'; end if;
 perform 1 from public.turkce_economy e join public.turkce_profiles u on u.id=e.user_id where e.user_id=actor and not u.disabled for update of e;
 if not found then raise exception 'Aktif öğrenci hesabı gerekli.'; end if;
 with completed as (
  select a.correct_first as correct,a.finished_at from public.turkce_attempts a where a.user_id=actor and a.finished_at is not null and a.last_result->>'done'='true'
  union all select a.correct,a.finished_at from turkce_private.study_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions)
  union all select a.correct,a.finished_at from turkce_private.topic_game_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions)
  union all select a.correct,a.finished_at from turkce_private.class_route_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions)
 ) select jsonb_build_object(
  'member',1,
  'stops',(select count(*) from public.turkce_stop_progress s where s.user_id=actor)+(select count(distinct a.activity_id) from turkce_private.class_route_attempts a where a.user_id=actor and a.passed),
  'study',(select count(*) from turkce_private.study_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions)),
  'perfect',(select count(*) from turkce_private.study_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions) and a.correct=jsonb_array_length(a.questions) and jsonb_array_length(a.questions)>0),
  'games',(select count(*) from public.turkce_attempts a where a.user_id=actor and a.mode='game' and a.finished_at is not null and a.last_result->>'done'='true')+(select count(*) from turkce_private.topic_game_attempts a where a.user_id=actor and a.finished_at is not null and a.next_question=jsonb_array_length(a.questions)),
  'correct',coalesce((select sum(c.correct) from completed c),0),
  'days',(select count(distinct (c.finished_at at time zone 'Europe/Istanbul')::date) from completed c),
  'missions',(select count(*) from turkce_private.mission_claims m where m.user_id=actor),
  'level',(select public.turkce_level(e.xp) from public.turkce_economy e where e.user_id=actor)
 ) into stats;
 catalog:='[
  {"id":"first-wing","metric":"member","target":1},
  {"id":"first-step","metric":"stops","target":1},
  {"id":"island-scout","metric":"stops","target":5},
  {"id":"route-captain","metric":"stops","target":10},
  {"id":"atlas-master","metric":"stops","target":25},
  {"id":"first-page","metric":"study","target":1},
  {"id":"knowledge-garden","metric":"study","target":5},
  {"id":"library-keeper","metric":"study","target":10},
  {"id":"flawless-feather","metric":"perfect","target":1},
  {"id":"diamond-mind","metric":"perfect","target":5},
  {"id":"game-spark","metric":"games","target":1},
  {"id":"game-explorer","metric":"games","target":5},
  {"id":"answer-scout","metric":"correct","target":25},
  {"id":"word-star","metric":"correct","target":100},
  {"id":"steady-wings","metric":"days","target":3},
  {"id":"seven-suns","metric":"days","target":7},
  {"id":"mission-scout","metric":"missions","target":3},
  {"id":"mission-hero","metric":"missions","target":10},
  {"id":"rising-wing","metric":"level","target":3},
  {"id":"papi-pride","metric":"level","target":10}
 ]';
 insert into turkce_private.member_badges(user_id,badge_id)
 select actor,b->>'id' from jsonb_array_elements(catalog) b where coalesce((stats->>(b->>'metric'))::bigint,0)>=(b->>'target')::int on conflict do nothing;
 select jsonb_agg(b||jsonb_build_object('count',coalesce((stats->>(b->>'metric'))::bigint,0),'earned_at',m.earned_at) order by ord) into badges
 from jsonb_array_elements(catalog) with ordinality as c(b,ord) left join turkce_private.member_badges m on m.user_id=actor and m.badge_id=b->>'id';
 return jsonb_build_object('ok',true,'badges',badges,'earned',(select count(*) from turkce_private.member_badges m where m.user_id=actor));
end $$;
revoke all on function public.turkce_badges_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_badges_request(uuid,text,jsonb) to service_role;
