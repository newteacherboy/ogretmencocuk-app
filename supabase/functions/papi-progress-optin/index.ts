import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "npm:@supabase/supabase-js@2";
const H={'content-type':'text/html; charset=utf-8','cache-control':'no-store','referrer-policy':'no-referrer'};
const page=(msg:string)=>new Response('<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><main style="max-width:500px;margin:12vh auto;padding:25px;background:#f0fdf4;border-radius:20px;font:17px system-ui"><h1>🦜 Diji Medu Türkçe</h1>'+msg+'</main></html>',{headers:H});
const js=(obj:unknown,code=200)=>new Response(JSON.stringify(obj),{status:code,headers:{'content-type':'application/json','access-control-allow-origin':'https://ogretmencocuk.com','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'POST,OPTIONS'}});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return js({ok:true});
 const api=Deno.env.get('SUPABASE_URL'),secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!api||!secret)return js({ok:false},503);
 const db=createClient(api,secret,{auth:{persistSession:false}});
 if(req.method==='GET'){
  const token=new URL(req.url).searchParams.get('token')||'';
  if(!/^[a-f0-9]{64}$/.test(token))return page('<p>Geçersiz bağlantı.</p>');
  return page('<h2>Papi e-posta bildirimleri</h2><p>İlerleme özetleri ve haftalık lig haberlerine abone olmak ister misin?</p><form method="POST"><input type="hidden" name="token" value="'+token+'"><button style="padding:14px 20px;border:0;border-radius:12px;background:#15803d;color:white">Evet, abone ol</button></form>');
 }
 if(req.method!=='POST')return js({ok:false},405);
 if((req.headers.get('content-type')||'').includes('form')){
  const f=await req.formData();const token=String(f.get('token')||'');
  if(!/^[a-f0-9]{64}$/.test(token))return page('<p>Bağlantı geçersiz.</p>');
  const c=await db.rpc('dm_papi_confirm_subscription',{raw_token:token});
  return page(c.data===true&&!c.error?'<h2>Aboneliğin başladı ✅</h2><p>Papi haberlerini almak için teşekkürler!</p>':'<p>Bağlantı geçersiz veya süresi dolmuş.</p>');
 }
 const bearer=req.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];if(!bearer)return js({ok:false},401);
 const user=await db.auth.getUser(bearer);
 if(user.error||!user.data.user?.identities?.some(x=>x.provider==='google'))return js({ok:false},401);
 const identity=user.data.user;
 const mapping=await db.from('student_google_accounts').select('student_id').eq('auth_user_id',identity.id).maybeSingle();
 if(!mapping.data?.student_id)return js({ok:false},403);
 const student=await db.from('students').select('id,email,status,role').eq('id',mapping.data.student_id).single();
 if(!student.data||student.data.status!=='approved'||student.data.role!=='student')return js({ok:false},403);
 const body=await req.json().catch(()=>({}));if(body.subscribe!==true)return js({ok:true,requested:0});
 const sender=Deno.env.get('EPOSTA_GONDEREN')||'',brevo=Deno.env.get('BREVO_API_KEY')||'',resend=Deno.env.get('RESEND_API_KEY')||'';
 if(!sender||(!brevo&&!resend))return js({ok:false,message:'Mail provider not configured'},503);
 const targets=[['parent',student.data.email],['student',identity.email]];
 const seen=new Set<string>();let requested=0;
 for(const [kind,rawMail] of targets){
  const email=String(rawMail||'').trim().toLowerCase();
  if(!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)||seen.has(email))continue;
  seen.add(email);
  const token=Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
  const issued=await db.rpc('dm_papi_issue_confirmation',{sid:student.data.id,kind,addr:email,raw_token:token});
  if(issued.error||issued.data!==true)continue;
  const slot=await db.rpc('dm_mail_slot');if(slot.error||!slot.data)break;
  const link=api+'/functions/v1/papi-progress-optin?token='+token;
  const html='<div style="padding:24px;background:#f0fdf4;font:16px Arial,sans-serif"><h1>🦜 Papi haberleri</h1><p>Diji Medu Türkçe ilerleme özetleri ve lig haberlerine abone olmak için adresini doğrula.</p><p><a href="'+link+'" style="background:#16825a;color:white;padding:14px 22px;border-radius:12px;text-decoration:none">E-posta aboneliğini onayla</a></p><small>İstek sana ait değilse yok say. 48 saat içinde onaylanmazsa abonelik başlamaz.</small></div>';
  try{
   const r=brevo?await fetch('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':brevo,'content-type':'application/json'},body:JSON.stringify({sender:{email:sender,name:'Diji Medu Türkçe'},to:[{email}],subject:'🦜 Papi haberlerini almak için onay ver',htmlContent:html})}):await fetch('https://api.resend.com/emails',{method:'POST',headers:{authorization:'Bearer '+resend,'content-type':'application/json'},body:JSON.stringify({from:'Diji Medu Türkçe <'+sender+'>',to:[email],subject:'🦜 Papi haberlerini almak için onay ver',html})});
   if(r.ok)requested++;
  }catch{}
 }
 return js({ok:true,requested});
});
