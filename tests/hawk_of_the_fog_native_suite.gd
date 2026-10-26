extends SceneTree
## Resource integration checks against the imported native rig, without GPU use.
const Fog = preload("res://assets/hawk-of-the-fog/roster.gd")
const Actor = preload("res://scripts/actor.gd")
const Bounds = preload("res://scripts/model_bounds.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _run() -> void:
	var style := Fog.STYLE.duplicate(true)
	var skin: Dictionary = Fog.APPEARANCES.default.duplicate(true)
	var config := {"modelPath":skin.modelPath,"textureDir":skin.textureDir,"prefix":style.prefix,
		"motions":style.motions,"attackPacing":style.attackPacing,"visual":skin.visual,
		"defense":style.defense,"victory":style.victory,"combatProfile":style.combatProfile,"rig":skin.rig}
	var actor := Actor.new();root.add_child(actor);actor.setup(false,{"actor":config})
	_check(actor.ready_for_combat,"Original Fog actor initializes")
	_check(actor.skeleton.get_bone_count()==154,"Own original C1_05_01 rig retains all154 bones")
	_check(actor.animation_player.get_animation_list().size()>=27,"All27 selected original clips are retained")
	_check(actor._victory_available,"Native FK_AF01 victory take is recognized")
	_check(actor._native_guard,"Defense uses existing native motions")
	_check(actor._normalization.height>1.4 and actor._normalization.height<2.2,"Neutral body uses meters consistent with native weapon")
	var skirt_bones:=0
	for bone in actor.skeleton.get_bone_count():
		if "C1_05_01_Skirt" in actor.skeleton.get_bone_name(bone):skirt_bones+=1
	_check(skirt_bones>=8,"Outfit-specific skirt bones remain on their own skeleton")
	for key in style.motions:
		var motion:Dictionary=style.motions[key]
		var name:String=style.prefix+motion.clip
		_check(actor.animation_player.has_animation(name),key+" selects an existing original clip")
		var anim=actor.animation_player.get_animation(name)
		_check(float(motion.end)<=anim.length+.0001,key+" stays inside its source take")
		if motion.has("contact"):_check(float(motion.contact)>0 and float(motion.contact)<float(motion.end),key+" contact lies in its source take")
		var previous_contact:=0.0
		for contact in motion.get("contacts",[]):
			_check(float(contact)>previous_contact and float(contact)<float(motion.end),key+" source contacts strictly increase within the take")
			previous_contact=float(contact)
		actor.animation_player.play(name)
		for fraction in [0.0,0.25,0.5,0.75,0.999]:
			actor.animation_player.seek(float(motion.end)*fraction,true);actor.animation_player.advance(0.0)
			var finite:=true
			for b in actor.skeleton.get_bone_count():finite=finite and actor.skeleton.get_bone_global_pose(b).is_finite()
			_check(finite,key+" has finite original bones at "+str(fraction))
	var meshes=actor.model.find_children("*","MeshInstance3D",true,false)
	_check(meshes.size()==9,"Seven original renderers plus two original equipped fists")
	var fists:=0
	for mesh:MeshInstance3D in meshes:
		if mesh.name.begins_with("NativeFist"):fists+=1
		_check(mesh.skin!=null,str(mesh.name)+" retains a Skin")
		if mesh.skin==null:continue
		var weighted:Dictionary={}
		for surface in mesh.mesh.get_surface_count():
			var a=mesh.mesh.surface_get_arrays(surface)
			for i in a[Mesh.ARRAY_BONES].size():
				if a[Mesh.ARRAY_WEIGHTS][i]>.00001:weighted[int(a[Mesh.ARRAY_BONES][i])]=true
		for index in weighted:
			var bind_name=mesh.skin.get_bind_name(index)
			var bone:int=actor.skeleton.find_bone(bind_name) if not str(bind_name).is_empty() else mesh.skin.get_bind_bone(index)
			_check(bone>=0 and bone<actor.skeleton.get_bone_count(),str(mesh.name)+" original weighted bind resolves: "+str(index))
	_check(fists==2,"Both equipped original gauntlets retained")
	var body:MeshInstance3D=actor.model.find_child("Body",true,false)
	var body_material=body.get_active_material(0)
	_check(body_material.get_meta("native_material","")=="Avatar_Fuka_C1_05_01_Material_Body","Own original body material is bound")
	_check(body.get_active_material(1) is StandardMaterial3D and body.get_active_material(1).albedo_color.a==0,"CommonEmpty stays invisible")
	_check(body.get_active_material(2).get_meta("native_role","")=="alpha","Original alpha surface remains independently identified")
	_check(ResourceLoader.exists(style.portraitPath),"Own original portrait is imported")
	var vfx:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hawk-of-the-fog/vfx-map.json"))
	for key in vfx:_check(ResourceLoader.exists(vfx[key]),"Native VFX resource exists: "+str(key))
	var report={"suite":"hawk_of_the_fog_native","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"bones":actor.skeleton.get_bone_count(),"skirtBones":skirt_bones,"meshes":meshes.size(),"nativeClips":actor.animation_player.get_animation_list().size()}
	FileAccess.open("res://build/reports/hawk-of-the-fog-native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));actor.free();quit(0 if failures.is_empty() else 1)
