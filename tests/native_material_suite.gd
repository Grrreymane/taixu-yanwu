extends SceneTree
## Headless integration checks. These verify data, import and material bindings;
## native_visual_probe provides the separate rendered before/after comparison.
const Actor = preload("res://scripts/actor.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const NativeMaterials = preload("res://scripts/native_materials.gd")
const CHARACTER_SHADER = preload("res://shaders/character.gdshader")
const OUTLINE_SHADER = preload("res://shaders/outline.gdshader")
const EXPECTED_SURFACES := 19
const CASES: Array[Dictionary] = [
	{"style":"azure_empyrea", "skin":"default", "profile":"azure_default"},
	{"style":"azure_empyrea", "skin":"taixu_memory", "profile":"taixu_memory"},
	{"style":"fenghuang", "skin":"default", "profile":"phoenix"}
]
var checks := 0
var failures: Array[String] = []
var surfaces: Array[Dictionary] = []
var observations: Array[String] = []
var completed_sections: Array[String] = []
var completed_appearances: Array[String] = []
var completed_materials: Array[String] = []
var completed_atlas_checks: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	_data_contract()
	_shader_contract()
	_uv2_fallback()
	for selection: Dictionary in CASES:
		_actor_binding(selection)
		await process_frame
	# GDScript can abort a nested function after a runtime error and let its
	# caller continue. Check end markers, not just an empty assertion list.
	_check(completed_sections == ["data", "shader", "uv2"], "all standalone validation sections reached their end")
	_check(completed_appearances.size() == CASES.size(), "all three appearance checks reached cleanup and completion")
	for selection: Dictionary in CASES:
		_check(completed_appearances.count(selection.profile) == 1, selection.profile+": appearance completed exactly once")
	_check(surfaces.size() == EXPECTED_SURFACES, "all 19 expected imported material surfaces were inspected")
	_check(completed_materials.size() == EXPECTED_SURFACES, "all 19 original-value validations reached their end")
	_check(completed_atlas_checks.size() == CASES.size()*4, "all 12 neutral/guard/reset atlas checks reached their end")
	var unique_surfaces: Dictionary = {}
	for surface: Dictionary in surfaces:
		unique_surfaces[str(surface.appearance)+"/"+str(surface.mesh)+":"+str(surface.surface)] = true
	_check(unique_surfaces.size() == EXPECTED_SURFACES, "surface coverage contains 19 unique imported surfaces")
	var report := {"suite":"native_material", "checks":checks, "passed":failures.is_empty(), "failures":failures,
		"coverage":"three real appearance imports, original role values, distinct face masks, UV2 fallback, expression UV and export inputs",
		"limitation":"Headless checks do not certify rendered color space, shading or outline appearance; use native_visual_probe.",
		"completion":{"sections":completed_sections,"appearances":completed_appearances,"materialValues":completed_materials.size(),"atlasChecks":completed_atlas_checks.size(),"expectedSurfaces":EXPECTED_SURFACES},
		"observations":observations, "surfaces":surfaces}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var file := FileAccess.open("res://build/reports/native-material-suite.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite":"native_material", "checks":checks, "failures":failures, "passed":failures.is_empty(), "appearances":completed_appearances.size(), "surfaces":surfaces.size(), "observations":observations}))
	quit(0 if failures.is_empty() else 1)

