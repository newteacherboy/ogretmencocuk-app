# Aşama 1 — 5. sınıf içerik teslimi

Kaynak dal: `main`, commit `9bf9fcb3822eda936bef0ab9ec80c2bbc5ca7961`. Bu teslim içerik modeli, doğrulama aracı ve 5. sınıfın altı temasını kapsar. 6–8. sınıf bankaları ve uygulama bağlantıları sonraki PR’lardır. Henüz canlı yayın yapılmadı.

## İçerik hacmi

| Tema | Kelime | Okuma uzunlukları | Konu | Soru | Dinleme | Yazma |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| 1. Oyun Dünyası | 30 | 257, 261 kelime | 5 | 70 | 1 | 1 |
| 2. Atatürk'ü Tanımak | 30 | 258, 251 kelime | 6 | 80 | 1 | 1 |
| 3. Duygularımı Tanıyorum | 30 | 252, 259 kelime | 6 | 80 | 1 | 1 |
| 4. Geleneklerimiz | 30 | 271, 263 kelime | 6 | 80 | 1 | 1 |
| 5. İletişim ve Sosyal İlişkiler | 30 | 259, 268 kelime | 5 | 70 | 1 | 1 |
| 6. Sağlıklı Yaşıyorum | 30 | 268, 269 kelime | 2 | 40 | 1 | 1 |

Toplam: **180 kelime, 12 özgün okuma metni, 30 konu anlatımı, 300 konu sorusu, 96 okuma sorusu, 24 dinleme sorusu, 6 dinleme metni ve 6 öğretmen değerlendirmeli yazma görevi**. Seçeneklerde doğru cevap konumu değişir. Cevap anahtarı yeni sözleşmede seçenek metnidir.

Söz varlığına eş/zıt/sesteş anlam, deyim ve atasözü örnekleri de bağlandı. Okuma ve dinleme metinleri bu çalışma için yazıldı. Ders kitabı metni, sorusu veya tarihsel kişiye atfedilen doğrulanmamış söz kullanılmadı. Yazma görevlerinde özel yaşantıyı veya gereksiz kişisel bilgiyi açıklama zorunluluğu yok.

## Kaynak ve çıktı eşlemesi

MEB’in altı resmi tema sayfası ile 2026–2027 taslak yıllık planı incelendi. Programdaki çıktı listesi ile etkinliklerde kullanılan kodlar ayrıdır: aşağıdaki tablo etkinliğe gerçekten bağlanan kodları gösterir; programın her çıktısının bu ilk bankada ölçüldüğü iddia edilmez.

| Tema | Etkinliğe bağlanan kodlar |
| --- | --- |
| 1 | `DYS.DO.5.1`, `DYS.DO.5.8`, `DYS.KY.5.8`, `T.D.5.5`, `T.O.5.15`, `T.O.5.20`, `T.O.5.5`, `T.O.5.6`, `T.Y.5.1`, `T.Y.5.13`, `T.Y.5.16`, `T.Y.5.3` |
| 2 | `DYS.DO.5.3`, `DYS.DO.5.4`, `DYS.KY.5.2`, `DYS.KY.5.3`, `T.D.5.5`, `T.K.5.19`, `T.O.5.20`, `T.O.5.5`, `T.O.5.6`, `T.Y.5.15`, `T.Y.5.16`, `T.Y.5.2`, `T.Y.5.3` |
| 3 | `DYS.DO.5.2`, `DYS.DO.5.7`, `DYS.KY.5.1`, `DYS.KY.5.7`, `T.D.5.5`, `T.D.5.6`, `T.K.5.19`, `T.O.5.13`, `T.O.5.16`, `T.O.5.18`, `T.O.5.20`, `T.O.5.5`, `T.O.5.6`, `T.Y.5.13`, `T.Y.5.15`, `T.Y.5.16`, `T.Y.5.3`, `T.Y.5.5` |
| 4 | `DYS.DO.5.5`, `DYS.DO.5.6`, `DYS.KY.5.4`, `DYS.KY.5.5`, `DYS.KY.5.6`, `T.D.5.5`, `T.D.5.6`, `T.O.5.10`, `T.O.5.20`, `T.O.5.21`, `T.O.5.5`, `T.O.5.8`, `T.O.5.9`, `T.Y.5.10`, `T.Y.5.16`, `T.Y.5.3`, `T.Y.5.7` |
| 5 | `DYS.KY.5.9`, `T.D.5.5`, `T.D.5.6`, `T.K.5.19`, `T.O.5.12`, `T.O.5.20`, `T.O.5.5`, `T.O.5.8`, `T.O.5.9`, `T.Y.5.13`, `T.Y.5.16`, `T.Y.5.2`, `T.Y.5.3` |
| 6 | `T.D.5.5`, `T.O.5.14`, `T.O.5.20`, `T.O.5.5`, `T.Y.5.1`, `T.Y.5.11`, `T.Y.5.15`, `T.Y.5.16`, `T.Y.5.3` |

Doğrulanamayan kod: **yok**. Önceki temanın çıktısını tekrar eden sorular `onKosul=true` taşır. DYS kodları tema sayfalarının dil yapıları açıklamalarından doğrulandı.

Kaynak notu: 6. tema sayfasının üst çıktı listesinde `T.O.5.5.14` yazım tutarsızlığı bulunuyor. Aynı sayfanın uygulamalar bölümünde ve resmi yıllık planda yer alan `T.O.5.14` kullanıldı. Geçersiz biçim bankaya taşınmadı.

