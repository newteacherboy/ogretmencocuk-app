export function normalizeUsername(value){return String(value||'').trim().toLocaleLowerCase('tr-TR').replace(/[çğıöşü]/g,c=>({'ç':'c','ğ':'g','ı':'i','ö':'o','ş':'s','ü':'u'}[c]));}
export const validUsername=name=>/^[a-z0-9][a-z0-9_.]{2,19}$/.test(name);
const reserved=new Set(['dijimedu','admin','administrator','teacher','ogretmen','yonetici','root','support']);
export async function createTurkceStudent(db,body,source='student'){
 const password=String(body.password||''),username=normalizeUsername(body.username);
 const full_name=String(body.full_name||username).trim().replace(/\s+/g,' '),school=String(body.school||'Araştırma Grubu').trim().replace(/\s+/g,' '),grade=Number(body.grade||5);
 if(!validUsername(username)||reserved.has(username))throw Error('Kullanıcı adı 3–20 karakter olmalı; harf, rakam, nokta ve alt çizgi kullanabilirsin. Başka bir kullanıcı adı seç.');
 if(password.length<6||password.length>128)throw Error('Şifre 6–128 karakter olmalı. Sayısal şifre kullanabilirsin.');
 if(full_name.length<3||full_name.length>80||school.length<3||school.length>120||!Number.isInteger(grade)||grade<5||grade>8)throw Error('Öğrenci bilgilerini kontrol et.');
 const existing=await db.from('turkce_profiles').select('id').eq('username',username).maybeSingle();
 if(existing.error)throw Error('Kayıt hizmeti geçici olarak kullanılamıyor.');
 if(existing.data)throw Error('Bu kullanıcı adı kullanılıyor. Başka bir ad seç.');
 const recovery=randomCode(24);
 const result=await db.auth.admin.createUser({email:alias(username),password,email_confirm:true,user_metadata:{username,full_name,school,grade,registration_source:source}});
 if(result.error||!result.data?.user)throw Error('Kullanıcı adı kullanılıyor olabilir. Başka bir adla yeniden dene.');
 const saved=await db.rpc('turkce_recovery_store',{actor:result.data.user.id,hash:await hash(recovery)});
 if(saved.error){await db.auth.admin.deleteUser(result.data.user.id);throw Error('Hesap oluşturulamadı. Yeniden dene.');}
 return {code:username,recovery,user_id:result.data.user.id};
}
const headers={'Access-Control-Allow-Origin':'https://ogretmencocuk.com','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const alphabet='abcdefghjkmnpqrstuvwxyz23456789';
function randomCode(length){const bytes=crypto.getRandomValues(new Uint8Array(length));return [...bytes].map(b=>alphabet[b%alphabet.length]).join('');}
async function hash(value){return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))].map(b=>b.toString(16).padStart(2,'0')).join('');}
const alias=code=>code+'@students.ogretmencocuk.invalid';
export async function turkceMemberAuth(req,db,authClient){
 const send=(data,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(req.method==='OPTIONS')return send({ok:true});if(req.method!=='POST')return send({ok:false,message:'POST gerekli.'},405);
 let body;try{const reader=req.body?.getReader();let size=0;const parts=[];if(reader)while(true){const x=await reader.read();if(x.done)break;size+=x.value.length;if(size>8192){await reader.cancel();return send({ok:false,message:'İstek çok büyük.'},413)}parts.push(x.value)}const bytes=new Uint8Array(size);let offset=0;for(const part of parts){bytes.set(part,offset);offset+=part.length}body=JSON.parse(new TextDecoder().decode(bytes));}catch{return send({ok:false,message:'Geçersiz istek.'},400)}
 if(!['register','login','recover'].includes(body?.action))return send({ok:false,message:'İşlem bulunamadı.'},400);
 const ip=req.headers.get('cf-connecting-ip')||req.headers.get('x-real-ip')||(req.headers.get('x-forwarded-for')||'unknown').split(',').at(-1).trim();
 const budget=await db.rpc('turkce_auth_budget',{bucket_key:await hash(body.action+':'+ip),max_count:body.action==='register'?120:240});
 if(budget.error)return send({ok:false,message:'Giriş hizmeti geçici olarak kullanılamıyor.'},503);
 if(!budget.data)return send({ok:false,message:'Çok fazla deneme yaptın. Daha sonra yeniden dene.'},429);
 const password=String(body.password||'');const code=normalizeUsername(body.code);
 if(password.length<6||password.length>128)return send({ok:false,message:'Şifren 6–128 karakter olmalı.'},400);
 if(body.action==='register'){
 let created;try{created=await createTurkceStudent(db,body)}catch(e){return send({ok:false,message:e.message},400)}
 const {code:username,recovery}=created;
 const login=await authClient.auth.signInWithPassword({email:alias(username),password});
 if(login.error)return send({ok:true,code:username,recovery,session:null,message:'Hesabın oluşturuldu. Kullanıcı adın ve şifrenle giriş yap.'});
 return send({ok:true,code:username,recovery,session:login.data.session});
 }
 if(!validUsername(code))return send({ok:false,message:'Kullanıcı adını ve şifreni kontrol et.'},400);
 const accountBudget=await db.rpc('turkce_auth_budget',{bucket_key:await hash('account:'+code+':'+ip),max_count:30});
 if(accountBudget.error||!accountBudget.data)return send({ok:false,message:'Çok fazla deneme. Daha sonra yeniden dene.'},429);
 if(body.action==='recover'){
 const recovery=String(body.recovery||'').trim().toLowerCase();if(!/^[a-z0-9]{24}$/.test(recovery))return send({ok:false,message:'Kullanıcı adını ve kurtarma kodunu kontrol et.'},400);
 const next=randomCode(24),oldHash=await hash(recovery),nextHash=await hash(next);
 const found=await db.rpc('turkce_recovery_consume',{code,hash:oldHash,next_hash:nextHash});
 if(found.error||!found.data)return send({ok:false,message:'Kullanıcı adını ve kurtarma kodunu kontrol et.'},400);
 const updated=await db.auth.admin.updateUserById(found.data,{password});
 if(updated.error){await db.rpc('turkce_recovery_consume',{code,hash:nextHash,next_hash:oldHash});return send({ok:false,message:'Şifre değiştirilemedi.'},400)}
 const resolved=await db.rpc('turkce_login_email',{code});if(!resolved.error&&resolved.data===null)return send({ok:false,message:'Kullanıcı adını ve şifreni kontrol et.'},401);const email=typeof resolved.data==='string'?resolved.data:alias(code);
 const fresh=await authClient.auth.signInWithPassword({email,password});
 if(fresh.data?.session)await db.auth.admin.signOut(fresh.data.session.access_token,'global');
 return send({ok:true,recovery:next});
 }
 const resolved=await db.rpc('turkce_login_email',{code});if(!resolved.error&&resolved.data===null)return send({ok:false,message:'Kullanıcı adını ve şifreni kontrol et.'},401);const email=typeof resolved.data==='string'?resolved.data:alias(code);
 const result=await authClient.auth.signInWithPassword({email,password});
 if(result.error||!result.data.session)return send({ok:false,message:'Kullanıcı adını veya şifreni kontrol et.'},401);
 const profile=await db.from('turkce_profiles').select('disabled').eq('id',result.data.user.id).maybeSingle();
 if(profile.error||!profile.data||profile.data.disabled){await db.auth.admin.signOut(result.data.session.access_token,'local');return send({ok:false,message:'Hesabın yetkili tarafından duraklatıldı.'},403);}
 return send({ok:true,session:result.data.session});
}
