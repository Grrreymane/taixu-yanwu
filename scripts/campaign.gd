extends RefCounted

const SAVE_PATH := "user://taixu_record.cfg"
const CLEAR_HEAL := 6.0
const REGIONS := ["晨岚台", "竹影庭", "赤霄坛"]
const CONTRACTS := {
 "mirror":{"id":"mirror","title":"明镜之约","description":"极限防御后的追击伤害提高 20%。识律幻身偏重正面压制。","rule":"防反追击伤害 +20%","objective":"完成 2 次极限防御","stat":"parries","target":2.0,"reward":"riposte"},
 "flow":{"id":"flow","title":"流转之约","description":"成功闪避攻击，立即缩短 E 冷却 1 秒。追袭幻身更常出现。","rule":"成功闪避使 E 冷却减少 1 秒","objective":"成功闪避 2 次攻击","stat":"dodges","target":2.0,"reward":"windstep"},
 "breaker":{"id":"breaker","title":"破阵之约","description":"架势伤害提高 20%。更多守御幻身，需要重击打开破绽。","rule":"架势伤害 +20%","objective":"打出 6 连击","stat":"maxCombo","target":6.0,"reward":"finisher"}
}
const REWARDS := {
 "fist":{"id":"fist","title":"寸心如锋","description":"所有攻击伤害提高 16%。"},
 "flow":{"id":"flow","title":"行云流水","description":"命中获得的 SP 提高 25%，更快释放必杀。"},
 "breath":{"id":"breath","title":"生生不息","description":"生命上限增加 20，立即恢复 35 HP。"},
 "iron":{"id":"iron","title":"破阵之势","description":"对敌人造成的架势伤害提高 30%。"},
 "swift":{"id":"swift","title":"招随心转","description":"E 技能的冷却时间缩短 18%。"},
 "reflection":{"id":"reflection","title":"明镜止水","description":"每次极限防御额外恢复 6 HP。"},
 "riposte":{"id":"riposte","title":"反照","description":"极限防御后接出的追击，伤害额外提高 30%。"},
 "windstep":{"id":"windstep","title":"乘风","description":"成功闪避攻击，额外缩短 E 冷却 1.5 秒。"},
 "finisher":{"id":"finisher","title":"三叠归元","description":"J 三连的末段命中，额外获得 10 SP。"},
 "reservoir":{"id":"reservoir","title":"气贯长虹","description":"命中回能提高 15%，E 冷却缩短 10%。"},
 "risk":{"id":"risk","title":"以攻代守","description":"伤害提高 26%，代价是生命上限减少 16。"},
 "calm":{"id":"calm","title":"守一","description":"生命上限增加 12，每次极限防御恢复 3 HP。"}
}

var mode := "trial"
var phase := "menu"
var stage_index := 0
var best_score := 0
var best_rank := "—"
var carry: Dictionary = {}
var checkpoint: Dictionary = {}
var boons: Array[String] = []
var reward_options: Array = []
var totals: Dictionary = {}
var last_stats: Dictionary = {}
var stages: Array = []
var selected_contract := "mirror"
var selected_contract_ids: Array[String] = ["mirror"]
var run_seed := 0
var run_number := 0
var completed_runs := 0
var contract_wins: Dictionary = {}
var unlocked_titles: Array[String] = []
var reward_ids: Array[String] = []
var achievements: Array[Dictionary] = []
var last_achievement: Dictionary = {}

func _init() -> void:
 _load_record()
 run_number=completed_runs
 _reset_run()
 stages = _make_stages()

func _reset_run() -> void:
 stage_index=0
 carry={"hp":120.0,"maxHp":120.0,"energy":100.0,"damageMultiplier":1.0,"energyGain":1.0,"postureMultiplier":1.0,"skillCooldownScale":1.0,"parryHeal":0.0,"riposteBonus":0.0,"dodgeRefund":0.0,"finisherEnergy":0.0}
 checkpoint=carry.duplicate(true)
 boons.clear()
 reward_ids.clear()
 achievements.clear()
 last_achievement={}
 reward_options.clear()
 totals={"kills":0,"parries":0,"dodges":0,"maxCombo":0,"damageTaken":0.0,"damageDealt":0.0,"elapsed":0.0,"retries":0,"achievementScore":0}
 last_stats={}