Kaynak adresleri ve indirilen HTML SHA-256 değerleri `content/turkce/kaynaklar.json` içinde. Yıllık planın 5. sınıf sayfasında tema başlangıçları 4, 12, 26, 39, 50 ve 59. satırlarda kontrol edildi; kitaptaki metinler kopyalanmadı.

## Doğrulama sonuçları

- `npm ci --prefix tools --ignore-scripts`: geçti. Ajv 8.17.1 ve kilit dosyası kullanılır.
- `node tools/icerik-dogrula.mjs`: **0 hata, 0 doğrulanmamış kaynak**. Altı tema için hacim, şema, kodlar, cevaplar, kimlikler, tekrarlar, karakterler ve konu kapsamı denetlendi.
- `node --test tests/turkce-content.test.mjs`: **15/15 geçti**. Olumsuz örneklerde yanlış cevap, eski indeks, yinelenen şık/soru/kelime, yanlış sınıf/kod, doğrulanmayan kod, kısa metin, bozuk karakter ve güvensiz HTML reddedildi.
- `node --test tests/`: bu ortamdaki Node v24.19.0 klasörü modül gibi çözerek MODULE_NOT_FOUND verir. Bu yüzden test dosyaları açık listeyle çalıştırıldı.
- İlk genel koşu açık işlem nedeniyle tamamlanmadı; kesilip sonlandırıldı. Sonraki iki karşılaştırmalı koşuda `--test-force-exit --test-concurrency=2 --test-timeout=90000` kullanıldı. Toplam zaman sınırı 180 saniyeydi; her iki koşu da yaklaşık 39 saniyede tamamlandı.

| Koşu | Seçilen dosya | Bildirilen test | Geçti | Başarısız | Atlandı |
| --- | ---: | ---: | ---: | ---: | ---: |
| Değişiklik öncesi, 1.149 dosyası Git blob SHA ile doğrulanmış kopya | 142 | 1114 | 1079 | 33 | 2 |
| Aşama 1 | 143 | 1135 | 1100 | 33 | 2 |

Başarısız testlerin konumu ve adı karşılaştırıldı: **yeni başarısızlık 0; çözülen eski başarısızlık 0**. Genel takım yeşil değildir. Toplam test sayıları çıkarılıp yeni test sayısı olarak yorumlanmaz; keşif/raporlama farkları bulunduğundan karşılaştırma başarısız test kimlikleriyle yapıldı. Yeni içerik testlerinin 15’i ayrıca temiz koşuda tamamlandı.

Eski başarısız dosyalar: `tests/achievement-actions.test.cjs`, `tests/evening-ui.test.cjs`, `tests/google-signup-frontend.test.cjs`, `tests/legacy-micro-progress.test.cjs`, `tests/meteor-api.test.cjs`, `tests/meteor-dom.test.cjs`, `tests/oyna-carousel.test.cjs`, `tests/parkur-learning.test.cjs`, `tests/profile-account-switch.test.cjs`, `tests/social-school-improvements.test.cjs`, `tests/student-management-api.test.cjs`, `tests/universal-onboarding-ui.test.cjs`.

Uygulama ve sunucu kaynakları değişmedi. Eski izlenen dosyalardan yalnız 5. sınıf müfredatı ve örnek tema değişti; eklenenler içerik, araç, CI, test ve belgelerdir. Genel takımdaki hataları gizlemek için eski testler silinmedi veya gevşetilmedi.

## Açılış ekranı kontrolü ve görüntüler

Playwright + Chromium 153.0.8010.0 ile mevcut açılış parçası 360×740, 768×1024 ve 1440×900 boyutlarında, gündüz/gece ve reduced-motion ayarında yeniden kontrol edildi. Altı durumda görsel çözüldü, yatay taşma oluşmadı, azaltılmış harekette animasyon kapalı kaldı, hazır sinyalinde ilerleme %100 oldu ve splash kapandı.

Gerçek index.html de dış servisler engellenerek localhost üzerinde 360×740’ta açıldı: splash kapandı, JavaScript hatası ve yatay taşma yok. Bu, canlı üyelik/OAuth uçtan uca testi değildir. Görüntüler izole özgün açılışın %42 ilerleme anıdır; yeni içerik ekranı veya bayraklı Papi tasarımı olarak sunulmaz.

| Boyut | Gündüz | Gece |
| --- | --- | --- |
| 360 px | [Görüntü](turkce-asama-1/acilis-360-day.png) | [Görüntü](turkce-asama-1/acilis-360-night.png) |
| 768 px | [Görüntü](turkce-asama-1/acilis-768-day.png) | [Görüntü](turkce-asama-1/acilis-768-night.png) |
| 1440 px | [Görüntü](turkce-asama-1/acilis-1440-day.png) | [Görüntü](turkce-asama-1/acilis-1440-night.png) |

## Uygulamaya geçiş

Kayıt veya profil seviye testi bu içerik modelinde yer almaz. Tek parkur, seçilen sınıfın ilk temasından başlayacaktır. Eski test ve iki parkur girişlerinin kapatılması Aşama 2’de yapılır; şu an canlı uygulamada kaldırılmış değildir.

Şema ön yüz bağımlılığı eklemez. npm/Ajv yalnız geliştirme ve CI aracıdır. Yeni JSON kaynakları henüz uygulama veya SW tarafından yüklenmediğinden bu PR’da uygulama kaynaklarının ?v değerleri ve SW sürümü değiştirilmedi; paketleri bağlayan Aşama 2 PR’ında birlikte güncellenecek.

Sahibin yapacağı OAuth/Supabase yapılandırması bu PR için yoktur. Öğretmen içerik incelemesi ve PR birleştirmesi sonradan yapılabilir; yayın yapılmış sayılmaz.
