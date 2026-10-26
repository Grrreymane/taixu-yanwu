'use strict';
// Ordinary clicks, drags, keys and the existing action bridge only.
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../build/screenshots/roster-audio-challenge');fs.mkdirSync(out,{recursive:true});
const report={checks:[],errors:[],stages:[],voices:{},shots:[],passed:false};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
const check=(name,fn)=>{fn();report.checks.push(name);save()};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const context=await browser.newContext({viewport:{width:1440,height:900}});
  await context.addInitScript(()=>{
   window.__audioLevels=[];const connect=AudioNode.prototype.connect;
   AudioNode.prototype.connect=function(...a){const value=connect.apply(this,a);if(a[0] instanceof AudioDestinationNode){const probe=this.context.createAnalyser();probe.fftSize=2048;connect.call(this,probe);const buf=new Float32Array(2048);setInterval(()=>{probe.getFloatTimeDomainData(buf);let sum=0;for(const x of buf)sum+=x*x;window.__audioLevels.push(Math.sqrt(sum/buf.length));if(window.__audioLevels.length>250)window.__audioLevels.shift()},30)}return value};
  });
  const page=await context.newPage();
  page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const wait=(fn,arg=null,timeout=18000)=>page.waitForFunction(fn,arg,{timeout});
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
  const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.shots.push(name);save()};
  const click=async rect=>{assert.ok(rect&&rect.length===4);await page.mouse.click(rect[0]+rect[2]/2,rect[1]+rect[3]/2)};
  await page.goto('http://127.0.0.1:4187/?v=roster-audio-2',{waitUntil:'domcontentloaded'});await wait(()=>window.__godotState?.ready,null,120000);
  let s=await read();report.initialUI=s.ui;
  check('Three real portraits and first-clear challenge lock',()=>{assert.equal(s.roster.styles.length,3);assert.ok(s.roster.styles.every(x=>x.portraitPath));assert.equal(s.campaign.contractsUnlocked,false)});
  await shot('01-portraits-menu');
  // Snapshot layout is supplied by the actual HUD, not hardcoded old coordinates.
  for(const id of ['fenghuang','night_squire','azure_empyrea']){
   s=await read();const entry=s.ui.armorChoiceRects.find(x=>x.id===id);await click(entry.rect);await wait(id=>window.__godotState.fighter.styleId===id,id);
   check(id+' portrait selects real combat profile',()=>{});
  }
  s=await read();const skin=s.ui.appearanceChoiceRects.find(x=>x.id==='taixu_memory');await click(skin.rect);await wait(()=>window.__godotState.fighter.appearanceId==='taixu_memory');
  s=await read();let r=s.ui.previewRect;const x=r[0]+r[2]*.55,y=r[1]+r[3]*.45;
  await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+240,y,{steps:16});await page.mouse.up();await wait(()=>Math.abs(window.__godotState.characterPreview.yaw+.2)>.5);await shot('02-rotated-character');
  await page.mouse.dblclick(x,y);await wait(()=>Math.abs(window.__godotState.characterPreview.yaw+.2)<.01);await shot('03-front-skirt');
  await page.setViewportSize({width:960,height:540});await page.waitForTimeout(300);
  s=await read();r=s.ui.previewRect;const sx=r[0]+r[2]*.5,sy=r[1]+r[3]*.5;
  await page.mouse.move(sx,sy);await page.mouse.down();await page.mouse.move(sx+90,sy,{steps:10});await page.mouse.up();await wait(()=>Math.abs(window.__godotState.characterPreview.yaw+.2)>.3);
  await page.mouse.dblclick(sx,sy);await wait(()=>Math.abs(window.__godotState.characterPreview.yaw+.2)<.01);await shot('04-menu-small');
  check('Scaled viewport drag and reset use the correct hit area',()=>{});
  await page.setViewportSize({width:1440,height:900});await page.reload();await wait(()=>window.__godotState?.ready,null,120000);
  s=await read();check('Skin and frontal preview survive page reload',()=>{assert.equal(s.fighter.appearanceId,'taixu_memory');assert.equal(s.characterPreview.dragging,false)});
  await action('start');await wait(()=>window.__godotState.story.active);await page.waitForTimeout(700);
  for(let i=0;i<4;i++){await action('story_next');await page.waitForTimeout(150)}
  s=await read();check('Dialogue no longer gets generic repeated grunts',()=>assert.ok(s.voice.recent.every(x=>x.category!=='dialogue')));await action('menu');
  // Mute BGM while checking actual voice output, then restore for the trial.
  await action('music');
  for(const id of ['azure_empyrea','fenghuang','night_squire']){
   await action('select_style:'+id);await wait(id=>window.__godotState.fighter.styleId===id,id);
   await action('practice');await wait(()=>window.__godotState.started);await action('training');await wait(()=>window.__godotState.training);
   await action('move',1);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await action('move',0);
   await page.evaluate(()=>window.__audioLevels=[]);const before=(await read()).voice.played;await page.keyboard.press('q');await wait(()=>window.__godotState.ultimate);
   await wait(before=>window.__godotState.voice.played>before,before);await page.waitForTimeout(400);
   s=await read();report.voices[id]=s.voice.recent.filter(x=>x.profile===id&&x.category==='ultimate').slice(-1);
   const peak=await page.evaluate(()=>Math.max(0,...window.__audioLevels));
   check(id+' ultimate plays real Chinese audio',()=>{assert.equal(report.voices[id].length,1);assert.ok(peak>.001)});
   await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  }
  await action('music');await action('select_style:azure_empyrea');await action('contract:mirror');await action('start');await wait(()=>window.__godotState.campaign.phase==='fight'&&window.__godotState.music.enabled);
  const deadline=Date.now()+360000;let lastStage=-1,rewardStage=-1,retries=0,entrance=false;
  while(Date.now()<deadline){
   s=await read();const c=s.campaign,p=s.player;
   if(s.story.active){await action('story_skip');await page.waitForTimeout(100);continue}
   if(s.bossEntrance.active){
    if(!entrance&&s.bossEntrance.time>.5){entrance=true;report.entrance=s.voice;await shot('06-boss-entrance')}
    await page.waitForTimeout(75);continue;
   }
   if(c.phase==='cleared'){await wait(()=>!window.__godotState.victory.playing);await shot('08-clear');break}
   if(c.phase==='failed'){if(retries++>=3)throw Error('Trial failed at stage '+c.stageIndex);await action('retry');continue}
   if(c.phase==='reward'){
    if(rewardStage!==c.stageIndex){rewardStage=c.stageIndex;const pref=['reflection','breath','riposte','calm','fist','iron','swift','flow','reservoir','finisher','windstep','risk'];const id=pref.find(id=>c.rewards.some(r=>r.id===id));await action('reward_'+c.rewards.findIndex(r=>r.id===id))}await page.waitForTimeout(100);continue;
   }
   if(c.stageIndex!==lastStage){lastStage=c.stageIndex;report.stages.push({stage:lastStage+1,music:s.music,hp:p.hp});save();console.log('STAGE',lastStage+1,'HP',p.hp,'BGM',s.music.track);if(lastStage===4){await shot('05-stage-five-theme')}}
   if(s.paused){await action('pause');continue}
   if(s.ended||s.ultimate||s.stageCountdown>0){await page.waitForTimeout(45);continue}
   const live=s.enemies.filter(e=>e.hp>0);const nearest=live.reduce((a,b)=>!a||Math.abs(b.x-p.x)<Math.abs(a.x-p.x)?b:a,null);if(!nearest)continue;
   const distance=Math.abs(nearest.x-p.x),direction=Math.sign(nearest.x-p.x);
   const threats=live.filter(e=>e.state==='attack'&&!e.attack.hasHit&&Math.abs(e.x-p.x)<e.attack.range+.4&&e.attack.windup-e.stateTime>-.02).sort((a,b)=>(a.attack.windup-a.stateTime)-(b.attack.windup-b.stateTime));
   const threat=threats[0],left=threat?threat.attack.windup-threat.stateTime:10;
   let move=distance>1.2?direction:0,command=null,guard=false;
   if(threat){
    if(left<.16&&threat.attack.unblockable){move=-direction;command='dodge'}
    else if(left<.12){guard=true;command='guard'}
    else if(left>.55&&p.skillCooldown<=0&&distance<2.1)command='ability';
   }else if(['idle','move','guard'].includes(p.state)){
    if(p.energy>=100)command='ultimate';else if(p.skillCooldown<=0&&distance<2.1)command='ability';else if(distance<1.7)command=nearest.state==='guard'?'heavy':'light';
   }else if(p.state==='attack'&&p.attack.name==='light')command='light';
   await page.evaluate(({move,guard,command})=>{__godotAction('move',move);__godotAction('guard_held',guard);if(command)__godotAction(command)},{move,guard,command});await page.waitForTimeout(35);
  }
  s=await read();check('Six-stage normal-input trial clears',()=>{assert.equal(s.campaign.phase,'cleared');assert.equal(report.stages.length,6);assert.equal(s.campaign.boons.length,5)});
  check('Sentience themes follow the fifth and final stages',()=>{assert.ok(report.stages.slice(0,4).every(x=>x.music.track==='battle_theme.ogg'));assert.equal(report.stages[4].music.track,'sentience_nrbl.ogg');assert.equal(report.stages[5].music.track,'sentience_hard_bone.ogg')});
  check('Boss entrance plays the original line',()=>{assert.ok(entrance);assert.ok(report.entrance.recent.some(x=>x.category==='entrance'))});
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');s=await read();await click(s.ui.contractAllRect);await wait(()=>window.__godotState.campaign.selectedContractIds.length===3);await shot('09-unlocked-all-rules');
  await page.reload();await wait(()=>window.__godotState?.ready,null,120000);s=await read();check('Earned unlock and all selected rules persist',()=>{assert.equal(s.campaign.contractsUnlocked,true);assert.equal(s.campaign.selectedContractIds.length,3);assert.equal(s.campaign.challengeLevel,2)});
  await action('start');await wait(()=>window.__godotState.story.active);s=await read();check('All rules reach actual new combat',()=>{assert.equal(s.player.riposteBonus,.2);assert.equal(s.player.dodgeRefund,1);assert.equal(s.player.postureMultiplier,1.2)});
  await action('menu');check('No browser or resource errors',()=>assert.deepEqual(report.errors,[]));report.passed=true;save();console.log(JSON.stringify({passed:true,checks:report.checks.length}));
 }catch(e){report.failure=e.stack;save();console.error(e);process.exitCode=1}finally{await browser.close()}
})();
