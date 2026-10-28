-- Username-only research registration. Existing user IDs and progress are preserved.
begin;
alter table public.turkce_profiles drop constraint if exists username_format;
alter table public.turkce_profiles add constraint username_format check(username ~ '^[a-zA-Z0-9_][a-zA-Z0-9_.]{2,19}$');
create table if not exists turkce_private.registration_notifications(
 id bigint generated always as identity primary key,
 user_id uuid not null unique references auth.users(id) on delete cascade,
 source text not null check(source in ('student','teacher')),
 created_at timestamptz not null default now(),read_at timestamptz
);
alter table turkce_private.registration_notifications enable row level security;
revoke all on turkce_private.registration_notifications from public,anon,authenticated;
grant all on turkce_private.registration_notifications to service_role;
grant usage,select on sequence turkce_private.registration_notifications_id_seq to service_role;
create or replace function turkce_private.turkce_on_auth_signup()
returns trigger language plpgsql security definer set search_path='' as $$
declare username text; grade smallint; full_name text; school text; is_admin boolean;
begin
 username:=lower(coalesce(new.raw_user_meta_data->>'username',''));
 is_admin:=coalesce(new.raw_app_meta_data->>'turkce_role'='admin',false);
 grade:=coalesce((new.raw_user_meta_data->>'grade')::smallint,5);
 full_name:=coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),username);
 school:=coalesce(nullif(trim(new.raw_user_meta_data->>'school'),''),'Araştırma Grubu');
 if username !~ '^[a-z0-9][a-z0-9_.]{2,19}$' or (username in ('dijimedu','admin','administrator','teacher','ogretmen','yonetici','root','support') and not is_admin) or grade not between 5 and 8 or length(full_name) not between 3 and 80 or length(school) not between 3 and 120 then raise exception 'Öğrenci bilgilerini kontrol et.';end if;
 insert into public.turkce_profiles(id,username,grade,full_name,school)values(new.id,username,grade,full_name,school);
 insert into public.turkce_economy(user_id)values(new.id);
 if not is_admin then
 insert into turkce_private.registration_notifications(user_id,source)values(new.id,case when new.raw_user_meta_data->>'registration_source'='teacher' then 'teacher' else 'student' end);
 end if;
 return new;
end;$$;
revoke all on function turkce_private.turkce_on_auth_signup() from public,anon,authenticated;
create or replace function public.turkce_registration_notifications(actor uuid,op text,p jsonb default '{}'::jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from auth.users where id=actor and raw_app_meta_data->>'turkce_role'='admin') then raise exception 'Bu işlem için yetkin yok.';end if;
 if op='notifications_read' then
 update turkce_private.registration_notifications set read_at=now() where id in(select value::bigint from jsonb_array_elements_text(coalesce(p->'ids','[]'::jsonb))) and read_at is null;
 elsif op<>'notifications' then raise exception 'İşlem bulunamadı.';end if;
 return jsonb_build_object('ok',true,'unread',(select count(*) from turkce_private.registration_notifications where read_at is null),'notifications',coalesce((select jsonb_agg(x) from(select n.id,p.username,p.grade,n.source,n.created_at,n.read_at from turkce_private.registration_notifications n join public.turkce_profiles p on p.id=n.user_id order by n.created_at desc limit 50)x),'[]'::jsonb));
end;$$;
revoke all on function public.turkce_registration_notifications(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_registration_notifications(uuid,text,jsonb) to service_role;
create or replace function public.turkce_admin_request(actor uuid,op text,p jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare target uuid; result jsonb; n int;
begin
 -- The Edge Function authenticates the admin via Auth app_metadata. No client role is trusted.
 if op='list' then
 result:=jsonb_build_object('students',coalesce((select jsonb_agg(x) from(select u.id,u.username,u.full_name,u.school,u.grade,u.disabled,u.created_at,e.energy,e.xp,e.gold,public.turkce_level(e.xp) as level,(select count(*) from public.turkce_stop_progress s where s.user_id=u.id) as completed from public.turkce_profiles u join public.turkce_economy e on e.user_id=u.id where u.id<>actor and not exists(select 1 from auth.users a where a.id=u.id and a.raw_app_meta_data->>'turkce_role'='admin') and (coalesce(p->>'search','')='' or u.username ilike '%'||left(p->>'search',80)||'%' or u.full_name ilike '%'||left(p->>'search',80)||'%' or u.school ilike '%'||left(p->>'search',80)||'%') order by u.created_at desc limit 100)x),'[]'::jsonb),'total',(select count(*) from public.turkce_profiles where id<>actor and not exists(select 1 from auth.users a where a.id=turkce_profiles.id and a.raw_app_meta_data->>'turkce_role'='admin')));
 elsif op='update' then
 target:=(p->>'user_id')::uuid;
 if target=actor or target is null then raise exception 'Geçersiz öğrenci.';end if;
 if length(trim(p->>'full_name')) not between 3 and 80 or length(trim(p->>'school')) not between 3 and 120 or (p->>'grade')::int not between 5 and 8 then raise exception 'Öğrenci bilgilerini kontrol et.';end if;
 update public.turkce_profiles set full_name=trim(p->>'full_name'),school=trim(p->>'school'),grade=(p->>'grade')::smallint,disabled=coalesce((p->>'disabled')::boolean,disabled),updated_at=now() where id=target and username<>'dijimedu' and not exists(select 1 from auth.users a where a.id=target and a.raw_app_meta_data->>'turkce_role'='admin');
 if not found then raise exception 'Öğrenci bulunamadı.';end if;
 insert into turkce_private.admin_audit(actor,target,action)values(actor,target,'profile_update');result:='{}'::jsonb;
 elsif op='economy' then
 target:=(p->>'user_id')::uuid;
 if target=actor or not exists(select 1 from public.turkce_profiles where id=target and username<>'dijimedu' and not exists(select 1 from auth.users a where a.id=target and a.raw_app_meta_data->>'turkce_role'='admin')) then raise exception 'Öğrenci bulunamadı.';end if;
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

commit;
