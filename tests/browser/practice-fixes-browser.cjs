'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/practice-fixes');fs.mkdirSync(out,{recursive:true});
const report={checks:[],errors:[]};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const page=await browser.newPage({viewport:{width:1280,height:800}});
 const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
 const act=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
 const wait=(fn,arg=null,timeout=30000)=>page.waitForFunction(fn,arg,{timeout});
 const click=async rect=>{await page.mouse.move(rect[0]+rect[2]/2,rect[1]+rect[3]/2);await page.mouse.down();await page.waitForTimeout(220);await page.mouse.up();};
 const resultButton=async name=>click((await read()).ui.resultButtons[name].rect);
 page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 try{
  await page.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=practice-native');
  await wait(()=>window.__godotState?.ready,null,180000);
  await act('practice');await wait(()=>window.__godotState.ui.infiniteHpVisible);
  const r=(await read()).ui.infiniteHpRect;
  await page.mouse.move(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(1000);
  await page.screenshot({path:path.join(out,'tooltip.png')});
  await click(r);await wait(()=>window.__godotState.infiniteHp);
  const health=await read();assert.equal(health.player.hp,health.player.maxHp);assert.equal(health.enemy.hp,health.enemy.maxHp);
  await act('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await act('move',0);
  await wait(()=>['idle','move','guard'].includes(window.__godotState.player.state));await act('ultimate');
  await wait(()=>window.__godotState.ultimate);await wait(()=>!window.__godotState.ultimate);
  await page.waitForTimeout(1200);
  let s=await read();assert.equal(s.player.hp,s.player.maxHp);assert.equal(s.enemy.hp,s.enemy.maxHp);assert.ok(s.stats.damageDealt>0);
  report.checks.push('Both sides retain full HP through an ultimate with active enemy AI');
  await act('pause');await wait(()=>window.__godotState.paused);await page.screenshot({path:path.join(out,'practice.png')});await act('pause');
  await act('practice');await wait(()=>window.__godotState.time<1&&window.__godotState.infiniteHp);report.checks.push('Restart retains infinite health');
  await click((await read()).ui.infiniteHpRect);await wait(()=>!window.__godotState.infiniteHp);
  await act('training');await wait(()=>window.__godotState.training);
  async function win(){
   const deadline=Date.now()+120000;
   while(Date.now()<deadline){
    const s=await read();if(s.victory.visible){await act('move',0);await act('victory_skip');await wait(()=>window.__godotState.ui.resultButtons.VictoryAgain.visible);return;}
    if(s.paused){await act('pause');continue;}
    if(s.ended||s.ultimate){await page.waitForTimeout(100);continue;}
    const d=s.enemy.x-s.player.x;await act('move',Math.abs(d)>1.1?Math.sign(d):0);
    if(Math.abs(d)<2.5&&['idle','move'].includes(s.player.state))await act(s.player.energy>=100?'ultimate':s.player.skillCooldown<=0?'ability':'heavy');
    await page.waitForTimeout(65);
   }throw Error('Practice did not finish through normal inputs');
  }
  await win();await page.screenshot({path:path.join(out,'results.png')});
  const plays=(await read()).victory.plays;await resultButton('VictoryReplay');await wait(n=>window.__godotState.victory.plays===n+1,plays);await act('victory_skip');
  await wait(()=>window.__godotState.ui.resultButtons.VictoryAgain.visible);await act('background');await act('foreground');await page.waitForTimeout(250);assert.equal((await read()).victory.paused,false);
  await resultButton('VictoryAgain');await wait(()=>window.__godotState.campaign.phase==='fight'&&!window.__godotState.victory.visible);
  report.checks.push('Replay and restart work with a 220 ms mouse press across UI refreshes; finished results survive focus changes');
  await win();await page.setViewportSize({width:960,height:540});await page.waitForTimeout(350);await resultButton('VictoryMenu');await wait(()=>window.__godotState.campaign.phase==='menu');
  report.checks.push('Return home works at 960 x 540');
  await act('practice');await wait(()=>window.__godotState.started);await act('training');await wait(()=>window.__godotState.training);await win();await resultButton('VictoryOtherMode');
  await wait(()=>window.__godotState.campaign.mode==='trial'&&window.__godotState.campaign.phase==='fight');assert.equal((await read()).infiniteHp,false);
  report.checks.push('Start trial works and cannot inherit infinite health');assert.deepEqual(report.errors,[]);report.passed=true;
 }catch(e){report.failure=e.stack;report.state=await read().catch(()=>null);await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});throw e;}
 finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();console.log(JSON.stringify({passed:report.passed,checks:report.checks,errors:report.errors}));}
})().catch(e=>{console.error(e);process.exitCode=1});
