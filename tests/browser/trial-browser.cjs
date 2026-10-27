const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/trial');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const errors=[],milestones=[];
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>{errors.push(e.message);console.log('PAGE ERROR',e.message)});
  page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log('ERROR',m.text())}});
  await page.goto('http://127.0.0.1:4187/?v=trial');await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:60000});
  await page.waitForTimeout(800);await page.screenshot({path:path.join(out,'00-menu.png')});
  await page.mouse.click(260,525);await page.waitForFunction(()=>__godotState.started);
  await page.keyboard.press('t');await page.waitForTimeout(150);assert.equal(await page.evaluate(()=>__godotState.training),false,'Trial cannot disable enemy AI');
  const began=Date.now();let lastStage=-1,rewardStage=-1,skillShot=false,ultShot=false,retries=0;
  while(Date.now()-began<360000){
   const s=await page.evaluate(()=>window.__godotState);const c=s.campaign,p=s.player;
   if(c.phase==='cleared'){
    await page.screenshot({path:path.join(out,'99-cleared.png')});milestones.push({kind:'cleared',stats:c.stats});break;
   }
   if(c.phase==='failed'){
    console.log('FAILED stage',c.stageIndex+1,c.stats);await page.screenshot({path:path.join(out,'failed-'+c.stageIndex+'.png')});
    if(retries++>=1)throw new Error('Normal-input bot could not clear stage '+(c.stageIndex+1));
    await page.evaluate(()=>__godotAction('retry'));await page.waitForTimeout(250);continue;
   }
   if(c.phase==='reward'){
    if(rewardStage!==c.stageIndex){
     rewardStage=c.stageIndex;milestones.push({kind:'reward',stage:c.stageIndex+1,hp:p.hp,stats:c.stats});
     console.log('Cleared stage',c.stageIndex+1,'HP',p.hp,'time',c.stats.elapsed);
     await page.screenshot({path:path.join(out,'reward-'+c.stageIndex+'.png')});
     const choice=c.rewards.findIndex(r=>r.id==='breath');
     await page.keyboard.press(String((choice<0?0:choice)+1));
    }
    await page.waitForTimeout(120);continue;
   }
   if(c.stageIndex!==lastStage){
    lastStage=c.stageIndex;console.log('Entered',c.title,'enemies',s.enemies.length,'HP',p.hp);
    await page.waitForTimeout(600);await page.screenshot({path:path.join(out,'stage-'+c.stageIndex+'.png')});
   }
   if(s.paused){await page.keyboard.press('Escape');continue;}
   if(s.ended){await page.waitForTimeout(120);continue;}
   if(s.ultimate){
    if(!ultShot&&s.ultimateTime>.6){ultShot=true;await page.screenshot({path:path.join(out,'ultimate.png')});}
    await page.waitForTimeout(65);continue;
   }
   const live=s.enemies.filter(e=>e.hp>0);const nearest=live.reduce((best,e)=>!best||Math.abs(e.x-p.x)<Math.abs(best.x-p.x)?e:best,null);
   if(!nearest){await page.waitForTimeout(100);continue;}
   const distance=Math.abs(nearest.x-p.x),direction=Math.sign(nearest.x-p.x);
   const threat=live.find(e=>e.state==='attack'&&!e.attack.hasHit&&Math.abs(e.x-p.x)<e.attack.range+.3&&e.attack.windup-e.stateTime>0&&e.attack.windup-e.stateTime<.19);
   const move=distance>1.3?direction:0;
   let command=null,guard=false;
   if(['idle','move','guard'].includes(p.state)){
    if(threat){if(threat.attack.unblockable)command='dodge';else guard=true;}
    else if(p.energy>=100)command='ultimate';
    else if(p.skillCooldown<=0&&distance<2.5)command='ability';
    else if(distance<1.7)command=nearest.state==='guard'?'heavy':'light';
   }else if(p.state==='attack'&&p.attack.name==='light'&&p.stateTime>.1){
    command=nearest.state==='guard'?'heavy':'light';
   }
   await page.evaluate(({move,guard,command})=>{__godotAction('move',move);__godotAction('guard_held',guard);if(command)__godotAction(command)},{move,guard,command});
   if(!skillShot&&p.state==='attack'&&p.attack.name==='ability'&&p.stateTime>.7){skillShot=true;await page.screenshot({path:path.join(out,'ability.png')});}
   await page.waitForTimeout(65);
  }
  const final=await page.evaluate(()=>__godotState);
  fs.writeFileSync(path.join(out,'trial-report.json'),JSON.stringify({errors,milestones,state:final},null,2));
  assert.equal(final.campaign.phase,'cleared','All six fights completed with normal player actions');
  assert.equal(final.campaign.stageIndex,5);assert.equal(final.campaign.boons.length,5);assert.equal(errors.length,0);
  await page.reload();await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:60000});
  assert.ok((await page.evaluate(()=>__godotState.campaign.bestScore))>0,'Best score survives page reload');
  console.log('PASS: six-stage browser trial, rewards, multi-enemy fights, boss, records; errors=0');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
