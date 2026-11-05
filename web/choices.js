/* Accessible web selection UI. Only forwards ordinary game actions. */
(() => {
 'use strict';
 let root,grid,title,footer,extras,entry,infoDialog,lastKey='',mode='',locked=false,returnFocus=null;
 const node=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text)n.textContent=text;return n};
 const send=(action)=>{if(!locked){locked=true;window.__godotAction?.(action)}};
 function init(){
  root=node('section');root.id='battle-choices';root.hidden=true;
  root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');root.setAttribute('aria-labelledby','bc-title');
  const panel=node('div','bc-panel');title=node('h1','bc-title');title.id='bc-title';
  grid=node('div','bc-grid');footer=node('div','bc-footer');extras=node('div','bc-extras');panel.append(title,grid,extras,footer);root.append(panel);document.body.append(root);
  entry=node('button','bc-practice-entry','打法配置  B');entry.id='practice-build-entry';entry.hidden=true;
  entry.setAttribute('aria-label','自由对练打法配置');entry.setAttribute('aria-haspopup','dialog');entry.setAttribute('aria-controls','battle-choices');entry.setAttribute('aria-keyshortcuts','B');
  entry.addEventListener('click',()=>window.__godotAction?.('practice_build'));document.body.append(entry);
  infoDialog=node('dialog');infoDialog.id='battle-choice-info';infoDialog.setAttribute('aria-labelledby','bc-info-title');document.body.append(infoDialog);
  infoDialog.addEventListener('close',()=>returnFocus?.focus());
  window.addEventListener('keydown',e=>{
   if(root.hidden)return;
   if(infoDialog.open){e.stopImmediatePropagation();return}
   if(e.key==='Tab'){
    const items=[...root.querySelectorAll('button:not(:disabled),input:not(:disabled)')],i=items.indexOf(document.activeElement);
    if(e.shiftKey&&i<=0){items.at(-1)?.focus();e.preventDefault()}
    else if(!e.shiftKey&&(i<0||i===items.length-1)){items[0]?.focus();e.preventDefault()}
   }else if(['1','2','3'].includes(e.key)){
    e.preventDefault();grid.children[Number(e.key)-1]?.querySelector('.bc-select')?.click();
   }else if((e.key==='Escape'||e.key.toLowerCase()==='b')&&mode==='practice'){e.preventDefault();send('practice_build_cancel')}
   else if(e.key==='Escape'&&mode==='core'){e.preventDefault();send('menu')}
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
 function practiceControls(s,focusId,entering){
  const build=s.practiceBuild;
  const baseline=node('button','bc-secondary bc-baseline','基础招式');baseline.id='bc-baseline';
  baseline.setAttribute('aria-label','基础招式，不使用核心与专属强化');baseline.setAttribute('aria-pressed',String(!build.core));
  baseline.addEventListener('click',()=>window.__godotAction?.('practice_core:'));extras.append(baseline);
  if(build.perks.length){
   const group=node('fieldset','bc-perks'),legend=node('legend',null,'专属强化'),list=node('div','bc-perk-grid');group.append(legend,list);
   build.perks.forEach(row=>{
    const label=node('label','bc-perk'),input=node('input');input.type='checkbox';input.id='bc-perk-'+row.id;
    input.checked=build.selectedPerks.includes(row.id);input.setAttribute('aria-labelledby',input.id+'-name');input.setAttribute('aria-describedby',input.id+'-effect');
    const copy=node('span'),name=node('span','bc-perk-name',row.title),effect=node('span','bc-perk-effect',row.description);
    name.id=input.id+'-name';effect.id=input.id+'-effect';copy.append(name,effect);label.append(input,copy);list.append(label);
    input.addEventListener('change',()=>window.__godotAction?.('practice_perk:'+row.id));
   });extras.append(group);
  }
  const cancel=node('button','bc-secondary','取消'),apply=node('button','bc-primary','应用并重置对练');
  cancel.id='bc-cancel';apply.id='bc-apply';
  cancel.addEventListener('click',()=>send('practice_build_cancel'));apply.addEventListener('click',()=>send('practice_build_apply'));footer.append(cancel,apply);
  if(!entering&&focusId&&document.getElementById(focusId))document.getElementById(focusId).focus({preventScroll:true});
  else {title.tabIndex=-1;title.focus()}
 }
 window.updateBattleChoices=s=>{
  const next=s.practiceBuild?.style?'practice':s.nightCoreChoice?'core':s.campaign?.phase==='reward'&&!s.paused&&!s.story?.active&&!s.ko?.active?'reward':'';
  const practiceAvailable=s.campaign?.mode==='practice'&&['fight','cleared','failed'].includes(s.campaign?.phase)&&!s.story?.active;
  if(!root){if(!next&&!practiceAvailable)return;init()}
  entry.hidden=!practiceAvailable||!!next;
  const entryRect=s.ui?.practiceBuildRect;
  if(entryRect?.length===4){
   const width=Math.max(144,entryRect[2]),height=Math.max(38,entryRect[3]);
   entry.style.left=Math.max(8,Math.min(entryRect[0],window.innerWidth-width-16))+'px';entry.style.top=entryRect[1]+'px';entry.style.width=width+'px';entry.style.height=height+'px';entry.style.right='auto';
  }
  if(!next){
   if(!root.hidden){root.hidden=true;infoDialog.close();document.getElementById('canvas')?.removeAttribute('inert');document.getElementById('canvas')?.focus()}
   lastKey='';mode='';return;
  }
  const practice=next==='practice';
  const rows=practice?s.practiceBuild.options:next==='core'?s.coreOptions:s.campaign.rewards;
  const key=JSON.stringify([next,rows,s.campaign.rerollsRemaining,practice?s.practiceBuild:null]);
  if(key===lastKey)return;
  const rerolling=mode===next&&!root.hidden;
  const focusId=document.activeElement?.id;
  lastKey=key;mode=next;locked=false;root.hidden=false;infoDialog.close();
  document.getElementById('canvas')?.setAttribute('inert','');
  root.classList.toggle('bc-practice',practice);
  title.textContent=next==='core'||practice?(s.fighter.styleName||s.roster?.styleName||'装甲')+(practice?' · 打法配置':' · 核心打法'):'选择强化';
  grid.setAttribute('role','group');grid.setAttribute('aria-label',practice?'核心打法':'候选项');
  grid.replaceChildren();footer.replaceChildren();extras.replaceChildren();
  rows.forEach((row,index)=>{
   const card=node('div','bc-card'),select=node('button','bc-select');
   const selected=practice&&s.practiceBuild.core===row.id;
   const h=node('span','bc-name',row.title),effect=node('span','bc-effect',row.description),action=node('span','bc-action',`${index+1}  ·  ${selected?'已选':next==='core'||practice?'选用':'选取并继续'} →`);
   select.id='bc-core-'+row.id;
   h.id=`bc-name-${index}`;effect.id=`bc-effect-${index}`;
   select.setAttribute('aria-label',(practice?'':next==='core'?'选用 ':'选取并继续 ')+row.title);select.setAttribute('aria-describedby',effect.id);
   if(practice)select.setAttribute('aria-pressed',String(selected));
   action.setAttribute('aria-hidden','true');select.append(h,effect,action);
   select.addEventListener('click',()=>{
    if(practice){window.__godotAction?.('practice_core:'+row.id);return}
    send(next==='core'?'night_core:'+row.id:'reward_'+index);[...grid.querySelectorAll('button')].forEach(b=>b.disabled=true)
   });
   card.append(select);
   const extra=practice?(s.practiceBuild.basics||row.hint):next==='core'?(s.coreBasics||row.hint):row.buildPreview;
   if(extra){
    const info=node('button','bc-info','i'),tip=node('div','bc-tooltip',extra);tip.hidden=true;tip.setAttribute('role','tooltip');tip.id=`bc-tip-${index}`;
    info.setAttribute('aria-label',row.title+'，查看详情');info.setAttribute('aria-describedby',tip.id);
    info.addEventListener('mouseenter',()=>tip.hidden=false);info.addEventListener('mouseleave',()=>tip.hidden=true);
    info.addEventListener('focus',()=>tip.hidden=false);info.addEventListener('blur',()=>tip.hidden=true);
    info.addEventListener('click',()=>{tip.hidden=true;details(info,row.title,extra)});card.append(info,tip);
   }
   grid.append(card);
  });
  if(practice){practiceControls(s,focusId,!rerolling);return}
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
