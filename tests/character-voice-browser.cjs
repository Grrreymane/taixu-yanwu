'use strict';
// Ordinary user controls + passive Web Audio probes. No combat state edits.
const {chromium}=require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../build/screenshots/character-voice-web');fs.mkdirSync(out,{recursive:true});
const report={passed:false,checks:[],errors:[],samples:{},shots:[],input:'Fresh browser; real keys/clicks and ordinary game action bridge, no state edits'};
const save=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 await context.addInitScript(()=>{
  window.__voiceProbe={outputs:[],samples:[],sources:[]};
  const start=AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start=function(...args){const item={duration:this.buffer?.duration||0,at:performance.now(),ended:false};this.addEventListener('ended',()=>item.ended=true);window.__voiceProbe.sources.push(item);return start.apply(this,args)};
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(...args){const result=connect.apply(this,args);if(args[0] instanceof AudioDestinationNode){const analyser=this.context.createAnalyser();analyser.fftSize=2048;connect.call(this,analyser);window.__voiceProbe.outputs.push({analyser,data:new Float32Array(2048),context:this.context})}return result};
  setInterval(()=>{let sum=0,n=0;for(const o of window.__voiceProbe.outputs){o.analyser.getFloatTimeDomainData(o.data);for(const v of o.data){sum+=v*v;n++}}window.__voiceProbe.samples.push({time:performance.now(),rms:n?Math.sqrt(sum/n):0});if(window.__voiceProbe.samples.length>1000)window.__voiceProbe.samples.shift()},15);
 });
 const page=await context.newPage();
 page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
 const read=()=>page.evaluate(()=>structuredClone(window.__godotState));
 const action=(name,value)=>page.evaluate(({name,value})=>window.__godotAction(name,value),{name,value});
 const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
 const check=(name,body)=>{body();report.checks.push(name);save()};
 const shot=async name=>{await page.screenshot({path:path.join(out,name+'.png')});report.shots.push(name);save()};
 const probe=()=>page.evaluate(()=>({peak:Math.max(0,...window.__voiceProbe.samples.map(s=>s.rms)),sources:window.__voiceProbe.sources.slice(-30),contexts:window.__voiceProbe.outputs.map(o=>o.context.state)}));
 const clearProbe=()=>page.evaluate(()=>{window.__voiceProbe.samples=[]});
 async function closeIn(){let s=await read();await action('move',Math.sign(s.enemy.x-s.player.x));await wait(()=>Math.abs(window.__godotState.enemy.x-window.__godotState.player.x)<1.3);await action('move',0);await wait(()=>window.__godotState.player.state==='idle')}
 try{
  await page.goto('http://127.0.0.1:4187/?v=cn-voice-1',{waitUntil:'domcontentloaded'});await wait(()=>window.__godotState?.ready&&window.__godotState.voice,null,120000);
  let s=await read();report.samples.initial=s.voice;
  check('Verified Chinese assets load without autoplay',()=>{assert.equal(s.voice.language,'zh-CN');assert.ok(s.voice.loaded>=25);assert.deepEqual(s.voice.catalogErrors,[]);assert.equal(s.voice.unlocked,false);assert.equal(s.voice.played,0)});
  const r=s.ui.voiceToggleRect;await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await wait(()=>!window.__godotState.voice.enabled);
  s=await read();check('Voice button is independent from music and game state',()=>{assert.equal(s.music.enabled,true);assert.equal(s.campaign.phase,'menu')});
  await page.keyboard.press('v');await wait(()=>window.__godotState.voice.enabled);await page.keyboard.press('m');await wait(()=>!window.__godotState.music.enabled);await shot('01-menu-voice-control');
  await clearProbe();await page.keyboard.press('Enter');await wait(()=>window.__godotState.story.active);
  // Find a naturally available conversational short cue, without injecting one.
  for(let i=0;i<8;i++){
   s=await read();if(s.voice.recent.some(v=>v.category==='dialogue'))break;
   await page.waitForTimeout(180);s=await read();if(!s.story.revealed){await action('story_next');await page.waitForTimeout(80)}
   await action('story_next');await page.waitForTimeout(160);
  }
  s=await read();assert.ok(s.voice.recent.some(v=>v.category==='dialogue'),'Existing Chinese conversational clips actually start');
  const initialKey=s.voice.lastLineKey,played=s.voice.played,index=s.story.index;
  if(!s.story.revealed){await action('story_next');await wait(()=>window.__godotState.story.revealed)}
  await page.waitForTimeout(400);s=await read();
  check('Revealing text does not replay its opening sound',()=>{assert.equal(s.story.index,index);assert.equal(s.voice.lastLineKey,initialKey);assert.equal(s.voice.played,played)});
  report.samples.dialogue={voice:s.voice,audio:await probe()};
  check('Dialogue produces real Web Audio output with BGM muted',()=>assert.ok(report.samples.dialogue.audio.peak>.001));
  await shot('02-dialogue-short-voice');
  const oldKey=initialKey;await action('story_next');await page.waitForTimeout(180);s=await read();
  check('New line replaces rather than overlaps the old short voice',()=>{assert.ok(s.story.index!==index||!s.story.active);assert.ok(s.voice.activePlayers<=1);if(s.voice.current.length)assert.notEqual(s.voice.current[0].lineKey,oldKey)});
  await action('story_skip');await wait(()=>!window.__godotState.story.active);s=await read();check('Skipping dialogue clears its sound',()=>assert.ok(s.voice.current.every(v=>v.category!=='dialogue')));
  await action('menu');
  for(const style of ['azure_empyrea','fenghuang','night_squire']){
   await action('select_style:'+style);await wait(style=>window.__godotState.fighter.styleId===style,style);
   await action('practice');await wait(()=>window.__godotState.started&&!window.__godotState.story.active);await action('training');await wait(()=>window.__godotState.training);
   await closeIn();let since=(await read()).voice.clock;await page.keyboard.press('j');
   await wait(({style,since})=>window.__godotState.voice.recent.some(v=>v.profile===style&&v.category==='attack'&&v.time>=since),{style,since});
   await wait(since=>window.__godotState.voice.recent.some(v=>v.profile==='sentience'&&v.category==='hurt'&&v.time>=since),since);
   s=await read();report.samples[style+'Attack']=s.voice;
   check(style+' attack and the correct enemy hurt voice are wired',()=>{assert.ok(s.voice.activePlayers<=2);assert.ok(s.voice.recent.some(v=>v.channel==='enemy'&&v.category==='hurt'))});
   await wait(()=>window.__godotState.player.state==='idle');await closeIn();since=(await read()).voice.clock;await page.keyboard.press('e');
   await wait(({style,since})=>window.__godotState.voice.recent.some(v=>v.profile===style&&v.category==='ability'&&v.time>=since),{style,since});
   await wait(()=>window.__godotState.player.state==='idle');since=(await read()).voice.clock;await page.keyboard.press('q');
   await wait(({style,since})=>window.__godotState.voice.recent.some(v=>v.profile===style&&v.category==='ultimate'&&v.time>=since),{style,since});
   report.samples[style+'Ultimate']=(await read()).voice;check(style+' has a native Chinese ultimate/activation sound',()=>assert.ok(report.samples[style+'Ultimate'].recent.some(v=>v.category==='ultimate'&&v.profile===style)));
   if(style==='azure_empyrea'){
    await wait(()=>window.__godotState.voice.current.some(v=>v.category==='ultimate'&&v.elapsed>.6));
    await page.keyboard.press('Escape');await wait(()=>window.__godotState.voice.paused);const frozen=await read();await clearProbe();await page.waitForTimeout(550);const still=await read();
    check('Pause freezes voice position and lifetime rather than restarting',()=>{assert.deepEqual(still.voice.current.map(v=>v.elapsed),frozen.voice.current.map(v=>v.elapsed));assert.equal(still.voice.played,frozen.voice.played);assert.equal(still.voice.playing,false)});
    await page.keyboard.press('Escape');await wait(()=>!window.__godotState.voice.paused);await page.waitForTimeout(160);s=await read();
    check('Resume continues the same ultimate voice once',()=>{assert.equal(s.voice.played,frozen.voice.played);assert.ok(s.voice.current.some(v=>v.category==='ultimate'&&v.elapsed>frozen.voice.current[0].elapsed))});
   }
   await shot('03-'+style+'-cast');await action('menu');await wait(()=>window.__godotState.campaign.phase==='menu');s=await read();check(style+' menu exit stops all old voices',()=>assert.equal(s.voice.active,false));
  }
  // A real enemy attack must use the player profile for the receiving hurt sound.
  await action('practice');await wait(()=>window.__godotState.started&&!window.__godotState.training);let since=(await read()).voice.clock;
  await action('move',1);await page.waitForTimeout(500);await action('move',0);
  await wait(since=>window.__godotState.voice.recent.some(v=>v.channel==='player'&&v.category==='hurt'&&v.time>=since),since,30000);
  s=await read();report.samples.receivedHit=s.voice;check('Taking a hit uses White Night voice, not the attacker voice',()=>assert.ok(s.voice.recent.some(v=>v.channel==='player'&&v.profile==='night_squire'&&v.category==='hurt'&&v.time>=since)));
  await page.keyboard.press('v');await wait(()=>!window.__godotState.voice.enabled);s=await read();check('Mute immediately silences the voice players',()=>{assert.equal(s.voice.active,false);assert.equal(s.music.enabled,false)});
  await page.reload({waitUntil:'domcontentloaded'});await wait(()=>window.__godotState?.ready&&window.__godotState.voice,null,120000);s=await read();
  check('Voice preference persists independently across reload',()=>{assert.equal(s.voice.enabled,false);assert.equal(s.music.enabled,false);assert.equal(s.voice.played,0)});
  check('No browser/audio/script errors',()=>assert.deepEqual(report.errors,[]));report.passed=true;save();console.log(JSON.stringify({passed:true,checks:report.checks.length}));
 }catch(e){report.failure=e.stack;save();throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
