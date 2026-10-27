const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),out=process.env.UI_SCREEN_DIR||'/tmp/turkce-games-ui';fs.mkdirSync(out,{recursive:true});
const mime={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml'};
const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://local'),file=path.resolve(root,'.'+(u.pathname==='/'?'/index.html':decodeURIComponent(u.pathname)));if(!file.startsWith(root+path.sep)||!fs.existsSync(file)){res.writeHead(404);return res.end('missing')}res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file))});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;const options={headless:true};if(process.env.BROWSER_EXECUTABLE){options.executablePath=process.env.BROWSER_EXECUTABLE;options.args=process.env.BROWSER_SINGLE_PROCESS==='1'?['--no-sandbox','--no-zygote','--single-process','--disable-dev-shm-usage']:['--no-sandbox'];}const browser=await chromium.launch(options);
try{const page=await browser.newPage();page.setDefaultTimeout(12000);const errors=[];page.on('pageerror',e=>errors.push(e.message));

 const fixture=`const data={is_admin:false,completed:[],profile:{username:'trteststudent',full_name:'Test Öğrenci',grade:5,share_activity:true,show_online:true,join_leagues:true},economy:{energy:24,xp:120,gold:80,level:1,nextEnergySeconds:0}};window.__starts=[];window.turkceMember={data,user:{id:'fixture'},ready:Promise.resolve(),snapshot:()=>data,request:async(op,p)=>{if(op==='social')return {friends:[],feed:[]};if(op==='leagues')return {rows:[]};if(op==='start'){window.__starts.push(p);return {...data,attempt_id:crypto.randomUUID(),index:0,wrong:0,mistakes:0};}return data;}};window.practiceEconomy={snapshot:()=>data.economy};`;
 await page.route('**/member-client.js*',route=>route.fulfill({contentType:'text/javascript',body:fixture}));
 await page.goto(origin+'/parkur.html',{waitUntil:'networkidle'});
 for(const [width,height] of [[360,740],[390,844],[768,1024],[1440,900]]){
  await page.setViewportSize({width,height});await page.getByRole('button',{name:'Oyunlar',exact:true}).click();
  assert.equal(await page.locator('.modern-game-card').count(),3);assert.equal(await page.locator('#energyValue').count(),1);assert.equal(await page.locator('#energyValue').textContent(),'24/30');assert.equal(await page.locator('#xpValue').textContent(),'120');assert.equal(await page.locator('#goldValue').textContent(),'80');
  for(const selector of ['#energyValue','#xpValue','#goldValue','#accountLink'])assert(await page.locator(selector).isVisible());
  assert.equal(await page.locator('body').evaluate(e=>e.scrollWidth>innerWidth),false,`${width}: horizontal overflow`);
  for(const selector of ['.modern-play','.tabs button:not([hidden])'])for(const box of await page.locator(selector).evaluateAll(xs=>xs.map(e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}}))){assert(box.x>=0&&box.x+box.w<=width,`${width}: control outside viewport`);if(width>=768)assert(box.y+box.h<=height,`${width}: desktop/tablet control below fold`);}
  await page.screenshot({path:path.join(out,'games-'+width+'.png'),fullPage:true});
  await page.getByRole('button',{name:'Parkur',exact:true}).click();assert(await page.locator('#energyValue').isVisible());assert.equal(await page.locator('#mapCanvas .mobile-node').count(),24);
  await page.getByRole('button',{name:'Oyunlar',exact:true}).click();assert(await page.locator('.tab.active').getByText('Oyunlar',{exact:true}).isVisible());
  console.log('PASS approved games layout, live header indicators, navigation and overflow',width,height);
 }
 for(const name of ['Kelime Dedektifi','Olay Treni','Noktalama Tamircisi']){
  await page.getByRole('button',{name:name+' — Oyuna Başla',exact:true}).click();assert.equal(await page.locator('.q-card-left h3').textContent(),name);await page.evaluate(()=>closeModal());
 }
 assert.deepEqual(await page.evaluate(()=>__starts.map(x=>x.activity_id)),['kelime-dedektifi','olay-treni','noktalama-tamircisi']);
 assert.equal(await page.locator('[data-view=topicsView],#topicsView').count(),0);assert.equal(await page.locator('.games-context-label').count(),2);await page.getByRole('button',{name:'Arkadaşlar',exact:true}).click();assert(await page.locator('#friendsView').evaluate(e=>e.classList.contains('active')));await page.getByRole('heading',{name:'Arkadaşlarım ve istekler',exact:true}).waitFor();assert.equal(await page.locator('#friendsView input[type=checkbox]').count(),0);await page.locator('[data-view=leaguesView]').click();await page.locator('button[data-league=local]').waitFor();assert.equal(await page.locator('button[data-league=local]').isEnabled(),true);assert.deepEqual(errors,[]);console.log('PASS all game launchers, removed class tab, no social checkboxes, enabled leagues and no page errors');
}finally{await browser.close();await new Promise(r=>server.close(r));}})().catch(e=>{console.error(e);server.close();process.exit(1)});
