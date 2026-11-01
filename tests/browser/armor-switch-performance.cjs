'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={errors:[],switches:[]};
 try{
  const p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  await p.addInitScript(()=>{
   window.glCosts=[];window.programSources=[];
   for(const key of ['getProgramParameter','texImage2D','compressedTexImage2D','bufferData']){
    const original=WebGL2RenderingContext.prototype[key];
    WebGL2RenderingContext.prototype[key]=function(...args){const start=performance.now(),result=original.apply(this,args),ms=performance.now()-start;if(ms>5)window.glCosts.push({key,ms,phase:window.switchPhase||'loading'});if(key==='getProgramParameter'&&ms>100)window.programSources.push({phase:window.switchPhase||'loading',ms,sources:this.getAttachedShaders(args[0]).map(s=>this.getShaderSource(s))});return result};
   }
  });
  await p.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=armor-switch');
  await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  await p.evaluate(()=>__godotAction('menu'));
  await p.waitForFunction(()=>__godotState.campaign.phase==='menu');
  await p.evaluate(()=>{window.frameTimes=[];let last=null;const tick=t=>{if(last!==null)frameTimes.push({ms:t-last,phase:window.switchPhase});last=t;requestAnimationFrame(tick)};requestAnimationFrame(tick)});
  for(const [index,style] of ['night_squire','azure_empyrea','night_squire','fenghuang','shadow_knight','hawk_of_the_fog','shadow_knight','hawk_of_the_fog'].entries()){
   const key=index+':'+style;
   const start=Date.now();
   const commandMs=await p.evaluate(({style,key})=>{window.switchPhase=key;const start=performance.now();__godotAction('select_style:'+style);return performance.now()-start},{style,key});
   await p.waitForFunction(style=>__godotState.fighter.styleId===style,style,{timeout:30000});
   const readyMs=Date.now()-start;
   await p.waitForTimeout(300);
   const state=await p.evaluate(()=>({fighter:__godotState.fighter,loading:__godotState.roster.loading,pose:__godotState.feel.player}));
   assert.equal(state.fighter.styleId,style);
   report.switches.push({key,commandMs,readyMs,model:state.pose.modelPath});
   console.log(JSON.stringify(report.switches.at(-1)));
  }
  report.frames=await p.evaluate(()=>window.frameTimes);report.glCosts=await p.evaluate(()=>window.glCosts.filter(x=>x.phase!=='loading'));
  fs.writeFileSync('build/armor-program-sources.json',JSON.stringify(await p.evaluate(()=>window.programSources),null,2));
  for(const row of report.switches){const frames=report.frames.filter(x=>x.phase===row.key);row.maxFrame=Math.max(0,...frames.map(x=>x.ms));row.over50=frames.filter(x=>x.ms>50).length;row.over100=frames.filter(x=>x.ms>100).length}
  fs.writeFileSync('build/armor-switch-'+(process.argv[2]||'sample')+'.json',JSON.stringify(report,null,2));
  console.log(JSON.stringify({switches:report.switches,glCosts:report.glCosts,errors:report.errors}));
  assert.deepEqual(report.errors,[]);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
