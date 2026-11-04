/* Accessible web selection UI. Only forwards ordinary game actions. */
(() => {
 'use strict';
 let root,grid,title,footer,infoDialog,lastKey='',mode='',locked=false,returnFocus=null;
 const node=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text)n.textContent=text;return n};
 const send=(action)=>{if(!locked){locked=true;window.__godotAction?.(action)}};
 function init(){
  root=node('section');root.id='battle-choices';root.hidden=true;
  root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');root.setAttribute('aria-labelledby','bc-title');
  const panel=node('div','bc-panel');title=node('h1','bc-title');title.id='bc-title';
  grid=node('div','bc-grid');footer=node('div','bc-footer');panel.append(title,grid,footer);root.append(panel);document.body.append(root);
  infoDialog=node('dialog');infoDialog.id='battle-choice-info';infoDialog.setAttribute('aria-labelledby','bc-info-title');document.body.append(infoDialog);
  infoDialog.addEventListener('close',()=>returnFocus?.focus());
  window.addEventListener('keydown',e=>{
   if(root.hidden)return;
   if(infoDialog.open){e.stopImmediatePropagation();return}
   if(e.key==='Tab'){
    const items=[...root.querySelectorAll('button:not(:disabled)')],i=items.indexOf(document.activeElement);
    if(e.shiftKey&&i<=0){items.at(-1)?.focus();e.preventDefault()}
    else if(!e.shiftKey&&(i<0||i===items.length-1)){items[0]?.focus();e.preventDefault()}
   }else if(['1','2','3'].includes(e.key)){
    e.preventDefault();grid.children[Number(e.key)-1]?.querySelector('.bc-select')?.click();
   }else if(e.key==='Escape'&&mode==='core'){e.preventDefault();send('menu')}
   e.stopImmediatePropagation();
  },true);
 }
 function details(button,heading,body){
  returnFocus=button;infoDialog.replaceChildren();
  const h=node('h2',null,heading);h.id='bc-info-title';const p=node('p',null,body);p.id='bc-info-body';
  infoDialog.setAttribute('aria-describedby','bc-info-body');
  const close=node('button','bc-secondary','关闭');close.addEventListener('click',()=>infoDialog.close());
  infoDialog.append(h,p,close);infoDialog.showModal();close.focus();
 }
 window.updateBattleChoices=s=>{
  const next=s.nightCoreChoice?'core':s.campaign?.phase==='reward'&&!s.paused&&!s.story?.active&&!s.ko?.active?'reward':'';
  if(!root){if(!next)return;init()}
  if(!next){
   if(!root.hidden){root.hidden=true;infoDialog.close();document.getElementById('canvas')?.removeAttribute('inert');document.getElementById('canvas')?.focus()}
   lastKey='';mode='';return;
  }
  const rows=next==='core'?s.coreOptions:s.campaign.rewards;
  const key=JSON.stringify([next,rows,s.campaign.rerollsRemaining]);
  if(key===lastKey)return;
  const rerolling=mode===next&&!root.hidden;
  lastKey=key;mode=next;locked=false;root.hidden=false;infoDialog.close();
  document.getElementById('canvas')?.setAttribute('inert','');
  title.textContent=next==='core'?(s.fighter.styleName||s.roster?.styleName||'装甲')+' · 核心打法':'选择强化';
  grid.replaceChildren();footer.replaceChildren();
  rows.forEach((row,index)=>{
   const card=node('div','bc-card'),select=node('button','bc-select');
   const h=node('span','bc-name',row.title),effect=node('span','bc-effect',row.description),action=node('span','bc-action',`${index+1}  ·  ${next==='core'?'选用':'选取并继续'} →`);
   h.id=`bc-name-${index}`;effect.id=`bc-effect-${index}`;
   select.setAttribute('aria-label',(next==='core'?'选用 ':'选取并继续 ')+row.title);select.setAttribute('aria-describedby',effect.id);
   action.setAttribute('aria-hidden','true');select.append(h,effect,action);
   select.addEventListener('click',()=>{send(next==='core'?'night_core:'+row.id:'reward_'+index);[...grid.querySelectorAll('button')].forEach(b=>b.disabled=true)});
   card.append(select);
   const extra=next==='core'?(s.coreBasics||row.hint):row.buildPreview;
   if(extra){
    const info=node('button','bc-info','i'),tip=node('div','bc-tooltip',extra);tip.hidden=true;tip.setAttribute('role','tooltip');tip.id=`bc-tip-${index}`;
    info.setAttribute('aria-label',row.title+'，查看详情');info.setAttribute('aria-describedby',tip.id);
    info.addEventListener('mouseenter',()=>tip.hidden=false);info.addEventListener('mouseleave',()=>tip.hidden=true);
    info.addEventListener('focus',()=>tip.hidden=false);info.addEventListener('blur',()=>tip.hidden=true);
    info.addEventListener('click',()=>{tip.hidden=true;details(info,row.title,extra)});card.append(info,tip);
   }
   grid.append(card);
  });
  const secondary=node('button','bc-secondary',next==='core'?'返回':`换一组（${s.campaign.rerollsRemaining}）`);
  secondary.setAttribute('aria-label',next==='core'?'返回装甲选择':`更换三项强化，剩余 ${s.campaign.rerollsRemaining} 次`);
  secondary.disabled=next==='reward'&&s.campaign.rerollsRemaining<=0;
  secondary.addEventListener('click',()=>{send(next==='core'?'menu':'reroll_rewards');secondary.disabled=true});footer.append(secondary);
  if(next==='reward'){
   const context=node('button','bc-secondary','i');context.setAttribute('aria-label','查看已获强化、补给和下一战');
   context.addEventListener('click',()=>details(context,'本轮强化与下一战',`已获强化：${s.campaign.boons?.join(' / ')||'无'}\n\n${s.campaign.buildSummary||''}\n\n${s.campaign.supply||''}\n\n下一战：${s.campaign.nextEncounter||''}`));footer.append(context);
  }
  // Focus the neutral heading on entry; no upgrade is visually recommended.
  title.tabIndex=-1;if(!rerolling)title.focus();else secondary.disabled?title.focus():secondary.focus();
 };
})();
