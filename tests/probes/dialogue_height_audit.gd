extends SceneTree
## Read-only diagnostic of the actual StoryPresentation controller. Vertex
## positions use each original Skin's inverse binds and the live bone palette.
const Story = preload("res://scripts/story_presentation.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
class RawActor extends Node3D:
	var model: Node3D
	var skeleton: Skeleton3D
	var _pivot: Node3D
	var _visual: Dictionary
	var _native_dialogue_clip:="untouched packed scene"
	var source_time:=0.0
var report: Dictionary={"scope":"Actual StoryPresentation, unchanged full original clips; CPU skinning of visible source vertices, no bone edits, no GPU.","actors":[]}
func _initialize() -> void: call_deferred("run")
func v(p: Vector3) -> Array: return [p.x,p.y,p.z]
func box(b: AABB) -> Dictionary: return {"min":v(b.position),"max":v(b.end),"height":b.size.y}
func bone_point(actor,name: String) -> Array:
	var id: int=actor.skeleton.find_bone(name)
	return v(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(id).origin) if id>=0 else []
func _bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty(): return AABB()
	var result:=AABB(points[0],Vector3.ZERO)
	for point in points: result=result.expand(point)
	return result
func _node_scales(actor) -> Array:
	var result: Array=[]
	var nodes: Array=[actor,actor._pivot,actor.model,actor.skeleton]
	var parent: Node=actor.skeleton.get_parent()
	while parent!=actor and parent!=null:
		if parent is Node3D and not nodes.has(parent):nodes.append(parent)
		parent=parent.get_parent()
	for node in nodes:
		result.append({"path":str(actor.get_path_to(node)),"localScale":v(node.scale),"globalScale":v(node.global_transform.basis.get_scale()),"position":v(node.position)})
	return result
func _sample(actor,time: float) -> Dictionary:
	var all_points:=PackedVector3Array()
	var eye_points:=PackedVector3Array()
	var face_points:=PackedVector3Array()
	var foot_points:=PackedVector3Array()
	var meshes: Array=[]
	var static_bounds:=AABB()
	var static_first:=true
	var active_blends: Array=[]
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		var original_box: AABB=(actor.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		static_bounds=original_box if static_first else static_bounds.merge(original_box)
		static_first=false
		var palette: Array[Transform3D]=[]
		var foot_binds: Array[bool]=[]
		var skin_skeleton: Skeleton3D=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if mesh.skin!=null and skin_skeleton!=null:
			for bind in mesh.skin.get_bind_count():
				var id:=mesh.skin.get_bind_bone(bind)
				if id<0:id=skin_skeleton.find_bone(mesh.skin.get_bind_name(bind))
				assert(id>=0,"All source skin binds must resolve")
				palette.append(skin_skeleton.global_transform*skin_skeleton.get_bone_global_pose(id)*mesh.skin.get_bind_pose(bind))
				var name: String=skin_skeleton.get_bone_name(id)
				foot_binds.append("Foot" in name or "Toe" in name)
		var points:=PackedVector3Array()
		for blend in mesh.mesh.get_blend_shape_count():
			if absf(mesh.get_blend_shape_value(blend))>0.000001:active_blends.append({"mesh":mesh.name,"shape":mesh.mesh.get_blend_shape_name(blend),"weight":mesh.get_blend_shape_value(blend)})
		for surface in mesh.mesh.get_surface_count():
			if str(mesh.name).to_lower()+":"+str(surface) in actor._visual.get("hiddenSurfaces",[]): continue
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices=arrays[Mesh.ARRAY_BONES]
			var weights=arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int=0 if indices==null or vertices.is_empty() else indices.size()/vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				var foot_weight:=0.0
				if palette.is_empty() or stride==0:point=mesh.global_transform*vertices[vertex]
				else:
					for influence in stride:
						var weight: float=weights[vertex*stride+influence]
						if weight<=0.0:continue
						var bind: int=indices[vertex*stride+influence]
						point+=(palette[bind]*vertices[vertex])*weight
						if foot_binds[bind]:foot_weight+=weight
				points.append(point)
				all_points.append(point)
				var lower:=str(mesh.name).to_lower()
				if "eye" in lower and not "brow" in lower:eye_points.append(point)
				if lower=="face":face_points.append(point)
				if foot_weight>=0.5:foot_points.append(point)
		meshes.append({"name":mesh.name,"skeletonPath":str(mesh.skeleton),"localScale":v(mesh.scale),"globalScale":v(mesh.global_transform.basis.get_scale()),"inverseBindCount":palette.size(),"vertices":points.size(),"staticModelSpace":box(original_box),"actualWorldSpace":box(_bounds(points))})
	var eyes:=Vector3.ZERO
	for point in eye_points: eyes+=point
	if not eye_points.is_empty():eyes/=float(eye_points.size())
	var bone_scales: Array=[]
	for index in actor.skeleton.get_bone_count():
		var pose: Vector3=actor.skeleton.get_bone_pose_scale(index)
		var rest: Vector3=actor.skeleton.get_bone_rest(index).basis.get_scale()
		if not pose.is_equal_approx(Vector3.ONE) or not rest.is_equal_approx(Vector3.ONE):
			bone_scales.append({"name":actor.skeleton.get_bone_name(index),"pose":v(pose),"rest":v(rest)})
	return {"time":time,"clip":actor._native_dialogue_clip,"sourceTime":actor.source_time,"transforms":_node_scales(actor),"nonUnitBoneScales":bone_scales,"staticModelSpace":box(static_bounds),"actualWorldSpace":box(_bounds(all_points)),"eyesCenterWorld":v(eyes),"eyesWorld":box(_bounds(eye_points)),"faceWorld":box(_bounds(face_points)),"footVerticesWorld":box(_bounds(foot_points)),"headBoneWorld":bone_point(actor,"Bip001 Head"),"leftFootBoneWorld":bone_point(actor,"Bip001 L Foot"),"rightFootBoneWorld":bone_point(actor,"Bip001 R Foot"),"rootBoneWorld":bone_point(actor,str(actor._visual.rootBone)),"activeBlendShapes":active_blends,"meshes":meshes}
func _raw_sample(config: Dictionary) -> Dictionary:
	var raw:=RawActor.new()
	root.add_child(raw)
	raw._visual=config.visual
	raw._pivot=Node3D.new()
	raw.add_child(raw._pivot)
	raw.model=(load(str(config.modelPath)) as PackedScene).instantiate()
	raw._pivot.add_child(raw.model)
	raw.skeleton=raw.model.find_children("*","Skeleton3D",true,false)[0]
	for mesh: MeshInstance3D in raw.model.find_children("*","MeshInstance3D",true,false):
		var lower:=str(mesh.name).to_lower()
		var hidden: bool=lower in config.visual.get("hiddenMeshes",[])
		for weapons in config.visual.get("weaponMeshes",{}).values():
			if lower in weapons:hidden=true
		mesh.visible=not hidden
		if lower=="body" and config.visual.has("nativeBodyMesh"):mesh.mesh=load(str(config.visual.nativeBodyMesh))
	var result:=_sample(raw,-1.0)
	raw.free()
	return result
func run() -> void:
	for selection: Dictionary in [Roster.resolve("fuhua","azure_empyrea","default"),Roster.resolve("fuhua","azure_empyrea","taixu_memory"),Roster.resolve("fuhua","fenghuang","default"),Roster.resolve("fuhua","night_squire","default")]:
		var story:=Story.new()
		root.add_child(story)
		story.begin("intro",{},selection)
		var samples: Dictionary={"fuhua":[],"senti":[]}
		var imported: Dictionary={}
		var previous:=0.0
		for time: float in [0.0,0.5,1.0,2.0,3.0,4.2,4.5,5.0,6.3]:
			story.tick(time-previous)
			previous=time
			for id: String in ["fuhua","senti"]:
				var sampled:=_sample(story.actors[id],time)
				if time==0.0:
					var actor=story.actors[id]
					var live_pose: Array[Transform3D]=[]
					for bone in actor.skeleton.get_bone_count():live_pose.append(actor.skeleton.get_bone_pose(bone))
					for bone in actor._imported_base_pose.size():actor.skeleton.set_bone_pose(bone,actor._imported_base_pose[bone])
					imported[id]=_sample(actor,-1.0)
					for bone in live_pose.size():actor.skeleton.set_bone_pose(bone,live_pose[bone])
				samples[id].append(sampled)
				print(JSON.stringify({"selection":str(selection.styleId)+"/"+str(selection.appearanceId),"identity":id,"time":time,"clip":sampled.clip,"pivot":sampled.transforms[1].localScale,"skeleton":sampled.transforms[3].localScale,"height":sampled.actualWorldSpace.height,"top":sampled.actualWorldSpace.max[1],"floor":sampled.footVerticesWorld.min[1],"eyeY":sampled.eyesCenterWorld[1],"headY":sampled.headBoneWorld[1],"staticHeight":sampled.staticModelSpace.height}))
		report.actors.append({"selection":str(selection.styleId)+"/"+str(selection.appearanceId),"model":selection.actor.modelPath,"fuhua":samples.fuhua,"senti":samples.senti,"importedPoseAtDisplayScale":imported,"rawPackedScene":{"fuhua":_raw_sample(selection.actor),"senti":_raw_sample(story.actors.senti._profile)}})
		story.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/dialogue-height-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
