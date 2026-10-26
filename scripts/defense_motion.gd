extends RefCounted
## Lighter's original body motion, baked into Fu Hua's rest axes and bone lengths.
const LIBRARY: AnimationLibrary = preload("res://assets/motions/lighter-defense.res")
var _library: AnimationLibrary = LIBRARY
var _full_grounding := false
var _bones: Array[int] = []
var _drapes: Array[Dictionary] = []
var _foot_ids: Array[int] = []
var _floor_height := 0.0

func setup(skeleton: Skeleton3D, library_path: String = "", full_grounding: bool = false) -> void:
	if not library_path.is_empty(): _library=load(library_path) as AnimationLibrary
	_full_grounding=full_grounding
	var clip := _library.get_animation("Attack_ParryAid_H")
	for track in clip.get_track_count():
		_bones.append(skeleton.find_bone(str(clip.track_get_path(track).get_subname(0))))
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if (bone_name.begins_with("Fuka_C5_Skirt_") and bone_name.ends_with("_01")) or bone_name in ["Fuka_C5_Hair_B_01","Fuka_C5_pifeng_L_01","Fuka_C5_pifeng_R_01","Fuka_C5_guashi_B_01"]:
			_drapes.append({"bone":i,"parent":skeleton.get_bone_parent(i),"stability":0.66 if "Hair" in bone_name else 0.82})
	_foot_ids = [skeleton.find_bone("Bip001 L Foot"),skeleton.find_bone("Bip001 R Foot")]
	_floor_height = minf(skeleton.get_bone_global_pose(_foot_ids[0]).origin.y,skeleton.get_bone_global_pose(_foot_ids[1]).origin.y)

func apply_pose(skeleton: Skeleton3D, clip_name: String, time: float, weight: float) -> void:
	if weight<=0.000001 or not _library.has_animation(clip_name): return
	var clip := _library.get_animation(clip_name)
	var t := clampf(time,0.0,clip.length)
	var original_drapes: Array[Basis] = []
	var original_parents: Array[Basis] = []
	for drape: Dictionary in _drapes:
		original_drapes.append(skeleton.get_bone_global_pose(drape.bone).basis.orthonormalized())
		original_parents.append(skeleton.get_bone_global_pose(drape.parent).basis.orthonormalized())
	for track in clip.get_track_count():
		var bone: int = _bones[track]
		if bone<0: continue
		if clip.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			var target := clip.rotation_track_interpolate(track,t)
			skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(target,weight))
		elif clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
			var target := clip.position_track_interpolate(track,t)
			skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(target,weight))
	# Keep the native long cloth hanging under gravity when a boxing torso bends.
	# Follow the parent's yaw, while reducing its sudden pitch/roll transfer.
	for i in _drapes.size():
		var drape: Dictionary = _drapes[i]
		var parent := skeleton.get_bone_global_pose(drape.parent).basis.orthonormalized()
		var change := parent*original_parents[i].inverse()
		var yaw := Basis(Vector3.UP,change.get_euler().y)
		var hanging := yaw*original_drapes[i]
		var current := skeleton.get_bone_global_pose(drape.bone).basis.orthonormalized()
		var stable := current.get_rotation_quaternion().slerp(hanging.get_rotation_quaternion(),float(drape.stability)*weight)
		skeleton.set_bone_pose_rotation(drape.bone,(parent.inverse()*Basis(stable)).get_rotation_quaternion())
	var root_id: int = _bones[0]
	var root_pos := skeleton.get_bone_pose_position(root_id)
	var foot_y := minf(skeleton.get_bone_global_pose(_foot_ids[0]).origin.y,skeleton.get_bone_global_pose(_foot_ids[1]).origin.y)
	root_pos.y += (_floor_height-foot_y)*(1.0 if _full_grounding else weight)
	skeleton.set_bone_pose_position(root_id,root_pos)
