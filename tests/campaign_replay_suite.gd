extends SceneTree
const Campaign=preload("res://scripts/campaign.gd")
const Story=preload("res://scripts/sentience_story.gd")
const Combat=preload("res://scripts/combat.gd")

class VolatileCampaign extends "res://scripts/campaign.gd":
 var saves:=0
 func _load_record() -> void: pass
 func _save_record() -> void: saves+=1

class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if error_type!=Logger.ERROR_TYPE_WARNING: errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})

var checks:=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var evidence: Dictionary={"runs":[],"rewardEffects":[],"storyCases":0}
var recorder:=ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)

func _run() -> void:
 OS.add_logger(recorder)
 _contracts_and_generation()
 _full_runs()
 _rewards()
 _retry_and_practice()
 _story()
 _persistence()
 check(completed==["contracts","runs","rewards","retry","story","persistence"],"all six independent sections completed")
 check(evidence.runs.size()==36 and evidence.rewardEffects.size()==12 and evidence.storyCases==6*Story.SCENES.size(),"all intended run, reward and dialogue cases executed")
 check(recorder.errors.is_empty(),"no engine or nested script errors")
 var report: Dictionary={"suite":"campaign_replay","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"completed":completed,"evidence":evidence}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/campaign-replay-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"campaign_replay","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size(),"completed":completed}))
 quit(0 if failures.is_empty() else 1)

func _contracts_and_generation() -> void:
 var signatures: Dictionary={}
 for route: String in Campaign.CONTRACTS:
  for seed_value in 12:
   var a:=VolatileCampaign.new()
   var b:=VolatileCampaign.new()
   check(a.select_contract(route),"menu accepts actual contract "+route)
   a.begin_trial("",seed_value)
   b.begin_trial(route,seed_value)
   check(a.stages==b.stages and a.carry==b.carry,"same route and seed reproduce encounter and initial build")
   check(a.stages.size()==6,"six encounters retained")
   var counts: Array=[1,2,2,3,2,1]
   for index in a.stages.size():
    var stage: Dictionary=a.stages[index]
    check(stage.regionIndex==index/2 and stage.enemies.size()==counts[index],"region and multi-enemy progression retained")
    var ids: Dictionary={}
    for foe: Dictionary in stage.enemies:
     check(not ids.has(foe.id) and foe.style=="sentience" and foe.characterId=="herrscher_of_sentience","varied encounters retain unique Sentience identities")
     ids[foe.id]=true
     check(absf(foe.x)<=Combat.LIMIT and absf(foe.x-float(stage.playerX))>=Combat.GAP,"randomized spawn remains in arena and separated from player")
   signatures[JSON.stringify(a.stages)]=true
   var original: Array=a.stages.duplicate(true)
   var encounter: Dictionary=a.encounter()
   encounter.enemies[0].hp=1
   check(a.stages==original,"returned encounter can be mutated without corrupting replay data")
   check(not a.select_contract("flow"),"contract cannot change after entering combat")
   a.back_to_menu()
   check(not a.select_contract("missing"),"unknown contract never silently changes selection")
   var options: Array=a.contract_options()
   options[0].title="not source data"
   check(a.contract_options()[0].title!="not source data","menu option data is not writable shared state")
  var initial:=VolatileCampaign.new()
  initial.begin_trial(route,7)
  check(is_equal_approx(initial.carry.riposteBonus,0.20 if route=="mirror" else 0.0),"mirror grants only its declared riposte rule")
  check(is_equal_approx(initial.carry.dodgeRefund,1.0 if route=="flow" else 0.0),"flow grants only its declared dodge rule")
  check(is_equal_approx(initial.carry.postureMultiplier,1.20 if route=="breaker" else 1.0),"breaker grants only its declared posture rule")
 check(signatures.size()>=24,"seeds materially change encounters rather than only exposing a different number")
 completed.append("contracts")

func _state(campaign,qualified: bool=true,winner: String="player") -> Dictionary:
 var live: Dictionary={"kills":campaign.stages[campaign.stage_index].enemies.size(),"parries":3 if qualified else 0,"dodges":3 if qualified else 0,"maxCombo":8 if qualified else 1,"damageTaken":12.0,"damageDealt":160.0,"elapsed":30.0}
 return {"winner":winner,"player":{"hp":60.0,"maxHp":campaign.carry.maxHp,"energy":20.0},"stats":live,"enemies":[]}

