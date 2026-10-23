const state = {
  progressKey:'ogretmencocuk_tr_5_1_progress',
  completed: (()=>{try{const v=JSON.parse(localStorage.getItem('ogretmencocuk_tr_5_1_progress') || '[]');return Array.isArray(v)?v.filter(n=>Number.isInteger(n)&&n>=1&&n<=24):[]}catch{return []}})(),
  currentStop:null,
  currentQuestionIndex:0,
  answers:[],
  currentView:'parkurView'
};

const views = document.querySelectorAll('.view');
const tabs = document.querySelectorAll('.tab');
const modalRoot = document.getElementById('modalRoot');
const completedCount = document.getElementById('completedCount');

function saveProgress(){ localStorage.setItem(state.progressKey, JSON.stringify(state.completed)); updateStats(); renderMap(); }
function updateStats(){ if(completedCount) completedCount.textContent = state.completed.length; }

function showView(id){
  views.forEach(v => v.classList.toggle('active', v.id===id));
  tabs.forEach(t => t.classList.toggle('active', t.dataset.view===id));
  state.currentView = id;
}

tabs.forEach(tab => tab.addEventListener('click', ()=>showView(tab.dataset.view)));


function getNextUnlockedStopId(){
  for(let i=1;i<=24;i++) if(!state.completed.includes(i)) return i;
  return 24;
}

function renderMap(){
  const map=document.getElementById('mapCanvas');
  if(!map) return;
  map.replaceChildren();
  const regionScenes=[
    {symbol:'🚪',landscape:'🏡 🌳',skill:'Görsel okuma ve tahmin',tone:'blue'},
    {symbol:'🌳',landscape:'🍄 🌲',skill:'Sözcükleri keşfet',tone:'green'},
    {symbol:'📖',landscape:'🏝️ 📚',skill:'Okuduğunu anla',tone:'orange'},
    {symbol:'🎭',landscape:'🏰 🎵',skill:'Dinle ve kendini ifade et',tone:'pink'},
    {symbol:'✏️',landscape:'📝 🏡',skill:'Cümle, yazım ve noktalama',tone:'teal'},
    {symbol:'🏆',landscape:'🎡 🎪',skill:'Kendi oyununu tasarla',tone:'purple'}
  ];
  zones.forEach((zone,zIndex)=>{
    const scene=regionScenes[zIndex];
    const region=document.createElement('section');
    region.className=`adventure-region tone-${scene.tone}`;
    region.setAttribute('aria-label',`${zone.id}. Bölge: ${zone.title}`);
    region.innerHTML=`<div class="region-landscape" aria-hidden="true"><span class="landscape-item">${scene.landscape}</span><span class="landscape-symbol">${scene.symbol}</span></div><div class="region-content"><div class="region-heading"><span class="region-count">${zone.id}. Bölge</span><h2>${zone.title}</h2><p>${scene.skill}</p></div><div class="region-stations"></div></div>`;
    const nodeList=region.querySelector('.region-stations');
    for(let i=1;i<=4;i++){
      const id=zIndex*4+i;
      const stop=stops.find(s=>s.id===id);
      const unlocked=id===1 || state.completed.includes(id) || state.completed.includes(id-1);
      const complete=state.completed.includes(id);
      const button=document.createElement('button');
      button.type='button';
      button.className=`adventure-station ${complete?'is-complete':unlocked?'is-current':'is-locked'}`;
      button.disabled=!unlocked;
      button.setAttribute('aria-label',`${id}. durak: ${stop.title}. ${complete?'Tamamlandı':unlocked?'Başlamaya hazır':'Kilitli'}`);
      button.innerHTML=`<span class="station-number">${id}</span><span class="station-status" aria-hidden="true">${complete?'✓':unlocked?'▶':'🔒'}</span>`;
      if(unlocked)button.addEventListener('click',()=>openStopIntro(id));
      nodeList.appendChild(button);
    }
    map.appendChild(region);
  });
  const counter=document.getElementById('adventureProgress');
  if(counter)counter.textContent=`${state.completed.length} / 24 durak tamamlandı`;
}

