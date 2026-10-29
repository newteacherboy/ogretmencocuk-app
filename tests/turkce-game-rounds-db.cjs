const {createRequire}=require('node:module');const {PGlite}=createRequire(require('node:path').resolve('tools/package.json'))('@electric-sql/pglite');const fs=require('fs');
(async()=>{let db=new PGlite();await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema turkce_private;create table auth.users(id uuid primary key,email_confirmed_at timestamptz,raw_user_meta_data jsonb,raw_app_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql as 'select null::uuid';`);
await db.exec(fs.readFileSync('supabase/turkce-safe-auth-schema.sql','utf8'));
let scaffold=fs.readFileSync('supabase/turkce-reward-infrastructure.proposed.sql','utf8').replaceAll('public.turkce_question_keys','turkce_private.turkce_question_keys');await db.exec(scaffold);
await db.exec(fs.readFileSync('supabase/member-release/no-email.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/member.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/catalog.sql','utf8'));await db.exec(fs.readFileSync('supabase/member-release/admin.sql','utf8'));
const uid='10000000-0000-4000-8000-000000000001';await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),'{"username":"traaaaaaaaaa","grade":5,"full_name":"Test Öğrenci","school":"Deneme Okulu"}')`,[uid]);
let seq=0;async function call(op,p={}){p.request_id=`20000000-0000-4000-8000-${String(++seq).padStart(12,'0')}`;return(await db.query('select public.turkce_member_request($1,$2,$3) r',[uid,op,JSON.stringify(p)])).rows[0].r;}

const assert=require('assert/strict');
await db.exec(fs.readFileSync('supabase/member-release/game-rounds.sql','utf8'));
await db.exec(fs.readFileSync('supabase/member-release/game-rounds-catalog.sql','utf8'));
for(const activity_id of ['kelime-dedektifi','olay-treni','noktalama-tamircisi']){
 let prior=[];
 for(let round=0;round<3;round++){
  await db.query('update public.turkce_economy set energy=30 where user_id=$1',[uid]);
  const payload={mode:'game',activity_id,game_version:2};
  let run=await call('start',payload);assert.equal(run.questions.length,8);
  const ids=run.questions.map(q=>q.id);assert.equal(new Set(ids).size,8);
  assert.equal(ids.filter(id=>prior.includes(id)).length,0,'adjacent rounds must be disjoint');
  assert(run.questions.every(q=>!('answer' in q)&&!('answerOrder' in q)),'start must not leak solutions');
  const resumed=await call('start',payload);assert.equal(resumed.attempt_id,run.attempt_id);assert.deepEqual(resumed.questions,run.questions);assert.equal(resumed.economy.energy,27);
  const keys=(await db.query('select game_questions from public.turkce_attempts where id=$1',[run.attempt_id])).rows[0].game_questions;
  for(let index=0;index<8;index++){
   await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");
   const r=await call('answer',{attempt_id:run.attempt_id,index,answer:keys[index].answer});
   assert(r.correct);assert.equal(r.done,index===7);assert.equal(r.graded_total,8);
   if(index===7){assert.equal(r.correct_first,8);assert.equal(r.reward.xp,round===0?70:0);}
  }
  prior=ids;
 }
 console.log('PASS',activity_id,'8 unique questions, disjoint replay, resume, server grading and daily reward cap');
}
// An old client can still finish a legacy five-question attempt after deployment.
await db.query('update public.turkce_economy set energy=30 where user_id=$1',[uid]);
const old=await call('start',{mode:'game',activity_id:'olay-treni'});assert.equal(old.questions,undefined);
const resumed=await call('start',{mode:'game',activity_id:'olay-treni',game_version:2});assert.equal(resumed.attempt_id,old.attempt_id);assert.equal(resumed.questions,undefined);
for(let index=0;index<5;index++){
 await db.query("update public.turkce_attempts set last_action_at=now()-interval '1 second'");
 const key=(await db.query("select answer from turkce_private.turkce_question_keys where mode='game' and activity_id='olay-treni' and question_index=$1",[index])).rows[0];
 const r=await call('answer',{attempt_id:old.attempt_id,index,answer:key.answer});assert(r.correct);assert.equal(r.done,index===4);
}
assert.equal((await db.query("select has_table_privilege('authenticated','turkce_private.game_question_bank','select') allowed")).rows[0].allowed,false);
assert.equal((await db.query("select has_function_privilege('authenticated','public.turkce_member_request(uuid,text,jsonb)','execute') allowed")).rows[0].allowed,false);
console.log('PASS legacy resume and service-only catalog/RPC');await db.close();
})().catch(e=>{console.error(e);process.exit(1)});
