extends SceneTree
const Campaign=preload("res://scripts/campaign.gd")
const Variants=preload("res://scripts/encounter_variants.gd")
const Combat=preload("res://scripts/combat.gd")
class VolatileCampaign extends "res://scripts/campaign.gd":
 func _load_record() -> void: pass
 func _save_record() -> void: pass
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)
func _run() -> void:
 var layouts: Dictionary={}
 var challenges: Dictionary={}
 var boss_cycles: Dictionary={}
 var previous: Array=[]
 for seed_value in 48:
  var a:=VolatileCampaign.new()
  var b:=VolatileCampaign.new()
  a.begin_trial("flow",seed_value)
  b.begin_trial("flow",seed_value)
  check(a.stages==b.stages,"seed reproduces all combat arrangements and objectives")
  if not previous.is_empty(): check(a.stages!=previous,"new seed changes an actual run")
  previous=a.stages.duplicate(true)
  var hp:=0.0
  var prior_rule: String=""
  for index in 6:
   var stage: Dictionary=a.stages[index]
   check(stage.encounterRule.id!=prior_rule,"adjacent stages ask for a different rhythm")
   prior_rule=stage.encounterRule.id
   check(stage.encounterRule.attackIntervalScale>=0.7 and stage.encounterRule.attackIntervalScale<=1.3 and stage.encounterRule.turnGapScale>=0.7 and stage.encounterRule.turnGapScale<=1.3,"rules affect recovery within bounded limits")
   var positions: Array=[float(stage.playerX)]
   for foe: Dictionary in stage.enemies:
    hp+=float(foe.hp)
    check(foe.tactic in ["press","guard","flank","range"],"only supported tactical roles are generated")
    check(absf(float(foe.x))<=Combat.LIMIT,"spawn remains inside arena")
    for x: float in positions: check(absf(float(foe.x)-x)>=Combat.GAP,"no same-side or cross-side spawn intersections")
    positions.append(float(foe.x))
    if foe.tactic=="range": check(foe.weaponLock=="spear","a ranged escort always has native spear reach")
   if index<5: layouts[stage.arrangementId]=true
   else:
    var boss: Dictionary=stage.enemies[0]
    check(not boss.has("weaponLock") and boss.weaponCycle.size()==4,"boss cycle keeps access to phase-two ultimate")
    check(boss.weaponCycle.count("sword")==2 and boss.weaponCycle.count("spear")==1 and boss.weaponCycle.count("chain")==1,"boss variations retain all weapon kits")
    boss_cycles[JSON.stringify(boss.weaponCycle)]=true
   challenges[stage.encounterChallenge.id]=true
  check(is_equal_approx(hp,1000.0),"replay variety never raises the existing health budget")
  var original:=a.stages.duplicate(true)
  a.encounter()
  a.finish({"winner":"enemy","stats":{"parries":99,"dodges":99,"maxCombo":99,"elapsed":1.0,"damageTaken":0.0}})
  check(a.last_encounter_achievement.is_empty(),"even completed goals do not pay on defeat")
  check(a.retry() and a.stages==original and a.run_seed==seed_value,"retry preserves complete layout, weapon plan, rules and goals")
 check(layouts.size()==12 and challenges.size()==5 and boss_cycles.size()==3,"all twelve formation patterns, five goals and three boss plans occur")
 _objectives()
 _awards()
 var report: Dictionary={"suite":"encounter_variants","passed":failures.is_empty(),"checks":checks,"failures":failures,"arrangements":layouts.keys(),"challenges":challenges.keys(),"bossPlans":boss_cycles.size()}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/encounter-variants-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func _objectives() -> void:
 for choice in 5:
  var goal:=Variants._challenge(2,choice)
  var below: Dictionary={str(goal.stat):float(goal.target)-1.0}
  var exact: Dictionary={str(goal.stat):float(goal.target)}
  var above: Dictionary={str(goal.stat):float(goal.target)+1.0}
  if goal.kind=="minimum":
   check(not Variants.objective(goal,below,true).awarded,"insufficient count cannot claim challenge")
   check(Variants.objective(goal,exact,true).awarded and Variants.objective(goal,above,true).awarded,"meeting count pays on victory")
   check(not Variants.objective(goal,above,false).awarded,"reaching count while fighting does not award early")
  else:
   check(not Variants.objective(goal,below,false).complete,"upper-bound challenge stays pending until victory")
   check(Variants.objective(goal,exact,true).awarded,"upper-bound equality is a valid victory")
   check(Variants.objective(goal,above,true).failed and not Variants.objective(goal,above,true).awarded,"exceeding damage or time loses only bonus")
func _awards() -> void:
 for choice in 5:
  var campaign:=VolatileCampaign.new()
  campaign.begin_trial("mirror",7)
  campaign.stages[0].encounterChallenge=Variants._challenge(0,choice)
  var goal: Dictionary=campaign.stages[0].encounterChallenge
  var stats: Dictionary={"kills":1,"parries":0,"dodges":0,"maxCombo":0,"elapsed":1.0,"damageTaken":0.0}
  stats[goal.stat]=goal.target
  var won_contract: bool=campaign.objective(stats,true).awarded
  campaign.finish({"winner":"player","stats":stats,"player":{"hp":50.0,"maxHp":120.0,"energy":10.0}})
  check(campaign.phase=="reward" and campaign.reward_options.size()==3,"side challenge never replaces normal upgrade selection")
  check(campaign.encounter_achievements.size()==1 and campaign.last_encounter_achievement.score==75,"objective has one independently visible result")
  check(campaign.carry.energy==38.0+(10.0 if won_contract else 0.0),"only earned eight SP is added to normal and contract supply")
  check(campaign.carry.hp==56.0+(8.0 if won_contract else 0.0),"new bonus does not inflate healing")
  var saved:=campaign.carry.duplicate(true)
  campaign.finish({"winner":"player","stats":stats})
  check(campaign.carry==saved and campaign.encounter_achievements.size()==1,"repeated finish cannot pay an objective twice")
  var shown:=campaign.snapshot({})
  check(shown.encounterObjective.awarded and not shown.lastEncounterAchievement.is_empty(),"reward screen receives earned challenge and notice")
  check(campaign.choose_reward(0),"choose real upgrade before a later failed encounter")
  campaign.finish({"winner":"enemy","stats":{"parries":0,"dodges":0,"elapsed":999.0,"damageTaken":999.0}})
  check(campaign.last_encounter_achievement.is_empty() and campaign.last_achievement.is_empty() and campaign.encounter_achievements.size()==1,"later defeat clears stale notices while retaining prior earned record")
  campaign.begin_practice()
  check(campaign.encounter_objective(stats).is_empty() and campaign.encounter_achievements.is_empty(),"practice resets all challenge and reward state")
