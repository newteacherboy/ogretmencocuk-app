const zones = [
  {id:1, title:'Oyun Kapısı', color:'blue', sign:{x:20,y:675}, island:{x:40,y:620,w:330,h:190}},
  {id:2, title:'Kelime Ormanı', color:'green', sign:{x:50,y:480}, island:{x:55,y:425,w:380,h:160}},
  {id:3, title:'Hikâye Adası', color:'gold', sign:{x:550,y:390}, island:{x:520,y:355,w:360,h:220}},
  {id:4, title:'Ses Şatosu', color:'purple', sign:{x:100,y:250}, island:{x:150,y:210,w:360,h:180}},
  {id:5, title:'Cümle Atölyesi', color:'red', sign:{x:470,y:165}, island:{x:470,y:120,w:330,h:170}},
  {id:6, title:'Oyun Festivali', color:'violet', sign:{x:510,y:34}, island:{x:560,y:16,w:280,h:120}}
];

const stationPositions = [
  [155,752],[223,752],[292,752],[360,740],
  [140,545],[214,545],[289,548],[363,556],
  [620,520],[690,515],[760,522],[810,558],
  [285,348],[356,342],[427,345],[497,334],
  [570,247],[637,247],[706,255],[772,272],
  [673,86],[726,84],[779,85],[830,78]
];

function makeText(question, skill, answer, feedback){
  return {type:'text', title:question, skill, placeholder:'En az bir cümle yaz.', answer, feedback};
}

const stops = [
  {
    id:1, zone:1, title:'Gizemli Oyun Kutusu', subtitle:'Görseller ve ipuçlarıyla oyunu tahmin et.', outcome:'Görsellerden hareketle tahminde bulunma', duration:'5-7 dakika',
    questions:[
      {type:'visual_mcq', image:'assets/questions/jump-rope.webp', imageAlt:'İki çocuk bir ipin uçlarını tutuyor. Ortadaki çocuk ipin üzerinden zıplıyor.', title:'Görselden Tahmin Et', skill:'Görsel okuma', prompt:'Görsele bak. Hangi oyunun anlatıldığını tahmin et?', choices:['Saklambaç','İp atlama','Mendil kapmaca','Yakan top'], answer:1, feedback:'Doğru. Çocuklar ipin üzerinden atlıyor.'},
      {type:'hint_mcq', title:'İpuçlarını Kullan', skill:'Tahmin etme', prompt:'İpuçlarını okuyarak oyunu bul.', hints:['En az iki kişiyle oynanır.','Sırayla saklanılır.','Bir oyuncu diğerlerini bulmaya çalışır.','Genellikle bahçede ya da parkta oynanır.'], choices:['Yakan top','Saklambaç','İp atlama','Körebe'], answer:1, feedback:'Aferin. Bu ipuçları saklambaç oyununu tanımlar.'},
      {type:'ordering', title:'Karışık Kuralları Sırala', skill:'Sıralama', prompt:'Verilen karışık oyun kurallarını doğru sıraya koy.', items:['Ebe, diğer oyuncuları arar.','Oyuncular uygun bir yere saklanır.','Ebeyi belirlemek için sayışma yapılır.','Oyun biter, ebe tüm oyuncuları bulduğunda.'], answerOrder:[2,1,0,3], feedback:'Harika. Kuralları doğru sıraya koydun.'},
      {type:'detail_mcq', image:'assets/questions/playground.webp', imageAlt:'Çimenli oyun alanında bir top, sarı kaydırak ve iki oturaklı salıncak var.', title:'Ayrıntıları Bul', skill:'Dikkat ve gözlem', prompt:'Görseldeki oyun alanını incele. Hangisi görselde yoktur?', choices:['Top','Salıncak','Kaydırak','Kayak'], answer:3, feedback:'Doğru. Görselde kayak yok.'},
      {type:'reading_mcq', title:'Metinden Tahmin Yap', skill:'Okuduğunu anlama', text:'Akşam olduğunda mahalledeki çocuklar toplanır. Baş gözüm üstüne sayışması yaparak ebe seçerler. Ebe gözlerini kapatır ve yüze kadar sayar. Diğer çocuklar saklanır. Ebe, herkesi bulmaya çalışır.', prompt:'Metindeki bilgilere göre hangi oyundan söz ediliyor?', choices:['İp atlama','Saklambaç','Mendil kapmaca','Yakan top'], answer:1, feedback:'Doğru. Metinde saklanma ve bulma anlatılıyor.'},
      {...makeText('Kendi Tahminini Yaz', 'Yazılı ifade', 'Bence çocuklar ip atlıyor; çünkü iki çocuk ipi tutuyor, ortadaki çocuk da ipin üzerinden zıplıyor.', 'Yazma görevin kaydedildi.'), prompt:'Görsele bak. Çocuklar hangi oyunu oynuyor olabilir? Tahminini ve görseldeki bir ipucunu tek cümleyle yaz.', image:'assets/questions/jump-rope.webp', imageAlt:'İki çocuk bir ipin uçlarını tutuyor. Ortadaki çocuk ipin üzerinden zıplıyor.'}
    ]
  }
];

