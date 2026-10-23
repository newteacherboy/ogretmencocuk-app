import VERSION from './turkce-bank.json' with {type:'json'};
import G5 from './turkce-bank-5.json' with {type:'json'};
import G6 from './turkce-bank-6.json' with {type:'json'};
import G7 from './turkce-bank-7.json' with {type:'json'};
import G8 from './turkce-bank-8.json' with {type:'json'};
const BANK={...VERSION,grades:[G5,G6,G7,G8]};
import {findActivity,markTurkish,validateWriting} from './turkce-core.mjs';
const retired=new Set(['placementSave','startPlacementSave','startPointChoose','startPlacementFollowup','teacherPlacementResults']);
export function turkceAPI({db,json,isDemo,inScope}:any){
 const fail=(mesaj:string,status=400)=>json({ok:false,mesaj},status);
 const checked=(r:any)=>{if(r.error)throw r.error;return r.data;};
 const task=(id:string)=>BANK.grades.flatMap(g=>g.themes.flatMap(t=>t.writing)).find(x=>x.id===id);
 return {async handle(op:string,b:any,a:any,method:string){
  if(!op.startsWith('turkce')&&!retired.has(op)&&op!=='studyPlacementInvite'&&!(op==='memberReminderClaim'&&b.kind==='placement'))return null;
  if(!a)return fail('Önce giriş yap.',401);
  if(retired.has(op))return fail('Seviye testi kaldırıldı. Sınıfının Türkçe parkurundan devam et.',410);
  if(op==='studyPlacementInvite'||op==='memberReminderClaim')return json({ok:true,show:false,retired:true});
  if(method!=='POST')return fail('POST gerekli.',405);
  try{
   const preview=a.role==='teacher'||isDemo(a);
   if(a.role!=='student'&&a.role!=='teacher')return fail('Öğrenci veya öğretmen oturumu gerekli.',403);
   if(op==='turkceWritingList'||op==='turkceWritingReview'){
    if(a.role!=='teacher')return fail('Öğretmen oturumu gerekli.',403);
    if(op==='turkceWritingList'){
     let q=db.from('students').select('id,username,class_no').eq('role','student');if(!a.yonetici)q=q.eq('teacher_id',a.teacher_id);
     const students=checked(await q.limit(1000));if(!students.length)return json({ok:true,submissions:[]});
     const rows=checked(await db.from('dm_turkce_writing').select('*').in('student_id',students.map((s:any)=>s.id)).order('updated_at',{ascending:false}).limit(100));
     return json({ok:true,submissions:rows.map((r:any)=>({...r,username:students.find((s:any)=>s.id===r.student_id)?.username,task:task(r.task_id)}))});
    }
    const s=checked(await db.from('students').select('id,teacher_id').eq('id',String(b.studentId||'')).maybeSingle());if(!s||!inScope(a,s))return fail('Bu öğrenciye erişimin yok.',403);
    const t=task(String(b.taskId||'')),scores=b.scores;if(!t||!Array.isArray(scores)||scores.length!==t.rubrik.length||scores.some((n:any)=>!Number.isInteger(n)||n<0||n>4)||typeof b.note!=='string'||b.note.length>2000)return fail('Rubrik puanlarını ve geri bildirimi kontrol et.');
    const r=checked(await db.from('dm_turkce_writing').update({review:{scores,note:b.note,teacherId:a.teacher_id,at:new Date().toISOString()},updated_at:new Date().toISOString()}).eq('student_id',s.id).eq('task_id',t.id).eq('revision',b.revision).select('task_id'));
    if(!r.length)return fail('Yazı değişmiş olabilir. Listeyi yenileyip tekrar değerlendir.',409);return json({ok:true});
   }
   if(op==='turkceStatus'){
    if(preview)return json({ok:true,preview:true,grade:5,done:[],version:BANK.version});
    const student=checked(await db.from('students').select('class_no').eq('id',a.student_id).single());
    const done=checked(await db.from('dm_turkce_progress').select('activity_id').eq('student_id',a.student_id));
    const writing=checked(await db.from('dm_turkce_writing').select('task_id,review,revision').eq('student_id',a.student_id));
    return json({ok:true,grade:student.class_no>=5&&student.class_no<=8?student.class_no:null,done:done.map((r:any)=>r.activity_id),writing,version:BANK.version});
   }
   if(op==='turkceWritingGet'){
    if(preview)return json({ok:true,text:''});
    const t=task(String(b.taskId||''));if(!t)return fail('Yazma görevi bulunamadı.');
    const r=checked(await db.from('dm_turkce_writing').select('text,review,revision').eq('student_id',a.student_id).eq('task_id',t.id).maybeSingle());return json({ok:true,...(r||{text:''})});
   }
   if(op==='turkceWritingSave'){
    if(preview)return fail('Ön izlemede yazı gönderilmez.',403);
    const t=task(String(b.taskId||''));if(!t)return fail('Yazma görevi bulunamadı.');const text=validateWriting(t,b.text);
    const r=checked(await db.rpc('dm_turkce_writing_save',{actor:a.student_id,task_key:t.id,writing_text:text}));return json({ok:true,...r});
   }
   const found=findActivity(BANK,String(b.activityId||''));if(!found)return fail('Türkçe durağı bulunamadı.');
   if(b.version!==BANK.version)return fail('İçerik güncellendi. Parkuru yeniden aç.',409);
   const activity=found.activity,run=String(b.runId||'');
   if(op==='turkcePreviewAnswer'||op==='turkcePracticeAnswer'){
    if(op==='turkcePreviewAnswer'&&!preview)return fail('Ön izleme yetkisi gerekli.',403);if(!Number.isInteger(b.slot))return fail('Geçersiz soru.');const q=activity.questions[b.slot];if(!q)return fail('Soru bulunamadı.');return json({ok:true,...markTurkish(q,b.answer)});
   }
   if(preview)return fail('Ön izlemede ilerleme ve ödül kaydedilmez.',403);
   if(!/^[a-zA-Z0-9_-]{16,100}$/.test(run))return fail('Geçersiz çalışma oturumu.');
   if(op==='turkceStart'){
    const r=checked(await db.rpc('dm_turkce_start',{actor:a.student_id,run_key:run,grade_no:found.grade,activity_key:activity.id,previous_key:found.previous,reward_no:activity.rewardId,bank_version:BANK.version,tasks:activity.questions}));return json({ok:true,...r});
   }
   if(op==='turkceAnswer'){
    // Read a server-created deck. Never grade client question text, score or correctness.
    const r=checked(await db.from('dm_turkce_runs').select('deck,activity_id').eq('student_id',a.student_id).eq('run_id',run).maybeSingle());
    if(!r||r.activity_id!==activity.id||!Number.isInteger(b.slot)||!r.deck[b.slot])return fail('Çalışma oturumu bulunamadı.',409);
    const result=markTurkish(r.deck[b.slot],b.answer);
    const receipt=checked(await db.rpc('dm_turkce_answer',{actor:a.student_id,run_key:run,slot_no:b.slot,answer_text:b.answer,feedback:result}));return json({ok:true,...receipt});
   }
   return fail('Bilinmeyen Türkçe işlemi.');
  }catch(e:any){console.error('turkce',e?.code||'request');return fail(e?.message||'Çalışma kaydedilemedi. Tekrar dene.',409);}
 }};
}
