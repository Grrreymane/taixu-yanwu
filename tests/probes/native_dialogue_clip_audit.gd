extends SceneTree
## Read-only audit of shipped scenes/libraries. No Actor controllers, authored
## overlays, masks, root locks, face drivers or secondary solvers are invoked.
const Roster=preload("res://scripts/fighter_roster.gd")
const Senti=preload("res://scripts/sentience_profile.gd")
var results: Array=[]
var player: AnimationPlayer
var skeleton: Skeleton3D
var nodes: Array[Node3D]=[]
var initial_transforms: Array[Transform3D]=[]
var initial_bones: Array[Transform3D]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for choice: Dictionary in [Roster.resolve("fuhua","azure_empyrea","default"),Roster.resolve("fuhua","azure_empyrea","taixu_memory"),Roster.resolve("fuhua","fenghuang","default"),Senti.selection()]:
		var config: Dictionary=choice.actor
		var packed:=load(str(config.modelPath)) as PackedScene
		var model:=packed.instantiate()
		root.add_child(model)
		nodes.clear(); initial_transforms.clear(); initial_bones.clear()
		_scan(model)
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if not str(config.get("animationLibraryPath","")).is_empty():
			player.add_animation_library(str(config.animationLibraryName),load(str(config.animationLibraryPath)))
		var victory: Dictionary=config.get("victory",{})
		if not str(victory.get("libraryPath","")).is_empty() and not player.has_animation_library("presentation"):
			player.add_animation_library("presentation",load(str(victory.libraryPath)))
		for node in nodes: initial_transforms.append(node.transform)
		for bone in skeleton.get_bone_count(): initial_bones.append(skeleton.get_bone_pose(bone))
		var actor_report: Dictionary={"style":choice.styleId,"appearance":choice.appearanceId,"model":config.modelPath,"boneCount":skeleton.get_bone_count(),"allActualClips":player.get_animation_list(),"clips":[]}
		for clip_name: String in player.get_animation_list():
			var lower:=clip_name.to_lower()
			if not ("standby" in lower or "idle" in lower or "combat" in lower or "victory" in lower): continue
			var clip:=player.get_animation(clip_name)
			var duration:=clip.length
			if clip_name=="Avatar_Fuka_Ani_C5_StandBy": duration=2.016666602881322
			if clip_name in ["Avatar_Fuka_Ani_StandBy","Avatar_Fuka_Ani_Combat","Avatar_Fuka_Ani_Victory_idle"]: duration=2.0
			if clip_name=="Avatar_Fuka_Ani_Victory": duration=4.316667
			var info: Dictionary={"name":clip_name,"resourceDuration":clip.length,"fullSourceDuration":duration,"runtimeLoopMode":clip.loop_mode,"tracks":clip.get_track_count(),"propTracks":[],"faceTracks":[],"nonBoneTracks":[]}
			for track in clip.get_track_count():
				var track_path:=str(clip.track_get_path(track))
				var detail: Dictionary={"path":track_path,"type":clip.track_get_type(track),"keys":clip.track_get_key_count(track),"constant":_constant(clip,track)}
				if "weapon" in track_path.to_lower() or "umbrella" in track_path.to_lower() or "sickle" in track_path.to_lower(): info.propTracks.append(detail)
				if "eye" in track_path.to_lower() or "mouth" in track_path.to_lower() or "face" in track_path.to_lower() or clip.track_get_type(track)==Animation.TYPE_BLEND_SHAPE: info.faceTracks.append(detail)
				if not ":" in track_path: info.nonBoneTracks.append(detail)
			var root_id:=skeleton.find_bone("Bip001")
			var feet: Array=[skeleton.find_bone("Bip001 L Foot"),skeleton.find_bone("Bip001 R Foot")]
			var first_pose: Array=[]
			var root_min:=Vector3(INF,INF,INF)
			var root_max:=Vector3(-INF,-INF,-INF)
			var foot_min:=INF
			var foot_max:=-INF
			var first_root:=Vector3.ZERO
			var max_root_shift:=0.0
			var max_body_change:=0.0
			var frame_count:=int(ceil(duration*30.0))+1
			player.play(clip_name)
			for frame in frame_count:
				for i in nodes.size(): nodes[i].transform=initial_transforms[i]
				for i in initial_bones.size(): skeleton.set_bone_pose(i,initial_bones[i])
				var at:=minf(duration-0.00001,float(frame)/30.0)
				player.seek(at,true)
				player.advance(0.0)
				var current_root:=skeleton.get_bone_pose_position(root_id)
				if frame==0:
					first_root=current_root
					info.rootStart=_v(current_root)
					for i in skeleton.get_bone_count(): first_pose.append(skeleton.get_bone_pose(i))
				root_min=root_min.min(current_root); root_max=root_max.max(current_root)
				max_root_shift=maxf(max_root_shift,current_root.distance_to(first_root))
				for foot: int in feet:
					var floor:=skeleton.get_bone_global_pose(foot).origin.y
					foot_min=minf(foot_min,floor); foot_max=maxf(foot_max,floor)
				var max_angle:=0.0
				for i in skeleton.get_bone_count():
					if not str(skeleton.get_bone_name(i)).begins_with("Bip001"): continue
					var a:=Transform3D(first_pose[i]).basis.orthonormalized().get_rotation_quaternion()
					var b:=skeleton.get_bone_pose_rotation(i)
					max_angle=maxf(max_angle,a.angle_to(b))
				max_body_change=maxf(max_body_change,max_angle)
				if frame==frame_count-1:
					info.seamBodyAngle=max_angle
					info.seamRootPosition=current_root.distance_to(first_root)
					var final_pose: Array=[]
					for bone in skeleton.get_bone_count(): final_pose.append(skeleton.get_bone_pose(bone))
					info.exactLoopSeam=_difference(first_pose,final_pose)
			info.rootRange=_v(root_max-root_min)
			info.maxRootDisplacement=max_root_shift
			info.footHeightRange=[foot_min,foot_max]
			info.maxBodyAngleChange=max_body_change
			info.samples=frame_count
			actor_report.clips.append(info)
		if str(choice.styleId)=="sentience":
			var idle_first:=_sample_pose("native/Idle",0.0)
			var idle_last:=_sample_pose("native/Idle",4.2333336-0.00001)
			var standby_first:=_sample_pose("native/Standby",0.0)
			actor_report.idleToStandby={"firstToFirst":_difference(idle_first,standby_first),"lastToFirst":_difference(idle_last,standby_first),"idleEndToStart":_difference(idle_last,idle_first)}
			print("C6_HANDOFF "+JSON.stringify(actor_report.idleToStandby))
		results.append(actor_report)
		model.free()
	var report: Dictionary={"scope":"Actual shipped resources; unmodified full-body sampling, no Actor, no overlays, no renderer. Units are original imported scene units before display normalization.","actors":results}
	FileAccess.open("res://build/reports/native-dialogue-clip-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for item in results:
		for clip in item.clips:
			print(JSON.stringify({"actor":str(item.style)+"/"+str(item.appearance),"clip":clip.name,"duration":clip.fullSourceDuration,"resourceDuration":clip.resourceDuration,"loop":clip.runtimeLoopMode,"rootStart":clip.rootStart,"rootRange":clip.rootRange,"footY":clip.footHeightRange,"seamBodyAngle":clip.seamBodyAngle,"maxBodyAngleChange":clip.maxBodyAngleChange,"propTracks":clip.propTracks.size(),"faceTracks":clip.faceTracks.size()}))
	quit()

func _scan(node: Node) -> void:
	if node is AnimationPlayer: player=node
	if node is Skeleton3D: skeleton=node
	if node is Node3D: nodes.append(node)
	for child in node.get_children(): _scan(child)

func _v(value: Vector3) -> Array: return [value.x,value.y,value.z]

func _sample_pose(clip_name: String,at: float) -> Array:
	for i in nodes.size(): nodes[i].transform=initial_transforms[i]
	for i in initial_bones.size(): skeleton.set_bone_pose(i,initial_bones[i])
	player.play(clip_name)
	player.seek(at,true)
	player.advance(0.0)
	var pose: Array=[]
	for i in skeleton.get_bone_count(): pose.append(skeleton.get_bone_pose(i))
	return pose

func _difference(a: Array,b: Array) -> Dictionary:
	var result: Dictionary={"allBoneAngle":0.0,"allBoneTranslation":0.0,"bodyBoneAngle":0.0,"bodyBoneTranslation":0.0,"worstBone":"","rootDistance":0.0}
	for i in a.size():
		var aa: Transform3D=a[i]
		var bb: Transform3D=b[i]
		var relative:=aa.basis.orthonormalized().get_rotation_quaternion().inverse()*bb.basis.orthonormalized().get_rotation_quaternion()
		var angle:=2.0*atan2(Vector3(relative.x,relative.y,relative.z).length(),absf(relative.w))
		var distance:=aa.origin.distance_to(bb.origin)
		if angle>float(result.allBoneAngle): result.worstBone=skeleton.get_bone_name(i)
		result.allBoneAngle=maxf(result.allBoneAngle,angle)
		result.allBoneTranslation=maxf(result.allBoneTranslation,distance)
		if str(skeleton.get_bone_name(i)).begins_with("Bip001"):
			result.bodyBoneAngle=maxf(result.bodyBoneAngle,angle)
			result.bodyBoneTranslation=maxf(result.bodyBoneTranslation,distance)
		if str(skeleton.get_bone_name(i))=="Bip001": result.rootDistance=distance
	return result

func _constant(clip: Animation,track: int) -> bool:
	if clip.track_get_key_count(track)<2: return true
	var first=clip.track_get_key_value(track,0)
	for key in range(1,clip.track_get_key_count(track)):
		if clip.track_get_key_value(track,key)!=first: return false
	return true
