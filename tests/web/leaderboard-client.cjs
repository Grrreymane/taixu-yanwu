'use strict';
const assert=require('node:assert/strict'),create=require('../../web/leaderboard.js');
function fixture(handler){let id=0,listeners=new Set(),handshakes=0;const calls=[];
 const w={crypto:{randomUUID:()=>`00000000-0000-4000-8000-${String(++id).padStart(12,'0')}`},setTimeout,clearTimeout,
 addEventListener:(t,f)=>listeners.add(f),removeEventListener:(t,f)=>listeners.delete(f),
 fetch:async(url,options)=>{calls.push({url,options});return handler(url,options,calls.length);}};
 w.parent={postMessage:(data,target)=>{if(target!=='https://www.aiwanna.games')return;handshakes++;queueMicrotask(()=>{for(const fn of [...listeners])fn({source:w.parent,origin:target,data:{source:'aimadegames-platform',type:'leaderboard-session',requestId:data.requestId,apiOrigin:target,session:{token:'mock-only'}}})})}};
 return {w,calls,client:create(w),listeners,handshakes:()=>handshakes};
}
const response=(data,status=200,headers={})=>({ok:status<400,status,headers:{get:k=>headers[k]??null},json:async()=>data});
(async()=>{
 let releaseStart;const f=fixture(async(url,opts)=>url.endsWith('/runs')?new Promise(resolve=>{releaseStart=()=>resolve(response({runId:'run-a'}))}):response({accepted:true,isPersonalBest:true,rank:1,personalBest:12345}));
 f.client.begin('a');await new Promise(r=>setImmediate(r));const pending=f.client.finish('a',12345);f.client.finish('a',99999);releaseStart();await pending;
 assert.equal(f.calls.length,2);assert.equal(JSON.parse(f.calls[1].options.body).score,12345);assert.notEqual(f.calls[0].options.headers['Idempotency-Key'],f.calls[1].options.headers['Idempotency-Key']);assert.equal(f.listeners.size,0);
 await f.client.retry();assert.equal(f.calls.length,2);
 let submits=0;const g=fixture(async(url)=>url.endsWith('/runs')?response({runId:'run-b'}):++submits===1?response({error:{code:'SESSION_EXPIRED'}},401):submits===2?response({},429,{'Retry-After':'0'}):response({accepted:true,rank:2}));
 g.client.begin('b');await new Promise(r=>setImmediate(r));await g.client.finish('b',32100);assert.equal(g.handshakes(),2);const scoreCalls=g.calls.filter(x=>x.url.endsWith('/score'));assert.equal(scoreCalls.length,3);assert.equal(new Set(scoreCalls.map(x=>x.options.headers['Idempotency-Key'])).size,1);assert.equal(new Set(scoreCalls.map(x=>x.options.body)).size,1);assert.ok(g.calls.every(x=>x.options.credentials==='omit'));
 const c=fixture(async()=>response({runId:'cancelled'}));c.client.begin('c');c.client.cancel();await new Promise(r=>setImmediate(r));await c.client.finish('c',1234);assert.equal(c.calls.length,1);
 const invalid=fixture(async()=>response({runId:'invalid'}));invalid.client.begin('d');await new Promise(r=>setImmediate(r));invalid.client.finish('d',-1);invalid.client.finish('d',NaN);assert.equal(invalid.calls.length,1);
 let liveFetch=0;const w={parent:null,fetch:()=>{liveFetch++}};w.parent=w;const standalone=create(w);standalone.begin('offline');standalone.finish('offline',30000);assert.equal(liveFetch,0);
 let lateStart;const race=fixture(async(url)=>url.endsWith('/runs')?new Promise(resolve=>{lateStart=()=>resolve(response({runId:'old'}))}):response({accepted:true}));race.client.begin('old');await new Promise(r=>setImmediate(r));const old=race.client.finish('old',5555);race.client.cancel();lateStart();await old;assert.equal(race.calls.filter(x=>x.url.endsWith('/score')).length,1);
 console.log('LEADERBOARD_PROTOCOL_PASS: delayed start, duplicate finish, 401 renewal, 429 retry, cancelled run, invalid scores, standalone, old completion');
})().catch(e=>{console.error(e);process.exitCode=1});
