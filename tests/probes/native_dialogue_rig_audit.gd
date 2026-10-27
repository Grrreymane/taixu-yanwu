extends SceneTree
## Read-only resource audit; deliberately never calls a presentation overlay.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Sentience=preload("res://scripts/sentience_profile.gd")
var rows:Array=[]
func _initialize() -> void: call_deferred("_run")
func _find(node:Node,kind:String) -> Node:
	if node.is_class(kind):return node
	for child in node.get_children():
		var found=_find(child,kind)
		if found!=null:return found
	return null
func _run() -> void:
	for selection in [Roster.resolve(),Roster.resolve("fuhua","azure_empyrea","taixu_memory"),Roster.resolve("fuhua","fenghuang","default"),Sentience.selection()]:
		var actor=Actor.new();root.add_child(actor);actor.setup(false,selection)
		var sk:Skeleton3D=actor.skeleton
		var raw=load(str(selection.actor.modelPath)).instantiate();root.add_child(raw)
		var raw_skeleton:Skeleton3D=_find(raw,"Skeleton3D")
		var row:Dictionary={"style":selection.styleId,"appearance":selection.appearanceId,"boneCount":sk.get_bone_count(),"clips":[]}
		for clip_name in actor.animation_player.get_animation_list():
			if not ("StandBy" in clip_name or "Idle" in clip_name or "Victory" in clip_name or "Combat" in clip_name):continue
			var clip:Animation=actor.animation_player.get_animation(clip_name)
			var body:Dictionary={};var auxiliary:Dictionary={};var skin_auxiliary:Dictionary={};var tracked:Dictionary={};var dynamic_auxiliary:Dictionary={}
			for track in clip.get_track_count():
				var path:NodePath=clip.track_get_path(track)
				if path.get_subname_count()!=1:continue
				var name:=str(path.get_subname(0))
				var bone:=sk.find_bone(name)
				if bone<0:continue
				var kind:=clip.track_get_type(track)
				tracked[name+":"+str(kind)]=true
				if name.begins_with("Bip001"):body[name]=true
				else:
					auxiliary[name]=true
					if name.begins_with("Fuka_C5_04_02_"):skin_auxiliary[name]=true
					for key in range(1,clip.track_get_key_count(track)):
						var value=clip.track_get_key_value(track,key)
						var first=clip.track_get_key_value(track,0)
						if not value.is_equal_approx(first):dynamic_auxiliary[name]=true;break
			var unkeyed_differences:Array=[];var significant_unkeyed:Array=[];var source_vs_initial:Array=[]
			for bone in sk.get_bone_count():
				var name:=str(sk.get_bone_name(bone));var rest:=sk.get_bone_rest(bone);var base:Transform3D=actor._source_base_pose[bone]
				if not tracked.has(name+":"+str(Animation.TYPE_ROTATION_3D)) and not rest.basis.orthonormalized().get_rotation_quaternion().is_equal_approx(base.basis.orthonormalized().get_rotation_quaternion()):unkeyed_differences.append(name+":rotation")
				if not tracked.has(name+":"+str(Animation.TYPE_POSITION_3D)) and not rest.origin.is_equal_approx(base.origin):unkeyed_differences.append(name+":position")
				if not tracked.has(name+":"+str(Animation.TYPE_SCALE_3D)) and not rest.basis.get_scale().is_equal_approx(base.basis.get_scale()):unkeyed_differences.append(name+":scale")
				var angle:=rest.basis.orthonormalized().get_rotation_quaternion().angle_to(base.basis.orthonormalized().get_rotation_quaternion())
				if not tracked.has(name+":"+str(Animation.TYPE_ROTATION_3D)) and angle>0.01:significant_unkeyed.append({"bone":name,"channel":"rotation","difference":angle})
				if not tracked.has(name+":"+str(Animation.TYPE_POSITION_3D)) and rest.origin.distance_to(base.origin)>0.001:significant_unkeyed.append({"bone":name,"channel":"position","difference":rest.origin.distance_to(base.origin)})
				if not tracked.has(name+":"+str(Animation.TYPE_SCALE_3D)) and rest.basis.get_scale().distance_to(base.basis.get_scale())>0.001:significant_unkeyed.append({"bone":name,"channel":"scale","difference":rest.basis.get_scale().distance_to(base.basis.get_scale())})
				var initial:=raw_skeleton.get_bone_pose(raw_skeleton.find_bone(name))
				if not tracked.has(name+":"+str(Animation.TYPE_ROTATION_3D)) and initial.basis.orthonormalized().get_rotation_quaternion().angle_to(base.basis.orthonormalized().get_rotation_quaternion())>0.01:source_vs_initial.append(name+":rotation")
				if not tracked.has(name+":"+str(Animation.TYPE_POSITION_3D)) and initial.origin.distance_to(base.origin)>0.001:source_vs_initial.append(name+":position")
			row.clips.append({"name":clip_name,"length":clip.length,"tracks":clip.get_track_count(),"bodyBones":body.size(),"auxiliaryBones":auxiliary.size(),"skinSpecificAuxiliaryBones":skin_auxiliary.size(),"dynamicAuxiliaryBones":dynamic_auxiliary.keys(),"unkeyedStandByBaseVersusRest":unkeyed_differences,"significantUnkeyedDifferences":significant_unkeyed,"sourceBaseVersusInitialSceneUnkeyed":source_vs_initial})
		if selection.appearanceId=="taixu_memory":
			var original=load("res://assets/azure-skin/Avatar.fbx").instantiate();root.add_child(original)
			var original_player:AnimationPlayer=_find(original,"AnimationPlayer")
			row.sourceSkinEmbeddedClips=original_player.get_animation_list() if original_player!=null else []
			row.secondaryBones=actor._secondary.snapshot().boneCount
			original.free()
		rows.append(row);actor.free();raw.free()
	var f=FileAccess.open("res://build/reports/native-dialogue-rig-audit.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"  "));f.close()
	print(JSON.stringify(rows));quit()
