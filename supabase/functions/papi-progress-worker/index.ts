import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const response=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{"content-type":"application/json","cache-control":"no-store"}});
Deno.serve(async(req)=>{
 if(req.method!=='POST')return response({ok:false},405);
 const url=Deno.env.get('SUPABASE_URL'),secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!url||!secret)return response({ok:false,error:'Missing project configuration'},503);
 const db=createClient(url,secret,{auth:{persistSession:false}});
 const key=req.headers.get('x-papi-worker')||'';
 if(key.length!==64)return response({ok:false},403);
 const auth=await db.rpc('dm_papi_worker_authorized',{provided:key});
 if(auth.error||auth.data!==true)return response({ok:false},403);
 const brevo=Deno.env.get('BREVO_API_KEY')||'',resend=Deno.env.get('RESEND_API_KEY')||'';
 const sender=Deno.env.get('EPOSTA_GONDEREN')||'';
 const senderName=Deno.env.get('EPOSTA_GONDEREN_AD')||'Diji Medu Türkçe';
 if(!sender||(!brevo&&!resend))return response({ok:false,error:'Mail provider not configured'},503);
 let sent=0,failed=0;
 for(let i=0;i<5;i++){
  const rem=await db.rpc('dm_papi_remaining_mail_slots');
  if(rem.error||Number(rem.data)<=0)break;
  const picked=await db.rpc('dm_papi_take_due');
  if(picked.error)return response({ok:false,error:'Queue unavailable',sent,failed},503);
  const m=Array.isArray(picked.data)?picked.data[0]:null;
  if(!m)break;
  const permission=await db.rpc('dm_progress_mail_allowed',{sid:m.student_id,addr:m.to_email});
  // If cancellation occurs after claiming, reject the send.
  if(permission.error||permission.data!==true){
   await db.rpc('dm_papi_mail_result',{mail_id:m.mail_id,sent:false,problem:'Consent no longer valid'});
   failed++;continue;
  }
  const slot=await db.rpc('dm_mail_slot');
  if(slot.error||!slot.data){
   await db.rpc('dm_papi_mail_result',{mail_id:m.mail_id,sent:false,problem:'Daily quota reached'});
   break;
  }
  try{
   let api:Response;
   if(brevo)api=await fetch('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':brevo,'Content-Type':'application/json'},body:JSON.stringify({sender:{email:sender,name:senderName},to:[{email:m.to_email}],subject:m.subject,htmlContent:m.html,textContent:m.text_body||''})});
   else api=await fetch('https://api.resend.com/emails',{method:'POST',headers:{'Authorization':'Bearer '+resend,'Content-Type':'application/json'},body:JSON.stringify({from:senderName+' <'+sender+'>',to:[m.to_email],subject:m.subject,html:m.html,text:m.text_body||''})});
   if(api.ok){await db.rpc('dm_papi_mail_result',{mail_id:m.mail_id,sent:true,problem:null});sent++;}
   else{await db.rpc('dm_papi_mail_result',{mail_id:m.mail_id,sent:false,problem:'Provider HTTP '+api.status});failed++;if(api.status===429)break;}
  }catch{await db.rpc('dm_papi_mail_result',{mail_id:m.mail_id,sent:false,problem:'Network error'});failed++;}
 }
 return response({ok:true,sent,failed});
});
