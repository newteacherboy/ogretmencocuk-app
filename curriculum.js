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
      {prompt:'“Sessiz” kelimesinin zıt anlamlısı hangisidir?', choices:['Sakin','Gürültülü','Hızlı','Derin'], answer:1}
    ]
  },
  {
    id:'olay-treni', title:'Olay Treni', description:'Karışık olayları sıraya koy.',
    questions:[
      {ordering:['Çocuk oyunu anlatır.','Önce oyunu düşünür.','Arkadaşlarıyla paylaşır.','Kuralları yazar.'], answerOrder:[1,3,0,2]},
      {ordering:['Top yere düşer.','Oyuncu topu atar.','Hakem sayıyı söyler.','Takım sevinir.'], answerOrder:[1,0,2,3]},
      {ordering:['Takımlar belirlenir.','Oyun başlar.','Kurallar açıklanır.','Kazanan alkışlanır.'], answerOrder:[0,2,1,3]},
      {ordering:['Kütüphane kartı alınır.','Kitap seçilir.','Kitap okunur.','Kitap geri teslim edilir.'], answerOrder:[0,1,2,3]},
      {ordering:['Soruyu okur.','Cevabı düşünür.','Cevabı işaretler.','Sonucu kontrol eder.'], answerOrder:[0,1,2,3]}
    ]
  },
  {
    id:'noktalama-tamircisi', title:'Noktalama Tamircisi', description:'Cümlelerin sonunu doğru tamamla.',
    questions:[
      {prompt:'“Bugün parka gittik” cümlesinin sonuna ne gelir?', choices:['?','!','.',','], answer:2},
      {prompt:'“Ne güzel bir gün” cümlesinin sonuna ne gelir?', choices:['!','.',',',':'], answer:0},
      {prompt:'“Yarın gelecek misin” cümlesinin sonuna ne gelir?', choices:['.',':','?','!'], answer:2},
      {prompt:'“Ali, Ayşe ve Mert geldi” cümlesinde hangi işaret kullanılır?', choices:['Kısa çizgi','Virgül','Kesme işareti','Soru işareti'], answer:1},
      {prompt:'“TBMM” hangi yazım örneğidir?', choices:['Kısaltma','Özel ad','Fiil','Sıfat'], answer:0}
    ]
  }
];