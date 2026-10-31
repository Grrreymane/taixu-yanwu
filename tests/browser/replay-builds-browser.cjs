'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path');
const out=path.resolve(__dirname,'../../build/screenshots/replay-builds-web');
fs.mkdirSync(out,{recursive:true});
const report={passed:false,errors:[],checks:[]};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const act=n=>page.evaluate(n=>window.__godotAction(n),n);
  const wait=(f,a=null,timeout=30000)=>page.waitForFunction(f,a,{timeout});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  await page.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=replay-builds');
  await wait(()=>window.__godotState?.ready,null,180000);
  assert.equal((await state()).campaign.rulesVersion,'trial-2026-10-31-builds');
  await act('trial');await wait(()=>window.__godotState.story.active);await act('story_skip');
  let won=false;
  for(let n=0;n<1300;n++){
   const s=await state(),p=s.player;
   if(s.campaign.phase==='reward'){won=true;break;}
   assert.notEqual(s.campaign.phase,'failed','ordinary first encounter survived');
   if(s.story.active){await act('story_skip');continue;}
   if(s.stageCountdown>0||s.ended||s.ultimate){await page.waitForTimeout(65);continue;}
   const foes=s.enemies.filter(e=>e.hp>0);
   const target=foes.sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x))[0];
   if(!target){await page.waitForTimeout(65);continue;}
   const gap=Math.abs(target.x-p.x);
   const danger=foes.find(e=>e.state==='attack'&&!e.attack.hasHit&&Math.abs(e.x-p.x)<e.attack.range+.3&&e.attack.windup-e.stateTime>0&&e.attack.windup-e.stateTime<.15);
   let command=null,guard=false;
   if(danger){if(danger.attack.unblockable)command='dodge';else guard=true;}
   else if(['idle','move','guard'].includes(p.state)){
    if(p.energy>=100)command='ultimate';
    else if(p.skillCooldown<=0&&gap<2.2)command='ability';
    else if(gap<1.7)command=target.state==='guard'?'heavy':'light';
   }else if(p.state==='attack'&&p.attack.name==='light')command='light';
   await page.evaluate(({move,guard,command})=>{
    window.__godotAction('move',move);window.__godotAction('guard_held',guard);
    if(command)window.__godotAction(command);
   },{move:gap>1.3?Math.sign(target.x-p.x):0,guard,command});
   await page.waitForTimeout(65);
  }
  assert.ok(won,'ordinary inputs reach actual reward screen');
  await page.evaluate(()=>{window.__godotAction('move',0);window.__godotAction('guard_held',false)});
  const first=await state();
  assert.equal(first.campaign.rerollsRemaining,2);
  assert.ok(first.campaign.rewards.every(r=>r.buildPreview));
  assert.ok(first.campaign.nextEncounter);
  await page.screenshot({path:path.join(out,'reward-large.png')});
  const ids=s=>s.campaign.rewards.map(r=>r.id);
  const clickReroll=async()=>{
   const {width:w,height:h}=page.viewportSize(),scale=Math.max(.4,Math.min(1.8,w/1280,h/800));
   await page.mouse.click(w/2,h/2+283*scale);
  };
  await clickReroll();
  await wait(()=>window.__godotState.campaign.rerollsRemaining===1);
  const redrawn=await state();
  assert.ok(ids(redrawn).every(id=>!ids(first).includes(id)));
  assert.equal(redrawn.campaign.rewardIds.length,0);
  report.checks.push('mouse reroll replaces all three cards without spending a pick');
  await page.waitForTimeout(300);
  await page.reload();await wait(()=>window.__godotState?.ready,null,180000);
  assert.equal((await state()).campaign.resume.phase,'reward');
  await act('continue');await wait(()=>window.__godotState.campaign.phase==='reward');
  assert.deepEqual(ids(await state()),ids(redrawn));
  assert.equal((await state()).campaign.rerollsRemaining,1);
  report.checks.push('browser reload restores same choices and remaining reroll');
  await page.setViewportSize({width:960,height:540});await page.waitForTimeout(300);
  await clickReroll();await wait(()=>window.__godotState.campaign.rerollsRemaining===0);
  const exhausted=await state();
  await clickReroll();await page.waitForTimeout(200);
  assert.deepEqual(ids(await state()),ids(exhausted));
  await page.screenshot({path:path.join(out,'reward-small.png')});
  const cards=exhausted.campaign.rewards;
  const newer=['crosswind','chainflow','afterglow','crack','focus','sustain'];
  let chosen=cards.findIndex(c=>newer.includes(c.id));if(chosen<0)chosen=0;
  const scale=.675;
  await page.mouse.click(480+(-335+335*chosen)*scale,270-45*scale);
  await wait(()=>window.__godotState.campaign.stageIndex===1);
  const acquired=await state();
  assert.deepEqual(acquired.campaign.rewardIds,[cards[chosen].id]);
  report.chosen=cards[chosen];
  const hook={crosswind:['dodgeStrike',.45],chainflow:['finisherRefund',1.2],afterglow:['afterglowBonus',.25],crack:['breakBonus',.25],focus:['riposteRefund',2],sustain:['killHeal',4]}[cards[chosen].id];
  if(hook)assert.equal(acquired.player[hook[0]],hook[1],'selected modifier reaches runtime fighter');
  report.checks.push('small-screen card click applies exactly one actual reward');
  await act('reward_'+chosen);await page.waitForTimeout(150);
  assert.deepEqual((await state()).campaign.rewardIds,[cards[chosen].id]);
  if((await state()).story.active)await act('story_skip');
  await wait(()=>!window.__godotState.story.active);
  await act('menu');
  assert.deepEqual(report.errors,[]);
  report.passed=true;
 }catch(error){report.failure=String(error.stack||error);throw error}
 finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();console.log(JSON.stringify(report));}
})().catch(()=>process.exitCode=1);
