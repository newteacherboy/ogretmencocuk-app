const {createRequire}=require('node:module');const {PGlite}=createRequire(require('node:path').resolve('tools/package.json'))('@electric-sql/pglite');const fs=require('fs');
(async()=>{let db=new PGlite();await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema turkce_private;create table auth.users(id uuid primary key,email_confirmed_at timestamptz,raw_user_meta_data jsonb,raw_app_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql as 'select null::uuid';`);
await db.exec(fs.readFileSync('supabase/turkce-safe-auth-schema.sql','utf8'));
let scaffold=fs.readFileSync('supabase/turkce-reward-infrastructure.proposed.sql','utf8').replaceAll('public.turkce_question_keys','turkce_private.turkce_question_keys');await db.exec(scaffold);
await db.exec(fs.readFileSync('supabase/member-release/no-email.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/member.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/catalog.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/admin.sql','utf8'));
const uid='10000000-0000-4000-8000-000000000001';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"traaaaaaaaaa","grade":5,"full_name":"Test Öğrenci","school":"Deneme Okulu"}')`,[uid]);
let seq=0;async function call(op,p={}){p.request_id=`20000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid,op,JSON.stringify(p)])).rows[0].r;}
const assert=require('assert/strict');assert.equal((await call('state')).economy.energy,30);
await assert.rejects(()=>call('start',{mode:'stop',activity_id:'2'}),/Önce/);
let a=await call('start',{mode:'stop',activity_id:'1'});assert.equal(a.economy.energy,24);let b=await call('start',{mode:'stop',activity_id:'1'});assert.equal(a.attempt_id,b.attempt_id);assert.equal(b.economy.energy,24);
for(let i=0;i<6;i++){await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");let ans=(await db.query("select answer,answer_kind from turkce_private.turkce_question_keys where mode='stop' and activity_id='1' and question_index=$1",[i])).rows[0];let r=await call('answer',{attempt_id:a.attempt_id,index:i,answer:ans.answer_kind==='ungraded_text'?'Anlamlı bir cümle yazıyorum.':ans.answer});assert.equal(r.correct,true);if(i===5){assert.equal(r.reward.xp,140);assert.deepEqual(r.completed,[1]);}}
assert.equal((await call('state')).economy.xp,140);await assert.rejects(()=>call('answer',{attempt_id:a.attempt_id,index:5,answer:'repeat'}),/Soru sırası/);

const uid2='10000000-0000-4000-8000-000000000002';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"trbbbbbbbbbb","grade":5,"full_name":"Test Öğrenci","school":"Deneme Okulu"}')`,[uid2]);
async function asOther(op,p={}){p.request_id=`30000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid2,op,JSON.stringify(p)])).rows[0].r;}
await call('friend_request',{username:'trbbbbbbbbbb'});assert.equal((await asOther('social')).friends[0].incoming,true);
await assert.rejects(()=>call('friend_accept',{user_id:uid2}),/Bekleyen/);await asOther('friend_accept',{user_id:uid});assert.equal((await call('social')).friends[0].accepted,true);
assert.equal((await asOther('social')).feed.length,0);await call('preferences',{share_activity:true,join_leagues:true,show_online:true});
await db.query("insert into public.turkce_activity(user_id,kind,description,shared)values($1,'award','Başarı kazandı.',true)",[uid]);assert.equal((await asOther('social')).feed.length,1);
assert.equal((await call('leagues')).rows.length,1);await assert.rejects(()=>call('leagues',{league:'champions'}),/seviyen/);
await call('preferences',{share_activity:false});assert.equal((await asOther('social')).feed.length,0);
await asOther('friend_remove',{user_id:uid});assert.equal((await call('social')).friends.length,0);
const rp={mode:'game',activity_id:'kelime-dedektifi',request_id:'40000000-0000-4000-8000-000000000001'};
const once=(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid,'start',JSON.stringify(rp)])).rows[0].r;
const again=(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid,'start',JSON.stringify(rp)])).rows[0].r;assert.deepEqual(once,again);assert.equal(once.economy.energy,21);

for(let run=0;run<2;run++){
 let game=await call('start',{mode:'game',activity_id:'kelime-dedektifi'});
 for(let i=0;i<5;i++){await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");const ans=(await db.query("select answer from turkce_private.turkce_question_keys where mode='game' and activity_id='kelime-dedektifi' and question_index=$1",[i])).rows[0].answer;const result=await call('answer',{attempt_id:game.attempt_id,index:i,answer:ans});if(i===4){assert.equal(result.reward.xp,run===0?70:0);assert.equal(result.reward.repeat,run!==0);}}
}
assert.equal((await call('state')).economy.xp,210);
const gameRetry=await asOther('start',{mode:'game',activity_id:'kelime-dedektifi'});
for(let n=1;n<=3;n++){
 await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");
 const retry=await asOther('answer',{attempt_id:gameRetry.attempt_id,index:0,answer:null});
 assert.equal(retry.advanced,n===3);assert.equal(retry.correct,false);
 if(n<3)assert.equal(retry.correct_answer,null);else assert.notEqual(retry.correct_answer,null);
}
console.log('PASS games keep retry behavior and hide solution until advancement');
let bad=await call('start',{mode:'stop',activity_id:'2'});let result;
for(let i=0;i<6;i++){
 const key=(await db.query("select answer,answer_kind from turkce_private.turkce_question_keys where mode='stop' and activity_id='2' and question_index=$1",[i])).rows[0];
 await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");
 result=await call('answer',{attempt_id:bad.attempt_id,index:i,answer:key.answer_kind==='ungraded_text'?'Anlamlı bir cümle yazıyorum.':null});
 assert.equal(result.advanced,true);assert.equal(result.index,i+1);assert.equal(result.correct_first,0);
 if(key.answer_kind!=='ungraded_text'){assert.equal(result.correct,false);assert.deepEqual(result.correct_answer,key.answer);await assert.rejects(()=>call('answer',{attempt_id:bad.attempt_id,index:i,answer:key.answer}),/Soru sırası/);}
}
console.log('PASS first wrong stop answer reveals solution and advances; replay cannot change score');
assert.equal(result.reward.passed,false);assert.deepEqual(result.completed,[1]);assert.equal(result.economy.xp,210);
await db.query("update public.turkce_reward_ledger set earned_at=now()-interval '8 days' where mode='stop'");
assert.equal((await call('leagues',{league:'local'})).rows[0].xp,70);assert.equal((await call('leagues',{league:'legends'})).rows[0].xp,210);
console.log('PASS game daily reward cap, failed run no reward/progress, Istanbul weekly vs all-time leagues');
assert.equal((await db.query("select has_function_privilege('authenticated','public.turkce_member_request(uuid,text,jsonb)','execute') ok")).rows[0].ok,false);
assert.equal((await db.query("select has_table_privilege('authenticated','turkce_private.turkce_question_keys','select') ok")).rows[0].ok,false);
console.log('PASS privacy, friendship acceptance/removal, league consent/level, idempotent start, service-only RPC');

await assert.rejects(()=>db.query("insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values(gen_random_uuid(),now(),'{\"username\":\"dijimedu\",\"grade\":5,\"full_name\":\"Fake Admin\",\"school\":\"School Name\"}')"),/Öğrenci/);
let audit=(await db.query("select public.turkce_admin_request($1,'update',$2) r",[uid,JSON.stringify({user_id:uid2,full_name:'Güncel Öğrenci',school:'Güncel Okul',grade:7,disabled:true})])).rows[0].r;assert.equal(audit.ok,true);await assert.rejects(()=>asOther('state'),/duraklat/);
assert.equal((await db.query("select has_function_privilege('authenticated','public.turkce_admin_request(uuid,text,jsonb)','execute') ok")).rows[0].ok,false);
console.log('PASS reserved admin identity, admin SQL edits/audit, suspended student guard');
await db.exec(fs.readFileSync('supabase/member-release/social-defaults.sql','utf8'));
let socialDefaults=(await call('state')).profile;assert.equal(socialDefaults.share_activity,true);assert.equal(socialDefaults.show_online,true);assert.equal(socialDefaults.join_leagues,true);
const uid3='10000000-0000-4000-8000-000000000003';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"trcccccccccc","grade":5,"full_name":"Yeni Öğrenci","school":"Deneme Okulu"}')`,[uid3]);
const fresh=(await db.query('select share_activity,show_online,join_leagues from public.turkce_profiles where id=$1',[uid3])).rows[0];assert.deepEqual(fresh,{share_activity:true,show_online:true,join_leagues:true});console.log('PASS existing and new profiles have all three social defaults enabled');
console.log('PASS schema, private catalog, locks/resume energy, server answers, sequential unlock, atomic reward, replay rejection');await db.close();})().catch(e=>{console.error(e);process.exit(1)});
