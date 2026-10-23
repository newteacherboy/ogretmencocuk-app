-- Diji-Medu Türkçe: independent Supabase project only.
-- Run ONLY in the Turkish project after verifying project ref.
-- Emails/passwords belong exclusively to Supabase Auth, never public profiles.
create table if not exists public.turkce_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique,
 grade smallint not null check (grade between 5 and 8),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint username_format check (username ~ '^[a-zA-Z0-9_]{3,20}$')
);
create table if not exists public.turkce_economy (
 user_id uuid primary key references auth.users(id) on delete cascade,
 energy smallint not null default 30 check (energy between 0 and 30),
 xp bigint not null default 0 check (xp >= 0),
 gold bigint not null default 0 check (gold >= 0),
 energy_refill_at timestamptz not null default now(),
 gift_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.turkce_stop_progress (
 user_id uuid not null references auth.users(id) on delete cascade,
 stop_id smallint not null check (stop_id between 1 and 24),
 completed_at timestamptz not null default now(),
 primary key(user_id,stop_id)
);
create table if not exists public.turkce_friendships (
 requester uuid not null references auth.users(id) on delete cascade,
 recipient uuid not null references auth.users(id) on delete cascade,
 accepted_at timestamptz,
 created_at timestamptz not null default now(),
 primary key(requester,recipient),
 constraint not_self_friend check (requester <> recipient)
);
create table if not exists public.turkce_activity (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check (kind in ('stop','level','badge','game','award')),
 description text not null check (char_length(description) between 1 and 160),
 shared boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists turkce_activity_owner_time on public.turkce_activity(user_id,created_at desc);
create index if not exists turkce_progress_user on public.turkce_stop_progress(user_id);

alter table public.turkce_profiles enable row level security;
alter table public.turkce_economy enable row level security;
alter table public.turkce_stop_progress enable row level security;
alter table public.turkce_friendships enable row level security;
alter table public.turkce_activity enable row level security;

-- No table is readable by other users. Display-name lookup/leaderboards
-- must be served through a later privacy-reviewed server endpoint.
revoke all on public.turkce_profiles from anon,authenticated;
revoke all on public.turkce_economy from anon,authenticated;
revoke all on public.turkce_stop_progress from anon,authenticated;
revoke all on public.turkce_friendships from anon,authenticated;
revoke all on public.turkce_activity from anon,authenticated;
grant select on public.turkce_profiles to authenticated;
grant select on public.turkce_economy to authenticated;
grant select on public.turkce_stop_progress to authenticated;
grant select on public.turkce_friendships to authenticated;
grant select on public.turkce_activity to authenticated;

drop policy if exists own_profile_read on public.turkce_profiles;
create policy own_profile_read on public.turkce_profiles
 for select to authenticated using ((select auth.uid())=id);
drop policy if exists own_economy_read on public.turkce_economy;
create policy own_economy_read on public.turkce_economy
 for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists own_progress_read on public.turkce_stop_progress;
create policy own_progress_read on public.turkce_stop_progress
 for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists own_friendships_read on public.turkce_friendships;
create policy own_friendships_read on public.turkce_friendships
 for select to authenticated using ((select auth.uid()) in (requester,recipient));
drop policy if exists own_activity_read on public.turkce_activity;
create policy own_activity_read on public.turkce_activity
 for select to authenticated using ((select auth.uid())=user_id);

-- The trigger inserts validated user-supplied display info, but metadata
-- MUST NOT control authorization or roles. No client mutation of economy.
create or replace function public.turkce_on_auth_signup()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
 requested_username text;
 requested_grade smallint;
begin
 requested_username := lower(coalesce(new.raw_user_meta_data->>'username',''));
 if requested_username !~ '^[a-z0-9_]{3,20}$' then
   raise exception 'Invalid username';
 end if;
 begin
   requested_grade := (new.raw_user_meta_data->>'grade')::smallint;
 exception when others then
   raise exception 'Invalid grade';
 end;
 if requested_grade not between 5 and 8 then raise exception 'Invalid grade'; end if;
 insert into public.turkce_profiles(id,username,grade)
 values(new.id,requested_username,requested_grade);
 insert into public.turkce_economy(user_id)
 values(new.id);
 return new;
end;
$$;
revoke all on function public.turkce_on_auth_signup() from public,anon,authenticated;
drop trigger if exists turkce_profile_after_auth_signup on auth.users;
create trigger turkce_profile_after_auth_signup after insert on auth.users
 for each row execute function public.turkce_on_auth_signup();

-- Online XP/gold/energy and reward events must only be written by
-- validated backend operations, not client-controlled requests.
