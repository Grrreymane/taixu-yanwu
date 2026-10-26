extends SceneTree
## Isolated visual fixture using the actual Main, combat, native actors and FX.
## This does not prove normal gameplay: weapon selection/positions are fixtures.
## Run with -- --capture under a graphics renderer; --check-only is headless safe.
const OUTPUT := "res://build/screenshots/sentience-effects-visual"
const STEP := 1.0/120.0
var capture := false
var world
var label: Label
var contact_time := -1.0
var contact_events: Array[Dictionary] = []
var records: Array[Dictionary] = []
var failures: Array[String] = []
var captured := 0

class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what: int) -> void: pass
	func _camera(_dt: float,_visual_dt: float,_ult_time: float) -> void:
		# Fixed inspection framing contains the 7.2m burst and the whole spear.
		camera_base=Vector3(0.45,3.0,12.8)
		menu_target=Vector3(0.45,1.35,0)
		camera.fov=38.0
		camera.position=camera_base
		camera.look_at(menu_target)

class QuietMusic extends Node:
	func unlock() -> void: pass
	func toggle() -> void: pass
	func set_context(_phase: String,_paused: bool,_ultimate: bool) -> void: pass
	func tick(_delta: float) -> void: pass
	func set_focused(_focused: bool) -> void: pass
	func snapshot() -> Dictionary: return {"enabled":false}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.music._player.free()
	world.music.free()
	world.music=QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	world.game.event.connect(_record_event)
	var canvas:=CanvasLayer.new();canvas.layer=101;root.add_child(canvas)
	label=Label.new();canvas.add_child(label)
	label.position=Vector2(24,112)
	label.add_theme_font_size_override("font_size",19)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	if not world.ready_to_play:
		failures.append("Actual Main failed to load")
	else:
		for weapon: String in ["sword","spear","chain","burst"]:
			await _weapon_case(weapon)
	var report:={"passed":failures.is_empty(),"failures":failures,"capture":capture,"captures":captured,
		"fixture":"Actual Main practice mode, AI disabled using training toggle, fixed positions and explicit native enemy attack selection. No production scripts or preferences changed. Not a normal-input gameplay proof.",
		"timing":"Capture ages use actual hit event game.time, after hitstop has expired. Wall-clock/render waits never advance simulation.","records":records}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SENTIENCE FX VISUAL ",records.size()," samples / ",captured," PNG; failures ",failures.size())
	world.free();canvas.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _record_event(data: Dictionary) -> void:
	if str(data.get("type",""))=="hit" and str(data.get("style",""))=="sentience" and str(data.get("targetId",""))=="player":
		if contact_time<0.0: contact_time=float(data.time)
		contact_events.append(data.duplicate(true))

func _tick(delta: float) -> void:
	world._process(delta)
	world.hud._process(delta)

func _weapon_case(weapon: String) -> void:
	world._action("practice")
	world.game.set_training(true)
	world.game.player.x=-1.0
	world.game.enemy.x=1.0
	if weapon=="spear":
		world.game.player.x=-1.7
		world.game.enemy.x=1.6
	elif weapon in ["chain","burst"]:
		world.game.player.x=-1.3
		world.game.enemy.x=1.2
	world.game.player.facing=1.0
	world.game.enemy.facing=-1.0
	world.game.enemy.weaponLock=weapon if weapon!="burst" else "sword"
	world.player.reset_presentation()
	for actor in world.enemy_nodes.values(): actor.reset_presentation()
	world.effects.clear();world.sentience_effects.clear();world.combat_accent.clear()
	world.hud._banner_time=0.0
	world.hud._notice_time=0.0
	for ignored in 30: _tick(STEP)
	contact_time=-1.0
	contact_events.clear()
	# Native combat performs damage, hitstop and the exact attack/hit FX events.
	# The training toggle only suppresses unsolicited follow-up AI decisions.
	world.game._sentience_attack(world.game.enemy,"light",0,weapon=="burst")
	var attack: Dictionary=world.game.enemy.attack.duplicate(true)
	var targets: Array[float]=[0.065,0.160]
	var index:=0
	var frozen_frames:=0
	var elapsed:=0.0
	for ignored in 720:
		_tick(STEP)
		elapsed+=STEP
		if float(world.game.hit_stop)>0.0: frozen_frames+=1
		if contact_time>=0.0 and float(world.game.hit_stop)<=0.0:
			var age: float=world.game.time-contact_time
			if index<targets.size() and age>=targets[index]+0.000001:
				await _capture(weapon,"contact" if index==0 else "peak",age,attack,frozen_frames)
				index+=1
				if index>=targets.size():break
	if contact_time<0.0: failures.append(weapon+": fixture produced no actual native hit event")
	if index!=2: failures.append(weapon+": did not reach both post-contact simulation timestamps")
	if frozen_frames==0: failures.append(weapon+": fixture did not exercise real contact hitstop")
	await process_frame

func _capture(weapon: String,phase: String,age: float,attack: Dictionary,frozen_frames: int) -> void:
	var enemy_actor=world.enemy_nodes.get(str(world.game.enemy.id))
	var pose: Dictionary=enemy_actor.presentation_snapshot() if enemy_actor!=null else {}
	var fx: Dictionary=world.sentience_effects.snapshot()
	var required: String={"sword":"blade","spear":"thrust","chain":"blade","burst":"ground"}[weapon]
	if phase=="contact" and required not in fx.get("textures",[]): failures.append(weapon+": expected original effect texture role missing after actual hit: "+required)
	label.text="NATIVE C6 VFX FIXTURE  /  %s  /  %s\n%s   source %.3fs   impact +%.3fs   hitstop %.3fs\nactual hit events %d   native FX %s"%[weapon.to_upper(),phase,str(attack.get("motion","")),float(pose.get("sourceTime",0.0)),age,float(world.game.hit_stop),contact_events.size(),str(fx.get("textures",[]))]
	if capture:
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/"+weapon+"-"+phase+".png")
		captured+=1
	records.append({"weapon":weapon,"phase":phase,"simulationAgeAfterHit":age,"hitTime":contact_time,
		"hitStop":world.game.hit_stop,"hitstopFrames":frozen_frames,"attack":attack,"events":contact_events.duplicate(true),
		"playerHp":world.game.player.hp,"playerX":world.game.player.x,"enemyX":world.game.enemy.x,
		"nativeActor":pose,"vfx":fx,"filename":weapon+"-"+phase+".png"})
