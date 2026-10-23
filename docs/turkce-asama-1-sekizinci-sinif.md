# Aşama 1 — 8. sınıf 2019 programı içerik bankası

Sekiz tema, 240 kelime kaydı, 16 yeni özgün okuma, 14 konu anlatımı, 140 konu sorusu, 128 okuma sorusu, 32 dinleme sorusu ve **160 LGS tarzı soru**: toplam **460 soru**, 8 dinleme ve 8 öğretmen değerlendirmeli yazma görevi eklendi.

| Tema | Kelime | İki okumanın kelime sayısı | Konu | Toplam soru | LGS |
| --- | ---: | --- | ---: | ---: | ---: |
| 1. Okuma Kültürü | 30 | 479, 491 | 3 | 70 | 20 |
| 2. Millî Mücadele ve Atatürk | 30 | 451, 473 | 2 | 60 | 20 |
| 3. Erdemler | 30 | 478, 472 | 2 | 60 | 20 |
| 4. Millî Kültürümüz | 30 | 474, 467 | 2 | 60 | 20 |
| 5. Bilim ve Teknoloji | 30 | 468, 480 | 2 | 60 | 20 |
| 6. Duygular | 30 | 467, 472 | 1 | 50 | 20 |
| 7. Doğa ve Evren | 30 | 469, 473 | 1 | 50 | 20 |
| 8. Sağlık ve Spor | 30 | 465, 482 | 1 | 50 | 20 |

Her okuma sekiz soru taşır. Her konu en az üç örnek ve on test sorusu içerir. Okumalar 451–491 kelime; hedef aralık 450–700’dür. Yazmalar 180–280 kelime ve dört ölçütte 0–4 öğretmen rubriği kullanır. Yazma aralığı ürün tercihidir; resmî sınır iddiası değildir. Dinleme için tr-TR TTS ve ses yoksa metin gösterme sözleşmesi korunur.

## Kaynak ve 2019 ayrımı

Kaynak, MEB’in 2019 Türkçe Dersi Öğretim Programı PDF’sindeki 8. sınıf bölümüdür. Dinleme 14, konuşma 7, okuma 35, yazma 20 olmak üzere **76 kazanım** sınıf düzeyinde doğrulandı. İncelenen yıllık plandaki kodlar da bu kümenin içindedir. PDF adresi ve SHA-256 kaydı ortak kaynak dosyasındadır. Bu teslim TYMM 8. sınıf kodlarını kullanmaz.

Tema sırası, MEB’in 2026–2027 taslak yıllık planlar arşivindeki `Türkçe 8. SINIF MEB YILLIK PLAN` sayfasından seçildi. Başlangıç satırları 4, 9, 16, 21, 28, 35, 42, 48’dir. Başka onaylı kitapların sırası farklı olabilir. Saatler 5 ders/hafta üzerinden nominal 20/25 saatlik çerçevelerdir; tatiller ve okul temelli planlama için kesin uygulanacak saat iddiası değildir.

2019 programı kazanımları sınıf düzeyinde verir. Bu nedenle her tema manifesti ve kaynak kaydı 76 kazanımlık **ortak izinli kümeyi** taşır. Bu, her kazanımın her temada ölçüldüğü veya resmî sabit tema dağılımı bulunduğu iddiası değildir. Etkinliklerin her birindeki cikti alanı gerçek kullanılan kodu gösterir. Ayrım, kaynak kaydının kapsam ve müfredatın kaynakNotlari alanlarında açıklanır.

Fiilimsiler T.8.3.9; dil bilgisel anlatım bozuklukları T.8.3.8; cümlenin ögeleri T.8.4.18; cümle türleri T.8.4.19; fiil çatısı T.8.4.20 ile eşlenir. Çatı ve cümle türlerinde soyut tanım ezberi yerine örneklerin anlam ve kuruluş farkları incelenir. Son temalar pekiştirme dersleri içerir. Yazım-noktalama, yazdığını düzenleme çıktısıyla T.8.4.16 kapsamında tekrarlanır.

