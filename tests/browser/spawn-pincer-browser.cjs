'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/armor-expansion');
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});const errors=[];
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const action=cmd=>page.evaluate(cmd=>window.__godotAction(cmd),cmd);
  const move=value=>page.evaluate(value=>window.__godotAction('move',value),value);
  await page.goto('http://127.0.0.1:4187/?v=armor-expansion-1');await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  await action('select_style:shadow_knight');await action('start');
  let seen=false;const deadline=Date.now()+90000;
  while(Date.now()<deadline){
   const s=await state();
   if(s.story.active){await action('story_skip');await page.waitForTimeout(80);continue}
   if(s.campaign.phase==='reward'){await action('reward_0');await page.waitForTimeout(80);continue}
   if(s.stageCountdown>0&&s.enemies.length===2){
    for(const e of s.enemies)assert.equal(e.facing,e.x<s.player.x?1:-1);
    assert.ok(s.enemies.some(e=>e.x<s.player.x)&&s.enemies.some(e=>e.x>s.player.x));
    await page.screenshot({path:path.join(out,'pincer-countdown-fixed.png')});
    fs.writeFileSync(path.join(out,'pincer-report.json'),JSON.stringify({passed:true,errors,state:s},null,2));seen=true;break;
   }
   if(s.campaign.phase==='failed')throw Error('Trial failed before pincer');
   if(s.stageCountdown>0||s.ultimate||s.knockout?.active){await page.waitForTimeout(80);continue}
   const p=s.player,e=s.enemy,gap=e.x-p.x;
   if(p.state==='idle'||p.state==='move'||p.state==='guard'){
    if(Math.abs(gap)>1.5)await move(Math.sign(gap));
    else {await move(0);await action(p.energy>=100?'ultimate':p.skillCooldown<=0?'ability':'light')}
   }else if(p.state==='attack')await action(p.combo===1?'heavy':'light');
   await page.waitForTimeout(70);
  }
  assert.ok(seen,'pincer countdown reached by completing the first fight');
  await action('menu');await action('select_style:fenghuang');await action('select_appearance:fire_and_sword');await action('practice');
  await page.waitForFunction(()=>window.__godotState.started&&window.__godotState.stageCountdown<=0&&!window.__godotState.bossEntrance.active);
  await action('training');await page.waitForFunction(()=>window.__godotState.training);
  await move(1);await page.waitForFunction(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.4);await move(0);
  await action('ultimate');await page.waitForFunction(()=>window.__godotState.vfx.nativeSwordCount===12);
  await page.waitForTimeout(600);await page.screenshot({path:path.join(out,'fire-sword-final.png')});
  assert.equal((await state()).vfx.nativeSwordCount,12);
  assert.deepEqual(errors,[]);console.log('PINCER_AND_SWORD_BROWSER_PASS');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
