extends RefCounted
## Per-material values from the original scene, kept separate from placement.
const ROOT := "res://assets/stage/native-props/"
const SOURCES := ["original-materials.json", "mountain-temple-materials.json"]
static var _catalog: Dictionary = {}

static func _color(value: Dictionary, fallback: Vector3=Vector3.ONE) -> Vector3:
	if value.is_empty(): return fallback
	return Vector3(float(value.get("r",1.0)),float(value.get("g",1.0)),float(value.get("b",1.0)))

static func _texture(env: Dictionary) -> Texture2D:
	var reference: Dictionary = env.get("m_Texture",{})
	if reference.get("IsNull",true): return null
	var path := ROOT+"textures/"+str(reference.get("Name",""))+".png"
	if not ResourceLoader.exists(path):
		push_error("Missing native stage texture: "+path)
		return null
	return load(path) as Texture2D

static func _vector(value: Dictionary, fallback: Vector2) -> Vector2:
	return Vector2(float(value.get("X",fallback.x)),float(value.get("Y",fallback.y)))

static func apply(node: Node3D, scene_tint: Color=Color.WHITE) -> void:
	if _catalog.is_empty():
		for source: String in SOURCES:
			var decoded = JSON.parse_string(FileAccess.get_file_as_string(ROOT+source))
			if decoded is Dictionary: _catalog.merge(decoded,true)
	var instances: Array[Material] = []
	for child in node.find_children("*","MeshInstance3D",true,false):
		var mesh_node := child as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var source_mat := mesh_node.get_active_material(surface) as ShaderMaterial
			if source_mat==null or not _catalog.has(source_mat.resource_name): continue
			var data: Dictionary = _catalog[source_mat.resource_name]
			var material := source_mat.duplicate() as ShaderMaterial
			# Shared stage time-of-day modulation, separate from recovered values.
			material.set_shader_parameter("tint",scene_tint)
			var props: Dictionary = data.properties
			var floats: Dictionary = props.get("m_Floats",{})
			var colors: Dictionary = props.get("m_Colors",{})
			material.set_shader_parameter("lightmap_intensity",float(floats.get("_LightMapIntensity",1.0)))
			var factor := Vector3.ONE
			if str(data.get("originalShaderPathId","")) == "-5500795706935829961":
				factor = 2.0*_color(colors.get("_Color",{}),Vector3.ONE*0.5)*_color(colors.get("_EnvColor",{}))
				var textures: Dictionary = props.get("m_TexEnvs",{})
				# Base Matcap applies to this whole shader family. The native
				# _EnableMatcapSpecular switch controls a separate additive pass.
				material.set_shader_parameter("use_matcap",true)
				material.set_shader_parameter("matcap_tex",_texture(textures.get("_MatCap",{})))
				material.set_shader_parameter("matcap_mask_tex",_texture(textures.get("_MatcapMaskMap",{})))
				material.set_shader_parameter("matcap_metal_ref",float(floats.get("_MetalRef",0.639)))
				var normal_env: Dictionary = textures.get("_BumpMap",{})
				var normal := _texture(normal_env)
				material.set_shader_parameter("use_normal_tex",normal!=null)
				material.set_shader_parameter("normal_tex",normal)
				material.set_shader_parameter("normal_uv_scale",_vector(normal_env.get("m_Scale",{}),Vector2.ONE))
				var offset := _vector(normal_env.get("m_Offset",{}),Vector2.ZERO)
				# Mesh UVs are exported with V flipped. Apply the same ST conversion.
				var scale := _vector(normal_env.get("m_Scale",{}),Vector2.ONE)
				material.set_shader_parameter("normal_uv_offset",Vector2(offset.x,1.0-scale.y-offset.y))
			material.set_shader_parameter("material_factor",factor)
			material.set_meta("source_material",source_mat.resource_name)
			mesh_node.set_surface_override_material(surface,material)
			instances.append(material)
	# Keep overrides alive until every child mesh has finished its destructor.
	# Otherwise the Compatibility/dummy backend queries an already-freed RID
	# while a region's scenery is being removed.
	node.set_meta("native_material_instances",instances)
