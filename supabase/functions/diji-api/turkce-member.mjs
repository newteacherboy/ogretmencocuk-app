// Verified Supabase Auth identity; service-only SQL dispatcher owns all mutations.
const headers={'Access-Control-Allow-Origin':'https://ogretmencocuk.com','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const allowed=new Set(['state','start','answer','preferences','friend_request','friend_accept','friend_remove','social','leagues']);
const rates=new Map();
export async function turkceMember(req,db){
 const send=(data,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(req.method==='OPTIONS')return send({ok:true});
 if(req.method!=='POST')return send({ok:false,message:'POST gerekli.'},405);
 const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
 if(!token)return send({ok:false,message:'Önce hesabına giriş yap.'},401);
 const {data,error}=await db.auth.getUser(token);
 if(error||!data?.user)return send({ok:false,message:'Oturumun sona erdi. Yeniden giriş yap.'},401);
 const user=data.user.id,now=Date.now();
 if(rates.size>10000)for(const [id,r]of rates)if(now-r.at>60000)rates.delete(id);
 const r=rates.get(user);if(r&&now-r.at<60000){if(++r.n>100)return send({ok:false,message:'Çok sık istek gönderdin. Biraz bekle.'},429)}else rates.set(user,{at:now,n:1});
 let body;try{const reader=req.body?.getReader();let size=0;const chunks=[];if(reader)while(true){const x=await reader.read();if(x.done)break;size+=x.value.length;if(size>8192){await reader.cancel();return send({ok:false,message:'İstek çok büyük.'},413)}chunks.push(x.value)}const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length}body=JSON.parse(new TextDecoder().decode(bytes));}catch{return send({ok:false,message:'Geçersiz istek.'},400)}
 if(!allowed.has(body?.action))return send({ok:false,message:'İşlem bulunamadı.'},400);
 const result=await db.rpc('turkce_member_request',{actor:user,op:body.action,p:body.payload||{}});
 if(result.error){console.error('turkce_member',result.error.code);return send({ok:false,message:result.error.code==='P0001'?result.error.message:'İşlem tamamlanamadı. Yeniden dene.'},400)}
 return send({...result.data,is_admin:data.user.app_metadata?.turkce_role==='admin'});
}
