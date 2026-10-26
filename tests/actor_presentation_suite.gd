extends SceneTree

const Actor = preload("res://scripts/actor.gd")
const Defense = preload("res://scripts/defense_motion.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _fighter(state: String, clock: float, facing: float = 1.0) -> Dictionary:
	return {"state": state, "stateTime": clock, "stateDuration": 0.32, "facing": facing, "x": 0.0}

func _point(actor, bone: String) -> Vector3:
	return actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)).origin

func _world_point(actor, bone: String) -> Vector3:
	return actor.skeleton.global_transform * _point(actor,bone)

func _floor(actor) -> float:
	return minf(_world_point(actor,"Bip001 L Foot").y,_world_point(actor,"Bip001 R Foot").y)

func _pose(actor) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in actor.skeleton.get_bone_count():
		result.append(actor.skeleton.get_bone_pose(i))
	return result

func _run() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup()
	_check(actor.ready_for_combat, "original model and animations load")
	for facing in [-1.0, 1.0]:
		actor.animate_fighter(_fighter("idle", 0.0, facing), 0.0, 0.0)
		var root_world: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001")
		var head_world: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001 Head")
		print("CENTER facing=", facing, " actorX=", actor.position.x, " root=", root_world, " head=", head_world)
		_check(absf(root_world.x - actor.position.x) < 0.0001 and absf(root_world.z) < 0.0001, "pelvis stays centered for facing " + str(facing))
		_check(absf(head_world.x - actor.position.x) < 0.10, "idle head is close to logical center for facing " + str(facing))
		var key_light: Vector3 = actor.materials[0].get_shader_parameter("key_direction")
		_check(key_light.x * facing > 0.0 and key_light.y > 0.0 and key_light.z > 0.0, "key light stays on front and camera side for facing " + str(facing))
	var idle_head := _point(actor, "Bip001 Head")
	actor.animate_fighter(_fighter("guard", 0.05), 0.05, 0.05)
	_check(is_equal_approx(actor.presentation_snapshot().guardWeight, 0.5), "guard has visible enter transition")
	actor.animate_fighter(_fighter("guard", 0.10), 0.05, 0.10)
	var head := _point(actor, "Bip001 Head")
	var left := _point(actor, "Bip001 L Hand")
	var right := _point(actor, "Bip001 R Hand")
	print("GUARD head=", head, " left=", left, " right=", right)
	_check(is_equal_approx(actor.presentation_snapshot().guardWeight, 1.0), "guard reaches full pose in 100ms")
	_check(head.y < idle_head.y - 0.15 and head.y > idle_head.y - 0.65, "native guard lowers the torso into a controlled boxing stance")
	var guard_head_world := _world_point(actor,"Bip001 Head")
	for side in ["L","R"]:
		var hand_world := _world_point(actor,"Bip001 "+side+" Hand")
		_check(hand_world.y > guard_head_world.y-0.38 and hand_world.y < guard_head_world.y+0.12, side+" wrist remains in the upper-body defense band")
		_check(hand_world.distance_to(guard_head_world)>0.22 and hand_world.distance_to(guard_head_world)<0.68, side+" fist has visible clearance from the head")
	for facing in [-1.0, 1.0]:
		actor.animate_fighter(_fighter("guard", 0.1, facing), 0.0, 0.1)
		var world_head: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001 Head")
		for side in ["L", "R"]:
			var world_hand: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001 " + side + " Hand")
			_check((world_hand.x - world_head.x) * facing > 0.25, side + " hand guards toward facing " + str(facing))
	for kind in ["block", "parry"]:
		actor.react_impact(kind, -1.0, false)
		actor.animate_fighter(_fighter("guard", 0.10), 0.0, 0.10)
		var before: Dictionary = actor.presentation_snapshot()
		var pose_before := _pose(actor)
		var pivot_before: Transform3D = actor._pivot.transform
		_check(before.recoil > 0.5, kind + " reacts immediately with zero simulation delta")
		_check(is_equal_approx(before.guardWeight, 1.0), kind + " retains guard")
		for ignored in range(5):
			actor.animate_fighter(_fighter("guard", 0.10), 0.0, 0.10)
		_check(before == actor.presentation_snapshot(), kind + " presentation clocks freeze during hitstop")
		_check(pose_before == _pose(actor), kind + " bones freeze during hitstop")
		_check(pivot_before == actor._pivot.transform, kind + " recoil transform freezes during hitstop")
		actor.animate_fighter(_fighter("guard", 0.15), 0.05, 0.15)
		_check(actor.presentation_snapshot().recoil < before.recoil, kind + " recoil recovers after hitstop")
	actor.animate_fighter(_fighter("idle", 0.0), 0.3, 0.0)
	actor.animate_fighter(_fighter("idle", 0.15), 0.15, 0.15)
	_check(is_zero_approx(actor.presentation_snapshot().guardWeight), "guard releases completely")
	_check(actor.presentation_snapshot().defensePhase=="none" and actor.presentation_snapshot().defenseClip=="", "released guard clears the source motion overlay")
	actor.reset_presentation()
	actor.react_impact("hit", -1.0, true)
	actor.animate_fighter(_fighter("stagger", 0.0), 0.0, 0.0)
	var contact: Dictionary = actor.presentation_snapshot()
	_check(contact.motion == "stagger" and contact.sourceTime >= 0.08, "stagger begins at native contact pose immediately")
	_check(contact.recoil > 1.0, "strong contact has stronger immediate recoil")
	_check(_point(actor, "Bip001 Head").y < idle_head.y - 0.20, "stagger contact visibly bends away from the original upright idle")
	var contact_pose := _pose(actor)
	for ignored in range(5):
		actor.animate_fighter(_fighter("stagger", 0.0), 0.0, 0.0)
	_check(contact_pose == _pose(actor), "hitstop freezes first contact bone pose")
	actor.animate_fighter(_fighter("stagger", 0.31), 0.31, 0.31)
	_check(actor.presentation_snapshot().sourceTime > 1.20, "native recovery fits combat stun duration")
	actor.flash()
	actor.reset_presentation()
	var reset: Dictionary = actor.presentation_snapshot()
	_check(reset.motion == "idle" and is_zero_approx(reset.sourceTime), "reset returns idle at origin time")
	_check(is_zero_approx(reset.guardWeight) and is_zero_approx(reset.recoil) and is_zero_approx(reset.flash), "reset clears guard recoil and flash")
	_check(actor._pivot.rotation.is_zero_approx(), "reset clears recoil rotation")
	_check(actor._previous_pose.is_empty(), "reset clears blend history")
	actor.animate_fighter(_fighter("guard", 0.04), 0.04, 0.04)
	var entering: Dictionary = actor.presentation_snapshot()
	var entering_pose := _pose(actor)
	actor.animate_fighter(_fighter("guard", 0.04), 0.0, 0.04)
	_check(entering == actor.presentation_snapshot() and entering_pose == _pose(actor), "pause freezes guard enter transition")
	actor.animate_fighter(_fighter("guard", 0.1), 0.06, 0.1)
	var floor_before: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001 L Foot")
	actor.react_impact("block", -1.0)
	var floor_after: Vector3 = actor.skeleton.global_transform * _point(actor, "Bip001 L Foot")
	_check(absf(floor_after.y - floor_before.y) < 0.04, "block recoil pivots around floor and keeps feet planted")
	actor.react_impact("parry", -1.0)
	var counter := _fighter("attack", 0.16)
	counter.attack = {"name": "light", "comboIndex": 0, "duration": 0.46, "windup": 0.16}
	actor.animate_fighter(counter, 0.16, 0.16)
	_check(is_zero_approx(actor.presentation_snapshot().guardWeight), "parry guard releases before counterattack contact")
	actor.react_impact("block", -1.0)
	actor.react_impact("hit", -1.0)
	_check(is_zero_approx(actor.presentation_snapshot().guardWeight), "unblocked hit does not retain old guard overlay")
	_check_native_defense(actor)
	_check_attack_pacing(actor)
	actor.queue_free()
	await process_frame
	print("ACTOR PRESENTATION: ", checks - failures.size(), "/", checks, " checks passed")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(false)
		await _capture(true)
	quit(0 if failures.is_empty() else 1)

