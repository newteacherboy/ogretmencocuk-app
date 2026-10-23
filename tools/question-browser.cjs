const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),out=process.env.UI_SCREEN_DIR||'/tmp/turkce-question-ui';fs.mkdirSync(out,{recursive:true});
const mime={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml'};
const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://local'),file=path.resolve(root,'.'+(u.pathname==='/'?'/index.html':decodeURIComponent(u.pathname)));if(!file.startsWith(root+path.sep)||!fs.existsSync(file)){res.writeHead(404);return res.end('missing')}res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file))});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;const options={headless:true};if(process.env.BROWSER_EXECUTABLE){options.executablePath=process.env.BROWSER_EXECUTABLE;options.args=process.env.BROWSER_SINGLE_PROCESS==='1'?['--no-sandbox','--no-zygote','--single-process','--disable-dev-shm-usage']:['--no-sandbox'];}const browser=await chromium.launch(options);
try{const page=await browser.newPage();page.setDefaultTimeout(12000);const errors=[];page.on('pageerror',e=>errors.push(e.message));

 const fixture=`const data={is_admin:false,completed:[],profile:{username:'trteststudent',grade:5},economy:{energy:30,xp:0,gold:0,level:1,nextEnergySeconds:0}};window.turkceMember={data,user:{id:'fixture'},ready:Promise.resolve(),snapshot:()=>data,request:async(op,p)=>{if(op==='start')return {...data,attempt_id:'fixture',index:0,wrong:0,mistakes:0};if(op==='answer'){const q=stops[0].questions[p.index];const answer=q.answerOrder??q.answer;return {...data,correct:JSON.stringify(p.answer)===JSON.stringify(answer),advanced:true,index:p.index+1,correct_answer:answer,done:false};}return data;}};window.practiceEconomy={snapshot:()=>data.economy};`;
 await page.route('**/member-client.js*',route=>route.fulfill({contentType:'text/javascript',body:fixture}));
 await page.goto(origin+'/parkur.html',{waitUntil:'networkidle'});
 for(const [width,height] of [[360,740],[390,844],[768,1024],[1440,900]]){
  await page.setViewportSize({width,height});await page.evaluate(()=>startStop(1));
  await page.locator('.question-illustration img').waitFor();await page.waitForFunction(()=>{const img=document.querySelector('.question-illustration img');return img?.complete&&img.naturalWidth>0});
  await page.locator('.option[data-index="0"]').click();await page.locator('#actionBtn').click();await page.getByText('Doğru cevap:',{exact:false}).waitFor();
  assert.match(await page.locator('#feedbackBox').textContent(),/B — İp atlama/);assert.equal(await page.locator('.option.correct').getAttribute('data-index'),'1');assert.equal(await page.locator('.option.wrong').getAttribute('data-index'),'0');assert.equal(await page.locator('#optionsArea button:disabled').count(),4);
  let box=await page.locator('#actionBtn').boundingBox();assert(box&&box.y>=0&&box.y+box.height<=height,`${width}: next must remain visible`);
  await page.screenshot({path:path.join(out,'question-wrong-'+width+'.png'),fullPage:true});
  await page.locator('#actionBtn').click();assert.match(await page.locator('.q-card-left h3').textContent(),/2. Soru/);
  await page.evaluate(()=>{state.currentQuestionIndex=2;renderQuestion()});await page.locator('#actionBtn').click();await page.getByText('Doğru cevap:',{exact:false}).waitFor();assert.match(await page.locator('#feedbackBox').textContent(),/1. Ebeyi belirlemek/);assert.equal(await page.locator('#orderList button:enabled').count(),0);
  box=await page.locator('#actionBtn').boundingBox();assert(box&&box.y+box.height<=height,`${width}: ordered solution next visible`);
  await page.screenshot({path:path.join(out,'question-order-'+width+'.png'),fullPage:true});
  await page.locator('#actionBtn').click();await page.waitForFunction(()=>{const img=document.querySelector('.question-illustration img');return img?.complete&&img.naturalWidth>0});await page.locator('.option[data-index="0"]').click();await page.locator('#actionBtn').click();assert.match(await page.locator('#feedbackBox').textContent(),/D — Kayak/);
  assert.equal(await page.locator('body').evaluate(e=>e.scrollWidth>innerWidth),false);
  console.log('PASS illustrations, wrong/correct marks, locked answers, manual next and ordered solution',width,height);
 }
 await page.route('**/assets/questions/playground.webp?broken=1',route=>route.abort());await page.evaluate(()=>{state.currentQuestionIndex=3;renderQuestion();document.querySelector('.question-illustration img').src='assets/questions/playground.webp?broken=1'});await page.locator('.question-illustration figcaption:not([hidden])').waitFor();assert.match(await page.locator('.question-illustration').textContent(),/top.*kaydırak.*salıncak/);assert.deepEqual(errors,[]);console.log('PASS accessible equivalent scene fallback and no page errors');
}finally{await browser.close();await new Promise(r=>server.close(r));}})().catch(e=>{console.error(e);server.close();process.exit(1)});