function showMapMessage(message){
  const old=document.querySelector('.map-toast');if(old) old.remove();
  const p=document.createElement('div');p.className='map-toast';p.textContent=message;
  document.body.appendChild(p);
  setTimeout(()=>p.remove(),2600);
}
function showProgress(){
  openModal(`<div class="modal-card"><div class="modal-inner"><div class="stop-header"><h2>İlerlemem</h2><button class="back-btn" onclick="closeModal()">×</button></div><p>5. Sınıf · Oyun Dünyası</p><div class="detail-grid"><div class="detail"><strong>${state.completed.length} / 24</strong><span>Tamamlanan durak</span></div><div class="detail"><strong>${24-state.completed.length}</strong><span>Kalan durak</span></div><div class="detail"><strong>Üyelik yok</strong><span>İlerleme yalnızca bu cihazda tutulur</span></div></div><button class="large-start" onclick="closeModal();openStopIntro(getNextUnlockedStopId())">Kaldığım yerden devam et →</button></div></div>`);
}

function openModal(content){
  modalRoot.innerHTML = `<div class="modal-backdrop">${content}</div>`;
}
function closeModal(){ modalRoot.innerHTML=''; }

function openStopIntro(stopId){
  const stop = stops.find(s=>s.id===stopId);
  openModal(`
    <div class="modal-card">
      <div class="modal-inner">
        <div class="stop-header">
          <button class="back-btn" onclick="closeModal()">←</button>
          <div class="crumbs">
            <span class="crumb-pill">5. Sınıf</span>
            <span>›</span>
            <span class="crumb-pill">1. Tema: Oyun Dünyası</span>
            <span>›</span>
            <span class="crumb-pill">${stop.zone}. Bölge: ${zones.find(z=>z.id===stop.zone).title}</span>
            <span>›</span>
            <span class="crumb-pill">${stop.id}. Durak</span>
          </div>
          <div></div>
        </div>
        <div class="stop-overview">
          <div>
            <h2>${stop.id}. Durak</h2>
            <h3>${stop.title}</h3>
            <p>${stop.subtitle}</p>
            <div class="detail-grid">
              <div class="detail"><strong>Kazanım</strong><span>${stop.outcome}</span></div>
              <div class="detail"><strong>Soru sayısı</strong><span>${stop.questions.length} soru</span></div>
              <div class="detail"><strong>Tahmini süre</strong><span>${stop.duration}</span></div>
            </div>
            <button class="large-start" onclick="startStop(${stop.id})">Göreve Başla →</button>
          </div>
          <div class="preview-image"></div>
        </div>
      </div>
    </div>
  `);
}

function startStop(stopId){
  state.currentStop = stops.find(s=>s.id===stopId);
  state.currentQuestionIndex = 0;
  state.answers = [];
  renderQuestion();
}

