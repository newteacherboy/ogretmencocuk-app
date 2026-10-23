import {readFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const normalize=text=>String(text).normalize('NFC').toLocaleLowerCase('tr-TR').replace(/\p{P}/gu,' ').replace(/\s+/g,' ').trim();
const codePattern=/^(?:T\.[DOKY]\.[5-8]\.\d+|DYS\.(?:DO|KY)\.[5-8]\.\d+|T\.8\.[1-4]\.\d+)$/;
const brokenText=/Ä[±°Ÿž°]|Å[Ÿžž]|Ã[§¶¼‡–œ]|\uFFFD|\x00/;
const wordCount=text=>String(text).trim().split(/\s+/u).filter(Boolean).length;
const readJSON=async file=>JSON.parse(await readFile(file,'utf8'));

export async function makeValidator(root=project){
 const schema=await readJSON(path.join(root,'content/turkce/sema.json'));
 const ajv=new Ajv2020({allErrors:true,strict:true});
 return ajv.compile(schema);
}

// Semantic checks supplement JSON Schema. No network call or student data is involved.
export function validateDocument(document,{schema,sourceCodes=new Set(),themeCodes=new Set(),seenIds=new Set(),seenQuestions=new Set(),file='document'}={}){
 const errors=[],warnings=[];const fail=(at,message)=>errors.push(`${file}${at}: ${message}`);
 if(!schema(document)){
  for(const e of schema.errors||[])fail(e.instancePath,`şema: ${e.message}`);
  return {errors,warnings};
 }
 const grade=document.sinif;
 if(document.program!==(grade===8?'2019':'TYMM'))fail('/program','sınıf ile program uyumsuz');
 function checkCode(code,at,obj){
  if(!codePattern.test(code)||(code.startsWith('T.8.')?8:Number(code.split('.')[2]))!==grade)fail(at,'kazanım kodu biçimi veya sınıfı geçersiz');
  else if(!sourceCodes.has(code)){
   if(obj.kaynak_dogrulanmadi===true||document.kaynak_dogrulanmadi===true)warnings.push(`${file}${at}: kaynak doğrulanmadı: ${code}`);
   else fail(at,`resmî kaynak kaydında bulunmayan kod: ${code}; kaynak_dogrulanmadi=true gerekli`);
  }
 }
 function walk(value,at=''){
  if(typeof value==='string'){
   if(brokenText.test(value))fail(at,'Türkçe karakter bozulması veya geçersiz karakter');
   if(value!==value.normalize('NFC'))fail(at,'metin NFC biçiminde olmalı');
   return;
  }
  if(Array.isArray(value)){value.forEach((v,i)=>walk(v,`${at}/${i}`));return;}
  if(!value||typeof value!=='object')return;
  if(value.id){if(seenIds.has(value.id))fail(at+'/id',`yinelenen kimlik: ${value.id}`);seenIds.add(value.id);}
  if(value.cikti)checkCode(value.cikti,at+'/cikti',value);
  for(const field of ['ciktilar','ekCiktilar','ogrenmeCiktilari'])if(value[field])value[field].forEach((c,i)=>checkCode(c,`${at}/${field}/${i}`,value));
  if(value.tip==='secim'){
   const options=value.secenekler.map(value.yazimDuyarli?text=>text.normalize('NFC').replace(/\s+/g,' ').trim():normalize);
   if(new Set(options).size!==options.length)fail(at+'/secenekler','aynı anlama gelen yazım/harf farkıyla yinelenen seçenek');
   if(value.secenekler.filter(x=>x===value.dogru).length!==1)fail(at+'/dogru','doğru cevap seçeneklerde tam bir kez bulunmalı');
   const signature=normalize(value.soru)+'|'+[...options].sort((a,b)=>a.localeCompare(b,'tr')).join('|');
   if(seenQuestions.has(signature))fail(at+'/soru','yinelenen soru (şık sırası değişse de aynı soru)');seenQuestions.add(signature);
   if(!themeCodes.has(value.cikti)&&value.onKosul!==true&&value.kaynak_dogrulanmadi!==true)fail(at+'/cikti','tema dışındaki tekrar çıktısı için onKosul=true gerekli');
  }
  for(const [key,v] of Object.entries(value))walk(v,at+'/'+key);
 }
 walk(document);
 if(document.belgeTuru==='tema'){
  if(themeCodes.size&&document.kaynak_dogrulanmadi!==true&&JSON.stringify([...new Set(document.ogrenmeCiktilari)].sort())!==JSON.stringify([...themeCodes].sort()))fail('/ogrenmeCiktilari','kayıtlı program/tema çıktı listesi eksik veya farklı');
  const words=document.sozVarligi.kelimeler.map(v=>normalize(v.kelime));
  if(new Set(words).size!==words.length)fail('/sozVarligi/kelimeler','tema içinde yinelenen kelime');
  const limits={5:[250,400],6:[300,500],7:[350,600],8:[450,700]}[grade];
  document.okumaParcalari.forEach((r,i)=>{const count=wordCount(r.metin);if(count<limits[0]||count>limits[1])fail(`/okumaParcalari/${i}/metin`,`${count} kelime; beklenen ${limits.join('–')}`);});
  if(grade===8)document.lgsSorulari.forEach((q,i)=>{if(q.secenekler.length!==4)fail(`/lgsSorulari/${i}/secenekler`,'LGS alıştırmasında dört seçenek gerekli');});
  document.konular.forEach((l,i)=>{
   if(/<(?!\/?(?:p|ul|li|strong|em|h3)\b)[^>]*>/iu.test(l.anlatimHTML)||/\son\w+\s*=|javascript:|<(?:p|ul|li|strong|em|h3)\s+[^>]+>/iu.test(l.anlatimHTML))fail(`/konular/${i}/anlatimHTML`,'yalnızca özniteliksiz güvenli anlatım etiketleri kullanılabilir');
   if(!new RegExp(`^${grade}-${document.tema}-[a-z0-9-]+$`).test(l.kod))fail(`/konular/${i}/kod`,'konu kodu sınıf/tema ile uyumsuz');
  });
  document.yazmaGorevleri.forEach((w,i)=>{if(w.minKelime>w.maxKelime)fail(`/yazmaGorevleri/${i}`,'yazma kelime aralığı ters');});
  const texts=document.okumaParcalari.map(r=>normalize(r.metin));if(new Set(texts).size!==texts.length)fail('/okumaParcalari','aynı metin iki kez kullanılmış');
 }
 return {errors,warnings};
}

export async function validateBank(root=project){
 const schema=await makeValidator(root),base=path.join(root,'content/turkce');
 const registry=await readJSON(path.join(base,'kaynaklar.json'));
 const sourceCodes=new Set(registry.kaynaklar.flatMap(s=>s.kodlar)),seenIds=new Set(),seenQuestions=new Set();
 const result={errors:[],warnings:[],classes:0,themes:0,words:0,readings:0,lessons:0,questions:0,listening:0,writing:0};
 for(const grade of [5,6,7,8]){
  const dir=path.join(base,`${grade}-sinif`);let files=[];try{files=await readdir(dir);}catch(e){if(e.code!=='ENOENT')throw e;}
  if(!files.includes('mufredat.json')){if(files.some(f=>/^tema-.*\.json$/.test(f)))result.errors.push(`${grade}-sinif: tema var ancak müfredat yok`);continue;}
  const manifest=await readJSON(path.join(dir,'mufredat.json'));result.classes++;
  const checked=validateDocument(manifest,{schema,sourceCodes,file:`${grade}-sinif/mufredat.json`});result.errors.push(...checked.errors);result.warnings.push(...checked.warnings);
  if(checked.errors.length)continue;
  const listed=new Set(manifest.temalar.map(t=>t.dosya));
  for(const extra of files.filter(f=>/^tema-.*\.json$/.test(f)&&!listed.has(f)))result.errors.push(`${grade}-sinif/${extra}: müfredata bağlı olmayan tema dosyası`);
  if(new Set(manifest.temalar.map(t=>t.no)).size!==manifest.temalar.length)result.errors.push(`${grade}-sinif: yinelenen tema numarası`);
  if(grade===8&&manifest.temalar.length!==8)result.errors.push('8. sınıf: sekiz tema gerekli');
  if([5,6,7].includes(grade)&&manifest.temalar.length!==6)result.errors.push(`${grade}. sınıf: altı tema gerekli`);
  for(const [index,theme] of manifest.temalar.entries()){
   if(theme.no!==index+1)result.errors.push(`${grade}-sinif: tema sırası kesintisiz olmalı`);
   let d;try{d=await readJSON(path.join(dir,theme.dosya));}catch(e){result.errors.push(`${grade}-sinif/${theme.dosya}: okunamadı (${e.message})`);continue;}
   const entry=registry.kaynaklar.find(s=>s.sinif===grade&&s.tema===theme.no);
   if(!entry)result.errors.push(`${theme.dosya}: resmî tema kaynak kaydı eksik`);
   else if(d.kaynak!==entry.url||theme.kaynak!==entry.url)result.errors.push(`${theme.dosya}: tema kaynak adresi kayıtla uyuşmuyor`);
   const checked=validateDocument(d,{schema,sourceCodes,themeCodes:new Set(entry?.kodlar||[]),seenIds,seenQuestions,file:`${grade}-sinif/${theme.dosya}`});
   result.errors.push(...checked.errors);result.warnings.push(...checked.warnings);if(checked.errors.length)continue;
   if(d.sinif!==grade||d.tema!==theme.no||d.temaAdi!==theme.ad||d.program!==manifest.program)result.errors.push(`${theme.dosya}: müfredat ve tema kimliği uyuşmuyor`);
   if(JSON.stringify([...d.ogrenmeCiktilari].sort())!==JSON.stringify([...theme.ciktilar].sort()))result.errors.push(`${theme.dosya}: tema/müfredat çıktı listesi farklı`);
   const actual=d.konular.map(x=>x.kod).sort(),expected=theme.dilBilgisiKonulari.map(x=>x.kod).sort();
   if(JSON.stringify(actual)!==JSON.stringify(expected))result.errors.push(`${theme.dosya}: müfredattaki her konu için anlatım ve test gerekli`);
   result.themes++;result.words+=d.sozVarligi.kelimeler.length;result.readings+=d.okumaParcalari.length;result.lessons+=d.konular.length;result.listening+=d.dinleme.length;result.writing+=d.yazmaGorevleri.length;
   result.questions+=d.okumaParcalari.reduce((n,r)=>n+r.sorular.length,0)+d.konular.reduce((n,r)=>n+r.testler.length,0)+d.dinleme.reduce((n,r)=>n+r.sorular.length,0)+d.lgsSorulari.length;
  }
 }
 if(!result.classes)result.errors.push('Doğrulanacak müfredat bulunamadı');
 return result;
}

if(process.argv[1]&&pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url){
 try{
  const args=process.argv.slice(2),at=args.indexOf('--root'),root=at>=0?path.resolve(args[at+1]||''):project;
  const result=await validateBank(root);
  if(args.includes('--json'))console.log(JSON.stringify(result,null,2));
  else{console.log(`${result.classes} sınıf, ${result.themes} tema, ${result.words} kelime, ${result.readings} okuma, ${result.lessons} konu, ${result.questions} soru, ${result.listening} dinleme, ${result.writing} yazma`);for(const e of result.errors)console.error('HATA '+e);for(const w of result.warnings)console.warn('UYARI '+w);console.log(`${result.errors.length} hata, ${result.warnings.length} doğrulanmamış kaynak`);}
  process.exitCode=result.errors.length?1:0;
 }catch(e){console.error(e.message);process.exitCode=1;}
}
