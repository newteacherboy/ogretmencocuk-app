#!/usr/bin/env python3
"""Uygulamayı yeni Supabase projesine bağlar.

Kullanım:
  python3 tools/supabase-baglan.py <proje-ref> <publishable-key>

Örnek:
  python3 tools/supabase-baglan.py abcdefghijklmnopqrst sb_publishable_xxxxx

Kodda geçen yeni-proje-ref ve YENI_PUBLISHABLE_KEY yer tutucularını gerçek
değerlerle değiştirir (uygulama sayfaları, edge function'lar, migration'lar,
GitHub iş akışları). Publishable key tarayıcıda görünmesi normal olan anahtardır;
service_role / secret key'i ASLA bu dosyalara yazma.
"""
import os, re, sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
ref, key = sys.argv[1].strip(), sys.argv[2].strip()
if not re.fullmatch(r'[a-z]{20}', ref):
    sys.exit('Proje ref 20 küçük harften oluşmalı (Supabase > Project Settings > General > Project ID).')
if not (key.startswith('sb_publishable_') or key.startswith('eyJ')):
    sys.exit('Publishable (anon) anahtar bekleniyor; secret/service_role anahtarını kullanma.')
if 'service_role' in key or key.startswith('sb_secret_'):
    sys.exit('Bu bir gizli anahtar. Tarayıcı koduna yalnızca publishable anahtar yazılır.')

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT = ('.html', '.js', '.mjs', '.cjs', '.ts', '.json', '.md', '.yml', '.yaml', '.sql', '.txt')
changed = 0
for d, dirs, files in os.walk(root):
    dirs[:] = [x for x in dirs if x not in ('.git', 'node_modules', 'diji-medu-gecmisi')]
    for f in files:
        p = os.path.join(d, f)
        if not f.endswith(TEXT) or p == os.path.abspath(__file__):
            continue
        try:
            s = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        n = s.replace('yeni-proje-ref', ref).replace('YENI_PUBLISHABLE_KEY', key)
        if n != s:
            open(p, 'w', encoding='utf-8').write(n)
            changed += 1
print(f'{changed} dosya yeni projeye bağlandı: https://{ref}.supabase.co')
