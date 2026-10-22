# Aşama 1 — 6. sınıf içerik teslimi

6. sınıfın altı temasına özgün kelime, okuma, dil yapıları, dinleme ve öğretmen değerlendirmeli yazma etkinlikleri eklendi. Başlangıç, seçilen sınıfın ilk temasıdır; tek parkur vardır ve kayıt sırasında veya sonrasında seviye testi yoktur. Bunlar içerik sözleşmesindeki kararlardır; eski canlı akışların kapatılması Aşama 2’de yapılacaktır.

Bu dal, şema ve doğrulama aracını sağlayan `codex/turkce-asama-1-besinci-sinif` dalının `1718186fb5858c60a51ba5bca825ab8a3315caf4` commit’i üzerine kuruludur. PR tabanı bu daldır; önce 5. sınıf PR’ı birleştirilmeli, ardından bu PR `main` tabanına alınmalıdır. Birleştirme ve yayın yapılmadı. 7. ve 8. sınıf sonraki teslimlerdir.

## Hacim

| Tema | Kelime | İki okumanın kelime sayısı | Konu | Soru | Dinleme | Yazma |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| 1. Dilimizin Zenginliği | 30 | 304, 325 | 5 | 73 | 1 | 1 |
| 2. Bağımsızlık Yolu | 30 | 323, 318 | 3 | 50 | 1 | 1 |
| 3. Farklı Dünyalar | 30 | 334, 321 | 3 | 50 | 1 | 1 |
| 4. İletişim ve Sosyal İlişkiler | 30 | 324, 319 | 3 | 50 | 1 | 1 |
| 5. Bilim ve Teknoloji | 30 | 315, 322 | 4 | 60 | 1 | 1 |
| 6. Lider Ruhlar | 30 | 322, 342 | 2 | 40 | 1 | 1 |

Toplam **180 kelime, 12 özgün okuma, 20 konu anlatımı, 203 konu sorusu, 96 okuma sorusu, 24 dinleme sorusu, 6 dinleme metni ve 6 yazma görevi**: 323 seçim sorusu. Her konunun en az 10 sorusu var; ilk temanın virgül konusu yedi farklı işlevi kapsamak için 13 soru içeriyor. Doğru cevap konumları: 1. seçenek 104, 2. seçenek 106, 3. seçenek 113. Dağılım ID’ye göre sabittir; doğru cevap aynı konumda tutulmaz.

Okumalar 304–342 kelime arasındadır. 300–500 okuma ve 120–200 yazma aralıkları ürün tercihidir; resmî MEB sınırı olarak sunulmaz. Yazma görevleri dört ölçütte 0–4 puanlık rubrik taşır; öğrenci beyanıyla otomatik değerlendirilmez. Dinleme için `tr-TR` TTS, ses yoksa metin gösterme sözleşmesi korunur.

## Kaynak ve kapsam

MEB’in 6. sınıf program dizini ve 104, 118, 124, 270, 278, 282 numaralı tema sayfaları 22 Ekim 2026’da kontrol edildi. Tema adları, sırası ve öğrenme çıktısı kodları 2026–2027 taslak çerçeve yıllık planıyla karşılaştırıldı. Çalışma sayfası `6. SINIF ÇERÇEVE YILLIK PLA (3)`; tema başlangıçları 4, 12, 22, 36, 47, 56. satırlardır. Her temadaki kod kümesi program sayfasıyla bire bir eşleşti; iki kaynak arasında eksik veya fazla kod bulunmadı. Saatler sırasıyla 35, 35, 34, 34, 34, 34’tür.

Adresler, indirilen HTML dosyalarının SHA-256 değerleri ve yıllık plan kaydı `content/turkce/kaynaklar.json` içindedir. 5. sınıfın kaynak kayıtları korunur. Kod biçimini doğrulamak, kaynağı tekrar internetten onaylamak anlamına gelmez; CI kayıtlı kaynak kümesini denetler.

6. sınıfın tema açıklamalarında bazı dil yapıları ayrı DYS kodu taşımadan anlatılır. **Yeni resmî kod uydurulmadı.** `6-2-kok` gibi konu kimlikleri uygulamaya aittir. Genel çıktılarla yapılan pedagojik eşleme:

