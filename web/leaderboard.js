/* AIWANNA REST leaderboard integration, promptVersion 2026-10-26. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory;
  else root.TaixuLeaderboard = factory(root);
})(typeof window === 'undefined' ? globalThis : window, function (w) {
  'use strict';
  const board = 'fffcacee-6f15-4e34-ba16-b45072177c4d';
  const origins = ['https://www.aiwanna.games','https://aiwanna.games','https://www.ai-made.games','https://ai-made.games','https://1gp-game-platform.vercel.app'];
  let session = null, connecting = null, current = null;
  let message = w.parent === w ? '请在 AIWanna 内游玩以参与排行榜' : '新开试炼并完成六关即可上榜';
  const standalone = w.parent === w;
  const sleep = ms => new Promise(resolve => w.setTimeout(resolve, ms));
  const status = text => { message = text; if (statusNode) statusNode.textContent = text; };
  let statusNode = null, panel = null, button = null;
  function connect() {
    if (standalone) return Promise.reject(new Error('请从 AIWanna 开始游戏后再上榜'));
    if (session) return Promise.resolve(session);
    if (connecting) return connecting;
    connecting = new Promise((resolve, reject) => {
      const requestId = w.crypto.randomUUID();
      const done = (error, value) => {
        w.clearTimeout(timer); w.removeEventListener('message', receive);
        if (error) reject(error); else { session = value; resolve(value); }
      };
      const receive = event => {
        const data = event.data;
        if (event.source !== w.parent || !origins.includes(event.origin) || !data ||
            data.source !== 'aimadegames-platform' || data.type !== 'leaderboard-session' || data.requestId !== requestId) return;
        if (data.error) return done(new Error('平台暂时无法连接排行榜，可继续游戏'));
        if (data.apiOrigin !== event.origin || typeof data.session?.token !== 'string') return;
        done(null, {origin:event.origin, token:data.session.token});
      };
      const timer = w.setTimeout(() => done(new Error('排行榜连接超时，可继续游戏')), 15000);
      w.addEventListener('message', receive);
      for (const origin of origins) w.parent.postMessage({source:'aimadegames',type:'leaderboard-session',requestId}, origin);
    }).finally(() => { connecting = null; });
    return connecting;
  }
  async function request(path, method='GET', key=null, score=null) {
    for (let attempt=0; attempt<3; attempt++) {
      const auth = await connect();
      const headers = {Authorization:'Bearer '+auth.token};
      if (key) headers['Idempotency-Key'] = key;
      if (score !== null) headers['Content-Type'] = 'application/json';
      let response;
      try {
        response = await w.fetch(auth.origin+path, {method, credentials:'omit', headers,
          ...(score === null ? {} : {body:JSON.stringify({score})}), signal:AbortSignal.timeout(15000)});
      } catch (error) { if (attempt===2) throw new Error('网络暂时不可用，可稍后重试'); await sleep(500*(attempt+1)); continue; }
      if (response.status===401 && attempt<2) { session=null; continue; }
      if (response.status===429 && attempt<2) {
        const raw=response.headers.get('Retry-After');
        const delay=/^\d+(\.\d+)?$/.test(raw||'') ? Number(raw)*1000 : Math.max(0,Date.parse(raw)-Date.now());
        await sleep(Number.isFinite(delay) ? delay : 60000); continue;
      }
      if (response.status>=500 && attempt<2) { await sleep(1000*(attempt+1)); continue; }
      const data=await response.json();
      if (!response.ok) {
        const messages={RUN_EXPIRED:'本轮已超过两小时上榜期限，本地成绩仍保留',ALREADY_SUBMITTED:'本轮已结算，请刷新榜单查看',BOARD_UNAVAILABLE:'排行榜暂不可用',INVALID_SCORE:'本轮成绩不符合榜单范围',BOARD_LIMIT:'本轮成绩不符合榜单限制',FORBIDDEN:'本轮账号或权限已变化，无法提交',RATE_LIMITED:'请求较多，请稍后重试'};
        throw new Error(messages[data.error?.code]||'排行榜暂时不可用，可稍后重试');
      }
      return data;
    }
    throw new Error('排行榜连接失败，可稍后重试');
  }
  function cancel(reason='本次为续档或自由对练，不提交排行榜') {
    if (current && current.score===null) current.cancelled=true;
    current=null; status(standalone ? '请在 AIWanna 内游玩以参与排行榜' : reason);
  }
  function begin(id) {
    if (current?.id===id) return;
    cancel();
    if (standalone) return;
    const run={id, startKey:w.crypto.randomUUID(), finishKey:w.crypto.randomUUID(), runId:null,
      score:null, cancelled:false, receipt:null, startPromise:null, submitting:null};
    current=run; status('正在登记本轮试炼…');
    start(run).catch(error => { if (current===run) status(error.message); });
  }
  function start(run) {
    if (run.runId) return Promise.resolve(run.runId);
    if (run.startPromise) return run.startPromise;
    run.startPromise=request('/api/v1/leaderboards/'+board+'/runs','POST',run.startKey).then(data=>{
      if (typeof data.runId!=='string') throw new Error('排行榜返回无效，请稍后重试');
      run.runId=data.runId;
      if (current===run && run.score===null) status('本轮已登记 · 六关通关后自动提交');
      return run.runId;
    }).finally(()=>{run.startPromise=null;});
    return run.startPromise;
  }
  function settle(run) {
    if (run.receipt) return Promise.resolve(run.receipt);
    if (run.submitting) return run.submitting;
    run.submitting=(async()=>{
      // A failed start must not be created retroactively at the finish line.
      if (!run.runId && !run.startPromise) throw new Error('开局登记未成功，本轮仅保留本地成绩');
      const runId=await start(run);
      const receipt=await request('/api/v1/runs/'+encodeURIComponent(runId)+'/score','POST',run.finishKey,run.score);
      if (receipt.accepted!==true) throw new Error('成绩未被接受，请刷新榜单查看');
      run.receipt=receipt;
      if(current===run) status((receipt.isPersonalBest?'刷新个人最佳！':'成绩已提交')+(receipt.rank ? ' · 第 '+receipt.rank+' 名' : ''));
      return receipt;
    })().catch(error=>{if(current===run)status(error.message);return null;}).finally(()=>{run.submitting=null;});
    return run.submitting;
  }
  function finish(id, score) {
    const run=current;
    if(!run || run.id!==id || run.cancelled || run.score!==null) return;
    if(!Number.isSafeInteger(score)||score<1||score>604800000){status('成绩超出榜单范围，本地成绩仍保留');return;}
    run.score=score; status('通关！正在提交用时…'); return settle(run);
  }
  const format = ms => { const s=Math.floor(ms/1000);return Math.floor(s/60)+':'+String(s%60).padStart(2,'0')+'.'+String(ms%1000).padStart(3,'0'); };
  async function standings() {
    const entries=await request('/api/v1/leaderboards/'+board+'/entries?limit=10');
    const me=await request('/api/v1/leaderboards/'+board+'/me?around=2');
    return {entries:entries.entries||[],me:me.entry};
  }
  function sync(phase, blocked) { if(button)button.hidden=blocked||!['menu','cleared','failed'].includes(phase); if(panel?.open&&button?.hidden)panel.close(); }
  if(w.document){
    const d=w.document;
    button=d.createElement('button'); button.id='ranking-open';button.textContent='通关榜';button.hidden=true;d.body.append(button);
    panel=d.createElement('dialog');panel.id='ranking-panel';
    const title=d.createElement('h2');title.textContent='六关通关用时榜';
    const rules=d.createElement('p');rules.textContent='战斗累计用时越短越好；重试累计，剧情与暂停不计时。所有装甲与规矩共榜。仅在 AIWanna 内新开的完整六关试炼可上榜，续档与自由对练不提交；开局后两小时内结算。';
    statusNode=d.createElement('p');statusNode.textContent=message;statusNode.setAttribute('role','status');
    const rows=d.createElement('ol'),personal=d.createElement('p'),refresh=d.createElement('button'),retry=d.createElement('button'),close=d.createElement('button');
    refresh.textContent='刷新排行';retry.textContent='重试提交';close.textContent='关闭';
    panel.append(title,rules,statusNode,personal,rows,refresh,retry,close);d.body.append(panel);
    const read=async()=>{refresh.disabled=true;try{const data=await standings();rows.replaceChildren();for(const row of data.entries){const li=d.createElement('li');li.textContent='#'+row.rank+'  '+(row.player?.displayName||'玩家')+'  '+format(row.score);rows.append(li);}if(!data.entries.length)rows.textContent='还没有通关记录';personal.textContent=data.me?'我的最佳：'+format(data.me.score)+' · 第 '+data.me.rank+' 名':'我的最佳：暂无记录';}catch(error){status(error.message);}finally{refresh.disabled=false;}};
    button.onclick=()=>{panel.showModal();read();};refresh.onclick=read;close.onclick=()=>{panel.close();d.getElementById('canvas')?.focus();};
    retry.onclick=()=>{if(current?.score!==null&&current?.score!==undefined)settle(current);else status('尚无待提交的通关成绩');};
    for(const type of ['keydown','keyup'])panel.addEventListener(type,event=>event.stopPropagation());
  }
  return {begin,cancel,finish,sync,standings,retry:()=>current?.score!=null ? settle(current) : Promise.resolve(null)};
});
