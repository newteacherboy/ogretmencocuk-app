const state = {
  progressKey:'ogretmencocuk_tr_5_1_progress',
  completed: [],
  currentStop:null,
  currentQuestionIndex:0,
  answers:[],
  currentView:'parkurView'
};

const views = document.querySelectorAll('.view');
const tabs = document.querySelectorAll('button.tab');
const modalRoot = document.getElementById('modalRoot');
const completedCount = document.getElementById('completedCount');

function refreshEconomy(){
 const x=window.practiceEconomy?.snapshot();if(!x)return;
 const vals={energyValue:x.energy+"/30",xpValue:x.xp.toLocaleString("tr-TR"),goldValue:x.gold.toLocaleString("tr-TR"),levelValue:"Sv. "+x.level};
 Object.entries(vals).forEach(([key,value])=>{const e=document.getElementById(key);if(e)e.textContent=value});
 const e=document.querySelector(".economy-pill.energy");
 if(e){const m=Math.floor(x.nextEnergySeconds/60),s=x.nextEnergySeconds%60;e.title=x.energy>=30?"Enerjin dolu":"Sonraki enerji: "+String(m).padStart(2,"0")+":"+String(s).padStart(2,"0");}
}
window.addEventListener("practice-rewards-changed",refreshEconomy);
function saveProgress(){ updateStats(); renderMap(); }
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
  if(!map)return;
  map.replaceChildren();
  zones.forEach((zone,zIndex)=>{
    const region=document.createElement('section');
    region.className=`mobile-region zone-${zIndex+1}`;
    region.setAttribute('aria-label',`${zone.id}. Bölge: ${zone.title}`);
    const text=document.createElement('div');text.className='mobile-region-label';
    const number=document.createElement('span');number.className='region-index';number.textContent=`${zone.id}. Bölge`;
    const title=document.createElement('h2');title.textContent=zone.id===1?'Okuma Yolculuğu':zone.title;
    text.append(number,title);
    const art=document.createElement('img');art.className='region-art';art.src=`assets/region-${zone.id}.webp`;art.alt='';art.loading='eager';
    const nodes=document.createElement('div');nodes.className='mobile-region-nodes';
    for(let i=1;i<=4;i++){
      const id=zIndex*4+i;const stop=stops.find(s=>s.id===id);
      const done=state.completed.includes(id);
      const unlocked=id===1||done||state.completed.includes(id-1);
      const button=document.createElement('button');button.type='button';
      button.className=`mobile-node ${done?'complete':unlocked?'available':'locked'}`;
      button.textContent=String(id);button.disabled=!unlocked;
      button.setAttribute('aria-label',`${id}. durak, ${stop.title}, ${done?'tamamlandı':unlocked?'açık':'kilitli'}`);
      if(unlocked)button.addEventListener('click',()=>openStopIntro(id));
      nodes.appendChild(button);
    }
    region.append(art,text,nodes);map.appendChild(region);
  });
  const counter=document.getElementById('adventureProgress');
  if(counter)counter.textContent=`${state.completed.length} / 24 durak`;
}

function showMapMessage(message){
  const old=document.querySelector('.map-toast');if(old) old.remove();
  const p=document.createElement('div');p.className='map-toast';p.textContent=message;
  document.body.appendChild(p);
  setTimeout(()=>p.remove(),2600);
}
function showProgress(){
  openModal(`<div class="modal-card"><div class="modal-inner"><div class="stop-header"><h2>İlerlemem</h2><button class="back-btn" onclick="closeModal()">×</button></div><p>5. Sınıf · Oyun Dünyası</p><div class="detail-grid"><div class="detail"><strong>${state.completed.length} / 24</strong><span>Tamamlanan durak</span></div><div class="detail"><strong>${24-state.completed.length}</strong><span>Kalan durak</span></div><div class="detail"><strong>Güvenli hesap</strong><span>İlerlemen sunucuda tutulur</span></div></div><button class="large-start" onclick="closeModal();openStopIntro(getNextUnlockedStopId())">Kaldığım yerden devam et →</button></div></div>`);
}

