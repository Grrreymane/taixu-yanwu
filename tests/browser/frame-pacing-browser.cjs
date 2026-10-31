'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
const label=process.argv[2]||'sample';
const width=Number(process.env.PERF_WIDTH||1440),height=Number(process.env.PERF_HEIGHT||900);
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={label,width,height,errors:[],runs:[]};
 try{
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:Number(process.env.PERF_DPR||1)});
  await page.addInitScript(()=>{
   window.slowGL=[];
   for(const key of ['compileShader','linkProgram','getProgramParameter','getShaderParameter','drawElements','drawArrays','getUniformLocation','texImage2D','compressedTexImage2D','bufferData']){
    const original=WebGL2RenderingContext.prototype[key];
    WebGL2RenderingContext.prototype[key]=function(...args){const start=performance.now(),result=original.apply(this,args),ms=performance.now()-start;if(ms>5)window.slowGL.push({key,ms,at:start,phase:window.frameAudit?.phase||'loading'});return result};
   }
  });
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  await page.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=frame-audit');
  await page.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  report.renderer=await page.evaluate(()=>{const c=document.querySelector('canvas'),gl=c.getContext('webgl2'),ex=gl?.getExtension('WEBGL_debug_renderer_info');return {width:c.width,height:c.height,dpr:devicePixelRatio,renderer:ex?gl.getParameter(ex.UNMASKED_RENDERER_WEBGL):'unknown'}});
  await page.evaluate(()=>{
   window.frameAudit={phase:'idle',frames:[],tasks:[]};
   new PerformanceObserver(list=>{for(const e of list.getEntries())window.frameAudit.tasks.push({at:e.startTime,ms:e.duration,phase:window.frameAudit.phase})}).observe({entryTypes:['longtask']});
   let last=null;
   const tick=t=>{const s=window.__godotState,a=window.frameAudit;if(last!==null)a.frames.push({at:t,ms:t-last,phase:a.phase,state:s?.player.state,ultimate:s?.ultimateTime,fps:s?.fps,effects:s?.vfx?.total,bridgeBytes:a.frames.length%60===0?JSON.stringify(s).length:undefined});last=t;requestAnimationFrame(tick)};
   requestAnimationFrame(tick);
  });
  const action=(name,value)=>page.evaluate(({name,value})=>__godotAction(name,value),{name,value});
  const phase=x=>page.evaluate(x=>window.frameAudit.phase=x,x);
  for(const style of (process.env.PERF_STYLES||'azure_empyrea,night_squire,shadow_knight').split(',')){
   await phase(style+':setup');await action('menu');
   await page.waitForFunction(()=>__godotState.campaign.phase==='menu');
   await action('select_style:'+style);await page.waitForFunction(style=>__godotState.player.style===style,style);
   await action('practice');
   await page.waitForFunction(()=>__godotState.campaign.phase==='fight'&&__godotState.started&&__godotState.stageCountdown<=0&&!__godotState.bossEntrance.active);
   const prepare=async()=>{
    const s=await page.evaluate(()=>window.__godotState);
    if(!s.training)await action('training');if(!s.infiniteHp)await action('practice_infinite_hp');
    await page.waitForFunction(()=>__godotState.training&&__godotState.infiniteHp);
    await action('move',1);await page.waitForFunction(()=>Math.abs(__godotState.player.x-__godotState.enemy.x)<1.3);await action('move',0);
   };
   await prepare();
   await phase(style+':idle');await page.waitForTimeout(1800);
   for(let round=1;round<=2;round++){
    await phase(style+':ultimate-'+round);await action('ultimate');await page.waitForTimeout(6500);
    await phase(style+':combat-'+round);
    for(let i=0;i<12;i++){await action(i%4===0?'ability':i%3===0?'heavy':'light');await page.waitForTimeout(210)}
    if(round===1){await phase(style+':restart');await action('restart');await page.waitForFunction(()=>__godotState.time<1&&__godotState.stageCountdown<=0);await prepare();}
   }
  }
  const data=await page.evaluate(()=>window.frameAudit);
  report.slowGL=await page.evaluate(()=>window.slowGL);
  for(const phaseName of [...new Set(data.frames.map(x=>x.phase))]){
   const frames=data.frames.filter(x=>x.phase===phaseName),sorted=frames.map(x=>x.ms).sort((a,b)=>a-b);
   report.runs.push({phase:phaseName,frames:frames.length,mean:sorted.reduce((a,b)=>a+b,0)/sorted.length,p95:sorted[Math.floor(sorted.length*.95)],p99:sorted[Math.floor(sorted.length*.99)],max:sorted.at(-1),over33:sorted.filter(t=>t>33.4).length,spikes:frames.filter(x=>x.ms>40),tasks:data.tasks.filter(x=>x.phase===phaseName)});
  }
  fs.writeFileSync('build/frame-pacing-'+label+'.json',JSON.stringify(report,null,2));
  console.log(JSON.stringify({renderer:report.renderer,errors:report.errors,runs:report.runs.map(({spikes,tasks,...x})=>x)}));
  assert.deepEqual(report.errors,[]);
  for(const run of report.runs.filter(x=>x.phase.includes(':ultimate-'))){
   assert.ok(data.frames.some(x=>x.phase===run.phase&&x.state==='ultimate'),run.phase+' actually played');
  }
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
