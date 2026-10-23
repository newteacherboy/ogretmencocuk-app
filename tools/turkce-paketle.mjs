#!/usr/bin/env node
// Source: only the reviewed Turkish content bank. No English/CEFR fallback.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=async p=>JSON.parse(await readFile(path.join(root,p),'utf8'));
const check=process.argv.includes('--check');
const registryPath='content/turkce/durak-kimlikleri.json';
let ids;try{ids=await read(registryPath);}catch(e){if(e.code!=='ENOENT')throw e;ids={};}
const catalog={version:'',grades:[]};let ordinal=Object.keys(ids).length;
const output=[];
for(const grade of [5,6,7,8]){
 const manifest=await read(`content/turkce/${grade}-sinif/mufredat.json`),group={grade,program:manifest.program,themes:[]};
 for(const item of manifest.temalar){
  const t=await read(`content/turkce/${grade}-sinif/${item.dosya}`),theme={number:t.tema,title:t.temaAdi,words:t.sozVarligi.kelimeler,activities:[],writing:t.yazmaGorevleri};
  const add=(id,kind,title,body,questions)=>{
   if(questions.length>12){const size=Math.ceil(questions.length/Math.ceil(questions.length/12));for(let j=0;j<questions.length;j+=size)add(id+'-bolum-'+(j/size+1),kind,title+' · '+(j/size+1),body,questions.slice(j,j+size));return;}
   if(!ids[id]){if(ordinal>=5000)throw Error('Reward namespace exhausted');const n=ordinal++;ids[id]=290000+Math.floor(n/50)*100+n%50+1;if(ids[id]>300000)throw Error('Reward namespace exhausted');}
   theme.activities.push({id,kind,title,body,questions,rewardId:ids[id]});
  };
  // Ten words per stop. Distractors come from the same reviewed theme.
  for(let i=0;i<theme.words.length;i+=10){const words=theme.words.slice(i,i+10);add(`${grade}-${t.tema}-soz-${i/10+1}`,'words',`Söz varlığı · ${i/10+1}`,words,words.map((w,j)=>({id:`${grade}-${t.tema}-kelime-${i+j}`,tip:'secim',soru:`“${w.kelime}” sözcüğünün bu temadaki anlamı nedir?`,secenekler:[w.anlam,...theme.words.filter(x=>x.anlam!==w.anlam).slice((i+j)%20,(i+j)%20+3).map(x=>x.anlam)],dogru:w.anlam,aciklama:w.ornek,cikti:w.cikti})));}
  for(const r of t.okumaParcalari)add(r.id,'reading',r.baslik,{text:r.metin,type:r.tur},r.sorular);
  for(const l of t.konular)add(`${grade}-${t.tema}-${l.kod}`,'lesson',l.ad,{html:l.anlatimHTML,examples:l.ornekler,code:l.cikti},l.testler);
  for(const l of t.dinleme)add(l.id,'listening',l.baslik,{text:l.metin},l.sorular);
  for(let i=0;i<t.lgsSorulari.length;i+=10)add(`${grade}-${t.tema}-lgs-${i/10+1}`,'lgs',`LGS · ${i/10+1}`,null,t.lgsSorulari.slice(i,i+10));
  for(const a of theme.activities){if(!a.questions.length||a.questions.length>12)throw Error(`Unexpected question count: ${a.id}`);if(new Set(a.questions.map(q=>q.id)).size!==a.questions.length)throw Error(`Duplicate questions: ${a.id}`);for(const q of a.questions)if(!q.secenekler.includes(q.dogru))throw Error(`Answer missing: ${q.id}`);}
  group.themes.push(theme);
 }
 catalog.grades.push(group);
}
if(new Set(catalog.grades.flatMap(g=>g.themes.flatMap(t=>t.activities.map(a=>a.id)))).size!==catalog.grades.reduce((n,g)=>n+g.themes.reduce((n,t)=>n+t.activities.length,0),0))throw Error('Duplicate activity ID');
catalog.version=createHash('sha256').update(JSON.stringify(catalog.grades)).digest('hex').slice(0,16);
const publicBank=structuredClone(catalog);
for(const g of publicBank.grades)for(const t of g.themes)for(const a of t.activities){delete a.rewardId;a.questions=a.questions.map(({dogru,aciklama,...q})=>q);}
output.push([registryPath,JSON.stringify(ids,null,2)+'\n'],['content/turkce/parkur.json',JSON.stringify({version:catalog.version,grades:publicBank.grades.map(g=>({grade:g.grade,program:g.program,file:`parkur-${g.grade}.json`,gamesAvailable:g.themes.some(t=>{const seen=new Set(),meanings=new Set();return t.words.filter(w=>{const k=w.kelime.normalize('NFC').toLocaleLowerCase('tr-TR'),m=w.anlam.normalize('NFC').toLocaleLowerCase('tr-TR');if(seen.has(k)||meanings.has(m))return false;seen.add(k);meanings.add(m);return true;}).length>=4;})}))})+'\n']);
for(const g of catalog.grades)output.push([`supabase/functions/diji-api/turkce-bank-${g.grade}.json`,JSON.stringify(g)+'\n']);
for(const g of publicBank.grades)output.push([`content/turkce/parkur-${g.grade}.json`,JSON.stringify({version:catalog.version,...g})+'\n']);
output.push(['supabase/functions/diji-api/turkce-bank.json',JSON.stringify({version:catalog.version})+'\n']);
for(const [p,data] of output){if(check){if(await readFile(path.join(root,p),'utf8')!==data)throw Error(`Generated file is stale: ${p}`);}else await writeFile(path.join(root,p),data);}
console.log(`Türkçe paket ${catalog.version}: ${ordinal} durak; ${check?'güncel':'oluşturuldu'}.`);
