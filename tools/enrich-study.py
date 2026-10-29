"""Build structured teaching cards and exact, code-rendered topic illustrations."""
import json,re
from pathlib import Path
from html.parser import HTMLParser
class TextBlocks(HTMLParser):
 def __init__(self): super().__init__();self.parts=[];self.current=[];self.tag=None
 def handle_starttag(self,tag,attrs):
  if tag in ('p','li'): self.current=[];self.tag=tag
 def handle_data(self,data):
  if self.tag:self.current.append(data)
 def handle_endtag(self,tag):
  if tag==self.tag:
   text=''.join(self.current).strip()
   if text:self.parts.append((tag,text))
   self.tag=None
# Each misconception is paired with a correction, not an unexplained right/wrong label.
meta={
'hece':('🔤',['hece','ünlü','tek harf'], 'Heceyi tahmin ederek bölme.', '“arkadaş” sözcüğü ar-ka-daş diye ayrılır. Her bölümde bir ünlü vardır.', ['ar','ka','daş'],'Üç ünlü → üç hece'),
'nokta':('●',['nokta','sıra','kısaltma'],'Her cümlenin sonuna nokta koyma.', '“Geldin mi?” bir sorudur; soru işareti ister. “Bugün geldim.” ise noktayla biter.', ['Bugün kitap okudum','.'],'Tamamlanmış haber cümlesi'),
'kisa-cizgi':('↔',['kısa çizgi','hece','satır'],'Kısa çizgi ile konuşma çizgisini karıştırma.', '“o-yun” içindeki kısa çizgi heceleri ayırır. Konuşma başında kullanılan “—” ise uzun çizgidir.', ['o','yun'],'o-yun · Hece sınırını göster'),
'isim-fiil':('🏃',['isim','fiil','cümle'],'Bir sözcüğün görevini cümleyi okumadan belirleme.', '“Yüzünü yıka.” cümlesindeki yüz isimdir. “Havuzda yüz.” cümlesindeki yüz ise eylem bildirir.', ['Çocuk','koşuyor'],'Varlık → hareket'),
'buyuk-harf':('🔠',['büyük harf','özel ad','cümle'],'Tür adlarını gereksiz yere büyük harfle yazma.', '“Ankara” bir şehrin özel adıdır. “şehir” ise aynı türden yerlerin ortak adıdır.', ['ankara','Ankara'],'Özel ad → büyük başlangıç'),
'virgul':('🧺',['virgül','eş görevli','seslenme'],'Her durakladığın yere virgül koyma.', '“Elma, armut ve muz aldım.” cümlesinde eş görevli adlar ayrılır. “ve” bağlacının iki yanına gereksiz virgül konmaz.', ['elma',',','armut','ve','muz'],'Eş görevli sözcükleri ayır'),
'soru-isareti':('❓',['soru','ayrı','soru eki'],'Soru ekini sözcüğe bitişik yazma.', '“Geldin mi?” doğru yazımdır. “Geldinmi?” biçimi yanlıştır; soru eki ayrı yazılır.', ['Geldin','mi','?'],'Soru eki ayrı, soru işareti sonda'),
'ismi-niteleyen':('🎨',['nasıl','hangi','kaç','isim'],'Özellik bildiren sözcüğü, belirttiği isimden koparma.', '“Kırmızı çanta” ifadesinde kırmızı sözcüğü çantanın rengini anlatır. “Nasıl çanta?” sorusunun cevabı kırmızıdır.', ['kırmızı','çanta'],'Nasıl çanta? → kırmızı'),
'sifat-fiil':('📖',['fiil','nitele','isim'],'Eylem kökenli her sözcüğü çekimli fiil sayma.', '“Okuyan çocuk” ifadesinde okuyan, çocuğun özelliğini anlatır. “Çocuk okuyor.” cümlesinde okuyor, yapılan işi bildirir.', ['okuyan','çocuk'],'Hangi çocuk? → okuyan çocuk'),
'ekleme':('➕',['ayrıca','üstelik','hatta','ekleme'],'Yeni bilgiyi önceki düşünceyle ilgisiz ekleme.', '“Kitap okudum. Ayrıca kısa bir özet yazdım.” cümlelerinde ikinci bilgi ilkini tamamlar.', ['Kitap okudum','ayrıca','özet yazdım'],'Bilgi + ilgili yeni bilgi'),
'unlem':('❗',['ünlem','duygu','uyarı'],'Güçlü duygu ile sıradan haberi aynı düşünme.', '“Eyvah, düştüm!” telaş bildirir. “Bugün parka gittim.” ise sıradan bir haber cümlesidir.', ['Eyvah',',','düştüm','!'],'Güçlü duygu → ünlem'),
'uzun-cizgi':('💬',['konuşma','uzun çizgi','satır'],'Konuşmacı değiştiğinde konuşmaları tek satırda birleştirme.', 'Her konuşmacının sözü yeni satırda konuşma çizgisiyle başlayabilir. Hece ayıran kısa çizgi bu görevi üstlenmez.', ['— Merhaba!','— Hoş geldin!'],'Yeni konuşmacı → yeni satır'),
'isimler':('🏷️',['özel ad','tür adı','isim'],'Özel ad ile ortak adı birbirine karıştırma.', '“Papi” belirli bir karakterin adıdır; özel addır. “papağan” ise bir türün ortak adıdır.', ['Papi','papağan'],'Özel ad ↔ tür adı'),
'amac':('🎯',['amaç','hedef','için'],'Amaç ile nedeni yalnızca “için” sözcüğüne bakarak ayırma.', '“Öğrenmek için okudum.” cümlesinde öğrenmek hedeftir. “Hasta olduğum için gelmedim.” cümlesinde hastalık gerçekleşmiş nedendir.', ['Öğrenmek için','kitap okudum'],'Hangi amaçla? → öğrenmek için'),
'duygu':('💛',['duygu','keşke','pişmanlık','dilek'],'“Keşke” sözcüğünü her cümlede aynı duyguyla yorumlama.', '“Keşke yarın güneş açsa.” dilektir. “Keşke arkadaşımı kırmasaydım.” ise geçmişe yönelik pişmanlık anlatır.', ['Yarın güneş açsa','Arkadaşımı kırmasaydım'],'Dilek ↔ pişmanlık'),
'sayilar':('🔢',['sayı','ayrı','sıra'],'Birden çok sözcükten oluşan sayıları bitiştirme.', '“Yirmi beş” ayrı yazılır. “5. sınıf” ifadesindeki nokta ise beşinci anlamını verir.', ['yirmi','beş'],'Birden çok sözcük → ayrı yazım'),
'uc-nokta':('…',['üç nokta','tamamlanmamış','devam'],'Üç noktayı tamamlanmış her cümlenin sonunda kullanma.', '“Masada elmalar, armutlar…” ifadesi saymanın sürebileceğini düşündürür. “Masada üç elma var.” ise tamamlanmış bir haberdir.', ['elmalar',',','armutlar','…'],'Sıralama devam edebilir'),
'kesme':('✍️',['kesme','özel ad','ek'],'Her ismin ekini kesmeyle ayırma.', '“Ankara’ya” özel ada gelen eki kesmeyle ayırır. “okula” tür adına gelen ek olduğu için kesme istemez.', ['Ankara', '’', 'ya'],'Özel ad + ek'),
'karsilastirma':('⚖️',['karşılaştırma','daha','gibi','benzerlik'],'Karşılaştırılan özelliği söylemeden yargıya varma.', '“Bu çanta ötekinden daha hafif.” cümlesinde karşılaştırılan özellik ağırlıktır. “Pamuk gibi yumuşak.” ifadesinde ise benzerlik vardır.', ['Bu çanta','daha hafif','öteki çanta'],'Hangi özellik? → ağırlık'),
'ozet':('📝',['özet','ana düşünce','ayrıntı'],'Özet yazarken bütün ayrıntıları tekrar etme.', 'Önce ana düşünceyi bul. Sonra temel bilgileri koruyup örnekleri ve gereksiz tekrarları azalt.', ['Ana düşünce','Temel bilgiler','Kısa anlatım'],'Seç → koru → kısalt'),
'zamir':('👤',['yerini','isim','ben','o'],'İsmi belirten sözcük ile ismin yerini tutan sözcüğü karıştırma.', '“Bu kitap benim.” cümlesinde bu, kitabı belirtir. “Bu benim.” cümlesinde ise bu, bir varlığın adının yerini tutar.', ['Ece kitabı aldı','O kitabı aldı'],'Ece → O · İsmin yerine geçer'),
'zaman-baglac':('⏳',['önce','sonra','bu sırada','zaman'],'Zaman sırasını yalnız sözcüklere bakıp olayları okumadan kurma.', '“Önce kitabı açtım, sonra okumaya başladım.” olayları sıraya koyar. “Bu sırada” ifadesi aynı anda gerçekleşen bir olayı da gösterebilir.', ['Önce','Sonra','Sonunda'],'Olay sırasını izle'),
 'tirnak':('❝',['tırnak','alıntı','söz'],'Tırnağı açıp kapatmayı unutma.', 'Annem “Kitabını getir.” dedi. Aktarılan sözün başlangıcı ve bitişi tırnakla gösterilmiştir.', ['Annem','“Kitabını getir.”','dedi.'],'Aktarılan sözün sınırlarını göster'),
'anlam-butunlugu':('🧩',['anlam','çelişki','kesinlik','olasılık'],'Kesinlik ile olasılığı aynı yargıda çeliştirme.', '“Kesinlikle belki gelir.” ifadesi çelişkilidir. “Belki gelir.” veya “Kesinlikle gelir.” denilerek anlatılmak istenen yargı seçilir.', ['Kesinlikle gelir','Belki gelir'],'Kesin yargı ↔ olası yargı'),
'yeniden-kurma':('🔄',['anlam','kendi','koru'],'Sözcükleri değiştirirken cümlenin anlamını değiştirme.', '“Arkadaşım bana yardım etti.” cümlesi “Arkadaşım bana destek oldu.” diye yeniden anlatılabilir. İki cümlede de aynı temel olay korunur.', ['Bana yardım etti','Bana destek oldu'],'Sözcükler değişebilir, temel anlam korunur'),
'ornek':('💡',['örneğin','mesela','örnek'],'Düşünceyle ilgisiz örnek seçme.', '“Düzenli hareket sağlıklıdır; örneğin yürüyüş yapabiliriz.” cümlesinde yürüyüş, hareket etmeye uygun bir örnektir.', ['Düzenli hareket','örneğin','yürüyüş'],'Düşünce → uygun somut örnek'),
'tekrar':('✅',['kontrol','noktalama','yazım'],'Bir metni yalnız cümle sonlarına bakarak kontrol etme.', 'Büyük harfleri, ekleri, sözcüklerin yazımını ve noktalama işaretlerini birlikte incele. Son okumada cümlelerin anlamca uyumunu da kontrol et.', ['Büyük harf','Sözcük / ek','Noktalama','Anlam'],'Dört adımda son okuma'),
'tahmin':('🔍',['ipucu','tahmin','kesin','belki'],'Tahmini kesin bilgi gibi sunma.', 'Gökyüzü bulutluysa “Galiba yağmur yağacak.” diyebiliriz. Bu bir tahmindir; gerçekleşip gerçekleşmediğini yeni bilgiyle kontrol ederiz.', ['Bulutlu gökyüzü','ipucu','Yağmur yağabilir'],'İpucu + düşünme → tahmin')}
path=Path('content/turkce/study-5.json');bank=json.loads(path.read_text());sources={}
for f in Path('content/turkce/5-sinif').glob('tema-*.json'):
 for item in json.loads(f.read_text())['konular']: sources[item['kod']]=item
for theme in bank['themes']:
 for lesson in theme['lessons']:
  source=sources[lesson['id']];slug=lesson['id'].split('-',2)[2];icon,keys,mistake,correction,tiles,caption=meta[slug]
  parser=TextBlocks();parser.feed(source['anlatimHTML'])
  lesson.update(icon=icon,keywords=keys,fullExplanation=[text for tag,text in parser.parts if tag=='p'],ruleExamples=[text for tag,text in parser.parts if tag=='li'],pitfall={'title':mistake,'explanation':correction},visual={'tiles':tiles,'caption':caption},workedExamples=[{'question':q['soru'],'answer':q['dogru'],'explanation':q['aciklama']} for q in source['testler'][2:5]])
path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+'\n')
print('30 konu: ayrıntılı anlatım, vurgulu kurallar, görsel şema, hata avcısı ve çözümlü örnekler.')