func select_contract(id: String) -> bool:
 if phase!="menu" or not CONTRACTS.has(id): return false
 if completed_runs<=0:
  selected_contract_ids.assign([id])
 elif id in selected_contract_ids:
  if selected_contract_ids.size()==1: return false
  selected_contract_ids.erase(id)
 else: selected_contract_ids.append(id)
 selected_contract=selected_contract_ids[0]
 _save_record()
 return true

func select_all_contracts() -> bool:
 if phase!="menu" or completed_runs<=0: return false
 selected_contract_ids.assign(CONTRACTS.keys())
 selected_contract=selected_contract_ids[0]
 _save_record()
 return true

func challenge_level() -> int:
 return maxi(0,selected_contract_ids.size()-1) if completed_runs>0 else 0

func challenge_description() -> String:
 var extra:=challenge_level()
 if extra==0: return "通关一次后，可同时接受多条规矩。" if completed_runs==0 else "可同时接受多条规矩，也可全部挑战。"
 return "同时接受 %d 条：敌人伤害 +%d%%，追击更紧；须完成全部约定才有额外补给。"%[selected_contract_ids.size(),extra*10]

func begin_trial(contract_id: String="", seed: int=-1) -> void:
 if CONTRACTS.has(contract_id):
  selected_contract=contract_id
  selected_contract_ids.assign([contract_id])
 if completed_runs<=0: selected_contract_ids.assign([selected_contract])
 selected_contract=selected_contract_ids[0]
 _reset_run()
 carry.energy=60.0
 carry.finisherEnergy=3.0
 run_number+=1
 if seed<0:
  var random:=RandomNumberGenerator.new()
  random.randomize()
  run_seed=int(random.randi() & 0x7fffffff)
 else: run_seed=seed
 for id: String in selected_contract_ids:
  match id:
   "mirror": carry.riposteBonus=0.20
   "flow": carry.dodgeRefund=1.0
   "breaker": carry.postureMultiplier=1.20
 checkpoint=carry.duplicate(true)
 stages=_make_stages(true)
 mode="trial"
 phase="fight"

func begin_practice() -> void:
 _reset_run()
 stages=_make_stages()
 mode="practice"
 phase="fight"

func back_to_menu() -> void:
 phase="menu"
 reward_options.clear()

func encounter() -> Dictionary:
 checkpoint=carry.duplicate(true)
 return stages[stage_index].duplicate(true)

func finish(state: Dictionary) -> void:
 if phase!="fight": return
 var live: Dictionary=state.get("stats",{})
 last_stats=_combined_stats(live)
 if mode=="practice":
  phase="cleared" if state.get("winner","")=="player" else "failed"
  return
 if state.get("winner","")!="player":
  phase="failed"
  return
 totals=last_stats.duplicate(true)
 var player: Dictionary=state.get("player",{})
 carry.hp=minf(float(player.get("maxHp",120.0)),float(player.get("hp",0.0))+CLEAR_HEAL)
 carry.maxHp=float(player.get("maxHp",120.0))
 carry.energy=minf(100.0,float(player.get("energy",0.0))+20.0)
 last_achievement={}
 var goal:=objective(live,true)
 if bool(goal.complete):
  last_achievement={"id":"%s_%d"%["+".join(selected_contract_ids),stage_index],"title":"诸约皆成" if selected_contract_ids.size()>1 else "契约达成 · "+str(CONTRACTS[selected_contract].title),"description":"额外恢复 8 HP 与 10 SP，结算加 100 分。","bonusHp":8.0,"bonusSp":10.0,"score":100}
  achievements.append(last_achievement.duplicate(true))
  carry.hp=minf(carry.maxHp,carry.hp+8.0)
  carry.energy=minf(100.0,carry.energy+10.0)
  totals.achievementScore=int(totals.get("achievementScore",0))+100
 if stage_index>=stages.size()-1:
  phase="cleared"
  var result: Dictionary=_scored(totals)
  if int(result.score)>best_score:
   best_score=int(result.score)
   best_rank=str(result.rank)
  completed_runs+=1
  for id: String in selected_contract_ids:
   contract_wins[id]=int(contract_wins.get(id,0))+1
  if not "识境来客" in unlocked_titles: unlocked_titles.append("识境来客")
  for id: String in selected_contract_ids:
   var title: String={"mirror":"明镜无尘","flow":"御风而行","breaker":"寸心破阵"}[id]
   if not title in unlocked_titles: unlocked_titles.append(title)
  if selected_contract_ids.size()==3 and not "诸约皆成" in unlocked_titles: unlocked_titles.append("诸约皆成")
  if contract_wins.size()==3 and not "三境皆通" in unlocked_titles: unlocked_titles.append("三境皆通")
  _save_record()
 else:
  phase="reward"
  reward_options=_roll_rewards()

