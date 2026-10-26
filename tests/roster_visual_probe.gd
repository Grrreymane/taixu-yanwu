extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Arena=preload("res://scripts/arena.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1280,800)
	var stage=Node3D.new()
	root.add_child(stage)
	var arena=Arena.new()
	stage.add_child(arena)
	var camera=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.position=Vector3(0,2.0,7.2)
	camera.fov=34
	camera.look_at(Vector3(0,1.45,0))
	DirAccess.make_dir_recursive_absolute("res://build/screenshots/roster")
	for ids in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		var selection=Roster.resolve("fuhua",ids[0],ids[1])
		if selection.is_empty(): continue
		var actor=Actor.new()
		stage.add_child(actor)
		actor.setup(false,selection)
		actor.animate_fighter({"x":0.0,"facing":1.0,"state":"idle","stateTime":0.6},0.1,0.6)
		actor.rotation.y=-0.18
		for pose in ["idle","victory"]:
			if pose=="victory": actor.animate_victory(1.8)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/screenshots/roster/"+ids[0]+"-"+ids[1]+"-"+pose+".png")
			print(ids," ",actor.presentation_snapshot())
		actor.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	quit()
