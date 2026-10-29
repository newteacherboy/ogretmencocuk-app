const headers={'Access-Control-Allow-Origin':'https://ogretmencocuk.com','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const accountOps=new Set(['profile','profile_update','report','missions','mission_claim','route_status','route_start','route_answer','avatars','username']);
const allowed=new Set(['social','like','study_start','study_answer','study_status',...accountOps,'account_username','account_password']),rates=new Map();
export async function features(req,db,authClient){
 const send=(data,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(req.method==='OPTIONS')return send({ok:true});if(req.method!=='POST')return send({ok:false,message:'POST gerekli.'},405);
 const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');if(!token)return send({ok:false,message:'Hesabına giriş yap.'},401);
 const {data,error}=await db.auth.getUser(token);if(error||!data?.user)return send({ok:false,message:'Oturumun sona erdi.'},401);
 const uid=data.user.id,now=Date.now();if(rates.size>10000)for(const [key,r]of rates)if(now-r.at>60000)rates.delete(key);
 const rate=rates.get(uid);if(rate&&now-rate.at<60000){if(++rate.n>100)return send({ok:false,message:'Biraz bekleyip yeniden dene.'},429);}else rates.set(uid,{at:now,n:1});
 let body;try{const reader=req.body?.getReader();let size=0;const chunks=[];if(reader)while(true){const x=await reader.read();if(x.done)break;size+=x.value.length;if(size>8192){await reader.cancel();return send({ok:false,message:'İstek çok büyük.'},413);}chunks.push(x.value);}const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}body=JSON.parse(new TextDecoder().decode(bytes));}catch{return send({ok:false,message:'Geçersiz istek.'},400);}
 if(!allowed.has(body.action))return send({ok:false,message:'İşlem bulunamadı.'},400);
 let operation=body.action,payload=body.payload||{};
 if(operation==='username')return send({ok:false,message:'Kullanıcı adı için mevcut şifreni doğrula.'},400);
 if(operation==='account_username'||operation==='account_password'){
  if(!authClient)return send({ok:false,message:'Hesap hizmeti hazırlanıyor.'},503);
  const current=String(payload.current_password||''),next=String(payload.new_password||'');
  if(current.length<6||current.length>128||operation==='account_password'&&(next.length<6||next.length>128))return send({ok:false,message:'Şifre 6–128 karakter olmalı.'},400);
  const verified=await authClient.auth.signInWithPassword({email:data.user.email,password:current});
  if(verified.error||verified.data?.user?.id!==uid)return send({ok:false,message:'Mevcut şifreni kontrol et.'},400);
  if(verified.data?.session)await db.auth.admin.signOut(verified.data.session.access_token,'local');
  if(operation==='account_password'){
   const updated=await db.auth.admin.updateUserById(uid,{password:next});if(updated.error)return send({ok:false,message:'Şifre güncellenemedi.'},400);
   return send({ok:true,message:'Şifren güncellendi.'});
  }
  operation='username';payload={request_id:payload.request_id,username:String(payload.username||'').trim().toLocaleLowerCase('tr-TR').replace(/[çğıöşü]/g,c=>({'ç':'c','ğ':'g','ı':'i','ö':'o','ş':'s','ü':'u'}[c]))};
 }
 const r=await db.rpc(accountOps.has(operation)?'turkce_account_request':'turkce_features_request',{actor:uid,op:operation,p:payload});
 if(r.error)return send({ok:false,message:r.error.code==='P0001'?r.error.message:'İşlem tamamlanamadı.'},400);
 return send({...r.data,is_admin:data.user.app_metadata?.turkce_role==='admin'});
}
