-- Diji Medu Türkçe veritabanı kurulumu: şemalar, eklentiler, tablolar
-- Diji Medu Türkçe şemasından (22 Ekim 2026) yapı olarak kopyalandı; öğrenci verisi içermez.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create schema if not exists dm_private;
revoke all on schema dm_private from public, anon, authenticated;
grant usage on schema dm_private to service_role;

create sequence if not exists public.activity_categories_id_seq;
create sequence if not exists public.assignments_id_seq;
create sequence if not exists public.badges_id_seq;
create sequence if not exists public.mail_queue_id_seq;
create sequence if not exists public.sentence_bank_id_seq;
create sequence if not exists public.speech_synonyms_id_seq;
create sequence if not exists public.word_cards_id_seq;

create table if not exists dm_private.dm_papi_worker_secret (
  key_name text not null,
  secret text not null
);

create table if not exists dm_private.papi_league_test_send (
  id integer not null,
  claimed_at timestamp with time zone default now() not null,
  result text
);

create table if not exists dm_private.papi_mascot_email_test (
  id integer not null,
  created_at timestamp with time zone default now()
);

create table if not exists dm_private.papi_official_mail_test (
  id integer not null,
  claimed_at timestamp with time zone default now()
);

create table if not exists public.activities (
  id uuid default gen_random_uuid() not null,
  code text not null,
  display_name text not null,
  category text,
  external_link text,
  teacher_comment text,
  active boolean default true not null,
  content jsonb default '{}'::jsonb not null
);

create table if not exists public.activity_categories (
  id bigint default nextval('activity_categories_id_seq'::regclass) not null,
  name text not null
);

create table if not exists public.announcement_reads (
  id uuid default gen_random_uuid() not null,
  announcement_id uuid not null,
  student_id uuid not null,
  seen_at timestamp with time zone default now() not null
);

create table if not exists public.announcements (
  id uuid default gen_random_uuid() not null,
  title text not null,
  message text not null,
  image_link text,
  target_type text default 'all'::text not null,
  target_list jsonb default '[]'::jsonb not null,
  display_limit integer,
  theme text,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  teacher_id uuid
);

create table if not exists public.annual_plans (
  id uuid default gen_random_uuid() not null,
  plan_code text not null,
  title text,
  total_weeks integer default 0 not null,
  plan_data jsonb default '[]'::jsonb not null,
  active boolean default true not null
);

create table if not exists public.assignment_status (
  assignment_id bigint not null,
  student_id uuid not null,
  done_at timestamp with time zone default now() not null,
  score integer,
  stars integer
);

