# Diji Medu Türkçe — uyarlama envanteri (Aşama 0)

İncelenen depo: `newteacherboy/ogretmencocuk-app`. Kaynak commit: `9bf9fcb3822eda936bef0ab9ec80c2bbc5ca7961` (22 Ekim 2026). Bu belge yalnızca keşif ve karar kaydıdır; uygulama, veritabanı, edge function ve canlı site değiştirilmemiştir.

## 1. Sahibin son kararı ve kapsam

22 Ekim 2026 tarihli sohbet talimatı, görev dosyasındaki başlangıç tanılama önerisinin yerine geçer:

- Kayıt sırasında **ve sonrasında seviye testi olmayacak**. Profil, rehber, kayıt sonrası başarı sayfası, eski bağlantılar ve sunucu girişleri birlikte ele alınacak.
- **Tek Türkçe parkuru** olacak: seçilen sınıf (5–8) → müfredat tema sırası → konu/etkinlik durakları. Yeni öğrenci kendi sınıfının ilk temasından başlayacak; A1–B2 veya ikinci parkur seçimi yapılmayacak.
- Ders içindeki alıştırmalar, mini testler ve öğretmen değerlendirmeleri devam edecek. Bunlar başlangıç/seviye belirleme testi değildir.
- Profilde sınıf güncellemesi, ikinci parkur seçimi anlamına gelmez. Sınıf değişikliği erişimi sunucuda doğrulanmalı; öğrencinin kayıtlı başarıları silinmemelidir.
- Eski placement API eylemleri yalnızca düğme gizlenerek açık bırakılmamalı: yeni deneme oluşturma/sonuç kaydetme devre dışı bırakılmalı; eski istemci çağrıları ödül veya üst tema erişimi üretmemeli.

### Kaldırılacak test ve ikinci parkur bağlantıları

| Yer | Bağlantı | Karar |
| --- | --- | --- |
| `first-discovery.js` | success ekranı, startSignupPlacement, placement eylemi ve CEFR skipLine | Test önerisi olmadan sınıfa göre doğrudan başlat. |
| `kisisel-bilgiler.js` | `.kb-placement`, `seviyeTestAc` | Profilde test bağlantısı kalmasın. |
| `index.html` | `seviyeTestAc`, `seviyeDavetGoster`, seviye tespit kartı, placement script/link etiketleri | Eski test, otomatik davet ve eski ekran girişleri kapatılacak. |
| `school-journey.js` | `learningNeedsTest`, `askLearningTest`, `purpose`, `setPurpose` | İkinci parkur seçimi ve teste dayalı yönlendirme kaldırılacak; tek Türkçe haritası. |
| `supabase/functions/diji-api/member-tools-api.ts` | `placementSave`, `startPlacementSave`, `startPointChoose`, `startPlacementFollowup`, `studyPlacementInvite`, `memberReminderClaim` placement türü | Yeni test kaydı/sonuca göre erişim ve test daveti üretme. Genel e-posta hatırlatmasını kapatma. |
| `feature-catalog.js`, `supabase/functions/diji-api/feature-catalog.ts`, `supabase/functions/medupro-api/feature-catalog.ts` | `seviye_tespit`, `seviyeTestAc` | Test özelliği kapalı; öğretmen ataması veya doğrudan çağrı bunu yeniden açmasın. |
| `supabase/functions/diji-api/start-path.mjs` ve `medupro-api` / `thematic-learning` kopyaları | `computeStartPath`, `placementLevel`, `learningTestValid`, `learningRoute: needs-test` | Sınıf/tema ilerlemesine dayanan tek erişim kuralını bir kaynaktan üret. |
| `start-path-access.mjs`, `study-placement-access.mjs`, demo hesabı | `placement_start_v1`, `placement_cefr_v2`, `start_point_v1` | Test verisi gerektirmeyen başlangıç; eski verileri silmeden yeni ödül/erişim üretmesini engelle. |

## 2. İnceleme yöntemi ve doğruluk sınırı

Depo ağacı GitHub bağlantısından alındı; standart HTTPS klonlama ağ zaman aşımına uğradı. Dosyalar aynı kaynak commitinden indirildi. Depoda `AGENTS.md` bulunmadı. Bu belge, dosya içerikleri ve import/fetch/üretim ilişkilerine dayanır. Canlı Supabase tablo sayısı, cron durumu, sırlar, Brevo ve OAuth ayarları bu aşamada sorgulanmadı; görev metnindeki sayılar doğrulanmış canlı ölçüm değildir.

Tarama kapsamı: 853 UTF-8 kaynak/içerik/test/dokümantasyon dosyası; JS/MJS/CJS/TS/JSON/HTML/CSS/SQL/YML/MD/PY/TXT/CONF/XML. Üçüncü taraf `vendor/`, SVG ve ikili medya tarama sayımlarına dahil değildir. Arşiv migration’lar toplamda dahil, aktif kaynak sütununda hariçtir. Yeni envanter kendini saymaz. Sayımlar büyük-küçük harfe duyarlı **sabit metin** eşleşmesidir; `A1` başka bir dizgenin içinde de sayılır.

## 3. Özellik bazında dönüşüm kararları

