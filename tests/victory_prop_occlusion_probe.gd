extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
var triangles:Array[Vector3]=[]
func _initialize() -> void: call_deferred("_run")
func _points(actor,mesh:MeshInstance3D) -> Array[Vector3]:
	var result:Array[Vector3]=[]
	var transforms:Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=actor.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
		var points:Array[Vector3]=[]
		for index in vertices.size():
			var point:=Vector3.ZERO
			for influence in 4:
				point+=(transforms[int(bones[index*4+influence])]*vertices[index])*float(weights[index*4+influence])
			points.append(point)
		result.append_array(points)
		if str(mesh.name).to_lower()=="umbrella_s":
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index in indices:triangles.append(points[index])
	return result
func _run() -> void:
	var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve())
	actor.animate_victory(4.4)
	_points(actor,actor._victory_props[0])
	var eye_points:Array[Vector3]=[]
	for name in ["Eye_L","Eye_R"]:
		var meshes=actor.model.find_children(name,"MeshInstance3D",true,false)
		var points:=_points(actor,meshes[0])
		var eye:=Vector3.ZERO
		for p in points:eye+=p
		eye/=float(points.size())
		eye_points.append(eye)
	var results=[]
	for yaw in range(-100,81,10):
		var view:=Vector3(sin(deg_to_rad(yaw)),0,cos(deg_to_rad(yaw)))
		var right:=Vector3(view.z,0,-view.x)
		var camera:=view*6.7+right*1.467+Vector3.UP*1.95
		var hits:=0
		for point in eye_points:
			for triangle in range(0,triangles.size(),3):
				if Geometry3D.segment_intersects_triangle(camera,point,triangles[triangle],triangles[triangle+1],triangles[triangle+2])!=null:hits+=1
		results.append({"yaw":yaw,"hits":hits,"camera":str(camera)})
	var passed:=results.all(func(row):return int(row.hits)==0)
	var report={"suite":"victory_native_prop_occlusion","passed":passed,"angles":results.size(),"results":results}
	var file=FileAccess.open("res://build/reports/victory-native-prop-occlusion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify({"suite":report.suite,"passed":passed,"angles":results.size()}))
	actor.free();quit(0 if passed else 1)
