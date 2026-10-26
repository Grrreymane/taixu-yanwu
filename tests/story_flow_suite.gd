extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var checks:=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var scenes: Array[String]=[]

class VolatileCampaign extends "res://scripts/campaign.gd":
 var saves:=0
 func _load_record() -> void: pass
 func _save_record() -> void: saves+=1
class QuietMusic extends Node:
 var focused:=true
 var context_paused:=false
 func unlock() -> void: pass
 func toggle() -> void: pass
 func set_context(_phase: String,paused: bool,_ultimate: bool) -> void: context_paused=paused
 func tick(_delta: float) -> void: pass
 func set_focused(value: bool) -> void: focused=value
 func snapshot() -> Dictionary: return {"enabled":true,"paused":context_paused}
class ErrorRecorder extends Logger:
 var errors: Array=[]
 var warnings: Array=[]
 func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  var entry: Dictionary={"file":file,"line":line,"code":code}
  if error_type==Logger.ERROR_TYPE_WARNING: warnings.append(entry)
  else: errors.append(entry)
var recorder:=ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)
func _frames(world,count: int,step: float=0.05) -> void:
 for index in count: world._process(step)
func _key(world,key: Key) -> void:
 var event:=InputEventKey.new()
 event.physical_keycode=key
 event.keycode=key
 event.pressed=true
 world._input(event)
func _pose(actor) -> Array:
 var result: Array=[]
 for bone in actor.skeleton.get_bone_count(): result.append(actor.skeleton.get_bone_pose(bone))
 return result
func _record(world) -> Dictionary:
 return {"totals":world.campaign.totals.duplicate(true),"stats":world.game.stats.duplicate(true),"saves":world.campaign.saves,"completions":world.campaign.completed_runs,"boons":world.campaign.boons.duplicate(),"best":world.campaign.best_score}
func _finish(world,win: bool=true) -> void:
 world.stage_countdown=0.0
 world.game.set_training(true)
 if win:
  for foe: Dictionary in world.game.enemies:
   if foe.hp>0:
    foe.hp=1.0
    world.game._receive(world.game.player,foe,Combat.HEAVY.duplicate(true))
 else:
  world.game.player.hp=1.0
  world.game._state(world.game.player,"idle")
  world.game._receive(world.game.enemy,world.game.player,Combat.HEAVY.duplicate(true))
 for index in 200:
  if world.campaign.phase!="fight": break
  world._process(0.05)

func _run() -> void:
 OS.add_logger(recorder)
 var Main=load("res://scripts/main.gd")
 check(Main!=null and Main.can_instantiate(),"real main with story and HUD loads")
 if Main!=null and Main.can_instantiate():
  var world=Main.new()
  world.process_mode=Node.PROCESS_MODE_DISABLED
  world.campaign=VolatileCampaign.new()
  world.music._player.free()
  world.music.free()
  world.music=QuietMusic.new()
  root.add_child(world)
  check(world.ready_to_play,"full real main initializes in a headless fixture")
  _opening(world)
  _full_trial(world)
  _failure_and_menu(world)
  world.free()
  await process_frame
  await process_frame
  # Let queued engine/audio retirement finish before forcing process exit.
  # Two unthrottled headless frames can outpace deferred resource cleanup.
  await create_timer(0.12).timeout
 check(completed==["opening","trial","failure","menu"],"all intended real-main paths completed")
 check(scenes==["intro","reward","reward","reward","reward","reward","victory","defeat"],"opening, all five choice stories and both endings were actually reached")
 check(recorder.errors.is_empty(),"no hidden engine or script errors")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/story-flow-suite.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"warnings":recorder.warnings,"completed":completed,"scenes":scenes},"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"story_flow","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size(),"warnings":recorder.warnings.size()}))
 quit(0 if failures.is_empty() else 1)

func _opening(world) -> void:
 world._action("contract:flow")
 world._action("start")
 check(world.story.active and world.story.scene_id=="intro" and world.story.actors.size()==2,"new trial starts a real two-model opening scene")
 scenes.append("intro")
 check(world.campaign.selected_contract=="flow" and world.game.player.dodgeRefund==1.0,"menu contract reaches actual battle before story begins")
 var time: float=world.game.time
 var countdown: float=world.stage_countdown
 var before: Dictionary=world.game.snapshot().duplicate(true)
 var stage: int=world.campaign.stage_index
 for action: String in ["light","heavy","ability","ultimate","guard","dodge","pause","reward_0","restart","practice","contract:breaker","victory_replay"]: world._action(action)
 _key(world,KEY_J)
 _frames(world,8)
 check(world.game.snapshot()==before and world.game.time==time and world.stage_countdown==countdown and world.campaign.stage_index==stage,"dialogue freezes battle and countdown and rejects combat/reward/restart input")
 check(world.story.clock>0.0 and not world.player.visible and not world.hud.visible,"only story presentation advances and uses its own visible actors/UI")
 var line_index: int=world.story.index
 check(not world.story.revealed,"opening begins with a partial reveal")
 _key(world,KEY_ENTER)
 check(world.story.revealed and world.story.index==line_index,"first Enter reveals the current line without skipping it")
 _key(world,KEY_ENTER)
 check(world.story.index==line_index+1 and not world.story.revealed,"second Enter advances exactly one line")
 _frames(world,1)
 world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 var held: Dictionary=world.story.snapshot().duplicate(true)
 var camera: Transform3D=world.camera.transform
 var actor_pose:=_pose(world.story.actors.senti)
 _frames(world,8)
 check(world.story.snapshot()==held and _pose(world.story.actors.senti)==actor_pose and world.camera.transform==camera,"focus loss freezes dialogue reveal, actor bones and camera")
 world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 _frames(world,1)
 check(world.story.clock>float(held.time) and world.game.time==time,"focus return resumes only the dialogue")
 world.touch_move=1.0
 world.touch_guard=true
 _key(world,KEY_ESCAPE)
 check(not world.story.active and world.stage_countdown==countdown and world.touch_move==0.0 and not world.touch_guard,"Escape skips story and clears held touch input without consuming countdown")
 _frames(world,2)
 check(world.stage_countdown<countdown and world.game.time==time and world.player.visible and world.hud.visible,"skipping restores normal countdown and battle visibility")
 completed.append("opening")

