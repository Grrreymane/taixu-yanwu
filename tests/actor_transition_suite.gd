extends SceneTree

const Actor := preload("res://scripts/actor.gd")
const Roster := preload("res://scripts/fighter_roster.gd")
var checks := 0
var failures: Array[String] = []
var evidence: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func fighter(state: String, time: float, facing: float) -> Dictionary:
	return {"state":state,"stateTime":time,"stateDuration":0.38,"facing":facing,"x":0.0,"side":"player"}

func attack(name: String, facing: float, windup: float = 0.16, motion: String = "") -> Dictionary:
	var f := fighter("attack",0.0,facing)
	f.attack = {"name":name,"comboIndex":0,"duration":0.48,"windup":windup,"parryFollowup":true,"motion":motion}
	return f

func world(a, bone: String) -> Vector3:
	return a.skeleton.global_transform * a.skeleton.get_bone_global_pose(a.skeleton.find_bone(bone)).origin

func floor_y(a) -> float:
	return minf(world(a,"Bip001 L Foot").y,world(a,"Bip001 R Foot").y)

func pose(a) -> Array:
	var result: Array = []
	for i in a.skeleton.get_bone_count():
		result.append(a.skeleton.get_bone_pose(i))
	return result

func body_rotation_error(a, before: Array) -> float:
	var error := 0.0
	for i in a.skeleton.get_bone_count():
		if str(a.skeleton.get_bone_name(i)).begins_with("Bip001"):
			var previous: Quaternion = before[i].basis.orthonormalized().get_rotation_quaternion()
			error = maxf(error,previous.angle_to(a.skeleton.get_bone_pose_rotation(i)))
	return error

func native_lengths(a, native) -> bool:
	for i in a.skeleton.get_bone_count():
		if i != a._root_bone and not a.skeleton.get_bone_pose_position(i).is_equal_approx(native.skeleton.get_bone_pose_position(i)):
			return false
		if not a.skeleton.get_bone_pose_scale(i).is_equal_approx(native.skeleton.get_bone_pose_scale(i)):
			return false
	return true

func assert_frozen(a, f: Dictionary, label: String) -> void:
	var before := pose(a)
	var snapshot: Dictionary = a.presentation_snapshot()
	for ignored in 80:
		a.animate_fighter(f,0.0,100.0+ignored)
	check(before==pose(a) and snapshot==a.presentation_snapshot(),label+" zero-delta bones/transition/cloth/face remain exact")

func prepare_parry(a, facing: float) -> void:
	a.reset_presentation()
	a.animate_fighter(fighter("guard",0.10,facing),0.10,0.10)
	a.react_impact("parry",-facing,false)
	a.animate_fighter(fighter("guard",0.10,facing),0.0,0.10)
	a.animate_fighter(fighter("guard",0.175,facing),0.075,0.175)

func native_sample(a, f: Dictionary) -> void:
	a.reset_presentation()
	a.animate_fighter(f,0.0,0.0)
	# Independent unblended source pose: this reference disables only the
	# presentation blend and preserves all native source-time/root handling.
	a._transition_time=a._transition_length
	a.animate_fighter(f,0.0,0.0)

