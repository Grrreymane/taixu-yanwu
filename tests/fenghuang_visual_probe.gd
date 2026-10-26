extends SceneTree
## Headless by default. Add -- --capture for optional native PNGs/contact sheets.
## Uses isolated fixtures, never writes preferences or adds a product input API.
const Roster = preload("res://scripts/fighter_roster.gd")
const STEP := 1.0 / 60.0
const OUTPUT := "res://build/screenshots/fenghuang-native-full"
var capture := false
var failures: Array[String] = []
var records: Array[Dictionary] = []
var gallery: Dictionary = {}
var world
var baseline: Dictionary = {}
var captured := 0

class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter = FighterRoster.resolve("fuhua","fenghuang","default")
		appearance_choices = {"fenghuang":"default"}
	func _save_fighter_choice() -> void:
		pass

class QuietMusic extends Node:
	func unlock() -> void: pass
	func toggle() -> void: pass
	func set_context(_phase: String, _paused: bool, _ultimate: bool) -> void: pass
	func tick(_delta: float) -> void: pass
	func set_focused(_focused: bool) -> void: pass
	func snapshot() -> Dictionary: return {"enabled":true}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world = ProbeMain.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.music._player.free()
	world.music.free()
	world.music = QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	if not world.player.ready_for_combat:
		failures.append("Selected native fighter did not load")
	else:
		for facing: float in [1.0,-1.0]:
			await _ultimate_case(facing)
		if not "--q-only" in OS.get_cmdline_user_args():
			for facing: float in [1.0,-1.0]:
				for stance: String in ["punch","kick"]:
					for index in 3:
						await _attack_case(facing,stance,"light",index)
					await _attack_case(facing,stance,"heavy",0)
					await _attack_case(facing,stance,"ability",0)
					await _attack_case(facing,stance,"counter",0)
					for reaction: String in ["guard","block","parry"]:
						await _defense_case(facing,stance,reaction)
				for action: String in ["move","dodge","dodgeBack","stagger"]:
					await _mobility_case(facing,action)
	if capture:
		_save_grids()
	var extremes: Array[Dictionary] = []
	for record: Dictionary in records:
		var max_head := -1000.0
		var min_foot := 1000.0
		var max_floor := -1000.0
		var peak_time := 0.0
		var outside := 0
		for sample: Dictionary in record.samples:
			if float(sample.head[1])>max_head:
				max_head=float(sample.head[1])
				peak_time=float(sample.clock)
			min_foot=minf(min_foot,float(sample.feetMinY))
			max_floor=maxf(max_floor,float(sample.feetMinY))
			if not sample.headInView: outside+=1
		extremes.append({"case":record.label,"maxHeadY":max_head,"headPeakAt":peak_time,"minFootY":min_foot,"maxBothFeetY":max_floor,"headOutOfViewSamples":outside})
	var report := {"passed":failures.is_empty(),"failures":failures,"capture":capture,"captured":captured,"sampleStep":STEP,
		"fighter":Roster.presentation_identity("fuhua","fenghuang","default"),"extremes":extremes,"records":records}
	var file := FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	extremes.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.maxHeadY)>float(b.maxHeadY))
	print(JSON.stringify({"passed":failures.is_empty(),"cases":records.size(),"captures":captured,"failures":failures,"highest":extremes.slice(0,8)}))
	world.free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _reset(facing: float, stance: String = "punch") -> void:
	world._action("practice")
	world.game.set_training(true)
	world.game.player.x=-0.8*facing
	world.game.enemy.x=0.8*facing
	world.game.player.facing=facing
	world.game.enemy.facing=-facing
	world.game.player.stance=stance
	world.game.player.energy=100.0
	world._process(0.0)
	world.hud._banner_time=0.0
	world.hud._notice_time=0.0
	for ignored in 30:
		_tick(STEP)
	baseline=_sample(0.0)

func _tick(delta: float) -> void:
	world._process(delta)
	world.hud._process(delta)

func _point(name: String) -> Vector3:
	var rig: Skeleton3D = world.player.skeleton
	var id := rig.find_bone(name)
	return rig.global_transform*rig.get_bone_global_pose(id).origin if id>=0 else Vector3.ZERO

func _xyz(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

func _sample(clock: float) -> Dictionary:
	var head := _point("Bip001 Head")
	var left := _point("Bip001 L Foot")
	var right := _point("Bip001 R Foot")
	var pelvis := _point("Bip001")
	var max_y := -1000.0
	var highest_point := Vector3.ZERO
	var highest_bone := ""
	var finite := true
	var rig: Skeleton3D = world.player.skeleton
	for index in rig.get_bone_count():
		var pose: Transform3D = rig.global_transform*rig.get_bone_global_pose(index)
		finite = finite and pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite()
		if pose.origin.y>max_y:
			max_y=pose.origin.y
			highest_point=pose.origin
			highest_bone=rig.get_bone_name(index)
	if not finite and not failures.has("Non-finite native bones"):
		failures.append("Non-finite native bones")
	var head_screen: Vector2 = world.camera.unproject_position(head)
	var left_screen: Vector2 = world.camera.unproject_position(left)
	var right_screen: Vector2 = world.camera.unproject_position(right)
	var highest_screen: Vector2 = world.camera.unproject_position(highest_point)
	var viewport: Rect2 = root.get_visible_rect()
	var clip: Dictionary = world.player.presentation_snapshot()
	return {"clock":clock,"gameTime":world.game.time,"ultimateTime":world.game.ultimate.get("time",-1.0),
		"motion":clip.motion,"sourceTime":clip.sourceTime,"finite":finite,"actorX":world.player.position.x,
		"root":_xyz(pelvis),"head":_xyz(head),"leftFoot":_xyz(left),"rightFoot":_xyz(right),
		"feetMinY":minf(left.y,right.y),"maxBoneY":max_y,"highestBone":highest_bone,"maxBonePoint":_xyz(highest_point),"maxBoneScreen":[highest_screen.x,highest_screen.y],
		"headScreen":[head_screen.x,head_screen.y],"footScreens":[[left_screen.x,left_screen.y],[right_screen.x,right_screen.y]],
		"headInView":viewport.has_point(head_screen) and not world.camera.is_position_behind(head),
		"feetInView":viewport.has_point(left_screen) and viewport.has_point(right_screen) and not world.camera.is_position_behind(left) and not world.camera.is_position_behind(right),
		"camera":_xyz(world.camera.position),"cameraTarget":_xyz(world.menu_target),"fov":world.camera.fov,
		"shot":world.cinematic_frame.get("shot",""),"hp":world.game.enemy.hp,"vfx":world.effects.snapshot()}

func _capture(label: String, group: String) -> void:
	if not capture: return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT+"/"+label+".png")
	image.resize(480,300,Image.INTERPOLATE_LANCZOS)
	if not gallery.has(group): gallery[group]=[]
	gallery[group].append(image)
	captured+=1

