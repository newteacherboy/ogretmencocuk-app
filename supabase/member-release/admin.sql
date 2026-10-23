create table if not exists turkce_private.admin_audit(id bigint generated always as identity primary key,actor uuid not null,target uuid,action text not null,created_at timestamptz not null default now());
alter table turkce_private.admin_audit enable row level security;
revoke all on turkce_private.admin_audit from public,anon,authenticated;
grant all on turkce_private.admin_audit to service_role;
grant usage,select on sequence turkce_private.admin_audit_id_seq to service_role;
create or replace function public.turkce_admin_request(actor uuid,op text,p jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare target uuid; result jsonb; n int;
begin
 -- The Edge Function authenticates the admin via Auth app_metadata. No client role is trusted.
 if op='list' then
 result:=jsonb_build_object('students',coalesce((select jsonb_agg(x) from(select u.id,u.username,u.full_name,u.school,u.grade,u.disabled,u.created_at,e.energy,e.xp,e.gold,public.turkce_level(e.xp) as level,(select count(*) from public.turkce_stop_progress s where s.user_id=u.id) as completed from public.turkce_profiles u join public.turkce_economy e on e.user_id=u.id where u.id<>actor and (coalesce(p->>'search','')='' or u.username ilike '%'||left(p->>'search',80)||'%' or u.full_name ilike '%'||left(p->>'search',80)||'%' or u.school ilike '%'||left(p->>'search',80)||'%') order by u.created_at desc limit 100)x),'[]'::jsonb),'total',(select count(*) from public.turkce_profiles where id<>actor));
 elsif op='update' then
 target:=(p->>'user_id')::uuid;
 if target=actor or target is null then raise exception 'Geçersiz öğrenci.';end if;
 if length(trim(p->>'full_name')) not between 3 and 80 or length(trim(p->>'school')) not between 3 and 120 or (p->>'grade')::int not between 5 and 8 then raise exception 'Öğrenci bilgilerini kontrol et.';end if;
 update public.turkce_profiles set full_name=trim(p->>'full_name'),school=trim(p->>'school'),grade=(p->>'grade')::smallint,disabled=coalesce((p->>'disabled')::boolean,disabled),updated_at=now() where id=target and username ~ '^tr[a-z0-9]{10}$';
 if not found then raise exception 'Öğrenci bulunamadı.';end if;
 insert into turkce_private.admin_audit(actor,target,action)values(actor,target,'profile_update');result:='{}'::jsonb;
 elsif op='economy' then
 target:=(p->>'user_id')::uuid;
 if target=actor or not exists(select 1 from public.turkce_profiles where id=target and username ~ '^tr[a-z0-9]{10}$') then raise exception 'Öğrenci bulunamadı.';end if;
 if (p->>'energy')::int not between 0 and 30 or (p->>'xp')::bigint not between 0 and 10000000 or (p->>'gold')::bigint not between 0 and 10000000 then raise exception 'Bakiyeleri kontrol et.';end if;
 update public.turkce_economy set energy=(p->>'energy')::int,xp=(p->>'xp')::bigint,gold=(p->>'gold')::bigint,energy_refill_at=now(),updated_at=now() where user_id=target;
 insert into turkce_private.admin_audit(actor,target,action)values(actor,target,'economy_update');result:='{}'::jsonb;
 elsif op='audit' then
 target:=(p->>'user_id')::uuid;insert into turkce_private.admin_audit(actor,target,action)values(actor,target,left(p->>'action',40));result:='{}'::jsonb;
 else raise exception 'İşlem bulunamadı.';end if;
 return result||jsonb_build_object('ok',true);
end;$$;
revoke all on function public.turkce_admin_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_admin_request(uuid,text,jsonb) to service_role;
