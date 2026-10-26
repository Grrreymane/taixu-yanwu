extends SceneTree
## Native, headless contracts. --baseline exercises existing behavior while
## the new helpers are being integrated; final acceptance uses no flags.
const Actor = preload("res://scripts/actor.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const STEP := 1.0 / 60.0
const AUX_PREFIXES := ["Fuka_C5_04_02_Hair_", "Fuka_C5_04_02_Ribbon_", "Fuka_C5_04_02_Skirt_"]
var checks := 0
var failures: Array[String] = []
var diagnostics: Dictionary = {}

class QuietMusic extends Node:
	func unlock() -> void: pass
	func toggle() -> void: pass
	func set_context(_phase: String, _paused: bool, _ultimate: bool) -> void: pass
	func tick(_delta: float) -> void: pass
	func set_focused(_focused: bool) -> void: pass
	func snapshot() -> Dictionary: return {"enabled":true}

class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass

class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","taixu_memory")
		appearance_choices={"azure_empyrea":"taixu_memory"}
	func _save_fighter_choice() -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		push_error(label)

func _fighter(state: String, at: float, facing: float=1.0) -> Dictionary:
	return {"state":state,"stateTime":at,"stateDuration":0.4,"facing":facing,"x":0.0,"stance":"punch"}

func _spawn(style: String, skin: String, disable_secondary: bool=false):
	var selection: Dictionary=Roster.resolve("fuhua",style,skin)
	if disable_secondary: selection.actor.visual.secondaryMotion=""
	var actor=Actor.new()
	root.add_child(actor)
	actor.setup(false,selection)
	return actor

func _pose(actor) -> Array[Transform3D]:
	var values: Array[Transform3D]=[]
	for i in actor.skeleton.get_bone_count(): values.append(actor.skeleton.get_bone_pose(i))
	return values

func _poses_close(a: Array, b: Array, tolerance: float=0.00001) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if not Vector3(a[i].origin).is_equal_approx(b[i].origin): return false
		for axis in 3:
			if Vector3(a[i].basis[axis]).distance_to(b[i].basis[axis])>tolerance: return false
	return true

func _finite(actor) -> bool:
	for transform: Transform3D in _pose(actor):
		if not transform.origin.is_finite() or not transform.basis.x.is_finite() or not transform.basis.y.is_finite() or not transform.basis.z.is_finite(): return false
	return true

func _different_bones(actor, reference) -> Array[String]:
	var names: Array[String]=[]
	for index in actor.skeleton.get_bone_count():
		if not _poses_close([actor.skeleton.get_bone_pose(index)],[reference.skeleton.get_bone_pose(index)]):
			names.append(actor.skeleton.get_bone_name(index))
	return names

func _face_materials(actor) -> Dictionary:
	var found: Dictionary={}
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			if material is ShaderMaterial and int(material.get_shader_parameter("material_kind"))==3:
				found[str(mesh.name)+":"+str(surface)]=material
	return found

func _face_uv(actor) -> Dictionary:
	var result: Dictionary={}
	var materials:=_face_materials(actor)
	for key: String in materials:
		result[key]={"scale":materials[key].get_shader_parameter("uv_scale"),"offset":materials[key].get_shader_parameter("uv_offset")}
	return result

func _valid_uv(actor) -> bool:
	for value: Dictionary in _face_uv(actor).values():
		var scale: Vector2=value.scale
		var offset: Vector2=value.offset
		if not scale.is_finite() or not offset.is_finite() or scale.x<=0.0 or scale.y<=0.0: return false
		if offset.x<0.0 or offset.y<0.0 or offset.x+scale.x>1.0001 or offset.y+scale.y>1.0001: return false
	return true

func _auxiliary(name: String) -> bool:
	for prefix: String in AUX_PREFIXES:
		if name.begins_with(prefix): return true
	return false

func _run() -> void:
	for ids: Array in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		_actor_regression(str(ids[0]),str(ids[1]))
	if not "--baseline" in OS.get_cmdline_user_args():
		_secondary_integration()
		_secondary_helper_contract()
		_expression_integration()
		_facial_helper_contract()
	if not "--unit-only" in OS.get_cmdline_user_args(): await _main_contract()
	await process_frame
	await process_frame
	var report: Dictionary={"suite":"skin_expression","checks":checks,"failures":failures,"passed":failures.is_empty(),"baselineOnly":"--baseline" in OS.get_cmdline_user_args(),"diagnostics":diagnostics}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var file:=FileAccess.open("res://build/reports/skin-expression-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _actor_regression(style: String, skin: String) -> void:
	var actor=_spawn(style,skin)
	var clean=_spawn(style,skin)
	var label:=style+"/"+skin
	_check(actor.ready_for_combat and clean.ready_for_combat,label+" models and native motion load")
	if not actor.ready_for_combat or not clean.ready_for_combat:
		actor.free()
		clean.free()
		return
	var faces:=_face_materials(actor)
	var clean_faces:=_face_materials(clean)
	_check(faces.size()>=3,label+" has independent eye and mouth surfaces")
	var separate:=true
	for key: String in faces:
		separate=separate and clean_faces.has(key) and faces[key]!=clean_faces[key]
	_check(separate,label+" face materials are per actor rather than shared between opponents")
	for side: float in [-1.0,1.0]:
		actor.reset_presentation()
		for state: String in ["idle","move","guard","stagger"]:
			for frame in 20:
				var at:=float(frame+1)*STEP
				actor.animate_fighter(_fighter(state,at,side),STEP,at)
			_check(_finite(actor) and _valid_uv(actor),label+" finite bones and valid atlas "+state+" / "+str(side))
			var frozen_pose:=_pose(actor)
			var frozen_face:=_face_uv(actor)
			var frozen: Dictionary=actor.presentation_snapshot()
			var fighter:=_fighter(state,20.0*STEP,side)
			for ignored in 12: actor.animate_fighter(fighter,0.0,20.0+float(ignored))
			_check(_poses_close(frozen_pose,_pose(actor)) and frozen_face==_face_uv(actor) and frozen==actor.presentation_snapshot(),label+" zero simulation delta freezes pose/face despite wall time "+state+" / "+str(side))
	actor.reset_presentation()
	for at: float in [0.0,0.2,0.4,0.8,1.2,1.8,3.0,4.6]:
		actor.animate_victory(at)
		var pose:=_pose(actor)
		var uv:=_face_uv(actor)
		var state: Dictionary=actor.presentation_snapshot()
		actor.animate_victory(at)
		actor.animate_victory(at)
		_check(_finite(actor) and _valid_uv(actor) and _poses_close(pose,_pose(actor)) and uv==_face_uv(actor) and state==actor.presentation_snapshot(),label+" repeated victory time is stable %.2f" % at)
	actor.reset_presentation()
	clean.reset_presentation()
	if not _poses_close(_pose(actor),_pose(clean)): diagnostics[label+"ResetResidual"]=_different_bones(actor,clean)
	_check(_poses_close(_pose(actor),_pose(clean)) and _face_uv(actor)==_face_uv(clean),label+" reset clears victory, cloth and facial residue")
	for frame in 60:
		var at:=float(frame)*STEP
		actor.animate_victory(at)
		clean.animate_victory(at)
	_check(_poses_close(_pose(actor),_pose(clean)) and _face_uv(actor)==_face_uv(clean),label+" replay matches a fresh actor at identical presentation times")
	actor.free()
	clean.free()

func _secondary_integration() -> void:
	var actor=_spawn("azure_empyrea","taixu_memory")
	var reference=_spawn("azure_empyrea","taixu_memory",true)
	var snapshot: Dictionary=actor.presentation_snapshot()
	_check(snapshot.has("secondaryMotion"),"actor exposes secondaryMotion diagnostics")
	if not snapshot.has("secondaryMotion"):
		actor.free()
		reference.free()
		return
	var secondary: Dictionary=snapshot.secondaryMotion
	_check(secondary.get("enabled",false) and int(secondary.get("boneCount",0))>0,"skin enables its auxiliary skeleton controller")
	var names: Array=secondary.get("boneNames",[])
	_check(not names.is_empty() and names.all(func(name): return _auxiliary(str(name))),"controller lists only the named skin hair/ribbon/skirt bones")
	var changed_names: Dictionary={}
	var bodies_equal:=true
	var other_bones_equal:=true
	var position_scale_equal:=true
	for state: String in ["idle","move","attack","guard","stagger"]:
		for frame in 40:
			var at:=float(frame+1)*STEP
			var fighter:=_fighter(state,at,-1.0 if frame>=20 else 1.0)
			fighter.x=at*2.0 if state=="move" else 0.0
			if state=="attack": fighter.attack={"name":"heavy","comboIndex":0,"duration":0.88,"windup":0.5}
			actor.animate_fighter(fighter,STEP,at)
			reference.animate_fighter(fighter,STEP,at)
			for index in actor.skeleton.get_bone_count():
				var name: String=actor.skeleton.get_bone_name(index)
				var actual: Transform3D=actor.skeleton.get_bone_pose(index)
				var expected: Transform3D=reference.skeleton.get_bone_pose(index)
				var same:=_poses_close([actual],[expected])
				if name.begins_with("Bip001"): bodies_equal=bodies_equal and same
				if _auxiliary(name):
					if not same: changed_names[name]=true
					position_scale_equal=position_scale_equal and actual.origin.is_equal_approx(expected.origin) and actual.basis.get_scale().is_equal_approx(expected.basis.get_scale())
				else: other_bones_equal=other_bones_equal and same
	_check(bodies_equal,"secondary controller never changes body animation or contact bones")
	_check(other_bones_equal,"secondary controller never changes bones outside its whitelist")
	_check(position_scale_equal,"secondary controller preserves auxiliary bone positions and scales")
	_check(changed_names.size()>6,"multiple hair and cloth bones actually move beyond their native rest pose")
	_check(not changed_names.has("Fuka_C5_04_02_Hair_B_01") and not changed_names.has("Fuka_C5_04_02_Skirt_B_01") and not changed_names.has("Fuka_C5_04_02_Skirt_BL_01") and not changed_names.has("Fuka_C5_04_02_Skirt_BR_01"),"original prefab's four fixed chain anchors retain their native rest rotations")
	diagnostics.secondaryChangedBones=changed_names.keys()
	actor.reset_presentation()
	reference.reset_presentation()
	_check(_poses_close(_pose(actor),_pose(reference)),"reset removes every auxiliary offset instead of accumulating on the last frame")
	actor.free()
	reference.free()

func _expression_integration() -> void:
	var actor=_spawn("azure_empyrea","taixu_memory")
	_check(actor.presentation_snapshot().has("facial"),"actor exposes facial atlas diagnostics")
	var frames: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/fuhua-face-atlas.json")).frames
	var seen: Dictionary={}
	var valid:=true
	var corresponding:=true
	for frame in 360:
		var at:=float(frame+1)*STEP
		actor.animate_fighter(_fighter("idle",at),STEP,at)
		seen[str(_face_uv(actor))]=true
		valid=valid and _valid_uv(actor)
		var facial: Dictionary=actor.presentation_snapshot().facial
		corresponding=corresponding and _atlas_matches(actor,frames.get(str(facial.frame),{}))
	_check(seen.size()>1,"native eye atlas changes during a live idle rather than staying frozen")
	_check(valid,"all sampled eye/mouth atlas rectangles stay inside the source texture")
	_check(corresponding,"both eyes and mouth keep their own source cell on every blink frame")
	diagnostics.idleFacialVariants=seen.size()
	actor.free()

func _atlas_matches(actor, frame: Dictionary) -> bool:
	if frame.is_empty(): return false
	var materials:=_face_materials(actor)
	for key: String in materials:
		var lower:=key.to_lower()
		var role: String="mouth" if "mouth" in lower else "eyeL" if "eye_l" in lower else "eyeR"
		var expected: Vector2=Vector2(frame[role][0],frame[role][1])
		if not Vector2(materials[key].get_shader_parameter("uv_offset")).is_equal_approx(expected): return false
	return true

func _secondary_helper_contract() -> void:
	var Helper=load("res://scripts/secondary_motion.gd")
	var actor=_spawn("azure_empyrea","taixu_memory",true)
	var helper=Helper.new()
	_check(helper.setup(actor.skeleton),"secondary helper recognizes the real skin skeleton")
	_check(helper.snapshot().boneCount==66 and helper.snapshot().chainCount==14,"secondary whitelist resolves all 66 bones in 14 original chains")
	var body_unchanged:=true
	var stable_length:=true
	var stable_scale:=true
	var source_pose:=_pose(actor)
	for frame in 90:
		helper.restore_base_pose()
		var at:=float(frame+1)*STEP
		actor.animate_fighter(_fighter("move",at,-1.0 if frame>45 else 1.0),STEP,at)
		var before:=_pose(actor)
		helper.update(STEP,{"state":"move","facing":-1.0 if frame>45 else 1.0,"x":sin(at)*2.0})
		var after:=_pose(actor)
		for index in before.size():
			if not _auxiliary(actor.skeleton.get_bone_name(index)):
				body_unchanged=body_unchanged and _poses_close([before[index]],[after[index]])
			stable_length=stable_length and before[index].origin.is_equal_approx(after[index].origin)
			stable_scale=stable_scale and before[index].basis.get_scale().is_equal_approx(after[index].basis.get_scale())
	_check(body_unchanged and stable_length and stable_scale,"helper only changes allowed rotations, never body, bone length or scale")
	var frozen: Dictionary=helper.snapshot()
	var pose:=_pose(actor)
	for ignored in 90: helper.update(0.0,{"state":"attack","facing":1.0,"x":1000.0})
	_check(helper.snapshot()==frozen and _poses_close(pose,_pose(actor)),"repeated zero delta never accumulates spring or turn/teleport input")
	helper.restore_base_pose()
	var restored:=_pose(actor)
	helper.restore_base_pose()
	_check(_poses_close(restored,_pose(actor)),"restoring unanimated auxiliary bones is idempotent")
	helper.update(STEP,{"state":"move","facing":1.0,"x":50.0,"teleport":true})
	_check(_finite(actor) and float(helper.snapshot().maxAngle)<=0.2001,"teleport clears inertia instead of whipping cloth across the body")
	helper.update(0.5,{"state":"idle","facing":1.0,"x":50.0})
	_check(_finite(actor) and float(helper.snapshot().maxAngle)<=0.2001,"large frame gaps keep auxiliary angles bounded")
	helper.reset()
	var reset: Dictionary=helper.snapshot()
	_check(reset.time==0.0 and reset.maxAngle==0.0 and reset.maxSpeed==0.0,"secondary reset removes both displacement and stored velocity")
	var all_rest:=true
	for index in actor.skeleton.get_bone_count():
		if _auxiliary(actor.skeleton.get_bone_name(index)):
			all_rest=all_rest and _poses_close([actor.skeleton.get_bone_pose(index)],[source_pose[index]])
	_check(all_rest,"secondary reset restores all native skin helper rest rotations")
	actor.free()
	for ids: Array in [["azure_empyrea","default"],["fenghuang","default"]]:
		var original=_spawn(str(ids[0]),str(ids[1]))
		var inactive=Helper.new()
		_check(not inactive.setup(original.skeleton) and not inactive.snapshot().enabled,"skin helper rejects unrelated original skeleton "+str(ids[0]))
		original.free()

func _facial_helper_contract() -> void:
	var Facial=load("res://scripts/facial_motion.gd")
	var helper=Facial.new()
	var materials: Dictionary={}
	for role: String in ["eyeR","eyeL","mouth"]:
		var material:=ShaderMaterial.new()
		material.shader=load("res://shaders/character.gdshader")
		helper.register_material("Eye_L" if role=="eyeL" else "Eye_R" if role=="eyeR" else "Mouth",material)
		materials[role]=material
	_check(helper.setup("res://assets/motions/fuhua-face-atlas.json"),"native facial catalog resolves three separately registered roles")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/fuhua-face-atlas.json"))
	var clock:=0.0
	for cue: Array in [[2.22,"halfBlink"],[2.26,"closed"],[2.34,"halfBlink"],[2.40,"neutral"]]:
		helper.update(float(cue[0])-clock,{"motion":"idle","clock":cue[0]})
		clock=float(cue[0])
		var snapshot: Dictionary=helper.snapshot()
		_check(snapshot.frame==cue[1],"idle blink selects the intended discrete cell at %.2f" % clock)
		var matches:=true
		for role: String in materials:
			var uv: Array=catalog.frames[str(cue[1])][role]
			matches=matches and materials[role].get_shader_parameter("uv_offset")==Vector2(uv[0],uv[1])
		_check(matches,"blink keeps left/right eyes distinct and mouth neutral at %.2f" % clock)
		helper.update(0.0,{"motion":"idle","clock":1000.0})
		_check(snapshot==helper.snapshot(),"blink clock ignores wall time during zero-delta freeze %.2f" % clock)
	helper.update(0.0,{"motion":"guard","clock":0.0})
	_check(helper.snapshot().frame=="focused","guard can set its expression immediately on a zero-delta contact frame")
	helper.update(0.0,{"motion":"stagger","clock":0.0,"duration":0.4})
	_check(helper.snapshot().frame in ["closed","hurt"],"first hitstop frame receives the hurt expression")
	for cue: Array in [[2.17,"halfBlink"],[2.21,"closed"],[2.29,"halfBlink"]]:
		helper.animate_victory(float(cue[0]))
		var frozen: Dictionary=helper.snapshot()
		helper.animate_victory(float(cue[0]))
		_check(frozen.frame==cue[1] and frozen==helper.snapshot(),"victory uses deterministic original atlas cells at %.2f" % float(cue[0]))
		_check(frozen.mouth==catalog.frames.smile.mouth,"victory blink preserves its smile independently of the eyes")
	helper.animate_victory(0.0)
	_check(helper.snapshot().frame=="neutral" and helper.snapshot().clock==0.0,"victory rewind returns the opening expression without stale blink")
	helper.reset()
	_check(helper.snapshot().frame=="neutral" and helper.snapshot().clock==0.0 and not helper.snapshot().blink,"facial reset restores neutral eyes and mouth")

func _main_contract() -> void:
	var world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free()
	world.music.free()
	world.music=QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	world._action("practice")
	world.game.set_training(true)
	world.touch_move=1.0
	for ignored in 12: world._process(STEP)
	world._action("pause")
	world._process(0.0)
	var pose:=_pose(world.player)
	var face:=_face_uv(world.player)
	var snapshot: Dictionary=world.player.presentation_snapshot()
	for ignored in 30: world._process(STEP)
	_check(world.game.paused and _poses_close(pose,_pose(world.player)) and face==_face_uv(world.player) and snapshot==world.player.presentation_snapshot(),"real main pause freezes the skin while UI frames continue")
	world._action("pause")
	world.touch_move=0.0
	for ignored in 12: world._process(STEP)
	var time_before: float=world.visual_time
	world.game.hit_stop=0.12
	world._process(0.0)
	pose=_pose(world.player)
	face=_face_uv(world.player)
	snapshot=world.player.presentation_snapshot()
	for ignored in 4: world._process(STEP)
	_check(world.visual_time>time_before and _poses_close(pose,_pose(world.player)) and face==_face_uv(world.player) and snapshot==world.player.presentation_snapshot(),"real main hitstop cannot advance cloth or blinking through visual_time")
	world._action("menu")
	var old_actor=world.player
	world._action("select_appearance:default")
	_check(world.player!=old_actor and not old_actor.visible and world.fighter.appearanceId=="default","menu skin selection replaces the actor instead of retaining old runtime state")
	world._action("select_style:fenghuang")
	_check(world.fighter.styleId=="fenghuang" and world.player.ready_for_combat,"original C4 still loads through real menu selection")
	world._action("select_style:azure_empyrea")
	world._action("select_appearance:taixu_memory")
	var fresh=_spawn("azure_empyrea","taixu_memory")
	_check(_poses_close(_pose(world.player),_pose(fresh)) and _face_uv(world.player)==_face_uv(fresh),"returning to the skin starts with a fresh pose and face material")
	fresh.free()
	world._action("practice")
	world.game.set_training(true)
	for foe in world.game.enemies: foe.hp=0.0
	world.game._check_end()
	for ignored in 35: world._process(0.05)
	_check(world.victory.visible,"real final result enters skin victory")
	world._action("victory_pause")
	pose=_pose(world.player)
	face=_face_uv(world.player)
	for ignored in 12: world._process(STEP)
	_check(_poses_close(pose,_pose(world.player)) and face==_face_uv(world.player),"result pause freezes skin cloth and native expression")
	world._action("victory_replay")
	world._process(0.0)
	pose=_pose(world.player)
	face=_face_uv(world.player)
	for ignored in 30: world._process(STEP)
	world._action("victory_replay")
	world._process(0.0)
	_check(_poses_close(pose,_pose(world.player)) and face==_face_uv(world.player),"result replay clears secondary inertia and returns the first native expression")
	world.free()
	await process_frame
