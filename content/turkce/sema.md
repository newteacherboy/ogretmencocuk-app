# Türkçe içerik sözleşmesi 1.0

Asıl içerik kaynağı bu klasördeki JSON dosyalarıdır. Sıra **sınıf → tema → konu/öğrenme çıktısı → etkinlikler** biçimindedir. Her sınıfın `mufredat.json` dosyası tema dosyalarını sıralar. Ön yüz ve sunucu paketleri Aşama 2'de bu kaynaktan üretilecektir. Bu PR içerikleri canlı uygulamaya bağlamaz.

## Belgeler ve program

- `sema.json`: JSON Schema 2020-12. `belgeTuru` ile `mufredat` ve `tema` ayrılır; bilinmeyen alanlar reddedilir.
- `kaynaklar.json`: resmi tema kaynakları, kontrol tarihi ve doğrulanmış kodlar; yıllık planın adresi ve kontrol edilen sayfa/satırlar. İndirilen kaynakların SHA-256 değerleri izlenebilirlik içindir. CI internete bağlanıp kaynak metinlerinin doğruluğunu yeniden onaylamaz.
- `5-sinif`–`7-sinif`: `program: "TYMM"`. 5., 6. ve 7. sınıfın altışar teması hazırdır.
- `8-sinif`: `program: "2019"`; her temada en az 20 LGS sorusu gerekir. Şema 2019 biçimindeki `T.8.3.1` gibi kodları da destekler. TYMM'ye geçiş ayrıca sürümlenecektir. 8. sınıf bankası sonraki teslimdir.

## Tema alanları

| Alan | İçerik ve alt sınır |
| --- | --- |
| `sinif`, `tema`, `temaAdi` | Müfredat kimliğiyle birebir eşleşir. |
| `ogrenmeCiktilari` | Resmi tema kodları; `T.O.5.20`, `DYS.DO.5.1` gibi. |
| `sozVarligi.kelimeler` | En az 30 ayrı kelime; `kelime`, özgün `anlam`, `ornek`, `tip: "kelime"`, `cikti`. |
| `esAnlamlilar`, `zitAnlamlilar` | İkili kelime listeleri; eş ve zıt anlam ilişkileri. |
| `esSesliler` | Aynı yazılışın farklı anlamlarını gösteren kayıtlar. |
| `deyimler`, `atasozleri` | `ifade`, `anlam`, `ornek` alanları; tema bağlamına göre kullanılır. |
| `okumaParcalari` | En az iki özgün metin; her birinde 8–10 seçim sorusu. |
| `konular` | Müfredattaki her konu için `kod`, `kategori`, `cikti`, `ekCiktilar`, `anlatimHTML`, en az üç `ornekler` ve en az on `testler`. |
| `dinleme` | En az bir özgün metin ve dört soru; `tts.dil: "tr-TR"`, `sesYoksa: "metin"`. Yabancı sese düşülmez. |
| `yazmaGorevleri` | En az bir görev; kelime aralığı, çıktı listesi ve ölçütlü rubrik. `ogretmenDegerlendirmeli` zorunlu olarak `true`. |
| `lgsSorulari` | 8. sınıfta en az 20 soru; diğer sınıflarda boş liste. |

Okuma uzunluğu boşlukla ayrılmış sözcüklere göre denetlenir: 5. sınıf 250–400, 6. sınıf 300–500, 7. sınıf 350–600, 8. sınıf 450–700 kelime. 6. ve 7. sınıf aralıkları proje içi ara basamak tercihidir; resmi bir MEB kelime sınırı olarak sunulmaz.

## Soru sözleşmesi

```json
{
  "id": "5-1-ornek-1",
  "tip": "secim",
  "soru": "Bir oyuncuya sıra geldiğini gösteren araç hangisidir?",
  "secenekler": ["Söz taşı", "Puan çizelgesi", "Zaman düdüğü"],
  "dogru": "Söz taşı",
  "aciklama": "Taş konuşma sırasını gösterir; puan veya süre ölçmez.",
  "cikti": "T.O.5.6"
}
```

`dogru`, seçeneklerde **tam bir kez bulunan metindir**; indeks değildir. Eski örnek temadaki 0 tabanlı indeksler bu sürümde metne dönüştürüldü. Tüketici paketi üretilirken indeks gerekiyorsa yalnızca o aşamada `secenekler.indexOf(dogru)` kullanılır. Bu cevap anahtarları öğrenci puanını güvenilir kabul etmek için kullanılmaz; sonuç doğrulaması Aşama 2'de sunucuda kalacaktır.

