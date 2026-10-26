extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Campaign=preload("res://scripts/campaign.gd")
var passed:=0
var failures: Array[String]=[]
class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if error_type!=Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

# Most scenarios use the real campaign implementation with persistence disabled.
# The separate disk round trip uses its own process-local user-data directory.
class VolatileCampaign extends "res://scripts/campaign.gd":
 var save_calls:=0
 func _load_record() -> void:
  pass
 func _save_record() -> void:
  save_calls+=1

func check(ok: bool,message: String) -> void:
 passed+=1
 if not ok:
  failures.append(message)
  print("CHECK FAILED: "+message)

func _reward_choice(campaign) -> int:
 # Inspect actual offered IDs: seeded draft cards are not fixed column slots.
 for preferred: String in ["breath","reflection","fist","riposte","iron","swift","flow","calm","reservoir","finisher","windstep","risk"]:
  for index in campaign.reward_options.size():
   if campaign.reward_options[index].id==preferred: return index
 return 0

func start_stage(campaign,game) -> void:
 game.start_encounter(campaign.encounter(),campaign.carry)

func _bot_fight(game,policy: String="aggressive",limit: float=150.0) -> Dictionary:
 var dt:=1.0/60.0
 var wall:=0.0
 var actions: Dictionary={}
 var min_gap:=100.0
 var commands:=0
 var max_attacking:=0
 var max_contact_windows:=0
 var observed: Dictionary={"enemyAttacks":0,"redWarnings":0,"bossPhases":0,"blocks":0,"armoredHits":0}
 var control: Dictionary={"nextAttackAt":0.0,"openingUntil":0.0}
 var observe: Callable=func(e: Dictionary):
  if e.type=="attack" and e.side=="enemy":
   observed.enemyAttacks+=1
   if e.get("unblockable",false):observed.redWarnings+=1
  if e.type=="bossPhase":observed.bossPhases+=1
  if e.type=="hit" and e.get("armored",false):observed.armoredHits+=1
  if e.type=="block" and e.side=="player":observed.blocks+=1
  if e.type in ["parry","block","evade"]:control.openingUntil=game.time+2.0
 game.event.connect(observe)
 while not game.ended and wall<limit:
  wall+=dt
  var movement:=0.0
  var guard:=false
  var command:=""
  var target: Dictionary=game.enemy
  var distance: float=absf(target.x-game.player.x)
  var available: bool=game.player.state in ["idle","move","guard"]
  var threat: Dictionary={}
  var impact:=100.0
  var enemy_busy:=false
  for foe in game.enemies:
   if foe.hp>0.0 and foe.state=="attack" and absf(foe.x-game.player.x)<=foe.attack.range+0.18:enemy_busy=true
   if foe.hp<=0.0 or foe.state!="attack" or foe.attack.get("hasHit",false):continue
   var remaining: float=foe.attack.windup-foe.stateTime
   if remaining>=-0.03 and absf(foe.x-game.player.x)<=foe.attack.range+0.18 and remaining<impact:
    threat=foe
    impact=remaining
  if game.ultimate.is_empty():
   if available:
    if game.player.energy>=100.0 and (policy!="counter" or game.stats.parries>=2):
     command="ultimate"
    elif not threat.is_empty():
     if threat.attack.get("unblockable",false):
      movement=signf(game.player.x-threat.x)
      if impact<=0.18:command="dodge"
     elif policy in ["counter","aggressive"]:
      if impact<=0.09:
       command="guard"
       guard=true
     else:
      guard=true
    elif policy!="aggressive" and enemy_busy:
     guard=policy=="guard"
    elif distance>1.45:
     movement=signf(target.x-game.player.x)
    elif policy=="counter" and game.stats.parries<2:
     # Deliberately exercise the defensive policy before spending SP or
     # ending this encounter; faster ripostes now kill before ten catches.
     pass
    elif policy!="aggressive" and game.time<control.nextAttackAt and game.time>=control.openingUntil:
     guard=policy=="guard"
    elif game.player.skillCooldown<=0.0:
     command="ability"
    else:
     command="light"
   elif game.player.state=="attack" and game.player.attack.name=="light" and game.player.stateTime>=0.12:
    if game.player.combo==0 and not game.player.queuedCombo:command="light"
    elif game.player.combo==1 and not game.player.queuedHeavy:command="heavy"
   if not command.is_empty() and game.action(command):
    if available and command in ["light","heavy","ability"]:control.nextAttackAt=game.time+3.7
    commands+=1
    actions[command]=int(actions.get(command,0))+1
  game.update(dt,movement,guard)
  var attacking:=0
  var contact_windows:=0
  var positions: Array[float]=[float(game.player.x)]
  for foe in game.enemies:
   if foe.hp>0.0:positions.append(float(foe.x))
   if foe.hp>0.0 and foe.state=="attack":
    attacking+=1
    if foe.stateTime>=foe.attack.windup and foe.stateTime<=foe.attack.windup+foe.attack.active:contact_windows+=1
  max_attacking=maxi(max_attacking,attacking)
  max_contact_windows=maxi(max_contact_windows,contact_windows)
  positions.sort()
  for j in range(1,positions.size()):min_gap=minf(min_gap,positions[j]-positions[j-1])
 game.event.disconnect(observe)
 return {"won":game.ended and game.winner=="player","timeout":not game.ended,"wallSeconds":snappedf(wall,0.01),"simSeconds":snappedf(game.time,0.01),"hp":snappedf(game.player.hp,0.01),"energy":snappedf(game.player.energy,0.01),"minGap":min_gap,"maxAttacking":max_attacking,"maxContactWindows":max_contact_windows,"actions":actions,"stats":game.stats.duplicate(true),"commands":commands,"observed":observed}

