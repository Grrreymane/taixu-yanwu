'use strict';
const { chromium } = require('./playwright-runtime.cjs');
const fs = require('node:fs');
const path = require('node:path');
const out = path.resolve(__dirname, '../../build/screenshots/skirt-menu-web', process.argv[2] || 'before');
fs.mkdirSync(out, { recursive: true });
(async () => {
 const browser = await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const context = await browser.newContext({viewport:{width:1440,height:1000},deviceScaleFactor:2});
 const page = await context.newPage();
 const errors=[]; page.on('pageerror', e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
 try {
  await page.goto('http://127.0.0.1:4187/?v=skirt-inspection', {waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.__godotState?.ready, null,{timeout:120000});
  await page.evaluate(()=>window.__godotAction('select_appearance:taixu_memory'));
  await page.waitForFunction(()=>window.__godotState.fighter.appearanceId==='taixu_memory');
  for(let i=0;i<24;i++) {
   await page.waitForTimeout(650);
   await page.screenshot({path:path.join(out, `menu-${String(i).padStart(2,'0')}.png`)});
  }
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({errors,state:await page.evaluate(()=>window.__godotState)},null,2));
  console.log(JSON.stringify({out,frames:24,errors}));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
