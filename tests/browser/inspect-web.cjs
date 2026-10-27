const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const page=await browser.newPage({viewport:{width:1440,height:900}});
 const logs=[];
 page.on('console',m=>{logs.push(m.type()+': '+m.text());if(m.type()==='error'||m.text().includes('DUEL'))console.log(m.type(),m.text());});
 page.on('pageerror',e=>{logs.push(e.stack);console.log('PAGEERROR',e.message)});
 page.on('requestfailed',r=>console.log('REQUEST FAILED',r.url(),r.failure()));
 await page.goto('http://127.0.0.1:4187/');
 await page.waitForTimeout(15000);
 await page.screenshot({path:path.resolve(__dirname,'../../build/screenshots/diagnose-web.png')});
 fs.writeFileSync(path.resolve(__dirname,'../../build/screenshots/web-log.txt'),logs.join('\n'));
 console.log('DOM',await page.locator('body').innerText());
 console.log('STATE',await page.evaluate(()=>({ready:window.__godotReady,state:window.__godotState})));
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