| Özellik | Mevcut davranış | Türkçe karşılığı ve karar |
| --- | --- | --- |
| Başlangıç ve kayıt | Kayıt sonrası test önerisi, CEFR başlangıcı ve profil testi. | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| Parkur ve ilerleme | Okul ve dil seviyesi yolları, rota seçimi ve durak erişimi. | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| Ders çalışma | A1–B2 tema, kelime, örnek, alıştırma ve sunucu oturumları. | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| Hikâye ve okuma | İngilizce hikâyeler, okuma soruları ve seviyeli hikâye rotası. | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| Konu oyunları | CEFR ve İngilizce dil bilgisi/söz varlığı oyun katalogları. | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| Diyaloglar | İngilizce diyalog ve çeviri alıştırmaları. | Dönüştür: günlük iletişim, hitabet ve görgü senaryoları; dinleme ve konuşma çıktılarıyla ilişkilendir. |
| Söz varlığı ve oyunlar | İngilizce-Türkçe kelime havuzları, şıklar, yazma/dinleme/sesli cevaplar. | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| Ses ve sözlü değerlendirme | İngilizce TTS, ses dosyaları ve telaffuz tanıma. | Dönüştür: tr-TR ile dinleme/sesli okuma. Türkçe ses bulunmazsa yabancı sese düşme; metin göster. Akıcılık ölçümü süre ve kelime doğruluğunu ayırır, öğretmen değerlendirmesi korunur. |
| Mezuniyet ve ödül | CEFR mezuniyetleri ve etkinliklere bağlı ödüller. | Dönüştür: 5–8. sınıf Türkçe başarıları; tek parkura bağla. XP/ekonomi, tekrar ödülü yasağı ve sunucu doğrulaması korunur. |
| Rehber ve maskot | İngilizce ders rehberi, Papi sohbeti, açılış ve yükleme metinleri. | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| Öğretmen alanı | İngilizce içerik seçimi, öğretmen sözlü ve ödev araçları. | Dönüştür: sınıf/şube → Türkçe tema/konu ödevi ve rapor; öğretmen onayı ve öğrenci erişim sınırları korunur. |
| Üyelik ve e-posta | Eski marka, OAuth anahtarları, misafir/demo ve posta metinleri. | Dönüştür: Türkçe marka, ayrı proje, 5. sınıf demo/misafir; mevcut üyelik güvenliği korunur. Apple düğmesi paket hazır olana kadar feature flag ile kapalı. |
| Tema ve uygulama kabuğu | Ana sayfa, marka, önbellek, metadata ve yasal sayfalar. | Dönüştür: Diji Medu Türkçe / DM Türkçe; kırmızı-beyaz vurgu, ikincil turkuaz. CSP ve sosyal/veli güvenliği gevşetilmez; yeni kaynakların ?v= ve SW sürümleri birlikte değiştirilir. |

Teknik İngilizce (`fetch`, değişken adları, protokol alanları) ile öğrenciye gösterilen İngilizce ders içeriği ayrılmalıdır. Eski ID alanlarının veritabanında bulunması otomatik silme gerekçesi değildir; içerik ve API geçişi kontrollü yapılır.

## 4. İçerik kaynakları ve üretim yönü

| Kaynak | Tüketici/kopya | Mevcut asıl kaynak ve hedef karar |
| --- | --- | --- |
| `content/turkce/5-sinif/mufredat.json` | 5. sınıfın altı tema iskeleti | Türkçe müfredat başlangıcı; resmi kaynaklar Aşama 1’de yeniden doğrulanacak. Dosyadaki kaynak beyanı bu envanterin bağımsız MEB doğrulaması değildir. |
| `content/turkce/5-sinif/tema-1-oyun-dunyasi.json` | 24 kelime, tek okuma parçası ve konu testleri | Örnek Türkçe içerik, taslak; asgari 30 kelime, iki uzun metin ve konu başına on soruya genişletilecek. dogru mevcut biçimde 0 tabanlı indekstir; şema bunu açıkça tanımlamalı. |
| `thematic-curriculum.json` | `supabase/functions/thematic-learning/curriculum.json` | Mevcut üretici scripts/build-thematic-learning.py; girdiler content/thematic-topics.txt, thematic-reference.json ve expansion TXT dosyalarıdır. Yeni asıl kaynak content/turkce olmalı; iki çıktı elle düzenlenmemeli. |
| `story-v2-curriculum.json` | `supabase/functions/diji-api/story-v2-curriculum.js` | JSON / export const STORY_V2_CHAPTERS JS ambalaj farkı; story-path.js JSON dosyasını fetch eder, story-api.ts JS modülünü import eder. Bu V2 için depoda açık üretici bulunamadı; yeni üretici tek Türkçe kaynaktan ikisini de çıkarmalı. |
| `scripts/build-story-curriculum.py` | `story-curriculum.js`, `supabase/functions/diji-api/story-curriculum.js` | Eski hikâye yazarlık/üretim kaynağı; yeni metinler content/turkce içinden türetilmeli. JS modülü ambalajı içerikle karıştırılmamalı. |
| `placement-bank.js` | `supabase/functions/diji-api/placement-bank.js` | Seviye testi bankası. Sahibin son kararıyla yeni Türkçe tanılama bankası üretme; feature flag ve API kontrolüyle kapat. |
| `start-placement-bank.js` | `supabase/functions/diji-api/start-placement-bank.js`, `start-placement-audio/*.mp3` | Kayıt sonrası başlangıç testi. Kapat; MP3 üretimini Türkçe seviye testi adına sürdürme. |
| `konu-oyunlari-a1.js`, `konu-oyunlari-a2.js` | `supabase/functions/diji-api/konu-oyunlari-a1.js`, `.../konu-oyunlari-a2.js` | İstemci ve API oyun içerikleri. Sınıf/tema/konu bankasından aynı cevap anahtarlarıyla üret. |
| `word-wheel-vocabulary.js` | Kelime çarkı ve meteor dahil oyun havuzları | Kök ve supabase/functions/diji-api/word-wheel-vocabulary.js içinde ES modülü kopyaları; Türkçe söz varlığı etkinliklerinden ikisi de üretilmeli. |
| `learning-dialogues.js` | Öğrenme/konuşma diyalogları | Kök ve supabase/functions/diji-api/learning-dialogues.js kopyaları; sunucu learning-companion.mjs import eder. Türkçe iletişim senaryolarından ikisini üret. |
| `original-reading-library.js` | Okuma kitaplığı | Kök ve supabase/functions/diji-api/original-reading-library.js kopyaları; özgün Türkçe metin ve sorular tek kaynaktan üretilecek. |
| `story-curriculum.js` | `story-path.js`, `supabase/functions/diji-api/story-api.ts` | Üretilen hikâye paketi; ikinci parkur olarak değil tek parkurun okuma etkinlikleri olarak kullan. |
| `supabase/functions/diji-api/graduation-catalog.json` | `route-graduations.mjs` ve mezuniyet arayüzü | Üretici scripts/build-thematic-learning.py; kökte aynı isimli dosya yok. Sınıf/tema başarıları için yeni tek kaynaktan türetilmeli. |
| `supabase/functions/diji-api/thematic-levels.json` | `supabase/functions/medupro-api/thematic-levels.json` | Sunucu katalog kopyaları; kökte aynı isimli dosya yok. CEFR yerine sınıf/tema erişimi üretilecek. |
| `content/thematic-*.txt` | Tematik içerik üretim girdileri | Eski İngilizce yazarlık kaynakları; yeni Türkçe üretim için asıl kaynak yapılmamalı. |
| `supabase/migrations/*.sql` | Veritabanı içerik, fonksiyon ve e-posta tanımları | Kurulum dosyaları yerinde değiştirilmez; yeni değişiklikler yeni migration. Bu aşamada hiçbir SQL çalıştırılmaz. |
| `supabase/diji-medu-gecmisi/` | Eski İngilizce projenin migration arşivi | Çalıştırılmayacak tarihsel kaynak. Arşivdeki sabit proje/alan adı satırları canlı bağımlılık sanılmamalı; ürün hedefi gereği sonraki PR’da taşınması/kaldırılması ayrıca kararlaştırılır. |