func _roll_rewards() -> Array:
 var available: Array=[]
 for key: String in REWARDS:
  if not key in reward_ids: available.append(key)
 var random:=RandomNumberGenerator.new()
 random.seed=run_seed+stage_index*7919+101
 for index in range(available.size()-1,0,-1):
  var other:=random.randi_range(0,index)
  var item=available[index]
  available[index]=available[other]
  available[other]=item
 # A matching technique is offered early, but never returns after acquisition.
 var favored: String=CONTRACTS[selected_contract].reward
 if stage_index==0 and favored in available:
  available.erase(favored)
  available.push_front(favored)
 var result: Array=[]
 for index in mini(3,available.size()): result.append(REWARDS[available[index]].duplicate(true))
 for index in range(result.size()-1,0,-1):
  var other:=random.randi_range(0,index)
  var item=result[index]
  result[index]=result[other]
  result[other]=item
 return result

func choose_reward(index: int) -> bool:
 if phase!="reward" or index<0 or index>=reward_options.size(): return false
 var reward: Dictionary=reward_options[index]
 if not REWARDS.has(str(reward.get("id",""))) or str(reward.id) in reward_ids: return false
 match str(reward.id):
  "fist": carry.damageMultiplier*=1.16
  "flow": carry.energyGain*=1.25
  "breath":
   carry.maxHp+=20.0
   carry.hp=minf(carry.maxHp,carry.hp+35.0)
  "iron": carry.postureMultiplier*=1.30
  "swift": carry.skillCooldownScale=maxf(0.4,carry.skillCooldownScale*0.82)
  "reflection": carry.parryHeal+=6.0
  "riposte": carry.riposteBonus+=0.30
  "windstep": carry.dodgeRefund+=1.5
  "finisher": carry.finisherEnergy+=10.0
  "reservoir":
   carry.energyGain*=1.15
   carry.skillCooldownScale=maxf(0.4,carry.skillCooldownScale*0.90)
  "risk":
   carry.damageMultiplier*=1.26
   carry.maxHp=maxf(1.0,carry.maxHp-16.0)
   carry.hp=minf(carry.hp,carry.maxHp)
  "calm":
   carry.maxHp+=12.0
   carry.parryHeal+=3.0
 reward_ids.append(str(reward.id))
 boons.append(str(reward.title))
 stage_index+=1
 phase="fight"
 reward_options.clear()
 return true

func retry() -> bool:
 if phase!="failed": return false
 carry=checkpoint.duplicate(true)
 carry.hp=maxf(carry.hp,carry.maxHp*0.70)
 carry.energy=maxf(carry.energy,35.0)
 totals.retries+=1
 phase="fight"
 last_stats={}
 last_achievement={}
 return true

