# Görev: Diji Medu Türkçe'yi ortaokul Türkçe dersine tam uyarlamak

Bu dosya, bu repoda çalışacak yapay zekâ kod asistanı (ChatGPT / Codex) içindir. Baştan sona oku, sonra **Aşama 0**'dan başla. Her aşamayı ayrı bir dal ve ayrı bir PR olarak teslim et.

---

## 1. Proje hakkında bilmen gerekenler

- **Uygulama:** Diji Medu Türkçe. Ortaokul 5–8. sınıf öğrencileri için oyunlu Türkçe dersi uygulaması.
- **Adres:** https://ogretmencocuk.com (GitHub Pages, repo kökü doğrudan yayınlanır, `CNAME` dosyası var).
- **Repo:** `newteacherboy/ogretmencocuk-app`, dal `main`.
- **Kaynağı:** Uygulama, aynı geliştiricinin İngilizce uygulaması "Diji Medu"dan kopyalandı. Bu yüzden kodda hâlâ İngilizce dersine özgü pek çok şey var:
  - CEFR seviyeleri (A1/A2/B1/B2)
  - İngilizce kelimeler, İngilizce telaffuz (`speechSynthesis` `en-US`/`en-GB`, `SpeechRecognition`)
  - "Kelimeyi İngilizce söyle" gibi metinler
  - İngilizce hikâye, diyalog ve konu oyunu içerikleri
  - **Senin işin bunları Türkçe dersine çevirmek.**
- **Diji Medu ile bağı yok:** Bu proje Diji Medu'dan tamamen bağımsızdır. Ayrı Supabase hesabı, ayrı öğrenciler. Kodda `dijimedu.com`, eski Supabase proje kimliği ya da İngilizce uygulamaya giden hiçbir bağlantı kalmamalı.
- **Ön yüz:** Derleme aracı yok, saf HTML/CSS/JS. Ana dosya `index.html` (~26 bin satır, içinde çok sayıda satır içi `<script>`). Yanında 120+ js ve 90+ css dosyası var. Dosya sürümleri `?v=` ile önbellekten çıkarılır; değiştirdiğin her dosyanın `?v=` değerini artır. Service worker `sw.js` içindeki önbellek listesi ve sürümü de güncellenmeli.
- **Arka uç:** Supabase. Proje kimliği `isgnsmkboehygxxysria`, bölge Frankfurt.
  - URL: `https://isgnsmkboehygxxysria.supabase.co`
  - Publishable anahtar: `sb_publishable_C79a3Zjz90omNzGLMFf1YQ_mEH1cwAa` (herkese açık, kodda zaten var)
- **Veritabanı:** 108 tablo, 128 fonksiyon, 13 zamanlanmış iş (pg_cron). Kurulum dosyaları `supabase/migrations/` içinde.
  - Tüm tablolar `anon`/`authenticated` rollerine kapalıdır, RLS açıktır.
  - Tarayıcı veritabanına **doğrudan erişmez**. Her şey edge function `diji-api` üzerinden, `service_role` ile yapılır. Bu güvenlik modelini bozma.
- **Edge function'lar** (`supabase/functions/`):
  - diji-api (ana API, `index.ts` + modüller)
  - account-delete, medupro-api, kelime-rallisi, teacher-oral, thematic-learning
  - papi-chat (kapalı)
  - papi-progress-worker / -optin / -unsubscribe
