'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/wardrobe-grid');fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],errors:[],snapshots:{}};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
  const wait=(fn,arg=null,time=20000)=>page.waitForFunction(fn,arg,{timeout:time});
  const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.snapshots[name]=await read();save()};
  const click=async r=>page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);
  const style=async id=>{const s=await read();await click(s.ui.armorChoiceRects.find(x=>x.id===id).rect);await wait(id=>window.__godotState.fighter.styleId===id,id)};
  const skin=async id=>{const s=await read();await click(s.ui.appearanceChoiceRects.find(x=>x.id===id).rect);await wait(id=>window.__godotState.fighter.appearanceId===id,id);await page.waitForTimeout(350)};
  await page.goto('http://127.0.0.1:4187/?v=wardrobe-grid-1');await wait(()=>window.__godotState?.ready,null,180000);
  const initial=await read();assert.equal(initial.roster.styles.length,5);
  assert.equal(new Set(initial.ui.armorChoiceRects.map(x=>Math.round(x.rect[1]))).size,2);
  for(const c of initial.ui.armorChoiceRects){assert.ok(c.rect[0]>=0&&c.rect[0]+c.rect[2]<=1440&&c.rect[1]+c.rect[3]<=900);await style(c.id)}
  report.checks.push('All five armor portraits are clickable in two visible rows');
  await style('night_squire');assert.equal((await read()).roster.appearances.length,5);
  for(const id of ['default','autumn_leaves','spring_traveler','xuanyi_sushang','black_butler']){await skin(id);await shot('night-'+id)}
  await skin('xuanyi_sushang');
  for(const [width,height] of [[960,540],[1440,900]]){
   await page.setViewportSize({width,height});await page.waitForTimeout(200);
   const s=await read();assert.equal(new Set(s.ui.armorChoiceRects.map(x=>Math.round(x.rect[1]))).size,2);
   for(const c of s.ui.appearanceChoiceRects)assert.ok(c.rect[0]>=0&&c.rect[0]+c.rect[2]<=width&&c.rect[1]+c.rect[3]<=height);
   await shot('wardrobe-'+width);
  }
  await page.reload();await wait(()=>window.__godotState?.ready,null,180000);assert.equal((await read()).fighter.appearanceId,'xuanyi_sushang');
  report.checks.push('Five Night Squire outfits fit at both viewport sizes and persist after reload');
  for(const id of ['spring_traveler','xuanyi_sushang','black_butler']){
   await skin(id);await action('start');await wait(()=>window.__godotState.story.active);await page.waitForTimeout(600);await shot('dialogue-'+id);await action('menu');
   await action('practice');await wait(()=>window.__godotState.started&&window.__godotState.stageCountdown<=0&&!window.__godotState.bossEntrance.active);
   await action('training');await wait(()=>window.__godotState.training);await action('move',1);
   await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await action('move',0);
   const hp=(await read()).enemy.hp;await page.keyboard.press('e');await page.waitForTimeout(650);await shot('skill-'+id);await wait(()=>window.__godotState.player.state==='idle');assert.ok((await read()).enemy.hp<hp);
   await page.keyboard.press('q');await wait(()=>window.__godotState.ultimate);await wait(()=>!window.__godotState.ultimate);assert.ok((await read()).player.nightBurstRemaining>0);await shot('burst-'+id);
   await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  }
  report.checks.push('All three added outfits use playable native skill and burst animations');
  await style('shadow_knight');
  for(const id of ['default','blood_moon']){
   await skin(id);await shot('moon-arms-'+id);
   const s=await read(),r=s.ui.previewRect,x=r[0]+r[2]*.55,y=r[1]+r[3]*.5;
   await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+250,y,{steps:16});await page.mouse.up();await page.waitForTimeout(200);await shot('moon-arms-rotated-'+id);await page.mouse.dblclick(x,y);
   await action('practice');await wait(()=>window.__godotState.started&&window.__godotState.stageCountdown<=0&&!window.__godotState.bossEntrance.active);
   await action('training');await wait(()=>window.__godotState.training);await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await action('move',0);
   await page.keyboard.press('e');await page.waitForTimeout(450);await shot('moon-arms-strike-'+id);await wait(()=>window.__godotState.player.state==='idle');
   await page.keyboard.press('q');await wait(()=>window.__godotState.ultimate);await wait(()=>!window.__godotState.ultimate);await page.waitForTimeout(100);await shot('moon-arms-eclipse-'+id);
   assert.ok((await read()).player.eclipseRemaining>0);await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  }
  report.checks.push('Both Moon outfits render original equipment in normal and eclipse forms');
  assert.deepEqual(report.errors,[]);report.passed=true;save();console.log('WARDROBE_GRID_BROWSER_PASS');
 }finally{save();await browser.close()}
})().catch(e=>{report.failure=e.stack;save();console.error(e);process.exitCode=1});
