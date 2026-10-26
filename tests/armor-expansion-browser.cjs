'use strict';
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../build/screenshots/armor-expansion');fs.mkdirSync(out,{recursive:true});
const report={checks:[],errors:[],snapshots:{},passed:false};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
  const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(cmd,value)=>page.evaluate(({cmd,value})=>window.__godotAction(cmd,value),{cmd,value});
  const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.snapshots[name]=await state();save()};
  await page.goto('http://127.0.0.1:4187/?v=armor-expansion-1');await wait(()=>window.__godotState?.ready,null,180000);
  assert.equal((await state()).roster.styles.length,5);report.checks.push('five selectable armors');
  for(const [style,skin] of [['shadow_knight','blood_moon'],['shadow_knight','default'],['fenghuang','fire_and_sword'],['hawk_of_the_fog','default']]){
   await action('select_style:'+style);await wait(s=>window.__godotState.fighter.styleId===s,style);
   await action('select_appearance:'+skin);await wait(s=>window.__godotState.fighter.appearanceId===s,skin);await page.waitForTimeout(650);
   await shot('menu-'+style+'-'+skin);
  }
  await action('start');await wait(()=>window.__godotState.story.active);await page.waitForTimeout(700);await shot('fog-dialogue');
  await action('story_skip');await wait(()=>window.__godotState.stageCountdown>0);await shot('spawn-countdown');
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  for(const [style,skin] of [['shadow_knight','blood_moon'],['hawk_of_the_fog','default'],['fenghuang','fire_and_sword']]){
   await action('select_style:'+style);await wait(s=>window.__godotState.fighter.styleId===s,style);
   await action('select_appearance:'+skin);await wait(s=>window.__godotState.fighter.appearanceId===s,skin);
   await action('practice');await wait(()=>window.__godotState.started&&window.__godotState.stageCountdown<=0&&!window.__godotState.bossEntrance.active);
   await action('training');await wait(()=>window.__godotState.training);
   await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.3);await action('move',0);
   const before=(await state()).enemy.hp;
   await page.keyboard.press('e');await page.waitForTimeout(430);await shot('skill-'+style);
   await wait(()=>window.__godotState.player.state==='idle');assert.ok((await state()).enemy.hp<before);
   const energy=(await state()).player.energy;assert.ok(energy>=100);
   await page.keyboard.press('q');await wait(()=>window.__godotState.ultimate);await page.waitForTimeout(style==='shadow_knight'?1000:style==='hawk_of_the_fog'?400:2400);await shot('ultimate-'+style);
   await wait(()=>!window.__godotState.ultimate);await page.waitForTimeout(150);
   const after=await state();assert.ok(after.voice.recent.some(v=>v.profile===style&&v.category==='ultimate'));
   await shot('after-ultimate-'+style);
   if(style==='shadow_knight'){
    assert.ok(after.player.eclipseRemaining>0);await shot('blood-moon-eclipse');
    await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.3);await action('move',0);
    await page.keyboard.press('j');await page.waitForTimeout(250);await shot('eclipse-strike');
   }
   if(style==='fenghuang')assert.ok(after.vfx.fireRoles.includes('original_sword_field'),'source sword array must appear');
   report.checks.push(style+' skill damage, Q and original voice');save();
   await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  }
  await page.setViewportSize({width:960,height:540});await page.waitForTimeout(300);await shot('menu-small');
  assert.deepEqual(report.errors,[]);report.passed=true;save();console.log('ARMOR_EXPANSION_BROWSER_PASS');
 }finally{save();await browser.close()}
})().catch(e=>{report.failure=e.stack;save();console.error(e);process.exitCode=1});
