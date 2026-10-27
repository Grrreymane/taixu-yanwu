extends SceneTree
## Actual Main and combat events with fixed initial positions; a visual fixture,
## not a normal-input gameplay test. --label=before/after keeps comparisons.
const STEP := 1.0/120.0
var world
var label := "current"
var output := ""
var samples: Array = []
var failures: Array[String] = []

class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what: int) -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=").validate_filename()
	output="res://build/screenshots/ultimate-effects/"+label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,800)
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	world.music.enabled=false
	world.voice.enabled=false
	world.effects.sounds.clear()
	if not world.ready_to_play: failures.append("Main failed to load")
	else:
		for style: String in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
			await armor(style)
	var report={"passed":failures.is_empty(),"failures":failures,"samples":samples,"label":label,"fixture":"Actual Main, native actors, real ultimate events; practice AI off and fixed HP/positions/SP. No preferences changed."}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTIMATE_EFFECTS_VISUAL ",samples.size()," samples; failures ",failures.size())
	world.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func tick() -> void:
	world._process(STEP)
	world.hud._process(STEP)

func armor(style: String) -> void:
	world._action("menu")
	world._select_fighter(style,"default")
	world._action("practice")
	world.game.set_training(true)
	world.stage_countdown=0.0
	world.game.player.x=-0.75
	world.game.enemy.x=0.75
	world.game.enemy.hp=1000.0
	world.game.enemy.maxHp=1000.0
	world.game.player.energy=100.0
	if world.game.player_profile!=style: failures.append(style+": incorrect combat profile "+str(world.game.player_profile))
	world.player.reset_presentation()
	world.effects.clear()
	world.sentience_effects.clear()
	for ignored in 30: tick()
	if not world.game.action("ultimate"):
		failures.append(style+": ultimate rejected")
		return
	var times: Array= {
		"azure_empyrea":[0.40,1.25,2.02,2.72],
		"fenghuang":[0.45,1.25,2.15,2.88],
		"night_squire":[0.35,0.80,1.24,1.64],
		"shadow_knight":[0.35,0.85,1.28,1.50],
		"hawk_of_the_fog":[0.20,0.39,0.52,0.75]
	}[style]
	var index:=0
	var elapsed:=0.0
	for ignored in 900:
		tick()
		elapsed+=STEP
		if index<times.size() and elapsed>=float(times[index]):
			await capture(style,index,elapsed)
			index+=1
			if index==times.size(): break
	if index!=times.size(): failures.append(style+": incomplete captures")
	await process_frame

func capture(style: String,index: int,time: float) -> void:
	var filename:=style+"-"+str(index)+".png"
	var fx: Dictionary=world.effects.snapshot()
	if DisplayServer.get_name()!="headless":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+filename)
	samples.append({"style":style,"index":index,"time":time,"fx":fx,"shot":world.cinematic_frame.get("shot",""),"png":filename})