func _data_contract() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(NativeMaterials.CATALOG))
	_check(catalog is Dictionary and int(catalog.get("schemaVersion", 0)) == 1, "native material catalog parses with the supported schema")
	if not catalog is Dictionary: return
	_check(catalog.profiles.size() == 3, "catalog contains the three integrated appearances")
	for selection: Dictionary in CASES:
		var resolved := Roster.resolve("fuhua", selection.style, selection.skin)
		_check(str(resolved.actor.visual.nativeMaterialProfile) == selection.profile, selection.profile+": roster selects its own original profile")
		for role: String in ["body", "hair", "face"]:
			var values := NativeMaterials.profile(selection.profile, role)
			var id: String = selection.profile+"/"+role
			_check(not values.is_empty() and not str(values.get("sourceMaterial", "")).is_empty(), id+": original material identity is retained")
			_check(_five_colors(values.get("firstShadowColors", [])) and _five_colors(values.get("outlineColors", [])), id+": padded role colors are finite RGB values")
			var available := true
			for path: String in values.get("textures", {}).values():
				available = available and ResourceLoader.exists(path) and load(path) is Texture2D
			_check(available, id+": every original texture is an imported project resource")
			if role == "face":
				_check(str(values.textures.lightmap) != str(values.textures.faceMap), id+": Face LightMap and FaceMap are distinct inputs")
	# A few independent anchors catch wrong appearance/role mapping or a stale copy.
	_check(is_equal_approx(float(NativeMaterials.profile("taixu_memory", "body").specMulti), 1.95), "skin body retains its native 1.95 specular multiplier")
	_check(is_equal_approx(float(NativeMaterials.profile("taixu_memory", "body").get("maxOutlineZOffset", 0.0)), 1.0), "skin body retains its native maximum outline depth offset")
	_check(is_equal_approx(float(NativeMaterials.profile("azure_default", "body").specMulti), 0.4), "original Azure body retains its native 0.4 specular multiplier")
	_check(is_equal_approx(float(NativeMaterials.profile("phoenix", "hair").specMulti), 0.3), "Phoenix hair retains its native 0.3 specular multiplier")
	_check(NativeMaterials.profile("unknown", "body").is_empty(), "an unknown appearance does not silently select another original material")
	var export_config := ConfigFile.new()
	var loaded := export_config.load("res://export_presets.cfg") == OK
	_check(loaded and "assets/materials/native-character-profiles.json" in str(export_config.get_value("preset.0", "include_filter", "")), "Web export explicitly includes the dynamically read JSON catalog")
	_check(loaded and export_config.get_value("preset.0", "export_filter", "") == "all_resources", "Web export includes imported textures loaded through the catalog")
	completed_sections.append("data")

func _shader_contract() -> void:
	var required := ["shadow_tint", "shadow_color_2", "shadow_color_3", "shadow_color_4", "shadow_color_5", "second_shadow_tint",
		"use_shadow_regions", "light_area", "second_shadow_area", "shininess", "specular_strength", "specular_color", "soft_specular",
		"specular_smoothness", "face_shadow_feather", "use_backface_uv2", "material_tint", "environment_tint", "backface_tint",
		"lightmap_texture", "has_lightmap", "face_mask_texture", "has_face_mask", "uv_scale", "uv_offset"]
	var names: Array[String] = []
	for uniform: Dictionary in CHARACTER_SHADER.get_shader_uniform_list(): names.append(str(uniform.name))
	var missing: Array[String] = []
	for name: String in required:
		if name not in names: missing.append(name)
	_check(missing.is_empty(), "all native bindings target declared character uniforms: "+str(missing))
	var code: String = CHARACTER_SHADER.code
	# Channel-use checks complement resource-path assertions. This is deliberately
	# not a second implementation of the recovered shader equations.
	_check("texture(face_mask_texture, lookup.xy).a" in code and "hi3_native_face_lit(face_alpha, mask.g" in code,
		"face pass consumes FaceMap ALPHA separately from Face LightMap GREEN")
	_check("use_backface_uv2 ? UV2 : UV" in code, "body pass has an explicit UV fallback for imports without UV2")
	var outline_names: Array[String] = []
	for uniform: Dictionary in OUTLINE_SHADER.get_shader_uniform_list(): outline_names.append(str(uniform.name))
	_check("use_backface_uv2" not in outline_names and "texture(lightmap_texture, UV).a" in OUTLINE_SHADER.code,
		"recovered shared outline always samples UV1 independently of the body's dual-face switch")
	completed_sections.append("shader")

