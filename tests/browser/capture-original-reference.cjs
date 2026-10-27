'use strict';
// Read-only research captures. No account, form submission or game automation.
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const out=path.resolve(__dirname,'../../build/references/original');
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const results=[];
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  for(const [name,url] of [
   ['taixu-official','https://bh3.mihoyo.com/news/695/120147'],
   ['azure-official','https://uploadstatic.mihoyo.com/contentweb/20200116/2020011611294483467.png'],
   ['outfit-screenshots','https://honkaiimpact3.fandom.com/wiki/Taixuan_Impression'],
   ['taixu-game-reference','https://upload-bbs.miyoushe.com/upload/2025/06/21/446232820/eb2145619df27b889b5b56c4b5612b22_1876406371314643583.jpg?x-oss-process=image%2Fresize%2Cs_600%2Fquality%2Cq_80%2Fauto-orient%2C0%2Finterlace%2C1%2Fformat%2Cjpg']
  ]){
   if(process.argv[2] && process.argv[2]!==name)continue;
   const entry={name,url};results.push(entry);
   try{
    await page.goto(url,{waitUntil:'domcontentloaded',timeout:25000});
    await page.waitForTimeout(2000);
    entry.title=await page.title();
    entry.text=(await page.locator('body').innerText()).slice(0,16000);
    entry.images=await page.locator('img').evaluateAll(xs=>xs.map(x=>({src:x.currentSrc||x.src,alt:x.alt,width:x.naturalWidth,height:x.naturalHeight})).filter(x=>x.width>100));
    await page.screenshot({path:path.join(out,name+'.png'),fullPage:false});
   }catch(e){entry.error=e.message;}
  }
 }finally{
  fs.writeFileSync(path.join(out,process.argv[2]?'sources-'+process.argv[2]+'.json':'sources.json'),JSON.stringify(results,null,2));
  console.log(JSON.stringify(results));await browser.close();
 }
})();