Hedef üretim sözleşmesi: `content/turkce` → doğrulayıcı → tek derleme betiği → ön yüz paketi + ilgili edge function paketleri. Aynı girdi aynı sıralı çıktıyı vermeli; CI, üretilen dosyalarda fark kalmadığını kontrol etmeli. Cevap/ödül doğrulamasının yetkisi sunucuda kalır.

## 5. Kök ile diji-api arasındaki aynı adlı dosyalar

Bu tablo, yalnızca içerik bankalarını değil ortak kuralları da kapsar. Eşitlik indirilen UTF-8 metinlerin doğrudan karşılaştırmasıyla belirlenir; indirme bütünlüğü ayrıca Git blob SHA-1 değerleriyle doğrulanır. Aynılık, hangi tarafın yazarlık kaynağı olduğunu tek başına kanıtlamaz; kaynak seçimi yukarıdaki üretim ilişkisine dayanır.

| Kök dosya | Sunucu kopyası | İçerik aynı mı? | Karar |
| --- | --- | --- | --- |
| `konu-oyunlari-a1.js` | `supabase/functions/diji-api/konu-oyunlari-a1.js` | Evet | content/turkce kaynaklı paketler üret. |
| `konu-oyunlari-a2.js` | `supabase/functions/diji-api/konu-oyunlari-a2.js` | Evet | content/turkce kaynaklı paketler üret. |
| `learning-dialogues.js` | `supabase/functions/diji-api/learning-dialogues.js` | Evet | content/turkce kaynaklı paketler üret. |
| `original-reading-library.js` | `supabase/functions/diji-api/original-reading-library.js` | Evet | content/turkce kaynaklı paketler üret. |
| `placement-bank.js` | `supabase/functions/diji-api/placement-bank.js` | Hayır | Kapat: seviye testi için yeni içerik üretilmez. |
| `progression-catalog.js` | `supabase/functions/diji-api/progression-catalog.js` | Evet | Ortak kuralı tek kaynaktan üret; güvenlik/ödül davranışı korunur. |
| `score-rules.js` | `supabase/functions/diji-api/score-rules.js` | Evet | Ortak kuralı tek kaynaktan üret; güvenlik/ödül davranışı korunur. |
| `start-placement-bank.js` | `supabase/functions/diji-api/start-placement-bank.js` | Evet | Kapat: seviye testi için yeni içerik üretilmez. |
| `story-curriculum.js` | `supabase/functions/diji-api/story-curriculum.js` | Hayır | content/turkce kaynaklı paketler üret. |
| `topic-games-core.mjs` | `supabase/functions/diji-api/topic-games-core.mjs` | Evet | Ortak kuralı tek kaynaktan üret; güvenlik/ödül davranışı korunur. |
| `word-wheel-vocabulary.js` | `supabase/functions/diji-api/word-wheel-vocabulary.js` | Evet | content/turkce kaynaklı paketler üret. |

Önemli kopya farkı: `placement-bank.js` istemci sürümü cevabın türünü ve aralığını denetliyor; diji-api kopyası daha eski sayı dönüşümüyle değerlendirme yapıyor. Aynı soru bankası bulunması aynı değerlendirme güvenliği anlamına gelmiyor. Sahibin son kararı uyarınca bu eski test API yolları kapatılmalı. `feature-catalog.js` ayrıca sunucularda `.ts` ambalajıyla bulunur; ortak kaynak/üretim kapsamına alınmalı.


## 6. İngilizce metin taraması