Metinler ve sorular proje için özgün yazıldı; ders kitabı veya yayınevi sorusu alınmadı. Kelime tanım ve örnekleri özgün proje bankasından tema uyumlu seçilir ve önceki sınıflardan spiral tekrar içerebilir. 240 kayıt, bütün sınıflarda 240 farklı yeni kelime iddiası değildir. Doğa ve evren için 30 kavramlık ek söz varlığı hazırlandı. Öğrenciden gereksiz kişisel veya sağlık bilgisi istenmez. Kurgusal tarih çalışmaları gerçek kişiye atfedilen uydurma söz içermez.

## LGS tarzı alıştırmalar

Her temada dört seçenekli 20 soru bulunur. Yirmi görev ailesi farklı tema bağlamlarında tekrar edilir: çok koşullu tablo, işlem sırası, örneklem kapsamı, iki görüş karşılaştırması, paragraf sırası, bağlantı, ana düşünce, yönerge, başlık, bütünlük, nesnellik, gerekli koşul, iki ölçütlü tablo, yalnız ifadesi, kaynak bağımsızlığı, özet, kesinlik, grafik sırası, bağlamda anlam ve iki duyuru karşılaştırması.

Bunlar MEB’in gerçek sınav soruları değildir; psikometrik güçlüğü kalibre edilmiş sınav iddiası taşımaz. Doğru cevap konumları **40/40/40/40** olarak dağılır. İsim veya şık sırası değiştirilmiş aynı soru, doğrulayıcıda yeni soru sayılmaz. Öğretmen incelemesi otomatik kontrollerden ayrıdır.

Tablo/sıralama sorularından sekiz temada dörderi, toplam 32 soru, üretilmiş JSON’un basılı metninden bağımsız yeniden çözüldü. Üç koşullu tabloda tek uygun satır bulundu. Sözel sıralamalarda 24 olası düzen ayrı ayrı taranıp tek çözüm olduğu görüldü. İki ölçütlü tablolar ve grafik etiketleri kaynaktaki rakamlardan yeniden hesaplandı. Bu testler CI’da çalışır; yalnız üretim betiğinin kendi cevabını tekrar kabul etmez.

## Kontroller

- npm ci --prefix tools --ignore-scripts: geçti.
- İçerik doğrulama: 0 hata, 0 doğrulanmamış kaynak.
- 28 içerik testi ve 32 mantık testi: **60/60 geçti**.
- 8. sınıf için 449/701 reddi ve 450/700 kabulü, 2019 programı, sekiz tema, 76 kod, LGS alt sınırı ve dört seçenek kontrolleri var.
- Dört sınıf birlikte: **26 tema, 780 kelime kaydı, 52 okuma, 79 konu, 1473 soru, 26 dinleme ve 26 yazma**.
- Başlangıç deposundaki eski uygulama dosyaları Git blob SHA ile karşılaştırıldı: beklenmeyen değişiklik veya eksik dosya yok.

Genel eski uygulama test takımı bu içerik değişikliği için yeniden çalıştırılmadı. Önceki PR’larda görülen uygulama ve medya denetimi başarısızlıkları giderilmiş sayılmaz. İçerik kontrollerinin yeşil olması bütün depo CI’ının yeşil olduğu anlamına gelmez.

## Entegrasyon ve dal bağımlılığı

Bu dal 7. sınıf PR’ı üzerine kuruludur. Önce 7. sınıf PR’ı, sonra bu PR birleştirilip main tabanı güncellenmelidir. Birleştirme ve yayın yapılmadı. Öğrenci ekranları, SW, hesaplar, sunucu ve veritabanı değişmedi. JSON bankası henüz canlıya bağlı olmadığından uygulama ?v değerleri veya SW sürümü değiştirilmedi. Ekran değişmediği için yeni ekran görüntüsü iddiası yoktur.

Sınıfın ilk temasından başlayan tek parkur ve kayıt sırasında/sonrasında seviye testi olmaması manifestte korunur. Eski canlı akışların kaldırılması ve bu içeriklerin ön yüz/sunucu paketlerine bağlanması Aşama 2 kapsamındadır.
