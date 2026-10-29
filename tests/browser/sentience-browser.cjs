const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const manuscript=require('../../scripts/data/sentience_story_scenes.json');
const sceneSize=id=>manuscript.scenes[id].lines.length+manuscript.scenes[id].stageDirections.length;
const out=path.resolve(__dirname,'../../build/screenshots/reward-story-full');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const errors=[],milestones=[];
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>{errors.push(e.message);console.log('PAGE ERROR',e.message)});
  page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log('ERROR',m.text())}});
  await page.goto('http://127.0.0.1:4187/?v=reward-story-1');await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:60000});
  await page.waitForTimeout(800);await page.screenshot({path:path.join(out,'00-menu.png')});
  await page.evaluate(()=>__godotAction('select_style:azure_empyrea'));
  await page.evaluate(()=>__godotAction('practice'));
  await page.waitForFunction(()=>__godotState.started&&__godotState.campaign.mode==='practice'&&__godotState.feel?.enemy?.modelPath?.includes('/sentience/'));
  await page.evaluate(()=>__godotAction('pause'));
  await page.waitForFunction(()=>__godotState.paused);
  const practice=await page.evaluate(()=>__godotState);
  assert.equal(practice.enemy.name,'识之律者');assert.equal(practice.enemy.characterId,'herrscher_of_sentience');
  assert.equal(practice.enemy.style,'sentience');assert.ok(practice.feel.enemy.modelPath.includes('/sentience/'));
  assert.match(String(practice.feel.enemy.adaptationSource),/Native C6/,'Actual enemy loads original C6 reconstruction');
  assert.equal(practice.vfx.sentience.nativeTextures,13,'All original Sentience effect textures are loaded');
  milestones.push({kind:'practice',enemy:practice.enemy,presentation:practice.feel.enemy});
  await page.screenshot({path:path.join(out,'01-practice.png')});
  await page.evaluate(()=>__godotAction('menu'));
  await page.waitForFunction(()=>__godotState.campaign.phase==='menu');
  await page.evaluate(()=>__godotAction('trial'));await page.waitForFunction(()=>__godotState.started&&__godotState.campaign.mode==='trial');
  await page.keyboard.press('t');await page.waitForTimeout(150);assert.equal(await page.evaluate(()=>__godotState.training),false,'Trial cannot disable enemy AI');
  const began=Date.now();let lastStage=-1,rewardStage=-1,skillShot=false,ultShot=false,retries=0,deathShot=false;
  const stories=new Set(),weapons=new Set(),weaponShots=new Set(),selectedRewards=[];
  while(Date.now()-began<360000){
   const s=await page.evaluate(()=>window.__godotState);const c=s.campaign,p=s.player;
   for(const enemy of s.enemies)if(enemy.state==='attack'&&enemy.attack.weapon)weapons.add(enemy.attack.weapon);
   const visibleAttack=s.enemies.find(enemy=>enemy.state==='attack'&&enemy.attack.weapon&&!weaponShots.has(enemy.attack.weapon)&&enemy.stateTime>=enemy.attack.windup-.03&&enemy.stateTime<=enemy.attack.windup+.14);
   if(visibleAttack){
    weaponShots.add(visibleAttack.attack.weapon);
    await page.screenshot({path:path.join(out,'weapon-'+visibleAttack.attack.weapon+'.png')});
    milestones.push({kind:'weapon-contact',weapon:visibleAttack.attack.weapon,motion:visibleAttack.attack.motion,vfx:s.vfx.sentience});
   }
   if(s.story?.active){
    const storyKey=s.story.scene==='reward'?'reward-'+s.story.choice.choiceCount:s.story.scene;
    if(!stories.has(storyKey)){
     stories.add(storyKey);milestones.push({kind:'story',scene:s.story.scene,stage:c.stageIndex,choice:s.story.choice,text:s.story.text});
     if(s.story.scene==='reward'){
      assert.deepEqual(s.story.choice.rewardIds,selectedRewards,'Dialogue uses actual ordered choices');
      assert.equal(s.story.choice.latestId,selectedRewards.at(-1),'Immediate response belongs to selected card');
      assert.equal(s.story.choice.choiceCount,c.stageIndex);
      const expectedLines=sceneSize(s.story.sourceSceneId)+(c.stageIndex===3?sceneSize('J01'):0)+(c.stageIndex===5?sceneSize({press:'E01',guard:'E02',flow:'E03',balanced:'E04'}[s.story.choice.routeId]):0);
      assert.equal(s.story.total,expectedLines,'Chosen scene includes exactly its source rows and the authored midgame/final continuation');
      if(c.stageIndex===5)assert.equal(s.story.choice.finalChoice,true,'Last choice includes the final encounter');
     }
     await page.waitForTimeout(900);await page.screenshot({path:path.join(out,'story-'+storyKey+'.png')});
    }
    await page.evaluate(()=>__godotAction('story_skip'));await page.waitForTimeout(200);continue;
   }
   if(c.phase==='cleared'){
    await page.waitForFunction(()=>!__godotState.victory.playing,null,{timeout:15000});
    await page.waitForTimeout(150);
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
     const preferred=['reflection','riposte','risk','breath','windstep','swift','flow','finisher','calm','iron','fist','reservoir'];
     const id=preferred.find(id=>c.rewards.some(r=>r.id===id));
     const choice=c.rewards.findIndex(r=>r.id===id);
     selectedRewards.push(c.rewards[choice].id);
     await page.keyboard.press(String(choice+1));
    }
    await page.waitForTimeout(120);continue;
   }
   if(c.stageIndex!==lastStage){
    lastStage=c.stageIndex;
    for(const enemy of s.enemies){assert.equal(enemy.characterId,'herrscher_of_sentience');assert.equal(enemy.style,'sentience');assert.ok(enemy.name.includes('识'));}
    assert.ok(s.feel.enemy.modelPath.includes('/sentience/'));
    milestones.push({kind:'stage',stage:c.stageIndex+1,enemies:s.enemies.map(e=>({id:e.id,name:e.name,characterId:e.characterId})),presentation:s.feel.enemy});
    console.log('Entered',c.title,'enemies',s.enemies.length,'HP',p.hp);
    await page.waitForTimeout(600);await page.screenshot({path:path.join(out,'stage-'+c.stageIndex+'.png')});
   }
   if(s.paused){await page.keyboard.press('Escape');continue;}
   if(s.ended){
    if(!deathShot&&c.stageIndex===5&&s.feel.enemy.sourceTime>0.8){deathShot=true;await page.screenshot({path:path.join(out,'final-boss-defeated.png')});}
    await page.waitForTimeout(120);continue;
   }
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
  fs.writeFileSync(path.join(out,'sentience-report.json'),JSON.stringify({errors,milestones,weapons:[...weapons],weaponShots:[...weaponShots],state:final},null,2));
  assert.equal(final.campaign.phase,'cleared','All six fights completed with normal player actions');
  assert.equal(final.campaign.stageIndex,5);assert.equal(final.enemy.name,'识之律者');assert.equal(milestones.filter(x=>x.kind==='stage').length,6);assert.equal(final.campaign.boons.length,5);assert.equal(errors.length,0);
  for(const key of ['intro','reward-1','reward-2','reward-3','reward-4','reward-5','victory'])assert.ok(stories.has(key),'Story boundary '+key);
  assert.equal(milestones.filter(x=>x.kind==='story'&&x.scene==='reward').length,5,'One scene per selected upgrade');
  assert.deepEqual(final.story.choice.rewardIds,selectedRewards,'Ending remembers every selected upgrade');
  assert.equal(final.campaign.storyRoute,final.story.choice.routeTitle,'Result recalls the same route');
  assert.equal(new Set(final.campaign.rewardIds).size,5,'Each selected upgrade is distinct');
  assert.ok(weapons.size>=2,'Live enemies execute different weapon kits');
  await page.reload();await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:60000});
  assert.ok((await page.evaluate(()=>__godotState.campaign.bestScore))>0,'Best score survives page reload');
  console.log('PASS: Six-stage browser trial, 5 choice-driven scenes, matching ending, unique upgrades, results and records; errors=0');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
