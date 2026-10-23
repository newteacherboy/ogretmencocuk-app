/* All signed-in progress and rewards come from the Turkish server. */
(function(){
'use strict';
const url='https://isgnsmkboehygxxysria.supabase.co',key='sb_publishable_C79a3Zjz90omNzGLMFf1YQ_mEH1cwAa';
const client=window.supabase.createClient(url,key,{auth:{storageKey:'dijimedu-turkce-auth-v1',autoRefreshToken:true,persistSession:true,detectSessionInUrl:true}});
let cached=null,user=null;
function apply(data){if(data?.economy){cached=data;window.dispatchEvent(new CustomEvent('member-state',{detail:data}));}return data;}
async function request(action,payload={},requestId=crypto.randomUUID(),scope="turkce_member"){
 const {data:{session}}=await client.auth.getSession();
 if(!session)throw Error('Devam etmek için hesabına giriş yap.');
 let response;const body=JSON.stringify({action,payload:{...payload,request_id:requestId}});
 for(let i=0;i<2;i++){try{response=await fetch(url+'/functions/v1/diji-api?op='+scope,{method:'POST',headers:{'Content-Type':'application/json',apikey:key,Authorization:'Bearer '+session.access_token},body,signal:AbortSignal.timeout(15000)});break}catch(error){if(i===1)throw Error('Bağlantı kurulamadı. İnternetini kontrol edip yeniden dene.')}}
 const data=await response.json();if(!response.ok||!data.ok)throw Error(data.message||'İşlem tamamlanamadı.');return apply(data);
}
const member=window.turkceMember={client,request,get user(){return user},get data(){return cached},adminRequest:(action,payload={})=>request(action,payload,crypto.randomUUID(),"turkce_member_admin"),authRequest:async function(action,payload){const r=await fetch(url+'/functions/v1/diji-api?op=turkce_member_auth',{method:'POST',headers:{'Content-Type':'application/json',apikey:key},body:JSON.stringify({action,...payload}),signal:AbortSignal.timeout(20000)});const d=await r.json();if(!r.ok||!d.ok)throw Error(d.message||'İşlem tamamlanamadı.');return d;},get snapshot(){return cached?.economy||{energy:0,xp:0,gold:0,level:1,nextEnergySeconds:0}},ready:null};
member.ready=(async()=>{try{const r=await client.auth.getUser();user=r.data.user;if(user)await request('state');}catch(error){member.error=error.message}return member;})();
window.practiceEconomy={snapshot:()=>member.snapshot};
client.auth.onAuthStateChange((event,session)=>{if(event==='SIGNED_OUT'){user=null;cached=null;window.dispatchEvent(new CustomEvent('member-state',{detail:null}))}else if(event==='SIGNED_IN')user=session?.user||null;});
})();
