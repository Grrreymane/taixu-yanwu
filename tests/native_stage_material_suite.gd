extends SceneTree
## Real Arena resource/binding/lifetime regression; no renderer or screenshots.
const Arena = preload("res://scripts/arena.gd")
const ROOT := "res://assets/stage/native-props/"
const MATCAP_FAMILY := "-5500795706935829961"
const SOURCES := ["original-materials.json", "mountain-temple-materials.json"]

class ErrorRecorder extends Logger:
	var errors: Array[Dictionary] = []
	var guard := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		guard.lock()
		errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type})
		guard.unlock()
	func _log_message(_message: String, _error: bool) -> void: pass
	func snapshot() -> Array[Dictionary]:
		guard.lock()
		var copy: Array[Dictionary] = errors.duplicate(true)
		guard.unlock()
		return copy

var checks := 0
var failures: Array[String] = []
var catalog: Dictionary = {}
var region_reports: Array[Dictionary] = []
var surface_reports: Array[Dictionary] = []
var geometry_cache: Dictionary = {}
var material_ids: Dictionary = {}
var completed_regions: Array[int] = []
var completed_props := 0
var expected_props := 0
var expected_surfaces := 0
var completed_surfaces := 0
var disabled_specular_matcaps := 0
var recorder := ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("CHECK FAILED: ",message)