create table if not exists public.assignments (
  id bigint default nextval('assignments_id_seq'::regclass) not null,
  teacher_id uuid,
  class_no integer not null,
  branch text default ''::text not null,
  kind text not null,
  title text not null,
  payload jsonb default '{}'::jsonb not null,
  due_date date,
  note text,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.audit_logs (
  id uuid default gen_random_uuid() not null,
  actor_role text,
  actor_id uuid,
  operation text,
  target text,
  payload jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.badges (
  id bigint default nextval('badges_id_seq'::regclass) not null,
  student_name text,
  name text not null,
  required_points numeric default 0,
  emoji text default '🏅'::text
);

create table if not exists public.chat_messages (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  sender_role text not null,
  message text not null,
  read_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.class_point_actions (
  id uuid default gen_random_uuid() not null,
  teacher_id uuid,
  student_ids jsonb not null,
  change_amount numeric(6,2) not null,
  reason text,
  action_at timestamp with time zone default now() not null,
  undone_at timestamp with time zone
);

create table if not exists public.diji_deletion_auth_queue (
  auth_user_id uuid not null,
  attempts integer default 0 not null,
  retry_at timestamp with time zone default now() not null
);

create table if not exists public.diji_deletion_rate (
  target_hash text not null,
  attempts integer not null,
  window_start timestamp with time zone not null
);

create table if not exists public.diji_deletion_receipts (
  token_hash text not null,
  result jsonb not null,
  expires_at timestamp with time zone default (now() + '1 day'::interval) not null
);

create table if not exists public.diji_deletion_tickets (
  token_hash text not null,
  account_id uuid not null,
  account_role text not null,
  password_hash_snapshot text not null,
  expires_at timestamp with time zone default (now() + '00:05:00'::interval) not null
);

create table if not exists public.diji_deletion_worker_settings (
  id boolean default true not null,
  worker_key text not null
);

create table if not exists public.dm_accessory_catalog (
  id text not null,
  name text not null,
  icon text not null,
  price integer not null
);

create table if not exists public.dm_accessory_gifts (
  id uuid default gen_random_uuid() not null,
  sender_id uuid,
  recipient_id uuid not null,
  item_id text not null,
  created_at timestamp with time zone default now()
);

create table if not exists public.dm_account_action_tickets (
  token_hash text not null,
  account_id uuid not null,
  account_role text not null,
  action text not null,
  password_hash_snapshot text not null,
  expires_at timestamp with time zone default (now() + '00:05:00'::interval) not null
);

create table if not exists public.dm_active_time (
  student_id uuid not null,
  seconds bigint default 0 not null,
  base_chest bigint default 0 not null,
  claimed bigint[] default '{}'::bigint[] not null,
  last_tick timestamp with time zone default now() not null,
  last_run text default ''::text not null,
  last_seq bigint default 0 not null
);

create table if not exists public.dm_break_chapters (
  game text not null,
  chapter integer not null,
  title text not null,
  theme text not null,
  goal integer not null
);

create table if not exists public.dm_break_checkpoints (
  run_id uuid not null,
  chapter integer not null,
  score integer not null,
  seconds integer not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_break_progress (
  student_id uuid not null,
  game text not null,
  unlocked_chapter integer default 1 not null,
  completed_all boolean default false not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_break_runs (
  id uuid not null,
  student_id uuid not null,
  game text not null,
  day text not null,
  score integer default 0 not null,
  gold integer default 0 not null,
  status text default 'playing'::text not null,
  created_at timestamp with time zone default now() not null,
  finished_at timestamp with time zone,
  start_chapter integer default 1 not null,
  chapter integer default 1 not null,
  highest_chapter integer default 1 not null,
  chapter_start_score integer default 0 not null,
  checkpoint_score integer default 0 not null,
  checkpoint_seconds integer default 0 not null,
  completed_all boolean default false not null
);

create table if not exists public.dm_communication_rules (
  key text not null,
  category text not null,
  title text not null,
  enabled boolean default true not null,
  settings jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_email_category_policy (
  kind text not null,
  category text not null,
  requires_verified_subscription boolean not null,
  description text not null
);

create table if not exists public.dm_email_verifications (
  token_hash text not null,
  student_id uuid not null,
  email text not null,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone default (now() + '24:00:00'::interval) not null,
  consumed_at timestamp with time zone
);

create table if not exists public.dm_energy_shop_purchases (
  student_id uuid not null,
  request_key text not null,
  energy_amount integer not null,
  gold_price integer not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_entitlements (
  account_id uuid not null,
  account_role text not null,
  product_key text not null,
  provider text not null,
  transaction_id uuid not null,
  state text not null,
  valid_until timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_feed_awards (
  student_id uuid not null,
  event_key text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_game_reward_runs (
  student_id uuid not null,
  run_id text not null,
  game_key text not null,
  class_no integer not null,
  units integer[] not null,
  xp integer not null,
  gold integer not null,
  created_at timestamp with time zone default now() not null,
  topic_key text
);

create table if not exists public.dm_guardian_challenges (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  token_hash text not null,
  email text not null,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone default (now() + '01:00:00'::interval) not null,
  used_at timestamp with time zone
);

create table if not exists public.dm_guardian_sessions (
  token_hash text not null,
  student_id uuid not null,
  pin_snapshot text not null,
  expires_at timestamp with time zone default (now() + '00:10:00'::interval) not null
);

create table if not exists public.dm_guest_previews (
  device_hash text not null,
  started_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone default (now() + '00:10:00'::interval) not null,
  used_features jsonb default '{}'::jsonb not null
);

create table if not exists public.dm_league_weeks (
  week_start date not null,
  settled_at timestamp with time zone
);

create table if not exists public.dm_lesson_fair_best (
  student_id uuid not null,
  level text not null,
  category text not null,
  topic_name text not null,
  best_tier integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_lesson_fair_runs (
  student_id uuid not null,
  run_id text not null,
  level text not null,
  category text not null,
  topic_name text not null,
  first_correct integer not null,
  question_count integer not null,
  wrong_indices jsonb default '[]'::jsonb not null,
  passed boolean default false not null,
  recovered boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_mail_budget (
  day date not null,
  attempts integer default 0 not null
);

create table if not exists public.dm_mail_league_snapshots (
  captured_at timestamp with time zone default now() not null,
  week_start date not null,
  board jsonb not null
);

create table if not exists public.dm_matches (
  id uuid default gen_random_uuid() not null,
  player_a uuid not null,
  player_b uuid not null,
  game text not null,
  mode text not null,
  status text default 'waiting'::text not null,
  class_no integer not null,
  questions jsonb not null,
  ready_a boolean default false,
  ready_b boolean default false,
  start_a timestamp with time zone,
  start_b timestamp with time zone,
  answers_a jsonb default '{}'::jsonb not null,
  answers_b jsonb default '{}'::jsonb not null,
  result_a jsonb,
  result_b jsonb,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone default (now() + '24:00:00'::interval) not null
);

create table if not exists public.dm_oral_questions (
  id uuid not null,
  teacher_id uuid,
  student_id uuid not null,
  class_no integer not null,
  unit_no integer not null,
  word_key text not null,
  english text not null,
  turkish text not null,
  status text default 'pending'::text not null,
  xp integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  graded_at timestamp with time zone,
  expires_at timestamp with time zone default (clock_timestamp() + '00:00:15'::interval),
  timed_out boolean default false not null
);

create table if not exists public.dm_papi_chat_budget (
  day date not null,
  blocked boolean default false not null
);

create table if not exists public.dm_papi_chat_turns (
  student_id uuid not null,
  request_id uuid not null,
  request_hash text not null,
  personal_day date default ((now() AT TIME ZONE 'Europe/Istanbul'::text))::date not null,
  global_day date default ((now() AT TIME ZONE 'UTC'::text))::date not null,
  topic text not null,
  input_text text not null,
  state text default 'pending'::text not null,
  result jsonb,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_papi_mail_confirmations (
  token_hash text not null,
  student_id uuid not null,
  recipient_kind text not null,
  email text not null,
  expires_at timestamp with time zone default (now() + '48:00:00'::interval) not null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_papi_progress_outbox (
  id bigint generated always as identity not null,
  student_id uuid not null,
  recipient_kind text not null,
  to_email text not null,
  subject text not null,
  html text not null,
  text_body text,
  kind text default 'papi_progress'::text not null,
  report_date date not null,
  send_after timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  sent_at timestamp with time zone,
  claimed_at timestamp with time zone,
  attempts integer default 0 not null,
  error text
);

create table if not exists public.dm_papi_unsubscribe_tokens (
  token_hash text not null,
  student_id uuid not null,
  email text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_parkur_question_ledger (
  student_id uuid not null,
  run_id text not null,
  question_no integer not null,
  answered boolean default false not null,
  correct boolean,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_parkur_recovery_runs (
  student_id uuid not null,
  run_id text not null,
  stop_no integer not null,
  class_no integer not null,
  deck jsonb not null,
  step integer default 0 not null,
  mistakes integer default 0 not null,
  completed boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_password_resets (
  id bigint generated always as identity not null,
  student_id uuid not null,
  token_hash text not null,
  expires_at timestamp with time zone not null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_payment_events (
  provider text not null,
  event_id text not null,
  received_at timestamp with time zone default now() not null,
  processed_at timestamp with time zone
);

create table if not exists public.dm_payment_transactions (
  id uuid default gen_random_uuid() not null,
  account_id uuid,
  account_role text not null,
  provider text not null,
  provider_transaction_id text not null,
  product_key text not null,
  state text not null,
  amount_minor bigint,
  currency text,
  verified_at timestamp with time zone,
  valid_until timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_progress_baseline (
  student_id uuid not null,
  stops jsonb not null
);

create table if not exists public.dm_progress_items (
  id text not null,
  minimum_level integer not null,
  price integer not null,
  owned_keys jsonb not null,
  style jsonb not null
);

create table if not exists public.dm_progress_mail_preferences (
  student_id uuid not null,
  recipient_kind text not null,
  email text not null,
  opted_in_at timestamp with time zone,
  consent_source text,
  verified_at timestamp with time zone,
  unsubscribed_at timestamp with time zone,
  unsubscribe_token_hash text not null,
  last_queued_at timestamp with time zone,
  last_sent_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_progress_rewards (
  student_id uuid not null,
  kind text not null,
  reward_key text not null,
  gold integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_rally_runs (
  id uuid not null,
  student_id uuid not null,
  class_no integer not null,
  units integer[] not null,
  difficulty text not null,
  deck jsonb not null,
  state jsonb default '{"combo": 0, "index": 0, "score": 0, "wrong": 0, "hearts": 2, "answers": [], "correct": 0, "elapsed": 0, "bestCombo": 0}'::jsonb not null,
  status text default 'playing'::text not null,
  reward jsonb,
  created_at timestamp with time zone default now() not null,
  round_at timestamp with time zone default now() not null,
  finished_at timestamp with time zone
);

create table if not exists public.dm_release_flags (
  code text not null,
  enabled boolean default true not null,
  updated_at timestamp with time zone default now() not null,
  updated_by uuid
);

create table if not exists public.dm_route_graduations (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  route text not null,
  level text not null,
  snapshot jsonb not null,
  issued_at timestamp with time zone default now() not null,
  notified_at timestamp with time zone
);

create table if not exists public.dm_route_mission_completions (
  student_id uuid not null,
  chapter integer not null,
  completed_at timestamp with time zone default now() not null
);

create table if not exists public.dm_safety_reports (
  id uuid default gen_random_uuid() not null,
  reporter_id uuid not null,
  target_id uuid not null,
  request_id uuid not null,
  kind text not null,
  item_id uuid,
  reason text not null,
  note text default ''::text not null,
  snapshot jsonb default '{}'::jsonb not null,
  status text default 'new'::text not null,
  reviewed_by uuid,
  review_note text default ''::text not null,
  action text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_safety_review_log (
  id uuid default gen_random_uuid() not null,
  report_id uuid not null,
  admin_id uuid,
  action text not null,
  note text default ''::text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_security_buckets (
  bucket_key text not null,
  hits integer default 0 not null,
  window_start timestamp with time zone default now() not null,
  expires_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_security_settings (
  key text not null,
  value boolean not null
);

create table if not exists public.dm_social_controls (
  student_id uuid not null,
  guardian_email text,
  pin_hash text,
  verified_at timestamp with time zone,
  social_enabled boolean default true not null,
  profile_visible boolean default true not null,
  messages_enabled boolean default true not null,
  duels_enabled boolean default true not null,
  gifts_enabled boolean default true not null,
  suspended_until timestamp with time zone,
  notice_seen_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_teacher_student_notices (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  teacher_id uuid,
  kind text not null,
  message text not null,
  created_at timestamp with time zone default now() not null,
  acknowledged_at timestamp with time zone,
  report_id uuid,
  appeal_allowed boolean default true not null,
  appealed_at timestamp with time zone,
  appeal_message text,
  appeal_reviewed_at timestamp with time zone
);

create table if not exists public.dm_thematic_enrollment (
  actor_key text not null,
  student_id uuid,
  teacher_id uuid,
  inherited_count integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_thematic_first_answers (
  actor_key text not null,
  chapter integer not null,
  question_cursor integer not null,
  first_correct boolean not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dm_thematic_recovery (
  actor_key text not null,
  chapter integer not null,
  step integer default 0 not null,
  errors integer default 0 not null,
  completed boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dm_topic_game_runs (
  run_id uuid not null,
  student_id uuid not null,
  topic_key text not null,
  game text not null,
  answer_key jsonb not null,
  question_count integer not null,
  started_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone default (now() + '00:30:00'::interval) not null
);

create table if not exists public.dm_verified_runs (
  student_id uuid not null,
  run_id text not null,
  game text not null,
  class_no integer not null,
  units integer[] not null,
  stop_no integer default 0 not null,
  deck jsonb not null,
  answers jsonb default '{}'::jsonb not null,
  events jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default clock_timestamp() not null,
  expires_at timestamp with time zone default (clock_timestamp() + '24:00:00'::interval) not null
);

create table if not exists public.dm_weekly_results (
  student_id uuid not null,
  week_start date not null,
  rank_no integer not null,
  league text not null,
  xp numeric not null,
  active_days integer not null,
  gold integer default 0 not null,
  energy integer default 0 not null,
  summary jsonb not null,
  awarded_at timestamp with time zone,
  shown_at timestamp with time zone
);

create table if not exists public.dm_weekly_xp (
  student_id uuid not null,
  week_start date not null,
  xp numeric default 0 not null,
  active_days integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.duels (
  id uuid default gen_random_uuid() not null,
  sender_student_id uuid,
  receiver_student_id uuid,
  status text default 'pending'::text not null,
  sender_payload jsonb default '{}'::jsonb not null,
  receiver_payload jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  responded_at timestamp with time zone
);

create table if not exists public.energy_transactions (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  change_amount integer not null,
  balance_after integer not null,
  reason text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.extra_data (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  key_name text not null,
  value jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.feature_flags (
  id uuid default gen_random_uuid() not null,
  code text not null,
  name text,
  target_type text default 'tumogrenciler'::text not null,
  target_value text,
  enabled boolean default false not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.feed_events (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  event_type text not null,
  target_student_id uuid,
  payload jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  safety_hidden boolean default false not null
);

create table if not exists public.feed_reactions (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  student_id uuid not null,
  reaction text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.follow_edges (
  id uuid default gen_random_uuid() not null,
  follower_student_id uuid not null,
  following_student_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.game_scores (
  id uuid default gen_random_uuid() not null,
  game_key text not null,
  student_id uuid,
  student_name text not null,
  class_no integer,
  unit_no integer,
  unit_name text,
  score numeric default 0 not null,
  correct_count integer default 0 not null,
  wrong_count integer default 0 not null,
  duration_seconds integer default 0 not null,
  detail text,
  played_on date default CURRENT_DATE not null,
  created_at timestamp with time zone default now() not null,
  extra jsonb default '{}'::jsonb not null
);

create table if not exists public.legacy_import_rows (
  id uuid default gen_random_uuid() not null,
  sheet_name text not null,
  source_row_no integer not null,
  source_headers jsonb not null,
  source_row jsonb not null,
  imported_at timestamp with time zone default now() not null
);

create table if not exists public.legacy_unmapped_rows (
  id uuid default gen_random_uuid() not null,
  sheet_name text not null,
  source_row integer not null,
  source_row_data jsonb not null,
  created_at timestamp with time zone default now()
);

create table if not exists public.lesson_progress (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  level text,
  category text,
  topic_name text,
  knew_it boolean,
  test_success boolean,
  completed_at timestamp with time zone default now() not null,
  extra jsonb default '{}'::jsonb not null
);

create table if not exists public.lesson_topics (
  id uuid default gen_random_uuid() not null,
  level text not null,
  category text not null,
  topic_name text not null,
  sort_no integer default 0 not null,
  content jsonb default '{}'::jsonb not null,
  active boolean default true not null
);

create table if not exists public.level_completions (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  mode text not null,
  class_no integer,
  unit_no integer,
  level_no integer not null,
  completed_at timestamp with time zone default now() not null
);

create table if not exists public.mail_queue (
  id bigint default nextval('mail_queue_id_seq'::regclass) not null,
  student_id uuid,
  to_email text not null,
  subject text not null,
  html text,
  text_body text,
  kind text default 'bilgi'::text not null,
  report_date date,
  send_after timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  sent_at timestamp with time zone,
  attempts integer default 0,
  error text,
  priority integer default 0 not null
);

create table if not exists public.notifications (
  id uuid default gen_random_uuid() not null,
  recipient_student_id uuid,
  sender_student_id uuid,
  type text,
  title text,
  message text,
  payload jsonb default '{}'::jsonb not null,
  read_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.papi_card_results (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  teacher_id uuid,
  owner_key text not null,
  run_id uuid not null,
  display_name text not null,
  class_no integer not null,
  unit_no integer not null,
  total integer not null,
  known_count integer not null,
  review_count integer not null,
  score integer not null,
  duration_seconds integer not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.papi_meteor_sessions (
  id uuid default gen_random_uuid() not null,
  actor_key text not null,
  student_id uuid,
  teacher_id uuid,
  class_no integer not null,
  unit_no integer not null,
  mode integer not null,
  status text default 'playing'::text not null,
  deck jsonb not null,
  state jsonb not null,
  version integer default 0 not null,
  best_score integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.papi_story_progress (
  actor_key text not null,
  student_id uuid,
  teacher_id uuid,
  chapter integer not null,
  cursor integer default 0 not null,
  completed boolean default false not null,
  version integer default 0 not null,
  mistakes integer default 0 not null,
  writing text default ''::text not null,
  updated_at timestamp with time zone default now() not null,
  replay boolean default false not null,
  reward_claimed boolean default false not null,
  questions_seen integer default 0 not null,
  charged_cursor integer default '-1'::integer not null,
  last_reward jsonb default '{}'::jsonb not null,
  deck_version smallint default 1 not null,
  attempt_cursor integer default '-1'::integer not null,
  attempt_count integer default 0 not null,
  review_cards jsonb default '[]'::jsonb not null,
  route_combo integer default 0 not null
);

create table if not exists public.papi_wheel_sessions (
  id uuid default gen_random_uuid() not null,
  actor_key text not null,
  student_id uuid,
  teacher_id uuid,
  class_no integer not null,
  unit_no integer not null,
  mode integer not null,
  status text default 'playing'::text not null,
  deck jsonb not null,
  state jsonb not null,
  version integer default 0 not null,
  best_score integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.points_transactions (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  change_amount numeric(6,2) not null,
  balance_after numeric(6,2) not null,
  reason text,
  unique_key text,
  created_at timestamp with time zone default now() not null,
  auto_key text
);

create table if not exists public.portal_sessions (
  id uuid default gen_random_uuid() not null,
  token_hash text not null,
  student_id uuid,
  teacher_id uuid,
  role text not null,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone not null,
  last_seen_at timestamp with time zone default now() not null
);

create table if not exists public.reading_results (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  class_label text,
  words_read integer default 0 not null,
  duration_seconds integer default 0 not null,
  wpm numeric default 0 not null,
  text_title text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.sentence_bank (
  id bigint default nextval('sentence_bank_id_seq'::regclass) not null,
  class_no integer not null,
  unit_no integer not null,
  turkish text not null,
  english text not null,
  alternatives text default ''::text,
  distractors text default ''::text,
  active boolean default true,
  created_at timestamp with time zone default now()
);

create table if not exists public.speech_synonyms (
  id bigint default nextval('speech_synonyms_id_seq'::regclass) not null,
  english text not null,
  turkish text,
  alternatives text not null
);

create table if not exists public.student_activities (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  activity_id uuid,
  assigned_by uuid,
  status text default 'assigned'::text not null,
  assigned_at timestamp with time zone default now() not null,
  completed_at timestamp with time zone,
  result jsonb default '{}'::jsonb not null
);

create table if not exists public.student_blocks (
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.student_google_accounts (
  auth_user_id uuid not null,
  student_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.student_plan_progress (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  plan_id uuid not null,
  week_no integer not null,
  completed boolean default false not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.student_videos (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  video_id uuid not null,
  watched_at timestamp with time zone,
  assigned_at timestamp with time zone default now() not null
);

create table if not exists public.student_xp_weekly (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  student_name text not null,
  week_code text not null,
  total_xp numeric default 0 not null,
  week_xp numeric default 0 not null,
  previous_week_xp numeric default 0 not null,
  gold numeric default 0 not null,
  freeze_count integer default 0 not null,
  unlocked_character_count integer default 0 not null,
  source_updated_at timestamp with time zone,
  imported_at timestamp with time zone default now() not null
);

create table if not exists public.students (
  id uuid default gen_random_uuid() not null,
  username text not null,
  password_hash text not null,
  phone text,
  class_no integer,
  branch text,
  email text,
  status text default 'pending'::text not null,
  role text default 'student'::text not null,
  kvkk_approved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  last_login_at timestamp with time zone,
  selected_class integer,
  total_seconds integer default 0 not null,
  energy integer default 30 not null,
  energy_max integer default 30 not null,
  streak integer default 0 not null,
  points numeric(6,2) default 0 not null,
  gold numeric default 0 not null,
  xp numeric default 0 not null,
  profile jsonb default '{}'::jsonb not null,
  energy_updated_at timestamp with time zone default now(),
  teacher_id uuid,
  email_verification_required boolean default false not null,
  email_verified_at timestamp with time zone,
  full_name text,
  school text,
  contact_deadline timestamp with time zone,
  contact_notice_day date,
  frozen_at timestamp with time zone
);

create table if not exists public.teacher_reports (
  id uuid default gen_random_uuid() not null,
  student_id uuid,
  report_date date default CURRENT_DATE not null,
  reading_score numeric,
  writing_score numeric,
  vocabulary_score numeric,
  speaking_score numeric,
  grammar_score numeric,
  genel_score numeric(5,1),
  exam_score numeric(5,1),
  teacher_id uuid,
  next_report_date date,
  book_name text,
  page_no integer default 0,
  target numeric default 40,
  read_count integer default 0,
  last_attempt boolean default false,
  homework_feedback text,
  next_homework text
);

create table if not exists public.teachers (
  id uuid default gen_random_uuid() not null,
  username text not null,
  password_hash text not null,
  display_name text default 'Diji Medu Türkçe'::text not null,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  last_login_at timestamp with time zone,
  email text,
  full_name text,
  school text,
  invite_code text,
  is_admin boolean default false not null,
  game_data jsonb,
  game_data_at timestamp with time zone,
  phone text,
  frozen_at timestamp with time zone
);

create table if not exists public.videos (
  id uuid default gen_random_uuid() not null,
  external_row_index integer,
  title text,
  category text,
  url text,
  description text,
  active boolean default true not null,
  content jsonb default '{}'::jsonb not null
);

create table if not exists public.word_bank (
  id uuid default gen_random_uuid() not null,
  class_no integer not null,
  unit_no integer not null,
  english text not null,
  turkish text not null,
  extra jsonb default '{}'::jsonb,
  active boolean default true
);

create table if not exists public.word_cards (
  id bigint default nextval('word_cards_id_seq'::regclass) not null,
  class_no integer not null,
  unit_no integer not null,
  level_no integer not null,
  button_name text default ''::text,
  external_link text not null
);

alter sequence public.assignments_id_seq owned by public.assignments.id;
alter sequence public.word_cards_id_seq owned by public.word_cards.id;
alter sequence public.badges_id_seq owned by public.badges.id;
alter sequence public.speech_synonyms_id_seq owned by public.speech_synonyms.id;
alter sequence public.activity_categories_id_seq owned by public.activity_categories.id;
alter sequence public.mail_queue_id_seq owned by public.mail_queue.id;
alter sequence public.sentence_bank_id_seq owned by public.sentence_bank.id;
