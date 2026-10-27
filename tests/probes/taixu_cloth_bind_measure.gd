extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua","azure_empyrea","taixu_memory"))
	var body:MeshInstance3D=actor.model.find_child("Body",true,false)
	var sk:Skeleton3D=actor.skeleton
	var matrices:Array[Transform3D]=[];var names:Array[String]=[]
	for bind in body.skin.get_bind_count():
		var bone:int=body.skin.get_bind_bone(bind)
		if bone<0:bone=sk.find_bone(body.skin.get_bind_name(bind))
		matrices.append(sk.get_bone_global_rest(bone)*body.skin.get_bind_pose(bind));names.append(sk.get_bone_name(bone))
	var groups:Dictionary={};var distances:Dictionary={}
	for surface in body.mesh.get_surface_count():
		var arrays:=body.mesh.surface_get_arrays(surface);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var stride:int=bones.size()/vs.size()
		for i in vs.size():
			var dominant:="";var maximum:=0.0;var point:=Vector3.ZERO
			for slot in stride:
				var w:float=weights[i*stride+slot];var bind:int=bones[i*stride+slot]
				point+=(matrices[bind]*vs[i])*w
				if w>maximum:maximum=w;dominant=names[bind]
			groups[dominant]=int(groups.get(dominant,0))+1
			for pair in [["Bip001 L Thigh","Bip001 L Calf"],["Bip001 R Thigh","Bip001 R Calf"],["Bip001 L Calf","Bip001 L Foot"],["Bip001 R Calf","Bip001 R Foot"]]:
				if dominant!=pair[0]:continue
				var a:=sk.get_bone_global_rest(sk.find_bone(pair[0])).origin;var b:=sk.get_bone_global_rest(sk.find_bone(pair[1])).origin
				var t:float=(point-a).dot(b-a)/(b-a).length_squared()
				if t<0.05 or t>0.95:continue
				if not distances.has(dominant):distances[dominant]=[]
				distances[dominant].append(point.distance_to(a.lerp(b,t)))
	var radii:Dictionary={}
	for name:String in distances:
		var values:Array=distances[name];values.sort()
		radii[name]={"count":values.size(),"min":values[0],"p95":values[int(values.size()*.95)],"max":values[-1]}
	print(JSON.stringify({"radii":radii,"groups":groups}));actor.free();quit()
