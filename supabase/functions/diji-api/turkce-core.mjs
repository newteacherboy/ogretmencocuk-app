// Turkish marking preserves spelling, dotted/dotless I and diacritics.
export const normalizeTurkish=value=>String(value??'').normalize('NFC').toLocaleLowerCase('tr-TR').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
export function markTurkish(question,answer){
 if(typeof answer!=='string'||answer.length>3000||!question.secenekler.includes(answer))throw Error('Ekrandaki seçeneklerden birini seç.');
 const correct=question.yazimDuyarli?answer.normalize('NFC')===question.dogru.normalize('NFC'):normalizeTurkish(answer)===normalizeTurkish(question.dogru);
 return {correct,expected:question.dogru,explanation:question.aciklama||''};
}
export function findActivity(bank,id){for(const grade of bank.grades)for(const theme of grade.themes){const index=theme.activities.findIndex(a=>a.id===id);if(index>=0){const all=grade.themes.flatMap(t=>t.activities),activity=theme.activities[index],n=all.indexOf(activity);return {grade:grade.grade,theme,activity,previous:n?all[n-1].id:null};}}return null;}
export const wordCount=text=>String(text).trim().split(/\s+/u).filter(Boolean).length;
export function validateWriting(task,text){if(typeof text!=='string'||text.length>15000||wordCount(text)<task.minKelime||wordCount(text)>task.maxKelime)throw Error(`Yazın ${task.minKelime}–${task.maxKelime} sözcük olmalı.`);return text.trim();}