func _check_native_defense(actor) -> void:
	var clip_names := Defense.LIBRARY.get_animation_list()
	_check(clip_names.size()==2 and Defense.LIBRARY.has_animation("Attack_ParryAid_L") and Defense.LIBRARY.has_animation("Attack_ParryAid_H"),"runtime defense resource contains only the two used L/H clips")
	for clip_name in clip_names:
		var clip: Animation=Defense.LIBRARY.get_animation(clip_name)
		var rotation_count := 0
		var position_count := 0
		var tracks_valid := true
		for track in clip.get_track_count():
			var bone_name := str(clip.track_get_path(track).get_subname(0))
			tracks_valid=tracks_valid and actor.skeleton.find_bone(bone_name)>=0 and clip.track_get_key_count(track)>0
			if clip.track_get_type(track)==Animation.TYPE_ROTATION_3D: rotation_count+=1
			elif clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
				position_count+=1
				tracks_valid=tracks_valid and bone_name=="Bip001"
			else: tracks_valid=false
		_check(tracks_valid and rotation_count==53 and position_count==1,str(clip_name)+" maps 53 body rotations and only the grounded root position")
	var limb_pairs: Array = [["L UpperArm","L Forearm"],["L Forearm","L Hand"],["R UpperArm","R Forearm"],["R Forearm","R Hand"],["L Thigh","L Calf"],["L Calf","L Foot"],["R Thigh","R Calf"],["R Calf","R Foot"]]
	for facing in [-1.0,1.0]:
		actor.reset_presentation()
		actor.animate_fighter(_fighter("idle",0.0,facing),0.0,0.0)
		var floor_y := _floor(actor)
		var lengths: Array[float]=[]
		for pair in limb_pairs:
			lengths.append(_world_point(actor,"Bip001 "+pair[0]).distance_to(_world_point(actor,"Bip001 "+pair[1])))
		actor.animate_fighter(_fighter("guard",0.04,facing),0.04,0.04)
		var enter: Dictionary=actor.presentation_snapshot()
		_check(enter.defensePhase=="enter" and enter.defenseClip=="Attack_ParryAid_H" and enter.defenseWeight>0.0 and enter.defenseWeight<1.0,"native H enters progressively / "+str(facing))
		actor.animate_fighter(_fighter("guard",0.12,facing),0.08,0.12)
		var hold: Dictionary=actor.presentation_snapshot()
		_check(hold.defensePhase=="hold" and hold.defenseClip=="Attack_ParryAid_H" and hold.defenseTime>=0.018 and hold.defenseTime<=0.0341,"held guard stays within H's opening stance / "+str(facing))
		_check(absf(_floor(actor)-floor_y)<0.04,"guard keeps a supporting foot on the native floor / "+str(facing))
		for entry in [["block",false,0.035,0.14],["block",true,0.035,0.23],["parry",false,0.0,0.32]]:
			actor.reset_presentation()
			actor.animate_fighter(_fighter("guard",0.10,facing),0.10,0.10)
			var kind: String=entry[0]
			var strong: bool=entry[1]
			var expected_clip := "Attack_ParryAid_L" if kind=="parry" else "Attack_ParryAid_H"
			var label := kind+" strong="+str(strong)+" facing="+str(facing)
			actor.react_impact(kind,-facing,strong)
			actor.animate_fighter(_fighter("guard",0.10,facing),0.0,0.10)
			var contact: Dictionary=actor.presentation_snapshot()
			_check(contact.defensePhase==kind and contact.defenseClip==expected_clip and is_equal_approx(contact.defenseTime,float(entry[2])),label+" starts the correct source section on contact")
			var previous_time: float=contact.defenseTime
			for step_index in 4:
				var clock := 0.10+float(step_index+1)*0.04
				actor.animate_fighter(_fighter("guard",clock,facing),0.04,clock)
				var sample: Dictionary=actor.presentation_snapshot()
				_check(sample.defenseClip==expected_clip and sample.defenseTime>=previous_time and sample.defenseTime<=float(entry[3])+0.0001,label+" source time advances within the intended trim")
				previous_time=sample.defenseTime
				_check(absf(_floor(actor)-floor_y)<0.04,label+" maintains a planted supporting foot")
				var lengths_preserved := true
				for i in limb_pairs.size():
					var pair: Array=limb_pairs[i]
					var length := _world_point(actor,"Bip001 "+pair[0]).distance_to(_world_point(actor,"Bip001 "+pair[1]))
					lengths_preserved=lengths_preserved and absf(length-lengths[i])<0.002
				_check(lengths_preserved,label+" retains Fu Hua's arm and leg lengths")
				var root_world := _world_point(actor,"Bip001")
				_check(absf(root_world.x-actor.position.x)<0.10 and absf(root_world.z)<0.10,label+" cannot inherit Lighter's multi-meter root travel")
			var frozen: Dictionary=actor.presentation_snapshot()
			var frozen_pose := _pose(actor)
			var frozen_pivot: Transform3D=actor._pivot.transform
			for pause_frame in 120:
				actor.animate_fighter(_fighter("guard",0.26,facing),0.0,10.0+float(pause_frame))
			_check(frozen==actor.presentation_snapshot() and frozen_pose==_pose(actor) and frozen_pivot==actor._pivot.transform,label+" pause and hitstop do not accumulate bone or cloth drift")
			actor.animate_fighter(_fighter("guard",0.28,facing),0.02,0.28)
			_check(actor.presentation_snapshot().impactAge>frozen.impactAge,label+" resumes on the simulation clock")
			if kind=="block":
				actor.react_impact("block",-facing,strong)
				actor.animate_fighter(_fighter("guard",0.28,facing),0.0,0.28)
				var restart: Dictionary=actor.presentation_snapshot()
				_check(restart.defensePhase=="block" and is_zero_approx(restart.impactAge) and is_equal_approx(restart.defenseTime,0.035),label+" repeated contact restarts the block motion")
			for command in ["light","heavy"]:
				actor.react_impact(kind,-facing,strong)
				var attack := _fighter("attack",0.0,facing)
				attack.attack={"name":command,"comboIndex":0,"duration":0.46 if command=="light" else 0.88,"windup":0.16 if command=="light" else 0.5}
				actor.animate_fighter(attack,0.0,0.0)
				var interrupted: Dictionary=actor.presentation_snapshot()
				_check(interrupted.defensePhase=="none" and interrupted.defenseClip=="" and is_zero_approx(interrupted.guardWeight),label+" J/K attack immediately owns the body: "+command)
		# Releasing L after a contact must finish with no residual overlay, including
		# when the incoming delta crosses the end of the reaction in one update.
		for kind in ["none","block","parry"]:
			actor.reset_presentation()
			actor.animate_fighter(_fighter("guard",0.10,facing),0.10,0.10)
			if kind!="none": actor.react_impact(kind,-facing)
			for i in 72:
				actor.animate_fighter(_fighter("idle",float(i+1)/120.0,facing),1.0/120.0,float(i+1)/120.0)
			var released: Dictionary=actor.presentation_snapshot()
			_check(is_zero_approx(released.guardWeight) and released.defensePhase=="none" and released.defenseClip=="","guard release leaves no pose after "+kind+" / "+str(facing))

