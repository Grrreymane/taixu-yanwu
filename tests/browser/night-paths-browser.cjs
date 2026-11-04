'use strict';
// Fresh browser saves and ordinary menu/combat input only.
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
const out='build/screenshots/night-paths-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={passed:false,errors:[],cases:[]};
 try{
  const p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const state=()=>p.evaluate(()=>window.__godotState);
  const action=(name,value)=>p.evaluate(({name,value})=>__godotAction(name,value),{name,value});
  const wait=(fn,arg=null)=>p.waitForFunction(fn,arg,{timeout:30000});
  const url=process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=night-paths';
  await p.goto(url);await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  await action('select_style:night_squire');
  await wait(()=>__godotState.player.style==='night_squire');
  for(const core of ['counter','dodge','chain']){
   await action('trial');await wait(()=>__godotState.nightCoreChoice);
   assert.equal((await state()).campaign.clockRunning,false);
   if(core==='counter'){
    await p.screenshot({path:out+'/core.png'});
    await p.keyboard.press('Escape');await wait(()=>!__godotState.nightCoreChoice&&__godotState.campaign.phase==='menu');
    await action('trial');await wait(()=>__godotState.nightCoreChoice);
   }
   if(core==='dodge')await p.mouse.click(720,468);
   else await p.keyboard.press(String(['counter','dodge','chain'].indexOf(core)+1));
   await wait(core=>__godotState.campaign.nightCore===core&&__godotState.story.active,core);
   await action('story_skip');
   let offered=null,mechanicSeen=false;const begin=Date.now();
   while(Date.now()-begin<100000){
    const s=await state(),c=s.campaign,pl=s.player;
    if(c.phase==='reward'){offered=c.rewards;break}
    assert.notEqual(c.phase,'failed','first stage should remain approachable');
    if(s.stageCountdown>0||s.ended){await p.waitForTimeout(50);continue}
    const enemy=s.enemies.find(e=>e.hp>0);if(!enemy)continue;
    const gap=Math.abs(enemy.x-pl.x),direction=Math.sign(enemy.x-pl.x);
    const threat=enemy.state==='attack'&&!enemy.attack.hasHit&&gap<enemy.attack.range+.3&&enemy.attack.windup-enemy.stateTime>0&&enemy.attack.windup-enemy.stateTime<.18;
    let move=gap>1.25?direction:0,guard=false,command=null;
    if(threat){if(core==='dodge'||enemy.attack.unblockable)command='dodge';else guard=true}
    else if(pl.nightFlowUntil>s.time||pl.nightChaseUntil>s.time)command='ability';
    else if(pl.riposteUntil>s.time&&core==='counter')command='heavy';
    else if(['idle','move','guard'].includes(pl.state)&&gap<1.8){
     const waitingForDefense=(core==='counter'&&s.stats.parries===0)||(core==='dodge'&&s.stats.dodges===0);
     if(!waitingForDefense)command=enemy.state==='guard'?'heavy':'light';
    }
    else if(pl.state==='attack'&&pl.attack.name==='light')command='light';
    mechanicSeen ||= !!pl.attack.nightImpact||!!pl.attack.nightFlow||pl.nightResumeUntil>s.time;
    await p.evaluate(({move,guard,command})=>{__godotAction('move',move);__godotAction('guard_held',guard);if(command)__godotAction(command)},{move,guard,command});
    await p.waitForTimeout(35);
   }
   assert.ok(offered,'first clear reaches reward selection');
   assert.ok(mechanicSeen,'selected core actually triggered during browser combat');
   const index=offered.findIndex(x=>x.core===core);assert.ok(index>=0,'matching special card offered');
   assert.ok(offered.every(x=>!x.core||x.core===core));
   await p.screenshot({path:out+'/'+core+'-reward.png'});
   await p.keyboard.press(String(index+1));
   await wait(()=>__godotState.campaign.stageIndex===1&&__godotState.campaign.phase==='fight');
   if((await state()).story.active)await action('story_skip');
   const before=await state();
   assert.ok(before.player.nightPerks[offered[index].id]);
   await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
   await p.reload();await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
   assert.ok((await state()).campaign.resume.available);
   await action('continue');
   await wait(core=>__godotState.player.nightCore===core&&__godotState.campaign.stageIndex===1,core);
   assert.ok((await state()).player.nightPerks[offered[index].id]);
   report.cases.push({core,card:offered[index].id,mechanicSeen,resume:true});
   console.log('NIGHT_BROWSER_CORE '+JSON.stringify(report.cases.at(-1)));
   await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
  }
  await action('select_style:azure_empyrea');await action('trial');
  await wait(()=>__godotState.nightCoreChoice);
  await p.keyboard.press('1');await wait(()=>__godotState.story.active);
  assert.equal((await state()).nightCoreChoice,false);assert.equal((await state()).player.armorCore,'az_balance');assert.equal((await state()).player.nightCore,'');
  assert.deepEqual(report.errors,[]);report.passed=true;
 }finally{fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));await browser.close()}
 console.log('NIGHT_PATHS_BROWSER_PASS');
})().catch(e=>{console.error(e);process.exitCode=1});
