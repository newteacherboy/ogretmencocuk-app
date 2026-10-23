import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {makeValidator,validateDocument,validateBank,normalize} from '../tools/icerik-dogrula.mjs';
const read=async p=>JSON.parse(await readFile(new URL(p,import.meta.url),'utf8'));
const original=await read('../content/turkce/5-sinif/tema-1-oyun-dunyasi.json');
const registry=await read('../content/turkce/kaynaklar.json');
const schema=await makeValidator();
const options=()=>({schema,sourceCodes:new Set(registry.kaynaklar.flatMap(x=>x.kodlar)),themeCodes:new Set(registry.kaynaklar[0].kodlar)});
const mutate=fn=>{const d=structuredClone(original);fn(d);return validateDocument(d,options());};
test('5–7. sınıf bankaları birlikte, yinelenen kimlik veya soru olmadan doğrulanır',async()=>{const r=await validateBank();assert.deepEqual(r.errors,[]);assert.deepEqual(r.warnings,[]);assert.equal(r.classes,3);assert.equal(r.themes,18);assert.equal(r.words,540);assert.equal(r.readings,36);assert.equal(r.lessons,65);assert.equal(r.questions,1013);assert.equal(r.listening,18);assert.equal(r.writing,18);});
test('doğru cevap şıklarda yoksa reddedilir',()=>assert(mutate(d=>d.konular[0].testler[0].dogru='bulunmayan cevap').errors.some(x=>x.includes('tam bir kez'))));
test('indeks tabanlı eski cevap sözleşmesi yanlışlıkla kabul edilmez',()=>assert(mutate(d=>d.konular[0].testler[0].dogru=0).errors.some(x=>x.includes('şema'))));
test('Türkçe büyük/küçük harfle gizlenmiş yinelenen şık reddedilir',()=>assert(mutate(d=>{const q=d.konular[3].testler[0];q.secenekler[1]=q.secenekler[0].toLocaleUpperCase('tr-TR');}).errors.some(x=>x.includes('yinelenen seçenek'))));
test('şık sırası ve id değişse de yinelenen soru yakalanır',()=>assert(mutate(d=>{const q=structuredClone(d.konular[0].testler[0]);q.id+='-kopya';q.secenekler.reverse();d.konular[0].testler.push(q);}).errors.some(x=>x.includes('yinelenen soru'))));
test('yanlış sınıf kazanımı reddedilir',()=>assert(mutate(d=>d.konular[0].cikti='T.Y.8.16').errors.some(x=>x.includes('sınıfı geçersiz'))));
test('kazanım kodundaki fazla bölüm reddedilir',()=>assert(mutate(d=>d.konular[0].cikti='T.O.5.5.14').errors.some(x=>x.includes('şema'))));
test('uydurma fakat biçimce geçerli kod işaretsiz kabul edilmez',()=>assert(mutate(d=>d.konular[0].cikti='T.Y.5.999').errors.some(x=>x.includes('resmî kaynak'))));
test('doğrulanmayan kod açık işaretle uyarı listesine girer',()=>{const r=mutate(d=>{d.konular[0].cikti='T.Y.5.999';d.konular[0].kaynak_dogrulanmadi=true;});assert.equal(r.errors.length,0);assert(r.warnings.some(x=>x.includes('T.Y.5.999')));});
test('bozulmuş Türkçe karakterler yakalanır',()=>assert(mutate(d=>d.sozVarligi.kelimeler[0].ornek='Bozuk yazÄ± örneği.').errors.some(x=>x.includes('karakter'))));
test('aynı kelimenin tema içinde tekrarı yakalanır',()=>assert(mutate(d=>d.sozVarligi.kelimeler.push(structuredClone(d.sozVarligi.kelimeler[0]))).errors.some(x=>x.includes('yinelenen kelime'))));
test('çok kısa okuma metni reddedilir',()=>assert(mutate(d=>d.okumaParcalari[0].metin='Kısa metin.').errors.some(x=>x.includes('kelime; beklenen'))));
test('anlatım HTML içinde olay işleyici kabul edilmez',()=>assert(mutate(d=>d.konular[0].anlatimHTML='<p onclick="alert(1)">Metin</p>').errors.some(x=>x.includes('güvenli anlatım'))));
test('yazma görevi otomatik öğrenci onayına dönüştürülemez',()=>assert(mutate(d=>d.yazmaGorevleri[0].ogretmenDegerlendirmeli=false).errors.some(x=>x.includes('şema'))));
test('Türkçe I ve İ aynı olmayan doğru eşlemelerle normalleştirilir',()=>{assert.equal(normalize('İLETİŞİM'),'iletişim');assert.equal(normalize('IŞIK'),'ışık');assert.notEqual(normalize('I'),normalize('İ'));});