func _combined_stats(live: Dictionary) -> Dictionary:
 var result:=totals.duplicate(true)
 for key in ["kills","parries","dodges","damageTaken","damageDealt","elapsed"]:
  result[key]=float(totals.get(key,0))+float(live.get(key,0))
 result.maxCombo=maxi(int(totals.get("maxCombo",0)),int(live.get("maxCombo",0)))
 return result

func _scored(data: Dictionary) -> Dictionary:
 var result:=data.duplicate(true)
 var value: float=220.0*float(result.get("kills",0))+90.0*float(result.get("parries",0))+45.0*float(result.get("dodges",0))+25.0*float(result.get("maxCombo",0))
 value+=maxf(0.0,1800.0-float(result.get("elapsed",0))*3.0)
 value-=float(result.get("damageTaken",0))*2.0+float(result.get("retries",0))*300.0
 value+=float(result.get("achievementScore",0))
 result.score=maxi(0,roundi(value))
 result.rank="S" if value>=4200.0 else "A" if value>=3200.0 else "B" if value>=2200.0 else "C"
 return result

func objective(live: Dictionary={}, won: bool=false) -> Dictionary:
 if selected_contract_ids.size()>1:
  var items: Array=[]
  var done:=0
  var labels: PackedStringArray=[]
  for id: String in selected_contract_ids:
   var rule: Dictionary=CONTRACTS[id]
   var value:=maxf(0.0,float(live.get(rule.stat,0.0)))
   var complete: bool=value>=float(rule.target)
   if complete: done+=1
   labels.append("%s %d/%d"%[rule.objective,mini(int(value),int(rule.target)),int(rule.target)])
   items.append({"id":id,"title":rule.objective,"progress":minf(float(rule.target),value),"target":rule.target,"complete":complete})
  return {"title":" · ".join(labels),"progress":done,"target":items.size(),"complete":done==items.size(),"awarded":won and done==items.size(),"items":items,"bonus":"全部达成：补给 8 HP / 10 SP，加 100 分"}
 var rule: Dictionary=CONTRACTS[selected_contract]
 var value:=maxf(0.0,float(live.get(rule.stat,0.0)))
 return {"title":str(rule.objective),"progress":minf(float(rule.target),value),"target":float(rule.target),"complete":value>=float(rule.target),"awarded":won and value>=float(rule.target),"bonus":"达成后额外补给 8 HP / 10 SP，并加 100 分"}

func contract_options() -> Array:
 var result: Array=[]
 for id: String in CONTRACTS: result.append(CONTRACTS[id].duplicate(true))
 return result

func snapshot(state: Dictionary) -> Dictionary:
 var stage: Dictionary=stages[stage_index]
 var alive:=0
 var foes: Array=state.get("enemies",[])
 for foe in foes:
  if float(foe.get("hp",0))>0: alive+=1
 var current: Dictionary=_combined_stats(state.get("stats",{})) if phase=="fight" else (last_stats if phase=="failed" or mode=="practice" else totals)
 return {"mode":mode,"phase":phase,"stageIndex":stage_index,"stageTotal":stages.size(),"title":stage.title if mode=="trial" else "自由对练","region":REGIONS[stage.regionIndex] if mode=="trial" else "晨岚台","regionIndex":stage.regionIndex if mode=="trial" else 0,"brief":stage.brief if mode=="trial" else "与识之律者切磋，T 切换木人模式。","enemiesRemaining":alive,"totalEnemies":foes.size(),"rewards":reward_options.duplicate(true),"stats":_scored(current),"boons":boons.duplicate(),"bestScore":best_score,"bestRank":best_rank,"supply":"过关补给：恢复 %d HP 与 20 SP"%int(CLEAR_HEAL),"contracts":contract_options(),"contract":CONTRACTS[selected_contract].duplicate(true),"contractId":selected_contract,"selectedContractIds":selected_contract_ids.duplicate(),"contractsUnlocked":completed_runs>0,"challengeLevel":challenge_level(),"challengeDescription":challenge_description(),"runSeed":run_seed,"runNumber":run_number,"completedRuns":completed_runs,"contractWins":contract_wins.duplicate(true),"unlockedTitles":unlocked_titles.duplicate(),"objective":objective(state.get("stats",{})) if mode=="trial" else {},"lastAchievement":last_achievement.duplicate(true),"achievements":achievements.duplicate(true),"rewardIds":reward_ids.duplicate()}

