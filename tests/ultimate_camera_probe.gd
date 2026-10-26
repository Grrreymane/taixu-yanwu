extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const TIMES = [0.15,0.40,0.85,1.25,1.65,1.90,2.35,2.65,3.05]

func _initialize() -> void:
	call_deferred("_run")

func _vector(value: Vector3) -> Array:
	return [snappedf(value.x,0.0001),snappedf(value.y,0.0001),snappedf(value.z,0.0001)]

func _fighter(clock: float) -> Dictionary:
	return {"state":"ultimate","stateTime":clock,"stateDuration":3.3,"facing":1.0,"x":0.0}

func _sample(actor, clock: float) -> void:
	actor.animate_fighter(_fighter(0.0),0.0,0.0,0.0)
	actor.animate_fighter(_fighter(clock),clock,clock,clock)

func _run() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup()
	var rows: Array = []
	for clock in TIMES:
		actor.reset_presentation()
		_sample(actor,clock)
		var row: Dictionary = {"gameTime":clock,"sourceTime":actor.source_time,"positions":{}}
		for bone_name in ["Bip001","Bip001 Head","Bip001 L Hand","Bip001 R Hand"]:
			var local: Vector3 = actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone_name)).origin
			row.positions[bone_name] = _vector(actor.skeleton.global_transform * local)
		var forward: Vector3 = actor.materials[0].get_shader_parameter("face_forward")
		row.faceForward = _vector(forward)
		row.faceYawDegrees = snappedf(rad_to_deg(atan2(forward.x,forward.z)),0.1)
		rows.append(row)
		print(JSON.stringify(row))
	var file := FileAccess.open("res://tests/ultimate-camera-samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"playerX":0,"facing":1,"stateDuration":3.3,"rows":rows},"\t"))
	file.close()
	actor.queue_free()
	if "--capture" in OS.get_cmdline_user_args():
		await _contact_sheet(false)
		await _contact_sheet(true)
	quit()

func _contact_sheet(frontal: bool) -> void:
	var viewports: Array[SubViewport] = []
	for clock in TIMES:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480,400)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("dce5e9")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.8
		stage.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-30,0)
		light.light_energy = 0.7
		stage.add_child(light)
		var actor = Actor.new()
		stage.add_child(actor)
		actor.setup()
		_sample(actor,clock)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.1
		stage.add_child(camera)
		camera.position = Vector3(7,2.4,3.0) if frontal else Vector3(0,2.2,11)
		camera.look_at(Vector3(0,1.55,0))
		camera.current = true
		var label := Label.new()
		label.text = "%.2fs / native %.2fs" % [clock, actor.source_time]
		label.position = Vector2(12,10)
		label.add_theme_color_override("font_color",Color("172e3f"))
		label.add_theme_font_size_override("font_size",20)
		viewport.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var sheet := Image.create(1440,1200,false,Image.FORMAT_RGBA8)
	for index in viewports.size():
		var source := viewports[index].get_texture().get_image()
		sheet.blit_rect(source,Rect2i(0,0,480,400),Vector2i((index%3)*480,(index/3)*400))
		viewports[index].queue_free()
	var path := "res://tests/ultimate-camera-" + ("front-oblique" if frontal else "side") + ".png"
	sheet.save_png(path)
	print("CAPTURE ",path)
	await process_frame
