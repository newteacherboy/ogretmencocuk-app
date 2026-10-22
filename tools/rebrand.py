#!/usr/bin/env python3
"""Diji Medu (İngilizce) kodunu Diji Medu Türkçe'ye uyarlayan tek seferlik dönüştürücü.

Kullanım: python3 tools/rebrand.py <klasör>

Yaptığı: eski adresleri ogretmencocuk.com'a çevirir, eski uygulama klasörü yolunu
kökten açar, marka adını değiştirir ve eski Supabase projesine olan bağlantıyı
yeni-proje-ref / YENI_PUBLISHABLE_KEY yer tutucularına çevirir.
Eski değerler bu dosyanın kendisini bozmasın diye parça parça yazıldı.
"""
import os, re, sys

root = sys.argv[1]
SELF = os.path.abspath(__file__)
TEXT = ('.html', '.js', '.mjs', '.cjs', '.ts', '.css', '.json', '.md', '.yml', '.yaml',
        '.sql', '.txt', '.xml', '.sh', '.svg', '.conf')

OLD_APP = 'app.' + 'dijimedu' + '.com'
OLD_DIR = 'ingi' + 'lizce'
OLD_REF = 'nxfqlutul' + 'xqzqgwewssd'
OLD_KEY = 'sb_publishable_' + 'K9h4CnyaL8xb8B98o8aaFw_s9cMikuF'
OLD_MAIL = 'official.' + 'dijimedu' + '@gmail.com'
NEW = 'https://ogretmencocuk.com'

url_rules = [
    ('https://raw.githubusercontent.com/newteacherboy/english-tracker/main/' + OLD_DIR + '/', NEW + '/'),
    ('https://' + OLD_APP + '/' + OLD_DIR + '/', NEW + '/'),
    ('https://' + OLD_APP + '/' + OLD_DIR, NEW + '/'),
    ('https://' + OLD_APP, NEW),
    (OLD_APP, 'ogretmencocuk.com'),
    (OLD_DIR + '-manifest.json', 'manifest.json'),
    ('"id": "/' + OLD_DIR + '/"', '"id": "/"'),
    ('/' + OLD_DIR + '/', '/'),
    (OLD_REF, 'yeni-proje-ref'),
    (OLD_KEY, 'YENI_PUBLISHABLE_KEY'),
    (OLD_MAIL, 'official.ogretmencocuk@gmail.com'),
]
D1, D2 = 'Diji-' + 'Medu', 'Diji' + 'Medu'
brand_rules = [
    (re.compile(D1 + ' İngilizce'), 'Diji Medu Türkçe'),
    (re.compile('(' + D1 + '|' + D2 + ")[’']ya"), 'Diji Medu Türkçe’ye'),
    (re.compile('(' + D1 + '|' + D2 + ")[’']yu"), 'Diji Medu Türkçe’yi'),
    (re.compile('(' + D1 + '|' + D2 + ")[’']nun"), 'Diji Medu Türkçe’nin'),
    (re.compile('(' + D1 + '|' + D2 + ")[’']dan"), 'Diji Medu Türkçe’den'),
    (re.compile('(' + D1 + '|' + D2 + ")[’']da"), 'Diji Medu Türkçe’de'),
    (re.compile(r'(?<![\w-])(' + D1 + '|' + D2 + r'|Diji Medu)(?![\w-]| Türkçe)'), 'Diji Medu Türkçe'),
]
path_rule = re.compile(r'(?<![\w/.:-])' + OLD_DIR + '/')
brand_ext = ('.html', '.js', '.mjs', '.ts', '.sql')
skip_brand = ('media-rights-manifest.json', 'media-generation-record.json')

changed = 0
for d, dirs, files in os.walk(root):
    dirs[:] = [x for x in dirs if x not in ('.git', 'node_modules', 'diji-medu-gecmisi')]
    for f in files:
        p = os.path.join(d, f)
        if os.path.abspath(p) == SELF or not f.endswith(TEXT):
            continue
        try:
            s = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        o = s
        for a, b in url_rules:
            s = s.replace(a, b)
        s = path_rule.sub('', s)
        if f.endswith(brand_ext) and f not in skip_brand and os.sep + 'docs' + os.sep not in p:
            for r, b in brand_rules:
                s = r.sub(b, s)
        if s != o:
            open(p, 'w', encoding='utf-8').write(s)
            changed += 1
print('değişen dosya:', changed)
