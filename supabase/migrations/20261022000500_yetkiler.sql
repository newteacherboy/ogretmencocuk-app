-- Diji Medu Türkçe veritabanı kurulumu: yetkiler
-- Uygulama veritabanına yalnızca edge function'lar (service_role) üzerinden erişir.
-- Tarayıcıdaki anahtar (anon/authenticated) hiçbir tabloyu veya fonksiyonu doğrudan kullanamaz.

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

revoke all on all tables in schema dm_private from public, anon, authenticated;
revoke execute on all functions in schema dm_private from public, anon, authenticated;
grant all on all tables in schema dm_private to service_role;
grant execute on all functions in schema dm_private to service_role;

-- Bundan sonra eklenecek tablo ve fonksiyonlar da varsayılan olarak kapalı başlasın.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
