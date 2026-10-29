'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs');
const url=process.env.TAIXU_TEST_URL||'http://127.0.0.1:4188/';
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={url,modes:[]};
 try {
  for(const mode of ['compressed','legacy','fallback']){
   const context=await browser.newContext({viewport:{width:1440,height:900}}),page=await context.newPage();
   const requests=[],errors=[];
   page.on('request',r=>requests.push(r.url()));page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('net::ERR_FAILED'))errors.push(m.text())});
   if(mode==='legacy')await page.addInitScript(()=>{window.DecompressionStream=undefined});
   if(mode==='fallback')await page.route('**/*.wasm.gz',r=>r.abort());
   await page.goto(url);await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
   if(mode==='compressed'){
    assert.ok(requests.some(x=>x.endsWith('.wasm.gz')));
    assert.ok(!requests.some(x=>x.endsWith('.wasm')),'normal startup must not download uncompressed WASM');
    const act=(name)=>page.evaluate(name=>window.__godotAction(name),name);
    const outfits={azure_empyrea:['default','taixu_memory'],fenghuang:['default','fire_and_sword'],night_squire:['default','autumn_leaves','spring_traveler','xuanyi_sushang','black_butler'],shadow_knight:['default','blood_moon'],hawk_of_the_fog:['default']};
    for(const [style,skins] of Object.entries(outfits)){
     await act('select_style:'+style);
     for(const skin of skins){await act('select_appearance:'+skin);await page.waitForFunction(([a,b])=>window.__godotState.fighter.styleId===a&&window.__godotState.fighter.appearanceId===b,[style,skin]);await page.waitForTimeout(100)}
    }
    await page.screenshot({path:'build/lean-menu.png'});
    await act('practice');await page.waitForFunction(()=>window.__godotState.started&&window.__godotState.stageCountdown<=0&&!window.__godotState.bossEntrance.active,null,{timeout:30000});
    await page.screenshot({path:'build/lean-fight.png'});
   }else assert.ok(requests.some(x=>x.endsWith('.wasm')));
   assert.deepEqual(errors,[]);
   report.modes.push({mode,passed:true,engineRequests:requests.filter(x=>x.includes('.wasm'))});
   await context.close();
  }
  fs.writeFileSync('build/lean-web-report.json',JSON.stringify(report,null,2));console.log('LEAN_WEB_PASS');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
