// Standalone Auth UI module; enable only after Turkish Supabase config is validated.
// Do not include service_role keys or public user email in profile lists.
import {createClient} from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.57.0/+esm";
const $=id=>document.getElementById(id);
const supabaseUrl=window.TURKCE_SUPABASE_URL;
const publishableKey=window.TURKCE_SUPABASE_PUBLISHABLE_KEY;
const configured=Boolean(supabaseUrl&&publishableKey&&/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(supabaseUrl));
const supabase=configured?createClient(supabaseUrl,publishableKey,{auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:true}}):null;
const status=$("auth-status");
function report(message,error=false){status.textContent=message;status.style.color=error?"#b3243b":"#1f7048"}
$("register").addEventListener("submit",async event=>{
 event.preventDefault();
 if(!supabase){report("Türkçe Supabase projesi henüz bağlı değil. Bu sürüm sadece önizleme.",true);return}
 const fd=new FormData(event.currentTarget);
 const username=String(fd.get("username")||"").trim().toLowerCase();
 const grade=Number(fd.get("grade"));
 const email=String(fd.get("email")||"").trim();
 const password=String(fd.get("password")||"");
 if(!/^[a-z0-9_]{3,20}$/.test(username)){report("Kullanıcı adı 3–20 karakter; yalnızca harf, rakam ve alt çizgi.",true);return}
 if(![5,6,7,8].includes(grade)){report("5–8. sınıflardan birini seç.",true);return}
 if(password.length<10){report("Şifren en az 10 karakter olmalı.",true);return}
 $("register-submit").disabled=true;
 try{const {error}=await supabase.auth.signUp({email,password,options:{data:{username,grade},emailRedirectTo:location.origin+"/hesap.html"}});
 if(error)throw error;
 report("Kayıt isteğin alındı. E-postana gelen doğrulama bağlantısını kontrol et.");
 }catch(e){report("Kayıt tamamlanamadı. Kullanıcı adını veya e-posta bilgilerini kontrol et.",true)}
 finally{$("register-submit").disabled=false}
});
$("login").addEventListener("submit",async event=>{
 event.preventDefault();
 if(!supabase){report("Türkçe Supabase projesi henüz bağlı değil.",true);return}
 const fd=new FormData(event.currentTarget);
 $("login-submit").disabled=true;
 try{const {error}=await supabase.auth.signInWithPassword({email:String(fd.get("email")||"").trim(),password:String(fd.get("password")||"")});
 if(error)throw error;report("Giriş başarılı.");await refresh();
 }catch(e){report("E-posta veya şifre hatalı ya da hesap doğrulanmamış.",true)}
 finally{$("login-submit").disabled=false}
});
$("logout").addEventListener("click",async()=>{if(supabase)await supabase.auth.signOut();await refresh()});
async function refresh(){
 const user=supabase?(await supabase.auth.getUser()).data.user:null;
 $("account-state").textContent=user?"Giriş yapıldı":"Giriş yapılmadı";
 $("logout").hidden=!user;
 if(user){const {data,error}=await supabase.from("turkce_profiles").select("username,grade").single();
 if(data&&!error)$("account-state").textContent=data.username+" • "+data.grade+". sınıf"}
}
await refresh();
