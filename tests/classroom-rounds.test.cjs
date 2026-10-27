const {test}=require('node:test');
const assert=require('node:assert/strict');
const core=require('../classroom-game-core.js');
const words=Array.from({length:24},(_,i)=>({kelime:'Sözcük '+i,anlam:'Anlam '+i,ornek:'Örnek cümle '+i}));
test('every question has four unique choices and exactly one correct answer',()=>{
 for(const w of words)for(let category=0;category<3;category++){
  const q=core.question(w,category,words);
  assert.equal(q.choices.length,4);assert.equal(new Set(q.choices).size,4);
  assert.equal(q.choices.filter(x=>x===q.answer).length,1);
 }
});
test('different speeds never give opponents the same live word',()=>{
 for(let trial=0;trial<40;trial++){
  const players=[{used:new Set()},{used:new Set()}];
  const advance=i=>{const p=players[i];p.word=core.chooseWord(words,p.used,players[1-i].word?.kelime);p.used.add(p.word.kelime);};
  advance(0);advance(1);
  for(const i of [0,0,1,0,1,1,0,0,0,1,1,1,1,0,1,0,1,0,1,0,1,1,0,0]){
   advance(i);assert.notEqual(players[0].word.kelime,players[1].word.kelime);
  }
 }
});
test('small pools still avoid concurrent duplicates after words run out',()=>{
 const small=words.slice(0,4),used=new Set(small.map(x=>x.kelime));
 for(const opponent of small)assert.notEqual(core.chooseWord(small,used,opponent.kelime).kelime,opponent.kelime);
});
test('example collisions fall back to a valid question',()=>{
 const repeated=words.map(x=>({...x,ornek:'Ortak cümle'}));
 const q=core.question(repeated[0],2,repeated);
 assert.equal(new Set(q.choices).size,4);assert.equal(q.answer,repeated[0].anlam);
});
test('round limit is 15 seconds and each player gets 12 questions',()=>{
 assert.equal(core.QUESTION_MS,15000);assert.equal(core.QUESTION_COUNT,12);
});