func _check_attack_pacing(actor) -> void:
	for entry in [["light1", 0.16, 0.46, 0.22], ["light2", 0.13, 0.42, 0.15], ["light3", 0.40, 0.72, 0.95], ["heavy", 0.50, 0.88, 0.83], ["ability", 0.68, 1.18, 0.65]]:
		var key: String = entry[0]
		var windup: float = entry[1]
		var duration: float = entry[2]
		var contact: float = entry[3]
		var end_time: float = Actor.MOTIONS[key].end
		var f := {"side": "player", "attack": {"windup": windup, "duration": duration}}
		_check(is_equal_approx(actor._sample_time(key, f, windup), contact), key + " native contact alignment")
		_check(is_zero_approx(actor._sample_time(key, f, 0.0)) and is_equal_approx(actor._sample_time(key, f, duration), end_time), key + " preserves source start and recovery end")
		var monotone := true
		var bounded := true
		var previous := -1.0
		for frame in range(241):
			var sampled: float = actor._sample_time(key, f, duration * frame / 240.0)
			monotone = monotone and sampled >= previous - 0.000001
			bounded = bounded and sampled >= 0.0 and sampled <= end_time
			previous = sampled
		_check(monotone and bounded, key + " source progression never reverses or leaves the clip")
		_check(absf(actor._sample_time(key, f, windup - 0.0001) - contact) < 0.002 and absf(actor._sample_time(key, f, windup + 0.0001) - contact) < 0.002, key + " source time is continuous across contact")
		if key in ["light1", "light2"]:
			_check(is_equal_approx(actor._sample_time(key, f, windup * 0.65), contact * 0.65), key + " quick startup remains unchanged")
			continue
		var held_distance: float = actor._sample_time(key, f, windup * 0.70) - actor._sample_time(key, f, windup * 0.50)
		var release_distance: float = actor._sample_time(key, f, windup * 0.97) - actor._sample_time(key, f, windup * 0.77)
		_check(release_distance > held_distance * 2.0, key + " release is faster than held anticipation")
		var enemy := f.duplicate(true)
		enemy.side = "enemy"
		_check(is_equal_approx(actor._sample_time(key, enemy, windup * 0.65), contact * 0.65), key + " enemy warning and startup stay unchanged")
		var state := _fighter("attack", 0.0)
		state.side = "player"
		state.stateDuration = duration
		state.attack = {"name": "light" if key == "light3" else key, "comboIndex": 2 if key == "light3" else 0, "windup": windup, "duration": duration}
		for clock in [windup * 0.55, windup, windup + (duration - windup) * 0.5]:
			actor.reset_presentation()
			state.stateTime = clock
			actor.animate_fighter(state, 0.0, clock)
			actor.animate_fighter(state, 0.10, clock)
			var before: Dictionary = actor.presentation_snapshot()
			var pose_before := _pose(actor)
			for ignored in range(5):
				actor.animate_fighter(state, 0.0, clock)
			_check(before == actor.presentation_snapshot() and pose_before == _pose(actor), key + " pose and source clock freeze at " + str(clock))
			state.stateTime = clock + 0.01
			actor.animate_fighter(state, 0.01, state.stateTime)
			_check(actor.presentation_snapshot().sourceTime > before.sourceTime, key + " resumes after freeze at " + str(clock))

