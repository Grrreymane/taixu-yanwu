const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../../build/screenshots/roster-audio-final');fs.mkdirSync(out,{recursive:true});
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});const errors=[];try{
 const page=await browser.newPage({viewport:{width:1440,height:900}});page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto('http://127.0.0.1:4187/?v=roster-audio-2');await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:120000});
 await page.evaluate(()=>window.__godotAction('select_appearance:taixu_memory'));await page.waitForFunction(()=>window.__godotState.fighter.appearanceId==='taixu_memory');await page.waitForTimeout(600);
 await page.screenshot({path:path.join(out,'menu-large.png')});
 await page.setViewportSize({width:960,height:540});await page.waitForTimeout(250);await page.screenshot({path:path.join(out,'menu-small.png')});
 const s=await page.evaluate(()=>structuredClone(window.__godotState));assert.deepEqual(errors,[]);assert.equal(s.roster.styles.length,3);assert.ok(s.ui.previewRect[2]>0);
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({passed:true,errors,ui:s.ui,fighter:s.fighter},null,2));console.log('FINAL_MENU_PASS');
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
