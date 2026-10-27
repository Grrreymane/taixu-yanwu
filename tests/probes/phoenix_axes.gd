extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var actor=load("res://scripts/actor.gd").new()
	root.add_child(actor)
	actor.setup(false,load("res://scripts/fighter_roster.gd").resolve("fuhua","fenghuang"))
	actor.rotation.y=1.1
	for node in [actor.model,actor.skeleton,actor._pivot]: print(node.name," local=",node.transform," global=",node.global_transform)
	for clip in ["JW_A1","JW_A2","JW_A3","JW_B1","JW_B2","JW_B3","JW_C1_1","JW_C2_1","JW_C3_1","JW_A4","JW_A5","JW_C3_2"]:
		actor.animation_player.play("Avatar_Fuka_Ani_"+clip)
		for t in [0.15,0.25,0.35,0.45]:
			actor.animation_player.seek(t,true)
			actor.animation_player.advance(0)
			var pos=actor.skeleton.get_bone_pose_position(actor._root_bone)
			pos.x=actor._root_origin.x
			pos.z=actor._root_origin.z
			actor.skeleton.set_bone_pose_position(actor._root_bone,pos)
			var pelvis=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor._root_bone).origin
			var points={}
			for bone in ["Bip001 L Hand","Bip001 R Hand","Bip001 L Foot","Bip001 R Foot"]:
				points[bone]=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)).origin-pelvis
			print(clip," ",t," ",points)
	actor.queue_free()
	await process_frame
	quit()
