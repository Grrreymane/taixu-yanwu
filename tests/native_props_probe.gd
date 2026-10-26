extends SceneTree
## --headless --script res://tests/native_props_probe.gd validates all framing.
## GPU: --script res://tests/native_props_probe.gd -- --capture
## Original transforms/materials are preserved. This is not a gameplay scene.
const INPUT := "res://assets/stage/native-props/"
const OUTPUT := "res://build/screenshots/native-props"
const PROPS := ["House_All", "TempleUpper", "BigTree", "RockGroup", "StonePlatform", "PlatformOriented", "NativeMountainTemple"]
const VIEWS: Array[Dictionary] = [
	{"id":"front", "direction":Vector3(0.0, 0.16, 1.0)},
	{"id":"side", "direction":Vector3(1.0, 0.16, 0.0)}
]
const VIEWPORT := Vector2i(1280, 800)
var stage: Node3D
var camera: Camera3D
var caption: Label
var capture := false
var samples: Array[Dictionary] = []
var props: Array[Dictionary] = []
var failures: Array[String] = []
var grid_images: Array[Image] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_size = VIEWPORT
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = VIEWPORT
	_build_stage()
	await process_frame
	for prop_name: String in PROPS:
		await _prop(prop_name)
	if capture and not grid_images.is_empty():
		var grid := Image.create(1280, 400 * PROPS.size(), false, Image.FORMAT_RGBA8)
		grid.fill(Color("a9b0ba"))
		for index in grid_images.size():
			grid.blit_rect(grid_images[index], Rect2i(0,0,640,400), Vector2i(index % 2 * 640, index / 2 * 400))
		grid.save_png(OUTPUT+"/grid-all.png")
	var report := {"probe":"native_props", "capture":capture, "passed":failures.is_empty(), "failures":failures,
		"contract":{"viewport":[1280,800], "background":"a9b0ba", "fov":35.0, "fit":"all eight world AABB corners, 14 percent margin", "sourceMaterialsUnmodified":true},
		"props":props, "shots":samples}
	var file := FileAccess.open(OUTPUT+"/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"probe":"native_props", "props":props.size(), "shots":samples.size(), "captures":samples.size() if capture else 0, "failures":failures}))
	stage.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a9b0ba")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.45
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = false
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0,-32.0,0.0)
	sun.light_energy = 0.65
	sun.shadow_enabled = false
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 35.0
	stage.add_child(camera)
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(20,14)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color("172732"))
	canvas.add_child(caption)

func _prop(prop_name: String) -> void:
	var path := INPUT+prop_name+".scn"
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append(prop_name+": packed scene could not be loaded")
		return
	var model := packed.instantiate()
	stage.add_child(model)
	var report := _inspect(model)
	report["name"] = prop_name
	report["scene"] = path
	props.append(report)
	if report.meshCount == 0:
		failures.append(prop_name+": no visible mesh")
		model.free()
		return
	var bounds: AABB = report["_bounds"]
	report.erase("_bounds")
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length() < 0.001:
		failures.append(prop_name+": invalid or empty bounds")
		model.free()
		return
	for view: Dictionary in VIEWS:
		_fit(bounds, view.direction)
		caption.text = "%s / %s    bounds %.2f x %.2f x %.2f    meshes %d    triangles %d" % [prop_name, view.id, bounds.size.x, bounds.size.y, bounds.size.z, report.meshCount, report.triangles]
		var pixels: Array = []
		var framed := true
		for corner in 8:
			var point := bounds.get_endpoint(corner)
			var pixel := camera.unproject_position(point)
			pixels.append(_vec(pixel))
			framed = framed and not camera.is_position_behind(point) and Rect2(Vector2.ZERO, Vector2(VIEWPORT)).has_point(pixel)
		var name: String = prop_name+"-"+str(view.id)
		if not framed: failures.append(name+": an AABB corner falls outside the viewport")
		samples.append({"id":name, "cameraPosition":_vec(camera.position), "target":_vec(bounds.get_center()), "rotation":_vec(camera.rotation), "fov":camera.fov, "near":camera.near, "far":camera.far, "allBoundsVisible":framed, "cornerPixels":pixels})
		if capture:
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(OUTPUT+"/"+name+".png")
			image.resize(640,400,Image.INTERPOLATE_LANCZOS)
			grid_images.append(image)
	model.free()
	await process_frame

