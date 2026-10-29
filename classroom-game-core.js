/* Shared question selection; usable by the browser and Node verification. */
(function(root){
  'use strict';
  const QUESTION_MS=15000, QUESTION_COUNT=8;
  function shuffle(items,random=Math.random){
    const result=[...items];
    for(let i=result.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[result[i],result[j]]=[result[j],result[i]];}
    return result;
  }
  function pool(words){
    const keys=new Set(),meanings=new Set();
    return words.filter(w=>{
      if(!w.kelime||!w.anlam||keys.has(w.kelime)||meanings.has(w.anlam))return false;
      keys.add(w.kelime);meanings.add(w.anlam);return true;
    });
  }
  function chooseWord(words,used,opponentWord,random=Math.random,previous=[]){
    // Reserve the word even while a wheel is spinning. Different speeds cannot
    // cause both players to receive the same live word later in the match.
    let options=words.filter(w=>w.kelime!==opponentWord&&!used.has(w.kelime));
    if(!options.length)options=words.filter(w=>w.kelime!==opponentWord);
    if(!options.length)throw Error('İki oyuncu için yeterli farklı içerik yok.');
    const fresh=options.filter(w=>!previous.includes(w.kelime));if(fresh.length)options=fresh;
    return options[Math.floor(random()*options.length)];
  }
  function question(word,category,words,random=Math.random){
    let field='anlam',prompt=`“${word.kelime}” sözcüğünün anlamı nedir?`;
    if(category===0){field='kelime';prompt=`${word.anlam}: Bu anlam hangi sözcüğe aittir?`;}
    if(category===2&&word.ornek){field='ornek';prompt=`“${word.kelime}” sözcüğünün kullanıldığı cümle hangisidir?`;}
    let wrong=[...new Set(words.filter(w=>w.kelime!==word.kelime).map(w=>w[field]).filter(Boolean))].filter(x=>x!==word[field]);
    // Some themes reuse an example sentence; fall back to a fully distinct
    // meaning question instead of displaying duplicate or missing choices.
    if(wrong.length<3&&field==='ornek')return question(word,1,words,random);
    if(wrong.length<3)throw Error('Dört farklı seçenek oluşturulamadı.');
    return {word:word.kelime,prompt,choices:shuffle([word[field],...shuffle(wrong,random).slice(0,3)],random),answer:word[field]};
  }
  function selectRound(words,count,previous=[]){
    const fresh=shuffle(words.filter(w=>!previous.includes(w.kelime)));
    return [...fresh,...shuffle(words.filter(w=>previous.includes(w.kelime)))].slice(0,count);
  }
  const api={selectRound,QUESTION_MS,QUESTION_COUNT,shuffle,pool,chooseWord,question};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  else root.dmClassroomCore=api;
})(typeof window!=='undefined'?window:globalThis);
