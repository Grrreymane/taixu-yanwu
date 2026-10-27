'use strict';
// UI clicks and existing normal action bridge; telemetry is read-only.
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/roster-web');
const report={checks:[],errors:[],milestones:[]};
fs.mkdirSync(out,{recursive:true});
function save(){fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));}
function check(label,fn){fn();report.checks.push(label);save();}
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
  const wait=(fn,arg,timeout=15000)=>page.waitForFunction(fn,arg,{timeout});
  const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
  await page.goto('http://127.0.0.1:4187/?v=phoenix-skin-1');
  await wait(()=>window.__godotState?.ready,null,90000);
  await page.mouse.click(166,366); // Yun Mo style
  await wait(()=>window.__godotState.fighter.styleId==='azure_empyrea');
  await page.mouse.click(313,445); // Taixuan Impression appearance
  await wait(()=>window.__godotState.fighter.appearanceId==='taixu_memory');
  let s=await read();
  check('Skin UI changes actual selected model configuration',()=>{assert.equal(s.roster.styles.length,2);assert.equal(s.roster.appearances.length,2);assert.equal(s.fighter.skinName,'太虚仙忆');});
  await shot('01-yunmo-taixu-memory');
  await page.mouse.click(313,366); // Phoenix
  await wait(()=>window.__godotState.fighter.styleId==='fenghuang');
  s=await read();
  check('Phoenix UI applies its battle profile and E stance switch',()=>{assert.equal(s.fighter.styleName,'炽翎');assert.equal(s.fighter.abilityName,'换式');assert.equal(s.player.style,'fenghuang');assert.equal(s.player.skillCooldownMax,1.35);});
  await shot('02-phoenix-menu');
  await page.reload();await wait(()=>window.__godotState?.ready,null,90000);
  s=await read();check('Reload restores Phoenix selection',()=>assert.equal(s.fighter.styleId,'fenghuang'));
  await page.mouse.click(166,366);await wait(()=>window.__godotState.fighter.styleId==='azure_empyrea');
  s=await read();check('Other style remembers its skin after reload',()=>assert.equal(s.fighter.appearanceId,'taixu_memory'));
  await page.mouse.click(313,366);await wait(()=>window.__godotState.fighter.styleId==='fenghuang');
  await page.setViewportSize({width:960,height:540});await page.waitForTimeout(250);await shot('03-selection-small');
  await page.setViewportSize({width:1280,height:800});await page.waitForTimeout(100);
  await page.mouse.click(238,572);
  await wait(()=>window.__godotState.campaign.phase==='fight');
  await action('select_style:azure_empyrea');
  s=await read();check('In-fight selection is refused',()=>assert.equal(s.fighter.styleId,'fenghuang'));
  await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.65);await action('move',0);
  await page.keyboard.press('q');await wait(()=>window.__godotState.ultimate);
  await wait(()=>window.__godotState.ultimateTime>.75);await page.keyboard.press('Escape');await wait(()=>window.__godotState.paused);
  const frozen=(await read()).ultimateTime;await page.waitForTimeout(250);
  s=await read();check('Phoenix cinematic pauses on the same pose',()=>assert.equal(s.ultimateTime,frozen));
  await shot('04-phoenix-ultimate-pause');await page.keyboard.press('Escape');
  await wait(()=>window.__godotState.ultimateTime>1.30);await shot('05-phoenix-ultimate-rise');
  await wait(()=>window.__godotState.ultimateTime>2.80);await shot('06-phoenix-ultimate-impact');
  await wait(()=>!window.__godotState.ultimate);
  s=await read();check('Phoenix ultimate deals both actual hits and returns to battle',()=>{assert.equal(s.events.filter(e=>e.type==='ultHit'&&e.style==='fenghuang').length,2);assert.equal(s.player.energy,0);assert.ok(s.enemy.hp<=60);});
  await page.keyboard.press('e');await wait(()=>window.__godotState.player.stance==='kick');
  s=await read();check('E switches to kick stance',()=>{assert.equal(s.player.stance,'kick');assert.ok(s.player.skillCooldown>0);});
  await page.keyboard.press('j');await page.waitForTimeout(260);await shot('07-phoenix-kick');
  const until=Date.now()+30000;
  while(Date.now()<until){
   s=await read();if(s.campaign.phase==='cleared')break;if(s.campaign.phase==='failed')throw new Error('Lost practice');
   if(s.paused){await page.keyboard.press('Escape');continue;}
   const p=s.player,e=s.enemy,d=Math.abs(e.x-p.x);
   let command=null,guard=false;
   const threat=e.state==='attack'&&!e.attack.hasHit&&d<e.attack.range+.2&&e.attack.windup-e.stateTime<.17&&e.attack.windup-e.stateTime>0;
   if(['idle','move','guard'].includes(p.state)){
    if(threat){if(e.attack.unblockable)command='dodge';else guard=true;}
    else if(d<2.15)command=e.state==='guard'?'heavy':'light';
   }else if(p.state==='attack'&&p.attack.name==='light'&&p.stateTime>.10)command='light';
   await page.evaluate(({move,guard,command})=>{window.__godotAction('move',move);window.__godotAction('guard_held',guard);if(command)window.__godotAction(command);},{move:d>1.3?Math.sign(e.x-p.x):0,guard,command});
   await page.waitForTimeout(50);
  }
  await action('move',0);await action('guard_held',false);
  await wait(()=>window.__godotState.victory.visible);
  s=await read();check('A normal AI practice fight reaches Phoenix native victory',()=>{assert.equal(s.winner,'player');assert.equal(s.training,false);assert.equal(s.feel.player.victoryAvailable,true);});
  await wait(()=>window.__godotState.victory.time>1.6);await shot('08-phoenix-victory');
  await wait(()=>!window.__godotState.victory.playing);await shot('09-phoenix-results');
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  await action('select_style:azure_empyrea');await wait(()=>window.__godotState.fighter.styleId==='azure_empyrea');
  await action('practice');await wait(()=>window.__godotState.campaign.phase==='fight');
  await page.keyboard.press('t');await wait(()=>window.__godotState.training);
  await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await action('move',0);
  await page.keyboard.press('j');await wait(()=>window.__godotState.events.some(e=>e.type==='hit'&&e.side==='player'&&e.style==='azure_empyrea'));
  await page.keyboard.press('l');await page.waitForTimeout(120);await shot('10-skin-in-combat');
  s=await read();check('Yun Mo skin still uses original battle actions and cooldown',()=>{assert.equal(s.fighter.appearanceId,'taixu_memory');assert.equal(s.player.style,'azure_empyrea');assert.equal(s.player.skillCooldownMax,8);});
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  await action('select_style:fenghuang');await wait(()=>window.__godotState.fighter.styleId==='fenghuang');
  s=await read();report.milestones.push({finalRoster:s.roster,finalFighter:s.fighter});
  check('No browser errors',()=>assert.deepEqual(report.errors,[]));
  report.passed=true;save();console.log(JSON.stringify({passed:true,checks:report.checks.length,errors:report.errors}));
 }catch(error){report.passed=false;report.failure=error.stack;save();console.error(error);process.exitCode=1;}
 finally{await browser.close();}
})();
