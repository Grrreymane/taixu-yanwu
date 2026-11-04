'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),assert=require('node:assert/strict');
const label=process.argv[2]||'sample',cpuRate=Number(process.env.PERF_CPU_RATE||1);
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const report={cpuRate,errors:[],runs:[],stages:[],ultimates:0};
 try{
  const p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
  await p.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v=group-frame-audit');
  await p.waitForFunction(()=>window.__godotState?.ready,null,{timeout:180000});
  if(cpuRate>1){const cdp=await p.context().newCDPSession(p);await cdp.send('Emulation.setCPUThrottlingRate',{rate:cpuRate})}
  await p.evaluate(()=>{
   window.groupFrames=[];let last=null;
   const tick=t=>{const s=window.__godotState;if(last!==null&&s?.campaign.phase==='fight'&&!s.story.active&&!s.bossEntrance.active&&!s.ended&&s.stageCountdown<=0){const n=s.enemies.filter(x=>x.hp>0).length;groupFrames.push({ms:t-last,phase:n+':'+(s.ultimate?'ultimate':'combat'),stage:s.campaign.stageIndex,fx:s.vfx.total})}last=t;requestAnimationFrame(tick)};
   requestAnimationFrame(tick);
  });
  const action=(name,value)=>p.evaluate(({name,value})=>__godotAction(name,value),{name,value});
  await action('start');let retries=0,previousUltimate=false;
  const begin=Date.now();
  while(Date.now()-begin<300000){
   const s=await p.evaluate(()=>window.__godotState),c=s.campaign,player=s.player;
   if(s.story.active){await action('story_skip');await p.waitForTimeout(60);continue}
   if(s.bossEntrance.active){await action('boss_skip');continue}
   if(c.phase==='failed'){if(retries++>=2)throw Error('Group fight bot exhausted retries');await action('retry');continue}
   if(c.phase==='reward'){
    if(c.stageIndex>=3){report.completedGroups=true;break}
    const choice=['breath','reflection','fist','finisher','riposte','flow'].map(id=>c.rewards.findIndex(r=>r.id===id)).find(i=>i>=0)??0;
    await p.keyboard.press(String(choice+1));await p.waitForTimeout(80);continue;
   }
   if(!report.stages.includes(c.stageIndex)){report.stages.push(c.stageIndex);console.log('GROUP_FRAME_STAGE '+c.stageIndex+' CPUx'+cpuRate)}
   if(s.ultimate&&!previousUltimate)report.ultimates++;previousUltimate=s.ultimate;
   if(s.ended||s.ultimate||s.stageCountdown>0){await p.waitForTimeout(60);continue}
   const live=s.enemies.filter(e=>e.hp>0),nearest=live.reduce((best,e)=>!best||Math.abs(e.x-player.x)<Math.abs(best.x-player.x)?e:best,null);
   if(!nearest){await p.waitForTimeout(60);continue}
   const distance=Math.abs(nearest.x-player.x),direction=Math.sign(nearest.x-player.x);
   const threat=live.find(e=>e.state==='attack'&&!e.attack.hasHit&&Math.abs(e.x-player.x)<e.attack.range+.35&&e.attack.windup-e.stateTime>0&&e.attack.windup-e.stateTime<.21);
   let move=distance>1.25?direction:0,guard=false,command=null;
   if(threat){if(threat.attack.unblockable)command='dodge';else guard=true}
   else if(['idle','move','guard'].includes(player.state)){
    if(player.energy>=100)command='ultimate';else if(player.skillCooldown<=0&&distance<2.5)command='ability';else if(distance<1.7)command=nearest.state==='guard'?'heavy':'light';
   }else if(player.state==='attack'&&player.attack.name==='light'&&player.stateTime>.1)command=nearest.state==='guard'?'heavy':'light';
   await p.evaluate(({move,guard,command})=>{__godotAction('move',move);__godotAction('guard_held',guard);if(command)__godotAction(command)},{move,guard,command});
   await p.waitForTimeout(50);
  }
  const frames=await p.evaluate(()=>groupFrames);
  for(const phase of [...new Set(frames.map(x=>x.phase))]){
   const selected=frames.filter(x=>x.phase===phase),sorted=selected.map(x=>x.ms).sort((a,b)=>a-b);
   report.runs.push({phase,frames:sorted.length,mean:sorted.reduce((a,b)=>a+b,0)/sorted.length,p95:sorted[Math.floor(sorted.length*.95)],p99:sorted[Math.floor(sorted.length*.99)],max:sorted.at(-1),over33:sorted.filter(x=>x>33.4).length,peakFx:Math.max(...selected.map(x=>x.fx))});
  }
  fs.writeFileSync('build/group-frame-pacing-'+label+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
  assert.ok(report.completedGroups);assert.ok(report.runs.some(r=>r.phase.startsWith('3:')));assert.ok(report.ultimates>0);assert.deepEqual(report.errors,[]);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
