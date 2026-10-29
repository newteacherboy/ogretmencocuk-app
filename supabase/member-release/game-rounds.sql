-- New clients receive eight server-selected questions. Existing attempts retain their keys.
alter table public.turkce_attempts add column if not exists game_questions jsonb;
create table if not exists turkce_private.game_question_bank(
 activity_id text not null, question_id int not null, payload jsonb not null,
 primary key(activity_id,question_id)
);
alter table turkce_private.game_question_bank enable row level security;
revoke all on turkce_private.game_question_bank from public,anon,authenticated;
grant all on turkce_private.game_question_bank to service_role;
CREATE OR REPLACE FUNCTION public.turkce_member_request(actor uuid, op text, p jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 e public.turkce_economy%rowtype; a public.turkce_attempts%rowtype; k record; target uuid; profile public.turkce_profiles%rowtype;
 result jsonb; reward jsonb; rid uuid; steps int; total int; graded int; good boolean; advanced boolean; idx int; amount int:=0; coins int:=0; written int:=0;
 v_mode text; v_activity text; previous_questions jsonb; selected_questions jsonb; day date:=(now() at time zone 'Europe/Istanbul')::date; ratio numeric; speed numeric; penalty numeric; elapsed numeric;
begin
 -- Email verification and identity are checked by the Edge Function; only service_role can call this RPC.
 select * into e from public.turkce_economy where user_id=actor for update;
 if not found then raise exception 'Öğrenci profili bulunamadı.'; end if;
 select * into profile from public.turkce_profiles where id=actor;
 if profile.disabled then raise exception 'Hesabın yetkili tarafından duraklatıldı.';end if;
 if op not in ('state','leagues','social') then
 rid:=(p->>'request_id')::uuid;
 if rid is null then raise exception 'İstek kimliği gerekli.'; end if;
 select response into result from turkce_private.requests where user_id=actor and request_id=rid;
 if found then return result; end if;
 end if;
 if e.energy<30 then
 steps:=floor(extract(epoch from(now()-e.energy_refill_at))/1800);
 if steps>0 then e.energy:=least(30,e.energy+steps);e.energy_refill_at:=case when e.energy=30 then now() else e.energy_refill_at+steps*interval '30 minutes' end;end if;
 end if;
 if now()-e.gift_at>=interval '24 hours' then e.energy:=least(30,e.energy+5);e.gift_at:=now();end if;
 update public.turkce_economy set energy=e.energy,energy_refill_at=e.energy_refill_at,gift_at=e.gift_at where user_id=actor;
 update public.turkce_profiles set last_seen=now() where id=actor;

 if op='start' then
 v_mode:=p->>'mode';v_activity:=p->>'activity_id';
 select count(*) into total from turkce_private.turkce_question_keys where turkce_question_keys.mode=v_mode and activity_id=v_activity;
 if total=0 then raise exception 'Etkinlik bulunamadı.';end if;
 if v_mode='stop' and v_activity::int>1 and not exists(select 1 from public.turkce_stop_progress where user_id=actor and stop_id=v_activity::int-1) then raise exception 'Önce önceki durağı tamamla.';end if;
 update public.turkce_attempts set finished_at=now() where user_id=actor and turkce_attempts.mode=v_mode and activity_id=v_activity and finished_at is null and started_at<now()-interval '1 day';
 select * into a from public.turkce_attempts where user_id=actor and turkce_attempts.mode=v_mode and activity_id=v_activity and finished_at is null for update;
 if not found then
 amount:=case when v_mode='game' then 3 else total end;
 if e.energy<amount then raise exception 'Enerjin yetersiz. Her 30 dakikada 1 enerji yenilenir.';end if;
 update public.turkce_economy set energy=energy-amount,energy_refill_at=case when energy=30 then now() else energy_refill_at end where user_id=actor;
 if v_mode='game' and p->>'game_version'='2' then
 select game_questions into previous_questions from public.turkce_attempts
 where user_id=actor and mode='game' and activity_id=v_activity and finished_at is not null
 order by started_at desc,id desc limit 1;
 select jsonb_agg(payload order by priority,random_order) into selected_questions from (
  select b.payload,case when exists(select 1 from jsonb_array_elements(coalesce(previous_questions,'[]'::jsonb)) q where (q->>'id')::int=b.question_id) then 1 else 0 end as priority,random() as random_order
  from turkce_private.game_question_bank b where b.activity_id=v_activity
  order by priority,random_order limit 8
 ) picked;
 if jsonb_array_length(selected_questions)<>8 or selected_questions is null then raise exception 'Oyun soru havuzu hazırlanamadı.';end if;
 end if;
 insert into public.turkce_attempts(user_id,mode,activity_id,game_questions) values(actor,v_mode,v_activity,selected_questions) returning * into a;
 end if;
 result:=jsonb_build_object('attempt_id',a.id,'index',a.next_question,'mistakes',a.question_mistakes,'correct_first',a.correct_first,'wrong',a.wrong_attempts);
 if a.game_questions is not null then
 result:=result||jsonb_build_object('questions',(select jsonb_agg(q-'answer'-'answerOrder'-'answer_kind' order by n) from jsonb_array_elements(a.game_questions) with ordinality as x(q,n)));
 end if;
 elsif op='answer' then
 select * into a from public.turkce_attempts where id=(p->>'attempt_id')::uuid and user_id=actor for update;
 if not found then raise exception 'Deneme bulunamadı.';end if;
 idx:=(p->>'index')::int;
 if idx is null or idx<>a.next_question or a.finished_at is not null then raise exception 'Soru sırası değişti. Etkinliği yeniden açarak devam et.';end if;
 if now()-a.started_at>interval '1 day' then raise exception 'Denemenin süresi doldu.';end if;
 if now()-a.last_action_at<interval '450 milliseconds' then raise exception 'Cevabı okuyup yeniden dene.';end if;
 if a.game_questions is not null then
 if a.game_questions->idx is null then raise exception 'Soru bulunamadı.';end if;
 select a.game_questions->idx->'answer' as answer,a.game_questions->idx->>'answer_kind' as answer_kind into k;
 else
 select * into k from turkce_private.turkce_question_keys where mode=a.mode and activity_id=a.activity_id and question_index=idx;
 if not found then raise exception 'Soru bulunamadı.';end if;
 end if;
 good:=case when k.answer_kind='ungraded_text' then jsonb_typeof(p->'answer')='string' and length(trim(p->>'answer')) between 8 and 220 else k.answer=p->'answer' end;
 good:=coalesce(good,false);
 if good then
 if a.question_mistakes=0 and k.answer_kind<>'ungraded_text' then a.correct_first:=a.correct_first+1;end if;
 else a.question_mistakes:=a.question_mistakes+1;a.wrong_attempts:=a.wrong_attempts+1;end if;
 advanced:=good or (a.mode='stop' and k.answer_kind<>'ungraded_text') or a.question_mistakes>=3;
 if advanced then a.next_question:=a.next_question+1;a.question_mistakes:=0;end if;
 if a.game_questions is not null then total:=jsonb_array_length(a.game_questions);graded:=total;
 else
 select count(*),count(*) filter(where answer_kind<>'ungraded_text') into total,graded from turkce_private.turkce_question_keys where mode=a.mode and activity_id=a.activity_id;
 end if;
 reward:=jsonb_build_object('xp',0,'gold',0,'repeat',false,'passed',false);
 if a.next_question=total then
 a.finished_at:=now();
 if graded>0 and a.correct_first::numeric/graded>=0.6 then
 elapsed:=extract(epoch from (now()-a.started_at))*1000;
 ratio:=a.correct_first::numeric/graded;
 speed:=greatest(case when a.mode='game' then .4 else .5 end,least(1,1-greatest(0,elapsed-case when a.mode='game' then 75000 else 90000 end)/case when a.mode='game' then 480000 else 600000 end));
 penalty:=greatest(case when a.mode='game' then .4 else .5 end,1-a.wrong_attempts*case when a.mode='game' then .08 else .07 end);
 amount:=round(case when a.mode='game' then 70 else 140 end*ratio*speed*penalty);coins:=round(case when a.mode='game' then 30 else 80 end*ratio*speed*penalty);
 insert into public.turkce_reward_ledger(user_id,mode,activity_id,xp,gold) values(actor,a.mode,a.activity_id,amount,coins) on conflict do nothing;
 get diagnostics written=row_count;
 if written=1 then
 update public.turkce_economy set xp=xp+amount,gold=gold+coins,updated_at=now() where user_id=actor;
 insert into public.turkce_activity(user_id,kind,description,shared) values(actor,a.mode,case when a.mode='stop' then a.activity_id||'. durağı tamamladı.' else 'Bir Türkçe oyununu tamamladı.' end,profile.share_activity);
 else amount:=0;coins:=0;end if;
 if a.mode='stop' then insert into public.turkce_stop_progress(user_id,stop_id) values(actor,a.activity_id::int) on conflict do nothing;end if;
 reward:=jsonb_build_object('xp',amount,'gold',coins,'repeat',written=0,'passed',true);
 end if;
 end if;
 result:=jsonb_build_object('correct',good,'advanced',advanced,'index',a.next_question,'done',a.finished_at is not null,'correct_first',a.correct_first,'graded_total',graded,'wrong',a.wrong_attempts,'reward',reward,'ungraded',k.answer_kind='ungraded_text','correct_answer',case when advanced and k.answer_kind<>'ungraded_text' then k.answer else null end,'answer_kind',k.answer_kind);
 update public.turkce_attempts set next_question=a.next_question,correct_first=a.correct_first,wrong_attempts=a.wrong_attempts,question_mistakes=a.question_mistakes,last_action_at=now(),finished_at=a.finished_at,last_result=result where id=a.id;
 elsif op='preferences' then
 update public.turkce_profiles set share_activity=coalesce((p->>'share_activity')::boolean,share_activity),show_online=coalesce((p->>'show_online')::boolean,show_online),join_leagues=coalesce((p->>'join_leagues')::boolean,join_leagues),updated_at=now() where id=actor;
 if p->>'share_activity'='false' then update public.turkce_activity set shared=false where user_id=actor;end if;
 result:='{}'::jsonb;
 elsif op='friend_request' then
 select id into target from public.turkce_profiles where username=lower(p->>'username');
 if target is null or target=actor then raise exception 'Kullanıcı bulunamadı.';end if;
 if exists(select 1 from public.turkce_friendships where (requester=actor and recipient=target) or (requester=target and recipient=actor)) then raise exception 'Bu arkadaşlık isteği zaten var.';end if;
 if (select count(*) from public.turkce_friendships where requester=actor or recipient=actor)>=100 then raise exception 'Arkadaşlık sınırına ulaştın.';end if;
 insert into public.turkce_friendships(requester,recipient) values(actor,target);result:='{}'::jsonb;
 elsif op='friend_accept' then
 update public.turkce_friendships set accepted_at=now() where requester=(p->>'user_id')::uuid and recipient=actor and accepted_at is null;
 if not found then raise exception 'Bekleyen istek bulunamadı.';end if; result:='{}'::jsonb;
 elsif op='friend_remove' then
 delete from public.turkce_friendships where (requester=actor and recipient=(p->>'user_id')::uuid) or(recipient=actor and requester=(p->>'user_id')::uuid);result:='{}'::jsonb;
 elsif op='social' then
 result:=jsonb_build_object('friends',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'username',u.username,'accepted',f.accepted_at is not null,'incoming',f.recipient=actor,'online',f.accepted_at is not null and u.show_online and u.last_seen>now()-interval '3 minutes')) from public.turkce_friendships f join public.turkce_profiles u on u.id=case when f.requester=actor then f.recipient else f.requester end where actor in(f.requester,f.recipient)),'[]'::jsonb),'feed',coalesce((select jsonb_agg(x) from(select u.username,t.kind,t.description,t.created_at from public.turkce_activity t join public.turkce_profiles u on u.id=t.user_id where t.shared and u.share_activity and exists(select 1 from public.turkce_friendships f where f.accepted_at is not null and ((f.requester=actor and f.recipient=t.user_id)or(f.recipient=actor and f.requester=t.user_id))) order by t.created_at desc limit 40)x),'[]'::jsonb));
 elsif op='leagues' then
 if not profile.join_leagues then raise exception 'Önce lig sıralamasına katılmayı seç.';end if;
 v_mode:=coalesce(p->>'league','local');
 if v_mode not in ('local','super','champions','legends') then raise exception 'Lig bulunamadı.';end if;
 if public.turkce_level(e.xp)<(case v_mode when 'super' then 5 when 'champions' then 10 else 1 end) then raise exception 'Bu lig için seviyen yetersiz.';end if;
 result:=jsonb_build_object('rows',coalesce((select jsonb_agg(x) from(select u.username,case when v_mode='legends' then ec.xp else coalesce(sum(l.xp),0) end as xp from public.turkce_profiles u join public.turkce_economy ec on ec.user_id=u.id left join public.turkce_reward_ledger l on l.user_id=u.id and l.earned_at>=(date_trunc('week',now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul') where u.join_leagues and not u.disabled and (v_mode<>'local' or u.grade=profile.grade) and public.turkce_level(ec.xp)>=case v_mode when 'super' then 5 when 'champions' then 10 else 1 end group by u.id,u.username,ec.xp order by xp desc,u.username limit 100)x),'[]'::jsonb));
 elsif op='state' then result:='{}'::jsonb;
 else raise exception 'İşlem bulunamadı.';
 end if;
 select * into e from public.turkce_economy where user_id=actor;
 select * into profile from public.turkce_profiles where id=actor;
 result:=result||jsonb_build_object('ok',true,'economy',jsonb_build_object('energy',e.energy,'xp',e.xp,'gold',e.gold,'level',public.turkce_level(e.xp),'nextEnergySeconds',case when e.energy=30 then 0 else greatest(0,ceil(1800-extract(epoch from(now()-e.energy_refill_at)))) end),'profile',jsonb_build_object('username',profile.username,'grade',profile.grade,'full_name',profile.full_name,'school',profile.school,'share_activity',profile.share_activity,'show_online',profile.show_online,'join_leagues',profile.join_leagues),'completed',coalesce((select jsonb_agg(stop_id order by stop_id) from public.turkce_stop_progress where user_id=actor),'[]'::jsonb));
 if rid is not null then insert into turkce_private.requests(user_id,request_id,response) values(actor,rid,result);end if;
 return result;
end;$function$;

revoke all on function public.turkce_member_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_member_request(uuid,text,jsonb) to service_role;
