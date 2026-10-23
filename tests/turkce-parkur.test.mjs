import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {markTurkish,findActivity,validateWriting} from '../supabase/functions/diji-api/turkce-core.mjs';
const read=async p=>JSON.parse(await readFile(new URL('../'+p,import.meta.url),'utf8'));
const BANK={...await read('supabase/functions/diji-api/turkce-bank.json'),grades:await Promise.all([5,6,7,8].map(g=>read(`supabase/functions/diji-api/turkce-bank-${g}.json`)))};
test('generated runtime packages are reproducible and contain only reviewed 5–8 Turkish content',()=>{execFileSync(process.execPath,['tools/turkce-paketle.mjs','--check'],{cwd:new URL('..',import.meta.url)});assert.deepEqual(BANK.grades.map(g=>g.grade),[5,6,7,8]);});
test('every question is reachable once; stable reward IDs never overlap the legacy route or alias rule',async()=>{
 const registry=await read('content/turkce/durak-kimlikleri.json'),ids=new Set();let sourceQuestions=0,runtimeQuestions=0;
 for(const g of BANK.grades){const manifest=await read(`content/turkce/${g.grade}-sinif/mufredat.json`);for(const t of manifest.temalar){const raw=await read(`content/turkce/${g.grade}-sinif/${t.dosya}`);sourceQuestions+=raw.okumaParcalari.flatMap(r=>r.sorular).length+raw.konular.flatMap(k=>k.testler).length+raw.dinleme.flatMap(d=>d.sorular).length+raw.lgsSorulari.length;}
  for(const t of g.themes)for(const a of t.activities){assert(!ids.has(a.id));ids.add(a.id);assert.equal(registry[a.id],a.rewardId);assert(a.rewardId>290000&&a.rewardId<=300000&&a.rewardId%100<=50);assert(a.questions.length<=12);if(a.kind!=='words')runtimeQuestions+=a.questions.length;for(const q of a.questions){assert.equal(markTurkish(q,q.dogru).correct,true,q.id);assert.equal(new Set(q.secenekler).size,q.secenekler.length);}}
 }
 assert.equal(runtimeQuestions,sourceQuestions);assert.equal(ids.size,252);assert.equal(new Set(Object.values(registry)).size,ids.size);
});
test('browser packages omit answer keys/explanations and match server decks',async()=>{for(const g of BANK.grades){const publicGrade=await read(`content/turkce/parkur-${g.grade}.json`);assert.equal(publicGrade.version,BANK.version);for(const t of publicGrade.themes)for(const a of t.activities){const server=findActivity(BANK,a.id).activity;assert.equal(a.questions.length,server.questions.length);for(const q of a.questions){assert(!('dogru'in q));assert(!('aciklama'in q));}}}});
test('Turkish diacritics and spelling-sensitive distractors survive grading; arbitrary answers are rejected',()=>{
 const q={secenekler:['IŞIK','İŞİK','ışık'],dogru:'IŞIK'};assert.equal(markTurkish(q,'ışık').correct,true);assert.equal(markTurkish(q,'İŞİK').correct,false);
 const spelling={secenekler:['her gün','hergün','Her gün'],dogru:'her gün',yazimDuyarli:true};assert.equal(markTurkish(spelling,'her gün').correct,true);assert.equal(markTurkish(spelling,'hergün').correct,false);assert.equal(markTurkish(spelling,'Her gün').correct,false);assert.throws(()=>markTurkish(spelling,{correct:true}));assert.throws(()=>markTurkish(spelling,'unknown'));
});
test('writing validates reviewed word limits and never invents automatic teacher scores',()=>{const t=BANK.grades[0].themes[0].writing[0];assert.throws(()=>validateWriting(t,'kısa yazı'));assert.equal(validateWriting(t,Array(t.minKelime).fill('sözcük').join(' ')).split(' ').length,t.minKelime);assert.throws(()=>validateWriting(t,Array(t.maxKelime+1).fill('sözcük').join(' ')));});
test('route predecessor follows the bank rather than browser grade, stage or CEFR claims',()=>{for(const g of BANK.grades){const all=g.themes.flatMap(t=>t.activities);assert.equal(findActivity(BANK,all[0].id).previous,null);for(let i=1;i<all.length;i++)assert.equal(findActivity(BANK,all[i].id).previous,all[i-1].id);}assert.equal(findActivity(BANK,'A1-1'),null);});