| Aranan sabit metin | Toplam eşleşme | Eşleşen satır | Dosya | Aktif kaynak eşleşmesi |
| --- | ---: | ---: | ---: | ---: |
| `İngilizce` | 621 | 336 | 86 | 567 |
| `English` | 110 | 59 | 41 | 91 |
| `CEFR` | 82 | 78 | 36 | 55 |
| `A1` | 2399 | 414 | 138 | 2178 |
| `en-US` | 51 | 48 | 22 | 39 |
| `en-GB` | 11 | 10 | 7 | 6 |
| `speechSynthesis` | 127 | 90 | 27 | 109 |
| `SpeechRecognition` | 24 | 14 | 8 | 16 |
| `telaffuz` | 11 | 11 | 8 | 6 |
| `pronunciation` | 7 | 7 | 7 | 3 |

Yeniden üretim için her terimde `rg --hidden -F -o TERIM` eşleşmeleri, `rg --hidden -F -l TERIM` dosyaları verir. Yukarıdaki uzantı/istisna kapsamı uygulanmalı; docs içindeki bu envanter hariç tutulmalıdır. Alt bölüm bütün eşleşen dosyaları içerir.

## 7. Dosya bazında izlenebilirlik

Her satırdaki ilk konum, yukarıdaki terimlerden birinin geçtiği gerçek satırdır. Tek bir minify satırı birçok eşleşme içerebilir. Tüm satırlar yerine ilk konum gösterilir; dosya içi tüm eşleşmeler `rg -n -F` ile bulunabilir.

