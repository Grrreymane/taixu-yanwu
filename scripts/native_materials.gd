extends RefCounted
## Values copied from the installed client's actual materials, per appearance.
## Shader math and screen-space outline conversion are handled separately.
const CATALOG := "res://assets/materials/native-character-profiles.json"
static var _profiles: Dictionary = {}
static var _external_catalogs: Dictionary = {}

static func profile(name: String, role: String, catalog: String = CATALOG) -> Dictionary:
	if not catalog.is_empty() and catalog != CATALOG:
		if not _external_catalogs.has(catalog) and FileAccess.file_exists(catalog):
			var external = JSON.parse_string(FileAccess.get_file_as_string(catalog))
			if external is Dictionary: _external_catalogs[catalog] = external.get("profiles", {})
		return _external_catalogs.get(catalog, {}).get(name, {}).get(role, {})
	if _profiles.is_empty() and FileAccess.file_exists(CATALOG):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		if data is Dictionary: _profiles = data.get("profiles", {})
	return _profiles.get(name, {}).get(role, {})

static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func apply(material: ShaderMaterial, outline: ShaderMaterial, name: String, role: String, has_uv2: bool = false, catalog: String = CATALOG) -> void:
	var values := profile(name, role, catalog)
	if values.is_empty(): return
	var alpha_clip := bool(values.get("useAlphaClip",false))
	material.set_shader_parameter("use_alpha_clip",alpha_clip)
	material.set_shader_parameter("alpha_clip_threshold",float(values.get("alphaClipThreshold",0.1)))
	if outline != null:
		outline.set_shader_parameter("use_alpha_clip",alpha_clip)
		outline.set_shader_parameter("alpha_clip_threshold",float(values.get("alphaClipThreshold",0.1)))
	var colors: Array = values.firstShadowColors
	material.set_shader_parameter("shadow_tint", _vector(colors[0]))
	for i in range(1, 5):
		material.set_shader_parameter("shadow_color_"+str(i+1), _vector(colors[i]))
	material.set_shader_parameter("use_shadow_regions", bool(values.useAlphaBands))
	material.set_shader_parameter("second_shadow_tint", _vector(values.secondShadowColor))
	material.set_shader_parameter("light_area", float(values.get("lightArea", 0.51)))
	material.set_shader_parameter("second_shadow_area", float(values.get("secondShadowArea", 0.51)))
	material.set_shader_parameter("shininess", float(values.get("shininess", 10.0)))
	material.set_shader_parameter("specular_strength", float(values.get("specMulti", 0.0)))
	material.set_shader_parameter("specular_color", _vector(values.get("specColor", [1.0,1.0,1.0])))
	material.set_shader_parameter("soft_specular", bool(values.specularSoft))
	material.set_shader_parameter("specular_smoothness", float(values.get("specularSmooth", 0.04)))
	material.set_shader_parameter("face_shadow_feather", float(values.get("shadowFeather", 0.001)))
	material.set_shader_parameter("use_backface_uv2", has_uv2 and bool(values.backFaceUseUv2))
	material.set_shader_parameter("material_tint", _vector(values.get("color", [1.0,1.0,1.0])))
	material.set_shader_parameter("environment_tint", _vector(values.get("envColor", [1.0,1.0,1.0])))
	material.set_shader_parameter("backface_tint", _vector(values.get("backFaceColor", [1.0,1.0,1.0])))
	var lightmap := str(values.get("textures", {}).get("lightmap", ""))
	if not lightmap.is_empty() and ResourceLoader.exists(lightmap):
		material.set_shader_parameter("lightmap_texture", load(lightmap))
		material.set_shader_parameter("has_lightmap", true)
	var face_map := str(values.get("textures", {}).get("faceMap", ""))
	var emission_map := str(values.get("textures", {}).get("emission", ""))
	if not emission_map.is_empty() and ResourceLoader.exists(emission_map):
		material.set_shader_parameter("emission_texture", load(emission_map))
		material.set_shader_parameter("has_emission_texture", true)
		material.set_shader_parameter("native_emission_tint", _vector(values.get("emissionColor", [1.0,1.0,1.0])))
		material.set_shader_parameter("native_emission_strength", float(values.get("emission",0.0)))
	if role == "face" and not face_map.is_empty() and ResourceLoader.exists(face_map):
		material.set_shader_parameter("face_mask_texture", load(face_map))
		material.set_shader_parameter("has_face_mask", true)
	if outline != null:
		# Enable the recovered authored depth offset only where the original
		# parameter has been audited; other appearances retain their current pass.
		outline.set_shader_parameter("outline_depth_offset", float(values.get("maxOutlineZOffset", 0.0))*float(values.get("outlineScale", 0.0)))
		outline.set_shader_parameter("use_color_regions", bool(values.useOutlineAlphaBands))
		var outline_colors: Array = values.outlineColors
		for i in 5:
			outline.set_shader_parameter("outline_color"+("" if i==0 else "_"+str(i+1)), _vector(outline_colors[i]))
		if not lightmap.is_empty() and ResourceLoader.exists(lightmap):
			outline.set_shader_parameter("lightmap_texture", load(lightmap))
	material.set_meta("native_material", values.sourceMaterial)
	material.set_meta("native_profile", name)
	material.set_meta("native_role", role)
	material.set_meta("native_catalog", catalog)
