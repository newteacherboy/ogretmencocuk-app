import {createClient} from "npm:@supabase/supabase-js@2.118.0";
import {turkceMemberAuth} from "../diji-api/turkce-member-auth.mjs";
import {turkceMemberAdmin} from "../diji-api/turkce-member-admin.mjs";
const options={auth:{persistSession:false,autoRefreshToken:false}};
const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,options);
Deno.serve(async(req:Request)=>{
 const op=new URL(req.url).searchParams.get('op');
 if(op==='admin')return turkceMemberAdmin(req,db);
 const client=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,options);
 return turkceMemberAuth(req,db,client);
});
