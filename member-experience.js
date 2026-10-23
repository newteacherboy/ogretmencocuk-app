/* Dismissible member tools. Account-bound queues; no automatic lesson launches. */
(()=>{'use strict';
/* Streak messages: a shield that saved the streak, or a gentle restart that keeps the best run visible. Once per day per student. */
function streakNotice(d,owner){try{const today=new Date(Date.now()+10800000).toISOString().slice(0,10),key='dm_streak_notice:'+String(owner).toLowerCase();if(localStorage.getItem(key)===today)return;
 const saved=Array.isArray(d.streakSaved)?d.streakSaved:[];let text='';
 if(saved.length){const free=saved.some(x=>x.source==='free'),paid=saved.some(x=>x.source==='paid');text='🧊 '+(free&&!paid?'Haftalık ücretsiz kalkanın':paid&&!free?'Seri kalkanın':'Kalkanların')+' '+d.loginStreak+' günlük serini korudu!';}
 else if(d.loginStreak===1&&Number(d.maxLoginStreak)>=3)text='🔥 En uzun serin '+d.maxLoginStreak+' gün. Bugün yeniden başlıyoruz, Papi seninle!';
 if(!text)return;localStorage.setItem(key,today);setTimeout(()=>window.yoToast?.(text),2500);}catch{}}
if(typeof document!=='undefined'&&!document.getElementById('dm-route-feedback-profile-style')){const link=document.createElement('link');link.id='dm-route-feedback-profile-style';link.rel='stylesheet';link.href='route-feedback-profile.css?v=20261015-member-fixes-2';document.head.append(link);}
const $=id=>document.getElementById(id),Y=()=>typeof yo!=='undefined'?yo:null;
const who=()=>typeof aktifOgrenciAdi==='undefined'?'':String(aktifOgrenciAdi||'');
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const ready=()=>!!who()&&who().toLowerCase()!=='teacher'&&!window.dmGuestMode&&!!Y()&&(!window.yoHazirMi||window.yoHazirMi())&&$('panel-alani')?.style.display==='block';
let welcomeTimer=null,welcomeOwner='';
let gamesEmailShown=false,emailNextAt=0,emailGamesVisited=false,emailPromptBusy=false;
let noticePolicyBusy=false,noticePolicyReadAt=0;
async function loadNoticePolicies(){if(!ready()||noticePolicyBusy||Date.now()-noticePolicyReadAt<60000)return;noticePolicyBusy=true;noticePolicyReadAt=Date.now();const owner=who();try{const d=await api('communicationNoticePolicy');if(owner!==who())return;window.dmCommunicationNoticeRules=Object.fromEntries((d.rules||[]).map(r=>[r.key,r]));document.dispatchEvent(new Event('dm:notice-policies'));}catch(e){console.warn('[Duyuru kuralları]',e.message);}finally{noticePolicyBusy=false;}}
let actor='',status=null,busy=false,lastRead=0,started=Date.now(),examAt=Date.now()+120000+Math.random()*480000,dismissedRoute=false,refreshPending=false;
async function api(islem,data={}){const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),12000);try{const r=await fetch(apiURL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({islem,t:localStorage.getItem('ing_token')||'',...data}),signal:controller.signal});const d=await r.json();if(!r.ok||d.ok===false)throw Error(d.mesaj||d.message||'İşlem tamamlanamadı.');return d;}finally{clearTimeout(timeout);}}
function sheet(title,content,id='dmMemberDialog'){
 const parent=window.dmViewHistory?.capture();$(id)?.remove();const before=document.activeElement,el=document.createElement('div');el.id=id;el.className='dm-member-overlay';
 el.innerHTML='<section class="dm-member-sheet" role="dialog" aria-modal="true" aria-labelledby="'+id+'Title"><button type="button" class="dm-member-close" aria-label="Kapat">×</button><h2 id="'+id+'Title">'+esc(title)+'</h2><div class="dm-member-body">'+content+'</div></section>';
 const close=()=>{if(!el.isConnected)return;el.dispatchEvent(new Event('dm:sheet-close'));if(id==='dmPlacementExam')window.speechSynthesis?.cancel();el.remove();const returned=window.dmViewHistory?.leave(el);if(!returned)before?.focus?.({preventScroll:true});};const dismiss=()=>{close();window.dmProfileDismiss?.();};el.onclick=e=>{if(e.target===el||e.target.closest('.dm-member-close'))dismiss();};
 el.onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();e.stopPropagation();dismiss();}if(e.key==='Tab'){const list=[...el.querySelectorAll('button,input,textarea,a')].filter(x=>!x.disabled&&!x.hidden),i=list.indexOf(document.activeElement);e.preventDefault();list[(i+(e.shiftKey?-1:1)+list.length)%list.length]?.focus();}};
 document.body.append(el);window.dmViewHistory?.track(el,{parent,close:()=>el.querySelector('.dm-member-close')?.click()});el.querySelector('.dm-member-close').focus();return {el,body:el.querySelector('.dm-member-body'),close};
}
const chosen=()=>true;
function chooseRoute(){return window.dmTurkce?.open('route');}
function autoRoute(){}
function banner(){
 if(!status||status.emailVerified||!ready()){$('dmEmailVerifyBanner')?.remove();if(status?.emailVerified){$('dmEmailVerification')?.querySelector('.dm-member-close')?.click();window.dmEmailGuide?.close();}return;}
 let el=$('dmEmailVerifyBanner');if(!el){
  el=document.createElement('aside');el.id='dmEmailVerifyBanner';el.className='dm-email-banner';
  el.setAttribute('aria-label','E-posta doğrulama yardımı');$('panel-alani').prepend(el);
  el.innerHTML='<img src="papi-welcome-v2.png" alt=""><div class="deg-banner-text"><strong>📨 E-postanı henüz doğrulamadın</strong><small>Gmail veya Outlook’ta mesajını bulmak için Papi sana gösterecek.</small></div><div class="deg-banner-actions"><button type="button" data-eg-quick-help>📖 Nasıl yapılır?</button><button type="button" data-eg-quick-resend>↻ Tekrar gönder</button></div>';
  el.querySelector('[data-eg-quick-help]').onclick=()=>emailPrompt();
  el.querySelector('[data-eg-quick-resend]').onclick=()=>{if(window.dmEmailGuide){window.dmEmailGuide.open('reminder');window.dmEmailGuide.resend();}else emailPrompt();};
 }
}
function emailPrompt(){
 if(!ready()||status?.emailVerified)return;
 emailNextAt=Date.now()+600000;
 gamesEmailShown=true;
 if(window.dmEmailGuide){window.dmEmailGuide.open('reminder');return;}const owner=who(),view=sheet('E-posta adresini doğrula','<p>Hesabını kullanmaya devam edebilirsin. Doğrulama bağlantısı kayıtlı veli e-posta adresine gönderilir.</p><p><b>'+esc(status?.email||'Kişisel bilgilerindeki e-posta adresi')+'</b></p><button type="button" class="dm-member-primary" data-resend>Doğrulama e-postasını gönder</button><button type="button" data-checked>E-postadan doğruladım, kontrol et</button><p class="dm-member-status" role="status"></p>','dmEmailVerification');
 view.el.querySelector('[data-resend]').onclick=async e=>{e.target.disabled=true;try{const d=await api('memberEmailResend');if(owner!==who())return view.close();view.body.querySelector('[role=status]').textContent=d.mesaj;if(d.verified){status.emailVerified=true;banner();view.close();}}catch(err){view.body.querySelector('[role=status]').textContent=err.message;}finally{e.target.disabled=false;}};
 view.el.querySelector('[data-checked]').onclick=async()=>{try{const d=await api('memberStatus');if(owner!==who())return view.close();status=d;if(Number.isInteger(d.loginStreak)){localStorage.setItem('ing_girisSerisiSayisi',String(d.loginStreak));localStorage.setItem('dm_login_streak:'+owner.toLowerCase(),String(d.loginStreak));const streak=$('headerStreakNum');if(streak)streak.textContent='🔥 '+d.loginStreak;}streakNotice(d,owner);window.dmMemberBadgeStatus={...d,owner};if(d.welcomeEligible&&!d.welcomeEarned&&welcomeOwner!==owner){clearTimeout(welcomeTimer);welcomeOwner=owner;const delay=Math.max(1000,120000-(Date.parse(d.serverNow)-Date.parse(d.memberFirstSeenAt)));welcomeTimer=setTimeout(()=>{if(who()===owner)check(true,true);},delay);}document.dispatchEvent(new Event('dm:member-status'));lastRead=Date.now();banner();if(d.emailVerified)view.close();else view.body.querySelector('[role=status]').textContent='Henüz doğrulanmadı. E-postadaki bağlantıya dokunup tekrar kontrol et.';}catch(e){view.body.querySelector('[role=status]').textContent=e.message;}};
}
async function check(force=false,quiet=false){
 if(!ready()||document.hidden||navigator.onLine===false)return;if(busy){if(force)refreshPending=true;return;}
 if(actor!==who()){actor=who();status=null;lastRead=0;started=Date.now();examAt=started+120000+Math.random()*480000;dismissedRoute=false;}
 const owner=actor;busy=true;
 try{
  if(force||!status||Date.now()-lastRead>120000){const d=await api('memberStatus');if(owner!==who())return;status=d;if(Number.isInteger(d.loginStreak)){localStorage.setItem('ing_girisSerisiSayisi',String(d.loginStreak));localStorage.setItem('dm_login_streak:'+owner.toLowerCase(),String(d.loginStreak));const streak=$('headerStreakNum');if(streak)streak.textContent='🔥 '+d.loginStreak;}streakNotice(d,owner);window.dmMemberBadgeStatus={...d,owner};if(d.welcomeEligible&&!d.welcomeEarned&&welcomeOwner!==owner){clearTimeout(welcomeTimer);welcomeOwner=owner;const delay=Math.max(1000,120000-(Date.parse(d.serverNow)-Date.parse(d.memberFirstSeenAt)));welcomeTimer=setTimeout(()=>{if(who()===owner)check(true,true);},delay);}document.dispatchEvent(new Event('dm:member-status'));lastRead=Date.now();banner();}if(quiet)return;
  if(!chosen())autoRoute(); // never force the route sheet at login; class students get Macera Haritası silently
  if(window.dmPapiNotices?.blocked()||document.querySelector('#dmRouteChoice,#dmPlacementExam,#dmStartPlacement,#dmStartingChoice,#dmEmailVerification,#dmPlacementInvite'))return;
  // Email verification is triggered by the Games tab; repeats only on safe screens after 10 minutes.

 }catch(e){console.warn('[Üye araçları]',e.message);}finally{busy=false;if(refreshPending){refreshPending=false;check(true,true);}}
}
let pendingOwner='',pending=new Map(),flushTimer=null,flushing=false;
function queueKey(owner){return 'dm_wrong_word_pending:'+owner.toLowerCase();}
function persist(){if(pendingOwner)try{localStorage.setItem(queueKey(pendingOwner),JSON.stringify([...pending.values()]));}catch{}}
function restore(){if(pendingOwner===who())return;persist();pendingOwner=who();pending=new Map();try{for(const w of JSON.parse(localStorage.getItem(queueKey(pendingOwner))||'[]'))pending.set(w.en.toLowerCase(),w);}catch{}}
function add(word){
 if(!ready()||!word||typeof siniftaOynananOgrenci!=='undefined'&&siniftaOynananOgrenci)return;
 const en=String(word.en||word.ingilizce||'').trim(),tr=String(word.tr||word.turkce||'').trim();if(!en||!tr)return;
 restore();pending.set(en.toLowerCase(),{en,tr,source:word.source||'etkinlik'});persist();clearTimeout(flushTimer);flushTimer=setTimeout(flush,1500);
}
async function flush(){
 if(!ready()||flushing||navigator.onLine===false)return;restore();if(!pending.size)return;flushing=true;const owner=pendingOwner,batch=[...pending.values()].slice(0,100);
 try{await api('wordReviewAdd',{words:batch});if(owner===who()&&owner===pendingOwner){for(const w of batch)if(pending.get(w.en.toLowerCase())===w)pending.delete(w.en.toLowerCase());persist();}}catch(e){console.warn('[Kelime kaydı]',e.message);}finally{flushing=false;if(pending.size&&owner===who())flushTimer=setTimeout(flush,30000);}
}
async function review(settings={}){
 if(!ready())return;const owner=who(),v=sheet('Hatırlama Zamanı','<p>Yanlış cevapladığın kelimeler yükleniyor…</p>','dmWordReview');
 let timer=null;const began=Date.now();let i=0,known=0,wrongCount=0,answered=false;
 const elapsed=()=>{const seconds=Math.floor((Date.now()-began)/1000);return Math.floor(seconds/60)+':'+String(seconds%60).padStart(2,'0');};
 const stop=()=>{clearInterval(timer);timer=null;};v.el.addEventListener('dm:sheet-close',stop,{once:true});
 try{while(flushing&&v.el.isConnected)await new Promise(r=>setTimeout(r,100));if(!v.el.isConnected)return;await flush();const legacy=Object.values(Y()?.zk||{});if(legacy.length)await api('wordReviewAdd',{words:legacy,legacy:true});const d=await api('wordReviewList');if(owner!==who()||!v.el.isConnected)return;const words=(d.words||[]).slice(0,settings.limit||20);
  const hud=()=>'<div class="dm-review-hud"><span>✓ <b>'+known+'</b> Doğru</span><span>✕ <b>'+wrongCount+'</b> Yanlış</span><span>⏱ <b data-review-time>'+elapsed()+'</b></span></div>';
  function show(){
   if(!v.el.isConnected)return;if(i>=words.length){stop();v.body.innerHTML='<div class="dm-review-result"><span>🌟</span><h3>Tekrar tamamlandı!</h3>'+hud()+'<p>'+known+' doğru cevap verdin. Kelimeler sonraki günlerde yeniden gelecek.</p><button type="button" class="dm-member-primary" data-review-done>Çalışmaya dön</button></div>';v.el.querySelector('[data-review-done]').onclick=()=>{v.close();settings.onComplete?.();document.dispatchEvent(new Event('dm:review-completed'));};return;}
   answered=false;const w=words[i];const candidates=[...words,...(window.masterKelimeHavuzu||[])].map(x=>({en:String(x.en||x.ingilizce||''),tr:String(x.tr||x.turkce||'')})).filter(x=>x.en&&x.en.toLowerCase()!==w.en.toLowerCase()&&x.tr.toLowerCase()!==w.tr.toLowerCase());const wrong=candidates[Math.floor(Math.random()*candidates.length)]?.en||'I do not know';const options=Math.random()<.5?[w.en,wrong]:[wrong,w.en];
   v.body.innerHTML='<p class="lc-free-note">Enerji harcamadan tekrar et · Kelimeler farklı günlerde yeniden gelir.</p>'+hud()+'<div class="dm-review-progress"><small>Kelime '+(i+1)+' / '+words.length+'</small><progress value="'+i+'" max="'+words.length+'"></progress></div><div class="dm-review-question"><small>İNGİLİZCE KARŞILIĞINI SEÇ</small><h3>'+esc(w.tr)+'</h3></div><div class="dm-review-options">'+options.map(x=>'<button type="button" data-answer="'+esc(x)+'">'+esc(x)+'</button>').join('')+'</div><p class="dm-review-feedback" role="status" aria-live="polite"></p><button type="button" class="dm-member-primary" data-next hidden>Sonraki kelime →</button>';
   v.el.querySelectorAll('[data-answer]').forEach(b=>b.onclick=async()=>{
    if(answered)return;answered=true;v.el.querySelectorAll('[data-answer]').forEach(x=>x.disabled=true);
    try{const result=await api('wordReviewAnswer',{id:w.id,version:w.version,answer:b.dataset.answer});if(owner!==who())return v.close();if(!v.el.isConnected)return;
     const feedback=v.body.querySelector('[role=status]');feedback.classList.add(result.correct?'correct':'wrong');feedback.textContent=result.stale?'Bu kelimenin kaydı başka ekranda güncellendi.':result.correct?'✓ Doğru! '+w.en+' — '+w.tr+'. Sonraki tekrar: '+new Date(result.dueAt).toLocaleDateString('tr-TR'):'Birlikte hatırlayalım: '+result.answer+' — '+w.tr+'. Yarın yeniden deneyelim.';
     v.el.querySelectorAll('[data-answer]').forEach(x=>{if(x.dataset.answer.toLocaleLowerCase('en')===String(result.answer||w.en).toLocaleLowerCase('en')){x.classList.add('dm-answer-correct');x.textContent='✓ '+x.textContent;}else if(x===b&&!result.correct){x.classList.add('dm-answer-wrong');x.textContent='✕ '+x.textContent;}});
     if(result.correct&&!result.stale){known++;if(Y()?.zk){delete Y().zk[w.en.toLowerCase()];window.yoKaydet?.();}}else if(!result.stale)wrongCount++;
     v.body.querySelector('.dm-review-hud').outerHTML=hud();v.el.querySelector('[data-next]').hidden=false;
    }catch(e){if(!v.el.isConnected)return;answered=false;v.body.querySelector('[role=status]').textContent=e.message;v.el.querySelectorAll('[data-answer]').forEach(x=>x.disabled=false);}
   });v.el.querySelector('[data-next]').onclick=()=>{i++;show();};
  }
  if(!words.length)v.body.innerHTML='<div class="dm-review-result"><span>🦜</span><h3>Bugünkü tekrarların tamam!</h3><p>Yeni bir kelimede zorlandığında veya tekrar zamanı geldiğinde burada görünecek.</p></div>';else{show();timer=setInterval(()=>{if(!v.el.isConnected||owner!==who()){stop();return;}const clock=v.el.querySelector('[data-review-time]');if(clock)clock.textContent=elapsed();},1000);}
 }catch(e){stop();if(v.el.isConnected)v.body.textContent=e.message;}
}