func _load_record() -> void:
 var file:=ConfigFile.new()
 if file.load(SAVE_PATH)==OK:
  best_score=maxi(0,int(file.get_value("record","score",0)))
  best_rank=str(file.get_value("record","rank","—"))
  completed_runs=maxi(0,int(file.get_value("progress","completed_runs",0)))
  var wins=file.get_value("progress","contract_wins",{})
  if wins is Dictionary:
   for id: String in CONTRACTS:
    if int(wins.get(id,0))>0: contract_wins[id]=int(wins[id])
  var titles=file.get_value("progress","titles",[])
  if titles is Array or titles is PackedStringArray:
   for title in titles:
    if title is String and not title in unlocked_titles: unlocked_titles.append(title)
  var saved_contract:=str(file.get_value("progress","contract","mirror"))
  if CONTRACTS.has(saved_contract): selected_contract=saved_contract
  selected_contract_ids.assign([selected_contract])
  var saved_ids=file.get_value("progress","contracts",[])
  if completed_runs>0 and (saved_ids is Array or saved_ids is PackedStringArray):
   var valid: Array[String]=[]
   for id in saved_ids:
    if id is String and CONTRACTS.has(id) and id not in valid: valid.append(id)
   if not valid.is_empty():
    selected_contract_ids=valid
    selected_contract=valid[0]

func _save_record() -> void:
 var file:=ConfigFile.new()
 file.load(SAVE_PATH) # Preserve older or future unrelated sections.
 file.set_value("record","score",best_score)
 file.set_value("record","rank",best_rank)
 file.set_value("progress","completed_runs",completed_runs)
 file.set_value("progress","contract_wins",contract_wins)
 file.set_value("progress","titles",unlocked_titles)
 file.set_value("progress","contract",selected_contract)
 file.set_value("progress","contracts",selected_contract_ids)
 file.save(SAVE_PATH)

func _foe(id: String,type: String,title: String,hp: float,x: float,tint: String,elite: bool=false) -> Dictionary:
 return {"id":id,"type":type,"name":title,"characterId":"herrscher_of_sentience","style":"sentience","hp":hp,"x":x,"tint":tint,"elite":elite,"boss":type=="boss","damageScale":0.85 if id=="gate" else 1.0}

