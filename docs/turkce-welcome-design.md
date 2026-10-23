# Onaylanan mavi macera tasarımı

İlk ziyaret ekranı artık `index.html`: Üye Ol ve Giriş Yap bağlantıları. Oturumu açık kullanıcı `parkur.html` üzerinden uygulamasına devam eder. Üyelik ve giriş formları `hesap.html?mode=register` ve `hesap.html?mode=login` ile ayrı açılır. Doğrudan parkur adresine gelen oturumsuz ziyaretçi karşılama ekranına yönlendirilir.

Kullanıcının seçtiği birinci görselin papağanı, macera sahnesi, form başlığı ve küçük özellik görselleri `assets/welcome/approved-adventure.webp` içinde korunur. Yalnızca dekoratif resim bölgeleri CSS ile gösterilir; başlıklar, alanlar ve butonlar gerçek HTML öğeleridir. Görseldeki taslak formu veya butonları tıklanabilir alan gibi kullanmayız. Görsel kaynağı bu sohbette ImageGen ile oluşturulmuş ve kullanıcı tarafından onaylanmıştır. PNG, görüntü boyutunu değiştirmeden WebP biçimine dönüştürülmüştür.

Kayıt hâlâ ad soyad, okul, 5–8 sınıf ve şifre ister; e-posta istemez. Öğrenci ve kurtarma kodları gösterilmeden otomatik yönlendirme yapılmaz. Başarılı giriş parkura yönlendirir; mevcut Kontrol Merkezi ve yetkilendirme korunur. Backend veya SQL değişikliği yoktur.

Kontroller: 132 ilgili Node testi, mevcut PostgreSQL üyelik/ödül/yetki senaryoları ve `tools/welcome-browser.cjs` ile 360×740, 390×844, 768×1024, 1440×900. Karşılama butonları ve kayıt butonu kaydırmadan görünür; taşma yoktur. Formlar arası geçiş, şifre göster/gizle, kayıt kodları, oturum yönlendirmesi, yetkili sekmesi ve çıkış/giriş kontrol edilir. Ekran görüntüleri görsel olarak incelenir.