func _full_runs() -> void:
 for route: String in Campaign.CONTRACTS:
  for seed_value in 12:
   var campaign:=VolatileCampaign.new()
   campaign.begin_trial(route,seed_value)
   var picked: Array=[]
   var goals:=0
   var encounter_goals:=0
   for stage in 6:
    var qualified: bool=(stage+seed_value)%2==0
    var state:=_state(campaign,qualified)
    var earned_encounter: bool=bool(campaign.encounter_objective(state.stats,true).get("awarded",false))
    if earned_encounter: encounter_goals+=1
    campaign.encounter()
    campaign.finish(state)
    if qualified: goals+=1
    check(is_equal_approx(campaign.carry.hp,74.0 if qualified else 66.0),"six-HP clear supply adds eight more HP only when the goal is achieved")
    check(is_equal_approx(campaign.carry.energy,(50.0 if qualified else 40.0)+(8.0 if earned_encounter else 0.0)),"contract and encounter rewards add exactly their earned SP")
    check(campaign.last_achievement.is_empty()!=qualified,"achievement notice agrees with actual award")
    var phase: String=campaign.phase
    var totals: Dictionary=campaign.totals.duplicate(true)
    campaign.finish(state)
    check(campaign.phase==phase and campaign.totals==totals,"duplicate finish cannot award supplies or statistics again")
    if stage<5:
     check(campaign.phase=="reward" and campaign.reward_options.size()==3,"every non-final win supplies three actual choices")
     var offered: Dictionary={}
     for card: Dictionary in campaign.reward_options:
      check(not card.id in picked and not offered.has(card.id),"already acquired or duplicate cards never appear in offer")
      offered[card.id]=true
     check(not campaign.choose_reward(-1) and not campaign.choose_reward(3),"invalid selection cannot consume or skip reward")
     var choice:=seed_value%3
     picked.append(campaign.reward_options[choice].id)
     check(campaign.choose_reward(choice),"valid choice advances one stage")
     check(not campaign.choose_reward(choice) and campaign.stage_index==stage+1,"a repeated input cannot consume the next reward early")
   var snapshot: Dictionary=campaign.snapshot({})
   check(campaign.phase=="cleared" and campaign.stage_index==5 and campaign.completed_runs==1,"one six-fight run increments completion once")
   check(campaign.reward_ids.size()==5 and campaign.boons.size()==5,"five distinct build techniques survive to the result")
   check(campaign.saves==1 and campaign.best_score>0,"clear commits score and progress once")
   check(campaign.achievements.size()==goals and campaign.encounter_achievements.size()==encounter_goals and campaign.totals.achievementScore==100*goals+75*encounter_goals,"goal scores award each contract and encounter objective once")
   check(campaign.contract_wins.get(route,0)==1 and campaign.unlocked_titles.size()==2,"first clear unlocks base and path titles without locking content")
   check(snapshot.stats.score==campaign.best_score,"result score includes goal bonuses without double-counting current combat")
   evidence.runs.append({"route":route,"seed":seed_value,"rewards":campaign.reward_ids.duplicate(),"achievements":goals,"score":snapshot.stats.score})
 completed.append("runs")

func _rewards() -> void:
 for id: String in Campaign.REWARDS:
  var campaign:=VolatileCampaign.new()
  campaign.begin_trial("mirror",4)
  campaign.phase="reward"
  campaign.reward_options=[Campaign.REWARDS[id].duplicate(true)]
  campaign.carry.hp=40.0
  var before: Dictionary=campaign.carry.duplicate(true)
  check(campaign.choose_reward(0),"all advertised cards have an accepted implementation "+id)
  check(campaign.carry!=before,"every card changes usable combat carry "+id)
  match id:
   "riposte": check(is_equal_approx(campaign.carry.riposteBonus,0.50),"riposte card adds to contract instead of replacing it")
   "windstep": check(is_equal_approx(campaign.carry.dodgeRefund,1.5),"dodge card supplies actual cooldown refund")
   "finisher": check(is_equal_approx(campaign.carry.finisherEnergy,float(before.finisherEnergy)+10.0),"finisher card adds its advertised third-hit energy")
   "risk": check(is_equal_approx(campaign.carry.maxHp,104.0) and campaign.carry.damageMultiplier>1.25,"offense card enforces its stated health tradeoff")
   "breath": check(is_equal_approx(campaign.carry.maxHp,140.0) and is_equal_approx(campaign.carry.hp,75.0),"recovery card heals and expands maximum HP")
  campaign.phase="reward"
  campaign.reward_options=[Campaign.REWARDS[id].duplicate(true)]
  check(not campaign.choose_reward(0),"duplicate injected acquisition is rejected as well as omitted "+id)
  evidence.rewardEffects.append({"id":id,"before":before,"after":campaign.carry.duplicate(true)})
 completed.append("rewards")

