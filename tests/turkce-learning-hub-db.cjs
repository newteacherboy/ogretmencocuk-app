const {createRequire}=require('node:module');const {PGlite}=createRequire(require('node:path').resolve('tools/package.json'))('@electric-sql/pglite');const fs=require('fs');
(async()=>{let db=new PGlite();await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema turkce_private;create table auth.users(id uuid primary key,email_confirmed_at timestamptz,raw_user_meta_data jsonb,raw_app_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql as 'select null::uuid';`);
await db.exec(fs.readFileSync('supabase/turkce-safe-auth-schema.sql','utf8'));
let scaffold=fs.readFileSync('supabase/turkce-reward-infrastructure.proposed.sql','utf8').replaceAll('public.turkce_question_keys','turkce_private.turkce_question_keys');await db.exec(scaffold);
await db.exec(fs.readFileSync('supabase/member-release/no-email.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/member.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/catalog.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/admin.sql','utf8'));
const uid='10000000-0000-4000-8000-000000000001';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"traaaaaaaaaa","grade":5,"full_name":"Test Öğrenci","school":"Deneme Okulu"}')`,[uid]);
let seq=0;async function call(op,p={}){p.request_id=`20000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid,op,JSON.stringify(p)])).rows[0].r;}

const assert=require('assert/strict');
await db.exec(fs.readFileSync('supabase/member-release/game-rounds.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/game-rounds-catalog.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/game-unlocks.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/learning-hub.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/study-catalog.sql','utf8'));
async function feature(actor,op,p={}){p.request_id=`50000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_features_request($1,$2,$3) r',[actor,op,JSON.stringify(p)])).rows[0].r;}
for(const activity_id of ['kelime-dedektifi','olay-treni','noktalama-tamircisi'])await assert.rejects(()=>call('start',{mode:'game',activity_id,game_version:3}),/seviyen/);
for(const [activity_id,min]of [['kelime-dedektifi',3],['olay-treni',6],['noktalama-tamircisi',9]]){
 const xp=(await db.query('select min(x) as xp from generate_series(0,10000) x where public.turkce_level(x)=$1',[min])).rows[0].xp;
 await db.query('update public.turkce_economy set xp=$1 where user_id=$2',[xp-1,uid]);await assert.rejects(()=>call('start',{mode:'game',activity_id,game_version:3}),/seviyen/);
 await db.query('update public.turkce_economy set xp=$1 where user_id=$2',[xp,uid]);const r=await call('start',{mode:'game',activity_id,game_version:3});assert.equal(r.questions.length,8);
}
console.log('PASS exact server XP thresholds unlock 3/6/9, browser level claims cannot bypass');
const lesson_id='5-1-hece';let initialXp=(await call('state')).economy.xp;
for(let iteration=0;iteration<2;iteration++){
 let start=await feature(uid,'study_start',{lesson_id});assert.equal(start.questions.length,8);assert(start.questions.every(q=>!q.answer&&!q.explanation));
 const resumed=await feature(uid,'study_start',{lesson_id});assert.equal(start.attempt_id,resumed.attempt_id);assert.deepEqual(start.questions,resumed.questions);
 const keys=(await db.query('select questions from turkce_private.study_attempts where id=$1',[start.attempt_id])).rows[0].questions;
 for(let index=0;index<8;index++){
 await db.query("update turkce_private.study_attempts set last_action_at=now()-interval '1 second'");
 const r=await feature(uid,'study_answer',{attempt_id:start.attempt_id,index,answer:keys[index].answer,xp:999999});assert(r.correct);assert.equal(r.done,index===7);if(index===7)assert.equal(r.reward.xp,iteration===0?200:0);
 }
 await assert.rejects(()=>feature(uid,'study_answer',{attempt_id:start.attempt_id,index:7,answer:keys[7].answer}),/Soru sırası/);
}
assert.equal((await call('state')).economy.xp,initialXp+200);
assert.equal((await feature(uid,'study_status')).lessons[0].score,100);
const other='10000000-0000-4000-8000-000000000002';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"trbbbbbbbbbb","grade":5,"full_name":"İkinci Öğrenci","school":"Deneme Okulu"}')`,[other]);
await db.query('update public.turkce_profiles set share_activity=true where id in ($1,$2)',[uid,other]);
const activity=(await db.query("insert into public.turkce_activity(user_id,kind,description,shared) values($1,'award','Başarı kazandı.',true) returning id",[uid])).rows[0].id;
await assert.rejects(()=>feature(other,'like',{activity_id:String(activity),liked:true}),/arkadaşlarının/);
assert.equal((await feature(other,'social')).feed.length,0);
await db.query('insert into public.turkce_friendships(requester,recipient,accepted_at) values($1,$2,now())',[uid,other]);
let feed=await feature(other,'social');assert(feed.feed.some(x=>x.id===String(activity)));
let liked=await feature(other,'like',{activity_id:String(activity),liked:true});assert.equal(liked.likes,1);assert(liked.liked);
liked=await feature(other,'like',{activity_id:String(activity),liked:true});assert.equal(liked.likes,1);
liked=await feature(other,'like',{activity_id:String(activity),liked:false});assert.equal(liked.likes,0);
await db.query('update public.turkce_profiles set share_activity=false where id=$1',[uid]);
assert.equal((await feature(other,'social')).feed.length,0);await assert.rejects(()=>feature(other,'like',{activity_id:String(activity),liked:true}),/görünmüyor/);
for(const table of ['study_catalog','study_attempts','activity_likes'])assert.equal((await db.query(`select has_table_privilege('authenticated','turkce_private.${table}','select') ok`)).rows[0].ok,false);
assert.equal((await db.query("select has_function_privilege('authenticated','public.turkce_features_request(uuid,text,jsonb)','execute') ok")).rows[0].ok,false);
console.log('PASS 30 lesson catalog, server grading/resume, one-time 200 XP, privacy and idempotent friend-only likes');
await db.close();})().catch(e=>{console.error(e);process.exit(1)});