const skillPool = [
  {
    title:'Kelime Avı', skill:'Kelime bilgisi', q:(n)=>({type:'mcq', prompt:`“Sevinçli” kelimesine yakın anlamlı sözcük hangisidir?`, choices:['Üzgün','Neşeli','Yorgun','Sessiz'], answer:1, feedback:'Doğru. Sevinçli ile neşeli yakın anlamlıdır.'})
  },
  {
    title:'Metni Anla', skill:'Okuduğunu anlama', q:(n)=>({type:'reading_mcq', text:`Ece ve arkadaşları okul bahçesinde yeni bir oyun denedi. Önce gruplara ayrıldılar. Sonra öğretmenlerinin anlattığı kurallara göre sırayla oynadılar. En çok bekleme sırasına saygı göstermeyi öğrendiler.`, prompt:'Metne göre öğrenciler en çok neyi öğrenmiştir?', choices:['Hızlı koşmayı','Kurallara saygı göstermeyi','Sessiz oturmayı','Kitap okumayı'], answer:1, feedback:'Doğru. Metinde bekleme sırasına saygı vurgulanıyor.'})
  },
  {
    title:'Dinle / Oku ve Seç', skill:'Dinleme ve konuşma', q:(n)=>({type:'hint_mcq', prompt:'Aşağıdaki açıklamaya göre en uygun yargıyı seç.', hints:['Bir arkadaşın oyunda hata yaptı.','Onunla konuşurken kırıcı olmamalısın.','Nazikçe yardım etmelisin.'], choices:['Onunla alay etmeliyim.','Bir daha dene, istersen yardımcı olayım demeliyim.','Oyundan çıkarmalıyım.','Hiç konuşmamalıyım.'], answer:1, feedback:'Aferin. İletişimde nazik olmak gerekir.'})
  },
  {
    title:'Olayları Sırala', skill:'Sıralama', q:(n)=>({type:'ordering', prompt:'Aşağıdaki olayları oluş sırasına göre diz.', items:['Oyuncular oyuna başlar.','Kurallar açıklanır.','Takımlar belirlenir.','Sonunda kazanan açıklanır.'], answerOrder:[2,1,0,3], feedback:'Doğru sıra: takımlar belirlenir, kurallar açıklanır, oyun başlar, kazanan açıklanır.'})
  },
  {
    title:'Dil Bilgisi ve Yazım', skill:'Dil bilgisi', q:(n)=>({type:'mcq', prompt:'“Çocuklar bahçede koştu.” cümlesinde fiil hangisidir?', choices:['Çocuklar','Bahçede','Koştu','Cümle'], answer:2, feedback:'Doğru. Fiil hareket bildiren “koştu” sözcüğüdür.'})
  },
  {
    title:'Yazma Görevi', skill:'Yazma', q:(n)=>({type:'text', prompt:'Bu durakta öğrendiklerini kullanarak oyunda uyulması gereken bir kural yaz.', placeholder:'En az bir anlamlı cümle yaz.', answer:'Oyunda herkes sırayla oynamalı ve kurallara uymalıdır.', feedback:'Yazma görevini tamamladın.'})
  }
];

