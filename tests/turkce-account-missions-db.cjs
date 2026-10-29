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
await db.exec('alter table auth.users add column email text; grant usage on schema auth to service_role;');
await db.exec(fs.readFileSync('supabase/member-release/character-shop.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/account-missions-routes.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/class-route-catalog.sql','utf8'));
async function feature(actor,op,p={}){p.request_id=`50000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_features_request($1,$2,$3) r',[actor,op,JSON.stringify(p)])).rows[0].r;}

async function account(op,p={}){p.request_id=`60000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_account_request($1,$2,$3) r',[uid,op,JSON.stringify(p)])).rows[0].r;}
assert((await account('profile')).preferences.onboarding_at,'existing users are not interrupted');
const fresh='10000000-0000-4000-8000-000000000003';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data)values($1,now(),'{"username":"trnewstudent","grade":5,"full_name":"Yeni Öğrenci","school":"Deneme Okulu"}')`,[fresh]);
let r=(await db.query("select public.turkce_account_request($1,'profile','{}') r",[fresh])).rows[0].r;assert.equal(r.preferences.onboarding_at,null,'new member gets onboarding');
await assert.rejects(()=>account('profile_update',{basic_avatar:'fake',start_grade:6,complete:true}),/Karakterini/);
r=await account('profile_update',{basic_avatar:'girl',start_grade:6,complete:true});assert.equal(r.preferences.start_grade,6);assert.equal(r.profile.grade,6);assert(r.preferences.onboarding_at);
const status=await account('route_status');assert.equal(status.grade,6);assert(status.activities.length>24);
await assert.rejects(()=>account('route_start',{activity_id:status.activities[1].id}),/Önce/);
await assert.rejects(()=>account('route_start',{activity_id:'7-1-soz-1'}),/sınıfa/);
let run=await account('route_start',{activity_id:status.activities[0].id});assert(run.questions.length);assert(run.questions.every(q=>!q.answer&&!q.explanation));const resumed=await account('route_start',{activity_id:status.activities[0].id});assert.equal(run.attempt_id,resumed.attempt_id);assert.equal(resumed.economy.energy,27);
const keys=(await db.query('select questions from turkce_private.class_route_attempts where id=$1',[run.attempt_id])).rows[0].questions;
for(let index=0;index<keys.length;index++){
 await db.query("update turkce_private.class_route_attempts set last_action_at=now()-interval '1 second'");
 r=await account('route_answer',{attempt_id:run.attempt_id,index,answer:keys[index].answer});assert(r.correct);if(index===keys.length-1){assert(r.done);assert(r.passed);assert.equal(r.reward.xp,140);}}
assert((await account('route_status')).done.includes(status.activities[0].id));
let tasks=await account('missions',{period:'daily'});assert.equal(tasks.tasks[0].count,1);
await assert.rejects(()=>account('mission_claim',{period:'daily',task:'study'}),/Önce/);
const xp=(await call('state')).economy.xp;
r=await account('mission_claim',{period:'daily',task:'route',xp:999999});assert.equal(r.reward.xp,40);
r=await account('mission_claim',{period:'daily',task:'route'});assert.equal(r.reward.xp,0);assert.equal(r.economy.xp,xp+40);
assert((await account('missions',{period:'daily'})).tasks[0].claimed);
assert.equal((await account('missions',{period:'weekly'})).tasks[0].target,4);
await account('profile_update',{basic_avatar:'boy',start_grade:8});assert.equal((await account('route_status')).grade,8);
await account('profile_update',{basic_avatar:'girl',start_grade:6});assert((await account('route_status')).done.includes(status.activities[0].id),'switching grade preserves prior progress');
await db.query('update auth.users set email=$1 where id=$2',['immutable@students.ogretmencocuk.invalid',uid]);
await account('username',{username:'newname05'});assert.equal((await db.query("select public.turkce_login_email('newname05') email")).rows[0].email,'immutable@students.ogretmencocuk.invalid');
assert.equal((await account('report')).stops,1);
for(const table of ['member_preferences','class_route_catalog','class_route_attempts','mission_claims'])assert.equal((await db.query(`select has_table_privilege('authenticated','turkce_private.${table}','select') ok`)).rows[0].ok,false);
await db.exec('set role service_role');
assert.equal((await account('profile')).preferences.start_grade,6);
assert.equal((await db.query("select public.turkce_login_email('newname05') email")).rows[0].email,'immutable@students.ogretmencocuk.invalid');
await db.exec('reset role');
console.log('PASS signup-only onboarding, profile, distinct grade routes/resume, prerequisites, server grading, permanent progress, daily/weekly claims, stable login alias and private reports');await db.close();})().catch(e=>{console.error(e);process.exit(1)});
