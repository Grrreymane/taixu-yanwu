extends RefCounted
## Measures the original skinned geometry in model-local coordinates. A mesh
## AABB alone misses scaling stored inside the skeleton (C3's root is 1.1).
## Caller supplies the untouched scene pose, never an animated/crouching pose.
static func measure(model: Node3D, skeleton: Skeleton3D, hidden_surfaces: Array) -> Dictionary:
	var inverse_model:=model.global_transform.affine_inverse()
	var bounds:=AABB()
	var first:=true
	var count:=0
	for child in model.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=child as MeshInstance3D
		if not mesh_node.visible or mesh_node.mesh==null: continue
		var skin:=mesh_node.skin
		var transforms: Array[Transform3D]=[]
		if skin!=null:
			for bind in skin.get_bind_count():
				var bone:=skin.get_bind_bone(bind)
				if bone<0: bone=skeleton.find_bone(skin.get_bind_name(bind))
				if bone<0 or bone>=skeleton.get_bone_count():
					push_error("Invalid skin binding while measuring "+str(mesh_node.name))
					return {}
				transforms.append(inverse_model*skeleton.global_transform*skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
		var relative:=inverse_model*mesh_node.global_transform
		for surface in mesh_node.mesh.get_surface_count():
			if str(mesh_node.name).to_lower()+":"+str(surface) in hidden_surfaces: continue
			var arrays:=mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			if vertices.is_empty(): continue
			var bones=arrays[Mesh.ARRAY_BONES]
			var weights=arrays[Mesh.ARRAY_WEIGHTS]
			var skinned:bool=not transforms.is_empty() and bones!=null and weights!=null and bones.size()>0
			var stride:int=bones.size()/vertices.size() if skinned else 0
			for index in vertices.size():
				var point:=Vector3.ZERO
				if skinned:
					for influence in stride:
						var offset:=index*stride+influence
						var weight:float=weights[offset]
						if weight>0.0: point+=(transforms[int(bones[offset])]*vertices[index])*weight
				else: point=relative*vertices[index]
				if first:
					bounds=AABB(point,Vector3.ZERO)
					first=false
				else: bounds=bounds.expand(point)
				count+=1
	return {} if first else {"bounds":bounds,"vertices":count}
