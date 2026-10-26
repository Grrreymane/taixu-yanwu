'use strict';
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../build/screenshots/sentience-story');
const report={checks:[],errors:[],httpErrors:[]};
fs.mkdirSync(out,{recursive:true});
const check=(label,fn)=>{fn();report.checks.push(label);};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try {
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push(r.url());});
  const action=(name)=>page.evaluate(name=>window.__godotAction(name),name);
  const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const wait=(fn,t=15000)=>page.waitForFunction(fn,null,{timeout:t});
  const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
  await page.goto('http://127.0.0.1:4187/?v=sentience-story-2');
  await wait(()=>window.__godotState?.ready,90000);
  await shot('00-contracts');
  await action('contract:flow');
  await wait(()=>window.__godotState.campaign.contractId==='flow');
  check('Menu changes actual trial contract',()=>assert.equal(report.errors.length,0));
  await action('start');
  await wait(()=>window.__godotState.story?.active);
  await page.waitForTimeout(1700);
  const before=await read();
  await action('light');await action('ultimate');
  await page.keyboard.press('j');await page.waitForTimeout(600);
  const after=await read();
  check('Dialogue freezes fight, countdown and health; combat input is ignored',()=>{
   assert.equal(after.time,before.time);assert.equal(after.stageCountdown,before.stageCountdown);
   assert.equal(after.player.hp,before.player.hp);assert.equal(after.player.energy,before.player.energy);
   assert.equal(after.player.state,before.player.state);assert.ok(after.story.time>before.story.time);
  });
  await shot('01-senti-intro');
  await action('story_next');
  let s=await read();
  if(s.story.index===0)await action('story_next');
  await wait(()=>window.__godotState.story.index===1);
  await page.waitForTimeout(700);await shot('02-fuhua-reply');
  await page.setViewportSize({width:960,height:540});
  await page.waitForTimeout(300);await shot('03-dialogue-small');
  await page.keyboard.press('Escape');
  await wait(()=>!window.__godotState.story.active);
  await wait(()=>window.__godotState.stageCountdown<=0);
  await page.waitForTimeout(300);s=await read();
  check('Skip returns to live encounter and contract effects',()=>{
   assert.equal(s.campaign.phase,'fight');assert.ok(s.time>0);assert.equal(s.player.dodgeRefund,1);
  });
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  await action('contract:breaker');await action('start');
  await wait(()=>window.__godotState.story.active);
  s=await read();
  check('New trial gets selected rule and resets dialogue',()=>{assert.equal(s.campaign.contractId,'breaker');assert.equal(s.story.index,0);assert.equal(s.player.postureMultiplier,1.2);});
  await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');
  s=await read();check('Menu during dialogue cleans up presentation',()=>assert.equal(s.story.active,false));
  await page.setViewportSize({width:1440,height:900});await page.waitForTimeout(200);await shot('04-menu-return');
  check('No browser errors or missing assets',()=>{assert.deepEqual(report.errors,[]);assert.deepEqual(report.httpErrors,[]);});
  report.passed=true;console.log(JSON.stringify({passed:true,checks:report.checks.length,errors:report.errors}));
 }catch(e){report.passed=false;report.failure=e.stack;console.error(e);process.exitCode=1;}
 finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();}
})();
