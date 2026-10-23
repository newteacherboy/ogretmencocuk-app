import {createTurkceStudent} from './turkce-member-auth.mjs';
const headers={'Access-Control-Allow-Origin':'https://ogretmencocuk.com','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
export async function turkceMemberAdmin(req,db){
 const send=(data,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(req.method==='OPTIONS')return send({ok:true});if(req.method!=='POST')return send({ok:false,message:'POST gerekli.'},405);
 const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');if(!token)return send({ok:false,message:'Giriş gerekli.'},401);
 const {data,error}=await db.auth.getUser(token);
 if(error||!data.user)return send({ok:false,message:'Giriş gerekli.'},401);
 if(data.user.app_metadata?.turkce_role!=='admin')return send({ok:false,message:'Bu işlem için yetkin yok.'},403);
 let body;try{const reader=req.body?.getReader();const chunks=[];let size=0;if(reader)while(true){const x=await reader.read();if(x.done)break;size+=x.value.length;if(size>8192){await reader.cancel();return send({ok:false,message:'İstek çok büyük.'},413)}chunks.push(x.value)}const bytes=new Uint8Array(size);let off=0;for(const c of chunks){bytes.set(c,off);off+=c.length}body=JSON.parse(new TextDecoder().decode(bytes));}catch{return send({ok:false,message:'Geçersiz istek.'},400)}
 const actor=data.user.id,p=body.payload||{},action=body.action;
 try{
 if(action==='create'){
 const student=await createTurkceStudent(db,p);await db.rpc('turkce_admin_request',{actor,op:'audit',p:{user_id:student.user_id,action:'student_create'}});return send({ok:true,...student});
 }
 if(action==='password'){
 if(typeof p.password!=='string'||p.password.length<10||p.password.length>128)return send({ok:false,message:'Öğrenci şifresi 10–128 karakter olmalı.'},400);
 const target=await db.auth.admin.getUserById(String(p.user_id));if(target.error||!target.data.user||target.data.user.app_metadata?.turkce_role==='admin'||!/^tr[a-z0-9]{10}$/.test(target.data.user.user_metadata?.username||''))return send({ok:false,message:'Öğrenci bulunamadı.'},400);
 const r=await db.auth.admin.updateUserById(target.data.user.id,{password:p.password});if(r.error)throw Error('Şifre değiştirilemedi.');await db.rpc('turkce_admin_request',{actor,op:'audit',p:{user_id:target.data.user.id,action:'password_reset'}});return send({ok:true});
 }
 if(!['list','update','economy'].includes(action))return send({ok:false,message:'İşlem bulunamadı.'},400);
 if(action==='update'&&(!String(p.full_name||'').trim()||!String(p.school||'').trim()||![5,6,7,8].includes(Number(p.grade))))return send({ok:false,message:'Öğrenci bilgilerini kontrol et.'},400);
 if(action==='economy'&&(!Number.isInteger(p.energy)||p.energy<0||p.energy>30||!Number.isInteger(p.xp)||p.xp<0||p.xp>10000000||!Number.isInteger(p.gold)||p.gold<0||p.gold>10000000))return send({ok:false,message:'Bakiyeleri kontrol et.'},400);
 const r=await db.rpc('turkce_admin_request',{actor,op:action,p});if(r.error)throw Error(r.error.code==='P0001'?r.error.message:'İşlem kaydedilemedi.');return send(r.data);
 }catch(e){return send({ok:false,message:e.message||'İşlem tamamlanamadı.'},400)}
}
