'use strict';
// Fresh browser storage; only real menu actions, pointer and keyboard inputs.
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
const out='build/screenshots/practice-builds-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={passed:false,errors:[],cases:[]};
 try{
  const p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const action=name=>p.evaluate(name=>__godotAction(name),name);
  const state=()=>p.evaluate(()=>window.__godotState);
  const wait=(fn,arg=null)=>p.waitForFunction(fn,arg,{timeout:30000});
  const open=async()=>{await p.getByRole('button',{name:'自由对练打法配置',exact:true}).click();await wait(()=>!!__godotState.practiceBuild?.style)};
  const choose=async id=>{await p.locator('#bc-core-'+id).click();await wait(id=>__godotState.practiceBuild.core===id,id)};
  const apply=async()=>{await p.getByRole('button',{name:'应用并重置对练',exact:true}).click();await wait(()=>!__godotState.practiceBuild?.style&&!__godotState.paused)};
  await p.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4187/?v=practice-builds');
  await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  await action('select_style:azure_empyrea');await action('trial');await wait(()=>__godotState.nightCoreChoice);
  await p.getByRole('button',{name:'选用 阴阳相生',exact:true}).click();await wait(()=>__godotState.story.active);
  await action('story_skip');await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
  for(const style of ['azure_empyrea','fenghuang','night_squire','shadow_knight','hawk_of_the_fog']){
   await action('select_style:'+style);await wait(style=>__godotState.player.style===style,style);
   await action('practice');await wait(()=>__godotState.campaign.mode==='practice'&&__godotState.campaign.phase==='fight');
   await action('training');await action('practice_infinite_hp');await open();
   const options=(await state()).practiceBuild.options;
   for(let i=0;i<3;i++){
    const row=options[i];if(i>0)await open();await choose(row.id);
    assert.equal(await p.getByRole('checkbox').count(),2);
    for(const perk of row.rewards){await p.locator('#bc-perk-'+perk).check();await wait(perk=>__godotState.practiceBuild.selectedPerks.includes(perk),perk)}
    if(i===0){
     await p.screenshot({path:out+'/'+style+'.png'});
     const snapshot=await state();await p.waitForTimeout(250);assert.equal((await state()).time,snapshot.time,'modal freezes simulation');
     await p.locator('.bc-info').first().click();await p.locator('#battle-choice-info').waitFor({state:'visible'});
     await p.keyboard.press('Escape');await p.locator('#battle-choice-info').waitFor({state:'hidden'});
    }
    if(style==='azure_empyrea'&&i===0){
     for(const viewport of [{width:960,height:540},{width:480,height:820}]){
      await p.setViewportSize(viewport);await p.waitForTimeout(120);
      const overflow=await p.locator('#battle-choices').evaluate(n=>n.scrollWidth>n.clientWidth+1);assert.equal(overflow,false);
      const clips=await p.locator('.bc-select,.bc-perk').evaluateAll(nodes=>nodes.some(n=>n.scrollWidth>n.clientWidth+2||n.scrollHeight>n.clientHeight+2));assert.equal(clips,false);
      await p.screenshot({path:out+'/config-'+viewport.width+'.png'});
      await p.locator('#bc-apply').scrollIntoViewIfNeeded();await p.screenshot({path:out+'/config-'+viewport.width+'-bottom.png'});
     }
     await p.setViewportSize({width:1440,height:900});
     await p.locator('#bc-apply').focus();await p.keyboard.press('Tab');assert.equal(await p.locator('.bc-select').first().evaluate(n=>n===document.activeElement),true,'Tab remains in configuration');
     await p.keyboard.press('Shift+Tab');assert.equal(await p.locator('#bc-apply').evaluate(n=>n===document.activeElement),true);
    }
    await apply();const applied=await state(),prefix=style==='night_squire'?'night':'armor';
    assert.equal(applied.player[prefix+'Core'],row.id);assert.deepEqual(Object.keys(applied.player[prefix+'Perks']).sort(),[...row.rewards].sort());
    assert.ok(applied.training&&applied.infiniteHp);report.cases.push({style,core:row.id,perks:row.rewards});
    console.log('PRACTICE_BUILD '+style+' '+row.id);
   }
   // Changing or cancelling a draft does not mutate the applied build.
   await p.keyboard.press('b');await wait(()=>!!__godotState.practiceBuild?.style);
   await p.getByRole('button',{name:'基础招式，不使用核心与专属强化',exact:true}).click();await wait(()=>__godotState.practiceBuild.core==='');
   assert.equal(await p.getByRole('checkbox').count(),0);
   await p.keyboard.press('Escape');await wait(()=>!__godotState.practiceBuild?.style);
   assert.equal((await state()).player[style==='night_squire'?'nightCore':'armorCore'],options[2].id);
   await action('menu');await wait(()=>__godotState.campaign.phase==='menu');
  }
  // Applied selections survive a real browser reload, independently per armor.
  await p.reload();await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  await action('select_style:azure_empyrea');await wait(()=>__godotState.player.style==='azure_empyrea');await action('practice');
  await wait(()=>__godotState.player.armorCore==='az_yin');assert.equal(Object.keys((await state()).player.armorPerks).length,2);
  await action('training');await action('practice_infinite_hp');await action('ultimate');await wait(()=>__godotState.cinematic.active);
  await open();const ultTime=(await state()).ultimateTime;await p.waitForTimeout(350);assert.equal((await state()).ultimateTime,ultTime);
  await choose('az_yang');await p.locator('#bc-perk-az_cycle').check();await wait(()=>__godotState.practiceBuild.selectedPerks.includes('az_cycle'));
  // Checkbox toggles keep keyboard focus rather than jumping to the heading.
  await p.locator('#bc-perk-az_cycle').focus();await p.keyboard.press('Space');await wait(()=>!__godotState.practiceBuild.selectedPerks.includes('az_cycle'));
  assert.equal(await p.locator('#bc-perk-az_cycle').evaluate(n=>n===document.activeElement),true);
  await apply();assert.equal((await state()).cinematic.active,false);assert.deepEqual((await state()).player.armorPerks,{});
  const entryRect=await p.locator('#practice-build-entry').boundingBox(),healthRect=(await state()).ui.infiniteHpRect;
  assert.ok(entryRect.y>=healthRect[1]+healthRect[3],'configuration entry does not overlap health control');
  await p.screenshot({path:out+'/practice-applied.png'});
  await open();await p.getByRole('button',{name:'基础招式，不使用核心与专属强化',exact:true}).click();await wait(()=>__godotState.practiceBuild.core==='');await apply();
  assert.equal((await state()).player.armorCore,'');
  await action('menu');await wait(()=>__godotState.campaign.phase==='menu');await action('continue');await wait(()=>__godotState.campaign.mode==='trial'&&__godotState.player.armorCore==='az_balance');
  assert.ok(await p.locator('#practice-build-entry').isHidden(),'practice controls absent from resumed trial');
  assert.deepEqual(report.errors,[]);report.passed=true;
 }finally{fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));await browser.close()}
 console.log('PRACTICE_BUILDS_BROWSER_PASS');
})().catch(e=>{console.error(e);process.exitCode=1});
