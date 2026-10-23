alter table public.turkce_profiles add column if not exists full_name text not null default '';
alter table public.turkce_profiles add column if not exists school text not null default '';
create table if not exists turkce_private.auth_limits(bucket text primary key,started_at timestamptz not null default now(),attempts int not null default 1);
create table if not exists turkce_private.recovery(user_id uuid primary key references auth.users(id) on delete cascade,secret_hash text not null);
alter table turkce_private.auth_limits enable row level security;
alter table turkce_private.recovery enable row level security;
revoke all on turkce_private.auth_limits,turkce_private.recovery from public,anon,authenticated;
grant all on turkce_private.auth_limits,turkce_private.recovery to service_role;
create or replace function public.turkce_auth_budget(bucket_key text,max_count int) returns boolean language plpgsql security invoker set search_path='' as $$
declare n int;
begin
 insert into turkce_private.auth_limits(bucket) values(bucket_key) on conflict(bucket) do update set attempts=case when auth_limits.started_at<now()-interval '1 hour' then 1 else auth_limits.attempts+1 end,started_at=case when auth_limits.started_at<now()-interval '1 hour' then now() else auth_limits.started_at end returning attempts into n;
 return n<=max_count;
end;$$;
create or replace function public.turkce_recovery_store(actor uuid,hash text) returns void language sql security invoker set search_path='' as $$insert into turkce_private.recovery(user_id,secret_hash)values(actor,hash) on conflict(user_id) do update set secret_hash=excluded.secret_hash;$$;
create or replace function public.turkce_recovery_check(code text,hash text) returns uuid language sql stable security invoker set search_path='' as $$select p.id from public.turkce_profiles p join turkce_private.recovery r on r.user_id=p.id where p.username=lower(code) and r.secret_hash=hash;$$;
revoke all on function public.turkce_auth_budget(text,int),public.turkce_recovery_store(uuid,text),public.turkce_recovery_check(text,text) from public,anon,authenticated;
grant execute on function public.turkce_auth_budget(text,int),public.turkce_recovery_store(uuid,text),public.turkce_recovery_check(text,text) to service_role;
create or replace function turkce_private.turkce_on_auth_signup()
returns trigger language plpgsql security definer set search_path='' as $$
declare username text; grade smallint; full_name text; school text;
begin
 username:=lower(coalesce(new.raw_user_meta_data->>'username',''));
 grade:=(new.raw_user_meta_data->>'grade')::smallint;
 full_name:=trim(coalesce(new.raw_user_meta_data->>'full_name',''));
 school:=trim(coalesce(new.raw_user_meta_data->>'school',''));
 if (username !~ '^tr[a-z0-9]{10}$' and not coalesce((username='dijimedu' and new.raw_app_meta_data->>'turkce_role'='admin'),false)) or grade is null or grade not between 5 and 8 or length(full_name) not between 3 and 80 or length(school) not between 3 and 120 then raise exception 'Öğrenci bilgilerini kontrol et.';end if;
 insert into public.turkce_profiles(id,username,grade,full_name,school)values(new.id,username,grade,full_name,school);
 insert into public.turkce_economy(user_id)values(new.id);
 return new;
end;$$;
revoke all on function turkce_private.turkce_on_auth_signup() from public,anon,authenticated;
drop trigger if exists turkce_profile_after_auth_signup on auth.users;
create trigger turkce_profile_after_auth_signup after insert on auth.users for each row execute function turkce_private.turkce_on_auth_signup();
drop function if exists public.turkce_on_auth_signup();
create or replace function public.turkce_recovery_consume(code text,hash text,next_hash text) returns uuid language sql security invoker set search_path='' as $$update turkce_private.recovery r set secret_hash=next_hash from public.turkce_profiles p where p.id=r.user_id and p.username=lower(code) and r.secret_hash=hash returning r.user_id;$$;
revoke all on function public.turkce_recovery_consume(text,text,text) from public,anon,authenticated;
grant execute on function public.turkce_recovery_consume(text,text,text) to service_role;
