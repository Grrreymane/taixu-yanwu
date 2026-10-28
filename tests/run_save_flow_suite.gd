extends "res://tests/story_flow_suite.gd"
## Exercise real Main transitions with in-memory saves and isolated preferences.
class IsolatedMain extends "res://scripts/main.gd":
 func _load_fighter_choice() -> void:
  fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
  appearance_choices={}
 func _save_fighter_choice() -> void: pass

func _run() -> void:
 OS.add_logger(recorder)
 var world:=IsolatedMain.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 world.music._player.free()
 world.music._previous_player.free()
 world.music.free()
 world.music=QuietMusic.new()
 root.add_child(world)
 world._action("start")
 _frames(world,4,0.4)
 check(world.campaign.run_time==0.0,"intro never consumes clear time")
 world._action("story_skip")
 _frames(world,5,0.05)
 check(world.campaign.run_time==0.0 and world.stage_countdown>0,"countdown never consumes clear time")
 world.stage_countdown=0.0
 world.game.set_training(true)
 world.game.hit_stop=0.4
 world._process(0.2)
 check(is_equal_approx(world.campaign.run_time,0.2) and world.game.time==0.0,"real time includes impact freeze without using capped simulation time")
 world.game.hit_stop=0.0
 world.game.player.energy=100.0
 world._action("ultimate")
 var before: float=world.campaign.run_time
 world._process(0.35)
 check(not world.game.ultimate.is_empty() and is_equal_approx(world.campaign.run_time,before+0.35),"ultimate counts in the same real-time clock")
 world._action("pause")
 before=world.campaign.run_time
 _frames(world,4,0.5)
 check(world.campaign.run_time==before,"pause freezes clear time")
 world._action("pause")
 world._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 world._process(0.6)
 check(world.campaign.run_time==before and world.game.paused,"focus loss saves and pauses without counting background time")
 world._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 world._process(0.2)
 check(world.campaign.run_time==before,"focus return requires an explicit resume")
 world._action("menu")
 var seed: int=world.campaign.run_seed
 var recorded: Dictionary=world.campaign.resume_summary()
 check(recorded.available and recorded.runTimeMs==roundi(before*1000.0),"menu commits the latest real time")
 world._action("select_style:fenghuang")
 world._action("continue")
 check(world.fighter.styleId=="azure_empyrea" and world.campaign.run_seed==seed,"continue restores saved armor and encounter seed")
 check(world.campaign.run_resumes==1 and world.game.player.x<world.game.enemy.x,"continue tracks reuse and starts a normal left-side duel")
 check(world.campaign.run_time==before and world.stage_countdown>0,"continue keeps time and restores the start of the current fight")
 world.stage_countdown=0.0
 world.game.set_training(true)
 world._process(0.4)
 _finish(world)
 check(world.campaign.phase=="reward","real clear reaches reward selection")
 var offers: Array=world.campaign.reward_options.duplicate(true)
 var carry: Dictionary=world.campaign.carry.duplicate(true)
 var totals: Dictionary=world.campaign.totals.duplicate(true)
 before=world.campaign.run_time
 _frames(world,3,0.5)
 check(world.campaign.run_time==before,"reward selection excludes deliberation time")
 world._action("menu")
 world._action("continue")
 check(world.campaign.phase=="reward" and world.game.ended and world.game.winner=="player","reward resume restores a finished fight, not another live clear")
 check(world.campaign.reward_options==offers and world.campaign.carry==carry and world.campaign.totals==totals,"reward reload cannot reroll choices or award healing twice")
 world._action("reward_0")
 check(world.campaign.stage_index==1 and world.campaign.reward_ids.size()==1,"restored reward advances exactly one stage")
 world._action("story_skip")
 _finish(world,false)
 check(world.campaign.phase=="failed","real defeat reaches failed checkpoint")
 before=world.campaign.run_time
 world._action("story_skip")
 world._action("menu")
 world._action("continue")
 check(world.campaign.phase=="fight" and world.campaign.stage_index==1 and world.campaign.totals.retries==1,"failed continuation performs one retry of the same stage")
 check(world.campaign.run_time==before and world.campaign.reward_ids.size()==1,"failed continuation retains spent time and acquired build")
 world._action("menu")
 var trial: Dictionary=world.campaign.resume_data.duplicate(true)
 world._action("practice")
 world.game.set_training(true)
 _frames(world,4,0.3)
 world._action("menu")
 check(world.campaign.resume_data==trial,"practice cannot replace a suspended trial checkpoint")
 check(world.campaign.best_time_ms==0,"incomplete and practice runs cannot create a clear record")
 world.free()
 await process_frame
 check(recorder.errors.is_empty(),"no engine errors during main save and timer transitions")
 OS.remove_logger(recorder)
 var report: Dictionary={"suite":"run_save_flow","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors}
 FileAccess.open("res://build/reports/run-save-flow.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
