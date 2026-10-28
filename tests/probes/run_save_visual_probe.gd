extends "res://tests/story_flow_suite.gd"
## Real Main/HUD rendering with an isolated, volatile test campaign.
const OUTPUT := "res://build/screenshots/run-save"
const SaveStore = preload("res://scripts/local_save.gd")

class PreviewMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","night_squire","autumn_leaves")
		appearance_choices={"night_squire":"autumn_leaves"}
	func _save_fighter_choice() -> void: pass

func _focus(world) -> void:
	world.application_focused=true
	world.game.paused=false
	world.knockout.set_focused(true)
	world.boss_entrance.focused=true
	world.victory.set_focused(true)
	world.story.focused=true

func _advance(world,count: int) -> void:
	_focus(world)
	for index in count:
		world._process(0.05)
		world.hud._process(0.05)

func _capture(world,label: String) -> void:
	for dimensions: Vector2i in [Vector2i(1440,900),Vector2i(960,540)]:
		root.size=dimensions
		_focus(world)
		world._process(0.0)
		world.hud._layout()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/%s-%d.png"%[label,dimensions.x])
		var ui: Dictionary=world.hud.presentation_snapshot()
		check(str(ui.menuPrimaryText).contains("第03战") if label=="continue" else true,"resume screenshot uses the actual third-stage checkpoint")
		check(str(ui.runTimerText).contains("01:") if label=="timer" else true,"battle screenshot displays accumulated trial time")
		check(str(ui.recordText).contains("新纪录") if label=="results" else true,"result screenshot uses a real completed campaign record")

func _run() -> void:
	OS.add_logger(recorder)
	var originals: Dictionary={}
	for relative: String in ["user://fighter-preferences.cfg", "user://taixu_record.cfg",SaveStore.FILE_PATH,SaveStore.FILE_PATH+".backup"]:
		var path:=ProjectSettings.globalize_path(relative)
		originals[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	# RenderingServer already established its shader-cache directory at startup.
	# Keep that engine path stable; isolate gameplay writes through the volatile
	# campaign and explicit preference overrides instead of moving user:// late.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size=Vector2i(1440,900)
	var world:=PreviewMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free()
	world.music._previous_player.free()
	world.music.free()
	world.music=QuietMusic.new()
	root.add_child(world)
	check(world.ready_to_play and not world.campaign.persistence_enabled,"real game initializes without writing player progress")
	world.campaign.begin_trial("mirror",104)
	world._begin_encounter(false)
	for stage in 2:
		_focus(world)
		world.campaign.tick_run(31.125)
		_finish(world)
		check(world.campaign.phase=="reward","normal combat finish reaches reward "+str(stage))
		world._action("reward_0")
		world._action("story_skip")
	world.campaign.tick_run(22.55)
	world._action("menu")
	_advance(world,24)
	check(world.campaign.has_resume(),"home has a real saved checkpoint")
	await _capture(world,"continue")
	world._action("continue")
	world.game.set_training(true)
	_advance(world,72)
	check(world.campaign.stage_index==2,"continue restores the saved stage")
	await _capture(world,"timer")
	for stage in range(2,6):
		_focus(world)
		world.campaign.tick_run(21.75)
		_finish(world)
		if stage<5:
			world._action("reward_0")
			world._action("story_skip")
	check(world.campaign.phase=="cleared" and world.campaign.recent_runs.size()==1,"all six normal finishes create one result record")
	world._action("story_skip")
	world._action("victory_skip")
	_advance(world,24)
	await _capture(world,"results")
	world.free()
	await process_frame
	await process_frame
	for path: String in originals:
		var after:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
		check(after==originals[path],"player save unchanged: "+path.get_file())
	check(recorder.errors.is_empty(),"no rendering or script errors")
	var report: Dictionary={"suite":"run_save_visual","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"output":OUTPUT,"fixture":true}
	FileAccess.open(OUTPUT+"/visual-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	OS.remove_logger(recorder)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
