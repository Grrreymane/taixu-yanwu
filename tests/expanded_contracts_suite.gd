extends SceneTree
const Campaign=preload("res://scripts/campaign.gd")
const Combat=preload("res://scripts/combat.gd")
const Preview=preload("res://scripts/character_preview.gd")
class MemoryCampaign extends "res://scripts/campaign.gd":
 var saves:=0
 func _load_record() -> void: pass
 func _save_record() -> void: saves+=1
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
 checks+=1
 if not value: failures.append(label)

func _initialize() -> void:
 var fresh:=MemoryCampaign.new()
 check(not fresh.select_all_contracts(),"all rules locked until a completed trial")
 fresh.select_contract("flow")
 fresh.select_contract("breaker")
 check(fresh.selected_contract_ids==["breaker"],"first run retains single-choice behavior")
 fresh.begin_trial("",123)
 check(not fresh.select_contract("mirror"),"cannot change active rules in combat")
 var single:=fresh.stages.duplicate(true)
 fresh.back_to_menu()
 fresh.completed_runs=1
 check(fresh.select_all_contracts(),"one clear unlocks all rules")
 check(fresh.selected_contract_ids.size()==3,"all three rules selected")
 check(fresh.snapshot({}).contractsUnlocked,"HUD receives unlock")
 check(fresh.snapshot({}).challengeLevel==2,"HUD receives two added pressure levels")
 fresh.begin_trial("",123)
 check(fresh.carry.riposteBonus==0.2 and fresh.carry.dodgeRefund==1.0 and fresh.carry.postureMultiplier==1.2,"all three player mechanics are active")
 for i in fresh.stages.size():
  var stage: Dictionary=fresh.stages[i]
  check(stage.pressureLevel==single[i].pressureLevel+2,"extra pressure stage %d"%i)
  check(stage.enemies.size()==single[i].enemies.size(),"no HP sponge or added enemies stage %d"%i)
  for j in stage.enemies.size():
   check(is_equal_approx(stage.enemies[j].damageScale,single[i].enemies[j].damageScale*1.2),"20 percent damage stage %d enemy %d"%[i,j])
   check(stage.enemies[j].hp==single[i].enemies[j].hp,"preserve enemy HP")
  var combat:=Combat.new()
  combat.start_encounter(stage,fresh.carry)
  check(combat._pressure_level==stage.pressureLevel,"combat accepts pressure above old ceiling")
  check(combat._ai_gap>0.0,"pressure does not produce negative gap")
 check(not fresh.objective({"parries":2,"dodges":0,"maxCombo":6}).complete,"partial objectives earn no all-rule reward")
 check(fresh.objective({"parries":2,"dodges":2,"maxCombo":6}).complete,"all objectives earn reward")
 var first:=fresh.encounter()
 fresh.phase="failed"
 check(fresh.retry(),"multi-rule retry succeeds")
 check(fresh.encounter()==first,"retry preserves exact enemies and pressure")
 fresh.stage_index=5
 fresh.finish({"winner":"player","stats":{"parries":2,"dodges":2,"maxCombo":6},"player":{"hp":65.0,"maxHp":120.0,"energy":70.0}})
 check(fresh.completed_runs==2,"one completed trial increments once")
 check(fresh.contract_wins.size()==3 and "诸约皆成" in fresh.unlocked_titles,"all selected contracts recorded on win")
 check(fresh.achievements.size()==1 and fresh.totals.achievementScore==100,"shared reward is not tripled")
 fresh.back_to_menu()
 fresh.select_contract("flow")
 fresh.select_contract("breaker")
 check(fresh.selected_contract_ids==["mirror"] and not fresh.select_contract("mirror"),"last rule cannot be unchecked")
 check(not fresh.select_contract("invalid"),"unknown rule rejected")
 fresh.begin_practice()
 check(fresh.stages[5].pressureLevel==2,"practice unaffected by challenge choices")
 var sparring:=Combat.new()
 sparring.start_sparring()
 check(sparring.enemy.boss and not sparring._legacy_mode,"free sparring uses real boss move scheduler")
 sparring.enemy.hp=89.0
 sparring._check_boss_phase(sparring.enemy)
 check(sparring.enemy.attack.get("weapon","")=="burst","free sparring has original half-health ultimate")
 sparring.set_training(true)
 sparring.start_sparring()
 check(sparring.training,"retry keeps dummy setting")
 sparring.enemy.hp=89.0
 sparring._check_boss_phase(sparring.enemy)
 check(sparring.enemy.state=="idle" and not sparring.enemy.get("phaseCounterPending",false),"dummy never retaliates at half health")
 sparring.set_training(false)
 sparring.enemy.aiRound=5
 sparring._attack(sparring.enemy,"light")
 check(sparring.enemy.attack.get("weapon","")=="burst","real sparring resumes phase-two ultimates")
 # Dragging rotates the model only; UI clicks outside the preview stay intact.
 var preview:=Preview.new()
 var area:=Rect2(600,100,600,600)
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=Vector2(50,150)
 check(not preview.handle(click,area),"menu button clicks are not captured")
 click.position=Vector2(900,300)
 check(preview.handle(click,area),"preview drag starts on character area")
 var motion:=InputEventMouseMotion.new()
 motion.relative=Vector2(300,0)
 preview.handle(motion,area)
 check(not is_equal_approx(preview.yaw,Preview.FRONT),"drag changes yaw")
 click.pressed=false
 click.position=Vector2(10,10)
 check(preview.handle(click,area) and not preview.dragging,"release outside character ends drag")
 click.pressed=true
 click.double_click=true
 click.position=Vector2(900,300)
 preview.handle(click,area)
 check(is_equal_approx(preview.yaw,Preview.FRONT),"double click restores front")
 var finger:=InputEventScreenTouch.new()
 finger.index=0
 finger.pressed=true
 finger.position=Vector2(900,300)
 check(preview.handle(finger,area),"touch starts same preview")
 var swipe:=InputEventScreenDrag.new()
 swipe.index=0
 swipe.relative=Vector2(150,0)
 check(preview.handle(swipe,area),"touch swipe rotates model")
 var touched_yaw:=preview.yaw
 swipe.index=1
 check(not preview.handle(swipe,area) and preview.yaw==touched_yaw,"second finger cannot hijack preview")
 finger.pressed=false
 check(preview.handle(finger,area) and not preview.dragging,"touch release ends capture")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures}
 FileAccess.open("res://build/reports/expanded-contracts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
