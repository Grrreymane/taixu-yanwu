'use strict';
// A fresh, non-persistent browser context is intentional: these checks never
// open the user's browser profile or modify a real player's local save.
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/run-save');
fs.mkdirSync(out,{recursive:true});
const report={passed:false,isolatedContext:true,errors:[],checks:[],snapshots:{}};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
const summary=s=>({
 phase:s.campaign.phase,mode:s.campaign.mode,stageIndex:s.campaign.stageIndex,runSeed:s.campaign.runSeed,
 runTimeMs:s.campaign.runTimeMs,bestTimeMs:s.campaign.bestTimeMs,runResumes:s.campaign.runResumes,
 saveStatus:s.campaign.saveStatus,resume:s.campaign.resume,fighter:s.fighter,paused:s.paused,
 countdown:s.stageCountdown,storyActive:s.story.active,ui:s.ui
});
const resumeIdentity=r=>({available:r.available,stageIndex:r.stageIndex,phase:r.phase,runTimeMs:r.runTimeMs,fighter:r.fighter});

(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 try{
  const page=await context.newPage();
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
  const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
  const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.snapshots[name]=summary(await read());save()};
  const menu=async()=>{await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu')};
  const live=()=>wait(()=>{const s=window.__godotState;return s.started&&s.campaign.phase==='fight'&&!s.story.active&&!s.bossEntrance.active&&s.stageCountdown<=0});
  const pause=async()=>{if(!(await read()).paused)await action('pause');await wait(()=>window.__godotState.paused);await page.waitForTimeout(100)};
  const choose=async(style,appearance)=>{
   await action('select_style:'+style);await wait(id=>window.__godotState.fighter.styleId===id,style);
   if(appearance){await action('select_appearance:'+appearance);await wait(id=>window.__godotState.fighter.appearanceId===id,appearance)}
  };
  await page.goto(process.env.TAIXU_TEST_URL||'http://127.0.0.1:4187/?v=run-save-1');
  await wait(()=>window.__godotState?.ready,null,180000);
  const fresh=await read();
  assert.equal(fresh.campaign.phase,'menu');
  assert.equal(fresh.campaign.resume.available,false,'new isolated browser has no previous run');
  const originalBest=fresh.campaign.bestTimeMs;
  await choose('night_squire','autumn_leaves');
  await action('start');await wait(()=>window.__godotState.story.active);
  await page.waitForTimeout(600);
  assert.equal((await read()).campaign.runTimeMs,0,'opening dialogue is excluded from the run clock');
  await action('story_skip');await wait(()=>!window.__godotState.story.active&&window.__godotState.stageCountdown>0);
  const opening=await read();
  assert.equal(opening.enemies.length,1);
  assert.ok(opening.player.x<0&&opening.enemy.x>0,'single-enemy opening puts player left');
  assert.equal(opening.player.facing,1);assert.equal(opening.enemy.facing,-1);
  assert.equal(opening.campaign.runTimeMs,0,'countdown is excluded from the run clock');
  const seed=opening.campaign.runSeed;
  const stageIndex=opening.campaign.stageIndex;
  await live();await action('move',-1);await action('guard_held',true);
  await wait(()=>window.__godotState.campaign.runTimeMs>=2200);
  await action('move',0);await pause();
  const stopped=await read();
  assert.ok(stopped.campaign.runTimeMs>=2200,'active battle contributes elapsed milliseconds');
  await page.waitForTimeout(650);
  assert.equal((await read()).campaign.runTimeMs,stopped.campaign.runTimeMs,'pause freezes run timer exactly');
  await shot('paused-timer');
  report.checks.push('Dialogue and countdown do not count; combat adds milliseconds and pause freezes the timer');
  report.checks.push('Single-enemy opening starts left/right facing inward before combat');

  await menu();
  await wait(()=>window.__godotState.campaign.resume.available);
  const saved=await read(),checkpoint=saved.campaign.resume;
  assert.equal(checkpoint.stageIndex,stageIndex);
  assert.equal(checkpoint.runTimeMs,stopped.campaign.runTimeMs,'returning to menu preserves elapsed battle time');
  assert.equal(checkpoint.fighter.styleId,'night_squire');
  assert.equal(checkpoint.fighter.appearanceId,'autumn_leaves');
  await shot('menu-continue');
  await choose('fenghuang','default');
  const continueRect=(await read()).ui.continueRect;
  assert.ok(continueRect[2]>0&&continueRect[3]>0,'continue button has a usable click target');
  await page.mouse.click(continueRect[0]+continueRect[2]/2,continueRect[1]+continueRect[3]/2);
  await wait(()=>window.__godotState.started&&window.__godotState.campaign.mode==='trial'&&window.__godotState.fighter.styleId==='night_squire');
  const restored=await read();
  assert.equal(restored.fighter.appearanceId,'autumn_leaves','continue restores the saved skin');
  assert.equal(restored.campaign.stageIndex,stageIndex);
  assert.equal(restored.campaign.runSeed,seed,'continue preserves the original seeded encounters');
  assert.ok(restored.campaign.runTimeMs>=checkpoint.runTimeMs,'continue never resets accrued time');
  assert.ok(restored.campaign.runResumes>=1,'continued run records its resume count');
  assert.ok(restored.player.x<0&&restored.enemy.x>0,'continued encounter restarts at its left/right opening');
  const firstResumeCount=restored.campaign.runResumes;
  await live();await action('move',-1);await action('guard_held',true);
  await wait(start=>window.__godotState.campaign.runTimeMs>=start+700,checkpoint.runTimeMs);
  const beforeReload=await read();
  await page.reload();await wait(()=>window.__godotState?.ready,null,180000);
  const reloaded=await read();
  assert.equal(reloaded.campaign.phase,'menu');
  assert.equal(reloaded.campaign.resume.available,true,'browser reload retains a resumable local trial');
  assert.equal(reloaded.campaign.resume.stageIndex,stageIndex);
  assert.equal(reloaded.campaign.resume.fighter.styleId,'night_squire');
  assert.equal(reloaded.campaign.resume.fighter.appearanceId,'autumn_leaves');
  assert.ok(reloaded.campaign.resume.runTimeMs>=beforeReload.campaign.runTimeMs,'pagehide saves recent time instead of only the prior periodic checkpoint');
  assert.ok(reloaded.campaign.resume.runTimeMs<=beforeReload.campaign.runTimeMs+1000,'loading time is not charged to the run');
  assert.equal(reloaded.campaign.bestTimeMs,originalBest,'an unfinished run never creates a clear record');
  await shot('reloaded-continue');
  report.checks.push('Menu continue restores armor, skin, stage and seed; an actual page reload preserves recent cumulative time');

  const trialSave=resumeIdentity(reloaded.campaign.resume);
  await choose('fenghuang','default');
  await action('practice');await live();await action('guard_held',true);
  await page.waitForTimeout(800);await pause();
  assert.equal((await read()).campaign.mode,'practice');
  await menu();
  const afterPractice=await read();
  assert.deepEqual(resumeIdentity(afterPractice.campaign.resume),trialSave,'practice cannot overwrite the suspended trial');
  assert.equal(afterPractice.campaign.bestTimeMs,originalBest,'practice cannot overwrite the best clear time');
  await page.reload();await wait(()=>window.__godotState?.ready,null,180000);
  assert.deepEqual(resumeIdentity((await read()).campaign.resume),trialSave,'trial save remains durable after practice and a second reload');
  await page.keyboard.press('Enter');
  await wait(()=>window.__godotState.started&&window.__godotState.campaign.mode==='trial');
  const resumedAgain=await read();
  assert.equal(resumedAgain.campaign.runSeed,seed);
  assert.equal(resumedAgain.campaign.stageIndex,stageIndex);
  assert.equal(resumedAgain.fighter.styleId,'night_squire');
  assert.equal(resumedAgain.fighter.appearanceId,'autumn_leaves');
  assert.ok(resumedAgain.campaign.runTimeMs>=trialSave.runTimeMs);
  assert.ok(resumedAgain.campaign.runResumes>firstResumeCount,'resume count persists across reloads');
  await live();await pause();await shot('continued-after-practice');
  report.checks.push('Practice cannot replace a suspended trial or set clear records; a second reload still restores that trial');
  assert.deepEqual(report.errors,[]);
  report.passed=true;save();console.log('RUN_SAVE_BROWSER_PASS');
 }finally{save();await context.close();await browser.close()}
})().catch(e=>{report.failure=e.stack;save();console.error(e);process.exitCode=1});
