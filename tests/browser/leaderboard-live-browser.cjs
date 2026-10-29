'use strict';
const {chromium}=require('./playwright-runtime.cjs'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});const report={requests:[],milestones:[],passed:false};
try{const page=await b.newPage({viewport:{width:1440,height:1000}});
page.on('response',async r=>{if(/\/api\/v1\/(leaderboards|runs)\//.test(r.url())){try{const body=await r.json();report.requests.push({url:r.url(),status:r.status(),body});console.log('RANK_API',r.status(),r.url().split('/api/v1/')[1]);}catch{}}});
await page.goto('https://www.aiwanna.games/games/game-3ae8aa2793124454/playing');await page.waitForSelector('iframe');const f=await (await page.locator('iframe').first().elementHandle()).contentFrame();
await f.waitForFunction(()=>window.__godotState?.ready&&window.TaixuLeaderboard,null,{timeout:180000});
await f.locator('#ranking-open').click();await f.locator('#ranking-panel').waitFor({state:'visible'});await page.waitForTimeout(1800);await f.getByRole('button',{name:'关闭',exact:true}).click();
const act=(x,v)=>f.evaluate(([x,v])=>window.__godotAction(x,v),[x,v]);await act('select_style:hawk_of_the_fog');await act('start');
let lastStage=-1,retries=0;const began=Date.now();
while(Date.now()-began<480000){
const s=await f.evaluate(()=>window.__godotState),c=s.campaign,p=s.player;
if(c.phase==='cleared'){report.elapsedMs=c.runTimeMs;report.milestones.push({phase:'cleared',elapsedMs:c.runTimeMs});break;}
if(s.story.active){await act('story_skip');await page.waitForTimeout(120);continue;}
if(s.bossEntrance.active){await act('boss_skip');await page.waitForTimeout(120);continue;}
if(c.phase==='failed'){if(retries++>=3)throw Error('Normal-input trial did not clear');await act('retry');continue;}
if(c.phase==='reward'){const choice=c.rewards.findIndex(r=>r.id==='breath');await act('reward_'+(choice<0?0:choice));await page.waitForTimeout(120);continue;}
if(c.stageIndex!==lastStage){lastStage=c.stageIndex;console.log('STAGE',lastStage+1,'HP',p.hp);report.milestones.push({stage:lastStage+1,hp:p.hp});}
if(s.ended||s.ultimate||s.stageCountdown>0){await page.waitForTimeout(80);continue;}
const live=s.enemies.filter(e=>e.hp>0),nearest=live.reduce((a,e)=>!a||Math.abs(e.x-p.x)<Math.abs(a.x-p.x)?e:a,null);if(!nearest){await page.waitForTimeout(80);continue;}
const distance=Math.abs(nearest.x-p.x),direction=Math.sign(nearest.x-p.x);
const threat=live.find(e=>e.state==='attack'&&e.attack&&!e.attack.hasHit&&Math.abs(e.x-p.x)<e.attack.range+.3&&e.attack.windup-e.stateTime>0&&e.attack.windup-e.stateTime<.22);
let command=null,guard=false;const move=distance>1.3?direction:0;
if(['idle','move','guard'].includes(p.state)){if(threat){if(threat.attack.unblockable)command='dodge';else guard=true;}else if(p.energy>=100)command='ultimate';else if(p.skillCooldown<=0&&distance<2.5)command='ability';else if(distance<1.7)command=nearest.state==='guard'?'heavy':'light';}
else if(p.state==='attack'&&p.attack.name==='light'&&p.stateTime>.1)command=nearest.state==='guard'?'heavy':'light';
await f.evaluate(({move,guard,command})=>{__godotAction('move',move);__godotAction('guard_held',guard);if(command)__godotAction(command)},{move,guard,command});await page.waitForTimeout(65);
}
assert.ok(report.elapsedMs>0,'six stages cleared through normal controls');await page.waitForTimeout(2000);
const receipt=report.requests.find(x=>x.url.endsWith('/score')&&x.body.accepted===true);assert.ok(receipt,'real clear accepted');assert.equal(receipt.body.submittedScore,report.elapsedMs);
await act('story_skip');await act('victory_skip');await act('menu');await f.locator('#ranking-open').click();await page.waitForTimeout(1000);await page.screenshot({path:'build/leaderboard-live.png'});report.passed=true;console.log('LEADERBOARD_REAL_CLEAR_PASS');
}finally{fs.writeFileSync('build/leaderboard-live-report.json',JSON.stringify(report,null,2));await b.close();}})().catch(e=>{console.error(e);process.exitCode=1});