func _run() -> void:
	OS.add_logger(recorder)
	for source: String in SOURCES:
		var decoded = JSON.parse_string(FileAccess.get_file_as_string(ROOT+source))
		_check(decoded is Dictionary and not decoded.is_empty(), "source catalog loads: "+source)
		if decoded is Dictionary: catalog.merge(decoded,true)
	var export_config := ConfigFile.new()
	_check(export_config.load("res://export_presets.cfg")==OK, "Web export configuration is readable")
	for source: String in SOURCES:
		_check("assets/stage/native-props/"+source in str(export_config.get_value("preset.0","include_filter","")), "Web export includes dynamic source catalog "+source)
	var arena = Arena.new()
	root.add_child(arena)
	await process_frame
	var previous_props: Array[WeakRef] = []
	for region in 3:
		arena.set_region(region)
		await process_frame
		await process_frame
		for previous: WeakRef in previous_props:
			_check(previous.get_ref()==null, "region "+str(region)+": previous native prop was destroyed rather than retained globally")
		previous_props.clear()
		for node: Node3D in arena._scenery.find_children("*","Node3D",true,false):
			if str(node.scene_file_path).begins_with(ROOT): previous_props.append(weakref(node))
		_inspect_region(arena,region)
		arena.set_ink_cinematic(true)
		_check(not arena._scenery.visible,"region "+str(region)+": ink cinematic hides the material-owning scenery root")
		arena.set_ink_cinematic(false)
		_check(arena._scenery.visible,"region "+str(region)+": scenery restores after the cinematic")
	# Reports contain paths/values only, never Material references. Otherwise the
	# test itself would accidentally hide the destruction-order regression.
	arena.free()
	await process_frame
	await process_frame
	for previous: WeakRef in previous_props:
		_check(previous.get_ref()==null, "final cleanup releases every native prop")
	_check(completed_regions==[0,1,2], "all three actual regions completed inspection")
	_check(expected_props>0 and completed_props==expected_props, "every discovered native prop completed validation")
	_check(expected_surfaces>=60 and completed_surfaces==expected_surfaces, "every discovered surface completed validation, including all 60 mountain-temple surfaces")
	_check(surface_reports.size()==completed_surfaces, "completed surface records contain no missing intermediate validation")
	_check(disabled_specular_matcaps>0, "real materials with additive Matcap specular disabled still exercise the base Matcap path")
	var engine_errors := recorder.snapshot()
	_check(engine_errors.is_empty(), "no engine, script, missing-texture or material-lifetime errors during load/switch/free")
	var report := {"suite":"native_stage_material","passed":failures.is_empty(),"checks":checks,"failures":failures,"engineErrors":engine_errors,
		"completion":{"regions":completed_regions,"props":completed_props,"expectedProps":expected_props,"surfaces":completed_surfaces,"expectedSurfaces":expected_surfaces,"disabledSpecularMatcapSurfaces":disabled_specular_matcaps},
		"regions":region_reports,"surfaces":surface_reports,"limitation":"Headless bindings and geometry checks; rendered Matcap appearance requires the separate scene screenshots."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var file := FileAccess.open("res://build/reports/native-stage-material-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	OS.remove_logger(recorder)
	print(JSON.stringify({"suite":"native_stage_material","passed":failures.is_empty(),"checks":checks,"failures":failures,"engineErrors":engine_errors.size(),"regions":completed_regions.size(),"props":completed_props,"surfaces":completed_surfaces}))
	quit(0 if failures.is_empty() else 1)

func _inspect_region(arena, region: int) -> void:
	var native_props: Array[Node3D] = []
	for node: Node3D in arena._scenery.find_children("*","Node3D",true,false):
		if str(node.scene_file_path).begins_with(ROOT): native_props.append(node)
	_check(native_props.size()==6,"region "+str(region)+": complete backdrop, two temples, tree and two rock groups are present")
	expected_props += native_props.size()
	var temple_groups := 0
	var region_surfaces := 0
	for prop: Node3D in native_props:
		var prop_name := prop.scene_file_path.get_file().get_basename()
		var meshes := prop.find_children("*","MeshInstance3D",true,false)
		var surface_count := 0
		for mesh: MeshInstance3D in meshes: surface_count += mesh.mesh.get_surface_count()
		expected_surfaces += surface_count
		region_surfaces += surface_count
		if prop_name=="NativeMountainTemple":
			temple_groups += 1
			_check(meshes.size()==9 and surface_count==20,"region "+str(region)+": complete native mountain-temple group has 9 components / 20 surfaces")
		_inspect_prop(prop,meshes,region,surface_count)
	_check(temple_groups==1,"region "+str(region)+": exactly one complete native mountain-temple group is rendered")
	region_reports.append({"region":region,"props":native_props.size(),"mountainTempleGroups":temple_groups,"surfaces":region_surfaces})
	completed_regions.append(region)

func _inspect_prop(prop: Node3D, meshes: Array[Node], region: int, surface_count: int) -> void:
	var id := "region-"+str(region)+"/"+str(prop.name)
	_check(not meshes.is_empty() and surface_count>0,id+": imported prop has actual geometry")
	var owners = prop.get_meta("native_material_instances",null)
	_check(owners is Array and owners.size()==surface_count,id+": parent retains every surface override until child destruction")
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			var surface_id := id+"/"+str(mesh.name)+":"+str(surface)
			_check(material is ShaderMaterial,surface_id+": actual override is a shader material")
			if not material is ShaderMaterial: continue
			_check(owners is Array and material in owners,surface_id+": override is retained by its prop, not just the mesh")
			var material_id := material.get_instance_id()
			_check(not material_ids.has(material_id),surface_id+": material instance is not shared across prop instances")
			material_ids[material_id]=true
			_inspect_surface(mesh,surface,material,surface_id)
	completed_props += 1

func _inspect_surface(mesh: MeshInstance3D, surface: int, material: ShaderMaterial, id: String) -> void:
	var source_name := str(material.get_meta("source_material",""))
	_check(not source_name.is_empty() and catalog.has(source_name),id+": material provenance resolves into the original catalog")
	if not catalog.has(source_name): return
	var source: Dictionary = catalog[source_name]
	var properties: Dictionary = source.properties
	var floats: Dictionary = properties.get("m_Floats",{})
	var textures: Dictionary = properties.get("m_TexEnvs",{})
	var colors: Dictionary = properties.get("m_Colors",{})
	var matcap := str(source.get("originalShaderPathId",""))==MATCAP_FAMILY
	var names: Array[String] = []
	for uniform: Dictionary in material.shader.get_shader_uniform_list(): names.append(str(uniform.name))
	_texture(material,"main_tex",textures.get("_MainTex",{}),id,true)
	if "has_shadow_tex" in names:
		var shadow_env: Dictionary = textures.get("_ShadowTex",{})
		var shadow_path := _path(shadow_env)
		_texture(material,"shadow_tex",shadow_env,id)
		_check(material.get_shader_parameter("has_shadow_tex")==not shadow_path.is_empty(),id+": baked-light flag matches original ShadowTex")
		_check(_near(material.get_shader_parameter("lightmap_intensity"),float(floats.get("_LightMapIntensity",1.0))),id+": native baked-light intensity is retained")
		var factor := Vector3.ONE
		if matcap:
			factor=2.0*_color(colors.get("_Color",{}),Vector3.ONE*0.5)*_color(colors.get("_EnvColor",{}),Vector3.ONE)
		var actual_factor = material.get_shader_parameter("material_factor")
		_check(actual_factor is Vector3 and actual_factor.is_equal_approx(factor),id+": original color/environment factor is bound")
	var geometry := _geometry(mesh.mesh,surface,matcap)
	_check(int(geometry.vertices)>0,id+": surface contains vertices")
	if matcap:
		_check(material.get_shader_parameter("use_matcap")==true,id+": base Matcap is enabled for the whole original shader family")
		_texture(material,"matcap_tex",textures.get("_MatCap",{}),id,true)
		_texture(material,"matcap_mask_tex",textures.get("_MatcapMaskMap",{}),id)
		var normal_env: Dictionary = textures.get("_BumpMap",{})
		_texture(material,"normal_tex",normal_env,id)
		_check(material.get_shader_parameter("use_normal_tex")==not _path(normal_env).is_empty(),id+": normal-map flag matches the original texture")
		_check(_near(material.get_shader_parameter("matcap_metal_ref"),float(floats.get("_MetalRef",0.639))),id+": original MetalRef is retained")
		var scale := _vec2(normal_env.get("m_Scale",{}),Vector2.ONE)
		var offset := _vec2(normal_env.get("m_Offset",{}),Vector2.ZERO)
		_check(material.get_shader_parameter("normal_uv_scale")==scale and material.get_shader_parameter("normal_uv_offset")==Vector2(offset.x,1.0-scale.y-offset.y),id+": normal-map ST matches the exported V convention")
		_check(int(geometry.tangentValues)==int(geometry.vertices)*4 and int(geometry.invalidTangents)==0,id+": every Matcap vertex has a finite nonzero orthogonal tangent and valid handedness")
		if float(floats.get("_EnableMatcapSpecular",0.0))==0.0: disabled_specular_matcaps+=1
	elif "use_matcap" in names:
		var explicit_value = material.get_shader_parameter("use_matcap")
		var native_default_off: bool = explicit_value==null and "uniform bool use_matcap = false;" in material.shader.code
		_check(explicit_value==false or native_default_off,id+": non-Matcap shader family remains on its explicit shader-default base path")
	surface_reports.append({"id":id,"sourceMaterial":source_name,"shaderFamily":str(source.get("originalShaderPathId","")),"matcap":matcap,
		"additiveMatcapSpecular":float(floats.get("_EnableMatcapSpecular",0.0)),"geometry":geometry,
		"mainTexture":_actual_path(material,"main_tex"),"matcapTexture":_actual_path(material,"matcap_tex") if matcap else "",
		"normalTexture":_actual_path(material,"normal_tex") if matcap else "","maskTexture":_actual_path(material,"matcap_mask_tex") if matcap else ""})
	completed_surfaces+=1

func _texture(material: ShaderMaterial, uniform: String, env: Dictionary, id: String, required: bool=false) -> void:
	var expected := _path(env)
	if required: _check(not expected.is_empty(),id+": source has required "+uniform)
	if not expected.is_empty(): _check(ResourceLoader.exists(expected) and load(expected) is Texture2D,id+": required source resource is imported: "+expected.get_file())
	_check(_actual_path(material,uniform)==expected,id+": "+uniform+" binds its exact original texture or explicit native null")

func _geometry(mesh: Mesh, surface: int, check_tangents: bool) -> Dictionary:
	var key := str(mesh.get_instance_id())+":"+str(surface)+":"+str(check_tangents)
	if geometry_cache.has(key): return geometry_cache[key]
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
	var invalid := 0
	var max_dot := 0.0
	var bad_samples: Array[Dictionary] = []
	var active_vertices: Dictionary = {}
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if check_tangents:
		for triangle in indices.size()/3:
			var a := indices[triangle*3]
			var b := indices[triangle*3+1]
			var c := indices[triangle*3+2]
			if (positions[b]-positions[a]).cross(positions[c]-positions[a]).length_squared()>0.000000000001:
				active_vertices[a]=true
				active_vertices[b]=true
				active_vertices[c]=true
	if check_tangents and tangents.size()==vertices*4 and normals.size()==vertices:
		for index in vertices:
			var t := Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
			var n := normals[index]
			var w := tangents[index*4+3]
			var alignment := absf(t.normalized().dot(n.normalized()))
			max_dot=maxf(max_dot,alignment)
			if not t.is_finite() or not n.is_finite() or not is_finite(w) or t.length()<0.5 or n.length()<0.5 or absf(absf(w)-1.0)>0.01 or alignment>0.05:
				invalid+=1
				if bad_samples.size()<50: bad_samples.append({"vertex":index,"tangent":[t.x,t.y,t.z,w],"normal":[n.x,n.y,n.z],"dot":alignment,"inNondegenerateTriangle":active_vertices.has(index)})
	elif check_tangents: invalid=vertices
	var result := {"vertices":vertices,"tangentValues":tangents.size(),"invalidTangents":invalid,"maxNormalTangentDot":max_dot,"badSamples":bad_samples,
		"uv2Vertices":0 if arrays[Mesh.ARRAY_TEX_UV2]==null else arrays[Mesh.ARRAY_TEX_UV2].size()}
	geometry_cache[key]=result
	return result

func _path(env: Dictionary) -> String:
	var reference: Dictionary = env.get("m_Texture",{})
	return "" if bool(reference.get("IsNull",true)) else ROOT+"textures/"+str(reference.get("Name",""))+".png"

func _actual_path(material: ShaderMaterial, uniform: String) -> String:
	var value = material.get_shader_parameter(uniform)
	return value.resource_path if value is Texture2D else ""

func _color(value: Dictionary, fallback: Vector3) -> Vector3:
	return fallback if value.is_empty() else Vector3(float(value.get("r",1.0)),float(value.get("g",1.0)),float(value.get("b",1.0)))

func _vec2(value: Dictionary, fallback: Vector2) -> Vector2:
	return Vector2(float(value.get("X",fallback.x)),float(value.get("Y",fallback.y)))

func _near(value: Variant, expected: float) -> bool:
	return (value is float or value is int) and is_equal_approx(float(value),expected)
