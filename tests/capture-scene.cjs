const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>console.log('ERROR',e.message));page.on('console',m=>{if(m.type()==='error')console.log('ERROR',m.text())});
  await page.goto('http://127.0.0.1:4187/');await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:60000});
  await page.waitForTimeout(1200);await page.screenshot({path:path.resolve(__dirname,'../build/screenshots/01-menu.png')});
  await page.mouse.click(260,525);await page.waitForFunction(()=>__godotState.started);
  await page.keyboard.press('t');await page.waitForTimeout(2500);
  await page.screenshot({path:path.resolve(__dirname,'../build/screenshots/02-arena.png')});
  await page.keyboard.press('q');await page.waitForFunction(()=>__godotState.ultimateTime>.3);
  await page.screenshot({path:path.resolve(__dirname,'../build/screenshots/04-ultimate.png')});
  await page.waitForFunction(()=>__godotState.ultimateTime>2.65);
  await page.screenshot({path:path.resolve(__dirname,'../build/screenshots/05-impact.png')});
  console.log('Scene screenshots captured');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