let quizTimerId=null;
function stopQuizTimer(){if(quizTimerId!==null){clearInterval(quizTimerId);quizTimerId=null}}
function startQuizTimer(startedAt=state.startedAt||Date.now()){stopQuizTimer();const tick=()=>{const el=document.getElementById('elapsedClock');if(el){const secs=Math.max(0,Math.floor((Date.now()-startedAt)/1000));el.textContent=String(Math.floor(secs/60)).padStart(2,'0')+':'+String(secs%60).padStart(2,'0')}};tick();quizTimerId=setInterval(tick,1000)}
function openModal(content){
  modalRoot.innerHTML = `<div class="modal-backdrop${content.includes('quiz-layout') ? ' quiz-screen' : ''}">${content}</div>`;
}
function closeModal(){stopQuizTimer();modalRoot.innerHTML=''; }

function openStopIntro(stopId){
  const stop = stops.find(s=>s.id===stopId);
  openModal(`
    <div class="modal-card stop-intro-card">
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
            <div class="stop-reward-hint">⚡ ${stop.questions.length} enerji &nbsp; ✨ En fazla 140 XP &nbsp; 🪙 En fazla 80 altın</div><button class="large-start" onclick="startStop(${stop.id})">Göreve Başla →</button>
          </div>
          <div class="stop-illustration" aria-hidden="true"><span class="stop-art-number">${stop.id}</span><span class="stop-art-symbol">📚</span><span class="stop-art-sparkle">✦</span></div>
        </div>
      </div>
    </div>
  `);
}

async function startStop(stopId){
  try{await window.turkceMember.ready;state.serverAttempt=await window.turkceMember.request("start",{mode:"stop",activity_id:String(stopId)});}catch(e){showMapMessage(e.message);return;}
  state.currentStop = stops.find(s=>s.id===stopId);
  state.currentQuestionIndex = state.serverAttempt.index;
  if(state.stopSession?.attemptId!==state.serverAttempt.attempt_id)state.stopSession={attemptId:state.serverAttempt.attempt_id,frontier:state.serverAttempt.index,results:{},drafts:{}};
  state.stopSession.frontier=state.serverAttempt.index;
  state.answers = [];
  state.questionMistakes = state.serverAttempt.mistakes;
  state.totalMistakes = state.serverAttempt.wrong;
  state.startedAt = Date.now();
  renderQuestion();
}

