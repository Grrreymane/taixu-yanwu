extends SceneTree
## Real Main/Combat/Campaign integration, isolated save state, no GPU renderer.
const Health=preload("res://scripts/enemy_health_display.gd")
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
var world

class VolatileCampaign extends "res://scripts/campaign.gd":
	var finish_calls:=0
	var accepted_rewards:=0
	var saves:=0
	func _load_record() -> void:pass
	func _save_record() -> void:saves+=1
	func finish(state:Dictionary) -> void:
		finish_calls+=1
		super.finish(state)
	func choose_reward(index:int) -> bool:
		var accepted:=super.choose_reward(index)
		if accepted:accepted_rewards+=1
		return accepted
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void:pass
	func _notification(_what:int) -> void:pass
	func simulate_focus(value:bool) -> void:
		super._notification(NOTIFICATION_APPLICATION_FOCUS_IN if value else NOTIFICATION_APPLICATION_FOCUS_OUT)
class QuietMusic extends Node:
	func unlock() -> void:pass
	func toggle() -> void:pass
	func set_context(_phase:String,_paused:bool,_ultimate:bool) -> void:pass
	func tick(_delta:float) -> void:pass
	func set_focused(_focused:bool) -> void:pass
	func snapshot() -> Dictionary:return {"enabled":false}
class ErrorRecorder extends Logger:
	var errors:Array=[]
	func _log_error(_function:String,file:String,line:int,code:String,_rationale:String,_notify:bool,error_type:int,_backtraces:Array[ScriptBacktrace]) -> void:
		if error_type!=Logger.ERROR_TYPE_WARNING:errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

func _initialize() -> void:call_deferred("_run")
func _check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);print("CHECK FAILED: ",label)
func _step(seconds:float) -> void:
	var left:=seconds
	while left>0.000001:
		var dt:=minf(1.0/60.0,left)
		world._process(dt);left-=dt
func _prepare(count:int=2,style:String="azure_empyrea") -> void:
	world._action("menu")
	world._action("select_style:"+style)
	world.campaign.begin_trial("mirror",2307)
	var enemies:Array=[]
	for i in count:enemies.append({"id":"probe_%d"%i,"name":"识律幻身","hp":100.0,"x":0.6+float(i)*2.0,"type":"striker"})
	world.game.start_encounter({"training":true,"playerX":-1.0,"enemies":enemies},world.campaign.carry)
	world.stage_countdown=0.0
	world.story.reset();world.boss_entrance.clear()
	world._sync_actors()
	world.simulate_focus(true)
	world.events.clear()
func _hit(defender:Dictionary,by_player:bool=true) -> void:
	# Exercise the actual native combat damage -> enemyDown -> end signal chain.
	var attacker:Dictionary=world.game.player if by_player else world.game.enemies[0]
	world.game._state(defender,"idle")
	var attack={"name":"light","damage":defender.hp+10.0,"postureDamage":1.0,"push":0.15,"stun":0.40,"comboIndex":0,"range":2.0}
	world.game._receive(attacker,defender,attack)
func _events(kind:String) -> int:
	var found:=0
	for event:Dictionary in world.events:
		if str(event.type)==kind:found+=1
	return found
