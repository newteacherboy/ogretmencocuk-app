-- Diji Medu Türkçe veritabanı kurulumu: fonksiyonlar
-- Diji Medu Türkçe şemasından (22 Ekim 2026) yapı olarak kopyalandı; öğrenci verisi içermez.

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION dm_private.parkur_xp_seed()
 RETURNS TABLE(student_id uuid, seed_xp integer, completed_stops jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 with words as (
   select w.class_no,w.unit_no,
     row_number() over(order by w.class_no,w.unit_no,w.english,w.id) rn,
     count(*) over(partition by w.class_no,w.unit_no) unit_words
   from public.word_bank w
   where w.active and w.class_no between 1 and 8 and w.unit_no>0
     and coalesce(w.english,'')<>'' and coalesce(w.turkish,'')<>''
 ), units as (
   select distinct class_no,unit_no,1000+class_no*100+unit_no stop_no from words
 ), completions as (
   select distinct c.student_id,c.level_no,
     case when coalesce(e.value#>>array['baYildiz',c.level_no::text],'') ~ '^[0-9]+$'
       then least(3,greatest(1,(e.value#>>array['baYildiz',c.level_no::text])::numeric))::integer
       else 1 end stars
   from public.level_completions c
   left join public.extra_data e on e.student_id=c.student_id and e.key_name='yo'
   where c.mode='buyu'
 ), old_units as (
   select c.student_id,1000+w.class_no*100+w.unit_no stop_no,max(c.stars) stars
   from completions c join words w on c.level_no=(w.rn-1)/8+1
   where c.level_no between 1 and 999
   group by c.student_id,w.class_no,w.unit_no
   having count(distinct w.rn)>=max(w.unit_words)::numeric/2
 ), candidate_stops as (
   select c.student_id,u.stop_no,c.stars from completions c join units u on u.stop_no=c.level_no
   union all select student_id,stop_no,stars from old_units
 ), stops as (
   select student_id,stop_no,max(stars) stars from candidate_stops group by student_id,stop_no
 ), totals as (
   select student_id,sum(case stars when 3 then 60 when 2 then 48 else 42 end)::integer seed_xp,
     jsonb_agg(jsonb_build_object('stop',stop_no,'stars',stars,'xp',case stars when 3 then 60 when 2 then 48 else 42 end) order by stop_no) completed_stops
   from stops group by student_id
 )
 select s.id,coalesce(t.seed_xp,0),coalesce(t.completed_stops,'[]'::jsonb)
 from public.students s left join totals t on t.student_id=s.id where s.role='student';
$function$
;

CREATE OR REPLACE FUNCTION public.admin_student_update(p_actor uuid, p_student uuid, p_expected timestamp with time zone, p_changes jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare s public.students; v text; credential_change boolean;
begin
 if not exists(select 1 from public.teachers where id=p_actor and active and is_admin and username='teacher') then
   raise exception 'Owner only' using errcode='42501';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(7783912);
 select * into s from public.students where id=p_student and role='student' for update;
 if not found then raise exception 'Student not found' using errcode='P0002'; end if;
 if s.updated_at is distinct from p_expected then raise exception 'Stale update' using errcode='40001'; end if;
 v:=trim(p_changes->>'username');
 if length(v) not between 3 and 50 or v ~ '[<>[:cntrl:]]' or
    coalesce((p_changes->>'class_no')::int,0) not between 1 and 8 or
    coalesce(length(trim(p_changes->>'branch')),0) not between 1 and 10 or
    (coalesce(p_changes->>'school','')<>'' and length(p_changes->>'school') not between 3 and 120) then
   raise exception 'Invalid fields' using errcode='22023';
 end if;
 if exists(select 1 from public.students where lower(username)=lower(v) and id<>s.id) or
    exists(select 1 from public.teachers where lower(username)=lower(v)) then
   raise exception 'Username already used' using errcode='23505';
 end if;
 if p_changes ? 'password_hash' and not (p_changes->>'password_hash' like 'pbkdf2$210000$%') then
   raise exception 'Invalid password hash' using errcode='22023';
 end if;
 credential_change := s.username<>v or p_changes ? 'password_hash';
 update public.students set username=v,school=nullif(p_changes->>'school',''),
   class_no=(p_changes->>'class_no')::int,selected_class=(p_changes->>'class_no')::int,
   branch=trim(p_changes->>'branch'),password_hash=coalesce(p_changes->>'password_hash',password_hash),updated_at=clock_timestamp()
 where id=s.id;
 if s.username<>v then
   update public.game_scores set student_name=v where student_id=s.id;
   update public.student_xp_weekly set student_name=v where student_id=s.id;
   update public.badges set student_name=v where student_name=s.username;
 end if;
 if credential_change then delete from public.portal_sessions where student_id=s.id; end if;
 insert into public.audit_logs(actor_role,actor_id,operation,target,payload)
 values('teacher',p_actor,'admin_student_update',s.id::text,jsonb_build_object('fields',jsonb_build_array('username','school','class_no','branch'),'password_changed',p_changes ? 'password_hash'));
 return (select jsonb_build_object('id',id,'username',username,'school',school,'class_no',class_no,'branch',branch,'status',status,'updated_at',updated_at)
   from public.students where id=s.id);
end $function$
;

CREATE OR REPLACE FUNCTION public.diji_delete_account(p_ticket_hash text, p_confirmation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  ticket public.diji_deletion_tickets%rowtype;
  account_name text; stored_hash text; account_email text; admin_account boolean;
  google_id uuid; needles text[]; active_admins integer; result jsonb;
begin
  if p_confirmation is distinct from 'HESABIMI SİL' then raise exception 'confirmation_required'; end if;
  select * into ticket from public.diji_deletion_tickets
    where token_hash=p_ticket_hash for update;
  if not found then
    select r.result into result from public.diji_deletion_receipts r
      where token_hash=p_ticket_hash and expires_at>now();
    if result is not null then return result; end if;
    raise exception 'ticket_expired';
  end if;
  if ticket.expires_at <= now() then raise exception 'ticket_expired'; end if;
  -- Serialize last-admin checks, including simultaneous self-deletions.
  if ticket.account_role='teacher' then
    perform pg_advisory_xact_lock(874205311);
    perform 1 from public.teachers where is_admin and active order by id for update;
    select username,password_hash,email,is_admin into account_name,stored_hash,account_email,admin_account
      from public.teachers where id=ticket.account_id for update;
  else
    select username,password_hash,email into account_name,stored_hash,account_email
      from public.students where id=ticket.account_id for update;
  end if;
  if account_name is null then raise exception 'account_missing'; end if;
  if stored_hash is distinct from ticket.password_hash_snapshot then raise exception 'reauth_required'; end if;
  needles := array[account_name,ticket.account_id::text];
  if ticket.account_role='teacher' and admin_account then
    select count(*) into active_admins from public.teachers
      where is_admin and active and id<>ticket.account_id;
    if active_admins=0 then raise exception 'last_admin'; end if;
  end if;

  delete from public.audit_logs where actor_id=ticket.account_id
    or target in (ticket.account_id::text,account_name,lower(account_name),lower(translate(account_name,'İI','iı')));
  update public.audit_logs set payload=public.diji_deletion_redact(payload,needles)
    where public.diji_deletion_redact(payload,needles) is distinct from payload;
  if ticket.account_role='student' then
    -- CASCADE alone leaves old score names and SET NULL references behind.
    delete from public.game_scores where student_id=ticket.account_id
      or (student_id is null and lower(btrim(student_name))=lower(btrim(account_name)));
    delete from public.badges where lower(btrim(student_name))=lower(btrim(account_name));
    delete from public.notifications where sender_student_id=ticket.account_id or recipient_student_id=ticket.account_id;
    delete from public.feed_events where target_student_id=ticket.account_id;
    update public.feed_events set payload=public.diji_deletion_redact(payload,needles)
      where student_id<>ticket.account_id and public.diji_deletion_redact(payload,needles) is distinct from payload;
    update public.notifications set payload=public.diji_deletion_redact(payload,needles)
      where public.diji_deletion_redact(payload,needles) is distinct from payload;
    delete from public.assignment_status where student_id=ticket.account_id;
    delete from public.mail_queue where student_id=ticket.account_id;
    delete from public.feature_flags where target_type='ogrenci'
      and lower(btrim(target_value))=lower(btrim(account_name));
    delete from public.legacy_import_rows where exists (
      select 1 from jsonb_each_text(case when jsonb_typeof(source_row)='object' then source_row else '{}'::jsonb end) a
      where translate(lower(a.key),'öğüşıç','ogusic') in ('ogrenci','ogrenciadi','ogrenci adi','student_id')
        and (lower(btrim(a.value))=lower(btrim(account_name)) or a.value=ticket.account_id::text)
    );
    delete from public.legacy_unmapped_rows where exists (
      select 1 from jsonb_each_text(case when jsonb_typeof(source_row_data)='object' then source_row_data else '{}'::jsonb end) a
      where translate(lower(a.key),'öğüşıç','ogusic') in ('ogrenci','ogrenciadi','ogrenci adi','student_id')
        and (lower(btrim(a.value))=lower(btrim(account_name)) or a.value=ticket.account_id::text)
    );
    update public.class_point_actions set student_ids=student_ids-ticket.account_id::text-account_name
      where student_ids ? ticket.account_id::text or student_ids ? account_name;
    update public.announcements set target_list=target_list-account_name-ticket.account_id::text
      where jsonb_typeof(target_list)='array' and (target_list ? account_name or target_list ? ticket.account_id::text);
    update public.extra_data set value=public.diji_deletion_redact(value,needles)
      where student_id<>ticket.account_id
        and public.diji_deletion_redact(value,needles) is distinct from value;
    if to_regclass('public.student_google_accounts') is not null then
      execute 'select auth_user_id from public.student_google_accounts where student_id=$1'
        into google_id using ticket.account_id;
      if google_id is not null then
        insert into public.diji_deletion_auth_queue(auth_user_id) values(google_id) on conflict do nothing;
      end if;
    end if;
    -- All FK-linked progress, sessions, duels, follows, reports and own feed rows cascade.
    delete from public.students where id=ticket.account_id;
  else
    -- Shared learning content and students survive deletion of their teacher.
    if not exists(select 1 from public.students where lower(btrim(username))=lower(btrim(account_name))) then
      delete from public.game_scores where student_id is null and lower(btrim(student_name))=lower(btrim(account_name));
      delete from public.badges where lower(btrim(student_name))=lower(btrim(account_name));
    end if;
    update public.students set teacher_id=null where teacher_id=ticket.account_id;
    update public.assignments set teacher_id=null where teacher_id=ticket.account_id;
    update public.announcements set teacher_id=null where teacher_id=ticket.account_id;
    update public.teacher_reports set teacher_id=null where teacher_id=ticket.account_id;
    delete from public.mail_queue where account_email is not null and account_email<>'' and to_email=account_email;
    delete from public.teachers where id=ticket.account_id;
  end if;
  delete from public.diji_deletion_tickets where account_id=ticket.account_id and account_role=ticket.account_role;
  result:=jsonb_build_object('ok',true,'google_cleanup_pending',google_id is not null);
  insert into public.diji_deletion_receipts(token_hash,result) values(p_ticket_hash,result);
  return result;
end $function$
;

CREATE OR REPLACE FUNCTION public.diji_deletion_claim_auth(p_limit integer DEFAULT 10)
 RETURNS TABLE(auth_user_id uuid)
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  update public.diji_deletion_auth_queue q set attempts=q.attempts+1,retry_at=now()+interval '10 minutes'
  where q.auth_user_id in (
    select a.auth_user_id from public.diji_deletion_auth_queue a where a.retry_at<=now()
    order by a.retry_at for update skip locked limit least(greatest(p_limit,1),20)
  ) returning q.auth_user_id;
$function$
;

CREATE OR REPLACE FUNCTION public.diji_deletion_rate_allow(p_target_hash text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare n integer;
begin
  insert into public.diji_deletion_rate as r(target_hash,attempts,window_start)
  values (p_target_hash,1,now())
  on conflict (target_hash) do update set
    attempts = case when r.window_start < now()-interval '15 minutes' then 1 else r.attempts+1 end,
    window_start = case when r.window_start < now()-interval '15 minutes' then now() else r.window_start end
  returning attempts into n;
  return n <= 5;
end $function$
;

CREATE OR REPLACE FUNCTION public.diji_deletion_redact(v jsonb, needles text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare result jsonb; item record;
begin
  if v is null then return null; end if;
  case jsonb_typeof(v)
  when 'string' then
    if v #>> '{}' = any(needles) then return '"Silinen hesap"'::jsonb; end if;
    return v;
  when 'array' then
    select coalesce(jsonb_agg(public.diji_deletion_redact(value,needles) order by ord),'[]'::jsonb)
      into result from jsonb_array_elements(v) with ordinality as a(value,ord);
    return result;
  when 'object' then
    result := '{}'::jsonb;
    for item in select key,value from jsonb_each(v) loop
      if not (item.key = any(needles)) then
        result := result || jsonb_build_object(item.key,public.diji_deletion_redact(item.value,needles));
      end if;
    end loop;
    return result;
  else return v;
  end case;
end $function$
;

CREATE OR REPLACE FUNCTION public.diji_deletion_tick()
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare key_value text; request_id bigint;
begin
  delete from public.diji_deletion_tickets where expires_at<now();
  delete from public.diji_deletion_rate where window_start<now()-interval '30 minutes';
  delete from public.diji_deletion_receipts where expires_at<now();
  if not exists(select 1 from public.diji_deletion_auth_queue where retry_at<=now()) then return null; end if;
  select worker_key into key_value from public.diji_deletion_worker_settings where id;
  select net.http_post(
    url:='https://isgnsmkboehygxxysria.supabase.co/functions/v1/account-delete',
    headers:=jsonb_build_object('Content-Type','application/json','x-diji-delete-worker',key_value),
    body:='{"operation":"cleanup"}'::jsonb,timeout_milliseconds:=10000
  ) into request_id;
  return request_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.diji_veri_temizligi()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin

    -- =====================================================
    -- AKIŞ
    -- Reaksiyonlar, bağlı oldukları akış olaylarından önce silinir.
    -- Akış olayları: 10 gün
    -- =====================================================

    delete from public.feed_reactions
    where event_id in (
        select id
        from public.feed_events
        where created_at < now() - interval '10 days'
    );

    delete from public.feed_events
    where created_at < now() - interval '10 days';


    -- =====================================================
    -- BİLDİRİMLER: 7 gün
    -- =====================================================

    delete from public.notifications
    where created_at < now() - interval '7 days';


    -- =====================================================
    -- ENERJİ HAREKETLERİ: 30 gün
    -- =====================================================

    delete from public.energy_transactions
    where created_at < now() - interval '30 days';


    -- =====================================================
    -- OYUN SKORLARI: 30 gün
    -- =====================================================

    delete from public.game_scores
    where created_at < now() - interval '30 days';


    -- =====================================================
    -- DÜELLOLAR: 10 gün
    -- =====================================================

    delete from public.duels
    where created_at < now() - interval '10 days';


    -- =====================================================
    -- SOHBET: 90 gün
    -- =====================================================

    delete from public.chat_messages
    where created_at < now() - interval '90 days';


    -- =====================================================
    -- AUDIT LOG: 20 gün
    -- =====================================================

    delete from public.audit_logs
    where created_at < now() - interval '20 days';


    -- =====================================================
    -- PUAN HAREKETLERİ: 90 gün
    -- =====================================================

    delete from public.points_transactions
    where created_at < now() - interval '90 days';


    -- =====================================================
    -- READING SONUÇLARI: 90 gün
    -- =====================================================

    delete from public.reading_results
    where created_at < now() - interval '90 days';


    -- =====================================================
    -- DUYURU OKUNMALARI: 15 gün
    -- =====================================================

    delete from public.announcement_reads
    where seen_at < now() - interval '15 days';


    -- =====================================================
    -- GÖNDERİLMİŞ MAİLLER: 10 gün
    -- =====================================================

    delete from public.mail_queue
    where sent_at is not null
      and sent_at < now() - interval '10 days';


    -- =====================================================
    -- SÜRESİ GEÇMİŞ OTURUMLAR: HEMEN
    -- =====================================================

    delete from public.portal_sessions
    where expires_at < now();

end;
$function$
;

CREATE OR REPLACE FUNCTION public.dm_account_action(p_ticket_hash text, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t public.dm_account_action_tickets; h text; e text; frozen timestamptz;
begin
 select * into t from public.dm_account_action_tickets where token_hash=p_ticket_hash for update;
 if not found or t.expires_at<now() or t.action<>p_action then raise exception 'ticket_expired'; end if;
 -- Serialize administrator lifecycle changes, including concurrent freeze attempts.
 perform pg_advisory_xact_lock(874205311);
 if t.account_role='student' then
  select password_hash,email,frozen_at into h,e,frozen from public.students where id=t.account_id for update;
 else
  select password_hash,email,frozen_at into h,e,frozen from public.teachers where id=t.account_id for update;
 end if;
 if not found or h is distinct from t.password_hash_snapshot then raise exception 'reauth_required'; end if;
 if t.account_role='teacher' and p_action='freeze' and exists(select 1 from public.teachers where id=t.account_id and is_admin and active) and not exists(select 1 from public.teachers where id<>t.account_id and is_admin and active and frozen_at is null) then raise exception 'last_admin'; end if;
 if t.account_role='student' then update public.students set frozen_at=case when p_action='freeze' then now() else null end where id=t.account_id;
 else update public.teachers set frozen_at=case when p_action='freeze' then now() else null end where id=t.account_id; end if;
 delete from public.portal_sessions where (t.account_role='student' and student_id=t.account_id) or (t.account_role='teacher' and teacher_id=t.account_id);
 if p_action='freeze' then
  update public.mail_queue set error='account_frozen',send_after='infinity'::timestamptz where sent_at is null and not (kind='kayit' and subject like 'Şifre yenileme%') and (student_id=t.account_id or (e is not null and lower(to_email)=lower(e)));
 end if;
 delete from public.dm_account_action_tickets where account_id=t.account_id and account_role=t.account_role;
 return jsonb_build_object('ok',true);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_account_purchase_cleanup()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r text:=case when tg_table_name='students' then 'student' else 'teacher' end;
begin
 delete from public.dm_entitlements where account_id=old.id and account_role=r;
 update public.dm_payment_transactions set account_id=null where account_id=old.id and account_role=r;
 delete from public.dm_account_action_tickets where account_id=old.id and account_role=r;
 return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_active_time_tick(actor uuid, run_key text, seq bigint, active_seconds integer, claim_index bigint DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_active_time; seed bigint; credit int; gold int:=0; quality int; v jsonb; ver bigint;
begin
 if run_key is null or length(run_key) not between 8 and 100 or seq is null or seq<0 or active_seconds is null or active_seconds not between 0 and 45 or claim_index is null or claim_index<0 then raise exception 'Geçersiz süre isteği';end if;
 select coalesce(total_seconds,0) into seed from public.students where id=actor for update;
 if not found then raise exception 'Öğrenci bulunamadı';end if;
 insert into public.dm_active_time(student_id,seconds,base_chest) values(actor,greatest(0,seed),greatest(0,seed)/6000) on conflict do nothing;
 select * into r from public.dm_active_time where student_id=actor for update;
 if active_seconds>0 and not(r.last_run=run_key and seq<=r.last_seq) then
  credit:=least(active_seconds,45,greatest(0,floor(extract(epoch from now()-r.last_tick))::int));
  r.seconds:=r.seconds+credit;r.last_tick:=now();r.last_run:=run_key;r.last_seq:=seq;
  update public.dm_active_time set seconds=r.seconds,last_tick=r.last_tick,last_run=r.last_run,last_seq=r.last_seq where student_id=actor;
  update public.students set total_seconds=greatest(coalesce(total_seconds,0),r.seconds) where id=actor;
 end if;
 if claim_index>0 then
  if claim_index<=r.base_chest or claim_index>r.seconds/6000 then raise exception 'Bu sandık henüz hazır değil';end if;
  if not(claim_index=any(r.claimed)) then
   quality:=least(4,((claim_index-r.base_chest-1)/5)::int);gold:=(array[20,40,75,120,200])[quality+1];
   select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
   if v is null then raise exception 'Hesap bilgileri hazır değil';end if;
   ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
   v:=v||jsonb_build_object('altin',coalesce((v->>'altin')::numeric,0)+gold,'guncelleme',ver,'dmRewardVersion',ver);
   update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
   update public.students set gold=(v->>'altin')::numeric where id=actor;
   r.claimed:=array_append(r.claimed,claim_index);update public.dm_active_time set claimed=r.claimed where student_id=actor;
  end if;
 end if;
 return jsonb_build_object('ok',true,'seconds',r.seconds,'stars',r.seconds/600,'baseChest',r.base_chest,'chestCount',r.seconds/6000,'claimed',to_jsonb(r.claimed),'gold',gold,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_blocked(a uuid, b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select exists(select 1 from public.student_blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a)); $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_checkpoint(actor uuid, run_key uuid, chapter_no integer, score integer, seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_break_runs;goal int;elapsed numeric;unlocked int;
begin
 perform 1 from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci oturumu gerekli.';end if;
 select * into r from public.dm_break_runs where id=run_key and student_id=actor for update;
 if not found then raise exception 'Oyun bulunamadı.';end if;
 if exists(select 1 from public.dm_break_checkpoints c where c.run_id=run_key and c.chapter=chapter_no) then return public.dm_break_status(actor)||public.dm_break_run_view(r)||jsonb_build_object('duplicate',true);end if;
 if r.status<>'playing' or r.completed_all or chapter_no is null or chapter_no<>r.chapter then raise exception 'Geçersiz bölüm sırası.';end if;
 elapsed:=extract(epoch from clock_timestamp()-r.created_at);
 if seconds is null or seconds>elapsed+1 or elapsed>7200 or seconds<r.checkpoint_seconds or score<r.checkpoint_score then raise exception 'Oyun süresi doğrulanamadı.';end if;
 perform public.dm_break_reward(r.game,score,0,seconds);
 select c.goal into goal from public.dm_break_chapters c where c.game=r.game and c.chapter=r.chapter;
 if score-r.chapter_start_score<goal then raise exception 'Bölüm eşiği henüz tamamlanmadı.';end if;
 insert into public.dm_break_checkpoints(run_id,chapter,score,seconds) values(run_key,r.chapter,score,seconds);
 unlocked:=least(10,r.chapter+1);
 insert into public.dm_break_progress(student_id,game,unlocked_chapter,completed_all) values(actor,r.game,unlocked,r.chapter=10)
 on conflict(student_id,game) do update set unlocked_chapter=greatest(public.dm_break_progress.unlocked_chapter,excluded.unlocked_chapter),completed_all=public.dm_break_progress.completed_all or excluded.completed_all,updated_at=now();
 update public.dm_break_runs set chapter=unlocked,highest_chapter=greatest(highest_chapter,unlocked),chapter_start_score=dm_break_checkpoint.score,checkpoint_score=dm_break_checkpoint.score,checkpoint_seconds=dm_break_checkpoint.seconds,score=dm_break_checkpoint.score,completed_all=(r.chapter=10) where id=run_key returning * into r;
 return public.dm_break_status(actor)||public.dm_break_run_view(r)||jsonb_build_object('completedChapter',chapter_no,'duplicate',false);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_finish(actor uuid, run_key uuid, score integer, collected_gold integer, seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students;r public.dm_break_runs;v jsonb;g int;ver bigint;best int;elapsed numeric;
begin
 select * into st from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci oturumu gerekli.';end if;
 select * into r from public.dm_break_runs where id=run_key and student_id=actor for update;
 if not found then raise exception 'Oyun bulunamadı.';end if;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Hesap bilgileri hazır değil.';end if;
 select coalesce(max(b.score),0) into best from public.dm_break_runs b where b.student_id=actor and b.game=r.game and b.status='finished' and b.id<>run_key;
 if r.status='finished' then
  return public.dm_break_status(actor)||jsonb_build_object('runId',r.id,'finished',true,'score',r.score,'gold',r.gold,'record',r.score>best,'yo',v)||public.dm_break_run_view(r);
 end if;
 elapsed:=extract(epoch from clock_timestamp()-r.created_at);
 if seconds is null or seconds>elapsed+1 or elapsed>7200 then raise exception 'Oyun süresi doğrulanamadı.';end if;
 if score<r.checkpoint_score or seconds<r.checkpoint_seconds then raise exception 'Oyun sonucu kayıtlı ilerlemenin gerisinde.';end if;
 g:=public.dm_break_reward(r.game,score,collected_gold,seconds);
 if not r.completed_all and score-r.chapter_start_score>=(select c.goal from public.dm_break_chapters c where c.game=r.game and c.chapter=r.chapter) then
 perform public.dm_break_checkpoint(actor,run_key,r.chapter,score,seconds);select * into r from public.dm_break_runs where id=run_key;end if;
 ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
 v:=v||jsonb_build_object('altin',coalesce((v->>'altin')::numeric,0)+g,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
 update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
 update public.students set gold=(v->>'altin')::numeric where id=actor;
 select value into v from public.extra_data where student_id=actor and key_name='yo';
 update public.dm_break_runs set score=dm_break_finish.score,gold=g,status='finished',finished_at=now() where id=run_key returning * into r;
 return public.dm_break_status(actor)||jsonb_build_object('runId',r.id,'finished',true,'score',r.score,'gold',g,'record',r.score>best,'yo',v)||public.dm_break_run_view(r);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_ranking(actor uuid, game_code text, period text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if game_code is null or game_code not in ('kosu','zipla','patlat') or period is null or period not in ('week','all') then raise exception 'Geçersiz sıralama.';end if;
 if not exists(select 1 from public.students where id=actor and status='approved' and role='student') then raise exception 'Öğrenci oturumu gerekli.';end if;
 with best as (
  select distinct on (r.student_id) r.student_id,s.username,r.score,r.highest_chapter,coalesce(r.finished_at,r.created_at) finished_at
  from public.dm_break_runs r join public.students s on s.id=r.student_id
  where r.game=game_code and (r.status='finished' or r.checkpoint_score>0) and s.status='approved' and s.role='student'
   and s.id<>'dcde2026-1015-4000-8000-000000000001'::uuid and lower(s.username)<>'dijimedu_demo'
   and (period='all' or coalesce(r.finished_at,r.created_at)>=date_trunc('week',now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')
  order by r.student_id,r.highest_chapter desc,r.score desc,r.finished_at,r.id
 ), ranked as (
  select row_number() over(order by highest_chapter desc,score desc,finished_at,student_id) rank,username name,score,highest_chapter chapter,student_id=actor mine from best
 ) select jsonb_build_object('ok',true,'liste',coalesce((select jsonb_agg(to_jsonb(t) order by t.rank) from ranked t where rank<=50),'[]'::jsonb),'me',(select to_jsonb(t) from ranked t where mine)) into result;
 return result;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_reward(game_code text, score integer, collected_gold integer, seconds integer)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare rate int;unit int;
begin
 if game_code is null or game_code not in ('kosu','zipla','patlat') or seconds is null or seconds<0 or seconds>1800 or score is null or score<0 or collected_gold is null or collected_gold<0 then raise exception 'Geçersiz oyun sonucu.';end if;
 rate:=case game_code when 'kosu' then 35 when 'zipla' then 60 else 2500 end;
 unit:=case game_code when 'kosu' then 100 when 'zipla' then 150 else 1000 end;
 if score>seconds*rate+(case when game_code='patlat' then 0 else 3 end) then raise exception 'Oyun sonucu süreyle uyuşmuyor.';end if;
 return least(100,least(collected_gold,seconds*3,case game_code when 'patlat' then score/60 else score/5 end)+least(20,score/unit));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_run_view(r dm_break_runs)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('runId',r.id,'finished',r.status='finished','score',r.score,'gold',r.gold,'chapter',r.chapter,'chapterStartScore',r.chapter_start_score,'highestChapter',r.highest_chapter,'completedAll',r.completed_all,'goal',(select goal from public.dm_break_chapters where game=r.game and chapter=r.chapter));
$function$
;

CREATE OR REPLACE FUNCTION public.dm_break_start(actor uuid, run_key uuid, game_code text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select public.dm_break_start(actor,run_key,game_code,null::integer); $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_start(actor uuid, run_key uuid, game_code text, chapter_no integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students;r public.dm_break_runs;available int;ticks int;chosen int;unlocked int;d text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
begin
 if run_key is null or game_code is null or game_code not in ('kosu','zipla','patlat') then raise exception 'Geçersiz oyun.';end if;
 select * into st from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci oturumu gerekli.';end if;
 select * into r from public.dm_break_runs where id=run_key;
 if found then
  if r.student_id<>actor or r.game<>game_code then raise exception 'Oyun bulunamadı.';end if;
  return public.dm_break_status(actor)||public.dm_break_run_view(r);
 end if;
 select coalesce((select p.unlocked_chapter from public.dm_break_progress p where p.student_id=actor and p.game=game_code),1) into unlocked;
 chosen:=coalesce(chapter_no,unlocked);
 if chosen<1 or chosen>unlocked or chosen>10 then raise exception 'Bu bölüm henüz açılmadı.';end if;
 if (select count(*) from public.dm_break_runs where student_id=actor and day=d and game=game_code)>=2 then raise exception 'Bugünkü 2 hakkın bitti, yarın yine gel';end if;
 ticks:=greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900));
 available:=case when st.energy>=st.energy_max then st.energy else least(st.energy_max,st.energy+ticks) end;
 if available<5 then raise exception 'Oyuna başlamak için 5 enerji gerekli.';end if;
 insert into public.dm_break_runs(id,student_id,game,day,start_chapter,chapter,highest_chapter) values(run_key,actor,game_code,d,chosen,chosen,chosen) returning * into r;
 update public.students set energy=available-5,energy_updated_at=case when available>=st.energy_max then now() else coalesce(st.energy_updated_at,now())+ticks*interval '15 minutes' end where id=actor;
 insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,-5,available-5,'mola:'||run_key);
 return public.dm_break_status(actor)||public.dm_break_run_view(r);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_break_status(actor uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students;d text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');games jsonb;available int;
begin
 select * into st from public.students where id=actor and status='approved' and role='student';
 if not found then raise exception 'Öğrenci oturumu gerekli.';end if;
 available:=case when st.energy>=st.energy_max then st.energy else least(st.energy_max,st.energy+greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900))::int) end;
 select jsonb_object_agg(g,jsonb_build_object('unlocked',coalesce((select p.unlocked_chapter from public.dm_break_progress p where p.student_id=actor and p.game=g),1),'currentChapter',coalesce((select p.unlocked_chapter from public.dm_break_progress p where p.student_id=actor and p.game=g),1),'completedAll',coalesce((select p.completed_all from public.dm_break_progress p where p.student_id=actor and p.game=g),false),'chapters',(select jsonb_agg(jsonb_build_object('chapter',c.chapter,'title',c.title,'goal',c.goal,'theme',c.theme) order by c.chapter) from public.dm_break_chapters c where c.game=g),'remaining',greatest(0,2-(select count(*) from public.dm_break_runs r where r.student_id=actor and r.day=d and r.game=g)))) into games from unnest(array['kosu','zipla','patlat']) g;
 return jsonb_build_object('ok',true,'day',d,'games',games,'energy',available,'energyMax',st.energy_max);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_capture_weekly_xp()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v jsonb; w date; days int; x numeric;
begin
 if new.key_name<>'yo' or jsonb_typeof(new.value)<>'object' then return new; end if;
 -- Preserve a freshly issued server reward against an older in-flight device save.
 if tg_op='UPDATE' and old.value ? 'dmRewardVersion' and coalesce((new.value->>'dmRewardVersion')::bigint,0)<coalesce((old.value->>'dmRewardVersion')::bigint,0) then
  new.value:=old.value; return new; -- stale device must reload the awarded balance
 end if;
 v:=new.value; w:=public.dm_week_start(v#>>'{lig,hafta}');
 if w is null or w<>date_trunc('week',now() at time zone 'Europe/Istanbul')::date then return new; end if;
 x:=greatest(0,least(1000000,coalesce((v#>>'{lig,xp}')::numeric,0)));
 select count(*) into days from jsonb_each(case when jsonb_typeof(v->'log')='object' then v->'log' else '{}'::jsonb end) d where d.key>=w::text and d.key<(w+7)::text and d.value::text ~ '^[0-9]+(\.[0-9]+)?$' and d.value::text::numeric>0;
 insert into public.dm_weekly_xp(student_id,week_start,xp,active_days) values(new.student_id,w,x,days)
 on conflict(student_id,week_start) do update set xp=greatest(dm_weekly_xp.xp,excluded.xp),active_days=greatest(dm_weekly_xp.active_days,excluded.active_days),updated_at=now();
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_claim_papi_league_test()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin insert into dm_private.papi_league_test_send(id) values(1) on conflict do nothing; return found; end $function$
;

CREATE OR REPLACE FUNCTION public.dm_claim_papi_mascot_email_test()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin insert into dm_private.papi_mascot_email_test(id) values(1) on conflict do nothing; return found; end $function$
;

CREATE OR REPLACE FUNCTION public.dm_claim_papi_official_test()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin insert into dm_private.papi_official_mail_test(id) values(1) on conflict do nothing; return found; end $function$
;

CREATE OR REPLACE FUNCTION public.dm_classic_result(actor uuid, game text, score numeric, seconds numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.duels; mine jsonb; other jsonb; winner text; out jsonb:='[]';
begin
 for d in select * from public.duels where actor in(sender_student_id,receiver_student_id) and status='accepted' and sender_payload->>'oyun'=game and responded_at>now()-interval '24 hours' order by id for update loop
  if public.dm_blocked(d.sender_student_id,d.receiver_student_id) then continue;end if;
  mine:=jsonb_build_object('puan',score,'sure',seconds);
  if actor=d.sender_student_id then d.sender_payload:=d.sender_payload||jsonb_build_object('result',mine);else d.receiver_payload:=coalesce(d.receiver_payload,'{}')||jsonb_build_object('result',mine);end if;
  if d.sender_payload ? 'result' and d.receiver_payload ? 'result' and coalesce(d.sender_payload#>>'{result,puanSurum}','2')=coalesce(d.receiver_payload#>>'{result,puanSurum}','2') then
   if (d.sender_payload#>>'{result,puan}')::numeric>(d.receiver_payload#>>'{result,puan}')::numeric then select username into winner from public.students where id=d.sender_student_id;
   elsif (d.sender_payload#>>'{result,puan}')::numeric<(d.receiver_payload#>>'{result,puan}')::numeric then select username into winner from public.students where id=d.receiver_student_id;
   elsif (d.sender_payload#>>'{result,sure}')::numeric<(d.receiver_payload#>>'{result,sure}')::numeric then select username into winner from public.students where id=d.sender_student_id;
   elsif (d.sender_payload#>>'{result,sure}')::numeric>(d.receiver_payload#>>'{result,sure}')::numeric then select username into winner from public.students where id=d.receiver_student_id;
   else winner:='berabere';end if;
   d.status:='finished';d.sender_payload:=d.sender_payload||jsonb_build_object('kazanan',winner);
   insert into public.notifications(recipient_student_id,type,message) values(d.sender_student_id,'duelloSonuc','Düello tamamlandı: '||winner),(d.receiver_student_id,'duelloSonuc','Düello tamamlandı: '||winner);
  end if;
  update public.duels set sender_payload=d.sender_payload,receiver_payload=d.receiver_payload,status=d.status where id=d.id;
  other:=case when actor=d.sender_student_id then d.receiver_payload->'result' else d.sender_payload->'result' end;
  out:=out||jsonb_build_array(jsonb_build_object('id',d.id,'status',d.status,'myResult',mine,'opponentResult',other,'winner',winner));
 end loop;
 return out;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_classic_result_v3(actor uuid, game text, score numeric, seconds numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.duels; mine jsonb; other jsonb; winner text; out jsonb:='[]';
begin
 for d in select * from public.duels where actor in(sender_student_id,receiver_student_id) and status='accepted' and sender_payload->>'oyun'=game and responded_at>now()-interval '24 hours' order by id for update loop
  if public.dm_blocked(d.sender_student_id,d.receiver_student_id) then continue;end if;
  mine:=case when actor=d.sender_student_id then d.sender_payload->'result' else d.receiver_payload->'result' end;
  if mine is null or mine->>'puanSurum'<>'3' then mine:=jsonb_build_object('puan',score,'sure',seconds,'puanSurum',3);end if;
  if actor=d.sender_student_id then d.sender_payload:=d.sender_payload||jsonb_build_object('result',mine);else d.receiver_payload:=coalesce(d.receiver_payload,'{}')||jsonb_build_object('result',mine);end if;
  if d.sender_payload ? 'result' and d.receiver_payload ? 'result' and coalesce(d.sender_payload#>>'{result,puanSurum}','2')=coalesce(d.receiver_payload#>>'{result,puanSurum}','2') then
   if (d.sender_payload#>>'{result,puan}')::numeric>(d.receiver_payload#>>'{result,puan}')::numeric then select username into winner from public.students where id=d.sender_student_id;
   elsif (d.sender_payload#>>'{result,puan}')::numeric<(d.receiver_payload#>>'{result,puan}')::numeric then select username into winner from public.students where id=d.receiver_student_id;
   elsif (d.sender_payload#>>'{result,sure}')::numeric<(d.receiver_payload#>>'{result,sure}')::numeric then select username into winner from public.students where id=d.sender_student_id;
   elsif (d.sender_payload#>>'{result,sure}')::numeric>(d.receiver_payload#>>'{result,sure}')::numeric then select username into winner from public.students where id=d.receiver_student_id;
   else winner:='berabere';end if;
   d.status:='finished';d.sender_payload:=d.sender_payload||jsonb_build_object('kazanan',winner);
   insert into public.notifications(recipient_student_id,type,message) values(d.sender_student_id,'duelloSonuc','Düello tamamlandı: '||winner),(d.receiver_student_id,'duelloSonuc','Düello tamamlandı: '||winner);
  end if;
  update public.duels set sender_payload=d.sender_payload,receiver_payload=d.receiver_payload,status=d.status where id=d.id;
  other:=case when actor=d.sender_student_id then d.receiver_payload->'result' else d.sender_payload->'result' end;
  out:=out||jsonb_build_array(jsonb_build_object('id',d.id,'status',d.status,'myResult',mine,'opponentResult',other,'winner',winner));
 end loop;
 return out;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_communication_mail_tick(rule_key text, kind text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare active_rule boolean; result_count integer;
begin
 if rule_key not in ('weekly_league_mail','monday_league_mail','three_day_mail') then raise exception 'Unsupported communication rule'; end if;
 select enabled into active_rule from public.dm_communication_rules where key=rule_key and category='mail';
 if active_rule is distinct from true then return 0; end if;
 if rule_key='weekly_league_mail' then
  select public.dm_papi_league_mail_prepare('sunday') into result_count;
 elsif rule_key='monday_league_mail' then
  select public.dm_papi_league_mail_prepare('monday') into result_count;
 else
  select public.dm_papi_progress_queue() into result_count;
 end if;
 return coalesce(result_count,0);
end; $function$
;

CREATE OR REPLACE FUNCTION public.dm_competitive_xp(actor uuid, week date)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select coalesce((select sum(greatest(0,correct_count*6+floor(coalesce((extra->>'speed')::numeric,0)/100)-wrong_count*3)) from public.game_scores where student_id=actor and extra->>'v'='3' and correct_count>0 and created_at>=week::timestamp at time zone 'Europe/Istanbul' and created_at<(week+7)::timestamp at time zone 'Europe/Istanbul'),0)
+coalesce((select 80*count(*) from (select min(completed_at) first_at from public.lesson_progress where student_id=actor and test_success group by level,category,topic_name) p where first_at>=week::timestamp at time zone 'Europe/Istanbul' and first_at<(week+7)::timestamp at time zone 'Europe/Istanbul'),0)
+coalesce((select 42*count(*) from public.level_completions where student_id=actor and mode='buyu' and level_no>=1000 and completed_at>=week::timestamp at time zone 'Europe/Istanbul' and completed_at<(week+7)::timestamp at time zone 'Europe/Istanbul'),0);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_daily_energy_bonus(actor uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 s public.students; day date := (now() at time zone 'Europe/Istanbul')::date;
 start_at timestamptz; claim_key text; cap int; before_energy int; balance int; amount int; added int;
 steps int; stamp timestamptz; already boolean;
begin
 select * into s from public.students where id=actor and status='approved' for update;
 if not found then raise exception 'Aktif öğrenci hesabı gerekli'; end if;
 start_at:=day::timestamp at time zone 'Europe/Istanbul';claim_key:='energy_daily:'||day::text;
 cap:=coalesce(nullif(s.energy_max,0),30);before_energy:=coalesce(s.energy,0);balance:=before_energy;stamp:=coalesce(s.energy_updated_at,now());
 -- Regenerate under the same row lock so parallel devices cannot overwrite the balance.
 if balance<cap then
  steps:=greatest(0,floor(extract(epoch from (now()-stamp))/900)::int);
  if steps>0 then
   balance:=least(cap,balance+steps);stamp:=case when balance>=cap then now() else stamp+steps*interval '15 minutes' end;
   insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,balance-before_energy,balance,'dolum');
  end if;
 elsif now()-stamp>interval '15 minutes' then stamp:=now();
 end if;
 -- Honor pre-upgrade claims as well as the new durable marker (including zero-credit claims).
 already:=exists(select 1 from public.extra_data where student_id=actor and key_name=claim_key)
 or exists(select 1 from public.energy_transactions where student_id=actor and reason='gunluk' and change_amount>0 and created_at>=start_at and created_at<start_at+interval '1 day');
 if already then
  update public.students set energy=balance,energy_updated_at=stamp where id=actor;
  insert into public.extra_data(student_id,key_name,value) values(actor,claim_key,jsonb_build_object('day',day,'legacy',true)) on conflict(student_id,key_name) do nothing;
  return jsonb_build_object('ok',true,'status','success','claimed',false,'alreadyClaimed',true,'day',day,'eklenen',0,'enerjiKalan',balance,'enerjiMax',cap,'mesaj','Günlük hediyeni bugün zaten aldın.');
 end if;
 amount:=case when coalesce(s.streak,0)>0 and s.streak%7=0 then 10 else 5 end;
 added:=greatest(0,least(amount,cap+10-balance));balance:=balance+added;
 update public.students set energy=balance,energy_updated_at=stamp,updated_at=now() where id=actor;
 insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,added,balance,'gunluk');
 insert into public.extra_data(student_id,key_name,value) values(actor,claim_key,jsonb_build_object('day',day,'amount',added)) on conflict(student_id,key_name) do nothing;
 return jsonb_build_object('ok',true,'status','success','claimed',true,'alreadyClaimed',false,'day',day,'eklenen',added,'enerjiKalan',balance,'enerjiMax',cap);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_deliver_accessory()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 update public.extra_data set value=jsonb_set(value,'{guncelleme}',to_jsonb(floor(extract(epoch from clock_timestamp())*1000))),updated_at=now() where student_id=new.recipient_id and key_name='yo' and jsonb_typeof(value)='object';
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_duel_action(actor uuid, action text, arg jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare target uuid;d public.duels;g text;listed jsonb;
begin
 if not exists(select from public.students where id=actor and status='approved') then raise exception 'Öğrenci bulunamadı.';end if;
 if action='create' then
  target:=(arg->>'target')::uuid;g:=arg->>'game';
  if target=actor or not exists(select from public.students where id=target and status='approved') then raise exception 'Geçersiz rakip.';end if;
  perform pg_advisory_xact_lock(hashtextextended('duel:'||actor::text,0));
  perform pg_advisory_xact_lock(hashtextextended(least(actor::text,target::text)||greatest(actor::text,target::text),0));
  if public.dm_blocked(actor,target) then raise exception 'Bu kişiyle iletişim kapalı.';end if;
  if (select count(*) from public.duels where sender_student_id=actor and created_at>=(now() at time zone 'Europe/Istanbul')::date::timestamp at time zone 'Europe/Istanbul')>=3 then raise exception 'Bugün 3 düello gönderdin. Yarın yine gel!';end if;
  insert into public.duels(sender_student_id,receiver_student_id,sender_payload) values(actor,target,jsonb_build_object('oyun',g));
  insert into public.notifications(recipient_student_id,sender_student_id,type,message) values(target,actor,'duello',g);
  return jsonb_build_object('ok',true,'status','success');
 elsif action='reply' then
  select * into d from public.duels where id=(arg->>'id')::uuid and receiver_student_id=actor for update;
  if d.id is null or d.status<>'pending' or d.created_at<now()-interval '24 hours' then raise exception 'Davet artık geçerli değil.';end if;
  if public.dm_blocked(actor,d.sender_student_id) then raise exception 'Bu kişiyle iletişim kapalı.';end if;
  update public.duels set status=case when (arg->>'accept')::boolean then 'accepted' else 'rejected' end,responded_at=now() where id=d.id;
  return jsonb_build_object('ok',true,'status','success');
 elsif action='list' then
  select coalesce(jsonb_agg(x),'[]') into listed from (select jsonb_build_object('id',dl.id,'gonderen',a.username,'alici',b.username,'durum',case when dl.status='finished' then 'bitti' when dl.status='rejected' then 'red' when coalesce(dl.responded_at,dl.created_at)<now()-interval '24 hours' then 'sure_doldu' when dl.status='accepted' then 'kabul' else 'bekliyor' end,'oyun',dl.sender_payload->>'oyun','kazanan',dl.sender_payload->>'kazanan','benPuan',case when actor=dl.sender_student_id then dl.sender_payload#>'{result,puan}' else dl.receiver_payload#>'{result,puan}' end,'rakipPuan',case when actor=dl.sender_student_id then dl.receiver_payload#>'{result,puan}' else dl.sender_payload#>'{result,puan}' end,'benSure',case when actor=dl.sender_student_id then dl.sender_payload#>'{result,sure}' else dl.receiver_payload#>'{result,sure}' end,'rakipSure',case when actor=dl.sender_student_id then dl.receiver_payload#>'{result,sure}' else dl.sender_payload#>'{result,sure}' end,'kalanDk',greatest(0,1440-floor(extract(epoch from now()-coalesce(dl.responded_at,dl.created_at))/60))) x from public.duels dl join public.students a on a.id=dl.sender_student_id join public.students b on b.id=dl.receiver_student_id where actor in(dl.sender_student_id,dl.receiver_student_id) order by dl.created_at desc limit 50) t;
  return jsonb_build_object('ok',true,'liste',listed);
 end if;raise exception 'Geçersiz işlem.';
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_email_issue(actor uuid, digest text, mail text, title text, html_body text, plain_body text)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students; last_at timestamptz; n int; mid bigint;
begin
 select * into st from public.students where id=actor for update;
 if st.id is null or st.status not in ('pending','approved') or lower(st.email)<>lower(mail) or length(digest)<>64 then raise exception 'Doğrulama oluşturulamadı.';end if;
 select max(created_at),count(*) filter(where created_at>now()-interval '24 hours') into last_at,n from public.dm_email_verifications where student_id=actor;
 if last_at>now()-interval '60 seconds' or n>=3 then raise exception 'Biraz bekle. Günde en fazla 3 doğrulama e-postası gönderebilirsin.';end if;
 update public.mail_queue set attempts=5,error='Yeni doğrulama bağlantısıyla değiştirildi.' where student_id=actor and kind='dogrulama' and sent_at is null;
 update public.dm_email_verifications set consumed_at=now() where student_id=actor and consumed_at is null;
 insert into public.dm_email_verifications(token_hash,student_id,email) values(digest,actor,mail);
 insert into public.mail_queue(student_id,to_email,subject,html,text_body,kind,priority) values(actor,mail,title,html_body,plain_body,'dogrulama',100) returning id into mid;
 return mid;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_email_verify(digest text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ticket public.dm_email_verifications; st public.students;
begin
 -- Serialize issuance and consumption by student, avoiding inverse lock ordering.
 select * into ticket from public.dm_email_verifications where token_hash=digest;
 if not found then return jsonb_build_object('ok',false,'mesaj','Bağlantı geçersiz. Yeni doğrulama e-postası iste.');end if;
 select * into st from public.students where id=ticket.student_id for update;
 select * into ticket from public.dm_email_verifications where token_hash=digest for update;
 if ticket.consumed_at is not null or ticket.expires_at<=now() or lower(st.email)<>lower(ticket.email) or st.status not in ('pending','approved') then return jsonb_build_object('ok',false,'mesaj','Bağlantının süresi dolmuş veya daha önce kullanılmış. Giriş ekranından yeni bağlantı iste.');end if;
 if st.status='pending' and not st.email_verification_required then return jsonb_build_object('ok',false,'mesaj','Bu hesap öğretmen onayı bekliyor.');end if;
 update public.dm_email_verifications set consumed_at=now() where token_hash=digest;
 update public.students set email_verified_at=now(),status='approved',updated_at=now() where id=st.id;
 return jsonb_build_object('ok',true,'ogrenci',st.username,'mesaj','Hoş geldin! E-posta adresin doğrulandı, hesabın hazır.');
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_energy_shop_buy(actor uuid, request_key text, pack_amount integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare price integer; st public.students; v jsonb; balance numeric; available integer; ticks integer; already public.dm_energy_shop_purchases;
 day_start timestamptz; bought_today integer;
begin
 if actor is null or request_key is null or length(request_key) not between 12 and 100 or pack_amount not in (5,10,15) then raise exception 'Geçersiz enerji paketi'; end if;
 price:=case pack_amount when 5 then 100 when 10 then 130 when 15 then 180 end;
 select * into st from public.students where id=actor for update;
 if not found then raise exception 'Öğrenci bulunamadı'; end if;
 select * into already from public.dm_energy_shop_purchases where student_id=actor and dm_energy_shop_purchases.request_key=dm_energy_shop_buy.request_key;
 if found then return jsonb_build_object('ok',true,'duplicate',true,'energy',st.energy,'gold',st.gold,'added',already.energy_amount,'price',already.gold_price); end if;
 day_start:=((now() at time zone 'Europe/Istanbul')::date)::timestamp at time zone 'Europe/Istanbul';
 select count(*) into bought_today from public.dm_energy_shop_purchases where student_id=actor and created_at>=day_start;
 if bought_today>=3 then raise exception 'Bugün en fazla 3 kez enerji alabilirsin. Yarın yine gel!'; end if;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci ekonomisi bulunamadı'; end if;
 balance:=greatest(0,coalesce((v->>'altin')::numeric,0));
 ticks:=greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900));
 available:=least(st.energy_max,st.energy+ticks);
 if available+pack_amount>st.energy_max then raise exception 'Enerji kapasitesi aşılıyor'; end if;
 if balance<price then raise exception 'Yetersiz altın'; end if;
 insert into public.dm_energy_shop_purchases(student_id,request_key,energy_amount,gold_price) values(actor,request_key,pack_amount,price);
 update public.students set energy=available+pack_amount,energy_updated_at=case when available=st.energy_max then now() else coalesce(st.energy_updated_at,now())+ticks*interval '15 minutes' end,gold=balance-price where id=actor;
 update public.extra_data set value=jsonb_set(v,'{altin}',to_jsonb(balance-price)),updated_at=now() where student_id=actor and key_name='yo';
 insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,pack_amount,available+pack_amount,'dm_energy_shop:'||request_key);
 return jsonb_build_object('ok',true,'duplicate',false,'energy',available+pack_amount,'gold',balance-price,'added',pack_amount,'price',price,'remainingToday',2-bought_today);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_entitlement_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.state='active' and not exists(select 1 from public.dm_payment_transactions t where t.id=new.transaction_id and t.account_id=new.account_id and t.account_role=new.account_role and t.product_key=new.product_key and t.provider=new.provider and t.state='verified' and t.verified_at is not null and (t.valid_until is null or t.valid_until>now()) and (t.valid_until is null or (new.valid_until is not null and new.valid_until<=t.valid_until))) then raise exception 'verified_receipt_required'; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_feed_achievement()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare sid uuid:=new.student_id; prev jsonb:='{}'; current_value jsonb; item text; label text; badge_names jsonb:='{"hos-geldin": "aktif-5", "aktif-5": "Meraklı Papi", "aktif-15": "Odak Ustası", "aktif-60": "Bir Saatlik Kaşif", "oyun-25": "Oyun Gezgini", "dogru-50": "Parlayan Zihin", "parkur-50": "Rota Efsanesi", "seri-14": "İki Haftalık Azim", "ilk-adim": "İlk Adım", "ilk-zafer": "İlk Zafer", "seri-3": "3 Gün Seri", "seri-7": "7 Gün Seri", "seri-30": "30 Gün Seri", "kelime-avcisi": "Kelime Avcısı", "kelime-ustasi": "Kelime Ustası", "tam-isabet": "Tam İsabet", "keskin-goz": "Keskin Göz", "ders-kurdu": "Ders Kurdu", "konu-ustasi": "Konu Ustası", "yildiz-toplayici": "Yıldız Toplayıcı", "parkurcu": "Parkurcu", "kasif": "Kaşif", "sampiyon": "Şampiyon", "gorev-avcisi": "Görev Avcısı", "seviye-5": "Seviye 5", "seviye-10": "Seviye 10", "seviye-20": "Seviye 20", "koleksiyoncu": "Koleksiyoncu", "puan-avcisi": "Puan Avcısı", "puan-efsanesi": "Puan Efsanesi", "altin-kumbara": "Altın Kumbara", "dinleme-ustasi": "Dinleme Ustası"}'::jsonb; n int; g int; message text; key text; kind text;
begin
 if tg_op='UPDATE' then prev:=to_jsonb(old);end if;
 if sid is null or sid='dcde2026-1015-4000-8000-000000000001'::uuid then return new;end if;
 if tg_table_name='lesson_progress' then
  if not coalesce(new.test_success,false) or coalesce((prev->>'test_success')::boolean,false) then return new;end if;
  perform public.dm_feed_publish(sid,'lesson:'||jsonb_build_array(new.level,new.category,new.topic_name)::text,'lesson_complete',new.level||' · '||new.topic_name||' ders konusunu tamamladı!','📚',jsonb_build_object('level',new.level,'category',new.category,'topic',new.topic_name));
 elsif tg_table_name='level_completions' then
  -- Zero-class legacy/thematic records are not school-unit achievements.
  if new.mode='buyu' and (new.class_no not between 1 and 8 or new.unit_no not between 1 and 10) then return new;end if;
  message:=case new.mode when 'buyu' then 'Macera Haritası · '||new.class_no||'. sınıf, '||new.unit_no||'. ünite, '||case when new.level_no>=200000 then new.level_no%100 else new.level_no end||'. durağı tamamladı!' when 'konusma' then 'Kelime Modu · '||new.level_no||'. bölümü tamamladı!' else new.mode||' parkurunda '||new.level_no||'. bölümü tamamladı!' end;
  perform public.dm_feed_publish(sid,'stop:'||jsonb_build_array(new.mode,new.class_no,new.unit_no,new.level_no)::text,'route_complete',message,'🗺️',jsonb_build_object('mode',new.mode,'class',new.class_no,'unit',new.unit_no,'stop',new.level_no));
 elsif tg_table_name='papi_story_progress' then
  if not new.completed or coalesce((prev->>'completed')::boolean,false) then return new;end if;
  perform public.dm_feed_publish(sid,'story:'||new.chapter,'story_complete','Öğrenme Yolu · '||(new.chapter+1)||'. bölümü tamamladı!','🚩',jsonb_build_object('chapter',new.chapter));
 elsif tg_table_name='dm_progress_rewards' then
  if new.kind='purchase' then
   label:=case split_part(new.reward_key,':',2)
     when 'pantolon' then 'Yeni bir pantolon' when 'tisort' then 'Yeni bir tişört'
     when 'canta' then 'Yeni bir çanta' when 'rozet' then 'Özel bir rozet'
     when 'kahraman' then 'Özel bir karakter' when 'durus' then 'Yeni bir karakter pozu'
     when 'sapka' then 'Yeni bir şapka' when 'gozluk' then 'Yeni bir gözlük'
     else 'Mağazadan yeni bir ürün' end;
   perform public.dm_feed_publish(sid,'purchase:'||new.reward_key,'purchase',label||' satın aldı!','🛍️',
     jsonb_build_object('category',split_part(new.reward_key,':',2)));
   return new;
  end if;
  if new.kind='lesson' or new.gold<=0 then return new;end if;
  label:=case new.kind when 'chest' then 'Parkur sandığını açarak' when 'weekly_target' then 'Haftalık hedefini tamamlayarak' when 'stop' then 'Parkur ödülü olarak' else 'Başarı ödülü olarak' end;
  perform public.dm_feed_publish(sid,'reward:'||new.kind||':'||new.reward_key,'reward_earned',label||' '||new.gold||' altın kazandı!','🎁',jsonb_build_object('kind',new.kind,'gold',new.gold));
 elsif tg_table_name='dm_active_time' then
  for item in select x::text from unnest(new.claimed) x where not(to_jsonb(x)<@coalesce(prev->'claimed','[]')) loop
   n:=item::int;g:=(array[20,40,75,120,200])[least(4,((n-new.base_chest-1)/5)::int)+1];
   perform public.dm_feed_publish(sid,'time-chest:'||item,'reward_earned','Aktif öğrenme sandığını açtı ve '||g||' altın kazandı!','🎁',jsonb_build_object('gold',g));
  end loop;
 elsif tg_table_name='extra_data' then
  if new.key_name<>'yo' or jsonb_typeof(new.value)<>'object' then return new;end if;
  current_value:=new.value;prev:=coalesce(prev->'value','{}');
  for item in select jsonb_array_elements_text(coalesce(current_value#>'{dmWorldBadges,ids}','[]')) except select jsonb_array_elements_text(coalesce(prev#>'{dmWorldBadges,ids}','[]')) loop
   label:=badge_names->>item;if label is null then continue;end if;
   -- First historical badge migration is a silent baseline, as in the badge UI.
   if not(prev ? 'dmWorldBadges') and item<>'hos-geldin' then
    insert into public.dm_feed_awards values(sid,'badge:'||item,now()) on conflict do nothing;
   else
    perform public.dm_feed_publish(sid,'badge:'||item,'badge_earned',label||' rozetini kazandı!','🏅',jsonb_build_object('badge_id',item,'badge_name',label));
   end if;
  end loop;
  for item in select jsonb_array_elements_text(coalesce(current_value->'krkSatin','[]')||coalesce(current_value->'krkGoruldu','[]')) except select jsonb_array_elements_text(coalesce(prev->'krkSatin','[]')||coalesce(prev->'krkGoruldu','[]')) loop
   if not(prev ? 'krkGoruldu') and not(coalesce(current_value->'krkSatin','[]') ? item) then
    insert into public.dm_feed_awards values(sid,'character:'||item,now()) on conflict do nothing;
   else
    if coalesce(current_value->'krkSatin','[]') ? item and not (coalesce(prev->'krkSatin','[]') ? item) then
     perform public.dm_feed_publish(sid,'character:'||item,'purchase',item||' karakterini satın aldı!','🛍️',jsonb_build_object('character_name',item));
    else
     perform public.dm_feed_publish(sid,'character:'||item,'character_earned',item||' karakterini koleksiyonuna kattı!','🎭',jsonb_build_object('character_name',item));
    end if;
   end if;
  end loop;
  for item in select jsonb_array_elements_text(coalesce(current_value#>'{karakter,sahip}','[]')) except select jsonb_array_elements_text(coalesce(prev#>'{karakter,sahip}','[]')) loop
   perform public.dm_feed_publish(sid,'item:'||item,'item_earned','Koleksiyonuna yeni bir kıyafet veya aksesuar kattı!','🛍️',jsonb_build_object('item_id',item));
  end loop;
  if public.dm_student_level(coalesce((current_value->>'totalXp')::numeric,0))>public.dm_student_level(coalesce((prev->>'totalXp')::numeric,0)) then
   n:=public.dm_student_level((current_value->>'totalXp')::numeric);
   perform public.dm_feed_publish(sid,'level:'||n,'student_level_up',n||'. seviyeye yükseldi!','🦜',jsonb_build_object('level',n));
  end if;
  if coalesce((current_value#>>'{gorev,alindi}')::boolean,false) and not coalesce((prev#>>'{gorev,alindi}')::boolean,false) then
   perform public.dm_feed_publish(sid,'daily:'||(current_value#>>'{gorev,t}'),'daily_complete','Günün 3 görevini tamamladı ve ödülünü aldı!','✅');
  end if;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_feed_publish(actor uuid, event_key text, kind text, message text, icon text, details jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if actor is null or actor='dcde2026-1015-4000-8000-000000000001'::uuid or not exists(select 1 from public.students where id=actor and status='approved' and role='student') then return;end if;
 insert into public.dm_feed_awards values(actor,event_key,now()) on conflict do nothing;
 if not found then return;end if;
 insert into public.feed_events(student_id,event_type,payload) values(actor,kind,details||jsonb_build_object('message',message,'icon',icon));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_feed_rank(actor uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
with bounds as (select date_trunc('week',now() at time zone 'Europe/Istanbul')::date w),
 scores as (select student_id,sum(greatest(0,correct_count*6+floor(coalesce((extra->>'speed')::numeric,0)/100)-wrong_count*3)) xp from public.game_scores,bounds where extra->>'v'='3' and correct_count>0 and created_at>=w::timestamp at time zone 'Europe/Istanbul' and created_at<(w+7)::timestamp at time zone 'Europe/Istanbul' group by student_id),
 first_lessons as (select student_id,min(completed_at) first_at from public.lesson_progress where test_success group by student_id,level,category,topic_name),
 lessons as (select student_id,count(*)*80 xp from first_lessons,bounds where first_at>=w::timestamp at time zone 'Europe/Istanbul' and first_at<(w+7)::timestamp at time zone 'Europe/Istanbul' group by student_id),
 stops as (select student_id,count(*)*42 xp from public.level_completions,bounds where mode='buyu' and level_no>=1000 and completed_at>=w::timestamp at time zone 'Europe/Istanbul' and completed_at<(w+7)::timestamp at time zone 'Europe/Istanbul' group by student_id),
 base as (select s.id,s.username,public.dm_student_level(coalesce((e.value->>'totalXp')::numeric,0)) level,coalesce(g.xp,0)+coalesce(l.xp,0)+coalesce(p.xp,0) xp from public.students s left join public.extra_data e on e.student_id=s.id and e.key_name='yo' left join scores g on g.student_id=s.id left join lessons l on l.student_id=s.id left join stops p on p.student_id=s.id where s.status='approved' and s.role='student' and s.id<>'dcde2026-1015-4000-8000-000000000001'::uuid),
 tier as (select *,case when level>=15 and xp>=1800 then 'sampiyon' when level>=10 and xp>=750 then 'super' else 'yerel' end league from base where level>=5),
 ranks as (select *,row_number() over(partition by league order by xp desc,username,id) rank from tier)
select jsonb_build_object('league',league,'rank',rank) from ranks where id=actor;
$function$
;

CREATE OR REPLACE FUNCTION public.dm_feed_rank_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare sid uuid; previous jsonb; current_rank jsonb; setting text; league_name text; week text:=date_trunc('week',now() at time zone 'Europe/Istanbul')::date::text;
begin
 sid:=new.student_id;
 if sid is null or sid='dcde2026-1015-4000-8000-000000000001'::uuid then return new;end if;
 if tg_table_name='extra_data' then
  if new.key_name<>'yo' or (tg_op='UPDATE' and coalesce(new.value->>'totalXp','0')=coalesce(old.value->>'totalXp','0')) then return new;end if;
 elsif tg_table_name='lesson_progress' then
  if not coalesce(new.test_success,false) or (tg_op='UPDATE' and coalesce(old.test_success,false)) then return new;end if;
 elsif tg_table_name='level_completions' then
  if new.mode<>'buyu' or new.level_no<1000 then return new;end if;
 elsif tg_table_name='game_scores' then
  if new.correct_count<=0 or new.extra->>'v' is distinct from '3' then return new;end if;
 end if;
 setting:='dm.feed_'||tg_table_name||'_'||replace(sid::text,'-','');
 if tg_when='BEFORE' then
  perform set_config(setting,coalesce(public.dm_feed_rank(sid),'{}')::text,true);return new;
 end if;
 previous:=coalesce(nullif(current_setting(setting,true),'')::jsonb,'{}');current_rank:=public.dm_feed_rank(sid);
 if current_rank is null then return new;end if;
 league_name:=case current_rank->>'league' when 'sampiyon' then 'Şampiyonlar Ligi' when 'super' then 'Süper Lig' else 'Yerel Lig' end;
 if previous->>'league' is distinct from current_rank->>'league' and
    (case current_rank->>'league' when 'sampiyon' then 3 when 'super' then 2 else 1 end)>
    (case previous->>'league' when 'sampiyon' then 3 when 'super' then 2 when 'yerel' then 1 else 0 end) then
  perform public.dm_feed_publish(sid,'league:'||week||':'||(current_rank->>'league'),'league_promotion',league_name||' seviyesine yükseldi!','🏆',current_rank);
 elsif previous->>'league'=current_rank->>'league' and (current_rank->>'rank')::int<(previous->>'rank')::int then
  perform public.dm_feed_publish(sid,'rank:'||week||':'||(current_rank->>'league')||':'||(current_rank->>'rank'),'rank_up',league_name||' sıralamasında '||(previous->>'rank')||'. sıradan '||(current_rank->>'rank')||'. sıraya yükseldi!','📈',current_rank||jsonb_build_object('previous_rank',previous->'rank'));
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_feed_reward_result()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare label text; games jsonb:='{"ky":"Kelime Laboratuvarı","kelime":"Kelime Laboratuvarı","ba":"Macera Haritası","kp":"Kelime Modu","jp":"Risk Balonları","jeopardy":"Risk Balonları","hafiza":"Hafıza Sandığı","bosluk":"Eksik Harf","asmaca":"Harf Avı","eslestirme":"Eşini Bul","yagmur":"Hız Fırtınası","dikte":"Kulak Dedektifi","tren":"Kelime Treni","cumle":"Cümle Ustası","harfbahcesi":"Harf Bahçesi","kelimebul":"Şifre Kırıcı"}';
begin
 if tg_table_name='dm_game_reward_runs' then
  if new.xp<=0 and new.gold<=0 then return new;end if;
  label:=coalesce(games->>new.game_key,'Oyun');
  perform public.dm_feed_publish(new.student_id,'game-reward:'||new.run_id,'reward_earned',label||' etkinliğinde '||new.xp||' XP ve '||new.gold||' altın kazandı!','✨',jsonb_build_object('game',new.game_key,'xp',new.xp,'gold',new.gold));
 else
  if new.xp<=0 then return new;end if;
  label:=case new.league when 'sampiyon' then 'Şampiyonlar Ligi' when 'super' then 'Süper Lig' else 'Yerel Lig' end;
  perform public.dm_feed_publish(new.student_id,'weekly-result:'||new.week_start,'weekly_result',label||' haftasını '||new.rank_no||'. sırada tamamladı!'||case when new.gold>0 or new.energy>0 then ' Ödülü: '||new.gold||' altın, '||new.energy||' enerji.' else '' end,'🏆',jsonb_build_object('league',new.league,'rank',new.rank_no,'gold',new.gold,'energy',new.energy));
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_frozen_last_admin_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 perform pg_advisory_xact_lock(874205311);
 if old.active and old.is_admin and old.frozen_at is null and not exists(select 1 from public.teachers where id<>old.id and active and is_admin and frozen_at is null) then raise exception 'last_admin'; end if;
 return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_frozen_mail_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.kind='kayit' and new.subject like 'Şifre yenileme%' then return new; end if;
 if exists(select 1 from public.students where frozen_at is not null and (id=new.student_id or lower(email)=lower(new.to_email))) or exists(select 1 from public.teachers where frozen_at is not null and lower(email)=lower(new.to_email)) then
  new.error='account_frozen';new.send_after='infinity'::timestamptz;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_frozen_session_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if (new.student_id is not null and exists(select 1 from public.students where id=new.student_id and frozen_at is not null)) or (new.teacher_id is not null and exists(select 1 from public.teachers where id=new.teacher_id and frozen_at is not null)) then raise exception 'account_frozen'; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_game_reward_claim(actor uuid, run_key text, game text, class_id integer, unit_ids integer[], correct integer, wrong integer, seconds numeric, first_clear boolean DEFAULT false, stars integer DEFAULT 1, boost integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v jsonb; previous public.dm_game_reward_runs; t timestamptz; n int; x int:=0;g int:=0;speed int;daily numeric;fac int;ver bigint;day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');reason text:='awarded';deadline timestamptz;
begin
 if game is null or class_id is null or unit_ids is null or correct is null or wrong is null or seconds is null or run_key is null or length(run_key) not between 8 and 100 or game not in ('ky','jp','bosluk','hafiza','yagmur','asmaca','kelimebul','eslestirme','tren','dikte','cumle','harfbahcesi','kp','ba') or class_id not between 0 and 12 or cardinality(unit_ids) not between 1 and 20 or exists(select 1 from unnest(unit_ids) u where u is null or u not between 0 and (case when game='ba' then 300000 else 100 end)) or correct not between 0 and (case when game='ba' then 32 else 12 end) or wrong not between 0 and 10000 or seconds<=0 or seconds>86400 then raise exception 'Geçersiz oyun sonucu';end if;
 -- Convert cached unit-scoped parkur claims to the first section only.
 if game='ba' and unit_ids[1]<1000 then unit_ids:=array[200000+class_id*10000+unit_ids[1]*100+1];end if;
 perform 1 from public.students where id=actor for update;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;if v is null then raise exception 'Öğrenci verisi gerekli';end if;
 select * into previous from public.dm_game_reward_runs where student_id=actor and run_id=run_key;
 if found then return jsonb_build_object('ok',true,'duplicate',true,'xp',previous.xp,'gold',previous.gold,'reason','duplicate','yo',v);end if;
 -- Parkur (ba): her yeni durak bağımsızdır; günlük/24 saat sınırı uygulanmaz.
 -- Sadece ilk başarılı tamamlama ödüllüdür. Aynı durak bir daha XP/altın vermez.
 if game='ba' then
  if correct<7 then reason:='no_correct';
  elsif exists(
    select 1 from public.dm_game_reward_runs
    where student_id=actor and game_key='ba' and class_no=class_id
      and (units&&unit_ids or (unit_ids[1]%100 between 51 and 99 and units @> array[(unit_ids[1]/100)*100+(unit_ids[1]%100-51)/3+1])) and xp>0
  ) then reason:='already_completed';
  else
   -- Parkur stop maximum stays 192 XP / 40 gold.
   speed:=round(12000/(120+seconds));
   x:=least(192,round(192*least(1,correct::numeric/12)*(0.7+0.3*least(1,speed::numeric/100))));
   g:=case when x<=0 then 0 else least(40,round(40*least(1,correct::numeric/12)*(0.7+0.3*least(1,speed::numeric/100)))) end;
  end if;
 else
  -- Every completed solo run may earn rewards; duplicate run IDs remain idempotent.
  -- A game run is always worth less than a parkur stop: hard ceiling dm_game_xp_cap() (172).
  if correct=0 then reason:='no_correct';else
   select count(*)+1 into n from public.dm_game_reward_runs where student_id=actor and game_key<>'ba' and game_key not like 'konu:%' and xp>0 and to_char(created_at at time zone 'Europe/Istanbul','YYYY-MM-DD')=day;
   daily:=case when n<=3 then 2 when n>12 then .5 else 1 end;
   fac:=case when public.dm_student_level(coalesce((v->>'totalXp')::numeric,0))>=15 and boost in (2,3) then 2 else 1 end;
   speed:=round(correct*600/(1+seconds/correct));
   x:=least(public.dm_game_xp_cap(),round(least(80,greatest(0,correct*6+floor(speed/100.0)-wrong*3))*daily*fac))::int;
   g:=case when x=0 then 0 else round((array[4,7,10])[case when correct::numeric/(correct+wrong)>=.8 then 3 when correct::numeric/(correct+wrong)>=.5 then 2 else 1 end]*daily*case when public.dm_student_level(coalesce((v->>'totalXp')::numeric,0))>=15 and boost in (2,4) then 2 else 1 end) end;
  end if;
 end if;
 if game='ba' and correct>=7 then
  insert into public.level_completions(student_id,mode,class_no,unit_no,level_no)
  values(actor,'buyu',0,0,unit_ids[1])
  on conflict(student_id,mode,class_no,unit_no,level_no) do nothing;
 end if;
 insert into public.dm_game_reward_runs values(actor,run_key,game,class_id,unit_ids,x,g,now());
 if x>0 or g>0 then
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)+x,'altin',coalesce((v->>'altin')::numeric,0)+g,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
  v:=jsonb_set(v,'{xpGun}',case when v#>>'{xpGun,tarih}'=day then v->'xpGun' else jsonb_build_object('tarih',day,'xp',0) end);v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(coalesce((v#>>'{xpGun,xp}')::numeric,0)+x));
  v:=jsonb_set(v,'{log}',coalesce(v->'log','{}'));v:=jsonb_set(v,array['log',day],to_jsonb(coalesce((v#>>array['log',day])::numeric,0)+x));
  update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';update public.students set gold=(v->>'altin')::numeric where id=actor;
  select value into v from public.extra_data where student_id=actor and key_name='yo';
 end if;
 return jsonb_build_object('ok',true,'xp',x,'gold',g,'reason',reason,'nextRewardAt',deadline,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_game_xp_cap()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ select 172 $function$
;

CREATE OR REPLACE FUNCTION public.dm_guard_parkur_xp_rebase()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.key_name<>'yo' then return new; end if;
 if tg_op='UPDATE' and old.value#>>'{dmParkurMigration,version}'='1' then
   if new.value#>>'{dmParkurMigration,version}' is distinct from '1'
      or jsonb_typeof(new.value->'guncelleme') is distinct from 'number'
      or (new.value->>'guncelleme')::numeric < (old.value->>'guncelleme')::numeric then
     new.value:=old.value;new.updated_at:=old.updated_at;return new;
   end if;
   new.value:=jsonb_set(new.value,'{dmParkurMigration}',old.value->'dmParkurMigration');
   if new.value->>'dmProgressProtocol' is distinct from '1' then
     new.value:=jsonb_set(new.value,'{totalXp}',old.value->'totalXp');
   elsif jsonb_typeof(new.value->'totalXp') is distinct from 'number'
      or (new.value->>'totalXp')::numeric < (old.value->>'totalXp')::numeric then
     new.value:=jsonb_set(new.value,'{totalXp}',old.value->'totalXp');
   end if;
 end if;
 if jsonb_typeof(new.value)='object' then new.value:=new.value-'dmProgressProtocol';end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_guardian_claim(p_hash text, p_pin text, p_session text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ch public.dm_guardian_challenges; c public.dm_social_controls; begin
 if length(p_hash)<>64 or length(p_session)<>64 or p_pin not like 'pbkdf2$%' then raise exception 'Geçersiz doğrulama.'; end if;
 select * into ch from public.dm_guardian_challenges where token_hash=p_hash for update;
 if ch.id is null or ch.used_at is not null or ch.expires_at<=now() then raise exception 'Bağlantı geçersiz veya süresi dolmuş.'; end if;
 -- Serialize competing initial claims without resetting any social preferences.
 perform 1 from public.students where id=ch.student_id and status='approved' for update;
 if not found then raise exception 'Hesap kullanılamıyor.'; end if;
 select * into c from public.dm_social_controls where student_id=ch.student_id for update;
 if c.verified_at is not null and c.guardian_email<>ch.email then raise exception 'Veli adresi değişmiş.'; end if;
 insert into public.dm_social_controls(student_id,guardian_email,pin_hash,verified_at) values(ch.student_id,ch.email,p_pin,now())
 on conflict(student_id) do update set guardian_email=excluded.guardian_email,pin_hash=excluded.pin_hash,verified_at=now(),updated_at=now();
 update public.dm_guardian_challenges set used_at=now() where student_id=ch.student_id and used_at is null;
 delete from public.dm_guardian_sessions where student_id=ch.student_id;
 insert into public.dm_guardian_sessions(token_hash,student_id,pin_snapshot) values(p_session,ch.student_id,p_pin);
 return ch.student_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_guardian_save(p_session text, p_settings jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare s public.dm_guardian_sessions; c public.dm_social_controls; k text; begin
 select * into s from public.dm_guardian_sessions where token_hash=p_session for update;
 if s.student_id is null or s.expires_at<=now() then raise exception 'Veli oturumu sona erdi. Yeniden doğrula.'; end if;
 select * into c from public.dm_social_controls where student_id=s.student_id for update;
 if c.verified_at is null or c.pin_hash<>s.pin_snapshot then raise exception 'Veli oturumu geçersiz.'; end if;
 if jsonb_typeof(p_settings)<>'object' or p_settings-'social_enabled'-'profile_visible'-'messages_enabled'-'duels_enabled'-'gifts_enabled'<>'{}'::jsonb then raise exception 'Geçersiz ayarlar.'; end if;
 foreach k in array array['social_enabled','profile_visible','messages_enabled','duels_enabled','gifts_enabled'] loop
 if jsonb_typeof(p_settings->k) is distinct from 'boolean' then raise exception 'Bütün ayarları seç.'; end if; end loop;
 update public.dm_social_controls set social_enabled=(p_settings->>'social_enabled')::boolean,profile_visible=(p_settings->>'profile_visible')::boolean,
 messages_enabled=(p_settings->>'messages_enabled')::boolean,duels_enabled=(p_settings->>'duels_enabled')::boolean,gifts_enabled=(p_settings->>'gifts_enabled')::boolean,updated_at=now() where student_id=s.student_id;
 return s.student_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_guest_claim(digest text, feature text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare g public.dm_guest_previews;
begin
 if feature not in ('ky','jp','bosluk','hafiza','yagmur','asmaca','kelimebul','eslestirme','tren','dikte','cumle','harfbahcesi','ba','kp','sh','kk','lesson','quiz','leveltest','shop','profile','ucus','rota') then return jsonb_build_object('ok',false,'mesaj','Bu özellik misafir denemesine dahil değil.');end if;
 select * into g from public.dm_guest_previews where device_hash=digest for update;
 if not found or g.expires_at<=now() then return jsonb_build_object('ok',false,'expired',true,'mesaj','10 dakikalık denemen tamamlandı.');end if;
 if g.used_features ? feature then return jsonb_build_object('ok',false,'used',true,'mesaj','Bu deneme hakkını kullandın. Diğer bölümleri keşfedebilir ya da ücretsiz üye olabilirsin.');end if;
 update public.dm_guest_previews set used_features=used_features||jsonb_build_object(feature,now()) where device_hash=digest;
 return jsonb_build_object('ok',true,'feature',feature);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_guest_lesson(digest text, lesson_key text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare g public.dm_guest_previews;
begin
 select * into g from public.dm_guest_previews where device_hash=digest for update;
 if not found or g.expires_at<=now() or length(lesson_key)>256 then return false;end if;
 if g.used_features ? 'lesson_key' then return (g.used_features->>'lesson_key')=lesson_key;end if;
 update public.dm_guest_previews set used_features=used_features||jsonb_build_object('lesson_key',lesson_key,'lesson',now()) where device_hash=digest;
 return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_guest_preview(digest text, begin_preview boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare g public.dm_guest_previews;
begin
 if length(digest)<>64 then raise exception 'Geçersiz deneme.';end if;
 if begin_preview then insert into public.dm_guest_previews(device_hash) values(digest) on conflict do nothing;end if;
 select * into g from public.dm_guest_previews where device_hash=digest;
 return jsonb_build_object('ok',g.device_hash is not null and g.expires_at>now(),'expiresAt',g.expires_at,'serverNow',now());
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_keep_gifts()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare items jsonb;
begin
 if new.key_name='yo' and jsonb_typeof(new.value)='object' and new.value ? 'karakter' then
  select jsonb_agg(distinct x) into items from (select value x from jsonb_array_elements(coalesce(new.value#>'{karakter,sahip}','[]')) union select to_jsonb('d:'||item_id) from public.dm_accessory_gifts where recipient_id=new.student_id) t;
  new.value:=jsonb_set(new.value,'{karakter,sahip}',coalesce(items,'[]'));
 end if;return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_lesson_fair_award(actor uuid, cefr text, category_name text, topic text, requested_tier integer, historical boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare old_tier int:=0; new_tier int; gain_xp int:=0; gain_gold int:=0; v jsonb; today text; ver bigint;
begin
 if actor is null or requested_tier not in (30,60,80,100) then raise exception 'Geçersiz ders başarısı';end if;
 if not exists(select 1 from public.lesson_topics where active and upper(level)=upper(cefr) and category=category_name and topic_name=topic)
 or not exists(select 1 from public.lesson_progress where student_id=actor and upper(level)=upper(cefr) and category=category_name and topic_name=topic and test_success=true)
 then raise exception 'Onaylı ders bitirme kaydı bulunamadı';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,17));
 select best_tier into old_tier from public.dm_lesson_fair_best
 where student_id=actor and level=upper(cefr) and category=category_name and topic_name=topic for update;
 old_tier:=coalesce(old_tier,0);
 -- Historical completions never create another first-clear award.
 if historical and old_tier=0 then
  insert into public.dm_lesson_fair_best(student_id,level,category,topic_name,best_tier)
  values(actor,upper(cefr),category_name,topic,100)
  on conflict do nothing;
  return jsonb_build_object('xp',0,'gold',0,'tier',100,'historical',true);
 end if;
 new_tier:=greatest(old_tier,requested_tier);
 if new_tier=old_tier then return jsonb_build_object('xp',0,'gold',0,'tier',old_tier,'duplicate',true);end if;
 -- Fixed 80 XP/25 gold base. Higher performance earns only the difference.
 gain_xp:=round(80.0*new_tier/100)-round(80.0*old_tier/100);
 gain_gold:=round(25.0*new_tier/100)-round(25.0*old_tier/100);
 insert into public.dm_lesson_fair_best(student_id,level,category,topic_name,best_tier)
 values(actor,upper(cefr),category_name,topic,new_tier)
 on conflict(student_id,level,category,topic_name) do update set
 best_tier=excluded.best_tier,updated_at=now();
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci ödül cüzdanı bulunamadı';end if;
 today:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
 ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
 v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)+gain_xp,
 'altin',coalesce((v->>'altin')::numeric,0)+gain_gold,'guncelleme',ver,
 'dmRewardVersion',ver,'dmProgressProtocol',1);
 v:=jsonb_set(v,'{xpGun}',case when v#>>'{xpGun,tarih}'=today
 then v->'xpGun' else jsonb_build_object('tarih',today,'xp',0) end);
 v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(coalesce((v#>>'{xpGun,xp}')::numeric,0)+gain_xp));
 update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
 update public.students set gold=(v->>'altin')::numeric where id=actor;
 return jsonb_build_object('xp',gain_xp,'gold',gain_gold,'tier',new_tier,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_mail_capture_league()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 insert into public.dm_mail_league_snapshots(week_start,board)
 values(date_trunc('week',now() at time zone 'Europe/Istanbul')::date,public.dm_progress_league()) on conflict do nothing;
 delete from public.dm_mail_league_snapshots where captured_at<now()-interval '15 days';
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_mail_escape(v text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select replace(replace(replace(coalesce(v,''),'&','&amp;'),'<','&lt;'),'>','&gt;') $function$
;

CREATE OR REPLACE FUNCTION public.dm_mail_league_card(sid uuid, moment text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare w date:=date_trunc('week',now() at time zone 'Europe/Istanbul')::date;
 board jsonb:=public.dm_progress_league(); prior jsonb; me jsonb; oldme jsonb; passed text; overtakers text;
 result public.dm_weekly_results%rowtype; tier text; reward int:=0; card text; changed text:=''; enabled boolean;
begin
 select x into me from jsonb_array_elements(board) x where x->>'id'=sid::text;
 select s.board into prior from public.dm_mail_league_snapshots s where s.week_start=w and s.captured_at<=now()-interval '1 hour' order by s.captured_at desc limit 1;
 select x into oldme from jsonb_array_elements(coalesce(prior,'[]')) x where x->>'id'=sid::text;
 if me is null then card:='<p>Lig sıralamasına katılmak için 5. seviyeye ulaş. Bir sonraki adım seni bekliyor!</p>';
 else
 tier:=case me->>'league' when 'sampiyon' then 'Şampiyonlar Ligi' when 'super' then 'Süper Lig' else 'Yerel Lig' end;
 if oldme is not null and oldme->>'league'=me->>'league' then
 select string_agg(public.dm_mail_escape(name),', ') into overtakers from (
 select n->>'name' name from jsonb_array_elements(board) n join jsonb_array_elements(prior) o on n->>'id'=o->>'id'
 where n->>'league'=me->>'league' and o->>'league'=oldme->>'league'
 and (n->>'rank')::int<(me->>'rank')::int and (o->>'rank')::int>(oldme->>'rank')::int order by (n->>'rank')::int limit 3) z;
 select string_agg(public.dm_mail_escape(name),', ') into passed from (
 select n->>'name' name from jsonb_array_elements(board) n join jsonb_array_elements(prior) o on n->>'id'=o->>'id'
 where n->>'league'=me->>'league' and o->>'league'=oldme->>'league'
 and (n->>'rank')::int>(me->>'rank')::int and (o->>'rank')::int<(oldme->>'rank')::int order by (n->>'rank')::int limit 3) z;
 if overtakers is not null then changed:=changed||'<p>⚡ <b>'||overtakers||'</b> seni geçti! Kısa bir ders veya oyunla yeniden yükselmek için güzel bir fırsat.</p>';end if;
 if passed is not null then changed:=changed||'<p>🚀 Harika ilerleme! <b>'||passed||'</b> adlı oyuncuyu/oyuncuları geçtin. Kendi öğrenme ritmini koru!</p>';end if;
 if (me->>'rank')::int<>(oldme->>'rank')::int then changed:=changed||'<p>Önceki kayıt: <b>'||(oldme->>'rank')||'.</b> → Şimdi: <b>'||(me->>'rank')||'.</b></p>';end if;
 elsif oldme is not null then changed:='<p>🌟 Ligin değişti! Güncel ligin: <b>'||tier||'</b>.</p>';
 end if;
 select coalesce(bool_and(f.enabled),true) into enabled from public.dm_release_flags f where f.code in ('lig','lig_odul');
 if enabled and (me->>'xp')::numeric>0 then
 if me->>'league'='sampiyon' and (me->>'rank')::int<=10 then reward:=(array[500,350,250,180,140,110,90,75,60,50])[(me->>'rank')::int];
 elsif me->>'league'='super' and (me->>'rank')::int<=2 then reward:=(array[30,20])[(me->>'rank')::int];end if;end if;
 card:='<p>🏆 <b>'||tier||'</b> · Sıran: <b>'||(me->>'rank')||'.</b> · Haftalık XP: <b>'||(me->>'xp')||'</b></p>';
 if reward>0 then card:=card||'<p>🪙 Bu sırayla haftayı tamamlarsan: <b>'||reward||' altın</b>. Bu tahmindir; kesin ödül hafta sonunda belirlenir.</p>';
 elsif me->>'league'='yerel' and (me->>'xp')::numeric>0 then card:=card||'<p>🏅 Bu haftaki katılımınla katılım rozeti adayı oldun.</p>';
 else card:=card||'<p>Yeni kelimeler öğrenerek ilerle; mevcut sıran için altın ödülü görünmüyor.</p>';end if;
 end if;
 if moment='monday' then
 select * into result from public.dm_weekly_results r where r.student_id=sid and r.week_start=w-7;
 if found then card:='<p>📋 <b>Geçen haftanın kesin sonucu:</b> '||
 case result.league when 'sampiyon' then 'Şampiyonlar Ligi' when 'super' then 'Süper Lig' else 'Yerel Lig' end||
' · <b>'||result.rank_no||'. sıra</b> · '||result.xp||' XP</p><p>🎁 Kesinleşen ödül: <b>'||result.gold||' altın · '||result.energy||' enerji</b>'||
 case when coalesce((result.summary->>'participationBadge')::boolean,false) then ' ve katılım rozeti' else '' end||
 case when result.awarded_at is null and (result.gold>0 or result.energy>0) then '. Ödülünü almak için uygulamaya gir.' else '.' end||'</p>'||card;
 end if;end if;
 return '<div style="background:#fff7df;border:2px solid #f4bd43;border-radius:16px;padding:18px;margin:16px 0"><h3>🏆 Sana özel lig özeti</h3>'||card||changed||'</div>';
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_mail_slot()
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ declare d date:=(now() at time zone 'Europe/Istanbul')::date; n int; begin insert into public.dm_mail_budget(day) values(d) on conflict do nothing; update public.dm_mail_budget set attempts=attempts+1 where day=d and attempts<240 returning attempts into n; return n is not null; end $function$
;

CREATE OR REPLACE FUNCTION public.dm_match_action(actor uuid, match_id uuid, action text, arg jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare m public.dm_matches;me public.students;them public.students; qs jsonb; pool jsonb;start_at timestamptz;ans jsonb;q jsonb;idx integer;sel integer;elapsed numeric;ra jsonb;rb jsonb;result jsonb;v jsonb;day text;n integer;mul numeric;gold integer;xp integer;
begin
 if action='create' then
  select * into me from public.students where id=actor and status='approved';select * into them from public.students where id=(arg->>'target')::uuid and status='approved';
  if me.id is null or them.id is null or me.id=them.id then raise exception 'Geçersiz rakip.';end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me.id::text,them.id::text)||greatest(me.id::text,them.id::text),0));
  if public.dm_blocked(me.id,them.id) then raise exception 'Bu kişiyle iletişim kapalı.';end if;
  select count(*) into n from public.dm_matches where player_a=actor and created_at>now()-interval '24 hours';if n>=10 then raise exception 'Bugünkü 10 karşılaşma hakkını kullandın.';end if;
  if arg->>'game'='rota' then
   select jsonb_agg(jsonb_build_object('word',english,'answer',turkish)) into pool from (select distinct english,turkish from public.word_bank where active and class_no=least(me.class_no,them.class_no) and position(' ' in trim(english))>0 and length(turkish)<140 order by english limit 400) s;
  else
   select jsonb_agg(jsonb_build_object('word',english,'answer',turkish)) into pool from (select distinct english,turkish from public.word_bank where active and class_no=least(me.class_no,them.class_no) order by english limit 500) s;
  end if;
  if coalesce(jsonb_array_length(pool),0)<12 then raise exception 'Bu sınıfta 12 soruluk yeterli havuz yok.';end if;
  select jsonb_agg(p) into qs from (select p from (select distinct on (x->>'word') x p from jsonb_array_elements(pool) x order by x->>'word') u order by random() limit 12) picked;
  if jsonb_array_length(qs)<>12 then raise exception '12 farklı soru gerekiyor.';end if;
  select jsonb_agg(jsonb_set(x,'{choices}',(select jsonb_agg(txt order by random()) from (select x->>'answer' txt union all select txt from (select txt from (select distinct y->>'answer' txt from jsonb_array_elements(pool) y where y->>'answer'<>x->>'answer') d order by random() limit 5) wrong) opts))) into qs from jsonb_array_elements(qs) x;
  select jsonb_agg(x||jsonb_build_object('puanSurum',3)) into qs from jsonb_array_elements(qs) x;
  insert into public.dm_matches(player_a,player_b,game,mode,class_no,questions) values(actor,them.id,arg->>'game',arg->>'mode',least(me.class_no,them.class_no),qs) returning * into m;
  insert into public.notifications(recipient_student_id,sender_student_id,type,message,payload) values(them.id,actor,'oyunDavet',case when m.mode='live' then 'Aynı anda oynayalım: ' else '24 saatlik karşılaşma: ' end||case when m.game='ucus' then 'Kelime Uçuşu 🪽' else 'Cümle Rotası 🧩' end,jsonb_build_object('matchId',m.id));
 else
  select * into m from public.dm_matches where id=match_id and actor in(player_a,player_b) for update;
  if m.id is null then raise exception 'Karşılaşma bulunamadı.';end if;
 end if;
 if m.status in ('cancelled','expired') then return jsonb_build_object('ok',true,'id',m.id,'status',m.status);end if;
 if public.dm_blocked(m.player_a,m.player_b) then update public.dm_matches set status='cancelled' where id=m.id;return jsonb_build_object('ok',true,'id',m.id,'status','cancelled');end if;
 if m.expires_at<now() and m.status<>'finished' then update public.dm_matches set status='expired' where id=m.id;return jsonb_build_object('ok',true,'id',m.id,'status','expired');end if;
 if action='ready' and m.status<>'finished' then
  if actor=m.player_a then m.ready_a:=true;else m.ready_b:=true;end if;
  if m.mode='live' and m.ready_a and m.ready_b and m.start_a is null then
   perform 1 from public.students where id in(m.player_a,m.player_b) order by id for update;
   perform public.dm_match_energy(m.player_a);perform public.dm_match_energy(m.player_b);
   m.start_a:=now()+interval '5 seconds';m.start_b:=m.start_a;m.status:='playing';
  elsif m.mode='async' then
   if actor=m.player_a and m.start_a is null then perform public.dm_match_energy(actor);m.start_a:=now()+interval '3 seconds';elsif actor=m.player_b and m.start_b is null then perform public.dm_match_energy(actor);m.start_b:=now()+interval '3 seconds';end if;m.status:='playing';
  end if;
 end if;
 start_at:=case when actor=m.player_a then m.start_a else m.start_b end;
 ans:=case when actor=m.player_a then m.answers_a else m.answers_b end;
 elapsed:=case when start_at is null then -999 else extract(epoch from now()-start_at) end;idx:=floor(elapsed/12);
 if action='answer' then
  if idx<0 or idx>=jsonb_array_length(m.questions) or (arg->>'index')::integer<>idx or ans ? idx::text then raise exception 'Bu sorunun süresi doldu veya cevaplandı.';end if;
  q:=m.questions->idx;sel:=(arg->>'choice')::integer;
  if sel<0 or sel>=jsonb_array_length(q->'choices') then raise exception 'Geçersiz cevap.';end if;
  ans:=jsonb_set(ans,array[idx::text],jsonb_build_object('answer',q->'choices'->>sel,'ms',floor((elapsed-idx*12)*1000)));
  if actor=m.player_a then m.answers_a:=ans;else m.answers_b:=ans;end if;
 end if;
 if m.start_a is not null and now()>=m.start_a+make_interval(secs=>12*jsonb_array_length(m.questions)) and m.result_a is null then m.result_a:=public.dm_round_score(m.answers_a,m.questions);end if;
 if m.start_b is not null and now()>=m.start_b+make_interval(secs=>12*jsonb_array_length(m.questions)) and m.result_b is null then m.result_b:=public.dm_round_score(m.answers_b,m.questions);end if;
 -- Persist each player's ordinary game reward once; replay and polling cannot award twice.
 for n in 0..1 loop
  result:=case when n=0 then m.result_a else m.result_b end;
  if result is not null and not (result ? 'reward') then
   insert into public.extra_data(student_id,key_name,value) values(case when n=0 then m.player_a else m.player_b end,'yo','{}') on conflict(student_id,key_name) do nothing;
   select value into v from public.extra_data where student_id=case when n=0 then m.player_a else m.player_b end and key_name='yo' for update;
   if jsonb_typeof(v)='string' then v:=(v#>>'{}')::jsonb;end if;
   day:=(now() at time zone 'Europe/Istanbul')::date::text;
   idx:=case when v#>>'{oyunGun,t}'=day then coalesce((v#>>'{oyunGun,n}')::integer,0)+1 else 1 end;mul:=case when idx<=3 then 2 when idx>12 then .5 else 1 end;
   gold:=round((case (result->>'yildiz')::integer when 3 then 10 when 2 then 7 else 4 end)*mul);xp:=round((case when result->>'puanSurum'='3' then (result->>'xp')::numeric else case (result->>'yildiz')::integer when 3 then 50 when 2 then 35 else 20 end end)*mul);
   v:=jsonb_set(v,'{altin}',to_jsonb(coalesce((v->>'altin')::numeric,0)+gold));v:=jsonb_set(v,'{xp}',to_jsonb(coalesce((v->>'xp')::numeric,0)+xp));
   v:=jsonb_set(v,'{xpGun}',jsonb_build_object('tarih',day,'xp',case when v#>>'{xpGun,tarih}'=day then coalesce((v#>>'{xpGun,xp}')::numeric,0)+xp else xp end));
   v:=jsonb_set(v,'{log}',jsonb_set(coalesce(v->'log','{}'),array[day],to_jsonb(coalesce((v->'log'->>day)::numeric,0)+xp)));
   v:=jsonb_set(v,'{oyunGun}',jsonb_build_object('t',day,'n',idx));v:=jsonb_set(v,'{guncelleme}',to_jsonb(floor(extract(epoch from clock_timestamp())*1000)));
   if v ? 'lig' then v:=jsonb_set(v,'{lig,xp}',to_jsonb(coalesce((v#>>'{lig,xp}')::numeric,0)+xp));end if;
   update public.extra_data set value=v,updated_at=now() where student_id=case when n=0 then m.player_a else m.player_b end and key_name='yo';
   insert into public.game_scores(game_key,student_id,student_name,class_no,score,correct_count,wrong_count,duration_seconds,played_on,extra) select m.game,id,username,m.class_no,(result->>'puan')::numeric,(result->>'dogru')::integer,(result->>'yanlis')::integer,ceil((result->>'sure')::numeric),current_date,jsonb_build_object('v',coalesce((result->>'puanSurum')::integer,2),'matchId',m.id) from public.students where id=case when n=0 then m.player_a else m.player_b end;
   result:=result||jsonb_build_object('reward',jsonb_build_object('gold',gold,'xp',xp));if n=0 then m.result_a:=result;else m.result_b:=result;end if;
  end if;
 end loop;
 if m.result_a is not null and m.result_b is not null then m.status:='finished';end if;
 update public.dm_matches set ready_a=m.ready_a,ready_b=m.ready_b,start_a=m.start_a,start_b=m.start_b,status=m.status,answers_a=m.answers_a,answers_b=m.answers_b,result_a=m.result_a,result_b=m.result_b where id=m.id;
 idx:=floor(elapsed/12);q:=case when idx between 0 and jsonb_array_length(m.questions)-1 then m.questions->idx else null end;
 ra:=case when actor=m.player_a then m.result_a else m.result_b end;rb:=case when actor=m.player_a then m.result_b else m.result_a end;
 return jsonb_build_object('ok',true,'id',m.id,'game',m.game,'mode',m.mode,'status',m.status,'serverNow',now(),'start',start_at,'ready',case when actor=m.player_a then m.ready_a else m.ready_b end,'opponentReady',case when actor=m.player_a then m.ready_b else m.ready_a end,'index',idx,'total',jsonb_array_length(m.questions),'seconds',greatest(0,ceil(12-mod(greatest(elapsed,0),12))),'question',case when q is null then null else q-'answer' end,'answered',ans ? idx::text,'feedback',case when ans ? idx::text then q->>'answer' else null end,'myScore',(case when m.questions->0->>'puanSurum'='3' then public.dm_round_score_v3(ans,m.questions,false) else public.dm_round_score(ans,m.questions) end)->'puan','myResult',ra,'opponentResult',rb,'opponent',(select username from public.students where id=case when actor=m.player_a then m.player_b else m.player_a end));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_match_energy(actor uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare s public.students; available integer; ticks integer;
begin
 select * into s from public.students where id=actor for update;
 ticks:=greatest(0,floor(extract(epoch from now()-coalesce(s.energy_updated_at,now()))/900));
 available:=least(s.energy_max,s.energy+ticks);
 if available<4 then raise exception 'Bu karşılaşma için 4 enerji gerekiyor.';end if;
 update public.students set energy=available-4,energy_updated_at=case when available=s.energy_max then now() else coalesce(s.energy_updated_at,now())+ticks*interval '15 minutes' end where id=actor;
 insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,-4,available-4,'iki kişilik oyun · 8 soru');
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_mission_summary(actor uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with bounds as (
 select (now() at time zone 'Europe/Istanbul')::date d,date_trunc('week',now() at time zone 'Europe/Istanbul')::date w
), periods as (select 'daily' p,d b,d+1 e from bounds union all select 'weekly',w,w+7 from bounds),
routes as (
 select completed_at from public.level_completions where student_id=actor
 union all select completed_at from public.dm_route_mission_completions where student_id=actor
), reviews as (
 select (value->>'lastReviewedAt')::timestamptz t from public.extra_data where student_id=actor and key_name like 'review_word:%' and value->>'lastReviewedAt' ~ '^\d{4}-\d{2}-\d{2}T'
), active as (
 select (completed_at at time zone 'Europe/Istanbul')::date d from routes
 union select (created_at at time zone 'Europe/Istanbul')::date from public.game_scores where student_id=actor
 union select (t at time zone 'Europe/Istanbul')::date from reviews
), result as (
 select p,jsonb_build_object(
 'route',(select count(*) from routes where completed_at>=b::timestamp at time zone 'Europe/Istanbul' and completed_at<e::timestamp at time zone 'Europe/Istanbul'),
 'game',(select count(*) from public.game_scores where student_id=actor and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<e::timestamp at time zone 'Europe/Istanbul'),
 'review',(select count(*) from reviews where t>=b::timestamp at time zone 'Europe/Istanbul' and t<e::timestamp at time zone 'Europe/Istanbul'),
 'days',(select count(*) from active where d>=b and d<e)) v from periods
) select jsonb_object_agg(p,v) from result;
$function$
;

CREATE OR REPLACE FUNCTION public.dm_oral_draw(actor uuid, pupil uuid, grade integer, unit_id integer, request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t public.teachers;s public.students;q public.dm_oral_questions;w record;
begin
 select * into t from public.teachers where id=actor and active is not false;
 if not found then raise exception 'Aktif öğretmen hesabı gerekli.';end if;
 select * into s from public.students where id=pupil and status='approved' and role='student' for update;
 if not found or (not coalesce(t.is_admin,false) and s.teacher_id is distinct from actor) then raise exception 'Bu öğrenciye erişim yetkiniz yok.';end if;
 if grade not between 1 and 8 or grade is null or s.class_no is distinct from grade or unit_id is null or unit_id not between 1 and 100 then raise exception 'Öğrenci sınıfı ve ünite seçimini kontrol edin.';end if;
 select * into q from public.dm_oral_questions where id=request_id;
 if found then
  if q.teacher_id is distinct from actor or q.student_id<>pupil or q.class_no<>grade or q.unit_no<>unit_id then raise exception 'Geçersiz soru isteği.';end if;
  if q.status='pending' then
   if q.expires_at is null then update public.dm_oral_questions set expires_at=clock_timestamp()+interval '15 seconds' where id=q.id returning * into q;end if;
  end if;
  return jsonb_build_object('ok',true,'question',to_jsonb(q));
 end if;
 select * into q from public.dm_oral_questions where teacher_id=actor and student_id=pupil and class_no=grade and unit_no=unit_id and status='pending' order by created_at limit 1;
 if found then if q.status='pending' then
   if q.expires_at is null then update public.dm_oral_questions set expires_at=clock_timestamp()+interval '15 seconds' where id=q.id returning * into q;end if;
  end if;
  return jsonb_build_object('ok',true,'question',to_jsonb(q));end if;
 select b.english,b.turkish,lower(regexp_replace(btrim(b.english),'\s+',' ','g')) as word_key into w
 from public.word_bank b where b.active and b.class_no=grade and b.unit_no=unit_id
 and nullif(btrim(b.english),'') is not null and nullif(btrim(b.turkish),'') is not null
 and not exists(select 1 from public.dm_oral_questions h where h.student_id=pupil and h.word_key=lower(regexp_replace(btrim(b.english),'\s+',' ','g')))
 order by random() limit 1;
 if not found then return jsonb_build_object('ok',true,'exhausted',true,'mesaj','Bu ünitedeki tüm kelimeler bu öğrenciye soruldu. Başka bir ünite seçin.');end if;
 insert into public.dm_oral_questions(id,teacher_id,student_id,class_no,unit_no,word_key,english,turkish)
 values(request_id,actor,pupil,grade,unit_id,w.word_key,w.english,w.turkish) returning * into q;
 return jsonb_build_object('ok',true,'question',to_jsonb(q));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_oral_grade(actor uuid, question_id uuid, known boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare delta int;answer_known boolean;expired boolean; t public.teachers;s public.students;q public.dm_oral_questions;v jsonb;ver bigint;day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
begin
 select * into t from public.teachers where id=actor and active is not false;
 if not found then raise exception 'Aktif öğretmen hesabı gerekli.';end if;
 select * into q from public.dm_oral_questions where id=question_id and teacher_id=actor;
 if not found or known is null then raise exception 'Soru bulunamadı.';end if;
 select * into s from public.students where id=q.student_id and status='approved' and role='student' for update;
 if not found or (not coalesce(t.is_admin,false) and s.teacher_id is distinct from actor) then raise exception 'Bu öğrenciye erişim yetkiniz yok.';end if;
 select * into q from public.dm_oral_questions where id=question_id for update;
 if q.status<>'pending' then return jsonb_build_object('ok',true,'alreadyGraded',true,'xp',q.xp,'question',to_jsonb(q));end if;
 expired:=q.expires_at is not null and clock_timestamp()>=q.expires_at;
 answer_known:=known;
  select value into v from public.extra_data where student_id=s.id and key_name='yo' for update;
  if v is null then raise exception 'Öğrenci hesap bilgileri hazır değil.';end if;
  delta:=case when answer_known then 100 else -least(100,greatest(0,coalesce((v->>'totalXp')::numeric,0)))::int end;
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)+delta,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
  v:=jsonb_set(v,'{xpGun}',case when v#>>'{xpGun,tarih}'=day then v->'xpGun' else jsonb_build_object('tarih',day,'xp',0) end);
  v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(coalesce((v#>>'{xpGun,xp}')::numeric,0)+delta));
  v:=jsonb_set(v,'{log}',coalesce(v->'log','{}'));v:=jsonb_set(v,array['log',day],to_jsonb(coalesce((v#>>array['log',day])::numeric,0)+delta));
  update public.extra_data set value=v,updated_at=now() where student_id=s.id and key_name='yo';
 update public.dm_oral_questions set status=case when answer_known then 'correct' else 'wrong' end,xp=delta,timed_out=expired,graded_at=now() where id=question_id returning * into q;
 return jsonb_build_object('ok',true,'xp',q.xp,'question',to_jsonb(q));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_pair_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a uuid; b uuid;
begin
 if tg_table_name='feed_events' then a:=new.student_id;b:=new.target_student_id;
 elsif tg_table_name='duels' then a:=new.sender_student_id;b:=new.receiver_student_id;
 else a:=new.sender_student_id;b:=new.recipient_student_id;end if;
 if a is not null and b is not null then
  perform pg_advisory_xact_lock(hashtextextended(least(a::text,b::text)||greatest(a::text,b::text),0));
  if public.dm_blocked(a,b) then raise exception 'Bu kişiyle iletişim kapalı.';end if;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_chat(actor uuid, action text, arg jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare pd date:=(now() at time zone 'Europe/Istanbul')::date; gd date:=(now() at time zone 'UTC')::date;
 used int; attempts int; requests int; people int; blocked boolean; rid uuid; old public.dm_papi_chat_turns%rowtype;
 cefr text; lvl int; history jsonb;
begin
 if not exists(select 1 from public.students where id=actor and role='student' and status='approved') then return jsonb_build_object('ok',false,'code','auth');end if;
 select public.dm_student_level(coalesce((value->>'totalXp')::numeric,0)) into lvl from public.extra_data where student_id=actor and key_name='yo';
 if coalesce(lvl,1)<20 then return jsonb_build_object('ok',false,'code','level','minimumLevel',20);end if;
 select value->>'level' into cefr from public.extra_data where student_id=actor and key_name='placement_cefr_v2';
 if cefr is null or cefr not in ('A1','A2','B1','B2') then cefr:='A1';end if;
 perform pg_advisory_xact_lock(hashtextextended('dm_papi_chat:'||gd,0));
 update public.dm_papi_chat_turns set state='failed' where state='pending' and created_at<now()-interval '90 seconds';
 select count(*) filter(where state<>'failed'),count(*) into used,attempts from public.dm_papi_chat_turns where student_id=actor and personal_day=pd;
 select coalesce(b.blocked,false) into blocked from public.dm_papi_chat_budget b where day=gd;
 select count(*),count(distinct student_id) into requests,people from public.dm_papi_chat_turns where global_day=gd;
 if action='status' then return jsonb_build_object('ok',true,'remaining',greatest(0,5-used),'limit',5,'level',cefr,'day',pd,'globalAvailable',not coalesce(blocked,false) and requests<500 and (people<100 or exists(select 1 from public.dm_papi_chat_turns where global_day=gd and student_id=actor)));end if;
 rid:=(arg->>'requestId')::uuid;
 select * into old from public.dm_papi_chat_turns where student_id=actor and request_id=rid;
 if action='reserve' then
  if old.request_id is not null then
   if old.request_hash<>arg->>'hash' then return jsonb_build_object('ok',false,'code','conflict');end if;
   return jsonb_build_object('ok',true,'state',old.state,'result',old.result,'remaining',greatest(0,5-used),'level',cefr);
  end if;
  if used>=5 or attempts>=10 then return jsonb_build_object('ok',false,'code','daily_limit','remaining',greatest(0,5-used));end if;
  if coalesce(blocked,false) or requests>=500 or (people>=100 and not exists(select 1 from public.dm_papi_chat_turns where global_day=gd and student_id=actor)) then return jsonb_build_object('ok',false,'code','global_limit');end if;
  if exists(select 1 from public.dm_papi_chat_turns where student_id=actor and (state='pending' or created_at>now()-interval '5 seconds')) then return jsonb_build_object('ok',false,'code','busy');end if;
  insert into public.dm_papi_chat_turns(student_id,request_id,request_hash,topic,input_text) values(actor,rid,arg->>'hash',arg->>'topic',arg->>'text');
  select coalesce(jsonb_agg(jsonb_build_object('text',t.input_text,'reply',t.result->>'reply') order by t.created_at),'[]') into history from (select input_text,result,created_at from public.dm_papi_chat_turns where student_id=actor and personal_day=pd and topic=arg->>'topic' and state='done' order by created_at desc limit 2) t;
  return jsonb_build_object('ok',true,'state','reserved','remaining',greatest(0,4-used),'level',cefr,'history',history);
 elsif action in ('finish','fail','quota') then
  if old.request_id is null then return jsonb_build_object('ok',false,'code','missing');end if;
  if old.state='pending' then update public.dm_papi_chat_turns set state=case when action='finish' then 'done' else 'failed' end,result=case when action='finish' then arg->'result' else null end where student_id=actor and request_id=rid;end if;
  if action='quota' then insert into public.dm_papi_chat_budget values(gd,true) on conflict(day) do update set blocked=true;end if;
  return jsonb_build_object('ok',true);
 end if;
 return jsonb_build_object('ok',false,'code','action');
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_confirm_subscription(raw_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c record;
begin
 if length(coalesce(raw_token,''))<>64 or raw_token !~ '^[a-f0-9]{64}$' then return false;end if;
 update public.dm_papi_mail_confirmations set used_at=now() where token_hash=md5(raw_token)
 and used_at is null and expires_at>now()
 returning student_id,recipient_kind,email into c;
 if not found then return false;end if;
 insert into public.dm_progress_mail_preferences(student_id,recipient_kind,email,opted_in_at,verified_at,unsubscribe_token_hash,consent_source)
 values(c.student_id,c.recipient_kind,c.email,now(),now(),md5(raw_token),'email_double_opt_in')
 on conflict(student_id,recipient_kind,email) do update set opted_in_at=now(),verified_at=now(),unsubscribed_at=null,consent_source='email_double_opt_in';
 return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_issue_confirmation(sid uuid, kind text, addr text, raw_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if kind not in ('student','parent') or length(coalesce(raw_token,''))<>64 or raw_token !~ '^[a-f0-9]{64}$' then return false;end if;
 if exists(select 1 from public.dm_papi_mail_confirmations where student_id=sid and recipient_kind=kind and lower(email)=lower(addr) and created_at>now()-interval '60 minutes') then return false;end if;
 insert into public.dm_papi_mail_confirmations(token_hash,student_id,recipient_kind,email,expires_at)
 values(md5(raw_token),sid,kind,lower(addr),now()+interval '48 hours');
 return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_league_mail_prepare(moment text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p record; today_tr date:=(now() at time zone 'Europe/Istanbul')::date; n int:=0; cap int; mail_token text; heading text; para text; color text; content text; mail_kind text;
begin
 perform public.dm_sync_registered_mail_recipients();
 if moment not in ('sunday','monday') then return 0; end if;
 mail_kind:='papi_league_'||moment;
 select greatest(0,least(240,
  240-coalesce((select count(*) from public.dm_papi_progress_outbox where (created_at at time zone 'Europe/Istanbul')::date=today_tr),0),
  240-coalesce((select attempts from public.dm_mail_budget where day=today_tr),0)
 )) into cap;
 cap:=100000;
 if moment='sunday' then
  heading:='Papi hatırlatıyor: Lig haftası bitiyor!';
  para:='Bu gece ligler yenileniyor. Öğrendiklerin ve gösterdiğin çaba değerli! Yeni haftada seni yepyeni kelimeler ve maceralar bekliyor.';
  color:='#7c3aed';
 else
  heading:='🌟 Yeni lig haftası başladı, hazır mısın?';
  para:='Yeni hafta yeni bir başlangıç! İngilizceni küçük adımlarla geliştirebilir, oyun ve derslerle kendi ilerlemeni görebilirsin.';
  color:='#0f766e';
 end if;
 for p in
  select pr.student_id,pr.recipient_kind,pr.email from public.dm_progress_mail_preferences pr
  join public.students s on s.id=pr.student_id
  where s.role='student' and s.status='approved' and pr.opted_in_at is not null and pr.unsubscribed_at is null
  and not exists(select 1 from public.dm_papi_progress_outbox o where lower(btrim(o.to_email))=lower(btrim(pr.email)) and o.report_date=today_tr and o.kind=mail_kind)
  order by md5(pr.student_id::text||pr.recipient_kind||today_tr::text)
  limit cap
 loop
  mail_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  insert into public.dm_papi_unsubscribe_tokens(token_hash,student_id,email) values(md5(mail_token),p.student_id,p.email) on conflict do nothing;
  content:='<div style="max-width:610px;margin:auto;padding:24px;background:#f7faff;color:#334155;font:16px/1.6 Arial,sans-serif"><div style="background:'||color||';color:white;padding:25px;border-radius:20px;text-align:center"><img src="https://ogretmencocuk.com/papi-reward-v2.png" width="120" height="120" alt="Diji Medu Türkçe Papi" style="display:block;margin:0 auto 12px;max-width:100%;object-fit:contain;border:0"><h1>Diji Medu Türkçe</h1><h2>'||heading||'</h2></div><div style="background:white;padding:26px;border-radius:20px;margin-top:15px"><p>'||para||'</p><p>📖 Yeni kelimeler • 🎮 İngilizce oyunları • 🗺️ Macera Haritası</p><p style="text-align:center"><a href="https://ogretmencocuk.com" style="display:inline-block;background:'||color||';color:white;padding:13px 20px;border-radius:13px;text-decoration:none">PAPİ İLE ÖĞRENMEYE DEVAM ET</a></p></div><p style="text-align:center;font-size:11px;color:#64748b">Bu e-postaları almak istemiyorsan <a style="color:#64748b" href="https://isgnsmkboehygxxysria.supabase.co/functions/v1/papi-progress-unsubscribe?token='||mail_token||'">abonelikten çık</a>.</p></div>';
  content:=replace(content,'<p>📖',public.dm_mail_league_card(p.student_id,moment)||'<p>📖');
 insert into public.dm_papi_progress_outbox(student_id,recipient_kind,to_email,subject,html,text_body,kind,report_date,send_after)
  values(p.student_id,p.recipient_kind,p.email,heading,replace(content,chr(92)||chr(34),chr(34)),para||' https://ogretmencocuk.com',mail_kind,today_tr,now())
  on conflict do nothing;
  n:=n+1;
 end loop;
 return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_mail_result(mail_id bigint, sent boolean, problem text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare s uuid;addr text;kind text; 
begin
 update public.dm_papi_progress_outbox q
 set sent_at=case when sent then now() else null end,
 error=case when sent then null else left(coalesce(problem,'Failed'),250) end
 where q.id=mail_id and q.claimed_at is not null
 returning q.student_id,q.to_email,q.recipient_kind into s,addr,kind;
 if not found then return false;end if;
 if sent then update public.dm_progress_mail_preferences p set last_sent_at=now()
 where p.student_id=s and p.recipient_kind=kind and lower(p.email)=lower(addr);end if;
 return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_progress_queue()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p record; v_day date:=(now() at time zone 'Europe/Istanbul')::date; cap int; n int:=0; games int; lessons int; parks int; seconds_total int; gain_xp int; previous_xp int; intro text; html_content text; mail_token text; mail_subject text; theme_color text; variant int; message_text text;
begin
 perform public.dm_sync_registered_mail_recipients();
 -- Hold 30 of the 200 daily sends for security and account email.
 select greatest(0,least(240,240-coalesce((select count(*) from public.dm_papi_progress_outbox where (created_at at time zone 'Europe/Istanbul')::date=v_day),0),240-coalesce((select attempts from public.dm_mail_budget where day=v_day),0)-coalesce((select count(*) from public.dm_papi_progress_outbox where sent_at is null and attempts<5 and send_after<=now() and kind<>'papi_progress'),0))) into cap;
 if cap<=0 then return 0;end if;
 for p in
 select pref.student_id,pref.recipient_kind,pref.email,s.username,s.streak,s.total_seconds
 from public.dm_progress_mail_preferences pref join public.students s on s.id=pref.student_id
 where s.role='student' and s.status='approved' and pref.opted_in_at is not null and pref.unsubscribed_at is null
   and not exists(select 1 from public.dm_papi_progress_outbox recent where recent.student_id=pref.student_id and ((recent.sent_at at time zone 'Europe/Istanbul')::date >= v_day-1 or (recent.sent_at is null and recent.attempts<5)))
 and not exists (select 1 from public.dm_papi_progress_outbox x where x.kind='papi_progress' and lower(btrim(x.to_email))=lower(btrim(pref.email)) and ((x.sent_at is not null and x.sent_at>now()-interval '7 days') or (x.sent_at is null and x.attempts<5))) and (pref.last_queued_at is null or pref.last_queued_at<=now()-interval '7 days')
   and not exists(select 1 from public.dm_papi_progress_outbox q where q.student_id=pref.student_id and q.kind='papi_progress' and lower(q.to_email)=lower(pref.email) and q.sent_at is null and q.attempts<5)
 order by pref.last_queued_at asc nulls first,pref.student_id
 limit least(cap,greatest(0,15-(select count(*)::int from public.dm_papi_progress_outbox daily where daily.kind='papi_progress' and daily.report_date=v_day)))
 loop
  select count(*),coalesce(sum(duration_seconds),0) into games,seconds_total from public.game_scores where student_id=p.student_id and created_at>=now()-interval '7 days';
  select count(*) into lessons from public.lesson_progress where student_id=p.student_id and test_success and completed_at>=now()-interval '7 days';
  select count(*) into parks from public.level_completions where student_id=p.student_id and mode='buyu' and completed_at>=now()-interval '7 days';
  select coalesce(sum((value#>>'{xpGun,xp}')::numeric),0)::int into gain_xp from public.extra_data where student_id=p.student_id and key_name='yo';
  variant:=mod(abs(hashtext(p.student_id::text||':'||p.recipient_kind||':'||(floor(extract(epoch from now())/259200))::text)),8);
  if games+lessons+parks=0 then
    mail_subject:=(array['Nerede kaldın? Papi seni merak etti!','🌿 Unuttun mu bizi? Yeni kelimeler bekliyor!','💚 Özledik seni! Kısa bir İngilizce molası?','✨ Papi''den küçük bir merhaba','🚀 Hadi kaldığımız yerden devam edelim','🎒 Macera Haritası seni bekliyor','🎯 Bugün tek bir kelime öğrenmeye ne dersin?','🌈 İngilizce yolculuğun hâlâ burada'])[variant+1];
    message_text:='Görüşmeyeli biraz zaman oldu. Sadece birkaç dakika ayırsan bile Papi seninle yeniden İngilizce keşfetmeye hazır!';
  else
    mail_subject:=(array['🌟 Papi''den haftalık başarı haberi!','Harika gidiyorsun, devam!','📚 İngilizce hazinen büyüyor!','🎮 Oyunlardan öğrenmeye: İşte gelişimin','🗺️ Yeni maceralara hazır mısın?','🔥 Öğrenme ritmini birlikte koruyalım','💫 Bu hafta neler başardın?','🏅 Papi seninle gurur duyuyor!'])[variant+1];
    message_text:='Bu hafta oyunlar, dersler ve maceralarla güzel adımlar attın. İşte kendi öğrenme yolculuğundan gerçek rakamlar!';
  end if;
  intro:=mail_subject;
  theme_color:=(array['#15803d','#7c3aed','#0369a1','#ea580c','#0f766e','#be185d','#4338ca','#b45309'])[variant+1];
  mail_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  update public.dm_progress_mail_preferences set unsubscribe_token_hash=md5(mail_token) where student_id=p.student_id and recipient_kind=p.recipient_kind and email=p.email;
  insert into public.dm_papi_unsubscribe_tokens(token_hash,student_id,email) values(md5(mail_token),p.student_id,p.email) on conflict do nothing;
  html_content:='<div style="max-width:620px;margin:auto;padding:30px 20px;font:16px/1.55 Arial,sans-serif;color:#243447;background:#f5f9ff"><div style="padding:25px;border-radius:22px;background:'||theme_color||';color:white;text-align:center"><img src="https://ogretmencocuk.com/papi-welcome-v2.png" width="112" height="112" alt="Diji Medu Türkçe Papi" style="display:block;margin:0 auto 12px;max-width:100%;object-fit:contain;border:0"><h1 style="margin:8px 0">Diji Medu Türkçe</h1><p style="font-size:20px;margin:0">'||replace(mail_subject,'&','&amp;')||'</p></div><div style="background:white;border-radius:20px;margin-top:16px;padding:22px"><p>'||message_text||'</p><h2 style="color:'||theme_color||'">Senin son 7 günün</h2><table style="width:100%;font-size:16px"><tr><td style="padding:9px">🎮 Oyun</td><td style="text-align:right"><b>'||games||'</b></td></tr><tr><td style="padding:9px">📚 Ders</td><td style="text-align:right"><b>'||lessons||'</b></td></tr><tr><td style="padding:9px">🗺️ Parkur</td><td style="text-align:right"><b>'||parks||'</b></td></tr><tr><td style="padding:9px">⏱️ Oyun süresi</td><td style="text-align:right"><b>'||(seconds_total/60)||' dk</b></td></tr><tr><td style="padding:9px">🔥 Güncel seri</td><td style="text-align:right"><b>'||coalesce(p.streak,0)||' gün</b></td></tr></table><p style="text-align:center;margin:26px 0"><a href="https://ogretmencocuk.com" style="background:'||theme_color||';color:white;text-decoration:none;font-size:16px;font-weight:bold;padding:15px 26px;border-radius:14px">PAPİ İLE DEVAM ET →</a></p></div><p style="text-align:center;font-size:11px;color:#64748b;margin-top:24px">Bu kişisel ilerleme e-postasını almak istemiyorsan <a style="color:#64748b" href="https://isgnsmkboehygxxysria.supabase.co/functions/v1/papi-progress-unsubscribe?token='||mail_token||'">abonelikten çık</a>.</p></div>';
  html_content:=replace(html_content,'<h2 style="',public.dm_mail_league_card(p.student_id,'progress')||'<h2 style="');
 insert into public.dm_papi_progress_outbox(student_id,recipient_kind,to_email,subject,html,text_body,kind,report_date,send_after)
  values(p.student_id,p.recipient_kind,p.email,mail_subject,replace(html_content,chr(92)||chr(34),chr(34)),'Papi ilerleme özeti: '||games||' oyun, '||lessons||' ders, '||parks||' parkur. https://ogretmencocuk.com','papi_progress',v_day,now()+interval '15 minutes')
  on conflict do nothing;
  update public.dm_progress_mail_preferences set last_queued_at=now() where student_id=p.student_id and recipient_kind=p.recipient_kind and email=p.email;
  n:=n+1;
 end loop;
 return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_progress_unsubscribe(raw_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare target record; changed int;
begin
 if length(coalesce(raw_token,''))<>64 or raw_token !~ '^[a-f0-9]{64}$' then return false; end if;
 select t.student_id,t.email into target from public.dm_papi_unsubscribe_tokens t
 where t.token_hash=md5(raw_token) limit 1;
 if not found then return false; end if;
 update public.dm_progress_mail_preferences p set unsubscribed_at=now()
 where p.student_id=target.student_id and lower(p.email)=lower(target.email);
 get diagnostics changed=row_count;
 update public.mail_queue set attempts=5,error='Papi raporu aboneliği kapatıldı.'
 where student_id=target.student_id and lower(to_email)=lower(target.email)
 and kind='papi_progress' and sent_at is null;
 return changed>0;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_remaining_mail_slots()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ select greatest(0,240-coalesce((select attempts from public.dm_mail_budget where day=(now() at time zone 'Europe/Istanbul')::date),0)) $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_take_due()
 RETURNS TABLE(mail_id bigint, student_id uuid, to_email text, subject text, html text, text_body text)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare chosen bigint;
begin
 perform pg_advisory_xact_lock(741918);
 update public.dm_papi_progress_outbox q set attempts=5,error='Permission absent or withdrawn'
 where q.sent_at is null and q.attempts<5 and not public.dm_progress_mail_allowed(q.student_id,q.to_email);
 update public.dm_papi_progress_outbox q
 set send_after=greatest(q.send_after,((r.last_day+2)::timestamp at time zone 'Europe/Istanbul')+interval '8 hours')
 from (select s.student_id,max((s.sent_at at time zone 'Europe/Istanbul')::date) last_day
 from public.dm_papi_progress_outbox s where s.sent_at is not null group by s.student_id) r
 where q.student_id=r.student_id and q.sent_at is null and q.attempts<5 and q.send_after<=now()
 and r.last_day>=(now() at time zone 'Europe/Istanbul')::date-1;
 select q.id into chosen from public.dm_papi_progress_outbox q
 where q.sent_at is null and q.attempts<5 and q.send_after<=now()
 and not exists(select 1 from public.dm_papi_progress_outbox previous where previous.kind=q.kind and lower(btrim(previous.to_email))=lower(btrim(q.to_email)) and previous.id<>q.id and previous.sent_at is not null and (previous.report_date=q.report_date or (q.kind='papi_progress' and previous.sent_at>now()-interval '7 days'))) and not exists(select 1 from public.dm_papi_progress_outbox other where other.student_id=q.student_id and other.id<>q.id and other.claimed_at>now()-interval '30 minutes' and other.sent_at is null)
 order by case when q.kind like 'papi_league_%' then 0 else 1 end,q.send_after,q.id limit 1 for update skip locked;
 if chosen is null then return;end if;
 return query update public.dm_papi_progress_outbox q set attempts=q.attempts+1,claimed_at=now(),send_after=now()+interval '30 minutes'
 where q.id=chosen returning q.id,q.student_id,q.to_email,q.subject,q.html,q.text_body;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_papi_worker_authorized(provided text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
select length(coalesce(provided,''))=64 and exists(
 select 1 from dm_private.dm_papi_worker_secret
 where key_name='mail_worker' and secret=provided)
$function$
;

CREATE OR REPLACE FUNCTION public.dm_parent_report(actor uuid, class_filter integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with auth as (select id,is_admin from public.teachers where id=actor and active), bounds as (select date_trunc('week',now() at time zone 'Europe/Istanbul')::date b), rows as (
 select s.id,s.username,s.class_no,s.branch,s.phone,s.total_seconds,s.streak,s.points,s.xp,s.gold,s.last_login_at,s.profile,
 coalesce(e.value,'{}'::jsonb) yo,b.b,
 coalesce((select xp from public.dm_weekly_xp where student_id=s.id and week_start=b.b),0) weekxp,
 coalesce((select active_days from public.dm_weekly_xp where student_id=s.id and week_start=b.b),0) days
 from public.students s cross join auth a cross join bounds b left join public.extra_data e on e.student_id=s.id and e.key_name='yo'
 where s.status='approved' and s.role='student' and (a.is_admin or s.teacher_id=a.id) and (class_filter is null or s.class_no=class_filter)
)
select coalesce(jsonb_agg(jsonb_build_object(
 'name',r.username,'class',r.class_no,'branch',r.branch,'phone',r.phone,'weekStart',r.b,'weekXP',r.weekxp,'activeDays',r.days,
 'metrics',public.dm_week_metrics(r.id,r.b),'totalXP',r.xp,'gold',r.gold,'points',r.points,'streak',r.streak,'totalSeconds',r.total_seconds,'lastLogin',r.last_login_at,
 'level',r.yo->'seviye','target',r.yo->'hedef','conversation',r.yo->'sohbet','dailyLog',r.yo->'log',
 'difficultWords',(select coalesce(jsonb_agg(z),'[]'::jsonb) from (select d.value z from jsonb_each(case when jsonb_typeof(r.yo->'zk')='object' then r.yo->'zk' else '{}'::jsonb end) d where coalesce((d.value->>'kutu')::int,0)<5 order by coalesce((d.value->>'yanlis')::int,0) desc limit 10) a),
 'learnedWords',(select count(*) from jsonb_each(case when jsonb_typeof(r.yo->'zk')='object' then r.yo->'zk' else '{}'::jsonb end) d where coalesce((d.value->>'kutu')::int,0)>=5),
 'gameDetails',(select coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb) from (select game_key,count(*) games,sum(correct_count) correct,sum(wrong_count) wrong,round(avg(score),1) avg_score,max(score) best_score,sum(duration_seconds) seconds from public.game_scores where student_id=r.id and created_at>=r.b::timestamp at time zone 'Europe/Istanbul' and created_at<(r.b+7)::timestamp at time zone 'Europe/Istanbul' group by game_key) g),
 'totalGames',(select count(*) from public.game_scores where student_id=r.id),
 'topics',(select coalesce(jsonb_agg(to_jsonb(l)),'[]'::jsonb) from (select level,topic_name,test_success,knew_it,completed_at from public.lesson_progress where student_id=r.id order by completed_at desc limit 25) l),
 'totalTopics',(select count(distinct topic_name) from public.lesson_progress where student_id=r.id and test_success),
 'totalLevels',(select count(*) from public.level_completions where student_id=r.id),
 'levels',(select coalesce(jsonb_agg(to_jsonb(l)),'[]'::jsonb) from (select mode,class_no,unit_no,level_no,completed_at from public.level_completions where student_id=r.id order by completed_at desc limit 15) l),
 'reading',(select coalesce(jsonb_agg(to_jsonb(z)),'[]'::jsonb) from (select words_read,duration_seconds,wpm,text_title,created_at from public.reading_results where student_id=r.id order by created_at desc limit 10) z),
 'reports',(select coalesce(jsonb_agg(to_jsonb(t)-'id'-'student_id'-'teacher_id'),'[]'::jsonb) from (select * from public.teacher_reports where student_id=r.id order by report_date desc limit 5) t),
 'homeworks',(select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from (select h.title,h.kind,h.due_date,h.note,x.done_at,x.score,x.stars from public.assignments h left join public.assignment_status x on x.assignment_id=h.id and x.student_id=r.id where h.active and h.class_no=r.class_no and (h.branch is null or h.branch='' or h.branch=r.branch) and (h.teacher_id=(select teacher_id from public.students where id=r.id)) order by h.due_date desc nulls last limit 20) a),
 'videos',(select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) from (select vd.title,sv.watched_at from public.student_videos sv join public.videos vd on vd.id=sv.video_id where sv.student_id=r.id order by sv.watched_at desc nulls last limit 15) v),
 'activities',(select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from (select ac.display_name,sa.status,sa.completed_at,sa.result from public.student_activities sa join public.activities ac on ac.id=sa.activity_id where sa.student_id=r.id order by sa.assigned_at desc limit 15) a),
 'planCompleted',(select count(*) from public.student_plan_progress where student_id=r.id and completed),
 'badges',(select coalesce(jsonb_agg(jsonb_build_object('name',bd.name,'emoji',bd.emoji)),'[]'::jsonb) from public.badges bd where bd.required_points<=r.points and (bd.student_name is null or bd.student_name='' or lower(bd.student_name)='herkes' or bd.student_name=r.username)),
 'latestLeague',(select to_jsonb(z)-'student_id'-'yo' from public.dm_weekly_results z where student_id=r.id order by week_start desc limit 1)
) order by r.username),'[]'::jsonb) from rows r;
$function$
;

CREATE OR REPLACE FUNCTION public.dm_parkur_fair_claim(actor uuid, run_key text, class_id integer, stop_no integer, seconds numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v jsonb; reward jsonb; previous public.dm_game_reward_runs; st public.students;
 rec public.dm_parkur_recovery_runs;
 answered_count int; correct_count int; percentage int:=0;
 raw_x int;raw_g int; adj_x int;adj_g int;ver bigint;
 options text[]; meanings text[]; words_count int; i int; n int; a int; b int; c int;
 deck jsonb:='[]'::jsonb;
 day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
begin
 if actor is null or run_key !~ '^[a-zA-Z0-9_-]{16,100}$'
 or class_id not between 0 and 12 or stop_no not between 200000 and 300000
 or (stop_no-200000)/10000<>class_id or mod(stop_no-200000,100) not between 1 and 99
 or seconds is null or seconds<=0 or seconds>86400 then
 raise exception 'Geçersiz parkur ödül isteği';end if;
 perform 1 from public.students where id=actor for update;
 select * into previous from public.dm_game_reward_runs
 where student_id=actor and run_id=run_key for update;
 if found then
  select value into v from public.extra_data where student_id=actor and key_name='yo';
  return jsonb_build_object('ok',true,'duplicate',true,'xp',previous.xp,'gold',previous.gold,
    'reason','duplicate','yo',v);
 end if;
 select count(*) filter(where answered),count(*) filter(where answered and correct)
 into answered_count,correct_count from public.dm_parkur_question_ledger
 where student_id=actor and run_id=run_key and question_no between 1 and 12;
 if answered_count<>12 then
  return jsonb_build_object('ok',true,'reason','incomplete','xp',0,'gold',0,
   'answered',answered_count,'required',12);
 end if;
 select * into rec from public.dm_parkur_recovery_runs where student_id=actor and run_id=run_key for update;
 if rec.student_id is not null and (rec.stop_no<>stop_no or rec.class_no<>class_id)
 then raise exception 'Pekiştirme kaydı uyuşmuyor';end if;
 if correct_count<8 and not coalesce(rec.completed,false) then
  if rec.student_id is null then
   select array_agg(w.english order by w.english),array_agg(w.turkish order by w.english)
   into options,meanings from (
     select distinct on (lower(trim(english))) trim(english) english, trim(turkish) turkish
     from public.word_bank where class_no=class_id
       and unit_no=mod(stop_no-200000,10000)/100
       and active and nullif(trim(english),'') is not null and nullif(trim(turkish),'') is not null
     order by lower(trim(english)),trim(english),trim(turkish)
   ) w;
   words_count:=coalesce(cardinality(options),0);
   if words_count<3 then
    select array_agg(w.english order by w.english),array_agg(w.turkish order by w.english)
    into options,meanings from (
     select distinct on (lower(trim(english))) trim(english) english,trim(turkish) turkish
     from public.word_bank where class_no=class_id and active
     and nullif(trim(english),'') is not null and nullif(trim(turkish),'') is not null
     order by lower(trim(english)),trim(english),trim(turkish)
    ) w;
    words_count:=coalesce(cardinality(options),0);
   end if;
   if words_count<3 then return jsonb_build_object('ok',true,'reason','practice_unavailable',
      'xp',0,'gold',0,'mesaj','Bu ünite için pekiştirme içeriği hazırlanıyor.');end if;
   -- Stable but run-specific rotation; answers never leave the protected table.
   n:=mod(abs(hashtext(run_key)::bigint),words_count)::int;
   for i in 0..2 loop
    a:=1+mod(n+i,words_count);
    b:=1+mod(n+i+1,words_count);
    c:=1+mod(n+i+2,words_count);
    deck:=deck||jsonb_build_array(jsonb_build_object(
       'prompt',meanings[a],'answer',options[a],
       'options',case mod(i,3) when 0 then to_jsonb(array[options[b],options[a],options[c]])
         when 1 then to_jsonb(array[options[c],options[b],options[a]])
         else to_jsonb(array[options[a],options[c],options[b]]) end));
   end loop;
   insert into public.dm_parkur_recovery_runs(student_id,run_id,stop_no,class_no,deck)
   values(actor,run_key,stop_no,class_id,deck)
   on conflict(student_id,run_id) do nothing;
   select * into rec from public.dm_parkur_recovery_runs
   where student_id=actor and run_id=run_key for update;
  end if;
 end if;
 if correct_count<8 and not rec.completed then
  return jsonb_build_object('ok',true,'reason','needs_recovery','xp',0,'gold',0,
    'firstCorrect',correct_count,'total',12,
    'recovery',public.dm_parkur_recovery_view(rec.deck,rec.step));
 end if;
 percentage:=case when correct_count>=12 then 100 when correct_count>=10 then 80
   when correct_count>=8 then 60 else 30 end;
 -- The old reward engine is called only after the 12-step gate has passed.
 -- Reuse its first-clear/duplicate rules, and discount the single ledger receipt.
 reward:=public.dm_game_reward_claim(actor,run_key,'ba',class_id,array[stop_no],
   12,0,seconds,true,case percentage when 100 then 3 when 80 then 2 else 1 end,1);
 if coalesce((reward->>'xp')::int,0)<=0 then
  return reward||jsonb_build_object('fairPercent',percentage,
   'firstCorrect',correct_count,'total',12);
 end if;
 raw_x:=(reward->>'xp')::int;raw_g:=(reward->>'gold')::int;
 adj_x:=floor(raw_x*(100-percentage)/100.0)::int;
 adj_g:=floor(raw_g*(100-percentage)/100.0)::int;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci ödül verisi bulunamadı';end if;
 if adj_x>0 or adj_g>0 then
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,
    coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)-adj_x,
    'altin',coalesce((v->>'altin')::numeric,0)-adj_g,
    'guncelleme',ver,'dmRewardVersion',ver);
  if v#>>'{xpGun,tarih}'=day then
   v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(greatest(0,coalesce((v#>>'{xpGun,xp}')::numeric,0)-adj_x)));
  end if;
  v:=jsonb_set(v,array['log',day],to_jsonb(greatest(0,coalesce((v#>>array['log',day])::numeric,0)-adj_x)),true);
  update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
  update public.students set gold=(v->>'altin')::numeric where id=actor;
  update public.dm_game_reward_runs set xp=raw_x-adj_x,gold=raw_g-adj_g
   where student_id=actor and run_id=run_key;
 end if;
 return jsonb_build_object('ok',true,'xp',raw_x-adj_x,'gold',raw_g-adj_g,
   'reason','awarded','yo',v,'firstCorrect',correct_count,'total',12,'fairPercent',percentage,
   'fairTier',case percentage when 100 then 'perfect' when 80 then 'high' when 60 then 'pass' else 'recovery' end);
end; $function$
;

CREATE OR REPLACE FUNCTION public.dm_parkur_fair_recover(actor uuid, run_key text, stop_no integer, expected_step integer, selected text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare rec public.dm_parkur_recovery_runs; good boolean;
begin
 if actor is null or run_key !~ '^[a-zA-Z0-9_-]{16,100}$'
 or stop_no not between 200000 and 300000 or expected_step not between 0 and 2
 or selected is null or length(selected)>200 then raise exception 'Geçersiz pekiştirme isteği';end if;
 perform 1 from public.students where id=actor for update;
 select * into rec from public.dm_parkur_recovery_runs where student_id=actor and run_id=run_key for update;
 if not found or rec.stop_no<>stop_no or rec.completed then
  return jsonb_build_object('ok',false,'mesaj','Pekiştirme açık değil');end if;
 if rec.step<>expected_step then
  return jsonb_build_object('ok',true,'stale',true,'correct',false,
    'recovery',public.dm_parkur_recovery_view(rec.deck,rec.step));end if;
 good:=lower(trim(selected))=lower(trim(rec.deck->rec.step->>'answer'));
 if good then
  update public.dm_parkur_recovery_runs set step=step+1,completed=(step=2)
   where student_id=actor and run_id=run_key returning * into rec;
 else
  update public.dm_parkur_recovery_runs set mistakes=mistakes+1
   where student_id=actor and run_id=run_key;
 end if;
 return jsonb_build_object('ok',true,'correct',good,'completed',rec.completed,
   'recovery',case when rec.completed then null else public.dm_parkur_recovery_view(rec.deck,rec.step) end);
end; $function$
;

CREATE OR REPLACE FUNCTION public.dm_parkur_question_step(actor uuid, run_key text, step_no integer, passed boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students; oldrow public.dm_parkur_question_ledger; ticks int; balance int; cost int:=case when step_no<=2 then 0 else 1 end; consecutive int:=0; i int; rowdata record; gain int:=0;
begin
 if actor is null or run_key !~ '^[a-zA-Z0-9_-]{16,100}$' or step_no not between 1 and 12 then raise exception 'Geçersiz parkur isteği';end if;
 select * into st from public.students where id=actor for update;
 if not found then raise exception 'Öğrenci bulunamadı';end if;
 if passed is null then
   select * into oldrow from public.dm_parkur_question_ledger where student_id=actor and run_id=run_key and question_no=step_no;
   if found then return jsonb_build_object('ok',true,'duplicate',true,'energy',st.energy,'max',st.energy_max);end if;
   if step_no>1 and not exists(select 1 from public.dm_parkur_question_ledger where student_id=actor and run_id=run_key and question_no=step_no-1 and answered) then raise exception 'Önceki soru tamamlanmadı';end if;
   ticks:=greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900));
   balance:=least(st.energy_max,st.energy+ticks);
   if balance<cost then raise exception 'Enerji yetersiz';end if;
   insert into public.dm_parkur_question_ledger(student_id,run_id,question_no) values(actor,run_key,step_no);
   update public.students set energy=balance-cost, energy_updated_at=case when balance=st.energy_max then now() else coalesce(st.energy_updated_at,now())+ticks*interval '15 minutes' end where id=actor;
   if cost>0 then insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,-cost,balance-cost,'parkur-question:'||run_key||':'||step_no);end if;
   return jsonb_build_object('ok',true,'energy',balance-cost,'max',st.energy_max,'charged',cost);
 end if;
 select * into oldrow from public.dm_parkur_question_ledger where student_id=actor and run_id=run_key and question_no=step_no for update;
 
 if not found then
   -- Some clients submit the answer without a successful preceding charge request.
   -- Charge and create the ledger atomically before recording the answer.
   if step_no>1 and not exists (
     select 1 from public.dm_parkur_question_ledger
     where student_id=actor and run_id=run_key and question_no=step_no-1 and answered
   ) then
     raise exception 'Önceki soru tamamlanmadı';
   end if;
   ticks:=greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900));
   balance:=least(st.energy_max,st.energy+ticks);
   if balance<cost then raise exception 'Enerji yetersiz';end if;
   insert into public.dm_parkur_question_ledger(student_id,run_id,question_no)
     values(actor,run_key,step_no)
     returning * into oldrow;
   update public.students
     set energy=balance-cost,
         energy_updated_at=case when balance=st.energy_max then now()
           else coalesce(st.energy_updated_at,now())+ticks*interval '15 minutes' end
     where id=actor;
   if cost>0 then insert into public.energy_transactions(student_id,change_amount,balance_after,reason)
     values(actor,-cost,balance-cost,'parkur-question:'||run_key||':'||step_no);end if;
   st.energy:=balance-cost;
 end if;

 if oldrow.answered then return jsonb_build_object('ok',true,'duplicate',true,'energy',st.energy,'gain',0);end if;
 update public.dm_parkur_question_ledger set answered=true,correct=passed where student_id=actor and run_id=run_key and question_no=step_no;
 if passed and step_no>=3 then
   for i in reverse step_no..1 loop
     if exists(select 1 from public.dm_parkur_question_ledger where student_id=actor and run_id=run_key and question_no=i and answered and correct) then
       consecutive:=consecutive+1;
     else exit;end if;
   end loop;
   if consecutive>=3 and consecutive%3=0 then gain:=1;end if;
 end if;
 if gain>0 then
   balance:=least(st.energy_max,st.energy+gain);gain:=balance-st.energy;
   if gain>0 then
    update public.students set energy=balance where id=actor;
    insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,gain,balance,'parkur-combo:'||run_key||':'||step_no);
   end if;
 end if;
 return jsonb_build_object('ok',true,'energy',st.energy+gain,'max',st.energy_max,'gain',gain);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_parkur_recovery_view(deck jsonb, step_index integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('step',step_index,'total',3,'prompt',deck->step_index->>'prompt','options',deck->step_index->'options');
$function$
;

CREATE OR REPLACE FUNCTION public.dm_payment_state_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.state in ('refunded','revoked','expired') then update public.dm_entitlements set state=case when new.state='expired' then 'expired' else 'revoked' end,updated_at=now() where transaction_id=new.id; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_award_stop(actor uuid, stop integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ctx jsonb; n int; g int:=0; v jsonb; l int;
begin
 perform pg_advisory_xact_lock(hashtextextended(actor::text,17));ctx:=public.dm_progress_context(actor);l:=(ctx->>'level')::int;
 if (stop%100 between 51 and 99 and ctx->'done' @> jsonb_build_array((stop/100)*100+(stop%100-51)/3+1)) or (stop%100 between 51 and 53 and ctx->'done' @> jsonb_build_array(1000+((stop-200000)/10000)*100+((stop-200000)%10000)/100)) or l<5 or not ctx->'done' @> jsonb_build_array(stop) or exists(select 1 from public.dm_progress_baseline p cross join lateral jsonb_array_elements(p.stops) x where p.student_id=actor and (x->>'stop')::int=stop) then return jsonb_build_object('gold',0);end if;
 insert into public.dm_progress_rewards(student_id,kind,reward_key) values(actor,'stop',stop::text) on conflict do nothing;
 if not found then return jsonb_build_object('gold',0);end if;
 select count(*) into n from public.dm_progress_rewards where student_id=actor and kind='stop';
 if n%3=0 then g:=(array[15,20,30,40,50,65,80,100])[least(8,(l-5)/5+1)];v:=public.dm_progress_credit(actor,g);update public.dm_progress_rewards set gold=g where student_id=actor and kind='stop' and reward_key=stop::text;end if;
 return jsonb_build_object('gold',g,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_chest(actor uuid, chest text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ctx jsonb; g int; v jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(actor::text,17));ctx:=public.dm_progress_context(actor);
 if ctx#>>array['chests',chest]<>'ready' or ctx#>>array['chests',chest] is null then raise exception 'Sandık henüz hazır değil veya zaten alındı';end if;
 g:=case chest when 'bronze' then 40 when 'silver' then 100 when 'gold' then 200 when 'crystal' then 350 when 'legend' then 600 end;
 insert into public.dm_progress_rewards values(actor,'chest',chest,g,now());v:=public.dm_progress_credit(actor,g);
 return jsonb_build_object('gold',g,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_context(actor uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v jsonb; l int; done jsonb; units jsonb:='[]'; comp jsonb:='[]'; group_stops jsonb; b int; n int; cnt int; prev boolean:=true; lessons jsonb:='{}'; ce text; ready boolean; ch jsonb:='{}'; cl int; cid text; feed boolean; preserved_done jsonb;
begin
 select value into v from public.extra_data where student_id=actor and key_name='yo';v:=coalesce(v,'{}');l:=public.dm_student_level(coalesce((v->>'totalXp')::numeric,0));
 select coalesce(jsonb_agg(distinct stop_no order by stop_no),'[]'::jsonb) into done
 from (
   select (x->>'stop')::int stop_no from dm_private.parkur_xp_seed() p
   cross join lateral jsonb_array_elements(p.completed_stops) x where p.student_id=actor
   union
   select c.level_no from public.level_completions c
   where c.student_id=actor and c.mode='buyu' and (c.level_no between 1000 and 1999 or c.level_no between 210000 and 290000)
 ) preserved;
 preserved_done:=done;
 for b in 0..3 loop
  select coalesce(jsonb_agg(stop_no order by class_no, mixed, unit_no, part),'[]') into group_stops from (
   select w.class_no,w.unit_no,part,part>ceil(w.word_count/4.0)::int mixed,200000+w.class_no*10000+w.unit_no*100+50+part stop_no from (
    select class_no,unit_no,count(distinct lower(btrim(english))) word_count
    from public.word_bank where active and class_no between b*2+1 and b*2+2 and unit_no>0 and btrim(coalesce(english,''))<>'' and btrim(coalesce(turkish,''))<>'' group by class_no,unit_no
   ) w cross join lateral generate_series(1,ceil(w.word_count/4.0)::int * case when w.class_no in (1,3,7,8) then 2 else 1 end) part
  ) sections;
  select coalesce(jsonb_agg(distinct stop_no order by stop_no),'[]') into done from (
   select (x.value)::text::int stop_no from jsonb_array_elements(done) x
   union select (x.value)::text::int from jsonb_array_elements(group_stops) x
   where (preserved_done @> jsonb_build_array(((x.value)::text::int/100)*100+(((x.value)::text::int%100-51)/3)+1) or (((x.value)::text::int%100) between 51 and 53 and preserved_done @> jsonb_build_array(1000+(((x.value)::text::int-200000)/10000)*100+(((x.value)::text::int-200000)%10000)/100)) ) and exists(select 1 from public.word_bank wb where wb.active and wb.class_no=(((x.value)::text::int-200000)/10000) and wb.unit_no=(((x.value)::text::int-200000)%10000)/100 group by wb.class_no,wb.unit_no having ((x.value)::text::int%100-50)<=ceil(count(distinct lower(btrim(wb.english)))/4.0))
  ) expanded;
  units:=units||jsonb_build_array(group_stops);n:=jsonb_array_length(group_stops);select count(*) into cnt from jsonb_array_elements(group_stops) x where done @> jsonb_build_array(x);
  comp:=comp||jsonb_build_array(n>0 and cnt=n);
 end loop;
 feed:=jsonb_array_length(units->0)>=2 and done @> jsonb_build_array(units#>'{0,0}',units#>'{0,1}');
 foreach ce in array array['A1','A2','B1','B2'] loop
  lessons:=jsonb_set(lessons,array[ce],to_jsonb(prev));
  select exists(select 1 from public.lesson_topics where active and upper(level)=ce) and not exists(select 1 from public.lesson_topics t where t.active and upper(t.level)=ce and not exists(select 1 from public.lesson_progress p where p.student_id=actor and upper(p.level)=ce and p.category=t.category and p.topic_name=t.topic_name and p.test_success)) into prev;
 end loop;
 for b in 0..4 loop
  cid:=(array['bronze','silver','gold','crystal','legend'])[b+1];cl:=(array[5,14,24,34,40])[b+1];ready:=l>=cl;
  if b=0 then ready:=ready and jsonb_array_length(units->0)>=3 and done @> jsonb_build_array(units#>'{0,0}',units#>'{0,1}',units#>'{0,2}');
  elsif b=1 then select count(*) into cnt from jsonb_array_elements(units->0) x where done @> jsonb_build_array(x);ready:=ready and cnt>=ceil(jsonb_array_length(units->0)/2.0) and cnt>0;
  else for n in 0..b-1 loop ready:=ready and (comp->>n)::boolean;end loop;
  end if;
  ch:=jsonb_set(ch,array[cid],to_jsonb(case when exists(select 1 from public.dm_progress_rewards where student_id=actor and kind='chest' and reward_key=cid) then 'claimed' when ready then 'ready' else 'locked' end));
 end loop;
 return jsonb_build_object('level',l,'feed',feed,'done',done,'units',units,'complete',comp,'lessons',lessons,'chests',ch,'owned',coalesce(v#>'{karakter,sahip}','[]'),'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_credit(actor uuid, amount integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v jsonb; st public.students; ver bigint;
begin
 select * into st from public.students where id=actor for update;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci verisi gerekli';end if;
 if coalesce((v->>'altin')::numeric,0)+amount<0 then raise exception 'Yeterli altın yok';end if;
 ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
 v:=jsonb_set(v,'{altin}',to_jsonb(coalesce((v->>'altin')::numeric,0)+amount));v:=jsonb_set(v,'{guncelleme}',to_jsonb(ver));v:=jsonb_set(v,'{dmRewardVersion}',to_jsonb(ver));
 update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
 update public.students set gold=(v->>'altin')::numeric where id=actor;
 return v;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_league(week date DEFAULT (date_trunc('week'::text, (now() AT TIME ZONE 'Europe/Istanbul'::text)))::date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with base as (select s.id,s.username,s.class_no,public.dm_student_level(coalesce((e.value->>'totalXp')::numeric,0)) level,public.dm_competitive_xp(s.id,week) xp from public.students s left join public.extra_data e on e.student_id=s.id and e.key_name='yo' where s.status='approved' and s.role='student' and s.id<>'dcde2026-1015-4000-8000-000000000001'::uuid), tier as (select *,case when level>=15 and xp>=1800 then 'sampiyon' when level>=10 and xp>=750 then 'super' else 'yerel' end league from base where level>=5), ranks as (select *,row_number() over(partition by league order by xp desc,username,id) rank from tier)
select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',username,'class',class_no,'level',level,'xp',xp,'league',league,'rank',rank) order by xp desc,username,id),'[]') from ranks;
$function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_lesson_energy(actor uuid, cefr text, category_name text, topic text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students; amount int; already int; reward_key text:=upper(cefr)||'|'||category_name||'|'||topic;
begin
 perform pg_advisory_xact_lock(hashtextextended(actor::text,17));
 if not exists(select 1 from public.lesson_topics where active and upper(level)=upper(cefr) and category=category_name and topic_name=topic) or not exists(select 1 from public.lesson_progress where student_id=actor and upper(level)=upper(cefr) and category=category_name and topic_name=topic and test_success) then raise exception 'Başarılı yayımlanmış ders gerekli';end if;
 insert into public.dm_progress_rewards(student_id,kind,reward_key) values(actor,'lesson',reward_key) on conflict do nothing;
 if not found then return jsonb_build_object('eklenenEnerji',0);end if;
 select * into st from public.students where id=actor for update;
 select coalesce(sum(change_amount),0) into already from public.energy_transactions where student_id=actor and reason='progress-lesson' and created_at>=date_trunc('day',now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
 amount:=greatest(0,least(2,12-already,coalesce(st.energy_max,30)+10-st.energy));
 if amount>0 then update public.students set energy=energy+amount where id=actor;insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,amount,st.energy+amount,'progress-lesson');end if;
 return jsonb_build_object('eklenenEnerji',amount,'enerjiKalan',st.energy+amount,'enerjiMax',st.energy_max);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_mail_allowed(sid uuid, addr text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select exists(select 1 from public.dm_progress_mail_preferences p
 where p.student_id=sid and lower(p.email)=lower(addr)
 and p.opted_in_at is not null and p.unsubscribed_at is null)
$function$
;

CREATE OR REPLACE FUNCTION public.dm_progress_purchase(actor uuid, item_key text, is_showcase boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ctx jsonb; v jsonb; o public.dm_progress_items; f int; x jsonb; owns jsonb; first_purchase boolean;
begin
 perform pg_advisory_xact_lock(hashtextextended(actor::text,17));ctx:=public.dm_progress_context(actor);v:=ctx->'yo';
 select * into o from public.dm_progress_items where id=item_key;if not found then raise exception 'Ürün bulunamadı';end if;
 if (ctx->>'level')::int<o.minimum_level then raise exception 'Ürün % . seviyede açılır',o.minimum_level;end if;
 if item_key<>'extra-joker' and o.owned_keys<@coalesce(v#>'{karakter,sahip}','[]') then raise exception 'Bu ürüne zaten sahipsin';end if;
 if item_key<>'extra-joker' and nullif(v#>>'{karakter,cins}','') is null then raise exception 'Önce avatarını seç';end if;
 first_purchase:=not coalesce((v->>'dolapIlkIndirimKullanildi')::boolean,false) and coalesce(v->'dolapIlkAlim','{}')='{}'::jsonb;
 f:=case when item_key='extra-joker' then o.price when first_purchase then floor(o.price*.75+.5)::int when is_showcase then floor(o.price*.7+.5)::int else o.price end;
 v:=public.dm_progress_credit(actor,-f);
 if item_key='extra-joker' then v:=jsonb_set(v,'{dmExtraJoker}',to_jsonb(coalesce((v->>'dmExtraJoker')::int,0)+1));
 else
  select jsonb_agg(distinct e) into owns from jsonb_array_elements(coalesce(v#>'{karakter,sahip}','[]')||o.owned_keys) e;
  v:=jsonb_set(v,'{karakter,sahip}',owns);v:=jsonb_set(v,'{karakter,s}',coalesce(v#>'{karakter,s}','{}')||o.style);v:=jsonb_set(v,'{dolapIlkIndirimKullanildi}','true');
 end if;
 update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
 insert into public.dm_progress_rewards(student_id,kind,reward_key,gold) values(actor,'purchase',item_key||':'||gen_random_uuid()::text,-f);
 return jsonb_build_object('price',f,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_public_login_day_totals()
 RETURNS TABLE(student_id uuid, login_days bigint)
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select ps.student_id, count(distinct (ps.created_at at time zone 'Europe/Istanbul')::date)::bigint
 from public.portal_sessions ps
 where ps.student_id is not null
 group by ps.student_id
$function$
;

CREATE OR REPLACE FUNCTION public.dm_rally_answer(actor uuid, run_key uuid, round_no integer, lane integer)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select public.dm_rally_answer(actor,run_key,round_no,lane,false) $function$
;

CREATE OR REPLACE FUNCTION public.dm_rally_answer(actor uuid, run_key uuid, round_no integer, lane integer, slowed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_rally_runs;s jsonb;q jsonb;right_answer boolean;delta int;elapsed numeric;combo int;hearts int;last jsonb;
begin
 perform 1 from public.students where id=actor for update;
 select * into r from public.dm_rally_runs where id=run_key and student_id=actor for update;
 if not found then raise exception 'Yarış bulunamadı.';end if;
 if (r.state->>'hearts')::int<=0 and r.status='playing' then return public.dm_rally_finish(actor,run_key);end if;
 if r.status='finished' or round_no<(r.state->>'index')::int then return public.dm_rally_view(r);end if;
 if round_no is null or round_no<>(r.state->>'index')::int or lane is null or lane not between 0 and 2 then raise exception 'Geçerli kelime kapısını seç.';end if;
 elapsed:=extract(epoch from clock_timestamp()-r.round_at);
 if elapsed<2 then raise exception 'Kelime kapısına henüz ulaşmadın.';end if;
 if now()-r.created_at>interval '4 hours' then return public.dm_rally_finish(actor,run_key);end if;
 q:=r.deck->round_no;right_answer:=lane=(q->>'answer')::int;s:=r.state;
 delta:=case when right_answer then 100+greatest(0,least(40,round(50-least(60,elapsed)*3)::int)) else -40 end;
 -- A slowed question earns a smaller race score as well.
 if coalesce(slowed,false) and right_answer then delta:=round(delta*.7)::int;end if;
 combo:=case when right_answer then (s->>'combo')::int+1 else 0 end;hearts:=(s->>'hearts')::int-case when right_answer then 0 else 1 end;
 last:=jsonb_build_object('round',round_no,'correct',right_answer,'answer',q->'options'->(q->>'answer')::int,'word',q->'word','en',q->'en','tr',q->'tr','lane',lane,'correctLane',(q->>'answer')::int,'delta',delta,'slowed',coalesce(slowed,false));
 s:=s||jsonb_build_object('index',round_no+1,'correct',(s->>'correct')::int+case when right_answer then 1 else 0 end,'wrong',(s->>'wrong')::int+case when right_answer then 0 else 1 end,'hearts',hearts,'score',greatest(0,(s->>'score')::int+delta),'combo',combo,'bestCombo',greatest((s->>'bestCombo')::int,combo),'elapsed',(s->>'elapsed')::numeric+elapsed,'slowed',coalesce((s->>'slowed')::int,0)+case when coalesce(slowed,false) then 1 else 0 end,'last',last,'answers',(s->'answers')||jsonb_build_array(last));
 update public.dm_rally_runs set state=s,round_at=clock_timestamp() where id=run_key returning * into r;
 if round_no+1>=jsonb_array_length(r.deck) or hearts<=0 then return public.dm_rally_finish(actor,run_key);end if;
 return public.dm_rally_view(r);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_rally_finish(actor uuid, run_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_rally_runs;v jsonb;s jsonb;c int;w int;x int:=0;g int:=0;n int;speed int;daily numeric;secs numeric;ver bigint;result jsonb;st public.students;fair_percent int:=0;slow_count int:=0;slow_percent int:=0;day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
begin
 select * into st from public.students where id=actor for update;
 select * into r from public.dm_rally_runs where id=run_key and student_id=actor for update;
 if not found then raise exception 'Yarış bulunamadı.';end if;
 if r.reward is not null then return public.dm_rally_view(r);end if;
 s:=r.state;c:=(s->>'correct')::int;w:=(s->>'wrong')::int;secs:=greatest(1,(s->>'elapsed')::numeric);
 slow_count:=greatest(0,coalesce((s->>'slowed')::int,0));slow_percent:=least(45,slow_count*3);
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Hesap bilgileri hazır değil.';end if;
 if c>0 then
  select count(*)+1 into n from public.dm_game_reward_runs where student_id=actor and game_key<>'ba' and game_key not like 'konu:%' and xp>0 and created_at>=day::date::timestamp at time zone 'Europe/Istanbul';
  daily:=case when n<=3 then 2 when n>12 then .5 else 1 end;
  speed:=round(c*600/(1+secs/c));x:=least(public.dm_game_xp_cap(),round(least(80,greatest(0,c*6+floor(speed/100.0)-w*3))*daily))::int;
  g:=case when x=0 then 0 else round((array[4,7,10])[case when c::numeric/(c+w)>=.8 then 3 when c::numeric/(c+w)>=.5 then 2 else 1 end]*daily) end;
 end if;
 fair_percent:=case when c=0 then 0 when c=15 and w=0 then 100
   when c>=12 and w<=1 then 80 when c>=8 then 60 else 35 end;
 x:=floor(x*fair_percent/100.0*(100-slow_percent)/100.0)::int;
 g:=floor(g*fair_percent/100.0*(100-slow_percent)/100.0)::int;
 insert into public.dm_game_reward_runs(student_id,run_id,game_key,class_no,units,xp,gold) values(actor,run_key::text,'ralli',r.class_no,r.units,x,g);
 if x>0 or g>0 then
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)+x,'altin',coalesce((v->>'altin')::numeric,0)+g,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
  v:=jsonb_set(v,'{xpGun}',case when v#>>'{xpGun,tarih}'=day then v->'xpGun' else jsonb_build_object('tarih',day,'xp',0) end);v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(coalesce((v#>>'{xpGun,xp}')::numeric,0)+x));
  v:=jsonb_set(v,'{log}',coalesce(v->'log','{}'));v:=jsonb_set(v,array['log',day],to_jsonb(coalesce((v#>>array['log',day])::numeric,0)+x));
  update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';update public.students set gold=(v->>'altin')::numeric where id=actor;
  select value into v from public.extra_data where student_id=actor and key_name='yo';
 end if;
 insert into public.game_scores(student_id,student_name,game_key,class_no,unit_no,unit_name,score,correct_count,wrong_count,duration_seconds,extra)
 values(actor,st.username,'ralli',r.class_no,r.units[1],array_to_string(r.units,','),(s->>'score')::int,c,w,ceil(secs)::int,jsonb_build_object('v',3,'speed',coalesce(speed,0),'run_id',run_key,'reward_protocol',1,'slowed',slow_count));
 if actor<>'dcde2026-1015-4000-8000-000000000001'::uuid then
 insert into public.feed_events(student_id,event_type,payload) values(actor,'game_score',jsonb_build_object('game_name','Kelime Rallisi','game_key','ralli','score',(s->>'score')::int,'icon','🏎️'));
 end if;
 result:=jsonb_build_object('xp',x,'gold',g,'reason',case when c=0 then 'no_correct' when x=0 and g=0 then 'no_correct' else 'awarded' end,'yo',v,'fairPercent',fair_percent,'slowCount',slow_count,'slowPercent',slow_percent,'fairTier',case fair_percent when 100 then 'perfect' when 80 then 'high' when 60 then 'pass' when 35 then 'practice' else 'none' end);
 update public.dm_rally_runs set status='finished',reward=result,finished_at=now() where id=run_key returning * into r;
 return public.dm_rally_view(r);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_rally_start(actor uuid, run_key uuid, class_id integer, unit_ids integer[], question_deck jsonb, pace text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare st public.students;r public.dm_rally_runs;available int;ticks int;v jsonb;
begin
 select * into st from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci hesabı gerekli.';end if;
 select value into v from public.extra_data where student_id=actor and key_name='yo';
 if public.dm_student_level(coalesce((v->>'totalXp')::numeric,0))<15 then raise exception 'Kelime Rallisi 15. seviyede açılır.';end if;
 select * into r from public.dm_rally_runs where id=run_key;
 if found then if r.student_id<>actor then raise exception 'Yarış bulunamadı.';end if;return public.dm_rally_view(r);end if;
 if class_id is null or class_id not between 1 and 8 or cardinality(unit_ids) not between 1 and 10 or exists(select 1 from unnest(unit_ids) u where u is null or u not between 1 and 100) or pace not in ('easy','normal','hard') or jsonb_typeof(question_deck) is distinct from 'array' or jsonb_array_length(question_deck)<>15 then raise exception 'Geçerli sınıf, ünite ve 15 kelime gerekli.';end if;
 if exists(select 1 from jsonb_array_elements(question_deck) q where jsonb_typeof(q->'options') is distinct from 'array' or jsonb_array_length(q->'options')<>3 or (q->>'answer')::int not between 0 and 2 or nullif(q->>'word','') is null) then raise exception 'Geçersiz yarış kelimeleri.';end if;
 if (select count(*) from public.dm_rally_runs where student_id=actor and created_at>now()-interval '1 minute')>=5 then raise exception 'Yeni yarış için kısa bir süre bekle.';end if;
 ticks:=greatest(0,floor(extract(epoch from now()-coalesce(st.energy_updated_at,now()))/900));
 available:=case when st.energy>=st.energy_max then st.energy else least(st.energy_max,st.energy+ticks) end;
 if available<3 then raise exception 'Yarışa başlamak için 3 enerji gerekli.';end if;
 insert into public.dm_rally_runs(id,student_id,class_no,units,difficulty,deck) values(run_key,actor,class_id,unit_ids,pace,question_deck) returning * into r;
 update public.students set energy=available-3,energy_updated_at=case when available>=st.energy_max then now() else coalesce(st.energy_updated_at,now())+ticks*interval '15 minutes' end where id=actor;
 insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,-3,available-3,'ralli:'||run_key);
 return public.dm_rally_view(r)||jsonb_build_object('energy',available-3,'energyMax',st.energy_max);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_rally_view(r dm_rally_runs)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select jsonb_build_object('ok',true,'runId',r.id,'totalQuestions',jsonb_array_length(r.deck),'classNo',r.class_no,'units',to_jsonb(r.units),'difficulty',r.difficulty,'finished',r.status='finished','state',r.state,'reward',r.reward,
 'question',case when r.status='playing' then (r.deck->(r.state->>'index')::int)-'answer'-'en'-'tr' else null end);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_record_route_mission()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.student_id is not null and new.completed and not new.replay and (TG_OP='INSERT' or not old.completed) then
  insert into public.dm_route_mission_completions(student_id,chapter) values(new.student_id,new.chapter) on conflict do nothing;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_round_score(answers jsonb, questions jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select case when questions->0->>'puanSurum'='3' then public.dm_round_score_v3(answers,questions,true) else public.dm_round_score_legacy(answers,questions) end
$function$
;

CREATE OR REPLACE FUNCTION public.dm_round_score_legacy(answers jsonb, questions jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare score integer:=0;correct integer:=0;streak integer:=0;spent numeric:=0;i integer;v jsonb;
begin
 for i in 0..7 loop
  v:=answers->i::text;spent:=spent+coalesce((v->>'ms')::numeric,12000);
  if v->>'answer'=questions->i->>'answer' then
   correct:=correct+1;streak:=streak+1;score:=score+100+case streak when 3 then 50 when 5 then 50 when 8 then 100 else 0 end;
  else streak:=0;end if;
 end loop;
 return jsonb_build_object('puan',least(1000,score),'dogru',correct,'yanlis',8-correct,'sure',round(spent/1000,2),'yildiz',case when score>=800 then 3 when score>=500 then 2 else 1 end);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_round_score_v3(answers jsonb, questions jsonb, completed boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare base integer:=0;correct integer:=0;wrong integer:=0;streak integer:=0;spent numeric:=0;i integer;v jsonb;speed integer;penalty integer;seconds numeric;seen jsonb:='{}';bonus integer;
begin
 for i in 0..jsonb_array_length(questions)-1 loop
  v:=answers->i::text;
  if v is null and not completed then continue;end if;
  spent:=spent+greatest(0,least(12000,coalesce((v->>'ms')::numeric,12000)));
  if v->>'answer'=questions->i->>'answer' then
   correct:=correct+1;streak:=streak+1;bonus:=case streak when 3 then 50 when 5 then 50 when 8 then 100 else 0 end;
   if seen ? streak::text then bonus:=0;else seen:=seen||jsonb_build_object(streak::text,true);end if;
   base:=base+100+bonus;
  else wrong:=wrong+1;streak:=0;end if;
 end loop;
 seconds:=round(spent/1000,2);speed:=case when correct=0 then 0 else round(correct*600/(1+seconds/correct)) end;penalty:=wrong*40;
 return jsonb_build_object('puan',greatest(0,base+speed-penalty),'temelPuan',base,'hizBonusu',speed,'hataCezasi',penalty,'dogru',correct,'yanlis',wrong,'sure',seconds,'xp',greatest(0,correct*6+floor(speed/100)-wrong*3),'puanSurum',3,'yildiz',case when correct>0 and correct::numeric/(correct+wrong)>=.8 then 3 when correct>0 and correct::numeric/(correct+wrong)>=.5 then 2 else 1 end);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_safety_feed_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare feature text; begin
 feature:=case when new.event_type='energy_send' then 'gifts' when new.event_type='duel_invite' then 'duels' else 'profile' end;
 if not public.dm_social_allowed(new.student_id,feature) or (new.target_student_id is not null and not public.dm_social_allowed(new.target_student_id,feature)) then return null; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_safety_peer_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a uuid; b uuid; feature text; begin
 if tg_table_name='notifications' then
 a:=new.sender_student_id;b:=new.recipient_student_id;
 if a is null then return new; end if;
 feature:=case when new.type in ('hediye','enerji') then 'gifts' when new.type='mesaj' then 'messages' when new.type in ('oyunDavet','duello') then 'duels' else 'social' end;
 elsif tg_op='UPDATE' and (to_jsonb(new)->>'status')='cancelled' then return new;
 elsif tg_table_name='dm_accessory_gifts' then a:=new.sender_id;b:=new.recipient_id;feature:='gifts';
 elsif tg_table_name='duels' then a:=new.sender_student_id;b:=new.receiver_student_id;feature:='duels';
 else a:=new.player_a;b:=new.player_b;feature:='duels'; end if;
 if not public.dm_social_allowed(a,feature) or not public.dm_social_allowed(b,feature) then raise exception 'Bu sosyal etkileşim veli veya yönetici ayarlarıyla kapalı.'; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_safety_report_create(p_actor uuid, p_target text, p_kind text, p_item uuid, p_reason text, p_note text, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare target uuid; snap jsonb; rid uuid; begin
 if not exists(select 1 from public.students where id=p_actor and status='approved') then raise exception 'Öğrenci oturumu gerekli.'; end if;
 select id into rid from public.dm_safety_reports where reporter_id=p_actor and request_id=p_request;
 if rid is not null then return rid; end if;
 if p_kind='feed' then
 select student_id,jsonb_build_object('type',event_type,'payload',payload) into target,snap from public.feed_events where id=p_item;
 elsif p_kind='message' then
 select sender_student_id,jsonb_build_object('type',type,'message',message) into target,snap from public.notifications where id=p_item and recipient_student_id=p_actor;
 elsif p_kind='user' then
 select id,jsonb_build_object('username',username) into target,snap from public.students where lower(username)=lower(trim(p_target)) and status='approved';
 else raise exception 'Geçersiz bildirim türü.'; end if;
 if target is null or target=p_actor then raise exception 'Bildirilecek kullanıcı veya içerik bulunamadı.'; end if;
 if (select count(*) from public.dm_safety_reports where reporter_id=p_actor and created_at>now()-interval '1 day')>=20 then raise exception 'Günlük bildirim sınırına ulaştın.'; end if;
 insert into public.dm_safety_reports(reporter_id,target_id,request_id,kind,item_id,reason,note,snapshot) values(p_actor,target,p_request,p_kind,p_item,p_reason,left(coalesce(p_note,''),500),snap)
 on conflict(reporter_id,request_id) do update set request_id=excluded.request_id returning id into rid;
 return rid;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_safety_review(p_admin uuid, p_report uuid, p_action text, p_note text DEFAULT ''::text, p_days integer DEFAULT 1)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_safety_reports; begin
 if not exists(select 1 from public.teachers where id=p_admin and active and is_admin) then raise exception 'Yönetici yetkisi gerekli.'; end if;
 select * into r from public.dm_safety_reports where id=p_report for update;
 if r.id is null then raise exception 'Bildirim bulunamadı.'; end if;
 if p_action not in ('review','dismiss','warn','hide','suspend','restore') or length(coalesce(p_note,''))>500 then raise exception 'Geçersiz işlem.'; end if;
 if p_action='hide' then
 if r.kind<>'feed' then raise exception 'Bu içerik akış paylaşımı değil.'; end if;
 update public.feed_events set safety_hidden=true where id=r.item_id;
 elsif p_action='suspend' then
 if p_days not in (1,7) then raise exception '1 veya 7 gün seç.'; end if;
 insert into public.dm_social_controls(student_id,suspended_until) values(r.target_id,now()+make_interval(days=>p_days))
 on conflict(student_id) do update set suspended_until=excluded.suspended_until,updated_at=now();
 elsif p_action='restore' then update public.dm_social_controls set suspended_until=null,updated_at=now() where student_id=r.target_id;
 end if;
 if p_action in ('warn','suspend') then insert into public.notifications(recipient_student_id,type,title,message) values(r.target_id,'guvenlik','Güvenlik bilgilendirmesi',case when p_action='suspend' then 'Sosyal özelliklerin yönetici incelemesi sonucunda süreli kapatıldı. Ders ve parkur özelliklerin açık.' else 'Lütfen topluluk kurallarına uy. Kırıcı davranıştan ve kişisel bilgi paylaşmaktan kaçın.' end); end if;
 update public.dm_safety_reports set status=case p_action when 'review' then 'reviewing' when 'dismiss' then 'dismissed' else 'resolved' end,action=p_action,reviewed_by=p_admin,review_note=coalesce(p_note,''),updated_at=now() where id=r.id;
 insert into public.dm_safety_review_log(report_id,admin_id,action,note) values(r.id,p_admin,p_action,coalesce(p_note,''));
 return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_security_rate_check(bucket_key text, max_hits integer, window_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare row public.dm_security_buckets;now_at timestamptz:=clock_timestamp();
begin
 if bucket_key is null or length(bucket_key) not between 16 and 180
 or max_hits not between 1 and 10000 or window_seconds not between 10 and 86400
 then raise exception 'Geçersiz güvenlik sınırı';end if;
 -- Concurrent requests for the same security bucket must count atomically.
 perform pg_advisory_xact_lock(hashtextextended(bucket_key,37));
 select * into row from public.dm_security_buckets where dm_security_buckets.bucket_key=dm_security_rate_check.bucket_key for update;
 if not found then
  insert into public.dm_security_buckets(bucket_key,hits,window_start,expires_at,updated_at)
  values(bucket_key,1,now_at,now_at+make_interval(secs=>window_seconds),now_at);
  return jsonb_build_object('allowed',true,'remaining',max_hits-1,'retryAfter',0);
 end if;
 if row.expires_at<=now_at then
  update public.dm_security_buckets set hits=1,window_start=now_at,
  expires_at=now_at+make_interval(secs=>window_seconds),updated_at=now_at
  where dm_security_buckets.bucket_key=dm_security_rate_check.bucket_key;
  return jsonb_build_object('allowed',true,'remaining',max_hits-1,'retryAfter',0);
 end if;
 if row.hits>=max_hits then
  return jsonb_build_object('allowed',false,'remaining',0,'retryAfter',greatest(1,ceil(extract(epoch from row.expires_at-now_at))::int));
 end if;
 update public.dm_security_buckets set hits=hits+1,updated_at=now_at
 where dm_security_buckets.bucket_key=dm_security_rate_check.bucket_key;
 return jsonb_build_object('allowed',true,'remaining',max_hits-row.hits-1,'retryAfter',0);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_settle_weeks()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare b date; cur date:=date_trunc('week',now() at time zone 'Europe/Istanbul')::date; r jsonb; g int; c int:=0; enabled boolean; rank int; sid uuid; tier text; x numeric;
begin
 perform pg_advisory_xact_lock(8031051);
 select coalesce(bool_and(f.enabled),true) into enabled from public.dm_release_flags f where f.code in ('lig','lig_odul');
 insert into public.dm_league_weeks(week_start) values(cur) on conflict do nothing;
 for b in select week_start from public.dm_league_weeks where week_start<cur and settled_at is null order by week_start loop
  for r in select * from jsonb_array_elements(public.dm_progress_league(b)) loop
   sid:=(r->>'id')::uuid;rank:=(r->>'rank')::int;tier:=r->>'league';x:=(r->>'xp')::numeric;g:=0;
   if enabled and x>0 then
    if tier='sampiyon' and rank<=10 then g:=(array[500,350,250,180,140,110,90,75,60,50])[rank];
    elsif tier='super' and rank<=2 then g:=(array[30,20])[rank];end if;
   end if;
   insert into public.dm_weekly_results(student_id,week_start,rank_no,league,xp,active_days,gold,energy,summary)
   values(sid,b,rank,tier,x,coalesce((select active_days from public.dm_weekly_xp where student_id=sid and week_start=b),0),g,0,public.dm_week_metrics(sid,b)||jsonb_build_object('participationBadge',tier='yerel' and x>0)) on conflict do nothing;c:=c+1;
  end loop;
  update public.dm_league_weeks set settled_at=now() where week_start=b;
 end loop;
 return c;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_social_action(actor uuid, target uuid, action text, arg text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me public.students; them public.students; v jsonb; k jsonb; item public.dm_accessory_catalog; txt text; n integer;
 presets text[]:=array['Merhaba! 👋','Beni takip eder misin? 🌟','Birlikte Kelime Uçuşu oynayalım! 🪽','Cümle Rotası düellosuna var mısın? 🧩','Kelime Laboratuvarı oynayalım! 🔬','Risk Balonları için hazır mısın? 🎈','Hafıza Sandığı oynayalım! 🧠','Hız Fırtınası yarışına katıl! 🌪️','Eş Bul oynayalım! 🔗','Kelime Treni düellosu yapalım! 🚂','Harf Avı oynayalım! 🔤','Şifre Kırıcı oynayalım! 🔐','Harika oynadın, tebrikler! 🎉','Rövanş yapalım mı? ⚔️','Bugün birlikte ders çalışalım! 📚'];
begin
 if actor is null or actor=target then raise exception 'Geçersiz öğrenci.';end if;
 perform pg_advisory_xact_lock(hashtextextended(least(actor::text,target::text)||greatest(actor::text,target::text),0));
 select * into me from public.students where id=actor and status='approved';
 select * into them from public.students where id=target and status='approved';
 if me.id is null or them.id is null then raise exception 'Öğrenci bulunamadı.';end if;
 if action='status' then return jsonb_build_object('ok',true,'blocked',public.dm_blocked(actor,target),'mine',exists(select 1 from public.student_blocks where blocker_id=actor and blocked_id=target));end if;
 if action='unblock' then delete from public.student_blocks where blocker_id=actor and blocked_id=target;return jsonb_build_object('ok',true);end if;
 if action='block' then
  insert into public.student_blocks values(actor,target,now()) on conflict do nothing;
  delete from public.feed_events where event_type='takip' and ((student_id=actor and target_student_id=target) or (student_id=target and target_student_id=actor));
  -- Remove outstanding invitations rather than allowing an acceptance after a block.
  delete from public.duels where status in ('pending','accepted') and ((sender_student_id=actor and receiver_student_id=target) or (sender_student_id=target and receiver_student_id=actor));
  delete from public.notifications where read_at is null and ((sender_student_id=actor and recipient_student_id=target) or (sender_student_id=target and recipient_student_id=actor));
  update public.dm_matches set status='cancelled' where status in ('waiting','playing') and ((player_a=actor and player_b=target) or (player_a=target and player_b=actor));
  return jsonb_build_object('ok',true);
 end if;
 if public.dm_blocked(actor,target) then raise exception 'Bu kişiyle iletişim kapalı.';end if;
 if action='message' then
  n:=arg::integer;if n<0 or n>=array_length(presets,1) then raise exception 'Hazır mesaj seç.';end if;txt:=presets[n+1];
  select count(*) into n from public.notifications where sender_student_id=actor and type='mesaj' and created_at>now()-interval '1 hour';
  if n>=20 then raise exception 'Biraz bekle; saatte 20 mesaj gönderebilirsin.';end if;
  insert into public.notifications(recipient_student_id,sender_student_id,type,message) values(target,actor,'mesaj',txt);
 elsif action='gift' then
  select * into item from public.dm_accessory_catalog where id=arg;if item.id is null then raise exception 'Aksesuar bulunamadı.';end if;
  -- Stable lock order prevents reciprocal gifts from deadlocking.
  perform 1 from public.students where id in(actor,target) order by id for update;
  insert into public.extra_data(student_id,key_name,value) values(actor,'yo','{}') on conflict(student_id,key_name) do nothing;
  select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
  if jsonb_typeof(v)='string' then v:=(v#>>'{}')::jsonb;end if;
  if coalesce((v->>'altin')::numeric,0)<item.price then raise exception 'Yeterli altının yok.';end if;
  select value into k from public.extra_data where student_id=target and key_name='yo' for update;
  if jsonb_typeof(k)='string' then k:=(k#>>'{}')::jsonb;end if;
  if coalesce(k#>'{karakter,sahip}','[]') ? ('d:'||item.id) then raise exception 'Bu aksesuar arkadaşında zaten var.';end if;
  insert into public.dm_accessory_gifts(sender_id,recipient_id,item_id) values(actor,target,item.id);
  v:=jsonb_set(v,'{altin}',to_jsonb((v->>'altin')::numeric-item.price));v:=jsonb_set(v,'{guncelleme}',to_jsonb(floor(extract(epoch from clock_timestamp())*1000)));
  update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';update public.students set gold=(v->>'altin')::numeric where id=actor;
  insert into public.notifications(recipient_student_id,sender_student_id,type,message) values(target,actor,'hediye',item.icon||' '||item.name||' hediye etti! Dolap’ta seni bekliyor.');
  return jsonb_build_object('ok',true,'yo',v);
 else raise exception 'Geçersiz işlem.';end if;
 return jsonb_build_object('ok',true);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_social_allowed(p_student uuid, p_feature text DEFAULT 'social'::text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select coalesce((select c.social_enabled and (c.suspended_until is null or c.suspended_until<=now()) and case p_feature
 when 'profile' then c.profile_visible when 'messages' then c.messages_enabled when 'duels' then c.duels_enabled when 'gifts' then c.gifts_enabled else true end
 from public.dm_social_controls c where c.student_id=p_student),true);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_solo_fair_claim(actor uuid, run_key text, game_code text, class_id integer, unit_ids integer[], right_count integer, wrong_count integer, duration_seconds numeric, boost_factor integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare earlier public.dm_game_reward_runs; raw jsonb; v jsonb;
 percentage integer; base_x int; base_g int; reduced_x int; reduced_g int; earned_x int:=0;earned_g int:=0;
 ver bigint; day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');
begin
 if actor is null or run_key is null or length(run_key) not between 8 and 100
 or game_code not in ('ky','jp','bosluk','hafiza','yagmur','asmaca','kelimebul','eslestirme',
  'tren','dikte','cumle','harfbahcesi','kp')
 or class_id not between 0 and 12 or cardinality(unit_ids) not between 1 and 20
 or exists(select 1 from unnest(unit_ids) x where x is null or x not between 0 and 100)
 or duration_seconds is null or duration_seconds<=0 or duration_seconds>86400
 or right_count not between 0 and 12 or wrong_count not between 0 and 10000
 then raise exception 'Geçersiz adil oyun sonucu';end if;
 perform 1 from public.students where id=actor for update;
 select * into earlier from public.dm_game_reward_runs
 where student_id=actor and run_id=run_key for update;
 if found then
  select value into v from public.extra_data where student_id=actor and key_name='yo';
  return jsonb_build_object('ok',true,'duplicate',true,'reason','duplicate',
   'xp',earlier.xp,'gold',earlier.gold,'yo',v);
 end if;
 percentage:=public.dm_solo_fair_percent(game_code,right_count,wrong_count);
 raw:=public.dm_game_reward_claim(actor,run_key,game_code,class_id,unit_ids,
    right_count,wrong_count,duration_seconds,false,1,
    case when boost_factor in (2,3,4) then boost_factor else 1 end);
 if not coalesce((raw->>'ok')::boolean,false) then raise exception 'Ödül doğrulanamadı';end if;
 if coalesce((raw->>'duplicate')::boolean,false) then return raw;end if;
 base_x:=coalesce((raw->>'xp')::int,0);base_g:=coalesce((raw->>'gold')::int,0);
 earned_x:=floor(base_x*percentage/100.0)::int;
 earned_g:=floor(base_g*percentage/100.0)::int;
 reduced_x:=base_x-earned_x;
 reduced_g:=base_g-earned_g;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci cüzdanı bulunamadı';end if;
 if reduced_x>0 or reduced_g>0 then
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,
   coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',greatest(0,coalesce((v->>'totalXp')::numeric,0)-reduced_x),
   'altin',greatest(0,coalesce((v->>'altin')::numeric,0)-reduced_g),
   'guncelleme',ver,'dmRewardVersion',ver);
  if v#>>'{xpGun,tarih}'=day then
   v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(greatest(0,coalesce((v#>>'{xpGun,xp}')::numeric,0)-reduced_x)));
  end if;
  v:=jsonb_set(v,array['log',day],to_jsonb(greatest(0,
   coalesce((v#>>array['log',day])::numeric,0)-reduced_x)),true);
  update public.extra_data set value=v,updated_at=now()
   where student_id=actor and key_name='yo';
  update public.students set gold=(v->>'altin')::numeric where id=actor;
  update public.dm_game_reward_runs set xp=base_x-reduced_x,gold=base_g-reduced_g
   where student_id=actor and run_id=run_key;
 end if;
 return raw||jsonb_build_object('xp',earned_x,'gold',earned_g,
  'yo',v,'reason',case when earned_x>0 or earned_g>0 then 'awarded' else 'no_correct' end,
  'fairPercent',percentage,'fairTier',case percentage
     when 100 then 'perfect' when 80 then 'high' when 60 then 'pass'
     when 35 then 'practice' else 'none' end);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_solo_fair_percent(game_code text, right_count integer, wrong_count integer)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare effective_errors numeric; accuracy numeric;
begin
 if game_code not in ('ky','jp','bosluk','hafiza','yagmur','asmaca','kelimebul',
 'eslestirme','tren','dikte','cumle','harfbahcesi','kp')
 or right_count not between 0 and 12 or wrong_count not between 0 and 10000
 then raise exception 'Geçersiz tek kişilik oyun skoru';end if;
 if right_count=0 then return 0;end if;
 -- Trying many cards in memory is not the same as answering a question wrong.
 effective_errors:=case
  when game_code in ('hafiza','eslestirme') then wrong_count*.40
  when game_code in ('asmaca','harfbahcesi','kelimebul') then wrong_count*.60
  else wrong_count::numeric end;
 accuracy:=right_count/(right_count+effective_errors);
 -- Short or prematurely-ended games may still earn something, but cannot
 -- receive the same premium as an accurate and complete performance.
 if right_count>=6 and accuracy>=.97 then return 100;end if;
 if right_count>=5 and accuracy>=.80 then return 80;end if;
 if right_count>=3 and accuracy>=.60 then return 60;end if;
 return 35;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_story_apply(owner_key text, chapter_no integer, expected_cursor integer, expected_version integer, answer_correct boolean, is_question boolean, step_count integer, question_count integer)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select public.dm_story_apply(owner_key,chapter_no,expected_cursor,expected_version,answer_correct,is_question,step_count,question_count,answer_correct);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_story_apply(owner_key text, chapter_no integer, expected_cursor integer, expected_version integer, answer_correct boolean, is_question boolean, step_count integer, question_count integer, combo_correct boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p public.papi_story_progress; s public.students; v jsonb; reward jsonb:='{}'; regen int; e int; cap int; costs int:=0; seen int; cur int; finished boolean; first_done boolean; stars int; l int; n int; g int:=0; bonus int:=0; combo int:=0; combo_gain int:=0;
begin
 if owner_key is null or owner_key !~ '^[st]:[0-9a-f-]{36}$' or (chapter_no not between 0 and 79 and chapter_no not between 1000 and 1411) or step_count not between 2 and 80 or question_count not between 1 and 80 or question_count>step_count or answer_correct is null or (is_question is null or combo_correct is null) then raise exception 'Geçersiz öğrenme işlemi';end if;
 if left(owner_key,2)='s:' then
  perform pg_advisory_xact_lock(hashtextextended(substring(owner_key from 3),17));
  select * into s from public.students where id=substring(owner_key from 3)::uuid for update;
  if not found then raise exception 'Öğrenci bulunamadı';end if;
 end if;
 select * into p from public.papi_story_progress where actor_key=owner_key and chapter=chapter_no for update;
 if not found then raise exception 'Önce durağı aç';end if;
 if p.version<>expected_version or p.cursor<>expected_cursor then return jsonb_build_object('ok',true,'stale',true,'progress',to_jsonb(p));end if;
 if p.cursor>=step_count then return jsonb_build_object('ok',true,'alreadyCompleted',true,'correct',true,'progress',to_jsonb(p));end if;
 seen:=p.questions_seen;
 if is_question and p.charged_cursor<>p.cursor then seen:=seen+1;if chapter_no>=1000 or seen%2=0 then costs:=1;end if;end if;
 if s.id is not null then
  cap:=coalesce(nullif(s.energy_max,0),30);e:=coalesce(s.energy,0);
  if e<cap then
   regen:=greatest(0,floor(extract(epoch from (now()-coalesce(s.energy_updated_at,now())))/900)::int);
   if regen>0 then e:=least(cap,e+regen);end if;
  end if;
  -- Exhausted energy pauses a new question; a previously paid retry stays available.
  if is_question and p.charged_cursor<>p.cursor and e<1 then return jsonb_build_object('ok',false,'energyEmpty',true,'mesaj','Enerjin bitti. Enerji dolunca bu sorudan devam edebilirsin.','enerjiKalan',e,'enerjiMax',cap);end if;
  if e<>coalesce(s.energy,0) then
   insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(s.id,e-coalesce(s.energy,0),e,'dolum');
  end if;
  if costs>0 then insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(s.id,-costs,e-costs,'papi_story:'||chapter_no||':'||p.cursor);end if;
  update public.students set energy=e-costs,energy_updated_at=case when e>=cap or s.energy_updated_at is null then now() when regen>0 then s.energy_updated_at+regen*interval '15 minutes' else s.energy_updated_at end,updated_at=now() where id=s.id;
 end if;
 combo:=case when p.cursor=0 then 0 else p.route_combo end;
 if is_question then
  if not combo_correct then combo:=0;
  else combo:=combo+1;
  end if;
 end if;
 if s.id is not null and combo_correct and is_question and combo>0 and combo % (case when chapter_no>=1000 then 5 else 3 end)=0 then
  combo_gain:=least(1,greatest(0,cap-(e-costs)));
  if combo_gain>0 then
   update public.students set energy=e-costs+combo_gain where id=s.id;
   insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(s.id,combo_gain,e-costs+combo_gain,'story-combo:'||chapter_no||':'||p.version);
  end if;
 end if;
 cur:=p.cursor+case when answer_correct then 1 else 0 end;finished:=cur>=step_count;first_done:=finished and not p.reward_claimed;
 if first_done and s.id is not null then
  stars:=case when question_count::numeric/(question_count+p.mistakes+case when combo_correct then 0 else 1 end)>=.9 then 3 when question_count::numeric/(question_count+p.mistakes+case when combo_correct then 0 else 1 end)>=.7 then 2 else 1 end;
  reward:=public.dm_game_reward_claim(s.id,'papi-story-'||chapter_no,'ba',0,array[50+chapter_no],question_count,p.mistakes,1,true,stars,1);
  g:=coalesce((reward->>'gold')::int,0);v:=reward->'yo';l:=public.dm_student_level(coalesce((v->>'totalXp')::numeric,0));
  if l>=5 then
   insert into public.dm_progress_rewards(student_id,kind,reward_key) values(s.id,'stop','papi-story-'||chapter_no) on conflict do nothing;
   if found then
    select count(*) into n from public.dm_progress_rewards where student_id=s.id and kind='stop';
    if n%3=0 then bonus:=(array[15,20,30,40,50,65,80,100])[least(8,(l-5)/5+1)];v:=public.dm_progress_credit(s.id,bonus);g:=g+bonus;update public.dm_progress_rewards set gold=bonus where student_id=s.id and kind='stop' and reward_key='papi-story-'||chapter_no;end if;
   end if;
  end if;
  reward:=reward||jsonb_build_object('gold',g,'yo',v,'stars',stars);
 end if;
 update public.papi_story_progress set route_combo=combo,cursor=cur,completed=p.completed or finished,reward_claimed=p.reward_claimed or finished,questions_seen=seen,charged_cursor=case when is_question then p.cursor else p.charged_cursor end,mistakes=p.mistakes+case when combo_correct then 0 else 1 end,version=p.version+1,last_reward=case when finished then reward else p.last_reward end,updated_at=now() where actor_key=owner_key and chapter=chapter_no returning * into p;
 return jsonb_build_object('ok',true,'progress',to_jsonb(p),'correct',answer_correct,'finished',finished,'leaf',case when first_done then 1 else 0 end,'energySpent',costs,'comboGain',combo_gain,'combo',combo,'enerjiKalan',case when s.id is not null then e-costs+combo_gain else null end,'enerjiMax',cap,'reward',p.last_reward,'yo',reward->'yo');
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_student_level(x numeric)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
select count(*)::int from unnest(array[0,40,100,180,300,480,720,1040,1450,1950,2550,3250,4050,4950,5950,7000,8100,9250,10450,11700,13000,14350,15750,17200,18700,20250,21850,23500,25200,26950,29350,32150,35350,38950,42950,47350,52150,57350,62950,68950]) t where t<=greatest(0,coalesce(x,0));$function$
;

CREATE OR REPLACE FUNCTION public.dm_sync_registered_mail_recipients()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare n integer;
begin
 insert into public.dm_progress_mail_preferences(student_id,recipient_kind,email,opted_in_at,consent_source,unsubscribe_token_hash)
 select s.id,'parent',lower(btrim(s.email)),now(),
  case when c.student_id is not null then 'registration_checkbox' else 'registration_existing_consent_owner_instruction_20261018' end,
  md5(gen_random_uuid()::text)
 from public.students s
 left join public.extra_data c on c.student_id=s.id and c.key_name='progress_mail_consent_v1'
  and lower(btrim(coalesce(c.value->>'email','')))=lower(btrim(s.email))
 where s.role='student' and s.status='approved'
 and btrim(coalesce(s.email,'')) ~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
 and (s.created_at < '2026-10-19T11:01:00Z'::timestamptz or c.student_id is not null)
 and not exists(select 1 from public.dm_progress_mail_preferences p where p.student_id=s.id and lower(p.email)=lower(btrim(s.email)))
 on conflict do nothing;
 get diagnostics n=row_count; return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_thematic_discount_final(owner_key text, chapter_no integer, award jsonb, percent integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare sid uuid; previous public.dm_game_reward_runs; v jsonb;
 base_x integer; base_g integer; next_x integer; next_g integer; dx integer; dg integer;
 day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD'); ver bigint;
 result_reward jsonb;
begin
 if owner_key !~ '^s:[0-9a-f-]{36}$' or chapter_no not between 1000 and 1411 or percent not in (30,60,80,100)
 then raise exception 'Geçersiz ödül oranı';end if;
 sid:=substring(owner_key from 3)::uuid;
 select * into previous from public.dm_game_reward_runs where student_id=sid
   and run_id='papi-story-'||chapter_no for update;
 if not found or previous.game_key<>'ba' then raise exception 'Tamamlama ödül kaydı eksik';end if;
 base_x:=previous.xp; base_g:=previous.gold;
 next_x:=floor(base_x*percent/100.0)::int;
 next_g:=floor(base_g*percent/100.0)::int;
 dx:=base_x-next_x;dg:=base_g-next_g;
 select value into v from public.extra_data where student_id=sid and key_name='yo' for update;
 if v is null then raise exception 'Öğrenci ödül verisi bulunamadı';end if;
 if dx>0 or dg>0 then
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',greatest(0,coalesce((v->>'totalXp')::numeric,0)-dx),
    'altin',greatest(0,coalesce((v->>'altin')::numeric,0)-dg),
    'guncelleme',ver,'dmRewardVersion',ver);
  if v#>>'{xpGun,tarih}'=day then
   v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(greatest(0,coalesce((v#>>'{xpGun,xp}')::numeric,0)-dx)));
  end if;
  v:=jsonb_set(v,array['log',day],to_jsonb(greatest(0,coalesce((v#>>array['log',day])::numeric,0)-dx)),true);
  update public.extra_data set value=v,updated_at=now() where student_id=sid and key_name='yo';
  update public.students set gold=(v->>'altin')::numeric where id=sid;
  update public.dm_game_reward_runs set xp=next_x,gold=next_g where student_id=sid and run_id=previous.run_id;
 end if;
 result_reward:=coalesce(award,'{}'::jsonb)||
    jsonb_build_object('xp',next_x,'gold',greatest(0,coalesce((award->>'gold')::int,base_g)-dg),'yo',v,
      'fairPercent',percent,'fairTier',case percent when 100 then 'perfect' when 80 then 'high' when 60 then 'pass' else 'recovery' end);
 update public.papi_story_progress set last_reward=result_reward
 where actor_key=owner_key and chapter=chapter_no;
 return result_reward;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_thematic_fair_step(owner_key text, chapter_no integer, expected_cursor integer, expected_version integer, answer_correct boolean, is_question boolean, step_count integer, question_count integer, combo_correct boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p public.papi_story_progress; r jsonb; n integer; correct_count integer;
 existing_answer boolean; effective_correct boolean; tier integer:=0; score_eligible boolean:=false;
 rec public.dm_thematic_recovery; new_award jsonb;
begin
 if owner_key is null or owner_key !~ '^[st]:[0-9a-f-]{36}$'
 or chapter_no not between 1000 and 1411 or expected_cursor not between 0 and 13
 or expected_version<0 or step_count not in (10,11,12,14)
 or (case when step_count=14 then question_count<>10 else question_count<>step_count-1 end) or answer_correct is null or is_question is null or combo_correct is null
 then raise exception 'Geçersiz öğrenme işlemi';end if;
 if left(owner_key,2)='s:' then
  perform pg_advisory_xact_lock(hashtextextended(substring(owner_key from 3),17));
  perform 1 from public.students where id=substring(owner_key from 3)::uuid for update;
 end if;
 select * into p from public.papi_story_progress where actor_key=owner_key and chapter=chapter_no for update;
 if not found then raise exception 'Önce bölümü aç';end if;
 if p.cursor<>expected_cursor or p.version<>expected_version then
  return jsonb_build_object('ok',true,'stale',true,'progress',to_jsonb(p));
 end if;
 select * into rec from public.dm_thematic_recovery
 where actor_key=owner_key and chapter=chapter_no for update;
 if rec.actor_key is not null and not rec.completed and not p.completed then
  select count(*),count(*) filter(where first_correct)
   into n,correct_count from public.dm_thematic_first_answers
   where actor_key=owner_key and chapter=chapter_no;
  return jsonb_build_object('ok',true,'correct',false,'needsRecovery',true,
   'progress',to_jsonb(p),'firstAttempt',jsonb_build_object('answered',n,'correct',correct_count,
     'total',question_count,'complete',n=question_count,'percentage',round(100.0*correct_count/greatest(n,1))),
   'recovery',jsonb_build_object('step',rec.step,'total',3));
 end if;
 -- Inspect the final task without accepting client-supplied correctness counts.
 -- Legacy/in-progress decks missing a complete historical first-answer ledger
 -- are grandfathered: do not block or discount those students.
 if step_count in (12,14) and p.cursor=step_count-1 and not p.replay and not p.reward_claimed then
  select count(*),count(*) filter(where first_correct) into n,correct_count
  from public.dm_thematic_first_answers where actor_key=owner_key and chapter=chapter_no;
  if not exists(select 1 from public.dm_thematic_first_answers where actor_key=owner_key
        and chapter=chapter_no and question_cursor=step_count-1) and p.charged_cursor<>p.cursor then
   n:=n+1;
   if combo_correct then correct_count:=correct_count+1;end if;
  end if;
  score_eligible:=n=question_count;
  if score_eligible then
   tier:=case when correct_count=question_count then 100
         when correct_count>=question_count-1 then 80
         when correct_count>=ceil(question_count*0.7) then 60 else 0 end;
  end if;
 end if;
 -- A below-8/11 learner finishes the review QUESTION but not the lesson.
 -- This deliberately returns cursor=11 and requires three new recovery questions.
 if score_eligible and tier=0 then
  r:=public.dm_story_apply(owner_key,chapter_no,expected_cursor,expected_version,
     false,is_question,step_count,question_count,combo_correct);
 else
  r:=public.dm_story_apply(owner_key,chapter_no,expected_cursor,expected_version,
     answer_correct,is_question,step_count,question_count,combo_correct);
 end if;
 if not coalesce((r->>'ok')::boolean,false)
  or coalesce((r->>'stale')::boolean,false)
  or coalesce((r->>'energyEmpty')::boolean,false) then return r;end if;
 if is_question and p.cursor>(step_count-question_count-1) and p.cursor<step_count
  and p.charged_cursor<>p.cursor and not p.replay and not p.completed then
  insert into public.dm_thematic_first_answers(actor_key,chapter,question_cursor,first_correct)
  values(owner_key,chapter_no,p.cursor,combo_correct) on conflict do nothing;
 end if;
 select count(*),count(*) filter(where first_correct)
  into n,correct_count from public.dm_thematic_first_answers
  where actor_key=owner_key and chapter=chapter_no;
 if score_eligible and tier=0 then
  insert into public.dm_thematic_recovery(actor_key,chapter)
  values(owner_key,chapter_no) on conflict do nothing;
  r:=r||jsonb_build_object('needsRecovery',true,
     'recovery',jsonb_build_object('step',0,'total',3),
     'mesaj','Kısa pekiştirme turuyla bölümü bitir.');
 elsif score_eligible and tier>0 and coalesce((r->>'finished')::boolean,false)
   and left(owner_key,2)='s:' then
  new_award:=public.dm_thematic_discount_final(owner_key,chapter_no,r->'reward',tier);
  r:=jsonb_set(r,'{reward}',new_award);
  r:=jsonb_set(r,'{yo}',new_award->'yo');
  r:=jsonb_set(r,'{progress,last_reward}',new_award);
 end if;
 return r||jsonb_build_object('firstAttempt',
   jsonb_build_object('answered',n,'correct',correct_count,'total',question_count,
     'complete',n=question_count,'eligible',n=question_count and not p.replay,
     'percentage',case when n>0 then round(100.0*correct_count/n) else null end));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_thematic_recovery_answer(owner_key text, chapter_no integer, expected_version integer, expected_step integer, answer_correct boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p public.papi_story_progress; rec public.dm_thematic_recovery; r jsonb; new_award jsonb;
 n integer; c integer; step_total integer; question_total integer; final_cursor integer;
begin
 if owner_key is null or owner_key !~ '^[st]:[0-9a-f-]{36}$'
  or chapter_no not between 1000 and 1411 or expected_version<0
  or expected_step not between 0 and 2 or answer_correct is null then
  raise exception 'Geçersiz pekiştirme cevabı';end if;
 if left(owner_key,2)='s:' then
  perform pg_advisory_xact_lock(hashtextextended(substring(owner_key from 3),17));
  perform 1 from public.students where id=substring(owner_key from 3)::uuid for update;
 end if;
 select * into p from public.papi_story_progress where actor_key=owner_key and chapter=chapter_no for update;
 if not found then raise exception 'Bölüm bulunamadı';end if;
 select * into rec from public.dm_thematic_recovery
 where actor_key=owner_key and chapter=chapter_no for update;
 step_total:=case when p.deck_version=8 then 14 else 12 end;
 question_total:=case when p.deck_version=8 then 10 else 11 end;
 final_cursor:=step_total-1;
 if not found or rec.completed or p.completed or p.replay or p.cursor<>final_cursor
 then raise exception 'Pekiştirme açık değil';end if;
 if rec.step<>expected_step or p.version<>expected_version then
  return jsonb_build_object('ok',true,'stale',true,'progress',to_jsonb(p),
   'needsRecovery',true,'recovery',jsonb_build_object('step',rec.step,'total',3));
 end if;
 if not answer_correct then
  update public.dm_thematic_recovery set errors=errors+1,updated_at=now()
   where actor_key=owner_key and chapter=chapter_no;
  return jsonb_build_object('ok',true,'correct',false,'accepted',false,'needsRecovery',true,
   'progress',to_jsonb(p),'recovery',jsonb_build_object('step',rec.step,'total',3));
 end if;
 if rec.step<2 then
  update public.dm_thematic_recovery set step=step+1,updated_at=now()
  where actor_key=owner_key and chapter=chapter_no;
  return jsonb_build_object('ok',true,'correct',true,'accepted',true,'needsRecovery',true,
   'progress',to_jsonb(p),'recovery',jsonb_build_object('step',rec.step+1,'total',3));
 end if;
 select count(*),count(*) filter(where first_correct) into n,c
 from public.dm_thematic_first_answers where actor_key=owner_key and chapter=chapter_no;
 if n<>question_total or c>=ceil(question_total*0.7) then raise exception 'İlk başarı kaydı tutarsız';end if;
 -- Final review was already answered (and charged), so this completion costs
 -- no additional energy and never adds a second five-answer combo.
 r:=public.dm_story_apply(owner_key,chapter_no,p.cursor,p.version,
   true,false,step_total,question_total,false);
 if not coalesce((r->>'ok')::boolean,false) or not coalesce((r->>'finished')::boolean,false)
 then raise exception 'Pekiştirme tamamlanamadı';end if;
 if left(owner_key,2)='s:' then
  new_award:=public.dm_thematic_discount_final(owner_key,chapter_no,r->'reward',30);
  r:=jsonb_set(r,'{reward}',new_award);
  r:=jsonb_set(r,'{yo}',new_award->'yo');
  r:=jsonb_set(r,'{progress,last_reward}',new_award);
 end if;
 update public.dm_thematic_recovery set step=3,completed=true,updated_at=now()
 where actor_key=owner_key and chapter=chapter_no;
 return r||jsonb_build_object('accepted',true,'recovered',true,'firstAttempt',
 jsonb_build_object('answered',n,'correct',c,'total',question_total,'percentage',round(100.0*c/question_total)));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_topic_game_finish(actor uuid, run_key uuid, picks jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.dm_topic_game_runs; v jsonb; i int; c int:=0; n int; x int:=0; used int; ver bigint;
 day text:=to_char(now() at time zone 'Europe/Istanbul','YYYY-MM-DD');reason text:='accuracy'; prior_scope text;
begin
 -- Serialize both wallet writes and daily quota checks across simultaneous runs.
 perform 1 from public.students where id=actor for update;
 if not found then raise exception 'Öğrenci oturumu gerekli.';end if;
 select * into r from public.dm_topic_game_runs where run_id=run_key and student_id=actor for update;
 if not found then return jsonb_build_object('ok',false,'sebep','missing','mesaj','Oyun oturumu bulunamadı veya tamamlandı.');end if;
 if r.expires_at<=clock_timestamp() then
  delete from public.dm_topic_game_runs where run_id=run_key;
  return jsonb_build_object('ok',false,'sebep','expired','mesaj','Oyun oturumunun süresi doldu.');
 end if;
 if jsonb_typeof(picks) is distinct from 'array' or jsonb_array_length(picks)<>r.question_count then raise exception 'Geçersiz cevaplar.';end if;
 n:=r.question_count;
 for i in 0..n-1 loop
  if jsonb_typeof(picks->i) is distinct from 'string' or not (r.answer_key->i->'allowed' @> jsonb_build_array(picks->i)) then raise exception 'Geçersiz cevaplar.';end if;
  if picks->>i=r.answer_key->i->>'correct' then c:=c+1;end if;
 end loop;
 select count(*) into used from public.dm_game_reward_runs where student_id=actor and topic_key=r.topic_key
 and game_key='konu:'||r.game and xp>0
 and created_at>=day::date::timestamp at time zone 'Europe/Istanbul'
 and created_at<(day::date+1)::timestamp at time zone 'Europe/Istanbul';
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 if v is null then raise exception 'Hesap bilgileri hazır değil.';end if;
 if used>=3 then reason:='daily_limit';
 elsif extract(epoch from clock_timestamp()-r.started_at)<n*1.5 then reason:='too_fast';
 elsif c*100>=n*80 then x:=least(70,public.dm_game_xp_cap());reason:='awarded';end if;
 if x>0 then
  insert into public.dm_game_reward_runs(student_id,run_id,game_key,class_no,units,xp,gold,topic_key)
  values(actor,run_key::text,'konu:'||r.game,0,array[0],x,0,r.topic_key);
  ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
  v:=v||jsonb_build_object('totalXp',coalesce((v->>'totalXp')::numeric,0)+x,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
  v:=jsonb_set(v,'{xpGun}',case when v#>>'{xpGun,tarih}'=day then v->'xpGun' else jsonb_build_object('tarih',day,'xp',0) end);
  v:=jsonb_set(v,'{xpGun,xp}',to_jsonb(coalesce((v#>>'{xpGun,xp}')::numeric,0)+x));
  v:=jsonb_set(v,'{log}',coalesce(v->'log','{}'));
  v:=jsonb_set(v,array['log',day],to_jsonb(coalesce((v#>>array['log',day])::numeric,0)+x));
  prior_scope:=coalesce(current_setting('diji.topic_game',true),'');
  perform set_config('diji.topic_game','1',true);
  update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
  perform set_config('diji.topic_game',prior_scope,true);
  select value into v from public.extra_data where student_id=actor and key_name='yo';
 end if;
 delete from public.dm_topic_game_runs where run_id=run_key;
 delete from public.dm_topic_game_runs where expires_at<=now();
 return jsonb_build_object('ok',true,'dogru',c,'toplam',n,'yuzde',round(c*100.0/n),'xp',x,'xpHakkiKaldi',greatest(0,3-used-case when x>0 then 1 else 0 end),'sebep',reason,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_verified_answer(actor uuid, run_key text, slot_no integer, event_key text, is_correct boolean, is_complete boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_verified_runs; s jsonb; good boolean; reply jsonb; energy jsonb;
begin
 if event_key !~ '^[a-zA-Z0-9_-]{16,100}$' or slot_no not between 0 and 31 or is_correct is null or is_complete is null then raise exception 'Geçersiz cevap';end if;
 perform 1 from public.students where id=actor for update;
 select * into r from public.dm_verified_runs where student_id=actor and run_id=run_key for update;
 if not found or r.expires_at<clock_timestamp() or slot_no>=jsonb_array_length(r.deck) then raise exception 'Oturum sona erdi';end if;
 if r.events ? event_key then return r.events->event_key;end if;
 if (select count(*) from jsonb_object_keys(r.events))>=2000 then raise exception 'Oturum işlem sınırı';end if;
 s:=coalesce(r.answers->slot_no::text,jsonb_build_object('misses',0,'complete',false));
 if coalesce((s->>'complete')::boolean,false) then return jsonb_build_object('correct',s->'correct','duplicate',true);end if;
 good:=is_correct and coalesce((s->>'misses')::int,0)=0;
 s:=s||jsonb_build_object('misses',coalesce((s->>'misses')::int,0)+case when is_correct then 0 else 1 end,'complete',is_complete,'correct',is_correct,'firstCorrect',good);
 if r.game='ba' and is_complete then
   energy:=public.dm_parkur_question_step(actor,run_key,slot_no+1,good);
 end if;
 reply:=jsonb_build_object('correct',is_correct,'firstCorrect',good,'complete',is_complete,'energy',energy);
 update public.dm_verified_runs set answers=jsonb_set(r.answers,array[slot_no::text],s),events=jsonb_set(r.events,array[event_key],reply)
 where student_id=actor and run_id=run_key;
 return reply;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_verified_required()
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select coalesce((select value from public.dm_security_settings where key='verified_games_required'),true);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_verified_result(actor uuid, run_key text, game_code text, cls integer, unit_ids integer[], stop_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_verified_runs; right_n int;wrong_n int;completed_n int;
begin
 select * into r from public.dm_verified_runs where student_id=actor and run_id=run_key;
 if not found or r.game<>game_code or r.class_no<>cls or r.units<>unit_ids or r.stop_no<>stop_id or r.expires_at<clock_timestamp() then raise exception 'Doğrulanmış oyun oturumu gerekli. Uygulamayı yenileyip yeniden başlat.';end if;
 select count(*) filter(where (value->>'complete')::boolean and (value->>'correct')::boolean),coalesce(sum((value->>'misses')::int),0),count(*) filter(where (value->>'complete')::boolean) into right_n,wrong_n,completed_n from jsonb_each(r.answers);
 wrong_n:=wrong_n+greatest(0,jsonb_array_length(r.deck)-(select count(*) from jsonb_object_keys(r.answers)));
 if r.answers='{}'::jsonb then raise exception 'Doğrulanmış cevap bulunamadı';end if;
 if game_code='ba' then
  if completed_n<>12 then raise exception 'Parkurun 12 cevabı doğrulanmalı';end if;
  update public.dm_parkur_question_ledger l set answered=true,correct=coalesce((r.answers->(l.question_no-1)::text->>'firstCorrect')::boolean,false) where l.student_id=actor and l.run_id=run_key;
 end if;
 return jsonb_build_object('correct',right_n,'wrong',wrong_n,'complete',completed_n,'total',jsonb_array_length(r.deck),'seconds',greatest(1,extract(epoch from clock_timestamp()-r.created_at)));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_verified_start(actor uuid, run_key text, game_code text, cls integer, unit_ids integer[], stop_id integer, tasks jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_verified_runs;
begin
 if run_key !~ '^[a-zA-Z0-9_-]{16,100}$' or jsonb_typeof(tasks)<>'array' or jsonb_array_length(tasks) not between 1 and 32 then raise exception 'Geçersiz oturum';end if;
 perform 1 from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci gerekli';end if;
 insert into public.dm_verified_runs(student_id,run_id,game,class_no,units,stop_no,deck) values(actor,run_key,game_code,cls,unit_ids,stop_id,tasks) on conflict do nothing;
 select * into r from public.dm_verified_runs where student_id=actor and run_id=run_key;
 if r.game<>game_code or r.class_no<>cls or r.units<>unit_ids or r.stop_no<>stop_id or r.deck<>tasks then raise exception 'Oturum kapsamı değiştirilemez';end if;
 return jsonb_build_object('answers',r.answers,'startedAt',r.created_at);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_week_metrics(sid uuid, b date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select jsonb_build_object(
 'games',(select count(*) from public.game_scores where student_id=sid and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'correct',(select coalesce(sum(correct_count),0) from public.game_scores where student_id=sid and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'wrong',(select coalesce(sum(wrong_count),0) from public.game_scores where student_id=sid and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'gameSeconds',(select coalesce(sum(duration_seconds),0) from public.game_scores where student_id=sid and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'topics',(select count(distinct topic_name) from public.lesson_progress where student_id=sid and test_success and completed_at>=b::timestamp at time zone 'Europe/Istanbul' and completed_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'levels',(select count(*) from public.level_completions where student_id=sid and completed_at>=b::timestamp at time zone 'Europe/Istanbul' and completed_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'videos',(select count(*) from public.student_videos where student_id=sid and watched_at>=b::timestamp at time zone 'Europe/Istanbul' and watched_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'activities',(select count(*) from public.student_activities where student_id=sid and completed_at>=b::timestamp at time zone 'Europe/Istanbul' and completed_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'homework',(select count(*) from public.assignment_status where student_id=sid and done_at>=b::timestamp at time zone 'Europe/Istanbul' and done_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'reading',(select count(*) from public.reading_results where student_id=sid and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul'),
 'matches',(select count(*) from public.dm_matches where ((player_a=sid and result_a is not null) or (player_b=sid and result_b is not null)) and created_at>=b::timestamp at time zone 'Europe/Istanbul' and created_at<(b+7)::timestamp at time zone 'Europe/Istanbul')
);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_week_start(w text)
 RETURNS date
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare y int; n int; b date;
begin
 if w !~ '^\d{4}-H([1-9]|[1-4][0-9]|5[0-3])$' then return null; end if;
 y:=split_part(w,'-H',1)::int; n:=split_part(w,'-H',2)::int;
 if y<2020 or y>2100 then return null; end if;
 b:=date_trunc('week',make_date(y,1,4)::timestamp)::date + (n-1)*7;
 if extract(isoyear from b)<>y then return null; end if;
 return b;
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_weekly_ack(actor uuid, week date)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 with ack as (update public.dm_weekly_results set shown_at=coalesce(shown_at,now()) where student_id=actor and week_start=week returning 1) select exists(select 1 from ack);
$function$
;

CREATE OR REPLACE FUNCTION public.dm_weekly_claim(actor uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.dm_weekly_results; v jsonb; st public.students; ver bigint;
begin
 if not exists(select 1 from public.students where id=actor and status='approved' and role='student') then raise exception 'Öğrenci bulunamadı'; end if;
 select * into r from public.dm_weekly_results where student_id=actor and shown_at is null order by week_start desc limit 1 for update;
 if not found then return null; end if;
 if r.awarded_at is null then
  select * into st from public.students where id=actor for update;
  select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
  v:=coalesce(v,'{}'::jsonb);ver:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
  if r.gold>0 or r.energy>0 then
   v:=jsonb_set(v,'{altin}',to_jsonb(greatest(coalesce((v->>'altin')::numeric,0),st.gold)+r.gold));
   v:=jsonb_set(v,'{guncelleme}',to_jsonb(ver));v:=jsonb_set(v,'{dmRewardVersion}',to_jsonb(ver));
   insert into public.extra_data(student_id,key_name,value,updated_at) values(actor,'yo',v,now()) on conflict(student_id,key_name) do update set value=excluded.value,updated_at=excluded.updated_at;
   update public.students set gold=(v->>'altin')::numeric,energy=least(500,energy+r.energy) where id=actor;
   insert into public.energy_transactions(student_id,change_amount,balance_after,reason) values(actor,r.energy,least(500,st.energy+r.energy),'Haftalık Şampiyonlar Ligi '||r.week_start);
  end if;
  update public.dm_weekly_results set awarded_at=now() where student_id=actor and week_start=r.week_start;
 end if;
 select value into v from public.extra_data where student_id=actor and key_name='yo';
 return to_jsonb(r)||jsonb_build_object('yo',v,'energyBalance',(select energy from public.students where id=actor));
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_weekly_target_claim(actor uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare week_date date := (date_trunc('week',now() at time zone 'Europe/Istanbul'))::date;
        week_code text; goal jsonb; legacy jsonb; v jsonb; st public.students;
        target int; awarded int; achieved numeric:=0; logged numeric:=0; weekly numeric:=0; wkxp numeric:=0;
        fresh boolean:=false; ver bigint; old boolean:=false;
begin
 week_code:=to_char(week_date,'YYYY-MM-DD');
 perform pg_advisory_xact_lock(hashtextextended(actor::text,81015));
 select * into st from public.students where id=actor and status='approved' and role='student' for update;
 if not found then raise exception 'Öğrenci bulunamadı'; end if;
 select value into v from public.extra_data where student_id=actor and key_name='yo' for update;
 v:=coalesce(v,'{}'::jsonb);
 select value into goal from public.extra_data where student_id=actor and key_name='weekly_target' for update;
 legacy:=v->'haftaHedef';
 if coalesce(goal->>'h','')<>week_code then
   if coalesce(legacy->>'h','')<>week_code then
      return jsonb_build_object('ok',false,'message','Önce bu hafta için hedef seç.');
   end if;
   goal:=legacy;
 end if;
 if coalesce(goal->>'xp','') !~ '^(1000|1500|2500)$' then
   return jsonb_build_object('ok',false,'message','Geçerli bir haftalık hedef seç.');
 end if;
 target:=(goal->>'xp')::int;
 old:=exists(select 1 from public.dm_progress_rewards
   where student_id=actor and kind='weekly_target' and reward_key=week_code)
   or coalesce(goal->>'odul','0')='1'
   or (coalesce(legacy->>'h','')=week_code and coalesce(legacy->>'odul','0')='1');
 if old then
   insert into public.dm_progress_rewards(student_id,kind,reward_key,gold)
      values(actor,'weekly_target',week_code,0) on conflict do nothing;
   goal:=jsonb_set(goal,'{odul}','1'::jsonb,true);
   insert into public.extra_data(student_id,key_name,value,updated_at) values(actor,'weekly_target',goal,now())
      on conflict(student_id,key_name) do update set value=excluded.value,updated_at=excluded.updated_at;
   if coalesce(legacy->>'h','')=week_code and coalesce(legacy->>'odul','0')<>'1' then
     v:=jsonb_set(v,'{haftaHedef}',goal,true);
     update public.extra_data set value=v,updated_at=now() where student_id=actor and key_name='yo';
   end if;
   return jsonb_build_object('ok',true,'duplicate',true,'newlyAwarded',false,'awardedGold',0,'haftaHedef',goal,'altin',greatest(coalesce(st.gold,0),coalesce((v->>'altin')::numeric,0)),'yo',v);
 end if;
 -- Match existing weekly UI: positive log XP this Istanbul week, or the league's current XP.
 select coalesce(sum(case when data.value~'^[0-9]+([.][0-9]+)?$' then greatest(0,data.value::numeric) else 0 end),0)
 into logged from jsonb_each_text(case when jsonb_typeof(v->'log')='object' then v->'log' else '{}'::jsonb end) data
 where data.key>=week_code and data.key<to_char(week_date+7,'YYYY-MM-DD');
 if coalesce(v#>>'{lig,xp}','')~'^[0-9]+([.][0-9]+)?$' then
   weekly:=(v#>>'{lig,xp}')::numeric;
 end if;
 select coalesce(xp,0) into wkxp from public.dm_weekly_xp where student_id=actor and week_start=week_date;
 achieved:=greatest(logged,weekly,coalesce(wkxp,0));
 if achieved<target then
   return jsonb_build_object('ok',false,'reached',false,'progress',achieved,'target',target,'message','Haftalık hedef henüz tamamlanmadı.');
 end if;
 awarded:=round(target/20.0)::int;
 insert into public.dm_progress_rewards(student_id,kind,reward_key,gold)
 values(actor,'weekly_target',week_code,awarded) on conflict do nothing;
 if not found then
   return jsonb_build_object('ok',true,'duplicate',true,'newlyAwarded',false,'awardedGold',0,'haftaHedef',goal,'altin',st.gold,'yo',v);
 end if;
 fresh:=true;
 goal:=jsonb_set(goal,'{odul}','1'::jsonb,true);
 ver:=greatest(floor(extract(epoch from clock_timestamp())*1000)::bigint,coalesce((v->>'guncelleme')::bigint,0)+1);
 v:=v||jsonb_build_object('altin',greatest(coalesce(st.gold,0),coalesce((v->>'altin')::numeric,0))+awarded,'haftaHedef',goal,'guncelleme',ver,'dmRewardVersion',ver,'dmProgressProtocol',1);
 insert into public.extra_data(student_id,key_name,value,updated_at) values(actor,'yo',v,now())
 on conflict(student_id,key_name) do update set value=excluded.value,updated_at=excluded.updated_at;
 insert into public.extra_data(student_id,key_name,value,updated_at) values(actor,'weekly_target',goal,now())
 on conflict(student_id,key_name) do update set value=excluded.value,updated_at=excluded.updated_at;
 update public.students set gold=(v->>'altin')::numeric,updated_at=now() where id=actor;
 return jsonb_build_object('ok',true,'duplicate',false,'newlyAwarded',fresh,'awardedGold',awarded,'haftaHedef',goal,'altin',(v->>'altin')::numeric,'yo',v);
end $function$
;

CREATE OR REPLACE FUNCTION public.dm_weekly_target_select(actor uuid, target_xp integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare week_code text := to_char(date_trunc('week',now() at time zone 'Europe/Istanbul'),'YYYY-MM-DD');
        goal jsonb; legacy jsonb; state jsonb; selected_xp int;
begin
 if target_xp not in (1000,1500,2500) then raise exception 'Geçersiz haftalık hedef'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,81015));
 if not exists(select 1 from public.students where id=actor and status='approved' and role='student') then raise exception 'Öğrenci oturumu gerekli'; end if;
 select value into state from public.extra_data where student_id=actor and key_name='yo';
 state:=coalesce(state,'{}'::jsonb);
 select value into goal from public.extra_data where student_id=actor and key_name='weekly_target';
 legacy:=state->'haftaHedef';
 if coalesce(goal->>'h','')=week_code then
   selected_xp:=coalesce((goal->>'xp')::int,target_xp);
 elsif coalesce(legacy->>'h','')=week_code and (legacy->>'xp')::int in (1000,1500,2500) then
   selected_xp:=(legacy->>'xp')::int;
 else selected_xp:=target_xp;
 end if;
 if selected_xp not in (1000,1500,2500) then selected_xp:=target_xp; end if;
 goal:=jsonb_build_object('h',week_code,'xp',selected_xp,'odul',case
   when exists(select 1 from public.dm_progress_rewards where student_id=actor and kind='weekly_target' and reward_key=week_code)
     or (coalesce(legacy->>'h','')=week_code and coalesce(legacy->>'odul','0')='1')
     or (coalesce(goal->>'h','')=week_code and coalesce(goal->>'odul','0')='1')
   then 1 else 0 end,'secildiAt',coalesce(goal->'secildiAt',legacy->'secildiAt',to_jsonb(floor(extract(epoch from clock_timestamp())*1000)::bigint)));
 insert into public.extra_data(student_id,key_name,value,updated_at) values(actor,'weekly_target',goal,now())
 on conflict(student_id,key_name) do update set value=excluded.value,updated_at=excluded.updated_at;
 return jsonb_build_object('ok',true,'haftaHedef',goal);
end $function$
;

CREATE OR REPLACE FUNCTION public.register_google_student(p_auth_user_id uuid, p_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_student_id uuid; v_username text := p_payload->>'username';
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_auth_user_id::text, 0));
  select student_id into v_student_id from public.student_google_accounts where auth_user_id = p_auth_user_id;
  if v_student_id is not null then return v_student_id; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(pg_catalog.lower(v_username), 1));
  if exists (select 1 from public.students where pg_catalog.lower(username) = pg_catalog.lower(v_username))
     or exists (select 1 from public.teachers where pg_catalog.lower(username) = pg_catalog.lower(v_username)) then
    raise exception 'Username already registered' using errcode = '23505';
  end if;
  insert into public.students(username,password_hash,phone,class_no,branch,email,status,teacher_id,kvkk_approved_at)
  values(v_username,p_payload->>'password_hash',p_payload->>'phone',(p_payload->>'class_no')::integer,
    p_payload->>'branch',p_payload->>'email','approved',(p_payload->>'teacher_id')::uuid,pg_catalog.now())
  returning id into v_student_id;
  insert into public.student_google_accounts(auth_user_id,student_id) values(p_auth_user_id,v_student_id);
  return v_student_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.student_contact_state(p_student uuid, p_claim boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare s public.students; d date := (now() at time zone 'Europe/Istanbul')::date; notify boolean:=false;
begin
 select * into s from public.students where id=p_student and role='student' for update;
 if not found then raise exception 'Student not found' using errcode='P0002'; end if;
 if public.student_contacts_complete(s.phone,s.email) then
   return jsonb_build_object('eksik',false,'donuk',false,'uyari',false);
 end if;
 if s.contact_deadline is null then
   s.contact_deadline:=now()+interval '15 days';
   update public.students set contact_deadline=s.contact_deadline where id=s.id;
 end if;
 if p_claim and now()<s.contact_deadline and s.contact_notice_day is distinct from d then
   notify:=true; update public.students set contact_notice_day=d where id=s.id;
 end if;
 return jsonb_build_object('eksik',true,'donuk',now()>=s.contact_deadline,'uyari',notify,
   'sonTarih',s.contact_deadline,'kalanGun',greatest(0,ceil(extract(epoch from(s.contact_deadline-now()))/86400)::int));
end $function$
;

CREATE OR REPLACE FUNCTION public.student_contacts_complete(p_phone text, p_email text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select coalesce(regexp_replace(p_phone,'[^0-9]','','g') ~ '^(05[0-9]{9}|905[0-9]{9})$',false)
    and coalesce(trim(p_email) ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$',false);
$function$
;

CREATE OR REPLACE FUNCTION public.teacher_students_create(p_actor uuid, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r jsonb; v text; result jsonb:='[]'; s public.students;
begin
 if not exists(select 1 from public.teachers where id=p_actor and active) then raise exception 'Teacher only' using errcode='42501'; end if;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows) not between 1 and 50 then raise exception 'Invalid batch' using errcode='22023'; end if;
 -- Serialize bulk creation and owner renames to avoid case-insensitive collisions.
 perform pg_catalog.pg_advisory_xact_lock(7783912);
 for r in select value from jsonb_array_elements(p_rows) loop
   v:=trim(r->>'username');
   if coalesce(length(v),0) not between 3 and 50 or v ~ '[<>[:cntrl:]]' or
      coalesce((r->>'class_no')::int,0) not between 1 and 8 or coalesce(length(trim(r->>'branch')),0) not between 1 and 10 or
      not coalesce(r->>'password_hash' like 'pbkdf2$210000$%',false) or
      (coalesce(r->>'school','')<>'' and length(r->>'school') not between 3 and 120) then raise exception 'Invalid student' using errcode='22023'; end if;
   if exists(select 1 from public.students where lower(username)=lower(v)) or exists(select 1 from public.teachers where lower(username)=lower(v)) then
     raise exception 'Username already used: %',v using errcode='23505';
   end if;
   insert into public.students(username,password_hash,class_no,selected_class,branch,school,teacher_id,role,status,email_verification_required)
     values(v,r->>'password_hash',(r->>'class_no')::int,(r->>'class_no')::int,trim(r->>'branch'),nullif(r->>'school',''),p_actor,'student','approved',false)
     returning * into s;
   result:=result || jsonb_build_array(jsonb_build_object('id',s.id,'username',s.username,'class_no',s.class_no,'branch',s.branch));
 end loop;
 insert into public.audit_logs(actor_role,actor_id,operation,target,payload)
 values('teacher',p_actor,'teacher_students_create',p_actor::text,jsonb_build_object('count',jsonb_array_length(result)));
 return result;
end $function$
;