function renderQuestion(){
  const stop = state.currentStop;
  const q = stop.questions[state.currentQuestionIndex];
  const progressNodes = stop.questions.map((_,i)=>`<div class="pnode ${i<state.currentQuestionIndex?'done':''} ${i===state.currentQuestionIndex?'active':''}">${i+1}</div>`).join('');
  let leftHtml='';
  if(q.type==='visual_mcq'){
    leftHtml = `<div class="image-panel playground"><div class="rope"></div><div class="child one"></div><div class="child jump"></div><div class="child two"></div></div>`;
  } else if(q.type==='hint_mcq'){
    leftHtml = `<div class="prompt-box"><ul>${q.hints.map(h=>`<li>${h}</li>`).join('')}</ul></div>`;
  } else if(q.type==='reading_mcq'){
    leftHtml = `<div class="reading-box">${q.text}</div>`;
  } else if(q.type==='ordering'){
    leftHtml = `<div class="order-list" id="orderList">${q.items.map((it,i)=>orderItemTemplate(it,i)).join('')}</div>`;
  } else if(q.type==='text'){
    leftHtml = `<div class="text-box"><textarea id="textAnswer" maxlength="220" placeholder="${q.placeholder || ''}"></textarea><div class="text-meta"><span>Kısa bir tahmin cümlesi yaz.</span><span id="charCount">0/220</span></div></div>`;
  } else {
    leftHtml = `<div class="prompt-box">${q.prompt || ''}</div>`;
  }

  const optionsHtml = (q.choices || []).map((c,i)=>`<button class="option" data-index="${i}"><b>${String.fromCharCode(65+i)}</b> <span>${c}</span></button>`).join('');

  openModal(`
    <div class="modal-card">
      <div class="modal-inner quiz-layout">
        <div class="quiz-top">
          <div class="crumbs">
            <button class="back-btn" onclick="openStopIntro(${stop.id})">←</button>
            <span class="crumb-pill">5. Sınıf</span><span>›</span>
            <span class="crumb-pill">1. Tema: Oyun Dünyası</span><span>›</span>
            <span class="crumb-pill">${stop.id}. Durak: ${stop.title}</span>
          </div>
          <div class="progress-nodes">${progressNodes}</div>
          <div class="timer"><div class="timer-pill">Soru ${state.currentQuestionIndex+1}/${stop.questions.length}</div></div>
        </div>
        <div class="quiz-card">
          <div class="q-card-left">
            <h3>${state.currentQuestionIndex+1}. Soru <span class="skill-badge">${q.skill}</span></h3>
            <div class="question-title">${q.prompt || q.title}</div>
            ${leftHtml}
            ${q.choices ? `<div class="options" id="optionsArea">${optionsHtml}</div>` : ''}
            <div class="q-actions">
              <div class="feedback-box" id="feedbackBox">Her soru farklı bir beceriyi ölçer.</div>
              <button class="nav-btn nav-green" id="actionBtn">Kontrol Et</button>
            </div>
          </div>
          <aside class="q-side">
            <div class="mascot-mini"><h4>Küçük İpucu</h4><div class="mascot-speech">Dikkatli bak, oku ve düşün. İstersen bir daha kontrol et.</div></div>
            <div class="reward-box"><h4>Durak Özeti</h4><div class="progress-summary"><span>Durak: ${stop.id}</span><span>Bölge: ${zones.find(z=>z.id===stop.zone).title}</span><span>Beceri odağı: ${q.skill}</span></div></div>
          </aside>
        </div>
      </div>
    </div>
  `);

  if(q.type==='text'){
    const ta=document.getElementById('textAnswer');
    const cc=document.getElementById('charCount');
    ta.addEventListener('input', ()=>cc.textContent=`${ta.value.length}/220`);
  }
  if(q.choices){
    document.querySelectorAll('.option').forEach(btn => btn.addEventListener('click', ()=>{
      document.querySelectorAll('.option').forEach(b=>b.classList.remove('selected'));
      btn.classList.add('selected');
    }));
  }
  if(q.type==='ordering') bindOrdering();

  document.getElementById('actionBtn').addEventListener('click', ()=>checkQuestion());
}

function orderItemTemplate(text,i){
  return `<div class="order-item" data-order-index="${i}"><span class="order-num">${i+1}</span><span class="order-text">${text}</span><div class="order-actions"><button onclick="moveOrder(${i},-1)">↑</button><button onclick="moveOrder(${i},1)">↓</button></div></div>`;
}

let currentOrderState = [];
function bindOrdering(){
  const q = state.currentStop.questions[state.currentQuestionIndex];
  currentOrderState = q.items.map((text,idx)=>({text, original: idx}));
  redrawOrder();
}
function redrawOrder(){
  const root=document.getElementById('orderList'); if(!root) return;
  root.innerHTML = currentOrderState.map((it,i)=>`<div class="order-item"><span class="order-num">${i+1}</span><span class="order-text">${it.text}</span><div class="order-actions"><button onclick="moveOrder(${i},-1)">↑</button><button onclick="moveOrder(${i},1)">↓</button></div></div>`).join('');
}
function moveOrder(index,dir){
  const ni=index+dir; if(ni<0 || ni>=currentOrderState.length) return;
  [currentOrderState[index], currentOrderState[ni]] = [currentOrderState[ni], currentOrderState[index]];
  redrawOrder();
}