const titles = [
  'Kelime Kutusu','Yakın ve Zıt Anlam','Metin Dedektifi','Olay Treni','Dinleme Bahçesi','Konuşma Köprüsü','Eş Sesli Sözcükler','Ana Fikir Adımı','Ayrıntı Avcısı','Kuralların Sırası','Duygu Kulesi','Nazik Konuşma','İsim ve Fiil','Heceleme Yolu','Noktalama Parkı','Tahmin Laboratuvarı','Oyun Kurucusu','Bilgi Toplayıcı','Özetleme Durağı','Cümle Atölyesi','Yaratıcı Kural','Arkadaşımın Oyunu','Festival Hazırlığı'
];

for(let i=2;i<=24;i++){
  const zone = Math.ceil(i/4);
  const title = titles[i-2] || `Durak ${i}`;
  const questions = skillPool.map((item, idx)=>({title:item.title, skill:item.skill, ...item.q(i)}));
  stops.push({
    id:i,
    zone,
    title,
    subtitle:'Türkçe becerilerini oyunlaştırılmış görevlerle geliştir.',
    outcome:['Kelime ve anlam ilişkilerini fark etme','Metni anlama ve yorumlama','Dinleme ve konuşma becerilerini kullanma','Sıralama ve kuralları kavrama','Dil bilgisi ve yazım kurallarını uygulama','Yazılı ifade geliştirme'][Math.min(zone-1,5)],
    duration:'5-7 dakika',
    questions
  })
}

