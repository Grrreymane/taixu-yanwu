extends SceneTree
var SOURCE=ProjectSettings.globalize_path("res://../hi3-fuhua-extract/exports/c5-menu-original/original/FBX/a303f703da40756b/-8681997045896087424/Avatar_Fuka_C5_IN.fbx")
const Roster=preload("res://scripts/fighter_roster.gd")
func _find(node:Node,kind:String) -> Node:
	if node.is_class(kind):return node
	for child in node.get_children():
		var found:=_find(child,kind)
		if found!=null:return found
	return null
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var doc:=FBXDocument.new();var state:=FBXState.new();state.handle_binary_image_mode=0;state.use_named_skin_binds=true
	assert(doc.append_from_file(SOURCE,state,0,"res://assets/azure")==OK)
	var source:=doc.generate_scene(state,30.0,true,true);root.add_child(source)
	var player:AnimationPlayer=_find(source,"AnimationPlayer")
	var rows:Array=[]
	for appearance:String in ["default","taixu_memory"]:
		var target=load(Roster.resolve("fuhua","azure_empyrea",appearance).actor.modelPath).instantiate();root.add_child(target)
		var skeleton:Skeleton3D=_find(target,"Skeleton3D")
		var target_player:AnimationPlayer=_find(target,"AnimationPlayer")
		var skeleton_path:NodePath=target_player.get_node(target_player.root_node).get_path_to(skeleton)
		var library:=AnimationLibrary.new()
		for name:StringName in player.get_animation_list():
			var anim:Animation=player.get_animation(name).duplicate(true)
			var removed:Array=[]
			for track in range(anim.get_track_count()-1,-1,-1):
				var path:=anim.track_get_path(track)
				if path.get_subname_count()==1 and skeleton.find_bone(path.get_subname(0))>=0:anim.track_set_path(track,NodePath(str(skeleton_path)+":"+str(path.get_subname(0))))
				else:removed.append(str(path));anim.remove_track(track)
			anim.length=2.0;anim.loop_mode=Animation.LOOP_LINEAR
			# Preserve the actual source two-second take; FBX's padded tail is
			# replaced only by its exact interpolated endpoint.
			for track in anim.get_track_count():
				var value:Variant
				match anim.track_get_type(track):
					Animation.TYPE_POSITION_3D:value=anim.position_track_interpolate(track,2.0)
					Animation.TYPE_ROTATION_3D:value=anim.rotation_track_interpolate(track,2.0)
					Animation.TYPE_SCALE_3D:value=anim.scale_track_interpolate(track,2.0)
					_:assert(false)
				for key in range(anim.track_get_key_count(track)-1,-1,-1):
					if anim.track_get_key_time(track,key)>=2.0:anim.track_remove_key(track,key)
				anim.track_insert_key(track,2.0,value)
			library.add_animation(name,anim)
			rows.append({"appearance":appearance,"name":str(name),"tracks":anim.get_track_count(),"removed":removed})
		assert(ResourceSaver.save(library,"res://build/reports/azure-menu-"+appearance+".res",ResourceSaver.FLAG_COMPRESS)==OK)
		target.free()
	FileAccess.open("res://build/reports/azure-native-menu-source.json",FileAccess.WRITE).store_string(JSON.stringify({"source":SOURCE,"animations":rows},"  "))
	for row in rows:print(row.appearance," ",row.name," retained=",row.tracks," missing=",row.removed.size())
	source.free();state=null;doc=null
	await process_frame;quit()
