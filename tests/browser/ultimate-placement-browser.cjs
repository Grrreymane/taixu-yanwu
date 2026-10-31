'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const out=path.resolve(__dirname,'../../build/screenshots/ultimate-placement-web');fs.mkdirSync(out,{recursive:true});
const report={passed:false,cases:[],errors:[]};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
  const act=n=>page.evaluate(n=>window.__godotAction(n),n);
  const wait=(f,a=null)=>page.waitForFunction(f,a,{timeout:30000});
  await page.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=ultimate-placement');
  await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  for(const [style,skin] of [['fenghuang','default'],['fenghuang','fire_and_sword'],['night_squire','default'],['night_squire','autumn_leaves']]){
   await act('menu');await act('select_style:'+style);await act('select_appearance:'+skin);await act('practice');
   if(!(await state()).training)await act('training');await wait(()=>window.__godotState.training);
   await act('ultimate');
   await wait(()=>window.__godotState.ultimateTime>.85&&window.__godotState.ultimateTime<1.5);
   await act('pause');await wait(()=>window.__godotState.paused);
   const held=await state();await page.waitForTimeout(180);
   assert.deepEqual((await state()).cinematic,held.cinematic);assert.deepEqual((await state()).vfx,held.vfx);
   if(style==='fenghuang'){
    assert.equal(held.cinematic.performerVisible,false);assert.equal(held.cinematic.phoenixVisible,true);
    assert.equal(held.cinematic.composition,'transformation');assert.ok(held.cinematic.target[1]>5,'camera follows real native ascent');
   }
   await page.screenshot({path:path.join(out,style+'-'+skin+'-ultimate.png')});
   await act('pause');await wait(()=>!window.__godotState.ultimate);
   await page.waitForTimeout(200);
   const after=await state();assert.equal(after.cinematic.performerVisible,true);assert.equal(after.cinematic.phoenixVisible,false);
   if(style==='night_squire'){
    assert.ok(after.vfx.textureKeys.some(k=>k.includes('Avatar_Fuka_ND_Ultra_Follow/Models_Smoke')),'original three-dimensional aura present');
    await page.screenshot({path:path.join(out,style+'-'+skin+'-aura.png')});
   }
   assert.ok(after.vfx.total<=112);await act('menu');await page.waitForTimeout(200);
   assert.equal((await state()).vfx.total,0);
   report.cases.push({style,skin,shot:held.cinematic.shot,transformation:held.cinematic.phoenixVisible,pausePassed:true,cleanupPassed:true});
  }
  assert.deepEqual(report.errors,[]);report.passed=true;
 }catch(e){report.failure=e.stack;throw e;}finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();console.log(JSON.stringify(report));}
})().catch(e=>{console.error(e);process.exitCode=1});
