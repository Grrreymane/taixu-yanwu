extends SceneTree
## Validate displayed geometry independently of the production bounds helper,
## including every selectable appearance and the native Sentience scene.
const Roster=preload("res://scripts/fighter_roster.gd")
const Sentience=preload("res://scripts/sentience_profile.gd")
var checks:=0
var failures: Array[String]=[]
var observations: Array=[]
class InspectActor extends "res://scripts/actor.gd":
	var normalize_calls:=0
	var pose_before: Array[Transform3D]=[]
	var pose_after: Array[Transform3D]=[]
	func _normalize_model() -> void:
		normalize_calls+=1
		for bone in skeleton.get_bone_count():pose_before.append(skeleton.get_bone_pose(bone))
		super._normalize_model()
		for bone in skeleton.get_bone_count():pose_after.append(skeleton.get_bone_pose(bone))
class ErrorRecorder extends Logger:
	var errors: Array=[]
	func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type!=Logger.ERROR_TYPE_WARNING:errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("CHECK FAILED: ",label)
func _delta(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _v(array: Array) -> Vector3:return Vector3(array[0],array[1],array[2])
func _baseline() -> Dictionary:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/model-normalization-baseline.json"))
	return fixture.actors
func _selections() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for character: Dictionary in Roster.list_characters():
		for style: Dictionary in Roster.list_styles(str(character.id)):
			for skin: Dictionary in Roster.list_appearances(str(character.id),str(style.id)):
				result.append(Roster.resolve(str(character.id),str(style.id),str(skin.id)))
	result.append(Sentience.selection())
	return result
func _world_bounds(actor) -> AABB:
	# This independently expands actual vertex positions using the mesh's own
	# skeleton path; no get_aabb or production ModelBounds result is consulted.
	var points:=PackedVector3Array()
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
		var skeleton: Skeleton3D=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var transforms: Array[Transform3D]=[]
		if mesh.skin!=null and skeleton!=null:
			for index in mesh.skin.get_bind_count():
				var bone:=mesh.skin.get_bind_bone(index)
				if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(index))
				check(bone>=0 and bone<skeleton.get_bone_count(),"original skin bind resolves on its own skeleton: "+str(mesh.name))
				if bone<0 or bone>=skeleton.get_bone_count():return AABB()
				transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(index))
		for surface in mesh.mesh.get_surface_count():
			if str(mesh.name).to_lower()+":"+str(surface) in actor._visual.get("hiddenSurfaces",[]):continue
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones=arrays[Mesh.ARRAY_BONES]
			var weights=arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int=0 if bones==null or vertices.is_empty() else bones.size()/vertices.size()
			for index in vertices.size():
				var point:=Vector3.ZERO
				if transforms.is_empty() or stride==0:point=mesh.global_transform*vertices[index]
				else:
					for influence in stride:
						var weight: float=weights[index*stride+influence]
						if weight>0.0:point+=(transforms[int(bones[index*stride+influence])]*vertices[index])*weight
				points.append(point)
	if points.is_empty():return AABB()
	var result:=AABB(points[0],Vector3.ZERO)
	for point in points:result=result.expand(point)
	return result
func run() -> void:
	OS.add_logger(recorder)
	var baseline:=_baseline()
	var seen: Array[String]=[]
	for selection: Dictionary in _selections():
		var label:=str(selection.styleId)+"/"+str(selection.appearanceId)
		seen.append(label)
		var actor:=InspectActor.new()
		root.add_child(actor)
		actor.setup(false,selection)
		check(actor.ready_for_combat,label+" loads its real model")
		check(actor.normalize_calls==1,label+" measures once during setup")
		var maximum_pose_error:=0.0
		for bone in actor.pose_before.size():maximum_pose_error=maxf(maximum_pose_error,_delta(actor.pose_before[bone],actor.pose_after[bone]))
		check(maximum_pose_error<0.000001,label+" normalization restores every sampled bone without poisoning setup")
		var pelvis: Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor._root_bone).origin
		check(absf(pelvis.x)<0.00001 and absf(pelvis.z)<0.00001,label+" sampled pelvis remains centered on the gameplay origin")
		var telemetry: Dictionary=actor.presentation_snapshot().normalization
		# C2 exports use centimetres; the reference can be 0.0178 before the
		# existing scene unit conversion. Verify final height, not import units.
		check(telemetry.reference=="native_neutral_skinned" and telemetry.vertices>0 and telemetry.height>0.0 and absf(float(telemetry.height)*float(telemetry.scale)-float(actor._visual.height))<0.00003,label+" reports the actual original neutral reference")
		var retained: Array[Transform3D]=[]
		for bone in actor.skeleton.get_bone_count():
			retained.append(actor.skeleton.get_bone_pose(bone))
			actor.skeleton.set_bone_pose(bone,actor._imported_base_pose[bone])
		var neutral_world:=_world_bounds(actor)
		check(absf(neutral_world.size.y-float(actor._visual.height))<0.00003,label+" actual neutral skinned vertex height is the configured 2.85")
		check(absf(neutral_world.position.y)<0.00003,label+" actual neutral feet remain grounded")
		if label=="sentience/default":
			actor.set_enemy_style(Color.WHITE,true)
			var boss_bounds:=_world_bounds(actor)
			check(absf(boss_bounds.size.y-neutral_world.size.y)<0.00003 and actor.scale==Vector3.ONE,"sparring/final boss designation never enlarges Sentience")
			actor.set_enemy_style(Color.WHITE,false)
		for bone in retained.size():actor.skeleton.set_bone_pose(bone,retained[bone])
		if label in ["azure_empyrea/default","azure_empyrea/taixu_memory","fenghuang/default","sentience/default"]:
			var old: Dictionary=baseline[label]
			check(actor._pivot.scale.distance_to(_v(old.scale))<0.00002,label+" preserves the existing display scale")
			check(actor._pivot.position.distance_to(_v(old.position))<0.00002,label+" preserves prior floor and pelvis alignment")
		if label=="night_squire/default":
			check(absf(actor._pivot.scale.y-1.5968492)<0.00002,"white display removes the accidental extra ten percent")
			var bone: int=actor.skeleton.find_bone("Avatar_Fuka_C3_ND")
			check(bone>=0 and is_equal_approx(actor.skeleton.get_bone_pose_scale(bone).y,1.1),"white original 1.1 root bone remains intact; no bones are rescaled")
		var initial_scale: Vector3=actor._pivot.scale
		var clip: String=actor._prefix+str(actor._motions.idle.clip)
		for clock: float in [0.0,0.37,1.1,1.95,4.5]:actor.animate_native_dialogue(clip,float(actor._motions.idle.end),clock,-1.0,0.25)
		check(actor._pivot.scale==initial_scale and actor.normalize_calls==1,label+" native animation poses never change the display scale")
		observations.append({"actor":label,"boneCount":actor.skeleton.get_bone_count(),"scale":initial_scale.y,"nativeNeutralHeight":telemetry.height,"neutralWorldHeight":neutral_world.size.y,"neutralFloor":neutral_world.position.y,"setupBoneError":maximum_pose_error})
		actor.free()
	check(seen.has("night_squire/default") and seen.has("sentience/default"),"both sides of the reported height mismatch were measured")
	await process_frame
	check(recorder.errors.is_empty(),"all selectable appearances load and normalize without engine errors")
	var report={"suite":"model_normalization","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"variants":seen,"observations":observations,"gpuUsed":false}
	FileAccess.open("res://build/reports/model-normalization-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	OS.remove_logger(recorder)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