func run() -> void:
	for selection in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		var a := Actor.new()
		var native := Actor.new()
		root.add_child(a)
		root.add_child(native)
		var config := Roster.resolve("fuhua",selection[0],selection[1])
		a.setup(false,config)
		native.setup(false,config)
		var label: String = selection[0]+"/"+selection[1]
		check(a.ready_for_combat and native.ready_for_combat,label+" both models load")
		for facing: float in [-1.0,1.0]:
			var actions: Array = [attack("light",facing),attack("heavy",facing),attack("ability",facing),attack("light",facing,0.055)]
			if selection[0]=="fenghuang":
				for key in ["counter_punch","counter_kick"]:
					if a._motions.has(key):
						actions.append(attack("light",facing,0.11,key))
			for f: Dictionary in actions:
				var tag := label+" facing="+str(facing)+" "+str(f.attack.name)+"/"+str(f.attack.motion)+" windup="+str(f.attack.windup)
				prepare_parry(a,facing)
				var outgoing := pose(a)
				var old_floor := floor_y(a)
				var old_hands := [world(a,"Bip001 L Hand"),world(a,"Bip001 R Hand")]
				a.animate_fighter(f,0.0,0.0)
				var error := body_rotation_error(a,outgoing)
				var hand_jump := maxf(world(a,"Bip001 L Hand").distance_to(old_hands[0]),world(a,"Bip001 R Hand").distance_to(old_hands[1]))
				check(error<0.0015,tag+" keeps the visible parry body rotations at handoff")
				check(hand_jump<0.004,tag+" handoff wrists have less than 4mm discontinuity")
				check(absf(floor_y(a)-old_floor)<0.0001,tag+" handoff supporting foot stays planted")
				check(a._transition_length>0.02 and a._transition_length<=float(f.attack.windup)*0.65+0.000001,tag+" short blend ends before contact")
				check(a.presentation_snapshot().defensePhase=="none" and is_zero_approx(float(a.presentation_snapshot().impactBodyAngle)),tag+" outgoing reaction is not applied twice over the new action")
				assert_frozen(a,f,tag+" first handoff")
				var duration: float=a._transition_length
				var max_floor_error := 0.0
				for fraction in [0.25,0.5,0.75,1.0]:
					f.stateTime=duration*float(fraction)
					a.animate_fighter(f,duration*0.25,f.stateTime)
					native_sample(native,f)
					var expected := lerpf(old_floor,floor_y(native),smoothstep(0.0,duration,f.stateTime))
					max_floor_error=maxf(max_floor_error,absf(floor_y(a)-expected))
					check(absf(floor_y(a)-expected)<0.0002,tag+" supporting-foot trajectory at "+str(fraction))
					check(native_lengths(a,native),tag+" target limb lengths/scales at "+str(fraction))
					assert_frozen(a,f,tag+" blend "+str(fraction))
				f.stateTime=f.attack.windup
				a.animate_fighter(f,maxf(0.0,float(f.attack.windup)-duration),f.stateTime)
				native_sample(native,f)
				check(is_equal_approx(a.source_time,float(a._motions[a.current_motion].contact)),tag+" exact original contact time")
				check(body_rotation_error(a,pose(native))<0.0015,tag+" contact body equals the unblended native pose")
				check(native_lengths(a,native),tag+" contact bone lengths equal native")
				var pelvis: Vector3=world(a,"Bip001")
				check(absf(pelvis.x-a.position.x)<0.0001 and absf(pelvis.z)<0.0001,tag+" combat pelvis X/Z stay locked")
				evidence.append({"selection":label,"facing":facing,"action":f.attack,"handoffRotationError":error,"handoffHandDistance":hand_jump,"maxSupportingFootError":max_floor_error,"blendSeconds":duration})
				# A frame arriving at contact must not restart the visible blend.
				prepare_parry(a,facing)
				a.animate_fighter(f,0.0,0.0)
				check(body_rotation_error(a,pose(native))<0.0015,tag+" direct contact sample has no late parry blend")

			# Consecutive incoming hits keep the current base pose; the fresh
			# chest impulse is already visible before simulation can advance.
			a.reset_presentation()
			a.animate_fighter(fighter("idle",0.0,facing),0.0,0.0)
			a.react_impact("hit",-facing,false)
			var stun := fighter("stagger",0.0,facing)
			a.animate_fighter(stun,0.0,0.0)
			for repetition in 12:
				stun.stateTime=0.12
				a.animate_fighter(stun,0.12,0.12)
				var pre_impact_head := world(a,"Bip001 Head")
				a.react_impact("hit",-facing,repetition%2==0)
				var hit_pose := pose(a)
				var hit_floor := floor_y(a)
				check((world(a,"Bip001 Head").x-pre_impact_head.x)*(-facing)>0.0001,label+" repeat "+str(repetition)+" immediate new torso impulse")
				stun.stateTime=0.0
				a.animate_fighter(stun,0.0,0.0)
				check(body_rotation_error(a,hit_pose)<0.0015,label+" repeat "+str(repetition)+" no jump back to the static hit start")
				check(absf(floor_y(a)-hit_floor)<0.0002,label+" repeat "+str(repetition)+" supporting foot remains planted")
				check(is_equal_approx(a._transition_length,0.04),label+" repeated hit uses the short body handoff")
				assert_frozen(a,stun,label+" repeated-hit first frame")
				stun.stateTime=0.02
				a.animate_fighter(stun,0.02,0.02)
				assert_frozen(a,stun,label+" repeated-hit halfway")
				native_sample(native,stun)
				check(native_lengths(a,native),label+" repeated-hit lengths/scales unchanged")
			# Extending an existing stagger for a late riposte must not rewind it.
			stun.stateTime=0.21
			a.animate_fighter(stun,0.19,0.21)
			var recovery_source: float=a.source_time
			stun.stateDuration=0.72
			a.animate_fighter(stun,0.0,0.21)
			check(is_equal_approx(a.source_time,recovery_source),label+" late riposte duration extension holds the recovery pose")
			assert_frozen(a,stun,label+" extended recovery")
			stun.stateTime=0.68
			a.animate_fighter(stun,0.47,0.68)
			check(a.source_time>recovery_source,label+" extended stagger eventually resumes native recovery")
			# Recovery and combo handoffs retain visible body posture, then reach
			# the new native pose without changing contact timing.
			var outgoing_stagger := pose(a)
			var idle := fighter("idle",0.0,facing)
			a.animate_fighter(idle,0.0,0.0)
			check(body_rotation_error(a,outgoing_stagger)<0.0015,label+" stagger recovery begins from the seen body pose")
			assert_frozen(a,idle,label+" stagger recovery handoff")
			idle.stateTime=0.10
			a.animate_fighter(idle,0.10,0.10)
			native_sample(native,idle)
			check(body_rotation_error(a,pose(native))<0.0015,label+" stagger recovery reaches idle in 100ms")
			var first := attack("light",facing)
			first.attack.parryFollowup=false
			first.stateTime=0.25
			a.animate_fighter(first,0.25,0.25)
			var first_pose := pose(a)
			var second := attack("light",facing,0.09)
			second.attack.parryFollowup=false
			second.attack.comboIndex=1
			a.animate_fighter(second,0.0,0.0)
			check(body_rotation_error(a,first_pose)<0.0015,label+" light combo handoff is continuous")
			second.stateTime=0.09
			a.animate_fighter(second,0.09,0.09)
			native_sample(native,second)
			check(body_rotation_error(a,pose(native))<0.0015,label+" accelerated next hit reaches native contact")
			if selection[0]=="fenghuang":
				for stance in ["punch","kick"]:
					var counter := attack("heavy",facing,0.19,"counter_"+stance)
					counter.stance=stance
					counter.attack.duration=0.72
					counter.stateTime=0.31
					a.animate_fighter(counter,0.31,0.31)
					var counter_pose := pose(a)
					var followup := attack("light",facing,0.17 if stance=="punch" else 0.29,"light1" if stance=="punch" else "kick_light1")
					followup.stance=stance
					followup.attack.comboIndex=1
					followup.attack.parryFollowup=false
					a.animate_fighter(followup,0.0,0.0)
					check(body_rotation_error(a,counter_pose)<0.0015,label+" "+stance+" counter connects continuously into an alternate native strike")
					assert_frozen(a,followup,label+" counter into alternate "+stance)
					followup.stateTime=followup.attack.windup
					a.animate_fighter(followup,followup.stateTime,followup.stateTime)
					native_sample(native,followup)
					check(body_rotation_error(a,pose(native))<0.0015,label+" "+stance+" alternate counter followup reaches its own contact pose")
					check(native_lengths(a,native),label+" "+stance+" counter followup preserves native bone lengths")
			a.reset_presentation()
			check(a._previous_pose.is_empty() and a._transition_from.is_empty() and is_zero_approx(a._transition_length),label+" reset clears outgoing pose and transition")
		a.queue_free()
		native.queue_free()
		await process_frame
	var report := {"suite":"actor_transitions","checks":checks,"failures":failures,"passed":failures.is_empty(),"evidence":evidence,
		"scope":"Headless pose continuity, original contact, limb lengths, supporting-foot heights and zero-delta clocks for three appearances/two facings. No visual acceptance claim."}
	FileAccess.open("res://build/reports/actor-transitions.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ACTOR TRANSITIONS ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
