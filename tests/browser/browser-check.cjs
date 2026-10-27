const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:1});
  const errors=[],logs=[];page.on('pageerror',e=>{errors.push(e.message);console.log('PAGEERROR',e.message)});page.on('console',m=>{logs.push(m.text());if(m.type()==='error'){errors.push(m.text());console.log('CONSOLE ERROR',m.text())}});
  page.on('response',r=>{if(r.status()>=400)console.log('HTTP ERROR',r.status(),r.url())});
  const started=Date.now();await page.goto('http://127.0.0.1:4187/');
  await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:90000});
  console.log('Loaded after',Date.now()-started,'ms');
  await page.waitForTimeout(1600);await page.screenshot({path:path.join(out,'01-menu.png')});
  await page.locator('canvas').click({position:{x:700,y:400}});
  await page.evaluate(()=>__godotAction('practice'));
  await page.evaluate(()=>__godotAction('training'));
  await page.waitForTimeout(1800);await page.screenshot({path:path.join(out,'02-arena.png')});
  const act=async name=>page.evaluate(n=>__godotAction(n),name);
  await page.keyboard.down('d');await page.waitForFunction(()=>Math.abs(__godotState.enemy.x-__godotState.player.x)<1.25);await page.keyboard.up('d');
  await act('light');await page.waitForFunction(()=>__godotState.player.state==='attack'&&__godotState.player.stateTime>.10);await act('light');
  await page.waitForFunction(()=>__godotState.player.attack?.comboIndex===1&&__godotState.player.stateTime>.10);await act('light');
  await page.waitForFunction(()=>__godotState.player.state==='idle');
  assert.equal(await page.evaluate(()=>__godotState.enemy.hp),77,'Three native combo strikes connect');
  await page.screenshot({path:path.join(out,'03-combo.png')});
  await act('ultimate');await page.waitForFunction(()=>__godotState.ultimateTime>.3);await page.screenshot({path:path.join(out,'04-ultimate.png')});
  await page.waitForFunction(()=>__godotState.ultimateTime>2.65);await page.screenshot({path:path.join(out,'05-impact.png')});
  await page.waitForFunction(()=>!__godotState.ultimate);
  assert.equal(await page.evaluate(()=>__godotState.enemy.hp),41);
  await act('pause');await page.waitForFunction(()=>__godotState.paused);
  const stopped=await page.evaluate(()=>__godotState.time);await page.waitForTimeout(250);assert.equal(await page.evaluate(()=>__godotState.time),stopped);
  await act('pause');await act('restart');await page.waitForTimeout(250);
  assert.equal(await page.evaluate(()=>__godotState.enemy.hp),100);
  await act('training');await page.waitForFunction(()=>__godotState.player.hp<100,null,{timeout:15000});
  await act('pause');await page.setViewportSize({width:650,height:900});await page.waitForTimeout(800);await page.screenshot({path:path.join(out,'06-narrow.png')});
  fs.writeFileSync(path.join(out,'browser-report.json'),JSON.stringify({errors,logs,state:await page.evaluate(()=>__godotState)},null,2));
  console.log('Errors:',JSON.stringify(errors));console.log('PASS: Godot web load, combo, ultimate, pause, reset, AI, resize');
  assert.equal(errors.length,0,'No browser or engine errors');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
