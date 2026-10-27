/* Classroom scores are local match points. Existing server XP/energy rules remain authoritative. */
(()=>{'use strict';
const titles={arena:'Bilgi Arenası',wheel:'Anlam Çarkı',bridge:'Anlam Köprüsü'},E=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),mix=a=>[...a].sort(()=>Math.random()-.5);
const core=window.dmClassroomCore;
let run=null,clock=null,audio=null,serial=0;
const later=(f,ms)=>{const s=run;const id=setTimeout(()=>{s?.jobs.delete(id);if(run===s)f();},ms);s.jobs.add(id);};
function sound(ok){try{audio??=new AudioContext();void audio.resume();const o=audio.createOscillator(),g=audio.createGain();o.connect(g);g.connect(audio.destination);o.frequency.value=ok?660:190;g.gain.setValueAtTime(.06,audio.currentTime);g.gain.exponentialRampToValueAtTime(.001,audio.currentTime+.18);o.start();o.stop(audio.currentTime+.2);}catch{}}
function close(){serial++;clearInterval(clock);clock=null;if(run){for(const j of run.jobs)clearTimeout(j);run.root.remove();run.focus?.focus();run=null;}document.body.classList.remove('classroom-playing');}
async function open(kind){close();const token=serial,previousFocus=document.activeElement;const root=document.createElement('section');root.className='cg-overlay';root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');root.setAttribute('aria-label',titles[kind]);root.innerHTML='<p>Oyun içeriği hazırlanıyor…</p>';document.body.append(root);document.body.classList.add('classroom-playing');run={root,kind,jobs:new Set(),focus:previousFocus};try{const response=await fetch('content/turkce/parkur-5.json?v=classroom-1');if(!response.ok)throw Error('İçerik yüklenemedi.');const bank=await response.json();if(serial!==token)return;run.themes=bank.themes;setup();}catch{if(serial===token){root.innerHTML='<div class="cg-setup"><h1>İçerik yüklenemedi</h1><button data-cg="exit">Oyunlara dön</button></div>';root.onclick=click;}}}
function setup(){const s=run;clearInterval(clock);for(const j of s.jobs)clearTimeout(j);s.jobs.clear();s.root.classList.remove('cg-live');s.root.className='cg-overlay cg-scene-'+s.kind;s.root.innerHTML=`<div class="cg-setup"><h1>${titles[s.kind]}</h1><p>${s.kind==='bridge'?'Her tur 4 çift. Doğru eşler yeşil kalır.':'Aynı ekranda iki oyuncu, ayrı cevaplar ve ayrı süreler.'}</p><label>Tema<select id="cg-theme">${s.themes.map((t,i)=>`<option value="${i}">${t.number}. Tema · ${E(t.title)}</option>`).join('')}</select></label>${s.kind==='bridge'?'':`<label>1. oyuncu<input id="cg-name-0" maxlength="24" value="Ece"></label><label>2. oyuncu<input id="cg-name-1" maxlength="24" value="Ali"></label>`}<p>Bu oyunlarda maç puanı hesaplanır. XP, altın ve enerji değişmez.</p><button data-cg="start">▶ Oyuna Başla</button><button data-cg="exit">Oyunlara dön</button></div>`;s.root.onclick=click;s.root.onkeydown=keys;s.root.querySelector('button').focus();}
function reserveQuestion(playerIndex){
 const s=run,p=s.players[playerIndex],other=s.players[1-playerIndex];
 p.word=core.chooseWord(s.pool,p.used,other.word?.kelime);p.used.add(p.word.kelime);
 p.question=core.question(p.word,1,s.pool);
}
function start(){
 const s=run;s.pool=core.pool(s.themes[Number(s.root.querySelector('#cg-theme').value)].words);
 s.words=core.shuffle(s.pool).slice(0,12);
 s.names=[0,1].map(i=>s.root.querySelector('#cg-name-'+i)?.value.trim()||'Oyuncu '+(i+1));
 s.started=Date.now();s.players=[0,1].map(()=>({index:0,score:0,right:0,wrong:0,used:new Set(),phase:s.kind==='wheel'?'spin':'answer',deadline:Date.now()+core.QUESTION_MS,rotation:0}));
 s.round=0;s.matches=new Set();s.selected=null;s.misses=0;s.root.classList.add('cg-live');
 if(s.words.length<4)return setup();
 if(s.kind==='bridge')pairRound();else{reserveQuestion(0);reserveQuestion(1);render();}
 clock=setInterval(tick,100);
}
function head(){return `<header class="cg-head"><button data-cg="exit" aria-label="Oyundan çık">←</button><strong>Diji Medu Türkçe<br>${titles[run.kind]}</strong><span id="cg-time">00:00</span></header>`;}
const wheel=p=>`<div class="cg-wheel-wrap"><div class="cg-pointer">▼</div><div class="cg-wheel ${p.phase==='spinning'?'spinning':''}" style="--turn:${p.rotation}deg">${['Sözcük','Anlam','Cümle','Sözcük','Anlam','Cümle'].map((t,i)=>`<span style="--i:${i}">${t}</span>`).join('')}<b>★</b></div></div>`;
function panel(p,i){const s=run,q=p.question;if(p.phase==='done')return `<article class="cg-player cg-p${i}"><h2>${E(s.names[i])}</h2><strong>${p.score} ★</strong><p>Yarışı tamamladın!</p></article>`;return `<article class="cg-player cg-p${i}"><div class="cg-player-hud"><h2>${E(s.names[i])}</h2><b>${p.score} ★</b><span id="cg-timer-${i}">${p.phase==='answer'?Math.max(0,Math.ceil((p.deadline-Date.now())/1000))+' sn':''}</span></div>${s.kind==='wheel'?wheel(p):`<div class="cg-race"><span style="width:${p.index/core.QUESTION_COUNT*100}%"></span></div>`}<small>Soru ${p.index+1}/${core.QUESTION_COUNT}</small>${p.phase==='spin'||p.phase==='spinning'?`<button class="cg-spin" data-cg="spin" data-player="${i}" ${p.phase==='spinning'?'disabled':''}>${p.phase==='spinning'?'Dönüyor…':'ÇEVİR'}</button>`:`<h3>${E(q.prompt)}</h3><div class="cg-answers">${q.choices.map((c,j)=>`<button data-cg="answer" data-player="${i}" data-choice="${j}" ${p.phase!=='answer'?'disabled':''} class="${p.phase==='feedback'&&c===q.answer?'cg-correct':p.chosen===j?'cg-wrong':''}"><b>${'ABCD'[j]}</b>${E(c)}</button>`).join('')}</div><p class="cg-note" role="status">${E(p.note||'')}</p>`}</article>`;}
function render(){const s=run;if(s.kind==='bridge')return pairs();s.root.innerHTML=head()+`<div class="cg-duel">${s.players.map(panel).join('')}</div>`;}
function tick(){const s=run;if(!s)return;const elapsed=Math.floor((Date.now()-s.started)/1000),el=s.root.querySelector('#cg-time');if(el)el.textContent=String(Math.floor(elapsed/60)).padStart(2,'0')+':'+String(elapsed%60).padStart(2,'0');if(s.kind==='bridge')return;for(const [i,p]of s.players.entries()){const t=s.root.querySelector('#cg-timer-'+i);if(t)t.textContent=p.phase==='answer'?Math.max(0,Math.ceil((p.deadline-Date.now())/1000))+' sn':'';if(p.phase==='answer'&&p.deadline<=Date.now())answer(i,-1);}}
function answer(i,j){const s=run,p=s.players[i];if(p.phase!=='answer')return;const q=p.question,ok=q.choices[j]===q.answer;p.chosen=j;p.phase='feedback';if(ok){p.right++;p.score+=100+Math.max(0,Math.ceil((p.deadline-Date.now())/1000))*5;}else{p.wrong++;p.score=Math.max(0,p.score-20);}p.note=ok?'Doğru! ✦':j===-1?'Süre doldu. Doğru cevap yeşil.':'Doğru cevap yeşil gösterildi.';sound(ok);render();later(()=>{p.index++;p.chosen=null;p.note='';p.phase=p.index>=core.QUESTION_COUNT?'done':s.kind==='wheel'?'spin':'answer';if(p.phase==='done')p.word=null;else reserveQuestion(i);p.deadline=Date.now()+core.QUESTION_MS;if(s.players.every(x=>x.phase==='done'))result();else render();},ok?700:1800);}
function spin(i){
 const s=run,p=s.players[i];if(p.phase!=='spin')return;
 p.phase='spinning';const category=Math.floor(Math.random()*3);
 // The question belongs to this player only, never to a shared question array.
 p.question=core.question(p.word,category,s.pool);
 const target=(360-(category*60+30))%360;
 p.rotation+=1080+((target-p.rotation%360+360)%360);
 render();sound(true);
 later(()=>{p.phase='answer';p.deadline=Date.now()+core.QUESTION_MS;render();},1600);
}
function pairRound(){const s=run;s.deck=s.words.slice(s.round*4,s.round*4+4);s.left=mix(s.deck.map((_,i)=>i));s.right=mix(s.deck.map((_,i)=>i));s.matches=new Set();s.selected=null;pairs();}
function pairs(){const s=run;const col=(ids,side)=>`<div class="cg-pair-column">${ids.map(i=>`<button data-cg="pair" data-side="${side}" data-pair="${i}" class="${s.matches.has(i)?'cg-correct':s.selected?.side===side&&s.selected.i===i?'cg-selected':''}" ${s.matches.has(i)?'disabled':''}>${E(side==='left'?s.deck[i].kelime:s.deck[i].anlam)}</button>`).join('')}</div>`;s.root.innerHTML=head()+`<div class="cg-match-hud"><span>Tur ${s.round+1}/${Math.ceil(s.words.length/4)}</span><span>${s.matches.size}/${s.deck.length} eş</span><span>${s.round*400+s.matches.size*100} ★</span></div><h2 class="cg-pair-title">Sözcükleri anlamlarıyla eşleştir.</h2><div class="cg-pair-grid">${col(s.left,'left')}${col(s.right,'right')}</div><p class="cg-pair-note" role="status">${E(s.note||`Her tur 4 çift · Toplam ${s.words.length} çift`)}</p>`;}
function pair(side,i){const s=run;if(s.matches.has(i)||s.waiting)return;if(!s.selected||s.selected.side===side){s.selected={side,i};s.note='Şimdi karşı taraftan eşini seç.';return pairs();}if(s.selected.i===i){s.matches.add(i);s.note='Doğru eş! ✓';sound(true);}else{s.misses++;s.note='Bu iki kart eş değil. Yeniden dene.';sound(false);}s.selected=null;pairs();if(s.matches.size===s.deck.length){s.waiting=true;later(()=>{s.waiting=false;s.round++;s.note='';if(s.round*4>=s.words.length)result();else pairRound();},900);}}
function result(){const s=run;clearInterval(clock);const [a,b]=s.players,winner=a.score===b.score?'Berabere!':s.names[a.score>b.score?0:1]+' kazandı!';s.root.innerHTML=head()+`<div class="cg-result"><div class="cg-stars">★ ★ ★</div><h1>${s.kind==='bridge'?'Tüm köprüler kuruldu!':E(winner)}</h1>${s.kind==='bridge'?`<p>${s.words.length} çift · ${s.misses} yanlış deneme</p>`:s.players.map((p,i)=>`<p><b>${E(s.names[i])}: ${p.score} puan</b> · ${p.right} doğru · ${p.wrong} yanlış</p>`).join('')}<p>Maç puanları bu oyuna aittir.</p><button data-cg="restart">Yeniden oyna</button><button data-cg="exit">Oyunlara dön</button></div>`;s.root.querySelector('h1').tabIndex=-1;s.root.querySelector('h1').focus();}
function click(e){const b=e.target.closest('[data-cg]');if(!b||b.disabled)return;const a=b.dataset.cg;if(a==='exit')close();else if(a==='start')start();else if(a==='restart')setup();else if(a==='answer')answer(Number(b.dataset.player),Number(b.dataset.choice));else if(a==='spin')spin(Number(b.dataset.player));else if(a==='pair')pair(b.dataset.side,Number(b.dataset.pair));}
function keys(e){if(e.key==='Escape'){e.preventDefault();close();return;}if(e.key==='Tab'){const bs=[...run.root.querySelectorAll('button:not(:disabled),input,select')];if(e.shiftKey&&document.activeElement===bs[0]){e.preventDefault();bs.at(-1)?.focus();}else if(!e.shiftKey&&document.activeElement===bs.at(-1)){e.preventDefault();bs[0]?.focus();}}}
function cards(){
 const grid=document.querySelector('#gameGrid');if(!grid)return;
 for(const [id,title] of Object.entries(titles)){
  const target=document.querySelector(id==='bridge'?'#soloGames':'#duelGames')||grid;
  target.insertAdjacentHTML('beforeend',`<article class="modern-game-card cg-card"><div class="game-illustration cg-cover cg-cover-${id}" role="img" aria-label="${title}"></div><div class="game-details"><h2>${title}</h2><p>${id==='bridge'?'4 çift × 3 tur · Anlamları buluştur.':'İki oyuncu · Farklı sorular · 15 saniye'}</p><div class="game-card-actions"><span>Serbest oyun</span><button class="modern-play" data-classroom="${id}">Oyuna Başla</button></div></div></article>`);
 }
 grid.addEventListener('click',e=>{const b=e.target.closest('[data-classroom]');if(b)void open(b.dataset.classroom);});
}
cards();window.dmClassroomGames={open,close};
})();
