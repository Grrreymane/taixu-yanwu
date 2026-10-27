extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := Node3D.new()
	actor.set_script(load("res://scripts/actor.gd"))
	viewport.add_child(actor)
	actor.setup(false)
	actor.animate_fighter({"state":"idle","stateTime":0.2,"x":0.0,"facing":1.0}, 0.2, 0.2)
	actor.rotation.y = 0.0
	actor._update_face_vectors()
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.0, 2.50, 2.1)
	camera.look_at(Vector3(0.035, 2.48, 0.45))
	camera.fov = 24.0
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.35, 0.45, 0.52)
	world.environment = environment
	viewport.add_child(world)
	for i in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var output := viewport.get_texture().get_image()
	var error := output.save_png("res://build/screenshots/eyes-closeup.png")
	print("EYE_VISUAL_CHECK image=",output.get_width(),"x",output.get_height()," save_error=",error)
	quit(error)
