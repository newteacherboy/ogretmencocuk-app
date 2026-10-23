# Türkçe üyelik ve kontrol merkezi

Kayıt: ad soyad, okul, 5–8 sınıf ve şifre. Gerçek e-posta toplanmaz, doğrulama istenmez. Sistem öğrenci kodu ve tek kullanımlık şifre kurtarma kodu oluşturur. Auth içindeki teknik kimlik adresleri posta göndermeyen `.invalid` alan adındadır. Parolalar yalnızca Supabase Auth tarafından tutulur.

`dijimedu` yetkili hesabı Auth `app_metadata.turkce_role=admin` ile yetkilendirilir. Parolası kaynak kodda, istemcide veya bu raporda yer almaz. Kontrol Merkezi öğrenci oluşturma, ad/okul/sınıf düzenleme, şifre yenileme, duraklatma ve XP/altın/enerji düzeltmeyi destekler. Öğrenci tarafından değiştirilebilen `user_metadata` yetki vermez. Yönetim işlemleri özel denetim tablosuna yazılır.

İlerleme ve ödüller soru cevaplarından sunucuda hesaplanır. Hesap kilidi, tekil ödül defteri ve istek kimliği aynı anda iki cihazın çift enerji/ödül üretmesini önler. İlk deneme başarısı en az %60 olmalıdır. Yazma görevleri otomatik doğruluk puanı getirmez. Parkur üst sınırları 140 XP/80 altın, oyunlar 70 XP/30 altındır. Parkur tekrarı ödülsüz, aynı oyun günlük bir kez ödüllüdür. Enerji 30 ile sınırlı, her 30 dakikada bir yenilenir; 24 saatte bir girişte 5 enerji eklenir.

Arkadaşlık karşılıklı kabul gerektirir. Akış, çevrimiçi görünürlük ve lig katılımı ayrı ayrı kapalı başlar. Liglerde yalnızca öğrenci kodu ve doğrulanmış XP gösterilir; ad, okul veya teknik Auth adresi paylaşılmaz. Yerel lig aynı sınıftakileri; Süper/Şampiyonlar sırasıyla 5/10 seviye üzerini gösterir. Haftalar Türkiye saatine göre pazartesi başlar; Efsaneler toplam XP kullanır.

Hedef yalnızca `isgnsmkboehygxxysria`. Başka Supabase projesi veya başka Edge Function değiştirilmedi. `diji-api` önceki v5 kaynakları korunarak üç üyelik modülü ve yönlendirmeleri ile v9'a güncellendi. İlk temel üyelik ve ödül tabloları önceden uygulanmıştı; `supabase/member-release/` bunların üstüne gelen incelenmiş SQL kaynağını içerir, başlangıç migration klasörüne otomatik karıştırılmaz. Üretimdeki asıl kayıt tetikleyicisinin `turkce_private.turkce_on_auth_signup` olduğu doğrulandı ve yeni alanlarla güncellendi.

Doğrulama: 132 ilgili Node testi; PGlite üzerinde gerçek PostgreSQL sorgularıyla ödül tekrarı, günlük oyun sınırı, başarısız ilerleme, haftalık lig, gizlilik, servis dışı RPC erişimi ve duraklatma testleri. Canlı API'de e-postasız kayıt/giriş/kurtarma, eşzamanlı başlangıç, sunucu cevabı, ödül, arkadaşlık ve lig testleri; yönetici giriş, öğrenci oluşturma, bilgi/bakiye/şifre değiştirme ve öğrenci erişim reddi. Mobil, tablet ve masaüstü tarayıcı kontrolü 360×740, 768×1024, 1440×900.

Geri alma: ön yüz için bu PR'ın birleştirme commit'i geri alınabilir. Yeni tabloları/verileri silmeden üyelik arayüzü geri çekilebilir. Backend geri alması gerektiğinde v5 kaynak anlık görüntüsü korunmuştur; ek tabloları silmek gerekmez.
