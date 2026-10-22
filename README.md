# Diji Medu Türkçe

Ortaokul (5–8. sınıf) Türkçe dersi için oyunlu öğrenme uygulaması. Adres: **ogretmencocuk.com**

Diji Medu'nun altyapısından türetildi ama ondan **tamamen bağımsızdır**: ayrı GitHub reposu, ayrı Supabase hesabı, ayrı öğrenci hesapları. Diji Medu'dan hiçbir öğrenci verisi taşınmadı.

## Klasörler

| Yer | Ne var |
| --- | --- |
| Kök dizin | Uygulamanın kendisi (`index.html`, js, css, görseller). ogretmencocuk.com doğrudan burayı açar. |
| `supabase/migrations/` | Yeni veritabanının tam kurulumu (112 tablo, 129 fonksiyon, 36 tetikleyici, 13 zamanlanmış iş). Boş başlar. |
| `supabase/functions/` | Edge function'lar (diji-api, account-delete, papi-progress-* …). |
| `supabase/diji-medu-gecmisi/` | Diji Medu'nun eski migration'ları. Yalnızca arşiv, çalıştırılmaz. |
| `content/turkce/` | Türkçe ders içeriği (MEB Maarif Modeli'ne göre). |
| `tools/` | Kurulum araçları. |

## Kurulum sırası

1. **GitHub:** Bu kodu yeni ve boş bir repoya yükle. Settings → Pages → Branch: `main` / root. Custom domain: `ogretmencocuk.com`.
2. **Supabase (yeni, bağımsız hesap):** Yeni proje aç. Bölge **Central EU (Frankfurt)**, ad `diji-medu-turkce`. Veritabanı şifresini güvenli yere yaz.
3. **Bağlama:** `python3 tools/supabase-baglan.py <proje-ref> <publishable-key>` — tüm dosyalardaki yer tutucuları yeni projeyle değiştirir.
4. **Veritabanı:** `supabase/migrations/` içindeki 7 dosyayı sırayla SQL Editor'de çalıştır (veya Supabase bağlantısı kurulduğunda Claude uygular).
5. **Edge function sırları** (Supabase → Edge Functions → Secrets):
   - `EPOSTA_GONDEREN` (gönderen adres), `EPOSTA_GONDEREN_AD` = `Diji Medu Türkçe`
   - `BREVO_API_KEY` veya `RESEND_API_KEY` (e-posta için, biri yeter)
   - `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` Supabase tarafından otomatik gelir.
   - Papi AI sohbeti ilk sürümde **kapalı**; `PAPI_CHAT_*` sırları eklenmez.
6. **Fonksiyonları yayınla:** GitHub → Actions → "Supabase fonksiyonlarını yayınla" → `YAYINLA`. Önce repoya `SUPABASE_ACCESS_TOKEN` secret'ı eklenir.
7. **Google ile giriş** (isteğe bağlı): `supabase/GOOGLE_LOGIN_SETUP.md` adımları, dönüş adresi `https://ogretmencocuk.com/`.
8. **Alan adı (Blogger'dan taşıma):** Blogger → Ayarlar → Özel alan adını kaldır. Alan adının DNS'inde eski Blogger kayıtlarını (`ghs.google.com` CNAME'leri) sil, şunları ekle:
   - `@` için A kayıtları: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `www` için CNAME: `<github-kullanıcı-adı>.github.io`
   - GitHub Pages'te "Enforce HTTPS" işaretlenir (sertifika birkaç saat sürebilir).
9. **Okul ağı testi:** Okulda ogretmencocuk.com ve `https://<proje-ref>.supabase.co` açılıyor mu kontrol et.

## Güvenlik

- Tarayıcı koduna yalnızca **publishable** anahtar yazılır. Service role / secret anahtar asla repoya girmez.
- Veritabanında tüm tablolar ve fonksiyonlar tarayıcıya kapalıdır; erişim yalnızca edge function'lar üzerinden olur.
- Posta işçisi ve hesap silme işçisi için gizli anahtarlar kurulumda veritabanında rastgele üretilir.

## Henüz yapılmayanlar

- Arayüzdeki İngilizceye özgü metinler, CEFR rotası, telaffuz ve İngilizce içerikler hâlâ kodda; Türkçe içerik yüklendikçe değiştirilecek.
- Papi'nin Türkiye tişörtlü görselleri çizilecek (`content/turkce/papi-gorsel-brief.md`).
- Android/iOS paketleri (yeni paket kimliği: `com.ogretmencocuk.turkce` önerilir).
