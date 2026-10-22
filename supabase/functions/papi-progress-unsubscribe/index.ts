import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const headers={"content-type":"text/html; charset=utf-8","cache-control":"no-store","referrer-policy":"no-referrer","x-content-type-options":"nosniff","content-security-policy":"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"};
const html=(body:string)=>new Response('<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Diji Medu Türkçe E-posta Tercihi</title><main style="max-width:500px;margin:12vh auto;padding:30px;font:18px/1.6 system-ui,sans-serif;color:#24503d;border:1px solid #ddf0e5;border-radius:20px;background:#f9fffb"><h1>🦜 Diji Medu Türkçe</h1>'+body+'</main></html>',{headers});
Deno.serve(async(req)=>{
 const u=new URL(req.url);
 const token=req.method==='POST'?(await req.formData().catch(()=>new FormData())).get('token'):u.searchParams.get('token');
 if(typeof token!=='string'||!/^[a-f0-9]{64}$/.test(token))return html('<p>Bağlantı geçersiz veya eksik.</p>');
 if(req.method==='GET')return html('<h2>İlerleme e-postalarını durdur</h2><p>Bu adrese gönderilen Papi ilerleme raporlarını kapatmak istiyor musun?</p><form method="POST"><input type="hidden" name="token" value="'+token+'"><button style="border:0;border-radius:12px;background:#207f60;color:white;padding:14px 20px;font-size:16px">E-postaları durdur</button></form>');
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!url||!key)return html('<p>İşlem şu an tamamlanamadı. Lütfen daha sonra deneyin.</p>');
 const db=createClient(url,key,{auth:{persistSession:false}});
 const {data,error}=await db.rpc('dm_papi_progress_unsubscribe',{raw_token:token});
 if(error)return html('<p>Bir hata oluştu. Lütfen tekrar deneyin.</p>');
 return html(data===true?'<h2>Tercihin kaydedildi ✅</h2><p>Bu adrese ilerleme raporu gönderilmeyecek.</p>':'<p>Bağlantı geçersiz veya daha önce kullanılmış olabilir.</p>');
});
