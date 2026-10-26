extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const Defense = preload("res://scripts/defense_motion.gd")
const OUT := "res://build/screenshots/defense-retarget"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1600,640)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c8d6d5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3
	stage.add_child(camera)
	camera.position = Vector3(0,2.4,15)
	camera.look_at(Vector3(0,1.42,0))
	camera.current = true
	var actors: Array = []
	var labels: Array[Label] = []
	for i in 5:
		var actor = Actor.new()
		stage.add_child(actor)
		actor.setup()
		actors.append(actor)
		var label := Label.new()
		label.position = Vector2(i*320+20,25)
		label.add_theme_font_size_override("font_size",20)
		label.add_theme_color_override("font_color",Color("18313e"))
		root.add_child(label)
		labels.append(label)
	for key in ["Attack_ParryAid_L","Attack_ParryAid_H"]:
		for i in 5:
			var actor = actors[i]
			var t: float = float(i)*0.15 if key!="Idle" and key!="Attack_ParryAid_Start" else float(i)*0.5
			actor.reset_presentation()
			actor.animate_fighter({"state":"idle","stateTime":0.0,"facing":1.0,"x":float(i-2)*2.15},0.0,0.0)
			var motion = Defense.new()
			motion.setup(actor.skeleton)
			motion.apply_pose(actor.skeleton,key,t,1.0)
			actor._update_face_vectors()
			labels[i].text = key.trim_prefix("Attack_")+"  "+str(t)+" s"
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/"+key+".png")
		print("DEFENSE CAPTURE ",key)
	stage.queue_free()
	await process_frame
	quit()