func _retry_and_practice() -> void:
 var campaign:=VolatileCampaign.new()
 campaign.begin_trial("flow",89)
 campaign.carry.finisherEnergy=10.0
 campaign.carry.riposteBonus=0.3
 campaign.carry.hp=56.0
 var layout: Array=campaign.stages.duplicate(true)
 campaign.encounter()
 var checkpoint: Dictionary=campaign.checkpoint.duplicate(true)
 campaign.finish(_state(campaign,true,"enemy"))
 check(campaign.phase=="failed" and campaign.achievements.is_empty() and campaign.last_achievement.is_empty(),"a lost fight never receives a completed-goal award")
 check(campaign.retry() and campaign.phase=="fight","failed encounter can retry")
 check(campaign.stages==layout and campaign.run_seed==89,"retry keeps the same opponents and rule")
 check(campaign.carry.riposteBonus==checkpoint.riposteBonus and campaign.carry.finisherEnergy==checkpoint.finisherEnergy and campaign.carry.dodgeRefund==checkpoint.dodgeRefund,"retry preserves conditional build hooks")
 check(campaign.totals.retries==1 and not campaign.retry(),"retry penalty counts once")
 campaign.begin_practice()
 check(campaign.carry.riposteBonus==0 and campaign.carry.dodgeRefund==0 and campaign.carry.finisherEnergy==0 and campaign.carry.postureMultiplier==1,"practice remains free of selected trial contract and boons")
 campaign.finish(_state(campaign))
 check(campaign.completed_runs==0 and campaign.saves==0 and campaign.reward_options.is_empty(),"practice does not award trial records, titles or cards")
 campaign.back_to_menu()
 campaign.begin_trial("",90)
 check(campaign.selected_contract=="flow" and campaign.carry.dodgeRefund==1,"rechallenge retains chosen contract but rebuilds its run")
 check(campaign.boons.is_empty() and campaign.achievements.is_empty() and campaign.reward_ids.is_empty(),"rechallenge clears all previous run rewards and achievements")
 completed.append("retry")

func _story() -> void:
 for route: String in Campaign.CONTRACTS:
  for run in [1,2]:
   var context: Dictionary={"contractId":route,"runNumber":run,"runSeed":run,"rewardIds":["fist"],"stageIndex":1}
   for scene: String in Story.SCENES:
    var lines: Array=Story.lines(scene,context)
    check(lines.size()>=2,"each story sequence contains all approved manuscript lines")
    check(lines==Story.lines(scene,context),"story replay is deterministic")
    var actors: Dictionary={}
    for line: Dictionary in lines:
     check(line.speaker in ["senti","fuhua","narrator","fuhua_thought","lixue"] and not str(line.text).is_empty(),"dialogue, inner thoughts and memory retain their authored speakers")
     check(line.mood in ["confident","tease","calm","serious","surprised"] and line.pose=="idle","dialogue presentation hints remain within supported safe poses")
     actors[line.speaker]=true
    check(actors.has("fuhua") and actors.has("senti") and Story.metadata(scene).skippable,"every scene is skippable and includes the main pair")
    evidence.storyCases+=1
 check(Story.lines("missing").is_empty(),"unknown scene produces no blocking placeholder")
 check(Story.lines("intro",{"runNumber":1})!=Story.lines("intro",{"runNumber":2}),"repeat opening acknowledges another attempt")
 check(Story.lines("stage_2",{"contractId":"mirror"})==Story.lines("stage_2",{"contractId":"flow"}),"approved spare scene does not invent contract-dependent wording")
 completed.append("story")

func _persistence() -> void:
 var original_path:=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 var original_hash:=FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent"
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","TaixuReplaySuite/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
 var isolated:=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 check(isolated!=original_path,"persistence fixture uses isolated user storage")
 if isolated==original_path: return
 DirAccess.make_dir_recursive_absolute(isolated.get_base_dir())
 var old:=ConfigFile.new()
 old.set_value("record","score",4321)
 old.set_value("record","rank","S")
 old.set_value("future_section","sentinel","keep me")
 check(old.save(isolated)==OK,"old-format record fixture written")
 var loaded:=Campaign.new()
 check(loaded.best_score==4321 and loaded.best_rank=="S" and loaded.completed_runs==0,"old two-field score loads without losing data")
 loaded.completed_runs=3
 loaded.contract_wins={"mirror":1,"flow":1,"breaker":1}
 loaded.unlocked_titles=["识境来客","三境皆通"]
 loaded.selected_contract="breaker"
 loaded.selected_contract_ids.assign(["breaker"])
 loaded._save_record()
 var replay:=Campaign.new()
 check(replay.best_score==4321 and replay.completed_runs==3 and replay.contract_wins.size()==3 and replay.selected_contract=="breaker","expanded progress roundtrips with the old best score")
 check(replay.unlocked_titles==loaded.unlocked_titles,"honor titles persist independently of gameplay selection")
 var preserved:=ConfigFile.new()
 preserved.load(isolated)
 check(preserved.get_value("future_section","sentinel","")=="keep me","save preserves unrelated existing fields")
 var after_hash:=FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent"
 check(original_hash==after_hash,"real player record is untouched")
 completed.append("persistence")
