extends SceneTree
## Native outfit integration only: separate original rig/skin/materials, shared
## original ND body takes, real equipment, and no synthetic clothing retarget.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Skins=preload("res://assets/night-squire-skins/roster.gd")
const Bounds=preload("res://scripts/model_bounds.gd")
const EXPECTED={"spring_traveler":{"bones":75,"name":"春风之旅","bodySurfaces":2,"empty":[1]},"xuanyi_sushang":{"bones":94,"name":"玄衣素裳","bodySurfaces":5,"empty":[1,4]},"black_butler":{"bones":78,"name":"黑执事","bodySurfaces":2,"empty":[1]}}
var checks:=0
var failures:Array[String]=[]
var appearances:Array=[]
func _initialize()->void:call_deferred("_run")
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _find(node:Node,kind:String)->Node:
	if node.is_class(kind):return node
	for child in node.get_children():
		var found=_find(child,kind)
		if found:return found
	return null
func _run()->void:
	_check(Skins.ORDERED_IDS==["default","autumn_leaves","spring_traveler","xuanyi_sushang","black_butler"],"Complete audited client outfit ordering includes the official recolor")
	_check(Skins.APPEARANCES.size()==3,"Package supplies exactly the three newly missing outfits")
	var donor=load("res://assets/night-squire/Avatar_Fuka_C3_ND.scn").instantiate();root.add_child(donor)
	var original_player:AnimationPlayer=_find(donor,"AnimationPlayer")
	for id in EXPECTED:
		var skin:Dictionary=Skins.APPEARANCES[id]
		_check(skin.name==EXPECTED[id].name and skin.styleId=="night_squire",id+" is the audited original C3 outfit")
		var choice=Roster.resolve("fuhua","night_squire","default")
		choice.appearanceId=id;choice.appearance=skin.duplicate(true)
		for field in ["modelPath","textureDir","visual","rig"]:choice.actor[field]=skin[field].duplicate(true) if skin[field] is Dictionary else skin[field]
		var actor=Actor.new();root.add_child(actor);actor.setup(false,choice)
		_check(actor.ready_for_combat and actor._victory_available,id+" initializes native combat and victory")
		_check(actor.skeleton.get_bone_count()==EXPECTED[id].bones,id+" retains its own original rig")
		var imported=load(skin.modelPath).instantiate();root.add_child(imported)
		var source_skeleton:Skeleton3D=_find(imported,"Skeleton3D")
		for bone in actor.skeleton.get_bone_count():actor.skeleton.set_bone_pose(bone,source_skeleton.get_bone_pose(bone))
		var measure:Dictionary=Bounds.measure(actor.model,actor.skeleton,skin.visual.hiddenSurfaces)
		_check(absf(measure.bounds.size.y*actor._pivot.scale.y-2.85)<.001,id+" actual original skinned neutral height normalizes correctly")
		_check(absf((actor._pivot.transform*Vector3(0,measure.bounds.position.y,0)).y)<.001,id+" neutral lowest visible vertex meets floor")
		var body:MeshInstance3D=actor.model.find_child("Body",true,false)
		_check(body.mesh.get_surface_count()==EXPECTED[id].bodySurfaces,id+" keeps every original body surface")
		for slot in EXPECTED[id].empty:
			var material=body.get_active_material(slot)
			_check(material is StandardMaterial3D and material.albedo_color.a==0,id+" audited CommonEmpty remains invisible "+str(slot))
		var fists:=0;var eyes:=0;var native_skins:=0
		for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
			var raw:MeshInstance3D=imported.find_child(mesh.name,true,false)
			var same:=raw!=null and raw.skin!=null and mesh.skin!=null and raw.skin.get_bind_count()==mesh.skin.get_bind_count()
			if same:
				for bind in mesh.skin.get_bind_count():same=same and mesh.skin.get_bind_pose(bind).is_equal_approx(raw.skin.get_bind_pose(bind))
			_check(same,id+" preserves source Skin matrices: "+str(mesh.name));native_skins+=1
			if mesh.name.begins_with("NativeFist"):
				fists+=1
				var source:MeshInstance3D=donor.find_child(mesh.name,true,false)
				_check(source.mesh.get_surface_count()==mesh.mesh.get_surface_count(),id+" equipped native hand surfaces exist")
				for surface in mesh.mesh.get_surface_count():
					var a=mesh.mesh.surface_get_arrays(surface);var b=source.mesh.surface_get_arrays(surface)
					_check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_BONES]==b[Mesh.ARRAY_BONES] and a[Mesh.ARRAY_WEIGHTS]==b[Mesh.ARRAY_WEIGHTS],id+" gauntlet vertices and weights remain original")
				_check(mesh.get_active_material(0).get_meta("native_role","")=="weapon",id+" original fist material completes the hidden hand slot")
			if str(mesh.name).to_lower() in ["eye_l","eye_r","mouth"]:eyes+=1
		_check(fists==2 and eyes==3 and native_skins==8,id+" has two full original gauntlets and three expression atlas meshes")
		var same_body_curves:=0
		for clip_name in actor.animation_player.get_animation_list():
			if not str(clip_name).begins_with("Avatar_Fuka_Ani_"):continue
			_check(original_player.has_animation(clip_name),id+" uses an existing ND take: "+str(clip_name))
			var clip:Animation=actor.animation_player.get_animation(clip_name)
			var source:Animation=original_player.get_animation(clip_name)
			var preserved:=true
			for track in clip.get_track_count():
				var path=clip.track_get_path(track)
				if path.get_subname_count()!=1:continue
				var name:String=path.get_subname(0)
				if not name.begins_with("Bip001"):continue
				var source_track:=source.find_track(NodePath("Skeleton3D:"+name),clip.track_get_type(track))
				if source_track<0:preserved=false;continue
				preserved=preserved and clip.track_get_key_count(track)==source.track_get_key_count(source_track)
				for key in clip.track_get_key_count(track):
					preserved=preserved and clip.track_get_key_time(track,key)==source.track_get_key_time(source_track,key) and clip.track_get_key_value(track,key)==source.track_get_key_value(source_track,key)
			_check(preserved,id+" exact original body key values and times retained: "+str(clip_name));same_body_curves+=1
		_check(same_body_curves==23,id+" retains all23 original ND body takes")
		for key in choice.actor.motions:
			_check(actor.animation_player.has_animation(choice.actor.prefix+choice.actor.motions[key].clip),id+" supports battle motion "+str(key))
		_check(ResourceLoader.exists(skin.portraitPath),id+" has its own imported original portrait")
		appearances.append({"id":id,"bones":actor.skeleton.get_bone_count(),"meshes":native_skins,"motions":same_body_curves,"fists":fists})
		actor.free();imported.free()
	donor.free()
	var report={"suite":"night_squire_skins","checks":checks,"passed":failures.is_empty(),"failures":failures,"appearances":appearances,"gpuUsed":false}
	FileAccess.open("res://build/reports/night-squire-skins.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
