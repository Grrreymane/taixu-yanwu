'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/native-remaining-web');fs.mkdirSync(out,{recursive:true});
const report={cases:[],errors:[],passed:false};
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const page=await browser.newPage({viewport:{width:1280,height:800}});
 const state=()=>page.evaluate(()=>structuredClone(window.__godotState));
 const act=n=>page.evaluate(n=>window.__godotAction(n),n);
 const wait=(f,a=null)=>page.waitForFunction(f,a,{timeout:30000});
 page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 try{
  await page.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=native-practice');
  await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  for(const [style,skin,required] of [['hawk_of_the_fog','default','Avatar_Fuka_FK_Attack_C2_3_Ultra/'],['shadow_knight','blood_moon','Avatar_Fuka_NL_Attack_UltraThunder_Dress01/'],['night_squire','default','Avatar_Fuka_ND_Ultra_']]){
   await act('menu');await act('select_style:'+style);await act('select_appearance:'+skin);await act('practice');await act('training');
   await wait(()=>window.__godotState.training);await act('ultimate');
   await wait(()=>window.__godotState.ultimateTime>0.1);await act('pause');await wait(()=>window.__godotState.paused);
   const before=await state();await page.waitForTimeout(180);const after=await state();assert.equal(before.ultimateTime,after.ultimateTime);assert.deepEqual(before.vfx,after.vfx);
   await act('pause');const keys=new Set();let peak=0,shot=false;const deadline=Date.now()+15000;
   while(Date.now()<deadline){
    const s=await state();for(const k of s.vfx.textureKeys)keys.add(k);peak=Math.max(peak,s.vfx.total);
    if(!shot&&s.vfx.textureKeys.some(k=>k.includes(required))){await page.screenshot({path:path.join(out,style+'-'+skin+'.png')});shot=true;}
    if(!s.ultimate&&s.time>5)break;await page.waitForTimeout(35);
   }
   assert.ok([...keys].some(k=>k.includes(required)),style+' original prefab reached exported renderer');assert.ok(peak>0&&peak<=112);
   await act('menu');await wait(()=>window.__godotState.campaign.phase==='menu');await page.waitForTimeout(180);assert.equal((await state()).vfx.total,0);
   report.cases.push({style,skin,peak,sourceKeys:[...keys].filter(k=>k.includes('Avatar_Fuka')),pausePassed:true,clearPassed:true});
  }
  assert.deepEqual(report.errors,[]);report.passed=true;
 }catch(e){report.failure=e.stack;throw e;}finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();console.log(JSON.stringify(report));}
})().catch(e=>{console.error(e);process.exitCode=1});
