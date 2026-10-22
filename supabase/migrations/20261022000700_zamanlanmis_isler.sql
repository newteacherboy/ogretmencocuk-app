-- Diji Medu Türkçe veritabanı kurulumu: zamanlanmış işler (pg_cron)
-- Diji Medu Türkçe'daki 13 zamanlanmış işin aynısı. Proje adresi kurulumda isgnsmkboehygxxysria yerine yazılır.

select cron.schedule('diji_cron_kayit_temizligi', '0 1 * * *', $$delete from cron.job_run_details where end_time < now() - interval '7 days'$$);
select cron.schedule('diji-account-deletion-cleanup', '*/10 * * * *', $$select public.diji_deletion_tick()$$);
select cron.schedule('diji-security-rate-prune', '45 3 * * *', $$delete from public.dm_security_buckets where expires_at < now()-interval '1 day'$$);
select cron.schedule('diji-veri-temizligi', '15 3 * * *', $$select public.diji_veri_temizligi();$$);
select cron.schedule('dm_verified_runs_cleanup', '23 3 * * *', $$delete from public.dm_verified_runs where expires_at<now()-interval '2 days'$$);
select cron.schedule('dm-mail-league-snapshot', '55 * * * *', $$select public.dm_mail_capture_league();$$);
select cron.schedule('dm-papi-chat-retention', '17 * * * *', $$delete from public.dm_papi_chat_turns where created_at<now()-interval '48 hours';delete from public.dm_papi_chat_budget where day<current_date-3;$$);
select cron.schedule('dm-papi-league-monday', '0 9 * * 1', $$select public.dm_communication_mail_tick('monday_league_mail');$$);
select cron.schedule('dm-papi-league-sunday', '0 16 * * 0', $$select public.dm_communication_mail_tick('weekly_league_mail');$$);
select cron.schedule('dm-papi-progress-prepare', '5 5 * * *', $$select public.dm_communication_mail_tick('three_day_mail');$$);
select cron.schedule('dm-weekly-league-settlement', '5 21 * * 0', $$select public.dm_settle_weeks();$$);
select cron.schedule('dm-social-safety-retention', '37 * * * *', $$
 delete from public.dm_guardian_sessions where expires_at<now();
 delete from public.dm_guardian_challenges where expires_at<now()-interval '1 day';
 delete from public.dm_safety_reports where status in ('resolved','dismissed') and updated_at<now()-interval '90 days';
$$);
select cron.schedule('dm-papi-progress-dispatch', '* * * * *', $$
 select net.http_post(
  url := 'https://isgnsmkboehygxxysria.supabase.co/functions/v1/papi-progress-worker',
  headers := jsonb_build_object(
   'Content-Type','application/json',
   'x-papi-worker',(select secret from dm_private.dm_papi_worker_secret where key_name='mail_worker')
  ),
  body := '{}'::jsonb,
  timeout_milliseconds := 30000
 );
$$);
