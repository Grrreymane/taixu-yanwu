'use strict';
// Exercise exported resources through the normal menu and player action bridge.
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/skin-expression-web');
fs.mkdirSync(out,{recursive:true});
const report={checks:[],errors:[],samples:[]};
const check=(label,fn)=>{fn();report.checks.push(label);};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
  const wait=(fn,arg,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
  const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
  await page.goto('http://127.0.0.1:4187/?v=skin-expression-1');
  await wait(()=>window.__godotState?.ready,null,90000);
  await action('select_style:azure_empyrea');
  await wait(()=>window.__godotState.fighter.styleId==='azure_empyrea');
  await action('select_appearance:taixu_memory');
  await wait(()=>window.__godotState.fighter.appearanceId==='taixu_memory');
  await wait(()=>window.__godotState.feel.player.secondaryMotion?.maxAngle>.005);
  let s=await read();
  check('Skin has its own 14 cloth/hair chains and original facial atlas in Web export',()=>{
   assert.equal(s.feel.player.secondaryMotion.boneCount,66);
   assert.equal(s.feel.player.secondaryMotion.chainCount,14);
   assert.equal(s.feel.player.facial.enabled,true);
  });
  await wait(()=>window.__godotState.feel.player.facial.blink,null,22000);
  s=await read();report.samples.push({type:'blink',facial:s.feel.player.facial});
  check('Menu blinks using distinct original left and right eye cells',()=>{
   assert.notDeepEqual(s.feel.player.facial.eyeL,s.feel.player.facial.eyeR);
   assert.deepEqual(s.feel.player.facial.mouth,[0,.75]);
  });
  await shot('01-menu-blink');
  await action('practice');await wait(()=>window.__godotState.campaign.phase==='fight');
  await action('training');await wait(()=>window.__godotState.training);
  await action('move',1);
  await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.5);
  await action('move',0);
  await action('guard_held',true);
  await wait(()=>window.__godotState.feel.player.motion==='guard');
  s=await read();
  check('Guard has focused expression while the skin follows the defensive pose',()=>{
   assert.equal(s.feel.player.facial.frame,'focused');
   assert.ok(s.feel.player.secondaryMotion.maxAngle>0);
  });
  await shot('02-guard');await action('guard_held',false);
  await action('light');
  await wait(()=>window.__godotState.events.some(e=>e.type==='hit'&&e.side==='player'));
  await wait(()=>['idle','move'].includes(window.__godotState.player.state));
  await action('ultimate');
  await wait(()=>window.__godotState.ultimateTime>.30&&window.__godotState.feel.player.facial.frame==='closed');
  await action('pause');await wait(()=>window.__godotState.paused);
  s=await read();const frozen=s.feel.player;
  await page.waitForTimeout(350);s=await read();
  check('Real cinematic pause freezes face, cloth and body diagnostics exactly',()=>{
   assert.deepEqual(s.feel.player,frozen);
   assert.equal(s.feel.player.facial.frame,'closed');
  });
  await shot('03-ultimate-eyes-closed');await action('pause');
  await wait(()=>window.__godotState.ultimateTime>1.1);
  s=await read();check('Release opens the eyes and resumes secondary motion',()=>{
   assert.notEqual(s.feel.player.facial.frame,'closed');
   assert.ok(s.feel.player.secondaryMotion.time>frozen.secondaryMotion.time);
  });
  await wait(()=>!window.__godotState.ultimate);
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  await action('select_style:fenghuang');await wait(()=>window.__godotState.fighter.styleId==='fenghuang');
  s=await read();check('Phoenix retains its own clothing animation and gets facial playback',()=>{
   assert.equal(s.feel.player.secondaryMotion.enabled,false);
   assert.equal(s.feel.player.facial.enabled,true);
  });
  await action('select_style:azure_empyrea');await wait(()=>window.__godotState.fighter.appearanceId==='taixu_memory');
  await page.reload();await wait(()=>window.__godotState?.ready,null,90000);
  s=await read();check('Reload restores the skin with the dynamic resources available',()=>{
   assert.equal(s.fighter.appearanceId,'taixu_memory');
   assert.equal(s.feel.player.secondaryMotion.enabled,true);
   assert.equal(s.feel.player.facial.enabled,true);
  });
  await shot('04-final-menu');
  check('Browser has no errors',()=>assert.deepEqual(report.errors,[]));
  report.passed=true;
 }catch(e){report.passed=false;report.failure=e.stack;process.exitCode=1;}
 finally{
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));await browser.close();
 }
})();
