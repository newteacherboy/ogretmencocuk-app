# Türkçe harita ve oyun alanı

Türkçe parkuru düz kart listesinden kıvrımlı bir keşif haritasına dönüştürüldü. Her tema açılıp kapanan bir bölge; sıradaki tema başlangıçta açık. Durakların kimlikleri, sırası, sunucudaki ilerleme, %75 eşiği ve ilk tamamlama ödülleri korunur. Tema mühürleri yalnız sunucudan gelen tamamlanmış duraklardan hesaplanır.

Sabit alt menü Parkur, Oyunlar, Çalışmalar ve Hesabım’a erişir. Eski oyun kısayolları Türkçe oyun alanını açar. Eski İngilizce oyun dosyalarının isteğe bağlı yükleyicisi Türkçe alan açıkken eski kaynağı yüklemez. Giriş, yardım, rapor ve tanıtım metinleri Türkçe ürüne uyarlandı. Yeni tasarım sıcak kâğıt, turkuaz, mercan ve çizim SVG simgeleri kullanır.

## Oyunlar

Dokuz farklı mekanik: açık eşleştirme, kapalı kart hafızası, Türkçe alfabeyle harf tahmini, harfleri sıralama, örnek cümleyi vagonlarla kurma, Türkçe sesle dikte, anlam balonları, süreli/süresiz sözcük yağmuru ve sözcük çarkı. Her oyun seçilen 5–8. sınıf ve temanın gözden geçirilmiş Türkçe sözcük/anlam/örnek kaynağını kullanır. Benzer anlamlı tekrarlar eşleştirme havuzundan ayıklanır. Dikte Türkçe ses bulunmazsa açık anlam ipucu sunar. Türkçe İ/ı ve diğer harfler korunur.

Bu sürümde oyunlar **serbest alıştırmadır**: enerji tüketmez, XP veya altın vermez, parkur ilerlemesini değiştirmez. Bu bilgi seçim ekranı, oyun ve sonuç ekranında açıktır. Sonuçtaki yıldızlar tur değerlendirmesidir. Oyunlar ödül veya ilerleme API’si çağırmaz. Veritabanı ya da backend dağıtımı gerektirmez.

## Doğrulama

- Türkçe içerik ve kayıt regresyonları: 97/97 test geçti.
- İsteğe bağlı oyun yükleme ve çalışma zamanı temizliği: 7/7 test geçti.
- `tools/turkce-oyun-tarayici.cjs`: dokuz oyunun tamamını gerçek sınıf/tema içeriğiyle bitirdi; alıştırma sırasında hiçbir ödül/ilerleme isteği yapılmadığını doğruladı. Duraklat/devam et, süresiz mod, Escape, menüden çıkış, hesap değiştirme ve temizleme kontrolleri geçti.
- 360×740 gündüz/gece, 768×1024 ve 1440×900: taşma veya tarayıcı JavaScript hatası yok.
- Gerçek uygulama HTML/CSS’si içinde gündüz/gece başlık kontrastı 11’in üzerinde. Bağımsız örnekle sınırlı olmayan uygulama testi mevcut.
- `tools/turkce-tarayici-kontrol.cjs`: parkur cevabı/ağ hatası/yeniden deneme, kayıt, sınıf seçimi, LGS, yazma, öğretmen kapsamı ve hesap değiştirme regresyonları geçti.

Ayrıntılı sonuçlar: `turkce-harita-oyunlar/sonuclar.json`. Tarayıcı kontrolleri Türkçe içerik GitHub Actions işine eklendi.

CI notu: Tarayıcı işi, Playwright 1.58.2 ile uyumlu Ubuntu 24.04'e sabitlendi; ubuntu-latest'in Ubuntu 26.04'e geçmesi eski tarayıcı işlerinin kurulumunu bozuyordu. Yeni SVG için köken ve SHA-256 kaydı eklendi. Medya denetiminde önceden var olan alt klasör tarama/kayıt hataları ve eski İngilizce yol beklentileri bu değişikliğin dışında kaldı. İlgili Türkçe ve tarayıcı testleri ayrı değerlendirilir.

Oyun sınıf listesi artık içerik paketindeki gamesAvailable bilgisine göre süzülür; tema seçimi de yeterli, farklı Türkçe sözcük/anlam çifti bulunan havuzlarla sınırlıdır. 5–8. sınıflardaki tüm temaların altı soruluk oyun turuna yetecek dolu sözcük/anlam/örnek havuzu testle doğrulanır. Boş 1–4. sınıflar veya eski İngilizce üniteler oyun seçicisine girmez.
