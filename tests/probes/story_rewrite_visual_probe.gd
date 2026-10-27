extends SceneTree
const Presentation = preload("res://scripts/story_presentation.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
const Arena = preload("res://scripts/arena.gd")
const OUTPUT := "res://build/screenshots/story-v3"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world:=Node3D.new()
	root.add_child(world)
	world.add_child(Arena.new())
	var presentation:=Presentation.new()
	world.add_child(presentation)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.current=true
	presentation.begin("intro",{"runNumber":1},Roster.resolve("fuhua","azure_empyrea","default"))
	for sample: Array in [["A01","A01-direction-01","opening-direction"],["A01","A01-02","opening"],["J01","J01-10","midpoint"],["I00","I00-17","signboard"],["I01","I01-01","street"],["I01","I01-direction-02","seated"],["I01_CONT","I01-13","waiting"],["I02","I02-direction-01","noodles-served"],["I02","I02-direction-02","paused-at-table"],["I02","I02-direction-03","flashback-direction"],["I02","I02-02","memory"],["I02","I02-direction-04","memory-direction"],["I02","I02-direction-05","return-to-present"],["I02","I02-03","present"],["I02","I02-27","ending"]]:
		presentation.lines=Dialogue.scene_lines(str(sample[0]))
		var found:=false
		for index: int in presentation.lines.size():
			if str(presentation.lines[index].lineId)==sample[1]:
				presentation.index=index
				found=true
				break
		if not found:
			push_error("Missing manuscript visual sample: "+str(sample))
			quit(1)
			return
		presentation._refresh_line()
		presentation.tick(2.5)
		presentation.revealed=true
		presentation._text.visible_characters=-1
		var frame:=presentation.frame(float(root.size.x)/root.size.y)
		camera.position=frame.position
		camera.fov=frame.fov
		camera.look_at(frame.target)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/"+str(sample[2])+".png")
	root.size=Vector2i(960,540)
	presentation._layout()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/ending-small.png")
	world.queue_free()
	await process_frame
	print("STORY_REWRITE_VISUAL_PASS")
	quit()
