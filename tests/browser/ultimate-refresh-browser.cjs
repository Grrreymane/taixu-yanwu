'use strict';
// Browser acceptance uses only existing menu/combat actions. The telemetry is
// read-only; no HP, SP, animation time, stage or random seed is patched.
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/ultimate-refresh-web');
fs.mkdirSync(out,{recursive:true});
const report={passed:false,errors:[],cases:[],encounter:null};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=name=>page.evaluate(name=>window.__godotAction(name),name);
  const wait=(predicate,arg=null)=>page.waitForFunction(predicate,arg,{timeout:30000});
  await page.goto('http://127.0.0.1:4187/?v=ultimate-encounters-2');
  await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  for(const profile of ['azure_empyrea','fenghuang','night_squire','shadow_knight','hawk_of_the_fog']){
   await action('menu'); await wait(()=>window.__godotState.campaign.phase==='menu');
   await action('select_style:'+profile); await wait(profile=>window.__godotState.player.style===profile,profile);
   await action('practice'); await wait(()=>window.__godotState.started&&window.__godotState.campaign.mode==='practice');
   if(!(await state()).training)await action('training');
   await wait(()=>window.__godotState.training);
   await action('ultimate');
   await wait(()=>window.__godotState.ultimate&&window.__godotState.ultimateTime>=0.15);
   await action('pause'); await wait(()=>window.__godotState.paused);
   const held=await state();
   await page.waitForTimeout(200); const still=await state();
   assert.equal(held.ultimateTime,still.ultimateTime,'paused native animation clock');
   assert.deepEqual(held.cinematic,still.cinematic,'paused camera');
   assert.deepEqual(held.feel.ultimateFocus,still.feel.ultimateFocus,'paused screen framing');
   assert.ok(held.feel.ultimateFocus.active,'ultimate focus available in exported Web');
   await action('pause'); await wait(()=>!window.__godotState.paused);
   const shots=new Set([held.cinematic.shot]),compositions=new Set([held.cinematic.composition]);
   let peak=0,lastTime=-1,frames=0;
   for(let i=0;i<250;i++){
    const s=await state();
    if(!s.ultimate)break;
    assert.ok(s.ultimateTime>=lastTime);lastTime=s.ultimateTime;
    assert.ok(Number.isFinite(s.cinematic.fov)&&s.cinematic.position[2]>0);
    shots.add(s.cinematic.shot);compositions.add(s.cinematic.composition);
    peak=Math.max(peak,s.vfx.total);frames++;
    await page.waitForTimeout(35);
   }
   await wait(()=>!window.__godotState.ultimate);
   await page.waitForTimeout(350);
   const after=await state();
   assert.ok(!after.feel.ultimateFocus.active,'framing clears at handoff');
   assert.ok(shots.size>=3,'distinct shot phases');
   assert.ok(compositions.has('portrait')&&compositions.has('full'),'portrait and action framing');
   assert.ok(peak>0&&peak<=112,'VFX produced within active-layer budget');
   report.cases.push({profile,shots:[...shots],compositions:[...compositions],peakLayers:peak,frames,pausePassed:true});save();
  }
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  await action('start');await wait(()=>window.__godotState.story.active);
  await action('story_skip');await wait(()=>!window.__godotState.story.active);
  await wait(()=>window.__godotState.stageCountdown<=0);
  const s=await state();
  assert.ok(s.campaign.encounterRule.id&&s.campaign.arrangementTitle&&s.campaign.encounterObjective.id);
  assert.ok(s.enemies.every(e=>['press','guard','range','flank'].includes(e.tactic)));
  assert.ok(s.campaign.encounterObjective.bonus.includes('8 SP'));
  report.encounter={title:s.campaign.arrangementTitle,rule:s.campaign.encounterRule,objective:s.campaign.encounterObjective};
  await page.screenshot({path:path.join(out,'encounter.png')});
  assert.deepEqual(report.errors,[]);report.passed=true;save();console.log('ULTIMATE_REFRESH_BROWSER_PASS '+JSON.stringify(report.cases));
 }finally{await browser.close()}
})().catch(error=>{report.failure=error.stack;save();console.error(error);process.exitCode=1});
