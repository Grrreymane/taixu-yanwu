extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Arena=preload("res://scripts/arena.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(420,440)
	var stage=Node3D.new()
	root.add_child(stage)
	stage.add_child(Arena.new())
	var camera=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.position=Vector3(0,1.8,6.7)
	camera.fov=34
	camera.look_at(Vector3(0,1.42,0))
	var actor=Actor.new()
	stage.add_child(actor)
	actor.setup(false,Roster.resolve("fuhua","fenghuang"))
	actor.rotation.y=1.1
	var layer=CanvasLayer.new()
	stage.add_child(layer)
	var label=Label.new()
	layer.add_child(label)
	label.position=Vector2(10,10)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y",2)
	DirAccess.make_dir_recursive_absolute("res://build/screenshots/phoenix-motion")
	for group in [["JW_A1","JW_A2","JW_A3"],["JW_B1","JW_B2","JW_B3"],["JW_C1_1","JW_C2_1","JW_C3_1"],["JW_A4","JW_A5","JW_C3_2"],["JW_Ultra"]]:
		var times=[0.0,0.16,0.32,0.48,0.64,0.84]
		if group[0]=="JW_Ultra": times=[0.0,0.6,1.2,1.9,2.55,3.3]
		var atlas=Image.create(420*6,440*group.size(),false,Image.FORMAT_RGB8)
		for row in group.size():
			var clip=group[row]
			actor.animation_player.play("Avatar_Fuka_Ani_"+clip)
			for col in times.size():
				actor.animation_player.seek(times[col],true)
				actor.animation_player.advance(0.0)
				var p=actor.skeleton.get_bone_pose_position(actor._root_bone)
				p.x=actor._root_origin.x
				p.z=actor._root_origin.z
				actor.skeleton.set_bone_pose_position(actor._root_bone,p)
				actor._update_face_vectors()
				label.text=clip+" / "+str(times[col])+" s"
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var frame=root.get_texture().get_image()
				frame.convert(Image.FORMAT_RGB8)
				atlas.blit_rect(frame,Rect2i(0,0,420,440),Vector2i(col*420,row*440))
		atlas.save_png("res://build/screenshots/phoenix-motion/"+group[0]+".png")
	stage.queue_free()
	await process_frame
	quit()