func _full_trial(world) -> void:
 var plays: int=world.victory.plays
 for stage in 6:
  check(world.campaign.stage_index==stage and not world.story.active,"fight starts at expected stage after story completion")
  _finish(world)
  if stage<5:
   check(world.campaign.phase=="reward" and not world.story.active and world.campaign.reward_options.size()==3,"intermediate victory reaches real reward selection without ending the run")
   check(world.victory.plays==plays and not world.victory.visible,"intermediate victory cannot begin the finale")
   var chosen: String=world.campaign.reward_options[0].id
   world._action("reward_0")
   check(world.campaign.reward_ids.size()==stage+1 and chosen in world.campaign.reward_ids,"choice is committed exactly once before entering the next scene")
   check(world.story.active and world.story.scene_id=="reward","every committed choice triggers its own single reward scene")
   check(world.story.snapshot().choice.latestId==chosen and world.story.snapshot().choice.finalChoice==(stage==4),"choice story identifies the actual selected card and last-choice boundary")
   scenes.append("reward")
   var saved:=_record(world)
   world._action("reward_1")
   _frames(world,4)
   check(_record(world)==saved,"story cannot lose, duplicate or replace the chosen reward")
   if stage==1:
    var advances:=0
    while world.story.active and advances<12:
     world._action("story_next")
     advances+=1
    check(not world.story.active and advances==world.story.lines.size()*2,"natural reveal/next sequence finishes once with no extra input")
   else: world._action("story_skip")
   check(not world.story.active and world.stage_countdown>0.0,"choice story returns directly to its encounter without a second middle/final scene")
  else:
   check(world.campaign.phase=="cleared" and world.story.active and world.story.scene_id=="victory","final death finishes before victory conversation begins")
   scenes.append("victory")
   check(world.victory.plays==plays and not world.victory.visible,"MVP presentation waits for the victory dialogue")
   var committed:=_record(world)
   _frames(world,10)
   check(_record(world)==committed and world.story.active,"ended combat cannot commit score again while characters speak")
   world._action("story_skip")
   check(world.victory.visible and world.victory.plays==plays+1 and world.campaign.saves==1,"skip begins exactly one MVP presentation after one progress save")
   _frames(world,12)
   world._action("story_skip")
   check(_record(world)==committed and world.victory.plays==plays+1,"late repeated skip cannot replay or rescore the victory")
 completed.append("trial")

func _failure_and_menu(world) -> void:
 world._action("menu")
 world._action("start")
 world._action("story_skip")
 var plays: int=world.victory.plays
 _finish(world,false)
 check(world.campaign.phase=="failed" and world.story.active and world.story.scene_id=="defeat","actual player death opens loss dialogue instead of victory")
 scenes.append("defeat")
 var committed:=_record(world)
 world._action("retry")
 check(world.story.active and world.campaign.phase=="failed","retry cannot bypass unfinished story through an unrelated action")
 world._action("story_skip")
 check(not world.victory.visible and world.victory.plays==plays and _record(world)==committed,"loss conversation never creates a win or records another score")
 var layout: Array=world.campaign.stages.duplicate(true)
 world._action("retry")
 check(world.campaign.phase=="fight" and not world.story.active and world.stage_countdown>0.0 and world.campaign.stages==layout,"retry keeps the same encounter and avoids replaying opening dialogue")
 completed.append("failure")
 world._action("menu")
 world._action("start")
 check(world.story.active,"fresh run permits its opening again")
 world.touch_move=-1.0
 world.touch_guard=true
 world._action("menu")
 _frames(world,1)
 check(not world.story.active and world.story_after.is_empty() and world.campaign.phase=="menu" and not world.game.started and not world.victory.visible,"menu during story clears all pending continuation state")
 check(world.touch_move==0.0 and not world.touch_guard and world.hud.visible,"menu clears controls and restores the main interface")
 world._action("practice")
 check(not world.story.active and world.campaign.mode=="practice" and world.game.player.dodgeRefund==0.0,"free practice stays immediate and free of trial dialogue/rules")
 completed.append("menu")