| Tema | Dil yapıları ve yerel dersler | Eşlenen doğrulanmış çıktı |
| --- | --- | --- |
| 1 | de/da, ki, mı/mi; virgül; bağlama uygun söz varlığı | `T.Y.6.21`, `T.Y.6.18` |
| 2 | kök, yapım/çekim eki, karşılaştırma | `T.Y.6.3`, `T.K.6.12` |
| 3 | iki nokta; zıtlık ve sebep | `T.Y.6.21`, `T.Y.6.1` |
| 4 | amaç, koşul, önceki yazım kurallarını gözden geçirme | `T.Y.6.3`, `T.Y.6.21` |
| 5 | kısa çizgi, kısaltma ekleri, kişi uyumu, dize aktarımında eğik çizgi | `T.Y.6.21`, `T.Y.6.3` |
| 6 | olumsuzluk ve benzerlik | `T.Y.6.16`, `T.Y.6.13` |

Bu eşlemeler, her dil yapısına ayrı bir resmî öğrenme çıktısı tanımlandığı iddiasını taşımaz. Konu adları MEB’in çıktı başlığı olarak gösterilmez. Soru etkinlikleri yapıları tanıma ve yorumlama alıştırmasıdır; konuşma/yazma becerisinin tam kazanıldığı yalnız bu seçim sorularıyla ileri sürülmez. Yazma görevlerinde kullanım ve öğretmen incelemesi ayrıca yer alır.

Tüm tema çıktıları manifestte bulunur; her birinin bu ilk bankada ölçüldüğü iddia edilmez. Etkinliklerde kullanılan kodlar ve nicel kontrol sonuçları `turkce-asama-1-altinci-sinif-kontrol.json` dosyasındadır. İlk temanın söz varlığı çıktısı `T.O.6.21`, sonraki temalarda pekiştirilir. Doğrulanamayan kod yoktur. Metin ve sorular özgündür; kitaplardan alıntı veya tarihsel kişilere atfedilmiş uydurma söz kullanılmadı. Bağımsızlık temasındaki sergi ve belgeler kurgusaldır.

## Doğrulama

- `npm ci --prefix tools --ignore-scripts`: geçti.
- `node tools/icerik-dogrula.mjs`: **0 hata, 0 doğrulanmamış kaynak**; 5. ve 6. sınıf birlikte 12 tema, 360 kelime, 24 okuma, 50 konu, 743 soru, 12 dinleme ve 12 yazma.
- `node --test tests/turkce-content.test.mjs`: **19/19 geçti**. Yeni denetimler: 6. sınıf tema sırası ve tek parkur kararı, 300/500 sınırları ile 299/501 reddi, resmî çıktı silinmesi, önceki tema sorularının tekrar etiketi.
- Kaynak kodları yıllık plandan bağımsız çıkarılan listeyle karşılaştırıldı: altı temada bire bir eşleşme.
- Başlangıç deposundaki özgün uygulama/sunucu dosyaları Git blob SHA ile karşılaştırıldı: beklenmeyen değişiklik ve eksik dosya yok.

Doğrulama aracı artık 6. sınıfta da altı tema arar; tema çıktı kümesinin kayıtlı resmî temayla eksiksiz eşleşmesini ve kaynak adreslerini kontrol eder. Cevap/şık tekrarı, karakterler, metin uzunlukları ve konu kapsamı denetimleri korunur.

Bu değişiklikte uygulama ekranı veya sunucu davranışı değişmediğinden genel eski test takımı yeniden çalıştırılmadı. 5. sınıf tesliminde belgelenen 33 eski test başarısızlığı giderilmiş sayılmaz. Eski medya hakları denetiminin önceki PR’da görülen kapsam sorunu da bu içerik PR’ında değiştirilmedi. İçerik kontrollerinin geçmesi bütün depo kontrollerinin yeşil olduğu anlamına gelmez.

## Entegrasyon sınırı

JSON dosyaları henüz öğrenci ekranı, ön yüz paketi veya edge function tarafından yüklenmiyor. Bu nedenle uygulama `?v` değerleri ve SW önbelleği değişmedi; bunlar Aşama 2’nin içerik paketleme PR’ında birlikte güncellenecek. Uygulama ekranı değişmediği için önceki açılış ekranı görüntüleri bu sınıfın yeni ekranları gibi sunulmadı. Veritabanı, öğrenci hesapları, OAuth ve e-posta yapılandırması değişmedi.