func _run_trial(policy: String) -> Dictionary:
 var campaign=VolatileCampaign.new()
 var game=Combat.new()
 campaign.begin_trial("mirror",3103)
 var results: Array=[]
 for stage in campaign.stages.size():
  start_stage(campaign,game)
  var entry_hp: float=game.player.hp
  var entry_energy: float=game.player.energy
  var result: Dictionary=_bot_fight(game,policy)
  result.stage=stage+1
  result.title=campaign.stages[stage].title
  result.entryHp=entry_hp
  result.entryEnergy=entry_energy
  results.append(result)
  print("BOT ",policy," ",JSON.stringify(result))
  if not result.won:return {"cleared":false,"stage":stage+1,"results":results}
  check(result.minGap>=Combat.GAP-0.0001,"normal-action encounter preserves actual actor spacing")
  check(result.maxAttacking<=2 and result.maxContactWindows<=1,"normal-action encounter overlaps only full warning/recovery, never live damage windows")
  var remaining_hp: float=game.player.hp
  var remaining_energy: float=game.player.energy
  campaign.finish(game.snapshot())
  var bonus_hp: float=campaign.last_achievement.get("bonusHp",0.0)
  var bonus_sp: float=campaign.last_achievement.get("bonusSp",0.0)
  check(is_equal_approx(campaign.carry.hp,minf(game.player.maxHp,remaining_hp+Campaign.CLEAR_HEAL+bonus_hp)),"clear restores base HP plus earned contract supply within maximum")
  check(is_equal_approx(campaign.carry.energy,minf(100.0,remaining_energy+20.0+bonus_sp)),"clear carries SP plus base and earned contract supply")
  if stage<campaign.stages.size()-1:
   check(campaign.phase=="reward" and campaign.reward_options.size()==3,"cleared encounter offers three rewards")
   check(not campaign.choose_reward(-1) and not campaign.choose_reward(3),"invalid reward selection cannot advance stage")
   check(campaign.choose_reward(_reward_choice(campaign)),"offered reward selected by its actual ID advances to next encounter")
   check(campaign.phase=="fight" and campaign.stage_index==stage+1,"reward transitions to the correct next stage")
  else:
   check(campaign.phase=="cleared" and campaign.stage_index==5,"sixth victory resolves the full trial")
 check(campaign.boons.size()==5 and campaign.totals.kills==11,"run retains five rewards and eleven actual kills")
 check(is_equal_approx(float(campaign.totals.damageDealt),1000.0),"actual six-stage enemy health totals one thousand damage")
 check(campaign.best_score>0 and campaign.save_calls==1,"full clear computes a best score and requests one save")
 return {"cleared":true,"results":results,"campaign":campaign,"game":game}