- **Üyelik sistemi:** Kendi oturum sistemi var, Supabase Auth'un e-posta/şifre girişi kullanılmıyor.
  - Tablolar: `students`, `teachers`, oturum tablosu.
  - Roller: `student` ve `teacher`. Öğretmenlerden `is_admin` olanlar yöneticidir.
  - Şifreler sunucuda hash'lenir: `diji-api/password-security.mjs`.
  - Google ile giriş Supabase Auth OAuth ile yapılır ve sunucuda öğrenciyle eşleştirilir (`supabase/GOOGLE_LOGIN_SETUP.md`). Apple girişi de kodda var.
  - E-postalar Brevo üzerinden gider (`BREVO_API_KEY` sırrı Supabase'de tanımlı, alan adı DKIM/DMARC doğrulandı).
- **Sınıf sınırı:** Sınıf seçimi zaten yalnızca ortaokul 5–8 olarak kısıtlandı. Kısıtın olduğu dosyalar:
  - `learner-profile.mjs`, `admin-students-api.ts`
  - `first-discovery.js`, `kisisel-bilgiler.js`
- **Testler:** `tests/` klasöründe 260+ Node testi var; `node --test tests/<dosya>` ile çalışır. Bazı testler İngilizce içeriğe bağlı. İçerik değiştikçe bu testleri Türkçe kurallara göre güncelle; testi silerek "geçirme".
- **Maskot:** Papi, turkuaz-mavi bir papağan. Karar: Papi kalacak ve Türkiye tişörtü giyecek. Görsel brifi `content/turkce/papi-gorsel-brief.md` dosyasında.

### Mevcut Türkçe içerik (başlangıç noktan)
- `content/turkce/5-sinif/mufredat.json`: 5. sınıf TYMM Türkçe'nin 6 teması, ders saatleri, öğrenme çıktısı kodları ve dil bilgisi konuları. Kaynak tymm.meb.gov.tr.
- `content/turkce/5-sinif/tema-1-oyun-dunyasi.json`: 1. tema için örnek içerik. **Bütün içeriği bu biçimde üret.**
  - 24 kelime ile eş, zıt ve sesteş anlamlı kelimeler
  - Özgün okuma metni ve 8 soru
  - 5 konu anlatımı ve 35 test sorusu
  - Soru biçimi: `{tip, soru, secenekler, dogru, aciklama}`

---

## 2. Değişmez kurallar

1. **Müfredat doğruluğu**
   - **5., 6. ve 7. sınıf:** 2026–2027'de Türkiye Yüzyılı Maarif Modeli (TYMM) uygulanıyor. Temaları, öğrenme çıktılarını (kodlarıyla, ör. `T.O.5.1.`) ve dil bilgisi konularını **tymm.meb.gov.tr**'deki Ortaokul Türkçe öğretim programından ve yıllık planlardan al.
   - **8. sınıf:** 2026–2027'de henüz TYMM'ye geçmedi. MEB'in yürürlükteki Türkçe Dersi Öğretim Programı'nı (2019) ve LGS kapsamını esas al. İçeriği, TYMM 8. sınıf programı yayımlanınca güncellenebilecek şekilde `program: "2019"` alanıyla işaretle.
   - Kazanımı uydurma. Kaynağını bulamadığın kodu `"kaynak_dogrulanmadi": true` ile işaretle ve PR açıklamasında listele.
2. **Telif**
   - Ders kitaplarından, yayınevlerinden ya da internetten metin, soru veya görsel **kopyalama**. Bütün okuma metinleri, şiirler, diyaloglar ve sorular özgün olmalı.
   - Telif süresi dolmuş klasik eserlerden (ör. Ömer Seyfettin, Mehmet Akif'in İstiklal Marşı) kısa alıntı yapılabilir; kaynağını belirt.
3. **Dil**
   - Arayüz ve içerik doğru, sade, yaşa uygun Türkiye Türkçesi olmalı. TDK yazım kurallarına uy: ğ, ı, İ, ş, ç, ö, ü ve şapkalı harfler (kâğıt, hâlâ) doğru yazılmalı.
   - Büyük-küçük harf dönüşümünde `toLocaleUpperCase('tr-TR')` kullan. `toUpperCase()` "i"yi yanlış çevirir.
   - Sıralama ve karşılaştırmada `localeCompare(x, 'tr')` kullan.
4. **Çocuk güvenliği ve KVKK**
   - Öğrenciler 10–14 yaşındadır. Mevcut sosyal güvenlik (`social-safety*`), veli onayı ve iletişim kuralları (`contact-policy*`) korunacak; gevşetme.
   - Öğrenciden gereksiz kişisel veri isteme.
5. **Güvenlik**
   - Service role anahtarı, veritabanı şifresi ya da erişim belirteci asla koda ve repoya yazılmaz.
   - Yeni tablo eklersen RLS açık olacak ve `anon`/`authenticated` erişimi kapalı kalacak; erişim yalnızca `diji-api` üzerinden olacak.
   - CSP'yi (`index.html` başı ve `deployment/security-headers.conf`) gevşetme.
6. **Veritabanı değişiklikleri**
   - Var olan migration dosyalarını değiştirme. Her değişiklik `supabase/migrations/2026MMDDHHMMSS_aciklama.sql` adıyla yeni bir dosya olsun.
   - Dosyalar tekrar çalıştırılabilir olsun (`if not exists`, `on conflict do nothing`).
   - Öğrenci verisini silen ya da bozan bir değişiklik yapma.
7. **Yapı**
   - Çalışan altyapıyı yeniden yazma. Ekonomi/XP, lig, rozet, arkadaşlık, öğretmen paneli, hesap silme ve dondurma, e-posta kuyruğu korunur; bunlara yalnızca Türkçe içerik bağlanır.
   - İngilizceye özgü bir özellik Türkçede anlamsızsa kaldırmak yerine **Türkçe karşılığına dönüştür** (aşağıdaki tabloya bak). Tamamen anlamsızsa, silmek yerine `feature_flags` ile kapat.
8. **Erişilebilirlik ve performans**
   - Mobil öncelikli tasarla, 360 px genişlikte yatay kaydırma olmasın.
   - `prefers-reduced-motion` desteklensin, renk kontrastı WCAG AA olsun.
   - Açılış ekranında yapay bekleme olmasın.

---

## 3. Aşamalar

### Aşama 0 — Keşif ve envanter (önce bu, kod değiştirme)
- Repoyu tara. `docs/turkce-uyarlama-envanteri.md` dosyasını yaz ve içine şunları koy:
  1. **İngilizceye özgü her özelliğin listesi:** dosya, ne yaptığı, Türkçedeki karşılığı ve karar (dönüştür / kapat).
  2. **İçerik veri kaynaklarının listesi.** Bunlar ve diji-api içindeki kopyaları dahil:
     - `thematic-curriculum.json`, `story-v2-curriculum.json`
     - `placement-bank.js`, `start-placement-bank.js`
     - `konu-oyunlari-a1.js` / `-a2.js`
     - `word-wheel-vocabulary.js`, `learning-dialogues.js`, `original-reading-library.js`
     - `story-curriculum.js`, `graduation-catalog.json`, `thematic-levels.json`
  3. **Ön yüz ile sunucu arasındaki içerik kopyaları:** Hangi dosyanın hem kökte hem `supabase/functions/diji-api/` içinde bulunduğu ve hangisinin asıl kaynak olduğu.
  4. **İngilizce metin taraması:** `grep` ile `İngilizce`, `English`, `CEFR`, `A1`, `en-US`, `en-GB`, `speechSynthesis`, `SpeechRecognition`, `telaffuz`, `pronunciation` sayımları.
- PR olarak gönder. Sahibin onayını beklemeden Aşama 1'e geçebilirsin. Envanterdeki kararlar sonraki aşamaların planıdır.

### Aşama 1 — İçerik modeli ve 5–8. sınıf içerik bankası
- **Tek bir içerik şeması tanımla.** `content/turkce/sema.md` dosyasına yaz ve JSON Schema'sını `content/turkce/sema.json` olarak ekle. Hiyerarşi: sınıf → tema → konu/öğrenme çıktısı → etkinlikler. Etkinlik türleri:
  - kelime (eş, zıt ve sesteş anlam, deyim, atasözü)
  - okuma metni ve okuduğunu anlama soruları
  - dil bilgisi (anlatım, örnekler, test)
  - yazım-noktalama
  - dinleme (metin + TTS)
  - yazma görevi (öğretmen değerlendirmeli)
  - LGS tarzı yeni nesil soru (8. sınıf)
- **Klasörler:** `content/turkce/5-sinif` … `8-sinif`. Her temanın kendi dosyası ve her sınıfın bir `mufredat.json` dosyası olsun.
- **Asgari içerik hacmi, her tema için:**
  - 30 kelime (tanım + örnek cümle)
  - 2 özgün okuma metni (5. sınıfta 250–400 kelime, 8. sınıfta 450–700 kelime), her biri 8–10 soru
  - Temadaki her dil bilgisi konusu için anlatım ve 10 test sorusu
  - 1 yazma görevi
  - 8. sınıf için ayrıca 20 LGS tarzı soru
- **Sorular:** Her soruda tek doğru cevap ve kısa, öğretici bir `aciklama` olsun. Çeldiriciler makul olsun. Seçenekler tekrar etmesin ve doğru cevap hep aynı şıkta olmasın.
- **Doğrulama aracı:** `tools/icerik-dogrula.mjs` yaz. Şunları kontrol etsin:
  - şema uyumu
  - `dogru` değerinin seçeneklerde bulunması
  - tekrar eden soruların olmaması
  - kazanım kodu biçimi
  - Türkçe karakter bozulması (`Ä±`, `ÅŸ` gibi)

  Bunu bir GitHub Actions iş akışına bağla.
- **Sıra:** Önce 5. sınıfın 6 temasını tamamla (tema-1 zaten var, onu genişlet). Sonra 6., 7. ve 8. sınıf. Her sınıf ayrı bir PR olabilir.

### Aşama 2 — Uygulama modüllerini Türkçe içeriğe bağlamak

Önerilen dönüşümler aşağıda. Envanterde daha iyi bir karşılık bulursan gerekçesiyle değiştir.

| Mevcut (İngilizce) | Türkçe karşılığı |
| --- | --- |
| CEFR seviyeleri A1/A2/B1/B2 (`thematic-curriculum.json`, parkur, rota, mezuniyet) | 5., 6., 7., 8. sınıf ve onların temaları. Seviye rozetleri ve mezuniyet: "5. Sınıf Türkçe Ustası" vb. |
| Seviye belirleme testi (`placement-bank`, `start-placement`) | Sınıfa göre başlangıç tanılama testi: okuma, kelime, dil bilgisi, yazım |
| Ders Çalış / tematik öğrenme (`thematic-learning`, `study-ui`, `learning-core`) | Tema → konu anlatımı → örnek → alıştırma → mini test akışı |
| Parkur / rota soruları (`route-questions`, `school-journey`, `parkur-*`) | Seçili sınıfın tema sırasına göre ilerleyen sorular |
| Hikâyeler (`story-v2`, `story-path`, `original-reading-library`) | Özgün Türkçe okuma metinleri ve okuduğunu anlama |
| Konu oyunları A1/A2 (`konu-oyunlari*`, `topic-games-core.mjs`) | Dil bilgisi konu oyunları (isim, sıfat, fiil, ek-kök, cümle ögeleri, fiilimsi…) |
| Kelime çarkı, Kelime Rallisi, Kelime Atölyesi, Harf Adası/Bahçesi, Meteor, balon oyunu | Türkçe kelime oyunları: anlam bulma, eş/zıt anlam, deyim-atasözü eşleştirme, yazım yanlışını bulma, hece, kelime türetme |
| İngilizce telaffuz / konuşma (`teacher-oral`, `SpeechRecognition` en-US) | Sesli okuma ve akıcılık: `tr-TR` konuşma tanıma ile okuma hızı (dakikada kelime) ve doğruluk. Öğretmen sözlü değerlendirmesi korunur. |
| TTS `en-US` / `en-GB` | `tr-TR` sesi; yoksa sessiz ve metin göster |
| İngilizce diyaloglar (`learning-dialogues`) | Günlük iletişim, hitabet, görgü kuralları senaryoları (TYMM "İletişim ve Sosyal İlişkiler" temasıyla bağlantılı) |
| MeduPro (`medupro*`) | Öğretmen çalışma alanı: ödev verme, tema seçme, sınıf raporu |
| Papi sohbet (`papi-chat`, kapalı) | Kapalı kalsın; açılacaksa yalnızca Türkçe ders yardımcısı olarak, ayrı aşamada |

- Ön yüzdeki ve sunucudaki içerik kopyalarını **tek kaynaktan** üret. `tools/` içine, `content/turkce` klasöründen hem ön yüz paketlerini hem `diji-api` kopyalarını oluşturan bir derleme betiği yaz. İkisinin elle ayrı ayrı düzenlenmesine son ver.
- Öğrencinin seçtiği sınıf (5–8) bütün modüllerde içerik filtresi olsun. Bir öğrenci kendi sınıfının üstündeki ya da altındaki içeriği yalnızca "Tekrar" ya da "İleri" etiketiyle görsün.
- XP, ödül ve adil ilerleme kuralları (`score-rules.js`, `fair-progress-policy.js`, `progress-rules.js`, `progression-catalog.js`) yeni etkinlik türleriyle çalışsın. Sunucu tarafındaki doğrulama (`verified-games.mjs`, `fair-study.mjs`) yeni oyunları tanısın.

### Aşama 3 — Bütün arayüz metinlerinin Türkçe derse uyarlanması
- "İngilizce", "English", "kelimeyi İngilizce söyle", CEFR adları ve İngilizce örnekler arayüzden tamamen çıksın. `index.html` içindeki satır içi metinler de buna dahil.
- Uygulama adı her yerde **Diji Medu Türkçe**, kısa adı **DM Türkçe** olsun. Bu kural şunları kapsar:
  - `manifest.json`, `<title>`, meta açıklamaları
  - `hakkinda.html`, `gizlilik.html`, `kullanim-kosullari.html`, `cerez.html`, `veli-kontrolu.html`, `telif.html`
- E-posta şablonları (`supabase/migrations/...fonksiyonlar.sql` içindeki HTML ve `papi-progress-worker`) Türkçe ders bağlamında olsun. Bunları yeni bir migration ile güncelle.
- Papi'nin rehber metinleri (`papi-guide-content.js`, `papi-tanitim.js`, `papi-onboarding.js`, `papi-sayfa-turlari.js`) Türkçe dersine göre yeniden yazılsın.

### Aşama 4 — Açılış animasyonu: Türk bayrağı sallayan Papi
- Açılış ekranı (`#dmBootSplash`, `#oturumYuklemeOverlay`, `papi-loading.css`, `index.html` satır ~192 ve ~208) şu animasyonu göstersin: **Papi bir kanadıyla Türk bayrağını sallıyor.**
- **Uygulama:**
  - Hafif, vektör tabanlı olsun: satır içi SVG + CSS animasyonu. Video ya da GIF kullanma. Toplam boyut 60 KB'tan az olsun.
  - Papi'nin görünümü korunsun: turkuaz-mavi tüyler, sarı göğüs, mor kanat uçları, turuncu gaga, büyük kahverengi gözler. Kırmızı (#E30A17) bir tişört giysin ve tişörtün üstünde beyaz ay-yıldız olsun.
  - Bayrak, **Türk Bayrağı Kanunu ve Tüzüğü'ndeki ölçülere uygun** çizilsin. Kırmızı #E30A17, ay ve yıldız beyaz. Hilal ve yıldızın oranları ve konumları tüzükteki G (genişlik) oranlarına göre olsun. Yıldız ayın açık tarafına bakar.
  - Bayrak dalgalansın: SVG `path` morph ya da `feTurbulence` yerine basit bir dalga dönüşümü kullan.
  - Bayrak yere değmesin, ters ya da yırtık gösterilmesin. Saygılı ve neşeli bir sunum olsun.
  - Mevcut yükleme ilerleme göstergesi (`--dm-papi-progress`) çalışmaya devam etsin. Örneğin bayrak direğinin dolması ya da bayrağın yükselmesi ilerlemeyi gösterebilir.
  - Yapay minimum süre ekleme: uygulama hazır olunca animasyon hemen kapansın.
  - `prefers-reduced-motion` açıkken animasyon olmasın, durağan görsel gösterilsin.
  - Gece temasında da (`day-night-theme`) okunaklı olsun.
- Marka satırı `Diji<span>Medu</span>` yerine **"Diji Medu Türkçe"** yazsın. "Türkçe" kelimesi kırmızı olsun.
- Uygulamanın her yerinde kullanılan PNG/WebP Papi görselleri (`papi-gorsel-brief.md` içindeki liste) için:
  - Yeni görsel üretemiyorsan dosyaları değiştirme.
  - Brifi güncelle ve hangi dosyaların yeniden çizilmesi gerektiğini PR'da yaz.
  - SVG ile yapılabilenleri (uygulama simgesi dahil) yap.

### Aşama 5 — Tema: Türkiye'yi anımsatan ufak dokunuşlar
- `day-night-theme.css` içindeki `--dm-*` renk değişkenlerini güncelle:
  - Vurgu rengi kırmızı (#E30A17) ile beyaz olsun. Gündüz temasında ana düğmeler kırmızı, üzerlerindeki yazı beyaz.
  - Mevcut turkuaz, ikincil renk olarak (Papi'nin rengi) kalsın.
  - Gece teması için kontrastı korunmuş, daha açık bir kırmızı tonu seç.
- Ay-yıldız motifini **az ve yerinde** kullan: açılış, başlık, rozet köşesi, başarı kutlaması. Her kartı bayrakla doldurma.
- Konfeti ve kutlama animasyonları (`odul-animasyon.*`) kırmızı-beyaz tonlarda olsun.
- Sabit hex renk kullanan CSS dosyalarını değişkenlere geçir. Bunu yalnızca ana ekranlarda yap; bütün CSS'i baştan yazma.
- Her değişiklik sonrası 360 px ve 768 px genişlikte, gündüz ve gece temasında ekran görüntüsü al (Playwright kurulu). Görüntüleri PR'a ekle.

### Aşama 6 — Üyelik sistemi
Mevcut sistem korunur, yalnızca Türkçe ve ortaokul için ayarlanır.

- **İlk yönetici hesabı:**
  - `teachers` tablosunda henüz kimse yok. `.github/workflows/yonetici-olustur.yml` adında elle çalışan bir iş akışı yaz. Girdiler: kullanıcı adı, ad-soyad, e-posta. Varsayılan e-posta `official.ogretmencocuk@gmail.com`.
  - Akış `SUPABASE_ACCESS_TOKEN` secret'ı ile Management API'yi kullansın. Var olan `kurulum.yml`'deki gibi şu adrese istek atsın: `https://api.supabase.com/v1/projects/isgnsmkboehygxxysria/database/query`. Bu istekle `is_admin=true` bir öğretmen oluştursun.
  - Şifre iş akışına girdi olarak **verilmesin**. Bunun yerine sistemin mevcut şifre sıfırlama e-postası tetiklensin ya da tek kullanımlık bir şifre belirleme bağlantısı üretilip o e-postaya gönderilsin.
  - Şifre hash biçimi `password-security.mjs` ile uyumlu olsun.
- **Kayıt akışları:**
  - Öğrenci kaydında şunlar istensin: ad, sınıf (5–8), şube, isteğe bağlı öğretmen kodu, veli e-postası ve veli onayı (13 yaş altı için KVKK gereği).
  - Mevcut bütün akışlar uçtan uca çalışsın: e-posta doğrulama (`hesap-dogrula.html`, `email-verification.js`), şifre yenileme (`sifre-yenile.html`), hesap dondurma, açma ve silme.
- **Öğretmen kaydı ve paneli:** Öğretmen hesabı yönetici onayıyla açılsın. Öğretmen kendi sınıf kodunu üretsin, öğrencilerini sınıf ve şube bazında görsün, tema veya konu ödevi versin, rapor alsın.
- **Google ile giriş:**
  - Kod hazır. Supabase ve Google tarafındaki ayarlar sahibine ait (bkz. Bölüm 4).
  - Kodda `storageKey` değeri hâlâ `diji-ingilizce-google-auth` ise `diji-turkce-google-auth` yap. Eski anahtarı okuyan bir geçiş kodu gerekmez, çünkü henüz kullanıcı yok.
- **Apple ile giriş:** Mağaza paketi yapılana kadar düğmeyi `feature_flags` ile gizle.
- **Demo hesabı** (`demo-account.*`) ve misafir modu (`misafir.*`, `guest-platform.*`): 5. sınıf Türkçe içeriğiyle çalışsın.
- **Testler:** Bu akışlar için `tests/` içindeki testleri güncelle: `onboarding-registration`, `google-signup`, `account-*`, `email-*`.

### Aşama 7 — Otomatik yayın ve doğrulama
- `main` dalında `supabase/functions/**` değiştiğinde ilgili fonksiyonları yayınlayan bir iş akışı yaz. Örnek olarak `supabase-fonksiyonlari-yayinla.yml` ve `kurulum.yml` dosyalarına bak; `SUPABASE_ACCESS_TOKEN` repoda secret olarak tanımlı.
- `supabase/migrations/` içine yeni dosya eklendiğinde yalnızca **henüz uygulanmamış** migration'ları Management API ile uygulayan bir iş akışı yaz.
  - Uygulananları `public.dm_applied_migrations (dosya text primary key, uygulandi timestamptz)` tablosunda tut. Tablo `anon`/`authenticated` erişimine kapalı olsun.
  - İlk 7 kurulum dosyası uygulanmış sayılsın.
- Diji Medu'dan kalan ve bu projede anlamsız olan iş akışlarını (`.github/workflows/` içinde 60 dosya var) gözden geçir. İngilizce içeriği test edenleri Türkçe içeriğe uyarla ya da kaldır.
- Her PR'da şunları çalıştır: `node --test tests/`, `tools/icerik-dogrula.mjs` ve açılış ekranının Playwright duman testi.

---

## 4. Senin yapamayacağın, sahibinin yapacağı işler
PR açıklamasında, ihtiyaç doğduğunda bunları açık adımlarla iste:
- **Supabase → Authentication → URL Configuration** (https://supabase.com/dashboard/project/isgnsmkboehygxxysria/auth/url-configuration):
  - Site URL: `https://ogretmencocuk.com`
  - Redirect URLs: `https://ogretmencocuk.com/**`
- **Supabase → Authentication → Providers → Google:** Google Cloud'da OAuth istemcisi açılır ve kimlik bilgileri girilir.
  - Yetkili kaynak: `https://ogretmencocuk.com`
  - Yönlendirme: `https://isgnsmkboehygxxysria.supabase.co/auth/v1/callback`
- Yeni Papi görsellerinin çizdirilmesi.
- PR'ların onaylanıp `main`'e birleştirilmesi.
- Okul (MEB) ağında erişim testi.

## 5. Her PR'da olması gerekenler
- Ne değişti; kısa liste.
- Hangi öğrenme çıktıları kapsandı: sınıf, tema ve kod tablosu.
- Doğrulanamayan kazanımlar.
- Çalıştırılan testlerin sonuçları.
- Ekran görüntüleri: mobil ve masaüstü, gündüz ve gece.
- Sahibinin yapması gereken bir şey varsa açık adımlar.
