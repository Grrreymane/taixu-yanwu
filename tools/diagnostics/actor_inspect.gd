extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://assets/azure/Avatar_Fuka_C5_IN.fbx") as PackedScene
	if packed == null:
		push_error("FBX did not import as a scene")
		quit(2)
		return
	var model := packed.instantiate()
	root.add_child(model)
	var report: Dictionary = {"nodes": [], "animations": []}
	_visit(model, report)
	var file := FileAccess.open("res://assets/azure/import-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("ACTOR_IMPORT_REPORT ", report["nodes"].size(), " nodes; ", report["animations"].size(), " animations")
	quit()

func _visit(node: Node, report: Dictionary) -> void:
	var row: Dictionary = {"name": node.name, "type": node.get_class(), "path": str(node.get_path())}
	if node is Node3D:
		row["position"] = str(node.position)
		row["scale"] = str(node.scale)
	if node is MeshInstance3D:
		row["aabb"] = str(node.get_aabb())
		row["skin_binds"] = node.skin.get_bind_count() if node.skin else 0
		row["surfaces"] = []
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(i)
			var surface: Dictionary = {"material": mat.resource_name if mat else ""}
			if mat is BaseMaterial3D:
				surface["albedo"] = mat.albedo_texture.resource_path if mat.albedo_texture else ""
				surface["uv1_scale"] = str(mat.uv1_scale)
				surface["uv1_offset"] = str(mat.uv1_offset)
			row["surfaces"].append(surface)
	if node is Skeleton3D:
		row["bone_count"] = node.get_bone_count()
		row["bones"] = []
		for i in node.get_bone_count():
			row["bones"].append(node.get_bone_name(i))
	if node is AnimationPlayer:
		for animation_name in node.get_animation_list():
			var animation: Animation = node.get_animation(animation_name)
			var tracks: Array = []
			for i in mini(8, animation.get_track_count()):
				tracks.append(str(animation.track_get_path(i)))
			report["animations"].append({"name": animation_name, "duration": animation.length, "tracks": animation.get_track_count(), "example_paths": tracks})
	report["nodes"].append(row)
	for child in node.get_children():
		_visit(child, report)
