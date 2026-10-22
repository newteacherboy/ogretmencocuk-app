const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
test('guest query parameters are retired without losing member token or other URL state',()=>{
 const values=new Map([['ing_oturumAcik','true'],['ing_token','real-session'],['ing_aktifOgrenci','Alice']]);let url;
 const storage={getItem:k=>values.get(k)||null};
 const c={window:{localStorage:storage,sessionStorage:storage,fetch(){}},location:{search:'?misafir=1&kesif=1&kod=teacher',pathname:'/',hash:''},history:{replaceState:(a,b,u)=>url=u},URLSearchParams,document:{addEventListener(){},documentElement:{classList:{add(){}}}}};
 vm.runInNewContext(fs.readFileSync('first-discovery-state.js','utf8'),c);
 assert.equal(c.window.dmDiscoveryContext.guest,false);assert.equal(c.window.dmDiscoveryContext.member,true);assert.equal(values.get('ing_token'),'real-session');assert.equal(url,'/?kod=teacher');
});
test('entry button, guest script loading and expired-trial help are removed',()=>{
 const html=fs.readFileSync('index.html','utf8');assert.doesNotMatch(html,/<script[^>]+src="guest-platform/);
 assert.doesNotMatch(fs.readFileSync('onboarding-ui.js','utf8'),/dmGuestEntry|Önce keşfet/);
 assert.doesNotMatch(fs.readFileSync('papi-guide-content.js','utf8'),/Misafir denemesi|10 dakikalık keşif/);
 assert.doesNotMatch(fs.readFileSync('first-discovery.js','utf8'),/navigate\('\.\/\?misafir=1/);
 assert.match(fs.readFileSync('misafir.html','utf8'),/giris=1/);
});