func _run() -> void:
	OS.add_logger(recorder)
	root.size=Vector2i(1440,900)
	world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free();world.music.free();world.music=QuietMusic.new()
	root.add_child(world);world.effects.sounds.clear()
	_check(world.ready_to_play,"Actual Main loads native actors and presentation modules")
	_health_rules()
	_group_and_reward()
	_reset_and_failure()
	_ultimate_finish()
	await process_frame
	await process_frame
	_check(recorder.errors.is_empty(),"No engine or script errors in complete Main flow")
	var report={"suite":"knockout_flow","checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations,"errors":recorder.errors,"gpuUsed":false,"profileSaved":false}
	FileAccess.open("res://build/reports/knockout-flow.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	OS.remove_logger(recorder);world.free()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func _group_and_reward() -> void:
	_prepare(2)
	var plays:int=world.knockout.plays
	var finishes:int=world.campaign.finish_calls
	_hit(world.game.enemies[0])
	_check(_events("enemyDown")==1 and not world.game.ended,"First enemy death leaves the encounter running")
	_check(world.knockout.snapshot().badgeActive and not world.knockout.active,"First death shows only the short defeat counter")
	_check(world.knockout.snapshot().timeScale==1.0 and world.knockout.snapshot().count==1,"Intermediate badge never scales simulation time")
	world.game.hit_stop=0.0
	world.game._state(world.game.player,"idle")
	world._action("light")
	_check(world.game.player.state=="attack","Attack input still reaches Combat while the minor badge is visible")
	world.game._state(world.game.player,"idle")
	world.touch_move=-1.0
	var before_x:float=world.game.player.x
	_step(0.1)
	_check(world.game.player.x<before_x,"Movement continues during ordinary defeat badge")
	_hit(world.game.enemies[1])
	_check(world.game.ended and world.knockout.active,"Final enemy immediately starts KO through the real damage event")
	_check(_events("enemyDown")==2 and _events("end")==1,"Real final strike emitted both enemyDown and end")
	_check(world.knockout.plays==plays+1,"enemyDown/end pair starts the main KO exactly once")
	_check(world.touch_move==0.0 and not world.touch_guard,"Finishing contact clears held movement and guard")
	_step(0.05)
	var freeze_time:float=world.visual_time
	world._action("pause")
	var ko_time:float=world.knockout.time
	_step(0.25)
	_check(world.knockout_paused and is_equal_approx(world.knockout.time,ko_time),"Escape pauses the finishing overlay even after Combat ended")
	_check(is_equal_approx(world.visual_time,freeze_time) and world.campaign.phase=="fight","Paused KO cannot move actors or commit rewards")
	_check(world.knockout.snapshot().pauseHint=="已暂停 · ESC 继续","Paused KO includes its resume hint")
	world._action("pause");_step(0.05)
	_check(not world.knockout_paused and world.knockout.time>ko_time,"Escape resumes the same sequence")
	world.simulate_focus(false)
	ko_time=world.knockout.time;freeze_time=world.visual_time
	_step(0.25)
	_check(is_equal_approx(world.knockout.time,ko_time) and is_equal_approx(world.visual_time,freeze_time),"Focus loss freezes both overlay and actor clocks")
	world.simulate_focus(true)
	_step(1.4)
	_check(world.campaign.phase=="reward" and not world.knockout.active,"Final overlay closes directly into the stage reward")
	_check(world.campaign.finish_calls==finishes+1 and world.campaign.totals.kills==2,"Stage result and kills commit exactly once")
	var options=world.campaign.reward_options.duplicate(true)
	_step(0.3)
	_check(world.campaign.finish_calls==finishes+1 and world.campaign.reward_options==options,"Idle reward frames never resubmit or reroll results")
	var accepted:int=world.campaign.accepted_rewards
	world._action("reward_0")
	world._action("reward_0")
	_check(world.campaign.accepted_rewards==accepted+1 and world.campaign.reward_ids.size()==1,"Double reward input applies one upgrade")
	_check(world.campaign.stage_index==1 and world.story.active,"One reward advances one stage and enters its dialogue")
	_check(not world.knockout_started and not world.knockout.active,"The next encounter reset removes the prior finish latch")

func _reset_and_failure() -> void:
	_prepare(1)
	_hit(world.game.enemies[0])
	world._action("pause");_step(0.01)
	world._action("menu")
	_check(world.campaign.phase=="menu" and not world.knockout.active and not world.knockout_paused and not world.knockout_started,"Return to menu clears a paused finish and all its latches")
	world._action("practice")
	world.game.set_training(true)
	var plays:int=world.knockout.plays
	var finishes:int=world.campaign.finish_calls
	_hit(world.game.player,false)
	_check(world.game.ended and world.game.winner=="enemy" and world.knockout.snapshot().result=="defeat","Player death produces a distinct defeat KO")
	_check(world.knockout.plays==plays+1 and _events("end")>=1,"Failure fallback plays once without enemyDown")
	_step(1.5)
	_check(world.campaign.phase=="failed" and world.campaign.finish_calls==finishes+1,"Failure commits only after its KO completes")
	_check(not world.victory.visible,"Failure does not play the victory animation")
	world._action("menu")
	world._action("practice")
	_check(not world.knockout_started and not world.knockout.visible and world.knockout.snapshot().timeScale==1.0,"Fresh practice has no stale KO or slow motion")

func _ultimate_finish() -> void:
	_ultimate_case("azure_empyrea",1.0,2.65,true)
	_ultimate_case("azure_empyrea",19.0,2.65,false)
	_ultimate_case("fenghuang",1.0,2.82,true)
	_ultimate_case("fenghuang",11.0,2.82,false)

func _ultimate_case(style:String,enemy_hp:float,final_cue:float,early_kill:bool) -> void:
	_prepare(1,style)
	world.game.enemies[0].hp=enemy_hp
	world.game.player.energy=100.0
	var plays:int=world.knockout.plays
	var finishes:int=world.campaign.finish_calls
	world._action("ultimate")
	_check(not world.game.ultimate.is_empty(),style+": native ultimate starts through Main action")
	var wall:=0.0
	while _events("enemyDown")==0 and wall<4.2:
		_step(1.0/60.0);wall+=1.0/60.0
	_check(_events("enemyDown")==1 and not world.game.ended,style+": lethal ultimate hit precedes Combat end")
	if early_kill:_check(not world.knockout.active,style+": early lethal hit waits for the authored finishing impact")
	else:_check(world.knockout.active,style+": lethal last hit starts KO within that same cue")
	var at_death:=wall
	while not world.knockout.active and wall<4.3:
		_step(1.0/60.0);wall+=1.0/60.0
	var ko_started_at:=wall
	_check(world.knockout.active and not world.game.ended,style+": final impact starts KO before ultimateEnd")
	_check(world.knockout.plays==plays+1,style+": final cue creates one KO sequence")
	var source_time:float=world.game.ultimate.get("time",-1.0)
	_check(source_time>=final_cue-0.01 and source_time<final_cue+0.05,style+": KO aligns to its original final impact")
	while world.campaign.phase=="fight" and wall<6.0:
		_step(1.0/60.0);wall+=1.0/60.0
	_check(_events("end")==1 and world.knockout.plays==plays+1,style+": later ultimate end never replays the KO")
	_check(world.campaign.phase=="reward" and world.campaign.finish_calls==finishes+1,style+": ultimate defeat commits one reward")
	_check(wall-ko_started_at<=1.40,style+": finishing impact through reward has no post-KO idle gap")
	observations.append({"scenario":"early_ultimate_kill" if early_kill else "last_cue_kill","style":style,"enemyHp":enemy_hp,"deathAt":at_death,"koAt":ko_started_at,"rewardAt":wall,"koToReward":wall-ko_started_at})

func _health_rules() -> void:
	var single:=[{"id":"one","hp":100.0,"boss":false}]
	var plan:=Health.plan(single)
	_check(plan.mode=="single" and plan.primaryId=="one" and plan.overheadIds.is_empty(),"Single duel shows only the main enemy bar")
	single[0].hp=0.0;plan=Health.plan(single)
	_check(plan.primaryId=="one" and plan.overheadIds.is_empty(),"Defeated single enemy has no duplicate overhead bar")
	var group:=[{"id":"a","hp":80.0,"boss":false},{"id":"b","hp":100.0,"boss":false}]
	plan=Health.plan(group)
	_check(plan.mode=="group" and plan.primaryId.is_empty() and plan.overheadIds==["a","b"],"Group battle uses overhead bars without a duplicate main target bar")
	group[0].hp=0.0;plan=Health.plan(group)
	_check(plan.mode=="group" and plan.primaryId.is_empty() and plan.overheadIds==["b"],"Last group survivor keeps its existing overhead indicator")
	var boss:=[{"id":"boss","hp":500.0,"boss":true},{"id":"add","hp":80.0,"boss":false}]
	plan=Health.plan(boss)
	_check(plan.mode=="boss" and plan.primaryId=="boss" and plan.overheadIds==["add"],"Boss uses the main bar while its escort keeps one overhead bar")
	boss[0].hp=0.0;plan=Health.plan(boss)
	_check(plan.primaryId.is_empty() and plan.overheadIds==["add"],"A defeated boss never hides the surviving escort's health")
	plan=Health.plan([])
	_check(plan.primaryId.is_empty() and plan.overheadIds.is_empty(),"Empty encounters have no phantom health indicator")