func _capture(hits: bool) -> void:
	root.size = Vector2i(1440, 810)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("dce5e9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 0.7
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	stage.add_child(camera)
	camera.position = Vector3(0, 2.2, 11)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.current = true
	var titles := ["Guard / facing right", "Guard / facing left", "Block contact", "Parry contact"]
	if hits:
		titles = ["Original idle", "Hit contact / right", "Hit contact / left", "Hit recovery"]
	for index in range(4):
		var actor = Actor.new()
		stage.add_child(actor)
		actor.setup()
		var facing := -1.0 if index == 1 and not hits or index == 2 and hits else 1.0
		var f := _fighter("guard" if not hits else "idle", 0.1, facing)
		f.x = (index - 1.5) * 2.0
		actor.animate_fighter(f, 0.1, 0.1)
		if not hits and index >= 2:
			actor.react_impact("block" if index == 2 else "parry", -facing, false)
			actor.animate_fighter(f, 0.0, 0.1)
		if hits and index >= 1:
			actor.react_impact("hit", -facing, true)
			f.state = "stagger"
			f.stateTime = 0.27 if index == 3 else 0.0
			actor.animate_fighter(f, 0.27 if index == 3 else 0.0, f.stateTime)
		var label := Label.new()
		label.text = titles[index]
		label.position = Vector2(index * 360 + 30, 55)
		label.add_theme_color_override("font_color", Color("193044"))
		label.add_theme_font_size_override("font_size", 23)
		stage.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://tests/actor-presentation-" + ("hits" if hits else "guard") + ".png"
	var result := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", result)
	stage.queue_free()
	await process_frame
