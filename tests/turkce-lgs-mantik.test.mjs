import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=async p=>JSON.parse(await readFile(new URL(p,import.meta.url),'utf8'));
const manifest=await read('../content/turkce/8-sinif/mufredat.json');
const normalize=s=>s.trim().toLocaleLowerCase('tr-TR');
function permutations(xs){if(!xs.length)return [[]];return xs.flatMap((x,i)=>permutations(xs.filter((_,j)=>i!==j)).map(rest=>[x,...rest]));}
for(const theme of manifest.temalar){
 const d=await read('../content/turkce/8-sinif/'+theme.dosya);
 const question=n=>d.lgsSorulari.find(q=>q.id===`8-${theme.no}-lgs-${n}`);
 test(`8/${theme.no}: basılı tablo üç koşulla bağımsız çözülür`,()=>{
  const q=question(1);const limit=Number(q.soru.match(/süre (\d+) dakikayı/)[1]);
  const rows=[...q.soru.matchAll(/([^\n]+): (\d+) dakika; kaynak notu (var|yok); ses gereksinimi (var|yok)\./g)];
  assert.equal(rows.length,4);
  const accepted=rows.filter(([,name,time,source,audio])=>Number(time)<=limit&&source==='var'&&audio==='yok').map(r=>r[1]);
  assert.deepEqual(accepted,[q.dogru]);assert.equal(q.secenekler.filter(x=>accepted.includes(x)).length,1);
 });
 test(`8/${theme.no}: sözel kurallar 24 olası sıralamada tek çözüm verir`,()=>{
  const q=question(2),stem=q.soru;
  const steps=stem.match(/yapılacaktır: (.*?)\./)[1].split(', ');
  const before=stem.match(/\. ([^.,]+), ([^.,]+) işleminden önce yapılır\./).slice(1).map(normalize);
  const after=stem.match(/\. ([^.,]+), ([^.,]+) işleminin hemen ardından gelir\./).slice(1).map(normalize);
  const last=normalize(stem.match(/\. ([^.]+) son işlemdir\./)[1]);
  const candidates=permutations(steps);assert.equal(candidates.length,24);
  const valid=candidates.filter(p=>p.indexOf(before[0])<p.indexOf(before[1])&&p.indexOf(after[0])===p.indexOf(after[1])+1&&p.at(-1)===last);
  assert.equal(valid.length,1);assert.equal(valid[0].join(' → '),q.dogru);
  assert.equal(q.secenekler.filter(x=>x===valid[0].join(' → ')).length,1);
 });
 test(`8/${theme.no}: miktar ve eksik alan koşulları birlikte sağlanır`,()=>{
  const q=question(13),minimum=Number(q.soru.match(/En az (\d+) çalışma/)[1]);
  const rows=[...q.soru.matchAll(/\n(I{1,3}|IV): (\d+) \/ (\d+)/g)];assert.equal(rows.length,4);
  const accepted=rows.filter(([,name,total,missing])=>Number(total)>=minimum&&Number(missing)===0).map(r=>r[1]);
  assert.deepEqual(accepted,[q.dogru]);
 });
 test(`8/${theme.no}: grafik sırası kaynak rakamlardan yeniden hesaplanır`,()=>{
  const q=question(18),pairs=[...q.soru.matchAll(/([ABCD]):(\d+)/g)];assert.equal(pairs.length,4);
  const expected=pairs.sort((a,b)=>Number(b[2])-Number(a[2])).map(r=>r[1]).join(' – ');
  assert.equal(q.dogru,expected);assert.equal(q.secenekler.filter(x=>x===expected).length,1);
 });
}
