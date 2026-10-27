extends SceneTree
## Test-only scene showcase. It creates no gameplay controls or browser hooks.
## Add -- --capture with a rendering-enabled Godot process for PNGs.
const Arena = preload("res://scripts/arena.gd")
const Actor = preload("res://scripts/actor.gd")
const BattleCamera = preload("res://scripts/battle_camera.gd")
const OUTPUT := "res://build/screenshots/scene-art-native"
var failures: Array[String] = []
var report: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _visible_geometry(node: Node) -> int:
	var count := 0
	if node is GeometryInstance3D and node.is_visible_in_tree(): count += 1
	for child in node.get_children(): count += _visible_geometry(child)
	return count

func _frame(camera: Camera3D, size: Vector2i) -> void:
	root.size = size
	var framing: Dictionary = BattleCamera.frame(-0.9, [0.9], float(size.x) / float(size.y))
	camera.position = framing.position
	camera.fov = framing.fov
	camera.look_at(framing.target)

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")
	if result != OK: failures.append("Could not save " + name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var capture := "--capture" in OS.get_cmdline_user_args()
	var stage := Node3D.new()
	root.add_child(stage)
	var arena = Arena.new()
	stage.add_child(arena)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var actors: Array = []
	for i in 2:
		var actor = Actor.new()
		stage.add_child(actor)
		actor.setup(i == 1)
		var f := {"state":"idle", "stateTime":0.0, "stateDuration":0.0, "side":"player" if i == 0 else "enemy", "x":-0.9 if i == 0 else 0.9, "facing":1.0 if i == 0 else -1.0}
		actor.animate_fighter(f, 0.0, 0.0)
		actors.append(actor)
	await process_frame
	for region in 3:
		arena.set_region(region)
		await process_frame
		arena.update_arena(0.0, 0.0)
		actors[1].set_enemy_style([Color("48c6ef"), Color("69dbb6"), Color("f5b05f")][region])
		_frame(camera, Vector2i(1440, 900))
		var visible_before := _visible_geometry(arena)
		if capture: await _capture("region-" + str(region) + "-wide")
		_frame(camera, Vector2i(960, 540))
		if capture: await _capture("region-" + str(region) + "-small")
		arena.set_ink_cinematic(true)
		var visible_hidden := _visible_geometry(arena)
		if visible_hidden != 0: failures.append("Region " + str(region) + " leaves " + str(visible_hidden) + " arena meshes visible during ink cinematic")
		arena.set_ink_cinematic(false)
		var visible_restored := _visible_geometry(arena)
		if visible_before == 0 or visible_restored != visible_before: failures.append("Region " + str(region) + " does not fully restore its visible arena meshes")
		report.append({"region":region, "visibleBefore":visible_before, "visibleDuringUltimate":visible_hidden, "visibleRestored":visible_restored})
	var file := FileAccess.open(OUTPUT + "/scene-art-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"regions":report, "failures":failures, "captures":capture}, "  "))
	print("SCENE ART: ", 3 - failures.size(), "/3 regions hide and restore; captures=", capture)
	for failure in failures: push_error(failure)
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
