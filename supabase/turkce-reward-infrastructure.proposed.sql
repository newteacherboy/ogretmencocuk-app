-- Diji-Medu Türkçe secure score transaction infrastructure.
-- ONLY for Supabase project isgnsmkboehygxxysria, AFTER checking existing schema.
-- This is a proposed follow-on migration and has NOT been executed.
-- Never expose reward tables to authenticated clients as writable relations.
create table if not exists public.turkce_question_keys (
 mode text not null check(mode in ('stop','game')),
 activity_id text not null,
 question_index smallint not null check(question_index between 0 and 50),
 answer jsonb not null,
 answer_kind text not null check(answer_kind in ('choice','order','ungraded_text')),
 primary key(mode,activity_id,question_index)
);
create table if not exists public.turkce_attempts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 mode text not null check(mode in ('stop','game')),
 activity_id text not null,
 next_question smallint not null default 0,
 correct_first smallint not null default 0,
 wrong_attempts smallint not null default 0,
 question_mistakes smallint not null default 0,
 started_at timestamptz not null default now(),
 last_action_at timestamptz not null default now(),
 finished_at timestamptz,
 constraint attempts_question_nonnegative check (next_question >= 0 and correct_first >= 0 and wrong_attempts >= 0)
);
create unique index if not exists turkce_one_open_attempt_per_activity on public.turkce_attempts(user_id,mode,activity_id) where finished_at is null;
create index if not exists turkce_attempts_owner on public.turkce_attempts(user_id,started_at desc);
create table if not exists public.turkce_reward_ledger (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 mode text not null check(mode in ('stop','game')),
 activity_id text not null,
 xp integer not null check(xp >= 0 and xp <= 140),
 gold integer not null check(gold >= 0 and gold <= 80),
 earned_at timestamptz not null default now(),
 reward_day date not null default ((now() at time zone 'Europe/Istanbul')::date)
);
create unique index if not exists turkce_stop_reward_once on public.turkce_reward_ledger(user_id,activity_id) where mode='stop';
create unique index if not exists turkce_game_reward_once_per_day on public.turkce_reward_ledger(user_id,activity_id,reward_day) where mode='game';

alter table public.turkce_question_keys enable row level security;
alter table public.turkce_attempts enable row level security;
alter table public.turkce_reward_ledger enable row level security;
revoke all on public.turkce_question_keys from public,anon,authenticated;
revoke all on public.turkce_attempts from public,anon,authenticated;
revoke all on public.turkce_reward_ledger from public,anon,authenticated;
grant select on public.turkce_attempts to authenticated;
grant select on public.turkce_reward_ledger to authenticated;
drop policy if exists turkce_own_attempts on public.turkce_attempts;
create policy turkce_own_attempts on public.turkce_attempts for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists turkce_own_rewards on public.turkce_reward_ledger;
create policy turkce_own_rewards on public.turkce_reward_ledger for select to authenticated using ((select auth.uid())=user_id);

-- Critical: No remote mutation RPC is present until question key catalog has been seeded,
-- reviewed, and server-side transaction procedures have passed concurrency tests.
-- A client-provided correct=true or xp amount must never be accepted.