func _check_retry() -> void:
 var campaign=VolatileCampaign.new()
 var game=Combat.new()
 campaign.begin_trial("mirror",3103)
 for reward in 2:
  start_stage(campaign,game)
  var result: Dictionary=_bot_fight(game)
  check(result.won,"reach upgraded checkpoint using legal combat actions")
  campaign.finish(game.snapshot())
  check(campaign.choose_reward(_reward_choice(campaign)),"apply actual offered upgrades before retry scenario")
 start_stage(campaign,game)
 var checkpoint: Dictionary=campaign.checkpoint.duplicate(true)
 var boons_before: Array=campaign.boons.duplicate()
 var hp_before: float=game.player.hp
 # A genuine defeat: the player stands idle while the real enemy AI attacks.
 for i in 12000:
  if game.ended:break
  game.update(1.0/60.0)
 check(game.ended and game.winner=="enemy" and game.stats.damageTaken>=hp_before-0.01,"real enemy attacks produce the failure state")
 campaign.finish(game.snapshot())
 check(campaign.phase=="failed" and campaign.stage_index==2,"failure stays on the current encounter")
 check(campaign.retry(),"failed trial permits retry")
 check(campaign.boons==boons_before and campaign.boons.size()==2,"retry preserves both acquired card identities")
 for key: String in ["damageMultiplier","energyGain","postureMultiplier","skillCooldownScale","parryHeal","riposteBonus","dodgeRefund","finisherEnergy"]:
  check(is_equal_approx(float(campaign.carry[key]),float(checkpoint[key])),"retry preserves actual checkpoint build effect: "+key)
 check(campaign.carry.hp>=campaign.carry.maxHp*0.70 and campaign.carry.energy>=35.0,"retry supplies health/SP minimums")
 check(campaign.totals.retries==1 and campaign.totals.kills==3,"retry increments penalty without counting failed-attempt kills")
 start_stage(campaign,game)
 check(is_equal_approx(game.player.hp,campaign.carry.hp) and is_equal_approx(game.player.energy,campaign.carry.energy),"retry carry is applied to new combat state")
 check(_bot_fight(game).won,"the upgraded retried encounter remains winnable")
 campaign.back_to_menu()
 game.reset()
 check(campaign.phase=="menu" and not game.started and campaign.reward_options.is_empty(),"menu transition closes combat and reward state")
 campaign.begin_trial("mirror",3104)
 start_stage(campaign,game)
 check(campaign.stage_index==0 and campaign.boons.is_empty() and campaign.totals.retries==0,"restart resets stage, upgrades and retries")
 check(game.player.hp==120.0 and game.player.energy==60.0 and game.player.damageMultiplier==1.0,"restart restores clean trial health/SP/strength")
 campaign.begin_practice()
 game.start()
 check(campaign.mode=="practice" and game.enemies.size()==1 and game.player.hp==100.0,"free-practice reset retains the original duel")

func _check_record(saved_campaign) -> void:
 var original_path: String=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 var original_hash:=FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent"
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","TaixuTrialSuite/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
 var path: String=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 check(path!=original_path,"record fixture has its own user-data path")
 if path==original_path: return
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var real_campaign=Campaign.new()
 real_campaign.best_score=saved_campaign.best_score
 real_campaign.best_rank=saved_campaign.best_rank
 real_campaign._save_record()
 var loaded=Campaign.new()
 var persisted: bool=loaded.best_score==real_campaign.best_score and loaded.best_rank==real_campaign.best_rank
 var after_hash:=FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent"
 check(after_hash==original_hash,"record round trip never overwrites the user's current file")
 check(persisted,"best score and rank survive the actual disk save/load implementation")

func _initialize() -> void:
 OS.add_logger(recorder)
 var campaign=VolatileCampaign.new()
 check(campaign.phase=="menu" and campaign.stages.size()==6,"actual campaign starts at menu with six authored encounters")
 check(not campaign.choose_reward(0) and not campaign.retry(),"menu rejects reward and retry actions")
 var aggressive: Dictionary=_run_trial("aggressive")
 check(aggressive.cleared,"aggressive legal-action bot clears all six encounters")
 var skilled: Dictionary=_run_trial("counter")
 check(skilled.cleared,"counter-oriented legal-action bot clears all six encounters")
 var cautious: Dictionary=_run_trial("guard")
 check(cautious.cleared,"guard-oriented bot clears without relying on precise parries")
 if not aggressive.cleared or not skilled.cleared or not cautious.cleared:
  _finish_report()
  return
 check(skilled.campaign.totals.parries>=10 and skilled.campaign.totals.dodges>=1,"counter policy really exercises successful parries and dodges")
 var held_blocks:=0
 for result in cautious.results:held_blocks+=result.observed.blocks
 # This policy never times a parry input. A faster recovery can incidentally
 # enter guard within the perfect window; successful held blocks must dominate.
 check(held_blocks>=10 and held_blocks>=4*cautious.campaign.totals.parries,"guard policy relies on held blocks rather than precise parries")
 for run in [aggressive,skilled,cautious]:
  var boss_result: Dictionary=run.results[-1]
  # An evasive policy need not deliberately hit armor. The dedicated native
  # combat suite separately proves ordinary hits preserve it and E breaks it.
  check(boss_result.observed.bossPhases==1 and boss_result.observed.redWarnings>=1,"normal-action boss fight exhibits one phase transition and readable red native attacks")
 _check_retry()
 _check_record(skilled.campaign)
 _finish_report()

func _finish_report() -> void:
 check(recorder.errors.is_empty(),"no nested script or engine failure was swallowed by a helper")
 var result: Dictionary={"suite":"trial_integration","checks":passed,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/trial-suite.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
