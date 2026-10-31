extends SceneTree
## Offline camera data sampled from the original bird skeleton, not hand drawn.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=load("res://assets/vfx/phoenix-native/model/phoenix.scn").instantiate()
	root.add_child(model)
	var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Avatar_Fuka_Ani_JW_Ultra_Phoenix")
	var samples: Array=[]
	for index in 116:
		var time:=minf(1.916667,index/60.0)
		player.seek(time,true)
		skeleton.force_update_all_bone_transforms()
		var anchor: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Dummy_zx")).origin
		var bounds: AABB=preload("res://scripts/model_bounds.gd").measure(model,skeleton,[]).bounds
		var center:=bounds.get_center()
		samples.append({"time":time,"anchor":[anchor.x,anchor.y,anchor.z],"center":[center.x,center.y,center.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
	FileAccess.open("res://assets/vfx/phoenix-native/flight.json",FileAccess.WRITE).store_string(JSON.stringify(samples))
	print("BAKED_PHOENIX_FLIGHT ",samples[30]," ",samples[75])
	model.free()
	quit()
