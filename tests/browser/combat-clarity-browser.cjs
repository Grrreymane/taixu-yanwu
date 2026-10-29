'use strict';
// Real input acceptance. Fresh storage; no debug actions, training, state
// mutations, damage/HP injection or time manipulation are used to clear fights.
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const uiOnly=process.argv.includes('--ui-only');
const out=path.resolve(__dirname,'../../build/screenshots/'+(uiOnly?'combat-clarity-web-ui':'combat-clarity-web'));fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],shots:[],errors:[],kos:[],encounters:[],rewards:[],storage:'Disposable context, ordinary UI and keyboard actions only'};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({viewport:{width:1440,height:900}}),page=await context.newPage();
 page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
 const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
 const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
 const check=(name,body)=>{body();report.checks.push(name);save()};
 const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.shots.push(name);save()};
 const rectClick=async field=>{let s=await read(),r=s.ui[field];await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2)};
 try{
  await page.goto('http://127.0.0.1:4187/?v=ko-flow-1',{waitUntil:'domcontentloaded'});
  await wait(()=>window.__godotState?.ready,null,120000);
  for(const style of ['azure_empyrea','fenghuang','night_squire']){
   await action('select_style:'+style);await wait(style=>window.__godotState.fighter.styleId===style,style);
   await rectClick('guideEntryRect');await wait(()=>window.__godotState.ui.guideOpen);
   const guideState=await read();
   check('Actual guide button opens '+style,()=>assert.equal(guideState.ui.guideOpen,true));
   await page.keyboard.press('j');await page.keyboard.press('q');
   let s=await read();check('Guide prevents gameplay commands for '+style,()=>{assert.equal(s.started,false);assert.equal(s.campaign.phase,'menu');assert.equal(s.ui.guideStyle,style)});
   await shot('guide-'+style);await page.keyboard.press('Escape');await wait(()=>!window.__godotState.ui.guideOpen);
  }
  await page.setViewportSize({width:960,height:540});await page.waitForTimeout(250);
  await rectClick('guideEntryRect');await wait(()=>window.__godotState.ui.guideOpen);
  const smallGuide=(await read()).ui;
  check('Small guide stays centered inside the actual browser viewport',()=>{
   const r=smallGuide.guidePanelRect,v=smallGuide.viewportSize;
   assert.ok(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=v[0]+1&&r[1]+r[3]<=v[1]+1);
   assert.ok(Math.abs(r[0]+r[2]/2-v[0]/2)<1);
  });await shot('guide-small');
  await page.mouse.move(500,350);await page.mouse.wheel(0,700);await page.waitForTimeout(250);await shot('guide-small-bottom');
  await rectClick('guideCloseRect');await wait(()=>!window.__godotState.ui.guideOpen);
  if(uiOnly){
   check('No browser rendering or script errors',()=>assert.deepEqual(report.errors,[]));
   report.passed=true;save();console.log(JSON.stringify({passed:true,scope:'guide UI after layout-only repair',checks:report.checks.length}));return;
  }
  await action('select_style:azure_empyrea');await wait(()=>window.__godotState.fighter.styleId==='azure_empyrea');
  await action('start');await wait(()=>window.__godotState.story.active);await action('story_skip');
  const deadline=Date.now()+9*60*1000;
  const koPlays=new Set(),rewardStages=new Set();let pausedKoTested=false,cleared=false;
  let currentStage=-1;
  while(Date.now()<deadline){
   const s=await read(),p=s.player;
   assert.equal(s.training,false,'Live enemy AI remains enabled');
   if(s.story.active){await action('story_skip');await page.waitForTimeout(70);continue}
   if(s.bossEntrance?.active){await page.waitForTimeout(80);continue}
   if(s.paused){await action('pause');continue}
   if(s.ko.active){
    if(!koPlays.has(s.ko.plays)&&s.ko.time>.15){
     koPlays.add(s.ko.plays);report.kos.push({stage:s.campaign.stageIndex,winner:s.ko.winner,time:s.ko.time,plays:s.ko.plays});
     assert.equal(s.campaign.phase,'fight','KO precedes reward/result commit');
     await shot('ko-stage-'+(s.campaign.stageIndex+1));
     if(!pausedKoTested){
      await page.keyboard.press('Escape');await wait(()=>window.__godotState.ko.paused);
      const before=await read();await action('reward_0');await action('light');await page.waitForTimeout(220);const after=await read();
      check('KO pause freezes presentation and rejects early reward/combat',()=>{assert.equal(after.ko.time,before.ko.time);assert.equal(after.campaign.phase,'fight');assert.deepEqual(after.campaign.rewardIds,before.campaign.rewardIds)});
      await page.keyboard.press('Escape');await wait(()=>!window.__godotState.ko.paused);pausedKoTested=true;
     }
    }
    await page.waitForTimeout(35);continue;
   }
   if(s.campaign.phase==='failed')throw new Error('Normal-input route lost stage '+(s.campaign.stageIndex+1));
   if(s.campaign.phase==='cleared'){
    check('Six encounters reach a real victory',()=>{assert.equal(s.winner,'player');assert.equal(report.rewards.length,5);assert.equal(koPlays.size,6)});
    await shot('victory');cleared=true;break;
   }
   if(s.campaign.phase==='reward'){
    const stage=s.campaign.stageIndex;
    assert.ok(!rewardStages.has(stage),'Reward commits once per stage');rewardStages.add(stage);
    const colors=s.ui.rewardCardColors;check('All offers start equally colored in stage '+(stage+1),()=>{assert.equal(colors.length,3);assert.equal(colors[0],colors[1]);assert.equal(colors[1],colors[2])});
    await action('move',0);await action('guard_held',false);await shot('reward-'+(stage+1));
    const wanted=p.hp<p.maxHp*.65?['breath','calm','reflection','fist','swift','iron','reservoir','flow','finisher','riposte','windstep','risk']:['fist','swift','iron','reservoir','flow','breath','calm','reflection','finisher','riposte','windstep','risk'];
    const choice=s.campaign.rewards.reduce((best,v,i,a)=>wanted.indexOf(v.id)<wanted.indexOf(a[best].id)?i:best,0);
    report.rewards.push({stage,choice,id:s.campaign.rewards[choice].id});save();
    await page.keyboard.press(String(choice+1));await wait(stage=>window.__godotState.campaign.stageIndex===stage+1,stage);continue;
   }
   if(s.stageCountdown>0||s.ended||s.ultimate){await page.waitForTimeout(45);continue}
   if(currentStage!==s.campaign.stageIndex){
    currentStage=s.campaign.stageIndex;
    report.encounters.push({stage:currentStage+1,startingHp:p.hp,health:s.healthDisplay});
    const living=s.enemies.filter(e=>e.hp>0),primary=s.healthDisplay.primaryId;
    check('One health source per enemy in stage '+(currentStage+1),()=>{
     for(const enemy of living)assert.equal(Number(primary===enemy.id)+Number(s.healthDisplay.overheadIds.includes(enemy.id)),1);
     assert.equal(s.ui.primaryHealthVisible,!!primary);
    });await shot('fight-'+(currentStage+1));
   }
   const live=s.enemies.filter(e=>e.hp>0),nearest=live.reduce((best,e)=>!best||Math.abs(e.x-p.x)<Math.abs(best.x-p.x)?e:best,null);
   if(!nearest){await page.waitForTimeout(40);continue}
   const distance=Math.abs(nearest.x-p.x);
   const threat=live.find(e=>e.state==='attack'&&e.attack&&!e.attack.hasHit&&Math.abs(e.x-p.x)<e.attack.range+.3&&e.attack.windup-e.stateTime>-.04&&e.attack.windup-e.stateTime<.23);
   let command=null,guard=false;
   if(threat){if(threat.attack.unblockable)command='dodge';else guard=true}
   else if(['idle','move','guard'].includes(p.state)){
    if(p.energy>=100&&distance<2.5)command='ultimate';
    else if(p.skillCooldown<=0&&distance<2.5)command='ability';
    else if(distance<1.8)command=nearest.state==='guard'?'heavy':'light';
   }else if(p.state==='attack'&&p.attack.name==='light'&&p.stateTime>.1)command=nearest.state==='guard'?'heavy':'light';
   await page.evaluate(({move,guard,command})=>{window.__godotAction('move',move);window.__godotAction('guard_held',guard);if(command)window.__godotAction(command)},
    {move:threat?.attack.unblockable?Math.sign(p.x-threat.x):distance>1.3?Math.sign(nearest.x-p.x):0,guard,command});
   report.encounters.at(-1).lastHp=p.hp;report.encounters.at(-1).damageTaken=s.stats.damageTaken;
   await page.waitForTimeout(40);
  }
  assert.ok(cleared,'Nine-minute live play acceptance deadline');
  check('No browser rendering or script errors',()=>assert.deepEqual(report.errors,[]));report.passed=true;save();console.log(JSON.stringify({passed:true,checks:report.checks.length,kos:report.kos.length,rewards:report.rewards.length}));
 }catch(e){report.failure=e.stack;save();throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