function checkQuestion(){
  const stop = state.currentStop;
  const q = stop.questions[state.currentQuestionIndex];
  let correct = false;
  const feedbackBox = document.getElementById('feedbackBox');
  if(q.type==='text'){
    const value=(document.getElementById('textAnswer').value || '').trim();
    if(value.length < 8){ feedbackBox.textContent='Lütfen en az bir anlamlı cümle yaz.'; return; }
    correct = true;
  } else if(q.type==='ordering'){
    const order = currentOrderState.map(x=>x.original);
    correct = JSON.stringify(order) === JSON.stringify(q.answerOrder);
  } else {
    const selected = document.querySelector('.option.selected');
    if(!selected){ feedbackBox.textContent='Önce bir seçenek işaretlemelisin.'; return; }
    const idx=Number(selected.dataset.index);
    correct = idx === q.answer;
    document.querySelectorAll('.option').forEach((opt,i)=>{
      if(i===q.answer) opt.classList.add('correct');
      else if(opt.classList.contains('selected')) opt.classList.add('wrong');
    });
  }
  if(correct) state.answers.push({question: q.title || q.prompt, correct:true});
  feedbackBox.textContent = correct ? (q.feedback || 'Doğru!') : 'Bir daha düşün. İstersen tekrar deneyebilirsin.';
  if(!correct){ return; }
  const actionBtn=document.getElementById('actionBtn');
  actionBtn.textContent = state.currentQuestionIndex === stop.questions.length-1 ? 'Sonuç Ekranına Geç →' : 'Sonraki Soru →';
  actionBtn.className='nav-btn nav-orange';
  actionBtn.onclick = ()=>nextQuestion();
}

function nextQuestion(){
  state.currentQuestionIndex++;
  if(state.currentQuestionIndex >= state.currentStop.questions.length){
    finishStop();
  } else {
    renderQuestion();
  }
}

function finishStop(){
  const total = state.answers.length;
  const correct = state.answers.filter(a=>a.correct).length;
  const wrong = total - correct;
  const score = total ? Math.round((correct/total)*100) : 0;
  if(!state.completed.includes(state.currentStop.id)){
    state.completed.push(state.currentStop.id);
    state.completed.sort((a,b)=>a-b);
    saveProgress();
  }
  openModal(`
    <div class="modal-card">
      <div class="modal-inner result-wrap">
        <div class="result-header">
          <button class="back-btn" onclick="closeModal()">←</button>
          <div class="crumbs"><span class="crumb-pill">${state.currentStop.id}. Durak tamamlandı</span></div>
          <div></div>
        </div>
        <div class="result-banner">
          <div>
            <div class="stars">⭐ ⭐ ⭐</div>
            <div class="big-title">Harika!</div>
            <div class="mascot-speech">${total} sorunun ${correct} tanesini doğru cevapladın.</div>
          </div>
          <div>
            <div class="result-stats">
              <div class="result-box"><strong>${score}/100</strong><span>Puanın</span></div>
              <div class="result-box"><strong>${correct}</strong><span>Doğru</span></div>
              <div class="result-box"><strong>${wrong}</strong><span>Yanlış</span></div>
              <div class="result-box"><strong>${state.currentStop.id}</strong><span>Durak</span></div>
            </div>
            <div class="result-actions">
              <button class="nav-btn nav-blue" onclick="restartStop(${state.currentStop.id})">Tekrar Oyna</button>
              <button class="nav-btn nav-orange" onclick="goNextStop(${state.currentStop.id})">Sonraki Durağa Geç →</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `);
}

function restartStop(id){ startStop(id); }
function goNextStop(id){
  closeModal();
  renderMap();
  const next = Math.min(24, id+1);
  setTimeout(()=>openStopIntro(next), 80);
}