func _fit(bounds: AABB, direction: Vector3) -> void:
	var center := bounds.get_center()
	var outward := direction.normalized()
	camera.position = center+outward
	camera.look_at(center)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var tan_y := tan(deg_to_rad(camera.fov*0.5))
	var tan_x := tan_y*float(VIEWPORT.x)/float(VIEWPORT.y)
	var distance := 0.01
	for corner in 8:
		var relative := bounds.get_endpoint(corner)-center
		var toward_camera := relative.dot(outward)
		distance = maxf(distance, toward_camera+absf(relative.dot(right))/tan_x*1.14)
		distance = maxf(distance, toward_camera+absf(relative.dot(up))/tan_y*1.14)
	camera.position = center+outward*distance
	camera.near = maxf(0.01, distance*0.001)
	camera.far = maxf(100.0, distance+bounds.size.length()*3.0)
	camera.look_at(center)

func _inspect(model: Node) -> Dictionary:
	var meshes: Array[Dictionary] = []
	var materials: Dictionary = {}
	var bounds := AABB()
	var first := true
	var total_vertices := 0
	var total_triangles := 0
	var surface_count := 0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var world_bounds: AABB = mesh.global_transform*mesh.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
		var surface_reports: Array[Dictionary] = []
		for index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(index)
			var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
			var indices: int = 0 if arrays[Mesh.ARRAY_INDEX] == null else arrays[Mesh.ARRAY_INDEX].size()
			var element_count := indices if indices > 0 else vertices
			var primitive: int = mesh.mesh.surface_get_primitive_type(index)
			var triangles: int = element_count / 3 if primitive == Mesh.PRIMITIVE_TRIANGLES else maxi(0,element_count-2) if primitive == Mesh.PRIMITIVE_TRIANGLE_STRIP else 0
			var material := mesh.get_active_material(index)
			var material_id := str(material.get_instance_id()) if material != null else "missing"
			if material == null:
				failures.append(str(model.name)+"/"+str(mesh.name)+":"+str(index)+": missing material")
			elif not materials.has(material_id): materials[material_id] = _material(material)
			surface_reports.append({"index":index, "vertices":vertices, "triangles":triangles, "primitive":primitive,
				"uv1Vertices":0 if arrays[Mesh.ARRAY_TEX_UV] == null else arrays[Mesh.ARRAY_TEX_UV].size(),
				"uv2Vertices":0 if arrays[Mesh.ARRAY_TEX_UV2] == null else arrays[Mesh.ARRAY_TEX_UV2].size(), "materialId":material_id})
			total_vertices += vertices
			total_triangles += triangles
			surface_count += 1
		meshes.append({"name":str(mesh.name), "path":str(model.get_path_to(mesh)), "worldBounds":_box(world_bounds), "surfaces":surface_reports})
	return {"_bounds":bounds, "bounds":_box(bounds), "meshCount":meshes.size(), "surfaceCount":surface_count, "materialCount":materials.size(), "vertices":total_vertices, "triangles":total_triangles, "meshes":meshes, "materials":materials}

func _material(material: Material) -> Dictionary:
	var result := {"name":material.resource_name, "path":material.resource_path, "type":material.get_class()}
	if material is ShaderMaterial:
		result["shader"] = material.shader.resource_path
		var parameters: Dictionary = {}
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			parameters[str(uniform.name)] = _value(material.get_shader_parameter(uniform.name))
		result["parameters"] = parameters
	elif material is BaseMaterial3D:
		result["albedo"] = _value(material.albedo_color)
		result["albedoTexture"] = _value(material.albedo_texture)
		result["transparency"] = material.transparency
	return result

func _vec(value: Variant) -> Array:
	if value is Vector2: return [value.x,value.y]
	return [value.x,value.y,value.z]

func _box(value: AABB) -> Dictionary:
	return {"position":_vec(value.position), "size":_vec(value.size), "center":_vec(value.get_center())}

func _value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector3: return _vec(value)
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Resource: return value.resource_path
	return value