func _save_grids() -> void:
	for group: String in gallery:
		var images: Array = gallery[group]
		var rows := ceili(float(images.size())/3.0)
		var sheet := Image.create(1440,rows*300,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("102632"))
		for index in images.size():
			sheet.blit_rect(images[index],Rect2i(0,0,480,300),Vector2i(index%3*480,index/3*300))
		sheet.save_png(OUTPUT+"/grid-"+group+".png")

func _ultimate_case(facing: float) -> void:
	_reset(facing)
	world.game.enemy.hp=40.0
	var label := "q-right" if facing>0.0 else "q-left"
	world._action("ultimate")
	var samples: Array[Dictionary] = []
	var cue_times := [0.0,0.20,0.55,1.0,1.5,2.10,2.82,3.3,3.8]
	var cue := 0
	var clock := 0.0
	for index in 230:
		samples.append(_sample(clock))
		# Sample just after each cue, so 2.10 includes the real hit rather than
		# a floating-point value immediately before Combat's damage threshold.
		if cue<cue_times.size() and clock>float(cue_times[cue])+0.000001:
			await _capture("%s-%03d" % [label,roundi(float(cue_times[cue])*100)],label)
			cue+=1
		_tick(STEP)
		clock+=STEP
	records.append({"label":label,"facing":facing,"baseline":baseline,"samples":samples})
	for ignored in 90:
		_tick(STEP)
	if not world.victory.visible:
		failures.append(label+": lethal Q did not enter victory")
	for at in [0.2,1.8,4.6]:
		world.victory.time=at
		_tick(0.0)
		await _capture("%s-victory-%03d" % [label,roundi(at*100)],label)
	await process_frame

func _attack_case(facing: float, stance: String, kind: String, combo: int) -> void:
	_reset(facing,stance)
	var label := "%s-%s-%s%d" % ["right" if facing>0.0 else "left",stance,kind,combo+1]
	if kind=="counter":
		world.game.player.counterUntil=world.game.time+1.0
		world.game.action("light")
	elif kind=="ability":
		world.game.action("ability")
	else:
		world.game._attack(world.game.player,kind,combo)
	var attack: Dictionary=world.game.player.attack.duplicate(true)
	var samples: Array[Dictionary]=[]
	var snapped := false
	for ignored in 180:
		var clock: float=world.game.player.stateTime
		samples.append(_sample(clock))
		if not snapped and clock+0.00001>=float(attack.windup):
			await _capture(label,"moves-"+("right" if facing>0.0 else "left"))
			snapped=true
		_tick(STEP)
		if world.game.player.state!="attack": break
	records.append({"label":label,"facing":facing,"attack":attack,"baseline":baseline,"samples":samples})
	await process_frame

func _defense_case(facing: float, stance: String, reaction: String) -> void:
	_reset(facing,stance)
	world.touch_guard=true
	world.game.action("guard")
	for ignored in 12: _tick(STEP)
	if reaction!="guard": world.player.react_impact(reaction,-facing,false)
	var label := "%s-%s-%s" % ["right" if facing>0.0 else "left",stance,reaction]
	var samples: Array[Dictionary]=[]
	for index in 30:
		_tick(STEP)
		samples.append(_sample(float(index)*STEP))
		if index==6: await _capture(label,"moves-"+("right" if facing>0.0 else "left"))
	records.append({"label":label,"facing":facing,"baseline":baseline,"samples":samples})
	await process_frame

func _mobility_case(facing: float, action: String) -> void:
	_reset(facing)
	if action=="move": world.touch_move=-facing
	elif action in ["dodge","dodgeBack"]:
		world.game._last_move=facing if action=="dodge" else -facing
		world.game.action("dodge")
	else:
		world.game._state(world.game.player,"stagger",0.5)
		world.player.react_impact("hit",-facing,false)
	var samples: Array[Dictionary]=[]
	var label := "%s-%s" % ["right" if facing>0.0 else "left",action]
	for index in 36:
		_tick(STEP)
		samples.append(_sample(float(index)*STEP))
		if index==8: await _capture(label,"moves-"+("right" if facing>0.0 else "left"))
	records.append({"label":label,"facing":facing,"baseline":baseline,"samples":samples})
	await process_frame
