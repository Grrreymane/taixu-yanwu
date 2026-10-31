'use strict';
const {chromium}=require('./playwright-runtime.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const source=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../scripts/data/sentience_story_scenes.json'),'utf8'));
const introOnly=process.argv.includes('--intro-only');
const introText=[...source.scenes.A01.lines.map(line=>({id:line.id,text:line.text})),...source.scenes.A01.stageDirections.map((line,index)=>({id:`A01-direction-${String(index+1).padStart(2,'0')}`,text:line.text}))];
const longestIntro=introText.reduce((a,b)=>a.text.length>b.text.length?a:b).id;
const sourceLine=line=>line.lineId.includes('-direction-')
 ? source.scenes[line.sourceSceneId].stageDirections[Number(line.lineId.split('-direction-')[1])-1]
 : source.scenes[line.sourceSceneId].lines.find(row=>row.id===line.lineId);
const out=path.resolve(__dirname,'../../build/screenshots/story-rewrite-web');fs.mkdirSync(out,{recursive:true});
const report={passed:false,errors:[],checks:[],seenScenes:[],scenes:[]};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
try{
 const p=await browser.newPage({viewport:{width:1440,height:900}});
 p.on('pageerror',e=>report.errors.push(e.message));p.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 const state=()=>p.evaluate(()=>structuredClone(window.__godotState));
 const action=(name,value)=>p.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
 const wait=(fn,arg=null)=>p.waitForFunction(fn,arg,{timeout:180000});
 await p.goto(process.env.GODOT_TEST_URL||'http://127.0.0.1:4188/?v='+encodeURIComponent(source.revision));await wait(()=>window.__godotState?.ready);
 await action('start');await wait(()=>window.__godotState.story.active);await p.waitForTimeout(100);
 const shot=async name=>p.screenshot({path:path.join(out,name+'.png')});
 let firstCamera=null,openingLines=0;
 while(true){
  const s=await state(),line=s.story,scene=source.scenes[line.sourceSceneId];
  if(!line.active)break;
  assert.equal(line.revision,source.revision);assert.ok(scene);
  assert.equal(line.text,sourceLine(line).text);
  const camera=s.cinematic.position;if(!firstCamera)firstCamera=camera;else assert.ok(camera.every((x,i)=>Math.abs(x-firstCamera[i])<.00001),'dialogue camera is fixed across clicks');
  if(!line.revealed){await action('story_next');await wait(index=>window.__godotState.story.index===index&&window.__godotState.story.revealed,line.index)}
  if(line.lineId==='A01-02')await shot('opening');
  if(line.kind==='direction'){assert.equal(line.displayName,'旁白');if(line.lineId==='A01-direction-01')await shot('narration')}
  else assert.equal(line.displayName,sourceLine(line).displayName);
  if(line.lineId===longestIntro){
   for(const [width,height] of [[960,540],[360,800],[1440,900]]){await p.setViewportSize({width,height});await p.waitForTimeout(80);const text=(await state()).story;assert.ok(text.textLineCount*text.fontSize<=text.textHeight+1);await shot('text-'+width)}
  }
  await action('story_next');await wait(index=>!window.__godotState.story.active||window.__godotState.story.index!==index,line.index);openingLines++;
 }
 report.checks.push('Full opening matches the manuscript, labels narration, fits three viewports and never moves the dialogue camera');
 report.scenes.push({kind:'intro',lines:openingLines});save();
 if(introOnly){assert.deepEqual(report.errors,[]);report.passed=true;report.scope='opening';save();console.log('STORY_COMPACT_BROWSER_OPENING_PASS');return}
 const begin=Date.now();let rewards=0,retries=0,handled='';
 while(Date.now()-begin<300000){
  const s=await state(),c=s.campaign,player=s.player;
  if(s.story.active){
   const key=s.story.scene+':'+s.story.sourceSceneId+':'+s.story.lineId;
   if(!report.seenScenes.includes(s.story.sourceSceneId))report.seenScenes.push(s.story.sourceSceneId);
   if(key!==handled){handled=key;assert.ok(source.scenes[s.story.sourceSceneId]);assert.equal(s.story.text,sourceLine(s.story).text)}
   if(s.story.scene==='reward'&&s.story.choice.choiceCount===3){
    if(!s.story.revealed)await action('story_next');await p.waitForTimeout(30);await shot('third-reward');assert.equal(s.story.total,2);report.thirdReward=true;
    report.checks.push('Third earned upgrade stays a two-line exchange in the exported browser build');break;
   }
   if(s.story.scene==='defeat'){
    await action('story_skip');if(retries++>=2)throw new Error('Trial bot exhausted retries');await action('retry');continue;
   }
   await action('story_next');await wait(({index,revealed})=>!window.__godotState.story.active||window.__godotState.story.index!==index||window.__godotState.story.revealed!==revealed,{index:s.story.index,revealed:s.story.revealed});continue;
  }
  if(s.bossEntrance.active){await action('boss_skip');continue}
  if(c.phase==='reward'){
   const priority=['breath','reflection','fist','finisher','riposte','flow'];
   const choice=priority.map(id=>c.rewards.findIndex(r=>r.id===id)).find(i=>i>=0)??0;
   report.scenes.push({kind:'reward',stage:c.stageIndex,hp:player.hp});save();rewards++;
   await p.keyboard.press(String(choice+1));await p.waitForTimeout(50);continue;
  }
  if(c.phase==='failed'){if(retries++>=2)throw new Error('Trial bot exhausted retries');await action('retry');continue}
  if(s.paused){await p.keyboard.press('Escape');continue}
  if(c.stageIndex===1&&!s.ended&&!s.ultimate&&s.stageCountdown===0&&!report.groupHealth){
   await shot('group-health');report.groupHealth=s.healthDisplay;
  }
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
 assert.ok(report.thirdReward,'earned third reward reached');assert.ok(!report.seenScenes.includes('J01'),'no unwanted midpoint appended');assert.deepEqual(report.errors,[]);
 report.passed=true;report.retries=retries;save();console.log('STORY_REWRITE_BROWSER_PASS');
}finally{save();await browser.close()}})().catch(e=>{report.failure=e.stack;save();console.error(e);process.exitCode=1});