function renderQuestion(){
  refreshEconomy();
  const stop = state.currentStop;
  const q = stop.questions[state.currentQuestionIndex];
  const progressNodes = stop.questions.map((_,i)=>`<div class="pnode ${i<(state.stopSession?.frontier??state.currentQuestionIndex)?'done':''} ${i===state.currentQuestionIndex?'active':''}">${i+1}</div>`).join('');
  let leftHtml='';
  if(q.type==='visual_mcq'||q.type==='detail_mcq'){
    leftHtml = `<figure class="image-panel question-illustration"><img src="${q.image}" alt="${q.imageAlt}" width="1050" height="700"><figcaption hidden>${q.imageAlt}</figcaption></figure>`;
  } else if(q.type==='hint_mcq'){
    leftHtml = `<div class="prompt-box"><ul>${q.hints.map(h=>`<li>${h}</li>`).join('')}</ul></div>`;
  } else if(q.type==='reading_mcq'){
    leftHtml = `<div class="reading-box">${q.text}</div>`;
  } else if(q.type==='ordering'){
    leftHtml = `<div class="order-list" id="orderList">${q.items.map((it,i)=>orderItemTemplate(it,i)).join('')}</div>`;
  } else if(q.type==='text'){
    leftHtml = `${q.image?`<figure class="image-panel question-illustration"><img src="${q.image}" alt="${q.imageAlt}" width="1050" height="700"><figcaption hidden>${q.imageAlt}</figcaption></figure>`:''}<div class="text-box"><textarea id="textAnswer" maxlength="220" placeholder="${q.placeholder || ''}"></textarea><div class="text-meta"><span>8–220 karakterlik bir cümle yaz. Birden fazla yanıt olabilir.</span><span id="charCount">0/220</span></div></div>`;
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
          <div class="timer"><div class="timer-pill">⏱ <span id="elapsedClock">00:00</span></div><div class="timer-pill">Soru ${state.currentQuestionIndex+1}/${stop.questions.length}</div></div>
        </div>
        <div class="quiz-card">
          <div class="q-card-left">
            <h3>${state.currentQuestionIndex+1}. Soru <span class="skill-badge">${q.skill}</span></h3>
            <div class="question-title">${q.prompt || q.title}</div>
            ${leftHtml}
            ${q.choices ? `<div class="options" id="optionsArea">${optionsHtml}</div>` : ''}
            <div class="q-actions">
              <div class="feedback-box" id="feedbackBox" role="status" aria-live="polite">Her soru farklı bir beceriyi ölçer.</div>
              <div class="question-navigation"><button class="nav-btn nav-blue" id="previousQuestionBtn" type="button" onclick="previousQuestion()">← Önceki Soru</button><button class="nav-btn nav-green" id="actionBtn">Kontrol Et</button></div>
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

  const illustration=document.querySelector('.question-illustration img');
  if(illustration){const fallback=()=>{illustration.hidden=true;illustration.nextElementSibling.hidden=false;};illustration.addEventListener('error',fallback);if(illustration.complete&&!illustration.naturalWidth)fallback();}
  startQuizTimer();
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

  const session=state.stopSession,idx=state.currentQuestionIndex;
  const saved=session?.results[idx],draft=saved?.answer??session?.drafts[idx];
  if(draft!==undefined&&draft!==null){
    if(q.choices)document.querySelector(`.option[data-index="${draft}"]`)?.classList.add('selected');
    else if(q.type==='ordering'&&Array.isArray(draft)){currentOrderState=draft.map(i=>({text:q.items[i],original:i}));redrawOrder();}
    else if(q.type==='text'){document.getElementById('textAnswer').value=draft;document.getElementById('charCount').textContent=draft.length+'/220';}
  }
  document.getElementById('previousQuestionBtn').disabled=idx===0;
  document.getElementById('actionBtn').onclick=checkQuestion;
  if(saved)showStopAnswer(q,saved.result,false);
  else if(session&&idx<session.frontier)showStopAnswer(q,{advanced:true,correct:null,ungraded:q.type==='text',correct_answer:q.answerOrder??q.answer},false);
}

function stopAnswerDraft(){
 const q=state.currentStop.questions[state.currentQuestionIndex];
 if(q.type==='text')return document.getElementById('textAnswer').value;
 if(q.type==='ordering')return currentOrderState.map(x=>x.original);
 const selected=document.querySelector('#optionsArea .selected');return selected?Number(selected.dataset.index):undefined;
}
function previousQuestion(){
 const button=document.getElementById('previousQuestionBtn');
 if(!button||button.disabled||state.currentQuestionIndex===0)return;
 state.stopSession.drafts[state.currentQuestionIndex]=stopAnswerDraft();
 state.currentQuestionIndex--;renderQuestion();
}

function orderItemTemplate(text,i){
  return `<div class="order-item" data-order-index="${i}"><span class="order-num">${i+1}</span><span class="order-text">${text}</span><div class="order-actions"><button aria-label="${i+1}. vagonu yukarı taşı" ${i===0?'disabled':''} onclick="moveOrder(${i},-1)">↑</button><button aria-label="${i+1}. vagonu aşağı taşı" ${i===currentOrderState.length-1?'disabled':''} onclick="moveOrder(${i},1)">↓</button></div></div>`;
}

let currentOrderState = [];
function bindOrdering(){
  const q = state.currentStop.questions[state.currentQuestionIndex];
  currentOrderState = q.items.map((text,idx)=>({text, original: idx}));
  redrawOrder();
}
function redrawOrder(){
  const root=document.getElementById('orderList'); if(!root) return;
  root.innerHTML = currentOrderState.map((it,i)=>`<div class="order-item"><span class="order-num">${i+1}</span><span class="order-text">${it.text}</span><div class="order-actions"><button aria-label="${i+1}. vagonu yukarı taşı" ${i===0?'disabled':''} onclick="moveOrder(${i},-1)">↑</button><button aria-label="${i+1}. vagonu aşağı taşı" ${i===currentOrderState.length-1?'disabled':''} onclick="moveOrder(${i},1)">↓</button></div></div>`).join('');
}
function moveOrder(index,dir){
  const ni=index+dir; if(ni<0 || ni>=currentOrderState.length) return;
  [currentOrderState[index], currentOrderState[ni]] = [currentOrderState[ni], currentOrderState[index]];
  redrawOrder();
}


// Answer sounds: synthesized only on a student's click; no external files.
let answerAudioContext;
function playAnswerSound(correct){
  try {
    const Ctx=window.AudioContext||window.webkitAudioContext;
    if(!Ctx)return;
    answerAudioContext=answerAudioContext||new Ctx();
    if(answerAudioContext.state==="suspended")answerAudioContext.resume();
    const ctx=answerAudioContext,now=ctx.currentTime;
    const tones=correct?[[660,0,.105],[880,.115,.16]]:[[240,0,.16],[185,.17,.2]];
    tones.forEach(([freq,offset,duration])=>{
      const osc=ctx.createOscillator(),gain=ctx.createGain(),start=now+offset;
      osc.type=correct?"sine":"triangle";osc.frequency.setValueAtTime(freq,start);
      gain.gain.setValueAtTime(.0001,start);gain.gain.exponentialRampToValueAtTime(.11,start+.014);
      gain.gain.exponentialRampToValueAtTime(.0001,start+duration);
      osc.connect(gain);gain.connect(ctx.destination);osc.start(start);osc.stop(start+duration+.01);
    });
  }catch(e){/* Sound is optional; never block interaction. */}
}
function showAnswerFeedback(correct,feedbackEl,correctText,wrongText){
  playAnswerSound(correct);
  if(feedbackEl){feedbackEl.textContent=(correct?"✓ ":"✕ ")+(correct?correctText:wrongText);feedbackEl.classList.toggle("feedback-correct",correct);feedbackEl.classList.toggle("feedback-wrong",!correct);}
}
function markOptionsAfterCheck(answer,correct,reveal=false){
  document.querySelectorAll(".option").forEach((opt,i)=>{
    const selected=opt.classList.contains("selected");
    opt.classList.remove("correct","wrong");
    if((correct||reveal) && i===answer){opt.classList.add("correct");}
    else if(!correct && selected){opt.classList.add("wrong");}
    const prior=opt.querySelector(".answer-mark");if(prior)prior.remove();
    if((correct||reveal)&&i===answer){const mark=document.createElement("strong");mark.className="answer-mark";mark.textContent=" ✓";mark.setAttribute("aria-label","Doğru");opt.append(mark);}
    if(!correct&&selected){const mark=document.createElement("strong");mark.className="answer-mark";mark.textContent=" ✕";mark.setAttribute("aria-label","Yanlış");opt.append(mark);}
  });
}

function showStopAnswer(q,r,playSound){
 const btn=document.getElementById('actionBtn'),fb=document.getElementById('feedbackBox');
 if(q.choices)markOptionsAfterCheck(r.correct_answer,r.correct,r.advanced);
 let solution='';
 if(q.choices&&Number.isInteger(r.correct_answer))solution=String.fromCharCode(65+r.correct_answer)+' — '+q.choices[r.correct_answer];
 else if(q.items&&Array.isArray(r.correct_answer))solution=r.correct_answer.map((i,n)=>(n+1)+'. '+q.items[i]).join(' → ');
 const explanation=q.type==='ordering'?'Kurallar bu sırayla uygulanır.':(q.feedback||'').replace(/^(Doğru|Aferin|Harika)[.!]?\s*/,'');
 let message;
 if(q.type==='text')message=(r.advanced?'Yanıtın kaydedildi. Bu görev otomatik puanlanmaz. ':'8–220 karakterlik bir cümle yaz. ')+(q.answer?'Örnek yanıt: '+q.answer:'');
 else if(r.correct===true)message=q.feedback||'Doğru!';
 else message=(solution?'Doğru cevap: '+solution+'. '+explanation:'Cevap bilgisi alınamadı.')+(r.correct===null?' Önceki seçimin bu oturumda kayıtlı değil.':'');
 if(playSound)playAnswerSound(r.correct===true);
 fb.textContent=(q.type==='text'||r.correct===null?'':r.correct?'✓ ':'✕ ')+message;
 fb.classList.toggle('feedback-correct',r.correct===true&&q.type!=='text');
 fb.classList.toggle('feedback-wrong',r.correct===false&&q.type!=='text');
 if(r.advanced){
   document.querySelectorAll('#optionsArea button,#orderList button,#textAnswer').forEach(el=>el.disabled=true);
   btn.dataset.validated='true';btn.textContent=state.currentQuestionIndex===state.currentStop.questions.length-1?'Sonuç Ekranına Geç →':'Sonraki Soru →';btn.onclick=nextQuestion;
 }
}
async function checkQuestion(){
 const btn=document.getElementById('actionBtn');if(!btn||btn.disabled||btn.dataset.validated==='true')return;
 const index=state.currentQuestionIndex,q=state.currentStop.questions[index],fb=document.getElementById('feedbackBox');
 const answer=stopAnswerDraft();
 if(q.type==='text'&&(answer.trim().length<8||answer.trim().length>220)){showStopAnswer(q,{advanced:false,correct:false,ungraded:true},false);return;}
 if(q.choices&&answer===undefined){fb.textContent='Önce bir seçenek işaretle.';return;}
 btn.disabled=true;document.getElementById('previousQuestionBtn').disabled=true;
 document.querySelectorAll('#optionsArea button,#orderList button,#textAnswer').forEach(el=>el.disabled=true);
 try{
   const r=await window.turkceMember.request('answer',{attempt_id:state.serverAttempt.attempt_id,index,answer:typeof answer==='string'?answer.trim():answer});
   state.serverResult=r;state.stopSession.drafts[index]=answer;
   if(r.advanced){state.stopSession.results[index]={answer,result:r};state.stopSession.frontier=r.index;}
   showStopAnswer(q,r,true);
 }catch(e){fb.textContent=e.message;}finally{
   btn.disabled=false;document.getElementById('previousQuestionBtn').disabled=index===0;
   if(btn.dataset.validated!=='true')document.querySelectorAll('#optionsArea button,#orderList button,#textAnswer').forEach(el=>el.disabled=false);
 }
}
function nextQuestion(){
 if(state.currentQuestionIndex>=state.stopSession.frontier)return;
 state.currentQuestionIndex++;
 if(state.currentQuestionIndex>=state.currentStop.questions.length)finishStop();else renderQuestion();
}
function reviewStopQuestions(){state.currentQuestionIndex=state.currentStop.questions.length-1;renderQuestion();}

function finishStop(){
  stopQuizTimer();
  const total=state.currentStop.questions.length,r=state.serverResult;
  const correct=r.correct_first,wrong=r.wrong,score=Math.round(correct/(r.graded_total||total)*100),reward=r.reward;
  refreshEconomy();state.completed=r.completed;saveProgress();
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
            <div class="big-title">${reward.passed?"Harika!":"Biraz daha çalışalım"}</div>
            <div class="mascot-speech">${correct} soruyu ilk denemede doğru cevapladın. Yazma görevleri otomatik puanlanmaz. ${reward.passed?"":"Geçmek için puanlanan sorularda en az %60 başarı gerekli."}</div><div class="reward-summary">✨ +${reward.xp} XP &nbsp; 🪙 +${reward.gold} Altın ${reward.repeat?"(Tekrar ödülü yok)":""}</div>
          </div>
          <div>
            <div class="result-stats">
              <div class="result-box"><strong>${score}/100</strong><span>Puanın</span></div>
              <div class="result-box"><strong>${correct}</strong><span>Doğru</span></div>
              <div class="result-box"><strong>${wrong}</strong><span>Yanlış</span></div>
              <div class="result-box"><strong>${state.currentStop.id}</strong><span>Durak</span></div>
            </div>
            <div class="result-actions">
              <button class="nav-btn nav-blue" onclick="reviewStopQuestions()">Soruları İncele</button><button class="nav-btn nav-blue" onclick="restartStop(${state.currentStop.id})">Tekrar Oyna</button>
              <button class="nav-btn nav-orange" onclick="${reward.passed?`goNextStop(${state.currentStop.id})`:`restartStop(${state.currentStop.id})`}">${reward.passed?"Sonraki Durağa Geç →":"Tekrar Çalış →"}</button>
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

async function openGame(gameId){
  const game = games.find(g=>g.id===gameId);
  if(!game)return;
  try{await window.turkceMember.ready;const run=await window.turkceMember.request('start',{mode:'game',activity_id:gameId});
  state.game={game,index:run.index,serverAttempt:run,startedAt:Date.now()};}catch(e){showMapMessage(e.message);return;}
  refreshEconomy();
  renderGameQuestion();
}
function renderGameQuestion(){
  const {game, index} = state.game;
  state.game.questionMistakes=0;
  const q = game.questions[index];
  const gameKind=game.id==='olay-treni'?'train':game.id==='noktalama-tamircisi'?'tools':'detective';
  const nodes = game.questions.map((_,i)=>`<div class="pnode ${i<index?'done':''} ${i===index?'active':''}">${i+1}</div>`).join('');
  let body='';
  if(q.ordering){
    currentOrderState=q.ordering.map((t,i)=>({text:t, original:i}));
    body=`<div class="order-list" id="orderList"></div>`;
  } else {
    body=`<div class="options" id="optionsArea">${q.choices.map((c,i)=>`<button class="option" data-index="${i}"><b>${String.fromCharCode(65+i)}</b><span>${c}</span></button>`).join('')}</div>`;
  }
  openModal(`
    <div class="modal-card sg-modal sg-${gameKind}"><div class="modal-inner quiz-layout">
      <div class="quiz-top"><div class="crumbs"><button class="back-btn" onclick="showView('gamesView');closeModal()">←</button><span class="crumb-pill">${game.title}</span></div><div class="progress-nodes">${nodes}</div><div class="timer"><div class="timer-pill">⏱ <span id="elapsedClock">00:00</span></div><div class="timer-pill">${index+1}/${game.questions.length}</div></div></div>
      <div class="sg-adventure"><div class="sg-track" aria-label="Oyun ilerlemesi">${game.questions.map((_,i)=>`<span class="${i<index?'sg-completed':i===index?'sg-current':''}">${gameKind==='train'?'▰':gameKind==='tools'?['.',',','?','!','…'][i%5]:'◆'}</span>`).join('')}</div><strong>${gameKind==='train'?'Vagonları sırala, hikâyeyi yoluna koy!':gameKind==='tools'?'Doğru aracı seç, cümleyi onar!':'İpuçlarını birleştir, anlamı keşfet!'}</strong><span class="sg-combo" id="sgCombo">${state.game.combo||0} doğru seri</span></div>
      <div class="quiz-card"><div class="q-card-left"><h3>${game.title}</h3><div class="question-title">${q.prompt || 'Vagonları yukarı ve aşağı taşıyarak olay sırasını kur.'}</div>${gameKind==='tools'?'<div class="sg-live-preview" aria-live="polite">Cümleyi tamamlayacak aracı seç.</div>':''}${body}<div class="q-actions"><div class="feedback-box" id="feedbackBox">Hazırsan cevapla.</div><button class="nav-btn nav-green" id="gameBtn">Kontrol Et</button></div></div><aside class="q-side"><div class="sg-scene sg-scene-${gameKind}" role="img" aria-label="${game.title} oyun sahnesi"></div><div class="mascot-mini"><h4>Papi’nin ipucu</h4><div class="mascot-speech">${gameKind==='train'?'Önce ne olmuş? Her vagonu doğru yerine taşı.':gameKind==='tools'?'Cümle soru mu soruyor, duygu mu anlatıyor? Seçmeden önce düşün.':'Sözcüğün cümledeki anlamını düşün, sonra doğru ipucunu seç.'}</div></div></aside></div>
    </div></div>
  `);
  if(q.ordering) redrawOrder();
  startQuizTimer(state.game.startedAt);
  document.querySelectorAll('.option').forEach(btn=>btn.addEventListener('click', ()=>{ document.querySelectorAll('.option').forEach(b=>b.classList.remove('selected')); btn.classList.add('selected');const preview=document.querySelector('.sg-live-preview');if(preview)preview.textContent='Seçtiğin araç: '+q.choices[Number(btn.dataset.index)]; }));
  document.getElementById('gameBtn').addEventListener('click', ()=>checkGameQuestion());
}
async function checkGameQuestion(){
 const btn=document.getElementById('gameBtn');if(!btn||btn.disabled||btn.dataset.validated==='true')return;
 const {game,index}=state.game,q=game.questions[index],fb=document.getElementById('feedbackBox');let answer;
 if(q.ordering)answer=currentOrderState.map(x=>x.original);else{const selected=document.querySelector('.option.selected');if(!selected){fb.textContent='Önce bir cevap seç.';return;}answer=Number(selected.dataset.index);}
 btn.disabled=true;try{const r=await window.turkceMember.request('answer',{attempt_id:state.game.serverAttempt.attempt_id,index,answer});state.game.serverResult=r;
 state.game.combo=r.correct?(state.game.combo||0)+1:0;const combo=document.getElementById('sgCombo');if(combo)combo.textContent=state.game.combo+' doğru seri';const scene=document.querySelector('.sg-modal');if(scene){scene.classList.remove('sg-success','sg-miss');void scene.offsetWidth;scene.classList.add(r.correct?'sg-success':'sg-miss');}if(q.choices)markOptionsAfterCheck(q.answer,r.correct,r.advanced);showAnswerFeedback(r.correct,fb,'Doğru cevap!',r.advanced?'Üç deneme tamamlandı. Sonraki soruya geç.':'Yeniden dene.');
 if(r.advanced){btn.dataset.validated='true';btn.textContent=r.done?'Sonuç Ekranı →':'Sonraki Soru →';btn.onclick=()=>{state.game.index=r.index;if(r.done)finishGame();else renderGameQuestion();};}
 }catch(e){fb.textContent=e.message;}finally{btn.disabled=false;}
}

function finishGame(){
  stopQuizTimer();
  const total = state.game.game.questions.length;
  const r=state.game.serverResult,correct=r.correct_first,score=Math.round(correct/(r.graded_total||total)*100),reward=r.reward;
  refreshEconomy();
  openModal(`
    <div class="modal-card"><div class="modal-inner result-wrap"><div class="result-banner"><div><div class="stars">🎮 ⭐ 🎮</div><div class="big-title">Oyun Bitti!</div><div class="mascot-speech">${state.game.game.title} oyununu tamamladın.</div><div class="reward-summary">✨ +${reward.xp} XP &nbsp; 🪙 +${reward.gold} Altın ${reward.repeat?"(Bugünkü tekrar için ödül yok)":""}</div><div class="league-preview-note">🏆 Arkadaşlar sekmesinden liglere katılabilirsin. ${reward.passed?"":"Ödül için en az %60 başarı gerekli."}</div></div><div><div class="result-stats"><div class="result-box"><strong>${score}/100</strong><span>Puanın</span></div><div class="result-box"><strong>${correct}</strong><span>Doğru</span></div><div class="result-box"><strong>${total-correct}</strong><span>Yanlış</span></div><div class="result-box"><strong>${total}</strong><span>Soru</span></div></div><div class="result-actions"><button class="nav-btn nav-blue" onclick="openGame('${state.game.game.id}')">Tekrar Oyna</button><button class="nav-btn nav-orange" onclick="closeModal()">Oyunlara Dön</button></div></div></div></div></div>
  `)
}

function setGameCategory(category){
  const solo=category==='solo';
  document.getElementById('soloGames').hidden=!solo;
  document.getElementById('duelGames').hidden=solo;
  for(const button of document.querySelectorAll('[data-game-category]')){
    const selected=button.dataset.gameCategory===category;
    button.setAttribute('aria-selected',String(selected));
    button.tabIndex=selected?0:-1;
  }
}
function renderGames(){
  const grid=document.getElementById('gameGrid');
  grid.classList.remove('modern-game-grid');grid.classList.add('games-browser');
  grid.innerHTML=`<div class="game-category-tabs" role="tablist" aria-label="Oyun türü"><button type="button" role="tab" id="soloTab" data-game-category="solo" aria-selected="true" aria-controls="soloGames" onclick="setGameCategory('solo')">Tek Kişilik</button><button type="button" role="tab" id="duelTab" data-game-category="duel" aria-selected="false" aria-controls="duelGames" tabindex="-1" onclick="setGameCategory('duel')">İki Kişilik</button></div><div id="soloGames" class="modern-game-grid" role="tabpanel" aria-labelledby="soloTab">${games.map((g,i)=>`<article class="modern-game-card game-tone-${i}"><div class="game-illustration game-art-${i}" role="img" aria-label="${g.title} oyun çizimi"></div><div class="game-details"><h2>${g.title}</h2><p>${g.description}</p><div class="game-card-actions"><span class="game-energy"><svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="m13 1-10 13h8l-1 9L22 9h-9l2-8z"/></svg>3 Enerji</span><button class="modern-play" onclick="openGame('${g.id}')" aria-label="${g.title} — Oyuna Başla"><svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 2v20l17-10z"/></svg><span>Oyuna Başla</span></button></div></div></article>`).join('')}</div><div id="duelGames" class="modern-game-grid" role="tabpanel" aria-labelledby="duelTab" hidden></div>`;
  grid.querySelector('[role=tablist]').addEventListener('keydown',event=>{
    if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;
    event.preventDefault();const current=document.querySelector('[data-game-category][aria-selected=true]').dataset.gameCategory;
    const next=event.key==='Home'?'solo':event.key==='End'?'duel':current==='solo'?'duel':'solo';
    setGameCategory(next);document.querySelector(`[data-game-category="${next}"]`).focus();
  });
}
window.setGameCategory=setGameCategory;

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
refreshEconomy();
window.addEventListener("focus",refreshEconomy);
document.addEventListener("visibilitychange",()=>{if(!document.hidden)refreshEconomy()});
setInterval(()=>{if(!document.hidden)refreshEconomy()},30000);
renderMap();
renderGames();
function applyMemberState(data){state.completed=data?.completed||[];refreshEconomy();renderMap();const link=document.getElementById('accountLink');if(link){link.textContent=data?.profile?'Hesabım':'Giriş';link.setAttribute('aria-label',link.textContent);link.title=data?.profile?.full_name||link.textContent;}}
window.addEventListener('member-state',event=>applyMemberState(event.detail));
window.turkceMember.ready.then(()=>{applyMemberState(window.turkceMember.data);if(window.turkceMember.error)showMapMessage(window.turkceMember.error);});
