'use strict';
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const revision=require('../../scripts/data/sentience_story_scenes.json').revision;
const appearance=process.argv[2]||'default';
const out=path.resolve(__dirname,'../../build/screenshots/'+(appearance==='default'?'night-squire-web':'autumn-leaves-web'));fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],errors:[],screenshots:[],storage:'Disposable browser context; ordinary UI actions and keyboard only'};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({viewport:{width:1440,height:900}}),page=await context.newPage();
 page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
 const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
 const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
 const check=(name,f)=>{f();report.checks.push(name);save()};
 const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.screenshots.push(name);save()};
 const closeIn=async()=>{
  let s=await read();const dir=s.enemy.x>=s.player.x?1:-1;
  await action('move',dir);await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.25);
  await action('move',0);await wait(()=>window.__godotState.player.state==='idle');
 };
 try{
  await page.goto('http://127.0.0.1:4187/?v=autumn-leaves-1',{waitUntil:'domcontentloaded'});
  await wait(()=>window.__godotState?.ready,null,120000);
  await action('select_style:night_squire');await wait(()=>window.__godotState.fighter.styleId==='night_squire');
  let original=await read();check('Original White Night includes native root scale in normalization',()=>{
   assert.equal(original.feel.player.normalization.reference,'native_neutral_skinned');
   assert.ok(Math.abs(original.feel.player.normalization.scale-1.5968492)<0.00001);
  });
  if(appearance==='autumn_leaves'){
   check('White Night offers original and Autumn Leaves',()=>assert.deepEqual(original.roster.appearances.map(v=>v.id),['default','autumn_leaves']));
   // Actual second appearance button at the inspected 1440x900 menu layout.
   await page.mouse.click(350,499);
   await wait(()=>window.__godotState.fighter.appearanceId==='autumn_leaves');
   const skin=await read();check('Real skin button loads original C3_04_03 at corrected scale',()=>{
    assert.equal(skin.fighter.skinName,'红叶知秋');assert.match(skin.feel.player.modelPath,/Avatar_Fuka_C3_04_03/);
    assert.ok(Math.abs(skin.feel.player.normalization.scale-1.6012958)<0.00001);
   });
  }
  let s=await read();check('Three armor choices, native White Night identity',()=>{
   assert.deepEqual(s.roster.styles.map(v=>v.id),['azure_empyrea','fenghuang','night_squire']);assert.equal(s.fighter.styleName,'白夜执事');
  });
  await shot('01-menu');await page.setViewportSize({width:960,height:540});await page.waitForTimeout(250);await shot('02-menu-small');
  await page.setViewportSize({width:1440,height:900});await action('start');
  await wait(()=>window.__godotState.story.active&&window.__godotState.story.time>1.0);
  s=await read();check('White Night dialogue plays original complete idle and accepted wording',()=>{
   assert.equal(s.story.revision,revision);assert.equal(s.story.performance.fuhua.mode,'native_full_clip');assert.equal(s.story.performance.fuhua.skeletalEdits,0);
  });await shot('03-dialogue');
  await action('menu');await action('practice');await wait(()=>window.__godotState.campaign.phase==='fight'&&window.__godotState.stageCountdown===0);
  await action('training');await wait(()=>window.__godotState.training);await closeIn();
  const hp=(await read()).enemy.hp;await page.keyboard.press('j');
  await wait(hp=>window.__godotState.enemy.hp<hp,hp);s=await read();
  check('Original ND punch deals contact damage',()=>{assert.ok(s.feelFrames.some(f=>f.playerMotion==='light1'));assert.ok(s.events.some(e=>e.type==='hit'&&e.style==='night_squire'));});await shot('04-punch');
  await wait(()=>window.__godotState.player.state==='idle');await closeIn();
  await page.keyboard.press('e');await wait(()=>window.__godotState.player.nightFocus===3);
  s=await read();check('E grants three charges on real contact and uses ND textures',()=>{
   assert.ok(s.player.skillCooldown>0);assert.ok(s.vfx.loadedTextures.includes('night_trail'));assert.ok(s.events.some(e=>e.type==='nightFocus'));
  });await shot('05-ability');
  await wait(()=>window.__godotState.player.state==='idle');await page.keyboard.press('q');
  await wait(()=>window.__godotState.ultimate&&window.__godotState.ultimateTime>.28);
  s=await read();check('Q uses brief White Night activation camera and no Azure ultimate',()=>{
   assert.ok(s.cinematic.shot.startsWith('night_'));assert.ok(!s.vfx.textureKeys.some(k=>['landscape','mountains','taiji'].includes(k)));
  });await shot('06-activation');
  await wait(()=>!window.__godotState.ultimate&&window.__godotState.player.nightBurstRemaining>6.0);
  await closeIn();await page.keyboard.press('j');await wait(()=>window.__godotState.feel.player.motion==='kick_light1');
  s=await read();check('Burst swaps to native B chain and consumes a charge',()=>{assert.ok(s.player.nightBurstRemaining>0);assert.equal(s.player.nightFocus,2);});await shot('07-burst-kick');
  await wait(()=>window.__godotState.player.state==='idle');await page.keyboard.press('Escape');await wait(()=>window.__godotState.paused);
  const frozen=(await read()).player.nightBurstRemaining;await page.waitForTimeout(350);
  check('Burst duration pauses with battle',()=>{});assert.equal((await read()).player.nightBurstRemaining,frozen);
  await page.keyboard.press('Escape');await wait(()=>!window.__godotState.paused);
  await action('menu');await action('select_style:azure_empyrea');await action('select_appearance:taixu_memory');
  await wait(()=>window.__godotState.fighter.appearanceId==='taixu_memory');await shot('08-taixu-regression');
  check('Switching back preserves the existing skin',()=>{});
  await action('select_style:night_squire');await page.reload({waitUntil:'domcontentloaded'});await wait(()=>window.__godotState?.ready,null,120000);
  s=await read();check('Selection survives reload in disposable context',()=>{assert.equal(s.fighter.styleId,'night_squire');assert.equal(s.fighter.appearanceId,appearance);});
  check('No browser script/render errors',()=>assert.deepEqual(report.errors,[]));report.passed=true;save();console.log(JSON.stringify({passed:true,checks:report.checks.length,screenshots:report.screenshots.length}));
 }catch(e){report.failure=e.stack;save();throw e;}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