const games = [
  {
    id:'kelime-dedektifi', title:'Kelime Dedektifi', description:'Anlamları çöz, doğru kelimeyi bul.',
    questions:[
      {prompt:'“Cesur” kelimesine yakın anlamlı olan hangisidir?', choices:['Korkak','Yürekli','Yorgun','Çekingen'], answer:1},
      {prompt:'“Dar” kelimesinin zıt anlamlısı hangisidir?', choices:['Geniş','Uzun','İnce','Büyük'], answer:0},
      {prompt:'“Yüz” sözcüğü hangi cümlede sayı anlamındadır?', choices:['Yüzünü yıkadı.','Yüz metre koştu.','Denizde yüz.','Yüzü kızardı.'], answer:1},
      {prompt:'“Neşeli” sözcüğü hangi anlama gelir?', choices:['Mutlu','Yorgun','Korkmuş','Kızgın'], answer:0},
      {prompt:'“Sessiz” kelimesinin zıt anlamlısı hangisidir?', choices:['Sakin','Gürültülü','Hızlı','Derin'], answer:1},
      {"prompt": "“Hızlı” sözcüğünün yakın anlamlısı hangisidir?", "choices": ["Çabuk", "Yavaş", "Uzak", "Sessiz"], "answer": 0},
      {"prompt": "“Islak” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Nemli", "Kuru", "Soğuk", "Yumuşak"], "answer": 1},
      {"prompt": "“Konuk” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Komşu", "Yolcu", "Misafir", "Arkadaş"], "answer": 2},
      {"prompt": "“Yanıt” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Soru", "Cevap", "Ödev", "Haber"], "answer": 1},
      {"prompt": "“Öykü” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Şiir", "Masal", "Roman", "Hikâye"], "answer": 3},
      {"prompt": "“İhtiyar” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Yaşlı", "Genç", "Yorgun", "Güçlü"], "answer": 1},
      {"prompt": "“Uzak” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Yakın", "Uzun", "Geniş", "İleri"], "answer": 0},
      {"prompt": "“Yoksul” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Fakir", "Cömert", "Zengin", "Mutlu"], "answer": 2},
      {"prompt": "“Doğa” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Orman", "Çevre", "Toprak", "Tabiat"], "answer": 3},
      {"prompt": "“Görev” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Vazife", "Oyun", "Sonuç", "İstek"], "answer": 0},
      {"prompt": "“Dolu” sözcüğü hangi cümlede bir hava olayını anlatır?", "choices": ["Bardak dolu.", "Çantam kitapla dolu.", "Bahçeye dolu yağdı.", "Otobüs dolu."], "answer": 2},
      {"prompt": "“Gül” sözcüğü hangi cümlede çiçek adıdır?", "choices": ["Bu şakaya gül.", "Vazoya bir gül koydu.", "Biraz da sen gül.", "Gül de neşelenelim."], "answer": 1},
      {"prompt": "“Ağır” sözcüğü hangi cümlede ağırlık bildirir?", "choices": ["Ağır bir çanta taşıdı.", "Ağır sözler söyledi.", "Ağır bir hastalık geçirdi.", "Ağır bir koku vardı."], "answer": 0},
      {"prompt": "“Tatlı” sözcüğü hangi cümlede mecaz anlamdadır?", "choices": ["Tatlı elmayı yedi.", "Tatlı bir şeftali aldı.", "Tatlı üzümler topladı.", "Bize tatlı bir gülümseme sundu."], "answer": 3},
      {"prompt": "“İnce” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Kısa", "Dar", "Kalın", "Uzun"], "answer": 2},
      {"prompt": "“Başlamak” sözcüğünün zıt anlamlısı hangisidir?", "choices": ["Bitirmek", "Açmak", "Denemek", "Hazırlamak"], "answer": 0},
      {"prompt": "“Fayda” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Zarar", "Yarar", "Amaç", "Neden"], "answer": 1},
      {"prompt": "“Özgür” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Tutsak", "Hür", "Cesur", "Yalnız"], "answer": 1},
      {"prompt": "“Beyaz” sözcüğünün eş anlamlısı hangisidir?", "choices": ["Kara", "Kızıl", "Ak", "Al"], "answer": 2}
    ]
  },
  {
    id:'olay-treni', title:'Olay Treni', description:'Karışık olayları sıraya koy.',
    questions:[
      {ordering:['Çocuk oyunu anlatır.','Önce oyunu düşünür.','Arkadaşlarıyla paylaşır.','Kuralları yazar.'], answerOrder:[1,3,0,2]},
      {ordering:['Top yere düşer.','Oyuncu topu atar.','Hakem sayıyı söyler.','Takım sevinir.'], answerOrder:[1,0,2,3]},
      {ordering:['Takımlar belirlenir.','Oyun başlar.','Kurallar açıklanır.','Kazanan alkışlanır.'], answerOrder:[0,2,1,3]},
      {ordering:['Kütüphane kartı alınır.','Kitap seçilir.','Kitap okunur.','Kitap geri teslim edilir.'], answerOrder:[0,1,2,3]},
      {ordering:['Soruyu okur.','Cevabı düşünür.','Cevabı işaretler.','Sonucu kontrol eder.'], answerOrder:[0,1,2,3]},
      {"prompt": "Tohumdan çiçeğe · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce saksıya toprak koydum.", "Sonra toprağa bir tohum ektim.", "Ardından tohumu suladım.", "Sonunda tohum filizlendi."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Okula hazırlık · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce sabah uyandım.", "Sonra yüzümü yıkadım.", "Ardından kahvaltımı yaptım.", "Son olarak okul servisine bindim."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Sandviç yapıyoruz · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce ekmeği ikiye böldüm.", "Sonra arasına peynir koydum.", "Ardından sandviçi tabağa aldım.", "En sonunda sandviçi yedim."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Kitap yolculuğu · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce kütüphaneye girdim.", "Sonra raftan bir kitap seçtim.", "Ardından kitabı ödünç aldım.", "Son olarak evde kitabı okudum."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Resim atölyesi · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce masaya bir kâğıt koydum.", "Sonra kalemle bir ev çizdim.", "Ardından evi boyadım.", "Son olarak resmi panoya astım."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Uçurtma günü · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce uçurtmanın çıtalarını birleştirdik.", "Sonra çıtaların üzerine kâğıt yapıştırdık.", "Ardından uçurtmaya ip bağladık.", "Sonunda uçurtmayı rüzgârda uçurduk."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Doğum günü · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce doğum günü pastasını yaptık.", "Sonra pastaya mumları taktık.", "Ardından mumları yaktık.", "Son olarak mumları üfledik."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Bilgi yarışması · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce yarışmanın kurallarını dinledik.", "Sonra ilk soruyu okuduk.", "Ardından cevabımızı yazdık.", "Sonunda sonuçları öğrendik."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Fidan dikiyoruz · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce bahçede bir çukur açtık.", "Sonra fidanı çukura yerleştirdik.", "Ardından köklerini toprakla örttük.", "Son olarak fidana su verdik."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Mektup gönderiyoruz · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce bir mektup yazdım.", "Sonra mektubu zarfa koydum.", "Ardından zarfın üzerine adresi yazdım.", "Son olarak mektubu postaneye verdim."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Piknik hazırlığı · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce piknik için yiyecek hazırladık.", "Sonra yiyecekleri sepete koyduk.", "Ardından piknik alanına gittik.", "Son olarak örtüyü serip yiyecekleri çıkardık."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Sınıf gazetesi · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce gazetenin konusunu belirledik.", "Sonra konuyla ilgili haberleri yazdık.", "Ardından yazıları sayfalara yerleştirdik.", "Son olarak gazeteyi sınıfta dağıttık."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Oyuncak tamiri · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce oyuncağın bozuk tekerleğini buldum.", "Sonra bozuk tekerleği çıkardım.", "Ardından yeni tekerleği taktım.", "Son olarak oyuncağı çalıştırıp denedim."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Kurabiye yapıyoruz · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce malzemeleri bir kaba koyduk.", "Sonra malzemeleri yoğurup hamur yaptık.", "Ardından hamura şekil verip fırına koyduk.", "Sonunda pişen kurabiyeleri çıkardık."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Yolculuk · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce biletimizi aldık.", "Sonra istasyona gittik.", "Ardından trene bindik.", "Sonunda gideceğimiz şehre vardık."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Yağmurlu gün · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce gökyüzünü bulutlar kapladı.", "Sonra yağmur yağmaya başladı.", "Ardından şemsiyemi açtım.", "Sonunda yağmur durunca şemsiyemi kapattım."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Tiyatro gösterisi · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce oyun için rollerimizi seçtik.", "Sonra repliklerimizi çalıştık.", "Ardından kostümlerimizi giyip sahneye çıktık.", "Sonunda gösteri bitince seyircileri selamladık."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Geri dönüşüm · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce atık kâğıtları topladık.", "Sonra kâğıtları geri dönüşüm kutusuna attık.", "Ardından görevliler kutuyu tesise götürdü.", "Sonunda tesiste kâğıtlardan yeni ürünler yapıldı."], "answerOrder": [0, 1, 2, 3]},
      {"prompt": "Satranç maçı · Olayları ilk olandan son olana doğru sırala.", "ordering": ["Önce satranç tahtasını masaya koyduk.", "Sonra taşları tahtaya dizdik.", "Ardından ilk hamleyi yaptık.", "Sonunda maç bitince taşları topladık."], "answerOrder": [0, 1, 2, 3]}
    ]
  },
  {
    id:'noktalama-tamircisi', title:'Noktalama Tamircisi', description:'Cümlelerin sonunu doğru tamamla.',
    questions:[
      {prompt:'“Bugün parka gittik” cümlesinin sonuna ne gelir?', choices:['?','!','.',','], answer:2},
      {prompt:'“Ne güzel bir gün” cümlesinin sonuna ne gelir?', choices:['!','.',',',':'], answer:0},
      {prompt:'“Yarın gelecek misin” cümlesinin sonuna ne gelir?', choices:['.',':','?','!'], answer:2},
      {prompt:'“Ali, Ayşe ve Mert geldi” cümlesinde hangi işaret kullanılır?', choices:['Kısa çizgi','Virgül','Kesme işareti','Soru işareti'], answer:1},
      {prompt:'“TBMM” hangi yazım örneğidir?', choices:['Kısaltma','Özel ad','Fiil','Sıfat'], answer:0},
      {"prompt": "“Adın ne” cümlesinin sonuna hangi işaret gelir?", "choices": [".", "?", "!", ","], "answer": 1},
      {"prompt": "“Eyvah, otobüsü kaçırdım” cümlesinin sonuna hangi işaret gelir?", "choices": [".", ",", "!", ";"], "answer": 2},
      {"prompt": "“Kitabımı masaya bıraktım” cümlesinin sonuna hangi işaret gelir?", "choices": ["?", ".", ":", ","], "answer": 1},
      {"prompt": "“Elma armut ve muz aldım.” cümlesinde “Elma”dan sonra hangisi gelmelidir?", "choices": ["Virgül", "Nokta", "Soru işareti", "Kesme işareti"], "answer": 0},
      {"prompt": "“Ankara_ya gittik.” ifadesindeki boşluğa hangi işaret gelir?", "choices": [",", ".", "'", "?"], "answer": 2},
      {"prompt": "“Pazardan şunları aldım_ elma, süt, ekmek.” cümlesindeki boşluğa ne gelir?", "choices": ["?", "!", ":", "'"], "answer": 2},
      {"prompt": "“5_ sınıf öğrencisiyim.” cümlesinde sıra sayısını göstermek için ne kullanılır?", "choices": ["Virgül", "Nokta", "Ünlem", "Kısa çizgi"], "answer": 1},
      {"prompt": "“Saat kaçta buluşacağız” cümlesinin sonuna hangi işaret gelir?", "choices": ["!", ".", ",", "?"], "answer": 3},
      {"prompt": "“Yaşasın, maçı kazandık” cümlesinin sonuna hangi işaret gelir?", "choices": ["!", "?", ":", ";"], "answer": 0},
      {"prompt": "“Kardeşim kitap okuyor” cümlesinin sonuna hangi işaret gelir?", "choices": [",", "?", ".", "!"], "answer": 2},
      {"prompt": "“Ayşe buraya gelir misin?” cümlesinde seslenmeden sonra ne kullanılır?", "choices": ["Nokta", "Virgül", "Kesme işareti", "Kısa çizgi"], "answer": 1},
      {"prompt": "“Türkçe” sözcüğünün yazımı için hangisi doğrudur?", "choices": ["türkçe", "Türkçe", "TÜrkçe", "TürKçe"], "answer": 1},
      {"prompt": "Bir cümlenin ilk harfi nasıl yazılır?", "choices": ["Her zaman küçük", "Her zaman büyük", "Yalnız sorularda büyük", "Yalnız başlıklarda büyük"], "answer": 1},
      {"prompt": "“İstanbul” sözcüğü nasıl bir addır?", "choices": ["Tür adı", "Fiil", "Özel ad", "Sıfat"], "answer": 2},
      {"prompt": "“Öğretmen ‘Aferin!’ dedi.” cümlesinde başkasının sözünü belirtmek için hangi işaret kullanılmıştır?", "choices": ["Tırnak işareti", "Kesme işareti", "Kısa çizgi", "İki nokta"], "answer": 0},
      {"prompt": "“Dr.” kısaltmasının sonundaki işaretin adı nedir?", "choices": ["Virgül", "Nokta", "Ünlem", "Soru işareti"], "answer": 1},
      {"prompt": "“Okuldan eve döndük” cümlesinin sonuna hangi işaret gelir?", "choices": ["!", "?", ",", "."], "answer": 3},
      {"prompt": "“Hangi kitabı seçtin” cümlesinin sonuna hangi işaret gelir?", "choices": [".", ":", "?", ","], "answer": 2},
      {"prompt": "“Dikkat, köpek var” uyarısının sonuna hangi işaret gelir?", "choices": ["!", "?", ",", ":"], "answer": 0}
    ]
  }
];