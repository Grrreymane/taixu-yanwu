extends RefCounted

const EncounterVariants=preload("res://scripts/encounter_variants.gd")
const LocalSave=preload("res://scripts/local_save.gd")
const FighterRoster=preload("res://scripts/fighter_roster.gd")
const RUN_RULES_VERSION := "trial-2026-10-27"
const TIMING_RULE := "active-combat-real-time-v1"

const SAVE_PATH := "user://taixu_record.cfg"
const CLEAR_HEAL := 6.0
const REGIONS := ["晨岚台", "竹影庭", "赤霄坛"]
const CONTRACTS := {
 "mirror":{"id":"mirror","title":"明镜之约","description":"极限防御后的追击伤害提高 20%。完成约定可获额外补给。","rule":"防反追击伤害 +20%","objective":"完成 2 次极限防御","stat":"parries","target":2.0,"reward":"riposte"},
 "flow":{"id":"flow","title":"流转之约","description":"成功闪避攻击，立即缩短 E 冷却 1 秒。完成约定可获额外补给。","rule":"成功闪避使 E 冷却减少 1 秒","objective":"成功闪避 2 次攻击","stat":"dodges","target":2.0,"reward":"windstep"},
 "breaker":{"id":"breaker","title":"破阵之约","description":"架势伤害提高 20%。完成约定可获额外补给。","rule":"架势伤害 +20%","objective":"打出 6 连击","stat":"maxCombo","target":6.0,"reward":"finisher"}
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
var encounter_achievements: Array[Dictionary] = []
var last_encounter_achievement: Dictionary = {}
var last_encounter_stats: Dictionary = {}
var run_time := 0.0
var run_resumes := 0
var run_fighter: Dictionary = {}
var run_id := ""
var best_time_ms := 0
var new_time_record := false
var recent_runs: Array[Dictionary] = []
var resume_data: Dictionary = {}
var save_status := "ready"
var _local_save := LocalSave.new()
# Volatile test campaigns override _load_record; they never enable disk writes.
var persistence_enabled := false

func _init() -> void:
 _load_record()
 run_number=completed_runs
 _reset_run()
 stages = _make_stages()

func _reset_run() -> void:
 run_time=0.0
 run_resumes=0
 run_fighter={}
 run_id=""
 new_time_record=false
 stage_index=0
 carry={"hp":120.0,"maxHp":120.0,"energy":100.0,"damageMultiplier":1.0,"energyGain":1.0,"postureMultiplier":1.0,"skillCooldownScale":1.0,"parryHeal":0.0,"riposteBonus":0.0,"dodgeRefund":0.0,"finisherEnergy":0.0}
 checkpoint=carry.duplicate(true)
 boons.clear()
 reward_ids.clear()
 achievements.clear()
 last_achievement={}
 encounter_achievements.clear()
 last_encounter_achievement={}
 last_encounter_stats={}
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
 run_id="%d-%d-%d"%[int(Time.get_unix_time_from_system()*1000.0),run_seed,run_number]
 resume_data={}
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
 last_encounter_stats=live.duplicate(true)
 last_achievement={}
 last_encounter_achievement={}
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
 var goal:=objective(live,true)
 if bool(goal.complete):
  last_achievement={"id":"%s_%d"%["+".join(selected_contract_ids),stage_index],"title":"诸约皆成" if selected_contract_ids.size()>1 else "契约达成 · "+str(CONTRACTS[selected_contract].title),"description":"额外恢复 8 HP 与 10 SP，结算加 100 分。","bonusHp":8.0,"bonusSp":10.0,"score":100}
  achievements.append(last_achievement.duplicate(true))
  carry.hp=minf(carry.maxHp,carry.hp+8.0)
  carry.energy=minf(100.0,carry.energy+10.0)
  totals.achievementScore=int(totals.get("achievementScore",0))+100
 var encounter_goal:=encounter_objective(live,true)
 if bool(encounter_goal.get("awarded",false)):
  last_encounter_achievement={"id":"encounter_%d_%s"%[stage_index,encounter_goal.id],"title":"挑战达成 · "+str(encounter_goal.title),"description":"额外获得 8 SP，结算加 75 分。","bonusHp":0.0,"bonusSp":8.0,"score":75}
  encounter_achievements.append(last_encounter_achievement.duplicate(true))
  carry.energy=minf(100.0,carry.energy+8.0)
  totals.achievementScore=int(totals.get("achievementScore",0))+75
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
  _record_clear(result)
  resume_data={}
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
 last_encounter_achievement={}
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

func encounter_objective(live: Dictionary={},won: bool=false) -> Dictionary:
 if mode!="trial" or stages.is_empty(): return {}
 return EncounterVariants.objective(stages[stage_index].get("encounterChallenge",{}),live,won)

func tick_run(delta: float) -> void:
 # Main supplies real active-combat time, including hit stop and ultimates.
 # Menus, dialogue, countdowns, pause and hidden tabs never call this method.
 if mode=="trial" and phase=="fight" and is_finite(delta) and delta>0.0:
  run_time+=delta

func save_checkpoint(fighter_choice: Dictionary={}) -> bool:
 if mode=="trial":
  if phase in ["fight","reward","failed"]:
   if _valid_fighter(fighter_choice): run_fighter=fighter_choice.duplicate(true)
   if not _valid_fighter(run_fighter): return false
   var choices: Array[String]=[]
   for item: Dictionary in reward_options: choices.append(str(item.id))
   resume_data={"rulesVersion":RUN_RULES_VERSION,"timingRule":TIMING_RULE,"runId":run_id,"phase":phase,"stageIndex":stage_index,"seed":run_seed,"runNumber":run_number,"contracts":selected_contract_ids.duplicate(),"rewardIds":reward_ids.duplicate(),"rewardChoices":choices,"carry":carry.duplicate(true),"checkpoint":checkpoint.duplicate(true),"totals":totals.duplicate(true),"lastStats":last_stats.duplicate(true),"lastEncounterStats":last_encounter_stats.duplicate(true),"achievements":achievements.duplicate(true),"encounterAchievements":encounter_achievements.duplicate(true),"lastAchievement":last_achievement.duplicate(true),"lastEncounterAchievement":last_encounter_achievement.duplicate(true),"elapsedMs":roundi(run_time*1000.0),"resumes":run_resumes,"fighter":run_fighter.duplicate(true)}
  elif phase=="cleared": resume_data={}
 if persistence_enabled: _save_record()
 return not persistence_enabled or save_status in ["saved","ready","recovered"]

func has_resume() -> bool:
 return not resume_data.is_empty() and _valid_resume(resume_data)

func resume_summary() -> Dictionary:
 if not has_resume(): return {"available":false}
 var index:=int(resume_data.stageIndex)
 return {"available":true,"stageIndex":index,"stageTotal":6,"phase":str(resume_data.phase),"runTimeMs":int(resume_data.elapsedMs),"fighter":resume_data.fighter.duplicate(true),"retries":int(resume_data.totals.get("retries",0)),"resumes":int(resume_data.resumes)}

func resume_trial() -> Dictionary:
 if phase!="menu" or not has_resume(): return {}
 var data:=resume_data.duplicate(true)
 _reset_run()
 mode="trial"
 phase=str(data.phase)
 stage_index=int(data.stageIndex)
 run_seed=int(data.seed)
 run_number=int(data.runNumber)
 run_id=str(data.runId)
 selected_contract_ids.assign(data.contracts)
 selected_contract=selected_contract_ids[0]
 reward_ids.assign(data.rewardIds)
 for id: String in reward_ids: boons.append(str(REWARDS[id].title))
 for id: String in data.rewardChoices: reward_options.append(REWARDS[id].duplicate(true))
 carry=data.carry.duplicate(true)
 checkpoint=data.checkpoint.duplicate(true)
 totals=data.totals.duplicate(true)
 last_stats=data.lastStats.duplicate(true)
 last_encounter_stats=data.lastEncounterStats.duplicate(true)
 achievements.assign(data.achievements)
 encounter_achievements.assign(data.encounterAchievements)
 last_achievement=data.lastAchievement.duplicate(true)
 last_encounter_achievement=data.lastEncounterAchievement.duplicate(true)
 run_time=float(data.elapsedMs)/1000.0
 run_resumes=int(data.resumes)+1
 run_fighter=data.fighter.duplicate(true)
 stages=_make_stages(true)
 if phase=="failed": retry()
 elif phase=="fight": carry=checkpoint.duplicate(true)
 save_checkpoint(run_fighter)
 return {"fighter":run_fighter.duplicate(true),"phase":phase}

func _record_clear(result: Dictionary) -> void:
 var elapsed_ms:=roundi(run_time*1000.0)
 if elapsed_ms<=0: return # Legacy scores do not fabricate a timed clear.
 new_time_record=best_time_ms==0 or elapsed_ms<best_time_ms
 if new_time_record: best_time_ms=elapsed_ms
 var entry: Dictionary={"runId":run_id,"rulesVersion":RUN_RULES_VERSION,"timingRule":TIMING_RULE,"completedAt":int(Time.get_unix_time_from_system()),"elapsedMs":elapsed_ms,"characterId":str(run_fighter.get("characterId","fuhua")),"styleId":str(run_fighter.get("styleId","azure_empyrea")),"appearanceId":str(run_fighter.get("appearanceId","default")),"seed":run_seed,"contracts":selected_contract_ids.duplicate(),"rewardIds":reward_ids.duplicate(),"retries":int(totals.get("retries",0)),"resumes":run_resumes,"score":int(result.score),"rank":str(result.rank),"source":"local"}
 recent_runs.push_front(entry)
 if recent_runs.size()>20: recent_runs.resize(20)

func _save_payload() -> Dictionary:
 return {"record":{"bestScore":best_score,"bestRank":best_rank,"bestTimeMs":best_time_ms},"progress":{"completedRuns":completed_runs,"contractWins":contract_wins.duplicate(true),"titles":unlocked_titles.duplicate(),"contracts":selected_contract_ids.duplicate()},"recentRuns":recent_runs.duplicate(true),"resume":resume_data.duplicate(true)}

static func _number(value: Variant,maximum: float=1.0e12) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum

static func _integer(value: Variant,maximum: float=1.0e12) -> bool:
 return _number(value,maximum) and float(value)==floorf(float(value))

static func _text(value: Variant,maximum: int=120) -> bool:
 return value is String and value.length()>0 and value.length()<=maximum

static func _known_ids(value: Variant,known: Dictionary,maximum: int) -> bool:
 if not value is Array or value.size()>maximum: return false
 var seen: Dictionary={}
 for id: Variant in value:
  if not id is String or not known.has(id) or seen.has(id): return false
  seen[id]=true
 return true

static func _valid_fighter(value: Variant) -> bool:
 if not value is Dictionary: return false
 for key: String in ["characterId","styleId","appearanceId"]:
  if not _text(value.get(key),80): return false
 var character: Dictionary=FighterRoster.CHARACTERS.get(value.characterId,{})
 var style: Dictionary=FighterRoster.STYLES.get(value.styleId,{})
 var appearance: Dictionary=FighterRoster.APPEARANCES.get(value.styleId,{}).get(value.appearanceId,{})
 return bool(character.get("playable",false)) and value.styleId in character.get("styles",[]) and bool(style.get("playable",false)) and style.get("characterId")==value.characterId and value.appearanceId in style.get("appearances",[]) and bool(appearance.get("playable",false)) and appearance.get("styleId")==value.styleId

static func _numeric_dictionary(value: Variant) -> bool:
 if not value is Dictionary or value.size()>32: return false
 for key: Variant in value:
  if not key is String or not _number(value[key]): return false
 return true

static func _valid_carry(value: Variant) -> bool:
 if not _numeric_dictionary(value): return false
 for key: String in ["hp","maxHp","energy","damageMultiplier","energyGain","postureMultiplier","skillCooldownScale","parryHeal","riposteBonus","dodgeRefund","finisherEnergy"]:
  if not value.has(key): return false
 return float(value.maxHp)>=1.0 and float(value.hp)<=float(value.maxHp) and float(value.energy)<=100.0

static func _dictionaries(value: Variant,maximum: int=12) -> bool:
 if not value is Array or value.size()>maximum: return false
 for item: Variant in value:
  if not item is Dictionary: return false
 return true

static func _valid_resume(value: Variant) -> bool:
 if not value is Dictionary: return false
 if value.is_empty(): return true
 if value.get("rulesVersion")!=RUN_RULES_VERSION or value.get("timingRule")!=TIMING_RULE: return false
 if not _text(value.get("runId")) or not value.get("phase") in ["fight","reward","failed"]: return false
 if not _integer(value.get("stageIndex"),5) or not _integer(value.get("seed"),2147483647) or not _integer(value.get("runNumber")): return false
 if not _integer(value.get("elapsedMs"),604800000) or not _integer(value.get("resumes")): return false
 if not _known_ids(value.get("contracts"),CONTRACTS,3) or value.contracts.is_empty(): return false
 if not _known_ids(value.get("rewardIds"),REWARDS,5) or value.rewardIds.size()!=int(value.stageIndex): return false
 if not _known_ids(value.get("rewardChoices"),REWARDS,3): return false
 if value.phase=="reward":
  if int(value.stageIndex)>=5 or value.rewardChoices.size()!=3: return false
  for id: String in value.rewardChoices:
   if id in value.rewardIds: return false
 elif not value.rewardChoices.is_empty(): return false
 if not _valid_carry(value.get("carry")) or not _valid_carry(value.get("checkpoint")) or not _valid_fighter(value.get("fighter")): return false
 for key: String in ["totals","lastStats","lastEncounterStats"]:
  if not _numeric_dictionary(value.get(key)): return false
 if not value.totals.has("retries"): return false
 for key: String in ["achievements","encounterAchievements"]:
  if not _dictionaries(value.get(key),6): return false
 for key: String in ["lastAchievement","lastEncounterAchievement"]:
  if not value.get(key) is Dictionary: return false
 return true

static func _valid_payload(data: Dictionary) -> bool:
 if not data.get("record") is Dictionary or not data.get("progress") is Dictionary: return false
 var record: Dictionary=data.record
 var progress: Dictionary=data.progress
 if not _integer(record.get("bestScore")) or not _integer(record.get("bestTimeMs"),604800000) or not record.get("bestRank") in ["—","S","A","B","C"]: return false
 if not _integer(progress.get("completedRuns")) or not _numeric_dictionary(progress.get("contractWins")): return false
 if not progress.get("titles") is Array or progress.titles.size()>64: return false
 for title: Variant in progress.titles:
  if not _text(title): return false
 if not _known_ids(progress.get("contracts"),CONTRACTS,3) or progress.contracts.is_empty(): return false
 return _valid_history(data.get("recentRuns")) and _valid_resume(data.get("resume"))

static func _valid_history(entries: Variant) -> bool:
 if not _dictionaries(entries,20): return false
 for entry: Dictionary in entries:
  if not _text(entry.get("runId")) or not _integer(entry.get("elapsedMs"),604800000) or int(entry.elapsedMs)<=0: return false
  for key: String in ["completedAt","seed","retries","resumes","score"]:
   if not _integer(entry.get(key)): return false
  for key: String in ["characterId","styleId","appearanceId","rulesVersion","timingRule","rank","source"]:
   if not _text(entry.get(key)): return false
  if not _known_ids(entry.get("contracts"),CONTRACTS,3) or not _known_ids(entry.get("rewardIds"),REWARDS,5): return false
 return true

func snapshot(state: Dictionary) -> Dictionary:
 var stage: Dictionary=stages[stage_index]
 var alive:=0
 var foes: Array=state.get("enemies",[])
 for foe in foes:
  if float(foe.get("hp",0))>0: alive+=1
 var current: Dictionary=_combined_stats(state.get("stats",{})) if phase=="fight" else (last_stats if phase=="failed" or mode=="practice" else totals)
 var result: Dictionary={"mode":mode,"phase":phase,"stageIndex":stage_index,"stageTotal":stages.size(),"title":stage.title if mode=="trial" else "自由对练","region":REGIONS[stage.regionIndex] if mode=="trial" else "晨岚台","regionIndex":stage.regionIndex if mode=="trial" else 0,"brief":stage.brief if mode=="trial" else "与识之律者切磋，T 切换木人模式。","enemiesRemaining":alive,"totalEnemies":foes.size(),"rewards":reward_options.duplicate(true),"stats":_scored(current),"boons":boons.duplicate(),"bestScore":best_score,"bestRank":best_rank,"supply":"过关补给：恢复 %d HP 与 20 SP"%int(CLEAR_HEAL),"contracts":contract_options(),"contract":CONTRACTS[selected_contract].duplicate(true),"contractId":selected_contract,"selectedContractIds":selected_contract_ids.duplicate(),"contractsUnlocked":completed_runs>0,"challengeLevel":challenge_level(),"challengeDescription":challenge_description(),"runSeed":run_seed,"runNumber":run_number,"completedRuns":completed_runs,"contractWins":contract_wins.duplicate(true),"unlockedTitles":unlocked_titles.duplicate(),"objective":objective(state.get("stats",{})) if mode=="trial" else {},"lastAchievement":last_achievement.duplicate(true),"achievements":achievements.duplicate(true),"rewardIds":reward_ids.duplicate(),"encounterRule":stage.get("encounterRule",{}).duplicate(true) if mode=="trial" else {},"arrangementTitle":stage.get("arrangementTitle","") if mode=="trial" else "","encounterObjective":encounter_objective(state.get("stats",last_encounter_stats if phase in ["reward","cleared","failed"] else {}),phase in ["reward","cleared"]),"lastEncounterAchievement":last_encounter_achievement.duplicate(true),"encounterAchievements":encounter_achievements.duplicate(true)}

 result.merge({"runTimeMs":roundi(run_time*1000.0),"bestTimeMs":best_time_ms,"newTimeRecord":new_time_record,"runResumes":run_resumes,"recentRuns":recent_runs.duplicate(true),"resume":resume_summary(),"saveStatus":save_status})
 return result

func _load_record() -> void:
 persistence_enabled=true
 var file:=ConfigFile.new()
 if file.load(SAVE_PATH)==OK:
  best_score=maxi(0,int(file.get_value("record","score",0)))
  best_rank=str(file.get_value("record","rank","—"))
  var old_time: Variant=file.get_value("record","best_time_ms",0)
  if _integer(old_time,604800000): best_time_ms=int(old_time)
  var old_history: Variant=file.get_value("record","recent_runs",[])
  if _valid_history(old_history): recent_runs.assign(old_history)
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

 var payload:=_local_save.load_payload(_valid_payload)
 save_status=_local_save.status
 if not payload.is_empty():
  # The legacy file may be newer if a browser write failed, or if the JSON
  # primary was damaged and we recovered an older backup. Never lose unlocks.
  if int(payload.record.bestScore)>=best_score:
   best_score=int(payload.record.bestScore)
   best_rank=str(payload.record.bestRank)
  var saved_time:=int(payload.record.bestTimeMs)
  if saved_time>0 and (best_time_ms==0 or saved_time<best_time_ms): best_time_ms=saved_time
  completed_runs=maxi(completed_runs,int(payload.progress.completedRuns))
  for id: String in CONTRACTS:
   var wins:=maxi(int(contract_wins.get(id,0)),int(payload.progress.contractWins.get(id,0)))
   if wins>0: contract_wins[id]=wins
  for title: String in payload.progress.titles:
   if not title in unlocked_titles: unlocked_titles.append(title)
  selected_contract_ids.assign(payload.progress.contracts)
  selected_contract=selected_contract_ids[0]
  for entry: Dictionary in payload.recentRuns:
   var exists:=false
   for previous: Dictionary in recent_runs:
    if str(previous.runId)==str(entry.runId): exists=true; break
   if not exists: recent_runs.append(entry.duplicate(true))
  recent_runs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.completedAt)>int(b.completedAt))
  if recent_runs.size()>20: recent_runs.resize(20)
  resume_data=payload.resume.duplicate(true)
  for entry: Dictionary in recent_runs:
   if str(entry.runId)==str(resume_data.get("runId","")): resume_data={}; break

func _save_record() -> void:
 if _local_save.status=="incompatible": save_status="incompatible"; return
 var file:=ConfigFile.new()
 file.load(SAVE_PATH) # Preserve older or future unrelated sections.
 file.set_value("record","score",best_score)
 file.set_value("record","rank",best_rank)
 file.set_value("record","best_time_ms",best_time_ms)
 file.set_value("record","recent_runs",recent_runs)
 file.set_value("progress","completed_runs",completed_runs)
 file.set_value("progress","contract_wins",contract_wins)
 file.set_value("progress","titles",unlocked_titles)
 file.set_value("progress","contract",selected_contract)
 file.set_value("progress","contracts",selected_contract_ids)
 file.save(SAVE_PATH)
 _local_save.write_payload(_save_payload())
 save_status=_local_save.status

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
 EncounterVariants.apply(result,run_seed)
 for stage: Dictionary in result:
  stage.contract=selected_contract
  stage.contracts=selected_contract_ids.duplicate()
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
