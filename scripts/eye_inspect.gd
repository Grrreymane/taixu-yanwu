extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _run() -> void:
	var actor := Node3D.new()
	actor.set_script(load("res://scripts/actor.gd"))
	root.add_child(actor)
	actor.setup(false)
	actor.animate_fighter({"state":"idle","stateTime":0.2,"x":0.0,"facing":1.0}, 0.2, 0.2)
	actor.rotation.y = 0.0
	var report: Dictionary = {"meshes":[]}
	var skel: Skeleton3D = actor.skeleton
	for name: String in ["Eye_L", "Eye_R", "Mouth", "Face", "Hair"]:
		var mesh_node := actor.model.find_child(name, true, false) as MeshInstance3D
		var row: Dictionary = {"name":name,"visible":mesh_node.is_visible_in_tree(),"surfaces":[]}
		for surface: int in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var mat := mesh_node.get_active_material(surface) as ShaderMaterial
			var tex: Texture2D = mat.get_shader_parameter("albedo_texture")
			var image: Image = tex.get_image()
			if image.is_compressed(): image.decompress()
			var uv_scale: Vector2 = mat.get_shader_parameter("uv_scale")
			var uv_offset: Vector2 = mat.get_shader_parameter("uv_offset")
			var min_uv := Vector2(INF, INF)
			var max_uv := Vector2(-INF, -INF)
			var final_vertices: Array = []
			var uv_values: Array = []
			var alphas: Array = []
			var bone_count_per_vertex: int = bones.size() / verts.size()
			for vi: int in verts.size():
				var p := Vector3.ZERO
				for wi: int in bone_count_per_vertex:
					var array_index: int = vi * bone_count_per_vertex + wi
					var bind: int = bones[array_index]
					var bone_name: StringName = mesh_node.skin.get_bind_name(bind)
					var bone: int = skel.find_bone(bone_name) if not bone_name.is_empty() else mesh_node.skin.get_bind_bone(bind)
					p += skel.get_bone_global_pose(bone) * mesh_node.skin.get_bind_pose(bind) * verts[vi] * weights[array_index]
				final_vertices.append(_vector(skel.global_transform * p))
				var uv: Vector2 = uvs[vi] * uv_scale + uv_offset
				uv_values.append([uv.x, uv.y])
				min_uv = min_uv.min(uv)
				max_uv = max_uv.max(uv)
				var pixel := Vector2i(clampi(int(uv.x * image.get_width()),0,image.get_width()-1), clampi(int(uv.y * image.get_height()),0,image.get_height()-1))
				alphas.append(image.get_pixelv(pixel).a)
			row["surfaces"].append({"texture":tex.resource_path,"kind":mat.get_shader_parameter("material_kind"),"uv_scale":[uv_scale.x,uv_scale.y],"uv_offset":[uv_offset.x,uv_offset.y],"uv_min":[min_uv.x,min_uv.y],"uv_max":[max_uv.x,max_uv.y],"uvs":uv_values,"vertex_alpha":alphas,"vertices":final_vertices,"indices":Array(arrays[Mesh.ARRAY_INDEX])})
		report["meshes"].append(row)
	var file := FileAccess.open("res://build/eye-inspection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("EYE_REPORT_WRITTEN")
	quit()
