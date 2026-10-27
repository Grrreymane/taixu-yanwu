extends SceneTree
## Repeatable balance evidence: real six-stage carry, legal inputs and offered
## rewards. Reactive policy reads public warning times; it is not a human model.
const Combat=preload("res://scripts/combat.gd")
const STEP:=1.0/120.0
class VolatileCampaign extends "res://scripts/campaign.gd":
 func _load_record() -> void:pass
 func _save_record() -> void:pass

func _initialize() -> void:
 var rows: Array=[]
 for profile: String in ["azure_empyrea","fenghuang","night_squire"]:
  for policy: String in ["j_only","reactive"]:
   for seed_value: int in [3103,89,2026]:
    rows.append(_run(profile,policy,seed_value))
 var result={"scope":"Six consecutive actual stages with carried HP/SP/boons and ordinary reward selection. J-only never guards/dodges/E/Q. Reactive policy reads public warning timing and uses defense/E/Q; 60s per-stage cap.","rows":rows}
 FileAccess.open("res://build/reports/continuous-pressure-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 for profile: String in ["azure_empyrea","fenghuang","night_squire"]:
  for policy: String in ["j_only","reactive"]:
   var cases=rows.filter(func(row):return row.profile==profile and row.policy==policy)
   print(JSON.stringify({"profile":profile,"policy":policy,"clears":cases.filter(func(row):return row.cleared).size(),"runs":cases.map(func(row):return {"seed":row.seed,"stage":row.stages.size(),"hp":row.hp,"damage":row.damageTaken,"parries":row.parries,"dodges":row.dodges,"seconds":row.seconds})}))
 quit()

func _run(profile:String,policy:String,seed_value:int) -> Dictionary:
 var campaign:=VolatileCampaign.new()
 campaign.begin_trial("mirror",seed_value)
 var stages:Array=[]
 var wall_time:=0.0
 var damage:=0.0
 var parries:=0
 var dodges:=0
 var hp:=120.0
 while campaign.phase=="fight":
  var game=Combat.new()
  game.set_player_profile(profile)
  var incoming:Dictionary=campaign.carry.duplicate(true)
  game.start_encounter(campaign.encounter(),campaign.carry)
  var guard:=false
  for frame in 7200:
   if game.ended:break
   guard=false
   var distance:float=absf(game.enemy.x-game.player.x)
   var movement:float=signf(game.enemy.x-game.player.x) if distance>1.18 else 0.0
   var warning:Dictionary={}
   var soonest:=10.0
   for foe in game.enemies:
    if foe.hp<=0 or foe.state!="attack" or bool(foe.attack.get("hasHit",false)):continue
    var left:float=foe.attack.windup-foe.stateTime
    if left>=-0.02 and left<soonest and absf(foe.x-game.player.x)<foe.attack.range+0.5:
     soonest=left
     warning=foe.attack
   if policy=="reactive" and not warning.is_empty():
    if soonest<0.07 and not warning.unblockable:
     guard=true
     game.action("guard")
    elif soonest<0.15 and warning.unblockable:
     movement=-signf(game.enemy.x-game.player.x)
     game.action("dodge")
    elif soonest>0.50 and game.player.skillCooldown<=0 and distance<2.2:
     game.action("ability")
    # Do not queue a fresh committed attack inside a visible warning.
   elif game.player.state in ["idle","move","guard"]:
    if policy=="reactive" and game.player.energy>=100.0 and game.ultimate.is_empty() and game.player.nightBurstRemaining<=0:
     game.action("ultimate")
    elif policy=="reactive" and game.player.skillCooldown<=0.0 and distance<2.0:
     game.action("ability")
    elif distance<1.65:game.action("light")
   elif game.player.state=="attack":game.action("light")
   game.update(STEP,movement,guard)
   wall_time+=STEP
  damage+=game.stats.damageTaken
  parries+=int(game.stats.parries)
  dodges+=int(game.stats.dodges)
  hp=game.player.hp
  stages.append({"stage":campaign.stage_index+1,"incoming":incoming,"hp":hp,"energy":game.player.energy,"winner":game.winner,"stats":game.stats.duplicate(true)})
  campaign.finish(game.snapshot())
  if campaign.phase=="reward":
   # Both bots choose the same general-purpose survival/offense priorities.
   var priorities:Array=["breath","fist","calm","iron","swift","finisher","reservoir","flow","reflection","riposte","windstep","risk"]
   var choice:=0
   for id in priorities:
    var found:=false
    for index in campaign.reward_options.size():
     if campaign.reward_options[index].id==id:
      choice=index
      found=true
      break
    if found:break
   campaign.choose_reward(choice)
 return {"profile":profile,"policy":policy,"seed":seed_value,"cleared":campaign.phase=="cleared","hp":hp,"damageTaken":damage,"parries":parries,"dodges":dodges,"seconds":snappedf(wall_time,0.1),"rewards":campaign.reward_ids.duplicate(),"stages":stages}
