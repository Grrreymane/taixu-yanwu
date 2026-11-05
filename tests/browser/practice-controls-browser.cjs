'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
const out='build/screenshots/practice-controls-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={passed:false,scope:process.env.PRACTICE_PATTERNS_ONLY?'patterns':process.env.PRACTICE_SMOKE?'smoke':'full',errors:[],ultimates:[],patterns:[]};let p;
 try{
  p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const state=()=>p.evaluate(()=>window.__godotState),action=name=>p.evaluate(name=>__godotAction(name),name);
  const wait=(fn,arg=null)=>p.waitForFunction(fn,arg,{timeout:30000});
  const open=async()=>{await p.getByRole('button',{name:'自由对练打法配置',exact:true}).click();await wait(()=>!!__godotState.practiceBuild?.style)};
  const apply=async()=>{await p.getByRole('button',{name:'应用并重置对练',exact:true}).click();await wait(()=>!__godotState.practiceBuild?.style&&!__godotState.paused)};
  await p.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4187/?v=practice-controls-1');
  await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  // Keep a real trial checkpoint in this disposable browser throughout practice.
  await action('select_style:azure_empyrea');await action('trial');await wait(()=>__godotState.nightCoreChoice);
  await p.getByRole('button',{name:'选用 阴阳相生',exact:true}).click();await wait(()=>__godotState.story.active);
  await action('story_skip');await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
  for(const style of (process.env.PRACTICE_PATTERNS_ONLY?[]:process.env.PRACTICE_SMOKE?['azure_empyrea']:['azure_empyrea','fenghuang','night_squire','shadow_knight','hawk_of_the_fog'])){
   await action('select_style:'+style);await wait(style=>__godotState.player.style===style,style);await action('practice');
   await wait(()=>__godotState.campaign.mode==='practice'&&__godotState.campaign.phase==='fight');await action('training');await action('practice_infinite_hp');
   if(!(await state()).infiniteEnergy){await p.getByRole('button',{name:'无限能量',exact:true}).click();await wait(()=>__godotState.infiniteEnergy)}
   const energyButton=p.getByRole('button',{name:'无限能量',exact:true});assert.equal(await energyButton.getAttribute('aria-pressed'),'true');
   if(style==='azure_empyrea'){
    await energyButton.focus();await p.keyboard.press('Space');await wait(()=>!__godotState.infiniteEnergy);assert.equal((await state()).player.state,'idle');
    await p.keyboard.press('Enter');await wait(()=>__godotState.infiniteEnergy);assert.equal((await state()).player.state,'idle');
   }
   for(let attempt=0;attempt<2;attempt++){
    await action('ultimate');await wait(()=>__godotState.cinematic.active);
    for(let i=0;i<5;i++){assert.equal((await state()).player.energy,100);await p.waitForTimeout(150)}
    await wait(()=>!__godotState.cinematic.active&&__godotState.player.state==='idle'&&(__godotState.player.nightBurstRemaining||0)<=0);
   }
   await energyButton.click();await wait(()=>!__godotState.infiniteEnergy);
   assert.equal(await p.locator('#canvas').evaluate(n=>n===document.activeElement),true,'pointer toggle returns keyboard control to combat');
   if(style==='azure_empyrea'){
    await p.keyboard.press('Space');await wait(()=>__godotState.player.state==='dodge');await wait(()=>__godotState.player.state==='idle');
    assert.equal((await state()).infiniteEnergy,false,'combat dodge does not reactivate the toggle');
   }
   await action('ultimate');await wait(()=>__godotState.cinematic.active);
   assert.ok((await state()).player.energy<100,'finite mode spends SP');
   await energyButton.click();await wait(()=>__godotState.infiniteEnergy&&__godotState.player.energy===100);
   assert.ok((await state()).cinematic.active,'mid-animation switch keeps original ultimate running');
   report.ultimates.push({style,repeated:2,finiteCost:true,midUltimateToggle:true});console.log('PRACTICE_ENERGY '+style);
   await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
  }
  await action('select_style:night_squire');await wait(()=>__godotState.player.style==='night_squire');await action('practice');
  await wait(()=>__godotState.campaign.mode==='practice'&&__godotState.campaign.phase==='fight'&&!__godotState.cinematic.active);
  await action('practice_infinite_hp');
  if(!(await state()).infiniteEnergy){await p.getByRole('button',{name:'无限能量',exact:true}).click();await wait(()=>__godotState.infiniteEnergy)}
  await open();await p.locator('#bc-core-counter').click();await wait(()=>__godotState.practiceBuild.core==='counter');
  await p.locator('#bc-perk-night_chase').check();await wait(()=>__godotState.practiceBuild.selectedPerks.includes('night_chase'));await apply();
  for(const pattern of ['sword','spear','chain']){
   await open();await p.getByLabel('小识招路',{exact:true}).focus();await p.getByLabel('小识招路',{exact:true}).selectOption(pattern);await wait(pattern=>__godotState.practiceBuild.enemyPattern===pattern,pattern);
   assert.equal(await p.getByLabel('小识招路',{exact:true}).evaluate(n=>n===document.activeElement),true,'selection retains keyboard focus');
   await p.getByRole('button',{name:'小识招路详情',exact:true}).click();await p.locator('#battle-choice-info').waitFor({state:'visible'});
   assert.ok((await p.locator('#bc-info-body').textContent()).length>15);await p.getByRole('button',{name:'关闭',exact:true}).click();
   if(pattern==='spear'){
    for(const size of [{width:1440,height:900},{width:960,height:540},{width:480,height:820}]){
     await p.setViewportSize(size);await p.waitForTimeout(150);await p.getByLabel('小识招路',{exact:true}).scrollIntoViewIfNeeded();
     assert.equal(await p.locator('#battle-choices').evaluate(n=>n.scrollWidth>n.clientWidth+1),false);
     await p.screenshot({path:out+'/config-'+size.width+'.png'});
    }
    await p.setViewportSize({width:1440,height:900});
   }
   await apply();await wait(pattern=>__godotState.enemy.bossPattern===pattern,pattern);
   assert.equal((await state()).player.nightCore,'counter');assert.ok((await state()).player.nightPerks.night_chase);
   assert.ok((await state()).infiniteEnergy&&(await state()).infiniteHp);
   if(pattern==='spear')await wait(()=>__godotState.enemy.aiRound>=3);
   const started=Date.now(),trace=[];let seen=false,parried=false;
   while(Date.now()-started<22000){
    const s=await state(),enemy=s.enemy;
    const remaining=enemy.state==='attack'?enemy.attack.windup-enemy.stateTime:10;
    if(enemy.state==='attack'&&enemy.attack.weapon===pattern){
     seen=true;
    }
    const guard=enemy.state==='attack'&&!enemy.attack.unblockable&&remaining<.11&&remaining>-.14;
    if(trace.at(-1)?.time!==s.time)trace.push({time:s.time,enemy:enemy.state,weapon:enemy.attack?.weapon,remaining,contact:enemy.attack?.contactOutcome,player:s.player.state,parryUntil:s.player.parryUntil,guard,parries:s.stats.parries});
    await p.evaluate(guard=>__godotAction('guard_held',guard),guard);
    if(s.stats.parries>0){parried=true;break}
    await p.waitForTimeout(25);
   }
   if(!parried)fs.writeFileSync(out+'/trace-'+pattern+'.json',JSON.stringify(trace,null,2));
   assert.ok(seen,'AI attacks with selected signature: '+pattern);assert.ok(parried,'selected signature can be parried: '+pattern);
   await p.evaluate(()=>__godotAction('guard_held',false));await action('heavy');
   report.patterns.push({pattern,signature:true,parry:true});console.log('PRACTICE_PATTERN '+pattern);
  }
  await open();await p.getByLabel('小识招路',{exact:true}).selectOption('spear');await wait(()=>__godotState.practiceBuild.enemyPattern==='spear');
  await p.getByRole('button',{name:'取消',exact:true}).click();await wait(()=>!__godotState.practiceBuild?.style);assert.equal((await state()).enemy.bossPattern,'chain');
  // Toggles must not overlap each other at narrow canvas scales.
  for(const size of [{width:1440,height:900},{width:960,height:540},{width:480,height:820}]){
   await p.setViewportSize(size);await p.waitForTimeout(200);
   const energy=await p.locator('#practice-energy').boundingBox(),config=await p.locator('#practice-build-entry').boundingBox();
   assert.ok(config.y>=energy.y+energy.height&&energy.height>=38&&config.x+config.width<=size.width);
  }
  await p.setViewportSize({width:1440,height:900});await p.screenshot({path:out+'/practice-controls.png'});
  await p.reload();await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});await action('practice');
  await wait(()=>__godotState.enemy.bossPattern==='chain'&&__godotState.infiniteEnergy&&__godotState.player.nightCore==='counter');
  await action('menu');await wait(()=>__godotState.campaign.phase==='menu');await action('continue');await wait(()=>__godotState.campaign.mode==='trial');
  assert.equal((await state()).infiniteEnergy,false);assert.equal((await state()).player.armorCore,'az_balance');assert.ok(await p.locator('#practice-energy').isHidden());
  assert.deepEqual(report.errors,[]);report.passed=true;
 }finally{
  if(!report.passed&&p)await p.screenshot({path:out+'/failure.png'}).catch(()=>{});
  fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));await browser.close();
 }
 console.log('PRACTICE_CONTROLS_BROWSER_PASS');
})().catch(e=>{console.error(e);process.exitCode=1});