// Short feedback tones, generated locally; no external audio files or permissions.
window.dmAnswerFeedback=playPlacementFeedback;
function playPlacementFeedback(correct){
 try{
  if(window.dmSoundEnabled===false||window.dmSesAcik===false||localStorage.getItem('dm_sound_muted')==='1')return;
  const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;
  const ctx=new Audio();ctx.resume?.().catch(()=>{});const now=ctx.currentTime;
  const notes=correct?[660,880]:[330,220];
  notes.forEach((hz,i)=>{const oscillator=ctx.createOscillator(),gain=ctx.createGain(),at=now+i*.115;oscillator.type=correct?'sine':'triangle';oscillator.frequency.setValueAtTime(hz,at);gain.gain.setValueAtTime(.0001,at);gain.gain.exponentialRampToValueAtTime(.075,at+.015);gain.gain.exponentialRampToValueAtTime(.0001,at+.105);oscillator.connect(gain);gain.connect(ctx.destination);oscillator.start(at);oscillator.stop(at+.11);});
  setTimeout(()=>ctx.close().catch(()=>{}),500);
 }catch(e){console.warn('Seviye testi sesi kullanılamadı:',e.message);}
}

function showPlacementResult(v,result,listenAvailable=true){
 const level=String(result.level||'A1 altı / başlangıç'),high=['B1','B2'].includes(level),badge=/^(A1|A2|B1|B2)$/.test(level)?level:'Başlangıç';
 const title=high?'Tebrikler, güçlü bir başlangıç!':'İngilizce yolculuğun şimdi başlıyor!';
 const message=high?'Bu seviyeye gelmek emek ister! Şimdi Papi ile yeni kelimeler öğren, daha zorlu oyunlarda kendini göster.':'Her gün birkaç dakika, yeni bir kelime, küçük bir başarı. Papi ile başla; ilerledikçe neler yapabildiğini göreceksin!';
 v.el.classList.add('dm-placement-celebration');
 v.body.innerHTML='<div class="dm-placement-result dm-placement-reveal"><div class="dm-placement-stars" aria-hidden="true">✦ ✧ ✦</div><img class="dm-placement-papi" src="papi-reward-v2.png" alt="Seni tebrik eden Papi"><small>DİL SEVİYENİ KEŞFETTİN</small><div class="dm-placement-level" aria-label="Yaklaşık seviyen '+esc(level)+'">'+esc(badge)+'</div><h3>'+title+'</h3><p>'+message+'</p></div><div class="dm-placement-metrics"><b>'+Number(result.correct||0)+' / '+Number(result.total||40)+' doğru</b>'+Object.entries(result.bySkill||{}).map(([key,score])=>'<span>'+esc({language:'Dil kullanımı',reading:'Okuma',listening:'Dinleme'}[key]||key)+' <strong>'+Number(score.correct||0)+' / '+Number(score.total||0)+'</strong></span>').join('')+'</div><p class="dm-placement-estimate">Yaklaşık CEFR ön değerlendirmesi; resmî seviye belgesi değildir. Yazma ve konuşma örneklerini öğretmenin ayrıca değerlendirir.</p>'+(!listenAvailable?'<p>Ses kullanılamadığı için dinleme sonucu kesin değildir.</p>':'')+'<div class="dm-placement-next"><button type="button" class="dm-member-primary" data-result-route>🗺️ Parkuruma devam et</button><button type="button" data-result-games>🎮 Oyunlarla pekiştir</button><button type="button" data-result-study>📚 Ders Çalış’a git</button></div>';
 const art='<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><defs><linearGradient id="l" x2="0" y2="1"><stop stop-color="#e7fff4"/><stop offset="1" stop-color="#a6eed3"/></linearGradient></defs><circle cx="300" cy="210" r="190" fill="url(#l)" stroke="#f3c454" stroke-width="12"/><text x="300" y="122" text-anchor="middle" font-family="system-ui,sans-serif" font-size="30" fill="#0f5d57">İNGİLİZCE SEVİYEM</text><text x="300" y="250" text-anchor="middle" font-family="system-ui,sans-serif" font-weight="900" font-size="'+(badge.length>3?56:116)+'" fill="#073f48">'+esc(badge)+'</text><text x="300" y="319" text-anchor="middle" font-family="system-ui,sans-serif" font-size="24" fill="#0f5d57">Yaklaşık CEFR sonucu</text></svg>';
 window.dmSharing?.attachAchievementActions(v.body,{kind:'placement',id:'cefr-'+badge,name:badge+' · İngilizce Seviyem',level:badge,svg:art,emoji:'🌟'});
 v.el.querySelector('[data-result-route]').onclick=()=>{v.close();if(chosen())window.dunyaAc?.();else chooseRoute(true);};v.el.querySelector('[data-result-games]').onclick=()=>{v.close();window.aktivitelerTamEkranAc?.();};v.el.querySelector('[data-result-study]').onclick=()=>{v.close();window.dersCalisTamEkranAc?.();};
}
function placement(){return window.dmTurkce?.open('route');}
window.dmMemberUI={sheet};window.dmMemberExperience={chooseRoute,check,emailPrompt};window.dmWrongWords={add,flush,review};
window.yoZkAc=review;window.dmDetailedPlacement=()=>placement(true);window.seviyeTestAc=placement;window.seviyeDavetGoster=()=>{};
window.aiModalAc=()=>window.dmTeacherChatOpen?.();
// Observe only small game responses; large account responses are never cloned here.
const transport=window.fetch;window.fetch=function(url,opt){let b;try{b=typeof opt?.body==='string'?JSON.parse(opt.body):null;}catch{}const requestOwner=who();const task=transport.apply(this,arguments);if(b&&['meteorCevap','kelimeCarkiCevap'].includes(b.islem))task.then(r=>r.clone().json()).then(d=>{if(requestOwner!==who()||!d.last||d.last.correct||d.mode!==1)return;const hit=(window.masterKelimeHavuzu||[]).find(w=>[w.en,w.ingilizce,w.tr,w.turkce].some(x=>String(x||'').toLowerCase()===String(d.last.word).toLowerCase()));if(hit)add(hit);else if(b.islem==='kelimeCarkiCevap')add({en:d.last.word,tr:d.last.answer});}).catch(()=>{});return task;};
function installScoreHook(){const score=window.OC;if(!score||score.yanlis?.dmReviewHook)return;const original=score.yanlis;const wrapper=function(){try{const key=score.aktif?.oyun;const word=key==='ky'&&typeof kySorularListesi!=='undefined'?kySorularListesi[kySoruIndex]:key==='jp'&&typeof jpAktifSoru!=='undefined'?jpAktifSoru:key==='yagmur'&&typeof yagmurAktifKelime!=='undefined'?yagmurAktifKelime:key==='asmaca'&&typeof asmacaKelimeler!=='undefined'?asmacaKelimeler[asmacaAktifIndex]:null;if(word)add(word);}catch{}return original.apply(this,arguments);};wrapper.dmReviewHook=true;score.yanlis=wrapper;}
setInterval(()=>{if(!ready())return;installScoreHook();if(!document.hidden){check();flush();if(!window.dmCommunicationNoticeRules)void loadNoticePolicies();}},30000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden){check(true,true);flush();}});window.addEventListener('online',()=>{check(true,true);flush();});
window.addEventListener('focus',()=>{if(!status?.emailVerified)check(true,true);});
window.addEventListener('pageshow',()=>{check(true,true);void loadNoticePolicies();});
window.addEventListener('storage',e=>{if(e.key==='dm_email_verified'){try{const mark=JSON.parse(e.newValue||'null');if(mark?.student===who())check(true,true);}catch{}}});
function emailSafe(){
 if(document.hidden||window.dmPapiNotices?.blocked())return false;
 const blockers='#dmRouteChoice,#dmPlacementExam,#dmStartPlacement,#dmStartingChoice,#dmEmailVerification,#dmPlacementInvite,#dmEmailGuide,.game-modal-overlay,.dc-fullscreen-overlay.active,.yo-modal.acik,#bzPerde,#mlThemeList,#genelSonucOverlay,#dmLeagueMomentum,.dm-teacher-child';
 return ![...document.querySelectorAll(blockers)].some(el=>{
   if(!el.isConnected||!el.getClientRects().length)return false;
   const style=getComputedStyle(el);
   return style.display!=='none'&&style.visibility!=='hidden'&&Number(style.opacity)!==0;
 });
}
async function tryEmail(fromGames=false){
 if(fromGames)emailGamesVisited=true;
 if(!emailGamesVisited||!ready()||emailPromptBusy||Date.now()<emailNextAt)return;
 if(window.dmCommunicationNoticeRules?.email_verification?.enabled===false)return;
 if(status?.emailVerified)return;
 if(!emailSafe())return;
 emailPromptBusy=true;const owner=who();
 try{if(!status||Date.now()-lastRead>120000)await check(true,true);if(owner!==who()||!status||status.emailVerified||!emailSafe())return;
   if(gamesEmailShown){const claim=await api('memberReminderClaim',{kind:'email'});if(owner!==who()||!claim.show)return;}
   emailPrompt();
 }catch(e){console.warn('[E-posta hatırlatması]',e.message);}finally{emailPromptBusy=false;}
}
document.addEventListener('click',e=>{if(e.target.closest('[data-ekran="tab-aktiviteler"]'))setTimeout(()=>void tryEmail(true),350);},true);
setInterval(()=>{if(emailGamesVisited&&Date.now()>=emailNextAt)void tryEmail();},20000);
document.addEventListener('dm:login',()=>{window.dmCommunicationNoticeRules=null;noticePolicyReadAt=0;void loadNoticePolicies();gamesEmailShown=false;emailGamesVisited=false;emailNextAt=0;clearTimeout(welcomeTimer);welcomeOwner='';actor='';status=null;window.dmMemberBadgeStatus=null;dismissedRoute=false;setTimeout(check,500);});
const oldLogout=window.cikisYap;window.cikisYap=function(){persist();clearTimeout(flushTimer);for(const id of ['dmRouteChoice','dmPapiTour','dmPapiFirstStart','dmWordReview','dmEmailVerification','dmEmailVerifyBanner','dmPlacementInvite','dmPlacementExam','dmStartPlacement','dmStartingChoice'])$(id)?.remove();document.body.classList.remove('dm-papi-preview','dm-papi-notices-paused');const result=oldLogout?.apply(this,arguments);Promise.resolve(result).then(()=>{if(!localStorage.getItem('ing_token')){$('panel-alani').style.display='none';$('login-container').style.display='block';document.querySelectorAll('.dc-fullscreen-overlay.active').forEach(x=>x.classList.remove('active'));}});return result;};
setTimeout(()=>{installScoreHook();check();},700);
})();

// Dismiss an old text field when a non-writing control is used; retain all real text inputs.
(()=>{const textField=e=>e instanceof HTMLElement&&(e.isContentEditable||e.matches('textarea:not([readonly]):not(:disabled),input:not([readonly]):not(:disabled):not([type=button]):not([type=submit]):not([type=reset]):not([type=checkbox]):not([type=radio]):not([type=range]):not([type=color]):not([type=file]):not([type=hidden]):not([type=date]):not([type=time]):not([type=number])'));
 document.addEventListener('pointerdown',e=>{const target=e.target instanceof Element?e.target:null;if(!target)return;const label=target.closest('label');if(textField(target)||textField(label?.control))return;const active=document.activeElement;if(textField(active))active.blur();},true);
 document.addEventListener('focusin',e=>{const t=e.target;if(t instanceof HTMLElement&&t.matches('input[readonly],textarea[readonly]')){t.setAttribute('inputmode','none');t.blur();}});
})();

/* The shared visual email guide is loaded once, defer, by index.html. */