func _uv2_fallback() -> void:
	var material := ShaderMaterial.new()
	material.shader = CHARACTER_SHADER
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	material.set_shader_parameter("uv_scale", Vector2(0.25, 0.25))
	material.set_shader_parameter("uv_offset", Vector2(0.75, 0.5))
	NativeMaterials.apply(material, outline, "taixu_memory", "body", true)
	_check(material.get_shader_parameter("use_backface_uv2") == true, "native body dual-face request is honored when UV2 exists")
	var outline_before := _outline_values(outline)
	NativeMaterials.apply(material, outline, "taixu_memory", "body", false)
	_check(material.get_shader_parameter("use_backface_uv2") == false, "missing UV2 explicitly selects the body's UV1 fallback")
	_check(_outline_values(outline) == outline_before, "body UV2 availability does not change the native UV1 outline inputs")
	_check(material.get_shader_parameter("uv_scale") == Vector2(0.25, 0.25) and material.get_shader_parameter("uv_offset") == Vector2(0.75, 0.5), "native role binding preserves pre-existing atlas UV transforms")
	NativeMaterials.apply(material, outline, "azure_default", "body", true)
	_check(material.get_shader_parameter("use_backface_uv2") == false, "having UV2 alone does not enable it for an original single-UV material")
	completed_sections.append("uv2")

