(()=>{'use strict';
const root=document.getElementById('memberStudy');if(!root)return;
const E=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const member=window.turkceMember;let bank,theme=1,lesson=null,stage='list',run=null,result=null,statuses=[],serial=0,busy=false;
const call=(op,p={})=>member.featuresRequest(op,p);
function control(label,action,secondary=false){return `<button type="button" data-study="${action}" class="${secondary?'secondary':''}">${label}</button>`;}
function controls(primary,action,back='list'){return `<div class="study-controls">${control('← '+(back==='list'?'Konular':'Geri'),back,true)}${control(primary,action)}</div>`;}
async function open(){const token=++serial;root.innerHTML='<p role="status">Derslerin hazırlanıyor…</p>';try{await member.ready;if(!bank){const r=await fetch('content/turkce/study-5.json?v=learning-hub-1');if(!r.ok)throw Error('Dersler yüklenemedi.');bank=await r.json();}const s=await call('study_status');if(token!==serial)return;statuses=s.lessons||[];stage='list';render();}catch(e){if(token===serial)root.innerHTML=`<p role="alert">${E(e.message)}</p>${control('Yeniden dene','reload')}`;}}
function render(){busy=false;if(stage==='list'){
 const selected=bank.themes.find(t=>t.number===theme);root.innerHTML=`<header class="study-heading"><h1>📖 Ders Çalış</h1><p>5. sınıf · Kısa anlatım → örnekler → 8 soruluk test</p><label><span class="sr-only">Tema seç</span><select id="studyTheme">${bank.themes.map(t=>`<option value="${t.number}" ${theme===t.number?'selected':''}>${t.number}. Tema · ${E(t.title)}</option>`).join('')}</select></label></header><div class="study-grid">${selected.lessons.map(l=>{const done=statuses.find(x=>x.lesson_id===l.id);return `<button type="button" class="study-lesson" data-study="lesson" data-lesson="${E(l.id)}"><small>${done?`✓ En iyi sonuç: %${done.score}`:'Yeni keşif'}</small><strong>${E(l.title)}</strong><span>Anlatımı aç →</span></button>`;}).join('')}</div><div class="study-level-note">İlk başarılı konu testinde en fazla 160 XP ve 60 altın. Anlatımı ve örnekleri ücretsiz incele.</div>`;return;}
 const top=`<header class="study-heading"><p>${E(lesson.title)}</p></header>`;
 if(stage==='read')root.innerHTML=top+`<div class="study-progress"><span style="width:33%"></span></div><article class="study-content"><h2>Konuyu keşfet</h2><p>${E(lesson.summary)}</p></article>`+controls('Örnekleri incele →','examples');
 if(stage==='examples')root.innerHTML=top+`<div class="study-progress"><span style="width:66%"></span></div><article class="study-content"><h2>Örneklerle pekiştir</h2><ul>${lesson.examples.map(x=>`<li>${E(x)}</li>`).join('')}</ul></article>`+controls('8 soruluk teste başla →','start','read');
 if(stage==='quiz'){
 const q=run.questions[run.index];root.innerHTML=top+`<div class="study-progress"><span style="width:${run.index/run.questions.length*100}%"></span></div><article class="study-content"><p>Soru ${run.index+1} / ${run.questions.length}</p><h2>${E(q.prompt)}</h2><div class="study-options">${q.choices.map((c,i)=>`<button type="button" data-study="answer" data-choice="${i}" ${result?'disabled':''} class="${result?c===result.answer?'correct':c===run.chosen?'wrong':'':''}">${E(c)}</button>`).join('')}</div><div class="study-feedback" role="status" aria-live="polite">${result?`${result.correct?'✓ Doğru!':'Birlikte öğrenelim.'} ${E(result.explanation)}`:'Doğru cevabı seç.'}</div></article><div class="study-controls">${control('← Konular','list',true)}${result?control(result.done?'Sonucu gör →':'Sonraki soru →','next'):''}</div>`;
 }
 if(stage==='result'){
 const percent=Math.round(result.correct_count/result.total*100);root.innerHTML=top+`<article class="study-content"><h2>Test tamamlandı!</h2><div class="study-score">%${percent}</div><p>${result.correct_count} doğru / ${result.total} soru</p><p>${percent>=60?'Konuyu başarıyla tamamladın!':'Anlatımı ve örnekleri inceleyip yeniden deneyebilirsin.'}</p><p>✨ +${result.reward.xp} XP · 🪙 +${result.reward.gold} altın</p><small>Her konunun ilk başarılı testi ödül kazandırır. Başarı için en az %60 gerekir.</small></article>`+controls('Tekrar çalış','read');
 }
 const heading=root.querySelector('h2');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}
}
root.addEventListener('change',e=>{if(e.target.id==='studyTheme'){theme=Number(e.target.value);render();}});
root.addEventListener('click',async e=>{const b=e.target.closest('[data-study]');if(!b||b.disabled||busy)return;const action=b.dataset.study;
 if(action==='reload')return open();
 if(action==='lesson'){lesson=bank.themes.flatMap(t=>t.lessons).find(l=>l.id===b.dataset.lesson);stage='read';return render();}
 if(['list','read','examples'].includes(action)){stage=action;return render();}
 if(action==='start'){busy=true;b.disabled=true;try{run=await call('study_start',{lesson_id:lesson.id});result=null;stage='quiz';render();}catch(error){busy=false;b.disabled=false;showError(error);}return;}
 if(action==='answer'){busy=true;root.querySelectorAll('[data-study=answer]').forEach(x=>x.disabled=true);run.chosen=run.questions[run.index].choices[Number(b.dataset.choice)];try{result=await call('study_answer',{attempt_id:run.attempt_id,index:run.index,answer:run.chosen});render();}catch(error){busy=false;root.querySelectorAll('[data-study=answer]').forEach(x=>x.disabled=false);showError(error);}return;}
 if(action==='next'){if(result.done){stage='result';const old=statuses.find(x=>x.lesson_id===lesson.id),score=Math.round(result.correct_count/result.total*100);if(old)old.score=Math.max(old.score,score);else statuses.push({lesson_id:lesson.id,score});}else{run.index=result.index;result=null;}render();}
});
function showError(error){let note=root.querySelector('.study-feedback');if(!note){note=document.createElement('p');note.className='study-feedback';note.setAttribute('role','alert');root.append(note);}note.textContent=error.message;}
document.querySelector('[data-view=studyView]')?.addEventListener('click',()=>open());
window.addEventListener('member-state',e=>{if(!e.detail){serial++;bank=null;run=null;statuses=[];root.replaceChildren();}});
})();
