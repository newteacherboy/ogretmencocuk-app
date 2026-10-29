import test from 'node:test';import assert from 'node:assert/strict';import {features} from '../supabase/functions/turkce-features/handler.mjs';
const request=(body,token='token')=>new Request('https://site.test',{method:'POST',headers:{authorization:token?'Bearer '+token:''},body:JSON.stringify(body)});
test('features reject missing session, unsafe verbs, unknown operations and large bodies',async()=>{
 const db={auth:{getUser:async()=>({data:{user:{id:'checked'}}})},rpc:async()=>({data:{ok:true}})};
 assert.equal((await features(request({},''),db)).status,401);
 assert.equal((await features(new Request('https://site.test'),db)).status,405);
 assert.equal((await features(request({action:'fake'}),db)).status,400);
 assert.equal((await features(request({action:'study_start',payload:'x'.repeat(9000)}),db)).status,413);
});
test('identity and reward decisions are passed only to the service-only RPC',async()=>{
 let sent;const db={auth:{getUser:async()=>({data:{user:{id:'verified',app_metadata:{}}}})},rpc:async(name,args)=>{sent={name,args};return{data:{ok:true}}}};
 const r=await features(request({action:'study_answer',actor:'victim',payload:{actor:'victim',correct:true,xp:999}}),db);
 assert.equal(r.status,200);assert.equal(sent.name,'turkce_features_request');assert.equal(sent.args.actor,'verified');assert.equal(r.headers.get('cache-control'),'no-store');
});
test('direct username RPC route is blocked and credential changes require the current password',async()=>{
 let writes=0;const db={auth:{getUser:async()=>({data:{user:{id:'owner',email:'stable@students.ogretmencocuk.invalid'}}}),admin:{signOut:async()=>{},updateUserById:async()=>{writes++;return{data:{}}}}},rpc:async()=>{writes++;return{data:{ok:true}}}};
 assert.equal((await features(request({action:'username',payload:{username:'renamed'}}),db)).status,400);
 const invalid={auth:{signInWithPassword:async()=>({error:{}})}};
 assert.equal((await features(request({action:'account_password',payload:{current_password:'wrong123',new_password:'new12345'}}),db,invalid)).status,400);assert.equal(writes,0);
 const other={auth:{signInWithPassword:async()=>({data:{user:{id:'different'}}})}};
 assert.equal((await features(request({action:'account_password',payload:{current_password:'test1234',new_password:'new12345'}}),db,other)).status,400);assert.equal(writes,0);
});