func _actor_binding(selection: Dictionary) -> void:
	var resolved := Roster.resolve("fuhua", selection.style, selection.skin)
	# Deliberately poison old approximate values: native configuration must win.
	resolved.actor.visual.hairShadowTint = Color(1.0, 0.0, 1.0)
	resolved.actor.visual.bodyShadowTint = Color(0.0, 1.0, 0.0)
	resolved.actor.visual.textures.faceMask = resolved.actor.visual.textures.bodyLightmap
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup(false, resolved)
	var identity: String = selection.profile
	_check(actor.ready_for_combat, identity+": real actor loads with its native configuration")
	if not actor.ready_for_combat:
		actor.free()
		return
	var roles: Dictionary = {}
	var tracked: Array[Dictionary] = []
	var atlas: Dictionary = {}
	var restored_body_surfaces := 0
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible: continue
		for surface_index in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface_index)
			if not material is ShaderMaterial: continue
			var kind := int(material.get_shader_parameter("material_kind"))
			var id: String = identity+"/"+str(mesh.name)+":"+str(surface_index)
			if kind == 3:
				_check(not material.has_meta("native_role"), id+": eye/mouth surface is excluded from body/face-role rebinding")
				atlas[str(mesh.name).to_lower()] = material
				continue
			var role: String = ["body", "hair", "face"][kind]
			roles[role] = true
			var values := NativeMaterials.profile(identity, role)
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
			var uv2_count: int = 0 if arrays[Mesh.ARRAY_TEX_UV2] == null else arrays[Mesh.ARRAY_TEX_UV2].size()
			var expected_uv2: bool = bool(values.backFaceUseUv2) and uv2_count > 0
			_check(uv2_count == 0 or uv2_count == vertex_count, id+": any imported UV2 covers every vertex")
			_check(str(material.get_meta("native_profile", "")) == identity and str(material.get_meta("native_role", "")) == role and str(material.get_meta("native_material", "")) == str(values.sourceMaterial), id+": material provenance matches its actual surface role")
			_validate_values(material, values, id)
			_check(_texture_path(material, "lightmap_texture") == str(values.textures.lightmap) and bool(material.get_shader_parameter("has_lightmap")), id+": original role LightMap is bound and enabled")
			_check(bool(material.get_shader_parameter("use_backface_uv2")) == expected_uv2, id+": native UV mode respects the actual imported surface")
			if identity=="taixu_memory" and str(mesh.name).to_lower()=="body":
				restored_body_surfaces+=1
				_check(vertex_count>0 and uv2_count==vertex_count and bool(values.backFaceUseUv2),id+": restored skin body contains the complete original UV2 channel")
				_check(material.get_shader_parameter("use_backface_uv2")==true,id+": restored skin body actively renders backs with the original UV2")
			if role == "face":
				_check(_texture_path(material, "face_mask_texture") == str(values.textures.faceMap) and bool(material.get_shader_parameter("has_face_mask")), id+": original FaceMap replaces the poisoned legacy face-mask input")
				_check(_texture_path(material, "face_mask_texture") != _texture_path(material, "lightmap_texture"), id+": angle mask and appearance-specific hairline mask remain separate")
			var outline = material.next_pass
			_check(outline is ShaderMaterial, id+": native role retains the existing outline pass")
			if outline is ShaderMaterial:
				var expected_depth := 0.01 if identity=="taixu_memory" and role=="body" else 0.0
				_check(is_equal_approx(float(outline.get_shader_parameter("outline_depth_offset")),expected_depth), id+": authored outline depth is active on every Taixu Body surface only")
				_check(outline.get_shader_parameter("use_color_regions") == bool(values.useOutlineAlphaBands), id+": native outline uses the original role's UV1 color regions")
				var outline_ok := true
				for index in 5:
					outline_ok = outline_ok and _same_color(outline.get_shader_parameter("outline_color"+("" if index == 0 else "_"+str(index+1))), values.outlineColors[index])
				_check(outline_ok and _texture_path(outline, "lightmap_texture") == str(values.textures.lightmap), id+": original outline colors and role LightMap survive old defaults")
			var state := _bound_values(material)
			tracked.append({"material":material, "state":state, "id":id})
			surfaces.append({"appearance":identity, "mesh":str(mesh.name), "surface":surface_index, "role":role, "vertices":vertex_count,
				"uv2Vertices":uv2_count, "nativeRequestsUv2":bool(values.backFaceUseUv2), "usesUv2":expected_uv2,
				"lightmap":_texture_path(material,"lightmap_texture"), "faceMap":_texture_path(material,"face_mask_texture") if role == "face" else ""})
			if bool(values.backFaceUseUv2) and uv2_count == 0:
				observations.append(id+": original dual-face material requests UV2, but this import contains none; explicit UV1 fallback is active")
	_check(roles.has("body") and roles.has("hair") and roles.has("face"), identity+": actual model exercises all three native roles")
	if identity=="taixu_memory":
		_check(restored_body_surfaces==3,"taixu_memory: all three restored Body surfaces were checked for active UV2")
	if selection.style == "fenghuang":
		for surface_id: String in ["hair:1", "hair:2"]:
			var expected_found := false
			for sample: Dictionary in surfaces:
				if sample.appearance == identity and str(sample.mesh).to_lower()+":"+str(sample.surface) == surface_id:
					expected_found = sample.role == "body"
			_check(expected_found, identity+"/"+surface_id+": original multi-material hair mesh keeps the body-role override")
	_check_atlas(atlas, actor.presentation_snapshot().get("facial", {}), identity+"/neutral")
	for facing in [-1.0, 1.0]:
		for step in 12:
			actor.animate_fighter({"x":0.0, "state":"guard", "stateTime":float(step+1)/60.0, "facing":facing}, 1.0/60.0, float(step+1)/60.0)
		_check_atlas(atlas, actor.presentation_snapshot().get("facial", {}), identity+"/guard/"+str(facing))
	actor.reset_presentation()
	for sample: Dictionary in tracked:
		_check(_bound_values(sample.material) == sample.state, sample.id+": animation, mirrored lighting and reset do not overwrite native role values")
	_check_atlas(atlas, actor.presentation_snapshot().get("facial", {}), identity+"/reset")
	actor.free()
	completed_appearances.append(identity)

