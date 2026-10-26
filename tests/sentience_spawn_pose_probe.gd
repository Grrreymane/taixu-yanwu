extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const Profile = preload("res://scripts/sentience_profile.gd")
const Bounds = preload("res://scripts/model_bounds.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.setup(false,Profile.selection())
	var rows: Array = []
	for state:String in ["idle","intro"]:
		for t:float in [0.0,0.5,1.0,1.5,2.0]:
			actor.reset_presentation()
			actor.animate_fighter({"state":state,"stateTime":t,"x":0.0,"facing":1,"side":"enemy","hp":100.0},.1,t)
			var measure:Dictionary = Bounds.measure(actor.model,actor.skeleton,actor._visual.get("hiddenSurfaces",[]))
			var bounds:AABB = measure.bounds
			var bottom:Vector3=actor.model.global_transform*bounds.position
			var top:Vector3=actor.model.global_transform*(bounds.position+Vector3.UP*bounds.size.y)
			var head:Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor._head_bone).origin
			var feet:Array=[]
			for index:int in actor._feet:
				feet.append((actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(index).origin).y)
			rows.append({"state":state,"time":t,"clip":actor._motions[state].clip,"bottomY":bottom.y,"topY":top.y,"headY":head.y,"footBonesY":feet,"rootY":actor.position.y,"pivotY":actor._pivot.position.y})
	var report:Dictionary={"gpu":false,"bodyBonesEdited":false,"poses":rows}
	FileAccess.open("res://build/reports/sentience-spawn-pose.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	actor.free()
	await process_frame
	quit()