`yazimDuyarli: true`, yazım ve noktalama karşılaştırmasında kullanılır. Bu durumda büyük/küçük harf ve işaret farkı anlamlıdır. Diğer sorularda Türkçe yerel harf dönüşümüyle normalleştirilen mükerrer şıklar reddedilir. Soru tekrarı, normalleştirilmiş soru ve sıra bağımsız seçenek kümesiyle yakalanır; yalnızca ID veya şık sırası değiştirmek yeni soru sayılmaz.

`onKosul: true`, önceki temada doğrulanmış bir çıktının tekrar edildiğini belirtir. Bir kodun yanlış temaya yeni kazanım gibi eklenmesini gizlemez. Kaynağı doğrulanamayan, biçimce geçerli kod ancak `kaynak_dogrulanmadi: true` ile açık uyarı listesine girer; PR'da ayrıca listelenmelidir. Bu teslimde böyle kod yoktur.

## Yazma ve anlatım güvenliği

Yazma görevleri öğrenci beyanıyla tamamlanmış veya puanlanmış sayılmaz. Rubrik dört ölçütte 0–4 aralığı sunar; öğretmen değerlendirmesi gerektirir. Öğrenciye özel yaşantısını, adresini veya iletişim bilgisini açıklatma zorunluluğu yoktur.

`anlatimHTML` yalnızca özniteliksiz `p`, `ul`, `li`, `strong`, `em`, `h3` etiketlerini taşır. Betik, olay işleyicisi ve dış kaynak içeren etiketler kabul edilmez. Diğer metinler düz metindir; ileride ekrana bağlanırken `textContent` veya güvenli kaçış kullanılır.

## Doğrulama

```sh
npm ci --prefix tools --ignore-scripts
node tools/icerik-dogrula.mjs
node --test tests/turkce-content.test.mjs
```

Araç şema uyumu yanında doğru cevabı, soru/kimlik/kelime tekrarlarını, karakter bozulmalarını, kod biçimi ve sınıfını, kaynak kaydını, tema-müfredat eşleşmesini, resmî tema çıktı listesinin eksiksizliğini, kaynak adresi eşleşmesini, 5–7. sınıfta altı tema şartını, konu kapsamını, metin uzunluğunu, güvenli anlatım HTML'ini ve öğretmen değerlendirmesi şartını kontrol eder. Hata varsa çıkış kodu 1 olur. `--json` rapor, `--root <depo>` başka bir kontrol kökü sağlar. Araç öğrenci veritabanına bağlanmaz.

GitHub Actions `turkce-icerik.yml`, kilit dosyasıyla Node 22 üzerinde bu denetimleri çalıştırır. Dilsel doğruluk, tek anlamlılık, kaynak-çıktı eşlemesinin pedagojik niteliği ve öğretmen incelemesi ayrıca değerlendirilir; otomatik kontrol bunların yerine geçmez.

## Tek parkur kararı

İçerik sözleşmesinde CEFR veya ikinci parkur seçimi yoktur. Başlangıç, seçilen 5–8. sınıfın ilk temasına göre olacaktır. Kayıt veya profil seviye testi üretilmez. Ders içindeki konu testleri ve anlama soruları öğrenme etkinliğidir. Uygulamadaki eski başlangıç testi/çift parkur girişlerinin kapatılması Aşama 2 kapsamındadır.

## 6. sınıfın dil yapıları

6. sınıfın tema uygulama açıklamalarında dil yapıları bulunur; her biri için ayrı bir resmî DYS kodu verilmiş gibi gösterilmez. `6-2-kok` gibi kimlikler yereldir. Etkinlikler temadaki doğrulanmış genel öğrenme çıktılarıyla eşlenir. Bu pedagojik eşleme, ayrı bir resmî dil bilgisi kazanım kodu iddiası taşımaz; ayrıntılar 6. sınıf müfredatının `kaynakNotlari` alanında ve sınıf teslim raporundadır.

`kaynaklar.json` içindeki `yillikPlan` 5. sınıfın ilk kaynak incelemesini, `ekSinifPlanlari` eklenen sınıfların kontrol edilen çalışma sayfalarını saklar. Temalara ait kodlar, adresler ve kaynak dosyalarının SHA-256 değerleri `kaynaklar` listesindedir.