func _make_stages(varied: bool=false) -> Array:
 var result: Array=[
  {"title":"第一试 · 入山","regionIndex":0,"brief":"先与识律幻身过招。试试 J 连击接 K 重击。","playerX":-1.8,"enemies":[_foe("gate","striker","识律幻身 · 迅击",60,1.8,"bd76b6")]},
  {"title":"第二试 · 合围","regionIndex":0,"brief":"识律幻身从两侧进攻。留意蓄力预警，闪避后再反击。","playerX":-0.7,"enemies":[_foe("pincer_l","striker","识律幻身 · 迅击",55,-3.4,"bd76b6"),_foe("pincer_r","striker","识律幻身 · 迅击",55,2.5,"be93e8")]},
  {"title":"第三试 · 铁壁","regionIndex":1,"brief":"守御幻身擅长防御。用重击和寸劲击破架势。","playerX":-2.0,"enemies":[_foe("iron","guardian","识律幻身 · 守御",105,1.1,"e7b568",true),_foe("escort","striker","识律幻身 · 迅击",55,3.7,"bd76b6")]},
  {"title":"第四试 · 追风","regionIndex":1,"brief":"三个幻身轮流进攻。极限防御创造反击机会。","playerX":-0.6,"enemies":[_foe("wind","duelist","识律幻身 · 追袭",90,-3.5,"be93e8",true),_foe("rush","striker","识律幻身 · 迅击",60,1.8,"bd76b6"),_foe("guard","guardian","识律幻身 · 守御",75,4.3,"dfb871")]},
  {"title":"第五试 · 破阵","regionIndex":2,"brief":"击退精英幻身，准备与识之律者正面对决。","playerX":-0.5,"enemies":[_foe("flame_guard","guardian","识律幻身 · 守御",90,-3.3,"eab368",true),_foe("flame_wind","duelist","识律幻身 · 追袭",95,2.5,"d96583",true)]},
  {"title":"终试 · 识之律者","regionIndex":2,"brief":"这次是本体。识之律者半血后强化，红光重击前及时闪避。","playerX":-2.0,"enemies":[_foe("final_boss","boss","识之律者",260,2.0,"d96583",true)]}
 ]
 for index in result.size():
  result[index].pressureLevel=mini(2,index/2)+(challenge_level() if varied else 0)
  # Later warnings matter more, while keeping the opening, HP budget and
  # native action speeds intact. A phase-two boss burst is still below a
  # quarter of the initial health pool and remains fully dodgeable.
  if index>=3:
   for foe: Dictionary in result[index].enemies:
    foe.damageScale=1.15 if index==3 else 1.25 if index==4 else 1.4
  if varied and challenge_level()>0:
   for foe: Dictionary in result[index].enemies:
    foe.damageScale=float(foe.damageScale)*(1.0+0.10*challenge_level())
  _assign_weapon_roles(result[index],index,0)
 if not varied: return result
 var random:=RandomNumberGenerator.new()
 random.seed=run_seed
 var aliases: Dictionary={"striker":"迅击","guardian":"守御","duelist":"追袭"}
 var families: Array=["striker","guardian","duelist"]
 var alternatives: Array=[["初探","问招"],["夹击","错影"],["守门","试锋"],["逐影","回身"],["双锋","照心"]]
 for index in result.size():
  var stage: Dictionary=result[index]
  stage.variant=random.randi_range(0,1)
  stage.contract=selected_contract
  stage.contracts=selected_contract_ids.duplicate()
  var favored: String={"mirror":"striker","flow":"duelist","breaker":"guardian"}[selected_contract_ids[index%selected_contract_ids.size()]]
  if index<5:
   stage.title="第%s试 · %s"%[["一","二","三","四","五"][index],alternatives[index][stage.variant]]
   for foe_index in stage.enemies.size():
    var foe: Dictionary=stage.enemies[foe_index]
    # Keep the opening readable and the existing six-stage health budget.
    foe.type="striker" if index==0 else favored if foe_index==0 else families[random.randi_range(0,2)]
    foe.name="识律幻身 · "+str(aliases[foe.type])
   stage.brief=challenge_description() if selected_contract_ids.size()>1 else str(CONTRACTS[selected_contract].rule)+"。"+str(CONTRACTS[selected_contract].objective)+"可获额外补给。"
  # The same seed always reproduces the arrangement; retry never rerolls it.
  if random.randi_range(0,1)==1:
   stage.playerX=-float(stage.playerX)
   for foe: Dictionary in stage.enemies: foe.x=-float(foe.x)
  _assign_weapon_roles(stage,index,int(stage.variant))
 return result

func _assign_weapon_roles(stage: Dictionary,index: int,variant: int) -> void:
 # Give each encounter a readable weapon problem without adding health.
 # Rear escorts have spear reach so their turn is not blocked by an ally.
 for slot in stage.enemies.size():
  var foe: Dictionary=stage.enemies[slot]
  if foe.boss:continue
  var rear:=false
  var distance: float=absf(float(foe.x)-float(stage.playerX))
  for other: Dictionary in stage.enemies:
   if other.id!=foe.id and (float(other.x)-float(stage.playerX))*(float(foe.x)-float(stage.playerX))>0.0 and absf(float(other.x)-float(stage.playerX))<distance:rear=true
  foe.weaponLock="spear" if rear else "sword" if index==0 else ["sword","chain","spear"][posmod(index+slot+variant,3)]
