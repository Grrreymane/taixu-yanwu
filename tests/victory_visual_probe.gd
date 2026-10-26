extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const Arena = preload("res://scripts/arena.gd")
const Victory = preload("res://scripts/victory_presentation.gd")
const OUTPUT := "res://build/screenshots/victory-native"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new()
	root.add_child(stage)
	var arena = Arena.new()
	stage.add_child(arena)
	var actor = Actor.new()
	stage.add_child(actor)
	actor.setup()
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	for at in [0.0,0.75,1.8,3.5,4.7]:
		actor.animate_victory(at)
		var shot := Victory.frame(at,1.6)
		camera.position = shot.position
		camera.fov = shot.fov
		camera.look_at(shot.target)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/pose-%02d.png" % roundi(at*10))
		print("VICTORY CAPTURE ",at," ",actor.presentation_snapshot())
	stage.queue_free()
	await process_frame
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.set_process(false)
	main._action("practice")
	main.game.ended = true
	main.game.winner = "player"
	main.campaign.finish(main.game.snapshot())
	main._begin_victory()
	for at in [1.8,3.5,4.7]:
		main.victory.time = at
		main._process(0.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/hud-%02d.png" % roundi(at*10))
	root.size = Vector2i(960,540)
	main._process(0.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/hud-results-small.png")
	main.queue_free()
	await process_frame
	quit()
