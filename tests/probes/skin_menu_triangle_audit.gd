extends SceneTree
## CPU skins actual Body vertices, then checks non-adjacent triangles for
## strict interior crossings. Does not infer mesh clearance from bone capsules.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
var reports:Array=[]
func _initialize() -> void:call_deferred("_run")
func _group(name:String) -> String:
	if "_Skirt_" in name or "_Ribbon_" in name:return name.substr(0,name.length()-3)
	if name.begins_with("Bip001") and ("Thigh" in name or "Calf" in name or "Foot" in name or "Toe" in name):return "leg"
	return "body"
func _triangles(actor) -> Array:
	var result:Array=[]
	var mesh:MeshInstance3D=actor.model.find_children("Body","MeshInstance3D",true,false)[0]
	var transforms:Array[Transform3D]=[];var bind_groups:Array[String]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=actor.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		bind_groups.append(_group(actor.skeleton.get_bone_name(bone)))
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
		var points:Array[Vector3]=[];var groups:Array[Dictionary]=[]
		var stride:int=bones.size()/vertices.size()
		for index in vertices.size():
			var point:=Vector3.ZERO;var group_weights:Dictionary={}
			for influence in stride:
				var weight:float=weights[index*stride+influence]
				if weight<=0.0:continue
				var bind:int=bones[index*stride+influence]
				point+=(transforms[bind]*vertices[index])*weight
				var group:=bind_groups[bind]
				group_weights[group]=float(group_weights.get(group,0.0))+weight
			points.append(point);groups.append(group_weights)
		for start in range(0,indices.size(),3):
			var a:=indices[start];var b:=indices[start+1];var c:=indices[start+2]
			var ps:Array[Vector3]=[points[a],points[b],points[c]]
			var box:=AABB(ps[0],Vector3.ZERO);box=box.expand(ps[1]);box=box.expand(ps[2])
			if box.position.y>1.90 or box.end.y<0.25:continue
			var total:Dictionary={}
			for index in [a,b,c]:
				for name in groups[index]:total[name]=float(total.get(name,0.0))+float(groups[index][name])
			var group:="body";var maximum:=0.0
			for name in total:
				if float(total[name])>maximum:maximum=total[name];group=name
			var normal:Vector3=(ps[1]-ps[0]).cross(ps[2]-ps[0])
			if normal.length_squared()<0.0000000001:continue
			result.append({"id":result.size(),"surface":surface,"triangle":start/3,"vertices":[a,b,c],"p":ps,"box":box,"group":group,"weights":total,"normal":normal.normalized()})
	return result
func _strict_hit(a:Vector3,b:Vector3,tri:Dictionary) -> Variant:
	var p:Array=tri.p
	var hit=Geometry3D.segment_intersects_triangle(a,b,p[0],p[1],p[2])
	if hit==null or hit.distance_to(a)<0.00001 or hit.distance_to(b)<0.00001:return null
	# Reject shared boundaries/UV seams. Only interior piercing is a crossing.
	for i in 3:
		if Geometry3D.get_closest_point_to_segment(hit,p[i],p[(i+1)%3]).distance_to(hit)<0.00001:return null
	return hit
func _crossing(a:Dictionary,b:Dictionary) -> Variant:
	for p:Vector3 in a.p:
		for q:Vector3 in b.p:
			if p.distance_squared_to(q)<0.0000000001:return null
	for edge in 3:
		var hit=_strict_hit(a.p[edge],a.p[(edge+1)%3],b)
		if hit!=null:return hit
		var reverse=_strict_hit(b.p[edge],b.p[(edge+1)%3],a)
		if reverse!=null:return reverse
	return null
func _audit(actor,at:float,mode:String) -> void:
	var triangles:=_triangles(actor)
	var camera:=Camera3D.new();root.add_child(camera)
	camera.fov=34.0;camera.position=Vector3(0.8,1.85,7.6);camera.look_at(Vector3(0.8,1.48,0))
	var head:Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Bip001 Head")).origin
	var head_screen:=camera.unproject_position(head)
	var floor_screen:=camera.unproject_position(Vector3(head.x,0.0,head.z))
	var height:=maxf(1.0,floor_screen.y-head_screen.y)
	var cells:Dictionary={};var cell_size:=0.12
	for tri in triangles:
		var low:Vector3i=Vector3i((tri.box.position/cell_size).floor())
		var high:Vector3i=Vector3i((tri.box.end/cell_size).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				for z in range(low.z,high.z+1):
					var cell:=Vector3i(x,y,z)
					if not cells.has(cell):cells[cell]=[]
					cells[cell].append(tri.id)
	var candidates:Dictionary={};var counts:Dictionary={};var samples:Array=[]
	for bucket:Array in cells.values():
		for i in bucket.size():
			for j in range(i+1,bucket.size()):
				var ai:=mini(bucket[i],bucket[j]);var bi:=maxi(bucket[i],bucket[j])
				var a:Dictionary=triangles[ai];var b:Dictionary=triangles[bi]
				if not "_Skirt_" in str(a.group) and not "_Skirt_" in str(b.group):continue
				var key:=ai*triangles.size()+bi
				if candidates.has(key):continue
				candidates[key]=true
				if not a.box.grow(0.00001).intersects(b.box):continue
				var hit=_crossing(a,b)
				if hit==null:continue
				var pair:=[str(a.group),str(b.group)];pair.sort()
				var name:String=pair[0]+" / "+pair[1]
				counts[name]=int(counts.get(name,0))+1
				var projected:Vector2=(camera.unproject_position(hit)-head_screen)/height
				samples.append({"groups":name,"a":[a.surface,a.triangle],"b":[b.surface,b.triangle],"point":[hit.x,hit.y,hit.z],"screenRelativeToHead":[projected.x,projected.y],"weightsA":a.weights,"weightsB":b.weights})
	var row={"time":at,"mode":mode,"actualMeshTriangles":triangles.size(),"candidatePairs":candidates.size(),"crossingsByNativeChain":counts,"examples":samples}
	reports.append(row)
	camera.free()
	print(JSON.stringify({"time":at,"mode":mode,"triangles":triangles.size(),"crossings":counts}))
func _run() -> void:
	for mode in ["secondary_on","secondary_off","no_capsules"]:
		var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua","azure_empyrea","taixu_memory"))
		if mode=="secondary_off":actor._secondary_enabled=false
		if mode=="no_capsules":actor._secondary._colliders.clear()
		for frame in 481:
			var at:=float(frame)/60.0
			actor.animate_fighter({"state":"idle","stateTime":at,"x":1.9,"facing":1.0,"presentationYaw":-0.20},1.0/60.0,at)
			if frame in [0,60,180,480]:_audit(actor,at,mode)
		actor.free()
	var f=FileAccess.open("res://build/reports/skin-menu-triangle-audit.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(reports,"  "));f.close();quit()
