/* Private learning preferences; never an authorization or age-verification claim. */
export function normalizeLearnerProfile(value, legacyClass=null, legacyPurpose='') {
 if(value===undefined||value===null)return {version:0,purpose:legacyPurpose==='school'?'school':legacyPurpose==='independent'?'independent':legacyClass?'school':'independent',ageBand:'',educationStage:legacyClass?Number(legacyClass)<=4?'primary':Number(legacyClass)<=8?'middle':'high':'',goal:'daily',startChoice:'new',knownLevel:'A1'};
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Öğrenme bilgilerini kontrol et.');
 const valid=(key,values,fallback)=>{const v=value[key]??fallback;if(!values.includes(v))throw Error('Öğrenme bilgilerini kontrol et: '+key);return v;};
 const purpose=valid('purpose',['school','independent'],'independent');
 return {version:1,purpose,ageBand:valid('ageBand',['under13','teen','adult'],''),educationStage:purpose==='school'?valid('educationStage',['middle'],''):'',goal:valid('goal',['daily','travel','school','exam'],'daily'),startChoice:'new',knownLevel:'A1'};
}
export function learnerClass(_profile, value){
 if(value===null||value===undefined||value==='')throw Error('Sınıfını seç; başlangıç durağın buna göre belirlenir.');
 const n=Number(value);if(!Number.isInteger(n)||n<5||n>8)throw Error('Sınıf 5 ile 8 arasında olmalı.');return n;
}
export async function saveLearnerProfile(db,id,profile){if(!profile.version)return;const r=await db.from('extra_data').upsert({student_id:id,key_name:'learner_profile_v1',value:profile,updated_at:new Date().toISOString()},{onConflict:'student_id,key_name'});if(r.error)throw r.error;}