const sixthManifest=await read('../content/turkce/6-sinif/mufredat.json');
const sixth=await read('../content/turkce/6-sinif/tema-1-dilimizin-zenginligi.json');
const sixthOptions=()=>({schema,sourceCodes:new Set(registry.kaynaklar.flatMap(x=>x.kodlar)),themeCodes:new Set(registry.kaynaklar.find(x=>x.sinif===6&&x.tema===1).kodlar)});
test('6. sınıfın MEB sırası, saatleri ve tek parkur kararı korunur',()=>{
 assert.deepEqual(sixthManifest.temalar.map(t=>t.ad),['Dilimizin Zenginliği','Bağımsızlık Yolu','Farklı Dünyalar','İletişim ve Sosyal İlişkiler','Bilim ve Teknoloji','Lider Ruhlar']);
 assert.deepEqual(sixthManifest.temalar.map(t=>t.saat),[35,35,34,34,34,34]);
 assert.match(sixthManifest.parkurKurali,/seviye testi yok/);
 assert.match(sixthManifest.parkurKurali,/Tek Türkçe parkuru/);
});
test('6. sınıf okumasında alt ve üst kelime sınırı gerçekten uygulanır',()=>{
 for(const n of [299,501]){const d=structuredClone(sixth);d.okumaParcalari[0].metin=Array(n).fill('kelime').join(' ');assert(validateDocument(d,sixthOptions()).errors.some(x=>x.includes('beklenen 300–500')));}
 for(const n of [300,500]){const d=structuredClone(sixth);d.okumaParcalari[0].metin=Array(n).fill('kelime').join(' ');assert.deepEqual(validateDocument(d,sixthOptions()).errors,[]);}
});
test('resmî tema listesinden bir çıktı sessizce silinemez',()=>{
 const d=structuredClone(sixth);d.ogrenmeCiktilari.pop();assert(validateDocument(d,sixthOptions()).errors.some(x=>x.includes('resmî temanın çıktı listesi')));
});
test('önceki temanın sorusu tekrar olarak işaretlenmelidir',async()=>{
 const d=await read('../content/turkce/6-sinif/tema-2-bagimsizlik-yolu.json');
 const opt={schema,sourceCodes:new Set(registry.kaynaklar.flatMap(x=>x.kodlar)),themeCodes:new Set(registry.kaynaklar.find(x=>x.sinif===6&&x.tema===2).kodlar)};
 d.okumaParcalari[0].sorular[0].cikti='T.O.6.6';delete d.okumaParcalari[0].sorular[0].onKosul;
 assert(validateDocument(d,opt).errors.some(x=>x.includes('onKosul=true')));
 d.okumaParcalari[0].sorular[0].onKosul=true;assert.deepEqual(validateDocument(d,opt).errors,[]);
});

const seventh=await read('../content/turkce/7-sinif/tema-1-hayat-boyu-gelisim.json');
const seventhOptions=()=>({schema,sourceCodes:new Set(registry.kaynaklar.flatMap(x=>x.kodlar)),themeCodes:new Set(registry.kaynaklar.find(x=>x.sinif===7&&x.tema===1).kodlar)});
test('7. sınıf da TYMM programını ve altı temayı kullanır',async()=>{const m=await read('../content/turkce/7-sinif/mufredat.json');assert.equal(m.program,'TYMM');assert.deepEqual(m.temalar.map(x=>x.ad),['Hayat Boyu Gelişim','Bir Hilal Uğruna','İletişim ve Sosyal İlişkiler','Türk Sanatı','Okuma Kültürü','Hak ve Sorumluluklar']);});
test('7. sınıfta 349 kelimelik okuma reddedilir, 350 kabul edilir',()=>{for(const n of [349,350]){const d=structuredClone(seventh);d.okumaParcalari[0].metin=Array(n).fill('örnek').join(' ');const errors=validateDocument(d,seventhOptions()).errors;assert.equal(errors.some(x=>x.includes('beklenen 350–600')),n===349);}});
test('7. sınıf konusu 2019 biçimindeki 8. sınıf koduyla eşlenemez',()=>{const d=structuredClone(seventh);d.konular[0].cikti='T.8.3.9';assert(validateDocument(d,seventhOptions()).errors.some(x=>x.includes('sınıfı geçersiz')));});
