extends SceneTree
## Real imported actor binding checks against independently audited source values.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func _check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _same(value:Variant,expected:float) -> bool:
	return value!=null and is_equal_approx(float(value),expected)
func _run() -> void:
	var choice=Roster.resolve("fuhua","night_squire","autumn_leaves")
	_check(choice.appearanceId=="autumn_leaves","Requested skin resolves to the actual red-leaf outfit")
	var actor=Actor.new();root.add_child(actor);actor.setup(false,choice)
	_check(actor.ready_for_combat,"Original outfit and native combat model initialize")
	var body:MeshInstance3D=actor.model.find_child("Body",true,false)
	_check(body!=null and body.mesh.get_surface_count()==2,"Original Body has its two real material surfaces")
	var mat:ShaderMaterial=body.get_active_material(0)
	_check(mat.get_meta("native_material","")=="Avatar_Fuka_C3_04_03_Material_Body","Body uses the04_03 material rather than03_01 or04_02")
	_check(mat.get_meta("native_profile","")=="night_squire_autumn","Body uses the skin's independent material catalog")
	_check(mat.get_shader_parameter("albedo_texture").resource_path.ends_with("Avatar_Fuka_C3_04_03_Texture_Body_Color.png"),"Body samples the native red-leaf texture")
	_check(mat.get_shader_parameter("lightmap_texture").resource_path.ends_with("Avatar_Fuka_C3_04_03_Texture_Body_LightMap.png"),"Body uses its own original material-region lightmap")
	_check(mat.get_shader_parameter("use_backface_uv2")==false,"04_03 does not inherit04_02 dual-face UV behavior")
	_check(mat.get_shader_parameter("use_shadow_regions")==true,"Body retains the original five shadow-color regions")
	_check(_same(mat.get_shader_parameter("specular_strength"),0.151),"Body retains its original0.151 specular multiplier")
	_check(_same(mat.get_shader_parameter("shininess"),1.7),"Body retains its original1.7 shininess")
	_check(mat.next_pass is ShaderMaterial,"Body keeps its contour pass")
	_check(_same(mat.next_pass.get_shader_parameter("outline_depth_offset"),0.01),"Body outline binds the audited1*.01 depth term")
	_check(mat.next_pass.get_shader_parameter("use_color_regions")==true,"Outline retains original regional colors")
	var hidden=body.get_active_material(1)
	_check(hidden is StandardMaterial3D and hidden.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and is_zero_approx(hidden.albedo_color.a),"CommonEmpty remains invisible without deleting original vertices")
	var weapons:=0
	var face_parts:=0
	for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		var name:=str(mesh.name).to_lower()
		for index in mesh.mesh.get_surface_count():
			var active=mesh.get_active_material(index)
			if not active is ShaderMaterial:continue
			var role:=str(active.get_meta("native_role",""))
			if role=="weapon":
				weapons+=1
				_check(active.get_meta("native_material","")=="Weapon_Fist_F1_25_3_Material","Both original fists use the real weapon material")
				_check(active.get_shader_parameter("has_lightmap")==false,"Fists do not borrow garment lightmaps")
				_check(_same(active.next_pass.get_shader_parameter("outline_depth_offset"),0.0),"Fist rendering is unchanged by the cloth depth binding")
			if role in ["hair","face"]:
				_check(_same(active.next_pass.get_shader_parameter("outline_depth_offset"),0.0),name+": shared hair/face contour retains existing behavior")
			if name in ["eye_l","eye_r","mouth"]:
				face_parts+=1
				_check(not active.has_meta("native_role"),name+": expression atlas is not rebound as garment material")
	_check(weapons==2,"Both native fist models are present")
	_check(face_parts==3,"All three original expression atlas meshes remain separate")
	var evidence=JSON.parse_string(FileAccess.get_file_as_string("res://assets/night-squire-autumn/secondary-source.json"))
	_check(evidence.dynamicBoneComponents==8 and evidence.dynamicBoneColliders==2,"Original attachment component counts are recorded without claiming a migrated solver")
	var report={"suite":"night_squire_autumn_material","passed":failures.is_empty(),"checks":checks,"failures":failures,"weaponMaterials":weapons,"expressionMeshes":face_parts}
	FileAccess.open("res://build/reports/night-squire-autumn-material.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));actor.free();quit(0 if failures.is_empty() else 1)