func _validate_values(material: ShaderMaterial, values: Dictionary, id: String) -> void:
	var colors_ok := _same_color(material.get_shader_parameter("shadow_tint"), values.firstShadowColors[0])
	for index in range(1, 5):
		colors_ok = colors_ok and _same_color(material.get_shader_parameter("shadow_color_"+str(index+1)), values.firstShadowColors[index])
	colors_ok = colors_ok and _same_color(material.get_shader_parameter("second_shadow_tint"), values.secondShadowColor)
	_check(colors_ok, id+": original first/second shadow colors win over poisoned old tint defaults")
	var numeric := {"light_area":["lightArea",0.51], "second_shadow_area":["secondShadowArea",0.51], "shininess":["shininess",10.0],
		"specular_strength":["specMulti",0.0], "specular_smoothness":["specularSmooth",0.04], "face_shadow_feather":["shadowFeather",0.001]}
	var mismatches: Array[String] = []
	for name: String in numeric:
		if not is_equal_approx(float(material.get_shader_parameter(name)), float(values.get(numeric[name][0], numeric[name][1]))): mismatches.append(name)
	_check(mismatches.is_empty(), id+": original scalar parameters are bound: "+str(mismatches))
	_check(bool(material.get_shader_parameter("use_shadow_regions")) == bool(values.useAlphaBands) and bool(material.get_shader_parameter("soft_specular")) == bool(values.specularSoft), id+": region selection and soft/hard specular mode follow the original role")
	var multipliers_ok := true
	for pair: Array in [["material_tint","color"],["environment_tint","envColor"],["backface_tint","backFaceColor"],["specular_color","specColor"]]:
		multipliers_ok = multipliers_ok and _same_color(material.get_shader_parameter(pair[0]), values.get(pair[1], [1.0,1.0,1.0]))
	_check(multipliers_ok, id+": raw original color multipliers are retained without old manual darkening")
	completed_materials.append(id)

func _check_atlas(atlas: Dictionary, facial: Dictionary, label: String) -> void:
	if not bool(facial.get("enabled", false)):
		# Phoenix keeps its existing authored face UVs and has no C5 expression helper.
		_check(not atlas.is_empty(), label+": original eye/mouth surfaces remain available")
		completed_atlas_checks.append(label)
		return
	var roles: Dictionary = {}
	var matches := true
	for name: String in atlas:
		var role := "eyeL" if "eye_l" in name else "eyeR" if "eye_r" in name else "mouth"
		roles[role] = true
		var material: ShaderMaterial = atlas[name]
		var offset: Array = facial[role]
		matches = matches and material.get_shader_parameter("uv_scale") == Vector2(0.25,0.25) and material.get_shader_parameter("uv_offset") == Vector2(float(offset[0]),float(offset[1]))
	_check(roles.size() == 3 and matches, label+": actual eye/mouth material UVs match each distinct facial role")
	_check(facial.eyeR != facial.eyeL, label+": left and right eyes retain separate atlas cells")
	completed_atlas_checks.append(label)

func _outline_values(outline: ShaderMaterial) -> Dictionary:
	var result: Dictionary = {}
	for uniform: Dictionary in outline.shader.get_shader_uniform_list():
		var value = outline.get_shader_parameter(uniform.name)
		result[str(uniform.name)] = value.resource_path if value is Resource else value
	return result

func _bound_values(material: ShaderMaterial) -> Dictionary:
	var result: Dictionary = {}
	for name: String in ["shadow_tint","shadow_color_2","shadow_color_3","shadow_color_4","shadow_color_5","second_shadow_tint",
		"light_area","second_shadow_area","shininess","specular_strength","specular_color","soft_specular","specular_smoothness",
		"use_shadow_regions","face_shadow_feather","use_backface_uv2","material_tint","environment_tint","backface_tint","has_lightmap","has_face_mask"]:
		result[name] = material.get_shader_parameter(name)
	for name: String in ["lightmap_texture", "face_mask_texture"]: result[name] = _texture_path(material, name)
	return result

func _texture_path(material: ShaderMaterial, name: String) -> String:
	var texture = material.get_shader_parameter(name)
	return texture.resource_path if texture is Texture2D else ""

func _same_color(actual: Variant, expected: Array) -> bool:
	var vector: Vector3
	if actual is Vector3: vector = actual
	elif actual is Color: vector = Vector3(actual.r, actual.g, actual.b)
	else: return false
	return vector.is_equal_approx(Vector3(float(expected[0]), float(expected[1]), float(expected[2])))

func _five_colors(colors: Array) -> bool:
	if colors.size() != 5: return false
	for color: Array in colors:
		if color.size() != 3: return false
		for channel: Variant in color:
			if not (channel is float or channel is int) or not is_finite(float(channel)): return false
	return true
