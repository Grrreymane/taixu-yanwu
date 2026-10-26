extends SceneTree
const Actor := preload("res://scripts/actor.gd")
const Roster := preload("res://scripts/fighter_roster.gd")
var checks:=0
var failures:Array[String]=[]
var evidence:=[]

func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fighter(state:String,t:float,facing:float) -> Dictionary:
	return {"state":state,"stateTime":t,"stateDuration":0.38,"facing":facing,"x":0.0,"side":"player"}
func world(a,bone:String) -> Vector3:
	return a.skeleton.global_transform*a.skeleton.get_bone_global_pose(a.skeleton.find_bone(bone)).origin
func pose(a) -> Array:
	var result:=[]
	for b in a.skeleton.get_bone_count():result.append(a.skeleton.get_bone_pose(b))
	return result

func run() -> void:
	for selection in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		var a:=Actor.new();var native:=Actor.new();root.add_child(a);root.add_child(native)
		var config:=Roster.resolve("fuhua",selection[0],selection[1]);a.setup(false,config);native.setup(false,config)
		var label:String=selection[0]+"/"+selection[1]
		check(a.ready_for_combat,label+" ready")
		for facing:float in [-1.0,1.0]:
			var light_shift:=0.0;var heavy_shift:=0.0
			for entry in [["hit",false],["hit",true],["block",false],["block",true],["parry",true]]:
				var kind:String=entry[0];var strong:bool=entry[1];var state:="stagger" if kind=="hit" else "guard"
				var tag:=label+" "+kind+" strong="+str(strong)+" facing="+str(facing)
				for target in [a,native]:
					target.reset_presentation();target.animate_fighter(fighter("guard" if state=="guard" else "idle",0.1,facing),0.1,0.1)
				var head_before:=world(a,"Bip001 Head");var feet_before:=[world(a,"Bip001 L Foot"),world(a,"Bip001 R Foot")]
				a.react_impact(kind,-facing,strong)
				check(float(a.presentation_snapshot().impactBodyAngle)>0.01,tag+" immediate bone response before another simulation step")
				check(world(a,"Bip001 L Foot")==feet_before[0] and world(a,"Bip001 R Foot")==feet_before[1],tag+" immediate impact cannot move either planted foot")
				check((world(a,"Bip001 Head").x-head_before.x)*(-facing)>0.0005,tag+" immediate upper-body impulse follows world force")
				native.react_impact(kind,-facing,strong)
				for target in [a,native]:target.animate_fighter(fighter(state,0.0,facing),0.0,0.0)
				native._restore_impact_pose() # Native clip/guard pose is the independent no-reaction control.
				var shift:float=(world(a,"Bip001 Head").x-world(native,"Bip001 Head").x)*(-facing)
				check(shift>0.0005,tag+" upper body moves away from the incoming strike on its first held pose")
				check(a._pivot.position==a._pivot_origin and a._pivot.rotation==Vector3.ZERO,tag+" no whole-model rubber translation or lean")
				var unchanged:=true
				for i in a.skeleton.get_bone_count():
					unchanged=unchanged and a.skeleton.get_bone_pose_position(i)==native.skeleton.get_bone_pose_position(i) and a.skeleton.get_bone_pose_scale(i)==native.skeleton.get_bone_pose_scale(i)
				check(unchanged,tag+" all local bone positions/scales and therefore bone lengths remain native")
				for bone in ["Bip001","Bip001 L Thigh","Bip001 R Thigh","Bip001 L Calf","Bip001 R Calf","Bip001 L Foot","Bip001 R Foot"]:
					check(world(a,bone).is_equal_approx(world(native,bone)),tag+" lower body untouched: "+bone)
				if kind=="hit":
					if strong:heavy_shift=shift
					else:light_shift=shift
					var first_pose:=pose(a)
					for repeat in 24:
						a.react_impact(kind,-facing,strong);a.animate_fighter(fighter(state,0.0,facing),0.0,0.0)
					check(first_pose==pose(a),tag+" repeated stagger contacts at time zero never compound the bone overlay")
				var previous_angle:float=a.presentation_snapshot().impactBodyAngle
				a.animate_fighter(fighter(state,0.04,facing),0.04,0.04)
				check(float(a.presentation_snapshot().impactBodyAngle)<previous_angle,tag+" response decays on simulation time")
				var frozen:=pose(a);var snapshot:Dictionary=a.presentation_snapshot()
				for pause_frame in 120:a.animate_fighter(fighter(state,0.04,facing),0.0,30.0+pause_frame)
				check(frozen==pose(a) and snapshot==a.presentation_snapshot(),tag+" hitstop and pause freeze bones, secondary cloth and facial state")
				var attack:=fighter("attack",0.0,facing);attack.attack={"name":"light","comboIndex":0,"duration":0.46,"windup":0.16}
				a.animate_fighter(attack,0.0,0.0)
				check(is_zero_approx(float(a.presentation_snapshot().impactBodyAngle)) and is_zero_approx(float(a.presentation_snapshot().recoil)),tag+" accepted attack immediately clears old impact")
				a.animate_fighter(attack,0.045,0.045);attack.stateTime=0.16;a.animate_fighter(attack,0.115,0.16)
				check(is_equal_approx(a.source_time,float(a._motions.light1.contact)),tag+" native attack contact stays aligned after interruption")
				evidence.append({"selection":label,"facing":facing,"kind":kind,"strong":strong,"headShiftWithForce":shift,"reactionDuration":snapshot.impactDuration})
			check(heavy_shift>light_shift*1.45,label+" facing="+str(facing)+" heavy contact is visibly stronger than light")
			a.reset_presentation();var reset:Dictionary=a.presentation_snapshot()
			check(is_zero_approx(float(reset.impactBodyAngle)) and a._impact_pose_base.is_empty(),label+" reset clears all additive body rotations")
			a.animate_victory(0.0);var victory_pose:=pose(a);a.animate_victory(0.0)
			check(victory_pose==pose(a),label+" victory zero-time pose is stable after impact reset")
		a.queue_free();native.queue_free();await process_frame
	var report:={"suite":"actor_impact_response","checks":checks,"failures":failures,"passed":failures.is_empty(),"evidence":evidence,"scope":"All three current model selections, both directions, native clips/contact times unchanged. Headless geometry/clock checks; visual acceptance still required."}
	FileAccess.open("res://build/reports/actor-impact-response.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ACTOR IMPACT RESPONSE ",checks-failures.size(),"/",checks);quit(0 if failures.is_empty() else 1)