| Dosya ve ilk satır | Bulunan terimler | Alan | Karar |
| --- | --- | --- | --- |
| `.github/workflows/topic-games-a1.yml:1` | A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `CHATGPT_GOREV.md:12` | İngilizce, English, CEFR, A1, en-US, en-GB, speechSynthesis, SpeechRecognition, telaffuz, pronunciation | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `README.md:45` | İngilizce, CEFR, telaffuz | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `activity-preview-social.js:16` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `approved-game-boards.js:5` | İngilizce | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `content/thematic-expansion.txt:2` | İngilizce, A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `content/thematic-topics.txt:64` | İngilizce, English | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `content/turkce/papi-gorsel-brief.md:13` | A1 | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `ders-vadi.js:163` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `docs/account-lifecycle-and-store-readiness.md:7` | English | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/all-ages-onboarding-placement-plan.md:11` | CEFR, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/approved-game-boards.md:5` | English, pronunciation | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/konu-oyunlari-a1-durum.md:1` | İngilizce, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/konu-oyunlari-a2-durum.md:1` | İngilizce, A1, telaffuz | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/learning-companion.md:7` | CEFR, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/learning-path-papi-exercise-flow.md:4` | İngilizce, A1, en-US | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/media-rights-manifest.json:1555` | A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/papi-learning-story.md:5` | English, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/papi-seviye-ilerlemesi.md:8` | CEFR, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/request-budget.md:3` | English | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/reward-repair.sql:91` | A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/route-expansion-20261020.md:1` | CEFR, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/route-graduations.md:5` | CEFR, A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/stability-audit-20261012.md:29` | A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `docs/thematic-learning.md:3` | A1 | Belge | Dönüştür: eski İngilizce bağlamını tarihsel kayıt olarak ayır; güncel tek parkur/testsiz kayıt kararını esas al. |
| `experience-preview-inner.html:1` | İngilizce, A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `experience-ui.js:52` | speechSynthesis, telaffuz | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `faithful-eight-games.js:7` | İngilizce, en-US, speechSynthesis, pronunciation | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `first-discovery.js:19` | İngilizce, A1, en-US, speechSynthesis | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `forest-workshop-preview-inner.html:208` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `forest-workshop-v1.js:19` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `game-access.js:5` | A1 | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `game-experience.js:7` | İngilizce | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `game-feedback.js:42` | İngilizce, en-US, speechSynthesis | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `gizlilik.html:26` | İngilizce, telaffuz | Tema ve uygulama kabuğu | Dönüştür: Diji Medu Türkçe / DM Türkçe; kırmızı-beyaz vurgu, ikincil turkuaz. CSP ve sosyal/veli güvenliği gevşetilmez; yeni kaynakların ?v= ve SW sürümleri birlikte değiştirilir. |
| `google-login.js:29` | İngilizce, A1 | Üyelik ve e-posta | Dönüştür: Türkçe marka, ayrı proje, 5. sınıf demo/misafir; mevcut üyelik güvenliği korunur. Apple düğmesi paket hazır olana kadar feature flag ile kapalı. |
| `hakkinda.html:1` | İngilizce, A1 | Tema ve uygulama kabuğu | Dönüştür: Diji Medu Türkçe / DM Türkçe; kırmızı-beyaz vurgu, ikincil turkuaz. CSP ve sosyal/veli güvenliği gevşetilmez; yeni kaynakların ?v= ve SW sürümleri birlikte değiştirilir. |
| `harf-adasi.js:47` | İngilizce, en-US, speechSynthesis | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `harf-bahcesi.js:38` | İngilizce | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `hesap-ac.html:29` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `hesap-dogrula.html:1` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `hesap-dondur.html:29` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `hesap-sil.html:29` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `hesap-sil.js:64` | İngilizce, English | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `index.html:463` | İngilizce, English, A1, en-US, en-GB, speechSynthesis, SpeechRecognition, telaffuz | Tema ve uygulama kabuğu | Dönüştür: Diji Medu Türkçe / DM Türkçe; kırmızı-beyaz vurgu, ikincil turkuaz. CSP ve sosyal/veli güvenliği gevşetilmez; yeni kaynakların ?v= ve SW sürümleri birlikte değiştirilir. |
| `kelime-atolyesi.js:8` | İngilizce, en-GB, speechSynthesis | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `kelime-rallisi.js:27` | İngilizce, en-US, speechSynthesis | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `kisisel-bilgiler.js:181` | A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `konu-oyunlari-a1.js:1` | English, A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `konu-oyunlari-a2.js:1` | İngilizce, English, A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `konu-oyunlari.js:10` | İngilizce, A1, en-US, speechSynthesis | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `learning-companion.css:77` | CEFR | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `learning-companion.js:28` | İngilizce, CEFR, A1, en-GB, speechSynthesis | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `learning-core.js:19` | İngilizce | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `learning-dialogues.js:5` | İngilizce, A1 | Diyaloglar | Dönüştür: günlük iletişim, hitabet ve görgü senaryoları; dinleme ve konuşma çıktılarıyla ilişkilendir. |
| `medupro.js:38` | İngilizce | Öğretmen alanı | Dönüştür: sınıf/şube → Türkçe tema/konu ödevi ve rapor; öğretmen onayı ve öğrenci erişim sınırları korunur. |
| `member-experience.js:23` | İngilizce, English, CEFR, A1, en-US, en-GB, speechSynthesis, SpeechRecognition | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `meteor.js:23` | İngilizce | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `notice-sharing.js:46` | İngilizce, CEFR | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `original-reading-library.js:5` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `oyna-v2.css:35` | CEFR | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `oyna-v2.js:95` | İngilizce, A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `papi-cards.js:5` | en-US, speechSynthesis | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `papi-chat.js:20` | İngilizce, A1 | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `papi-guide-content.js:26` | İngilizce, CEFR, A1 | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `papi-sayfa-turlari.js:41` | İngilizce, A1 | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `parkur-map-theme-v1.js:21` | İngilizce | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `parkur-seviye-onizleme.html:92` | İngilizce, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `parkur-theme.js:21` | İngilizce | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `placement-bank.js:1` | English, CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `portal-bootstrap.js:17` | İngilizce | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `profile-sections.css:46` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `progress-ui.js:17` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `progression-catalog.js:2` | A1 | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `progression-ui.js:18` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `question-calm-preview-inner.html:208` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `question-calm-v1.js:4` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `question-panels-preview-inner.html:208` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `route-graduation.js:26` | İngilizce | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `route-questions.css:46` | English | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `route-questions.js:8` | İngilizce, English, en-US, SpeechRecognition | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `school-adventure-v2.css:186` | English | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `scripts/build-start-placement-audio.py:2` | English | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `scripts/build-story-curriculum.py:5` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `scripts/build-thematic-learning.py:39` | A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `scripts/create-original-media.py:19` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `start-placement-bank.js:1` | English, CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `start-placement.js:7` | İngilizce, English, CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `story-curriculum.js:2` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-exercises-preview.html:33` | İngilizce | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-exercises.js:12` | İngilizce, en-US, speechSynthesis, SpeechRecognition | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-final-cards.js:9` | en-US | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-path.js:87` | İngilizce, A1, en-US, speechSynthesis | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-v2-curriculum.json:1` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `story-v2-ui.js:20` | İngilizce | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `study-ui.js:9` | A1, en-US, en-GB, speechSynthesis | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/ACCOUNT_DELETION.md:1` | English | Üyelik ve e-posta | Dönüştür: Türkçe marka, ayrı proje, 5. sınıf demo/misafir; mevcut üyelik güvenliği korunur. Apple düğmesi paket hazır olana kadar feature flag ile kapalı. |
| `supabase/GOOGLE_LOGIN_SETUP.md:1` | İngilizce | Üyelik ve e-posta | Dönüştür: Türkçe marka, ayrı proje, 5. sınıf demo/misafir; mevcut üyelik güvenliği korunur. Apple düğmesi paket hazır olana kadar feature flag ile kapalı. |
| `supabase/PRIVACY_REVIEW.md:1` | English | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/diji-medu-gecmisi/20261004211748_staged_progression_v1.sql:24` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/20261010195000_preserve_legacy_parkur_stops.sql:21` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/20261012234958_legacy_micro_progress_correction.sql:35` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/20261014122048_four_word_school_levels.sql:39` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/20261015212457_papi_ai_chat_limits.sql:31` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/route-expansion-20261020.sql:36` | A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/diji-medu-gecmisi/route-graduations-20261020.sql:11` | CEFR, A1 | Tarihsel arşiv | Kapat: üretim/kurulum girdisi olarak kullanma; eski migration dosyasını yerinde düzenleme. |
| `supabase/functions/account-delete/core.mjs:140` | İngilizce | Üyelik ve e-posta | Dönüştür: Türkçe marka, ayrı proje, 5. sınıf demo/misafir; mevcut üyelik güvenliği korunur. Apple düğmesi paket hazır olana kadar feature flag ile kapalı. |
| `supabase/functions/diji-api/graduation-catalog.json:1` | A1 | Mezuniyet ve ödül | Dönüştür: 5–8. sınıf Türkçe başarıları; tek parkura bağla. XP/ekonomi, tekrar ödülü yasağı ve sunucu doğrulaması korunur. |
| `supabase/functions/diji-api/index.ts:2024` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/functions/diji-api/konu-oyunlari-a1.js:1` | English, A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `supabase/functions/diji-api/konu-oyunlari-a2.js:1` | İngilizce, English, A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `supabase/functions/diji-api/learner-profile.mjs:3` | A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/learning-dialogues.js:5` | İngilizce, A1 | Diyaloglar | Dönüştür: günlük iletişim, hitabet ve görgü senaryoları; dinleme ve konuşma çıktılarıyla ilişkilendir. |
| `supabase/functions/diji-api/member-tools-api.ts:187` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/functions/diji-api/onboarding-api.ts:6` | İngilizce | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/original-reading-library.js:5` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `supabase/functions/diji-api/placement-bank.js:1` | English, CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/progression-api.ts:120` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/functions/diji-api/progression-catalog.js:2` | A1 | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `supabase/functions/diji-api/review-schedule.mjs:1` | CEFR | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/functions/diji-api/route-graduations.mjs:10` | A1 | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `supabase/functions/diji-api/start-path-access.mjs:7` | A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/start-path.mjs:4` | CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/start-placement-bank.js:1` | English, CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/diji-api/story-api.ts:14` | en-US | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `supabase/functions/diji-api/story-curriculum.js:1` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `supabase/functions/diji-api/story-v2-curriculum.js:2` | İngilizce, A1 | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `supabase/functions/diji-api/story-v2.ts:3` | İngilizce, en-US | Hikâye ve okuma | Dönüştür: özgün Türkçe okuma ve anlama etkinlikleri. Hikâyeler bağımsız ikinci parkur oluşturmaz; tek parkurun etkinlikleri ve okuma kitaplığı olarak bağlanır. |
| `supabase/functions/diji-api/study-placement-access.mjs:4` | A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/diji-api/thematic-levels.json:1` | A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/diji-api/topic-games-api.ts:7` | A1 | Konu oyunları | Dönüştür: sınıf/tema/konu filtresiyle Türkçe anlam, dil bilgisi ve yazım oyunları. İngilizce seçenekler, örnekler ve A1/A2 etiketleri değişir; sunucu cevap anahtarları birlikte üretilir. |
| `supabase/functions/diji-api/word-wheel-vocabulary.js:798` | İngilizce, English, telaffuz, pronunciation | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `supabase/functions/medupro-api/progression-api.ts:102` | A1 | Öğretmen alanı | Dönüştür: sınıf/şube → Türkçe tema/konu ödevi ve rapor; öğretmen onayı ve öğrenci erişim sınırları korunur. |
| `supabase/functions/medupro-api/progression-catalog.js:2` | A1 | Parkur ve ilerleme | Dönüştür: sınıf → tema → durak düzeninde tek Türkçe parkuru; parkur seçme/değiştirme ve CEFR yönlendirmeleri kapatılır. Profilde sınıf güncellemesi ayrı tutulur; kayıtlı başarılar silinmez. |
| `supabase/functions/medupro-api/start-path-access.mjs:7` | A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/medupro-api/start-path.mjs:4` | CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/functions/medupro-api/thematic-levels.json:1` | A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/papi-chat/handler.ts:7` | İngilizce, English, CEFR | Rehber ve maskot | Dönüştür: Türkçe ders rehberi ve bayraklı SVG açılış. Papi sohbeti kapalı kalır. İlerleme göstergesi, hazır olunca kapanma ve azaltılmış hareket korunur. |
| `supabase/functions/thematic-learning/core.ts:15` | İngilizce, CEFR, A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/thematic-learning/curriculum.json:1` | İngilizce, English, A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/thematic-learning/learning-core.js:19` | İngilizce | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `supabase/functions/thematic-learning/start-path.mjs:4` | CEFR, A1 | Başlangıç ve kayıt | Kapat: kayıt sırasında ve sonrasında seviye/tanılama testi yok. Sınıf seçimi (5–8) tek parkurun ilk temasını belirler. Mevcut oturum ve kayıt güvenliği korunur. |
| `supabase/migrations/20261022000200_kisitlar_indeksler.sql:204` | A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/migrations/20261022000300_fonksiyonlar.sql:1691` | İngilizce, A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `supabase/migrations/20261022000400_tetikleyici_guvenlik.sql:162` | CEFR | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `teacher-workspace.js:150` | CEFR, A1 | Öğretmen alanı | Dönüştür: sınıf/şube → Türkçe tema/konu ödevi ve rapor; öğretmen onayı ve öğrenci erişim sınırları korunur. |
| `tests/account-deletion-sw.test.cjs:26` | English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/account-deletion-ui.cjs:22` | İngilizce | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/achievement-feed.sql:13` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/active-map-route-picker-ui.cjs:7` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/approved-route-panels.cjs:2` | A1, SpeechRecognition | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/assignment-completion.test.cjs:6` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/content-moderation.test.mjs:3` | English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/ders-notebook-ui.cjs:14` | English, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/ders-test-ui.cjs:15` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/ders-vadi-ui.cjs:24` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/dual-route.test.cjs:8` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/eight-game-fullscreen-ui.cjs:53` | İngilizce | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/evening-mobile-ui.cjs:23` | CEFR | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/faithful-eight-games-ui.cjs:70` | İngilizce | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/fixtures/ders-konu-ornek.json:2` | İngilizce, English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/game-access.test.cjs:25` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/game-feedback-ui.cjs:2` | A1, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/guest-platform-ui.cjs:6` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/learning-companion-ui.cjs:7` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/listening-speech.test.cjs:5` | İngilizce, English, en-US, en-GB, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/member-activity-ui.cjs:28` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/member-flow-regression-ui.cjs:12` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/member-tools.test.cjs:23` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/onboarding-registration.test.cjs:30` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/original-reading-library.test.cjs:4` | CEFR, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/oyna-carousel-ui.cjs:4` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-cards-dom.test.cjs:3` | speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-cards-ui.cjs:2` | speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-chat-mobile.cjs:8` | İngilizce, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-chat-ui.test.cjs:4` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-chat.test.cjs:5` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-onboarding-real-ui.cjs:2` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-onboarding-school-ui.cjs:2` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/papi-wallet-ui.cjs:10` | İngilizce | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/parkur-learning.test.cjs:26` | SpeechRecognition | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/placement-skipped-answers.test.cjs:8` | CEFR, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/portal-integrity.test.cjs:2` | English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/profile-forest-ui.cjs:8` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/progression-api.test.cjs:3` | CEFR, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/progression-full-ui.cjs:2` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/progression-ui.cjs:2` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/question-voice-ui.cjs:17` | English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/route-design-three-ui.cjs:18` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/route-expansion.test.cjs:8` | CEFR, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/route-graduations.test.cjs:4` | CEFR | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/route-matching-variety.cjs:18` | English | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/selected-play-ui.cjs:2` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/start-path.test.cjs:4` | CEFR, A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/story-exercises.cjs:16` | en-US | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/story-ui.cjs:2` | speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/study-search-focus.test.cjs:15` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/study-ui.cjs:6` | CEFR, A1, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/thematic-learning-ui.cjs:20` | CEFR, en-US, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-a2-topics.json:59` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-a2-ui.test.cjs:5` | A1, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-a2.test.cjs:3` | English, A1, pronunciation | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-db.test.cjs:7` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-live-db.sql:16` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-live.cjs:5` | A1, speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-topics.json:3` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games-ui.test.cjs:4` | speechSynthesis | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/topic-games.test.cjs:4` | English, A1, pronunciation | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/universal-learning.test.cjs:10` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/universal-onboarding-ui.test.cjs:9` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/verified-parkur-ui.cjs:8` | English, SpeechRecognition | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `tests/world-badges-ui.cjs:33` | A1 | Test | Dönüştür: ilişkili modül PR’ında Türkçe sınıf/tema ve tek parkur davranışını doğrula; testi silerek geçirme. |
| `thematic-curriculum.json:1` | İngilizce, English, A1 | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `thematic-learning.js:45` | İngilizce, A1, en-US, speechSynthesis | Ders çalışma | Dönüştür: seçili sınıfın Türkçe temaları; konu anlatımı → örnek → alıştırma → mini test. Bunlar seviye testi değildir. Diğer sınıflar Tekrar/İleri etiketiyle sunulur. |
| `tools/rebrand.py:2` | İngilizce | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `weekly-preview-inner.html:7` | English, A1 | Diğer bağımlılıklar | Dönüştür: İngilizce ders bağlamını Türkçe içerik sözleşmesine uyarla; teknik İngilizce tanımlayıcıları körlemesine çevirme. |
| `word-wheel-vocabulary.js:798` | İngilizce, English, telaffuz, pronunciation | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |
| `word-wheel.js:23` | A1 | Söz varlığı ve oyunlar | Dönüştür: anlam, eş/zıt/sesteş anlam, deyim/atasözü, yazım, hece ve kelime türetme. word_bank gibi eski alanların anlamı açık bir uyarlama katmanıyla değiştirilir; sadece etiket değiştirmek yeterli değildir. |

## 8. Güvenlik ve bağımsız proje sınırı

Yeni içerik, mevcut özel oturum ve `diji-api` doğrulamasıyla servis edilir. Tarayıcıya doğrudan tablo yetkisi verilmez. Çocuk iletişim/veli kuralları, CSP, parola hash biçimi, hesap silme/dondurma ve mevcut ödül adaleti korunur. Seviye testi kaldırılırken yalnızca UI gizlemek yerine sunucu erişim/başlangıç/ödül yolları da kapatılmalıdır. Yeni sınıf/tema kimlikleri, eski CEFR kayıtlarını hatalı biçimde açmamalıdır.

| Eski bağımlılık taraması | Dosya | Toplam eşleşme |
| --- | ---: | ---: |
| `dijimedu.com` | 1 | 1 |
| `nxfqlutulxqzqgwewssd` | 0 | 0 |
| `diji-ingilizce-google-auth` | 4 | 4 |
| `isgnsmkboehygxxysria` | 42 | 59 |

Bu tarama kaynakta kalan dizgeleri gösterir; canlı servis bağlantısının gerçekleştiğini kanıtlamaz. Aktif kaynak/test/arşiv ayrımı yapılmadan toplu replace uygulanmamalıdır.

## 9. Sonraki PR sırası ve kabul ölçütleri

1. Aşama 1: şema + doğrulayıcı + 5. sınıf altı tam tema; sonra 6/7/8 ayrı içerik PR’ları. 5–7 TYMM ve 8. sınıf 2019 kapsamı resmi kaynaklardan doğrulanır; bulunamayan kodlar açıkça işaretlenir. Mevcut tema taslağı asgari hacmi karşılamıyor.
2. Aşama 2: tek kaynaklı paket üretimi; **seviye testinin tüm girişlerini kapatma ve sınıftan başlayan tek parkur**; tema/konu filtreleri ve sunucu doğrulaması.
3. Aşama 3: arayüz/yasal sayfalar/e-posta/rehber metinleri, bağımsız proje taraması.
4. Aşama 4: 60 KB altında SVG Papi + ölçülü bayrak, gerçek yükleme ilerlemesi ve reduced-motion.
5. Aşama 5: renk değişkenleri, kontrast, mobil ve gece/gündüz görsel doğrulama.
6. Aşama 6: üyelik/admin/öğretmen onayı; sınıf seçimi ile doğrudan başlangıç, test ve çift parkur geri gelmez.
7. Aşama 7: yalnız değişen function dağıtımı, uygulanmamış migration kaydı, Türkçe CI. PR birleştirmeleri sahibine aittir.

## 10. Aşama 0 doğrulama kaydı

- İndirme bütünlüğü: depodaki 1.149 dosyanın tümü kaynak commitindeki Git blob SHA-1 değeriyle aynı; eksik veya farklı kaynak dosyası yok.
- `rg` sabit metin taraması, 853 dosyada bağımsız sayımla karşılaştırıldı; on terimin tüm sayımları eşleşti.
- Node v24.19.0. Görevdeki `node --test tests/` bu sürümde klasörü modül gibi ele alarak `MODULE_NOT_FOUND` verdi. Aynı kapsamdaki 142 `tests/*.test.*` dosyası açık listeyle çalıştırıldı: **1.058 test; 1.017 geçti, 39 başarısız, 2 atlandı**. Bu sonuç, aşağıdaki bağımlılıklar kurulmadan önceki tam koşudur; yeşil sonuç değildir.
- İlk tam koşuda `jsdom` / `@electric-sql/pglite` eksikleri ve Chromium bulunamadı hataları da var. İkisi scratch ortamına sabit sürümlerle kuruldu (jsdom 26.1.0, pglite 0.3.14). Playwright indirmesi bozuk arşiv döndürdü; Chromium 153.0.8010.0 npm paketi üzerinden sağlandı. Projeye bağımlılık veya paket dosyası eklenmedi.
- Bağımlılıklar tamamlandıktan sonra 142 dosyalık koşu tekrar başlatıldı; **240 saniyede tamamlanmadı ve zaman aşımıyla sonlandırıldı**. Son tam özet oluşmadığından bu tekrar için geçme/kalma toplamı verilmez; ilk koşudaki başarısızlıklar giderilmiş varsayılmaz. Bazı test süreçleri açık kaldığı için bu çalışma başlangıç düzeyinde bir test altyapısı sorunu da kaydeder.
- `node tools/icerik-dogrula.mjs` çalıştırıldı: dosya mevcut olmadığı için başarısız (`MODULE_NOT_FOUND`). Doğrulayıcı Aşama 1 teslimidir; bu keşif PR’ında uygulama/araç kodu eklenmedi.
- Playwright + Chromium: özgün açılış HTML/CSS/JS parçasını izole fixture’da 360×740, 768×1024 ve 1440×900; gündüz/gece ve reduced-motion ayarında kontrol etti. Altı koşulda görsel çözüldü, yatay taşma yok, animasyon kapalı, hazır sinyalinde ilerleme %100 ve splash kapandı. Altı görsel, mevcut açılışın %42 ilerleme örneğidir; yeni bayraklı tasarım değildir.
- Gerçek `index.html`, localhost üzerinde 360×740 boyutunda da açıldı. Dış servis çağrıları engellendi; hiçbir canlı kayıt/oturum/veri değiştirilmedi. Açılış katmanı kapandı, sayfa JavaScript hatası ve yatay taşma yok. Bu test üyelik/OAuth uçtan uca doğrulaması değildir.
- Görsel gözlem: mevcut açılış gündüz/gece aynı krem zemini kullanıyor; görünen marka hâlâ DijiMedu. Türkçe marka ve bayraklı Papi, Aşama 3–5 kapsamındadır.

### İlk tam koşudaki başarısız dosyalar

| Dosya | Başarısız test/konteyner sayısı |
| --- | ---: |
| `tests/account-actions-ui.test.cjs` | 1 |
| `tests/achievement-actions.test.cjs` | 2 |
| `tests/active-time-clock.test.cjs` | 1 |
| `tests/bag-first-tap.test.cjs` | 1 |
| `tests/evening-ui.test.cjs` | 1 |
| `tests/google-signup-frontend.test.cjs` | 8 |
| `tests/legacy-micro-progress.test.cjs` | 2 |
| `tests/meteor-api.test.cjs` | 4 |
| `tests/meteor-dom.test.cjs` | 1 |
| `tests/mola-vakti-dom.test.cjs` | 1 |
| `tests/oyna-carousel.test.cjs` | 1 |
| `tests/papi-cards-dom.test.cjs` | 1 |
| `tests/papi-chat-ui.test.cjs` | 1 |
| `tests/parkur-learning.test.cjs` | 2 |
| `tests/profile-account-switch.test.cjs` | 1 |
| `tests/profile-return-poses.test.cjs` | 1 |
| `tests/social-safety-ui.test.cjs` | 1 |
| `tests/social-school-improvements.test.cjs` | 1 |
| `tests/student-management-api.test.cjs` | 2 |
| `tests/teacher-oral-selection.test.cjs` | 1 |
| `tests/topic-games-a2-ui.test.cjs` | 1 |
| `tests/topic-games-db.test.cjs` | 1 |
| `tests/topic-games-ui.test.cjs` | 1 |
| `tests/universal-onboarding-ui.test.cjs` | 1 |
| `tests/word-wheel-dom.test.cjs` | 1 |

Bu liste, eksik bağımlılık yüzünden dosyanın hiç yüklenemediği test konteynerlerini de içerir. Mevcut kod beklentileri arasında mikro durak ilerlemesi, Google kayıt, meteor, profil/harita ve donmuş hesap durum kodu assertion’ları da var. Aşama 0 bunları düzeltmek için uygulama koduna dokunmaz.

### Başlangıç ekranı görüntüleri

| Genişlik | Gündüz | Gece |
| --- | --- | --- |
| 360 px | [Gündüz](turkce-uyarlama-asama-0/acilis-360-day.png) | [Gece](turkce-uyarlama-asama-0/acilis-360-night.png) |
| 768 px | [Gündüz](turkce-uyarlama-asama-0/acilis-768-day.png) | [Gece](turkce-uyarlama-asama-0/acilis-768-night.png) |
| 1440 px | [Gündüz](turkce-uyarlama-asama-0/acilis-1440-day.png) | [Gece](turkce-uyarlama-asama-0/acilis-1440-night.png) |


Aşama 0 yeni öğrenme çıktısı veya etkinlik eklemez. Bu yüzden bu PR için kapsanan/yeni veya doğrulanamayan kazanım kodu yoktur; mevcut müfredat dosyasındaki kodlar henüz bağımsız doğrulanmış sayılmaz. Sahibin bu belge için yapması gereken yapılandırma adımı yoktur. OAuth, görseller ve okul ağı adımları ilgili uygulama aşamasında somutlaştırılacaktır.