function openGame(gameId){
  const game = games.find(g=>g.id===gameId);
  state.game = { game, index:0, answers:[] };
  renderGameQuestion();
}
function renderGameQuestion(){
  const {game, index} = state.game;
  const q = game.questions[index];
  const nodes = game.questions.map((_,i)=>`<div class="pnode ${i<index?'done':''} ${i===index?'active':''}">${i+1}</div>`).join('');
  let body='';
  if(q.ordering){
    currentOrderState=q.ordering.map((t,i)=>({text:t, original:i}));
    body=`<div class="order-list" id="orderList"></div>`;
  } else {
    body=`<div class="options" id="optionsArea">${q.choices.map((c,i)=>`<button class="option" data-index="${i}"><b>${String.fromCharCode(65+i)}</b><span>${c}</span></button>`).join('')}</div>`;
  }
  openModal(`
    <div class="modal-card"><div class="modal-inner quiz-layout">
      <div class="quiz-top"><div class="crumbs"><button class="back-btn" onclick="showView('gamesView');closeModal()">←</button><span class="crumb-pill">${game.title}</span></div><div class="progress-nodes">${nodes}</div><div class="timer-pill">${index+1}/${game.questions.length}</div></div>
      <div class="quiz-card"><div class="q-card-left"><h3>${game.title}</h3><div class="question-title">${q.prompt || 'Doğru sıralamayı yap.'}</div>${body}<div class="q-actions"><div class="feedback-box" id="feedbackBox">Hazırsan cevapla.</div><button class="nav-btn nav-green" id="gameBtn">Kontrol Et</button></div></div><aside class="q-side"><div class="mascot-mini"><h4>Oyun açıklaması</h4><div class="mascot-speech">${game.description}</div></div></aside></div>
    </div></div>
  `);
  if(q.ordering) redrawOrder();
  document.querySelectorAll('.option').forEach(btn=>btn.addEventListener('click', ()=>{ document.querySelectorAll('.option').forEach(b=>b.classList.remove('selected')); btn.classList.add('selected'); }));
  document.getElementById('gameBtn').addEventListener('click', ()=>checkGameQuestion());
}
function checkGameQuestion(){
  const {game, index} = state.game; const q = game.questions[index]; let correct = false;
  const fb=document.getElementById('feedbackBox');
  if(q.ordering){
    const order=currentOrderState.map(x=>x.original); correct = JSON.stringify(order)===JSON.stringify(q.answerOrder);
  } else {
    const selected=document.querySelector('.option.selected'); if(!selected){ fb.textContent='Önce bir cevap seç.'; return; }
    const idx=Number(selected.dataset.index); correct = idx===q.answer;
    document.querySelectorAll('.option').forEach((opt,i)=>{ if(i===q.answer) opt.classList.add('correct'); else if(opt.classList.contains('selected')) opt.classList.add('wrong'); });
  }
  if(!correct){ fb.textContent='Tekrar düşün ve yeniden dene.'; return; }
  state.game.answers.push(true);
  const btn=document.getElementById('gameBtn');
  fb.textContent='Doğru cevap!';
  btn.textContent = index===game.questions.length-1 ? 'Sonuç Ekranı →' : 'Sonraki Soru →';
  btn.className='nav-btn nav-orange';
  btn.onclick=()=>{
    state.game.index++;
    if(state.game.index >= game.questions.length) finishGame(); else renderGameQuestion();
  }
}
function finishGame(){
  const total = state.game.game.questions.length;
  const correct = state.game.answers.length;
  const score = Math.round((correct/total)*100);
  openModal(`
    <div class="modal-card"><div class="modal-inner result-wrap"><div class="result-banner"><div><div class="stars">🎮 ⭐ 🎮</div><div class="big-title">Oyun Bitti!</div><div class="mascot-speech">${state.game.game.title} oyununu tamamladın.</div></div><div><div class="result-stats"><div class="result-box"><strong>${score}/100</strong><span>Puanın</span></div><div class="result-box"><strong>${correct}</strong><span>Doğru</span></div><div class="result-box"><strong>${total-correct}</strong><span>Yanlış</span></div><div class="result-box"><strong>${total}</strong><span>Soru</span></div></div><div class="result-actions"><button class="nav-btn nav-blue" onclick="openGame('${state.game.game.id}')">Tekrar Oyna</button><button class="nav-btn nav-orange" onclick="closeModal()">Oyunlara Dön</button></div></div></div></div></div>
  `)
}

function renderGames(){
  const grid=document.getElementById('gameGrid');
  grid.innerHTML = games.map(g=>`<div class="game-card card"><h3>${g.title}</h3><p>${g.description}</p><button class="play" onclick="openGame('${g.id}')">Oyunu Aç</button></div>`).join('');
}

window.closeModal = closeModal;
window.startStop = startStop;
window.openStopIntro = openStopIntro;
window.restartStop = restartStop;
window.goNextStop = goNextStop;
window.moveOrder = moveOrder;
window.showView = showView;
window.openGame = openGame;

document.getElementById('continueJourney')?.addEventListener('click',()=>openStopIntro(getNextUnlockedStopId()));
document.getElementById('showAchievements')?.addEventListener('click',showProgress);
updateStats();
renderMap();
renderGames();