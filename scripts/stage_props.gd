extends RefCounted
## Geometry authored for this demo, not extracted stage meshes.
## Every prop batches all faces sharing a palette key.
## Local ground is Y=0; the returned root owns every mesh and can be hidden as one.

class Builder:
	extends RefCounted
	var surfaces: Dictionary = {}
	var palette: Dictionary
	var root: Node3D

	func _init(parent: Node3D, at: Vector3, factor: float, mats: Dictionary, label: String) -> void:
		palette = mats
		root = Node3D.new()
		root.name = label
		root.position = at
		root.scale = Vector3.ONE * factor
		parent.add_child(root)

	func tri(key: String, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		if (b-a).cross(c-a).length_squared() < 0.0000000001: return
		if not surfaces.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = surface
		var surface: SurfaceTool = surfaces[key]
		# Godot's front faces wind clockwise when seen from their normal side.
		if (b-a).cross(c-a).dot(normal) > 0.0:
			var swap := b
			b = c
			c = swap
		for point in [a,b,c]:
			surface.set_normal(normal.normalized())
			surface.add_vertex(point)

	func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
		tri(key,a,b,c,normal)
		tri(key,a,c,d,normal)

	func box(key: String, center: Vector3, size: Vector3) -> void:
		var p := center-size*0.5
		var q := center+size*0.5
		quad(key,Vector3(p.x,q.y,p.z),Vector3(q.x,q.y,p.z),Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z),Vector3.UP)
		quad(key,Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),Vector3(q.x,p.y,q.z),Vector3(p.x,p.y,q.z),Vector3.DOWN)
		quad(key,Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z),Vector3.BACK)
		quad(key,Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),Vector3.FORWARD)
		quad(key,Vector3(p.x,p.y,p.z),Vector3(p.x,p.y,q.z),Vector3(p.x,q.y,q.z),Vector3(p.x,q.y,p.z),Vector3.LEFT)
		quad(key,Vector3(q.x,p.y,p.z),Vector3(q.x,p.y,q.z),Vector3(q.x,q.y,q.z),Vector3(q.x,q.y,p.z),Vector3.RIGHT)

	func tube(key: String, start: Vector3, finish: Vector3, radius_a: float, radius_b: float, sides: int = 8) -> void:
		var axis := (finish-start).normalized()
		var across := axis.cross(Vector3.RIGHT if absf(axis.x)<0.8 else Vector3.UP).normalized()
		var other := axis.cross(across).normalized()
		for i in sides:
			var theta := TAU*float(i)/float(sides)
			var theta_next := TAU*float(i+1)/float(sides)
			var a := across*cos(theta)+other*sin(theta)
			var b := across*cos(theta_next)+other*sin(theta_next)
			quad(key,start+a*radius_a,start+b*radius_a,finish+b*radius_b,finish+a*radius_b,(a+b).normalized())
			tri(key,start,start+a*radius_a,start+b*radius_a,-axis)
			tri(key,finish,finish+a*radius_b,finish+b*radius_b,axis)

	func slab(key: String, center: Vector3, width: float, depth: float, height: float, bevel: float) -> void:
		var x := width*0.5
		var z := depth*0.5
		var edge: Array[Vector2] = [Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),Vector2(x,z-bevel),Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)]
		for i in edge.size():
			var p := edge[i]
			var q := edge[(i+1)%edge.size()]
			var a := center+Vector3(p.x,height*0.5,p.y)
			var b := center+Vector3(q.x,height*0.5,q.y)
			tri(key,center+Vector3(0,height*0.5,0),a,b,Vector3.UP)
			quad(key,a,b,b-Vector3.UP*height,a-Vector3.UP*height,Vector3((p+q).x,0,(p+q).y).normalized())

	func finish() -> Node3D:
		for key: String in surfaces:
			var item := MeshInstance3D.new()
			item.name = key.capitalize()+"Batch"
			var surface: SurfaceTool = surfaces[key]
			surface.index()
			item.mesh = surface.commit()
			item.material_override = palette.get(key,palette.get("stone"))
			root.add_child(item)
		root.set_meta("mesh_batches",surfaces.size())
		return root

static func _roof_point(u: float, v: float) -> Vector3:
	var end := absf(u)
	var edge := absf(v)
	# Curved pitch flattens at the eave, with a lifted tip at each corner.
	var height := 3.65+0.85*pow(1.0-edge,1.7)+0.20*pow(edge,5.0)+0.28*pow(end,6.0)*pow(edge,3.0)
	return Vector3(u*2.28*(0.80+0.20*edge),height,v*1.78)

static func pavilion(parent: Node3D, at: Vector3, scale_factor: float, mats: Dictionary) -> Node3D:
	var build := Builder.new(parent,at,scale_factor,mats,"CloudEavePavilion")
	build.slab("dark",Vector3(0,0.08,0),4.35,3.42,0.16,0.25)
	build.slab("stone",Vector3(0,0.24,0),4.15,3.22,0.16,0.22)
	build.slab("stone",Vector3(0,0.35,0),3.98,3.06,0.06,0.18)
	build.box("stone",Vector3(0,0.08,1.88),Vector3(1.65,0.16,0.50))
	build.box("stone",Vector3(0,0.18,1.65),Vector3(1.65,0.12,0.30))
	for x in [-1.43,1.43]:
		for z in [-1.04,1.04]:
			build.slab("dark",Vector3(x,0.43,z),0.48,0.48,0.12,0.09)
			build.slab("stone",Vector3(x,0.54,z),0.40,0.40,0.10,0.07)
			build.tube("wood",Vector3(x,0.58,z),Vector3(x,3.36,z),0.105,0.092,10)
			build.tube("bronze",Vector3(x,0.61,z),Vector3(x,0.69,z),0.113,0.113,10)
			build.tube("bronze",Vector3(x,2.98,z),Vector3(x,3.06,z),0.109,0.109,10)
			# Crossed bracket tiers support the roof without closing the open bays.
			build.box("wood",Vector3(x,3.12,z),Vector3(0.61,0.11,0.23))
			build.box("wood",Vector3(x,3.25,z),Vector3(0.25,0.12,0.64))
			build.box("bronze",Vector3(x,3.34,z),Vector3(0.40,0.05,0.40))
			for sign_value in [-1.0,1.0]:
				build.tube("wood",Vector3(x,2.75,z),Vector3(x+sign_value*0.38,3.10,z),0.055,0.045,5)
	for z in [-1.04,1.04]:
		build.box("wood",Vector3(0,3.42,z),Vector3(3.72,0.20,0.23))
		build.box("dark",Vector3(0,3.58,z),Vector3(3.94,0.10,0.28))
	for x in [-1.43,1.43]:
		build.box("wood",Vector3(x,3.42,0),Vector3(0.23,0.20,2.83))
		build.box("dark",Vector3(x,3.58,0),Vector3(0.28,0.10,3.03))
	# Actual curved roof skin, plus a separate dark soffit visible from below.
	for ix in 16:
		for iz in 14:
			var u0 := -1.0+2.0*float(ix)/16.0
			var u1 := -1.0+2.0*float(ix+1)/16.0
			var v0 := -1.0+2.0*float(iz)/14.0
			var v1 := -1.0+2.0*float(iz+1)/14.0
			var a := _roof_point(u0,v0)
			var b := _roof_point(u1,v0)
			var c := _roof_point(u1,v1)
			var d := _roof_point(u0,v1)
			var normal := (d-a).cross(b-a).normalized()
			build.quad("roof",a,b,c,d,normal)
			var offset := Vector3(0,0.075,0)
			build.quad("dark",a-offset,b-offset,c-offset,d-offset,-normal)
	# Thin tile crests follow the curved pitch, rather than floating straight bars.
	for ix in 15:
		var u := -0.96+float(ix)*1.92/14.0
		for iz in 14:
			var v0 := -1.0+2.0*float(iz)/14.0
			var v1 := -1.0+2.0*float(iz+1)/14.0
			build.tube("roof",_roof_point(u,v0)+Vector3.UP*0.018,_roof_point(u,v1)+Vector3.UP*0.018,0.025,0.025,4)
	# The lifted eave fascia and ridge have a restrained aged-bronze edge.
	for side in [-1.0,1.0]:
		for ix in 16:
			build.tube("dark",_roof_point(-1.0+2.0*ix/16.0,side),_roof_point(-1.0+2.0*(ix+1)/16.0,side),0.052,0.052,6)
		for iz in 14:
			build.tube("bronze",_roof_point(side,-1.0+2.0*iz/14.0),_roof_point(side,-1.0+2.0*(iz+1)/14.0),0.027,0.027,5)
		build.tube("roof",Vector3(side*1.72,4.55,0),Vector3(side*1.96,4.78,0),0.065,0.035,6)
	build.tube("roof",Vector3(-1.82,4.55,0),Vector3(1.82,4.55,0),0.085,0.085,8)
	return build.finish()

static func lantern(parent: Node3D, at: Vector3, scale_factor: float, mats: Dictionary) -> Node3D:
	var build := Builder.new(parent,at,scale_factor,mats,"StonePaperLantern")
	build.slab("dark",Vector3(0,0.07,0),0.64,0.64,0.14,0.10)
	build.slab("stone",Vector3(0,0.17,0),0.50,0.50,0.10,0.08)
	build.tube("stone",Vector3(0,0.22,0),Vector3(0,0.60,0),0.14,0.10,8)
	build.slab("bronze",Vector3(0,0.64,0),0.48,0.48,0.08,0.06)
	build.box("light",Vector3(0,0.91,0),Vector3(0.33,0.47,0.33))
	for x in [-0.19,0.19]:
		for z in [-0.19,0.19]:
			build.box("wood",Vector3(x,0.91,z),Vector3(0.045,0.56,0.045))
	for y in [0.72,1.10]:
		for side in [-1.0,1.0]:
			build.box("wood",Vector3(0,y,side*0.19),Vector3(0.42,0.025,0.025))
			build.box("wood",Vector3(side*0.19,y,0),Vector3(0.025,0.025,0.42))
	# Four sloped facets taper to a small finial; the rim kicks upwards at corners.
	for i in 4:
		var angle := float(i)*PI*0.5+PI*0.25
		var next := angle+PI*0.5
		var a := Vector3(cos(angle)*0.43,1.19,sin(angle)*0.43)
		var b := Vector3(cos(next)*0.43,1.19,sin(next)*0.43)
		var middle := Vector3(0,1.39,0)
		build.tri("roof",a,b,middle,(middle-b).cross(a-b).normalized()*-1.0)
		build.tube("bronze",a,b,0.020,0.020,4)
	build.tube("bronze",Vector3(0,1.37,0),Vector3(0,1.52,0),0.055,0.008,7)
	return build.finish()

static func bamboo_grove(parent: Node3D, at: Vector3, seed_value: int, mats: Dictionary) -> Node3D:
	var build := Builder.new(parent,at,1.0,mats,"BambooGrove")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 11:
		var base := Vector3(rng.randf_range(-1.25,1.25),0,rng.randf_range(-0.8,0.8))
		var height := rng.randf_range(3.0,5.5)
		var lean := Vector3(rng.randf_range(-0.36,0.36),0,rng.randf_range(-0.18,0.18))
		var radius := rng.randf_range(0.035,0.065)
		var count := int(ceil(height/0.62))
		for segment in count:
			var t0 := float(segment)/float(count)
			var t1 := float(segment+1)/float(count)
			var a := base+Vector3.UP*height*t0+lean*t0*t0
			var b := base+Vector3.UP*height*t1+lean*t1*t1
			var r0 := radius*(1.0-t0*0.42)
			var r1 := radius*(1.0-t1*0.42)
			build.tube("wood",a,b,r0,r1,6)
			if segment>0:
				build.tube("leaf",a-Vector3.UP*0.018,a+Vector3.UP*0.018,r0*1.18,r0*1.18,6)
			if t1<0.44: continue
			var side := -1.0 if (segment+i)%2==0 else 1.0
			var reach := rng.randf_range(0.45,0.85)
			var branch := Vector3(side*reach,rng.randf_range(0.08,0.26),rng.randf_range(-0.22,0.22))
			var branch_start := b-Vector3.UP*0.08
			var branch_end := branch_start+branch
			build.tube("wood",branch_start,branch_end,0.016,0.004,4)
			for leaf_index in 7:
				var fraction := 0.15+float(leaf_index)*0.115
				var origin := branch_start+branch*fraction
				var fan := -1.0 if leaf_index%2==0 else 1.0
				var length := rng.randf_range(0.25,0.48)*(1.0-fraction*0.25)
				var leaf_axis := Vector3(side*0.52,fan*0.70-0.12,fan*0.23).normalized()*length
				var width_axis := leaf_axis.cross(Vector3.BACK).normalized()*rng.randf_range(0.022,0.040)
				var middle := origin+leaf_axis*0.44
				var tip := origin+leaf_axis
				# Narrow tapered leaves with a folded midrib, visible on both sides.
				var ridge := middle+Vector3(0,0,0.014)
				for sign_value in [-1.0,1.0]:
					var edge: Vector3 = middle+width_axis*float(sign_value)
					var normal: Vector3 = (edge-origin).cross(ridge-origin).normalized()
					if normal.length_squared()<0.01: normal=Vector3.BACK
					build.tri("leaf",origin,edge,ridge,normal)
					build.tri("leaf",edge,tip,ridge,normal)
					build.tri("leaf",origin,edge,ridge,-normal)
					build.tri("leaf",edge,tip,ridge,-normal)
	return build.finish()

static func _tree_leaf_material(mats: Dictionary) -> StandardMaterial3D:
	var tint: Color = Color("506d5b")
	var supplied = mats.get("tree_tint")
	if supplied is Color:
		tint = supplied
	else:
		var source = mats.get("leaf")
		if source is ShaderMaterial:
			var value = source.get_shader_parameter("base_color")
			if value is Color: tint = value
			elif value is Vector3: tint = Color(value.x,value.y,value.z)
		elif source is BaseMaterial3D:
			tint = source.albedo_color
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/stage/native/Stage_TaiXu_Leaf_Tex.png")
	material.albedo_color = Color(tint.r,tint.g,tint.b,1.0)
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.34
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = false
	return material

static func _tree_leaf_card(build: Builder, center: Vector3, size: Vector2, angles: Vector3, atlas_x: float, shade: float, flip: bool) -> void:
	var key := "tree_leaves"
	if not build.surfaces.has(key):
		var created := SurfaceTool.new()
		created.begin(Mesh.PRIMITIVE_TRIANGLES)
		build.surfaces[key] = created
	var surface: SurfaceTool = build.surfaces[key]
	var orientation := Basis.from_euler(angles)
	# A shallow folded card keeps each leaf packet from becoming a rigid flat plate.
	for ix in 2:
		for iy in 2:
			var corners: Array[Vector2] = [Vector2(ix,iy)*0.5,Vector2(ix+1,iy)*0.5,Vector2(ix+1,iy+1)*0.5,Vector2(ix,iy+1)*0.5]
			for corner_index in [0,1,2,0,2,3]:
				var p: Vector2 = corners[corner_index]
				var offset := Vector3((p.x-0.5)*size.x,(0.5-p.y)*size.y,(1.0-absf(p.x*2.0-1.0))*0.085)
				# Direct PNG UVs use its top half; inset avoids bleeding from the grass below.
				var atlas_u := 1.0-p.x if flip else p.x
				surface.set_uv(Vector2(atlas_x+0.003+atlas_u*0.494,0.003+p.y*0.494))
				surface.set_color(Color(shade,shade,shade,1.0))
				surface.set_normal(orientation*Vector3.BACK)
				surface.add_vertex(center+orientation*offset)

static func _tree_crown(build: Builder, center: Vector3, width: float, depth: float, rng: RandomNumberGenerator) -> void:
	var material: StandardMaterial3D = build.palette.tree_leaves
	var tint := material.albedo_color
	var atlas_x := 0.5 if tint.r>tint.g*1.15 else 0.0
	# Seven sparse overlapping packets form one uneven crown, with no solid canopy disk.
	# Back packets establish volume; smaller front packets break the contour into leaves.
	_tree_leaf_card(build,center+Vector3(0,0.15,-depth*0.30),Vector2(width*1.92,0.95),Vector3(0.14,rng.randf_range(-0.24,0.24),rng.randf_range(-0.12,0.12)),atlas_x,0.77,false)
	for i in 6:
		var side := float(i%3)-1.0
		var front := i>=3
		var offset := Vector3(side*width*0.47,(0.19 if front else 0.04)+rng.randf_range(-0.10,0.14),(0.23 if front else -0.06)*depth)
		var size := Vector2(width*rng.randf_range(0.94,1.16),rng.randf_range(0.69,0.90))
		var angles := Vector3(rng.randf_range(-0.25,0.30),side*(0.30 if front else -0.55)+rng.randf_range(-0.16,0.16),side*0.16+rng.randf_range(-0.20,0.20))
		_tree_leaf_card(build,center+offset,size,angles,atlas_x,rng.randf_range(0.86,1.10) if front else rng.randf_range(0.74,0.91),i%2==0)

static func wind_tree(parent: Node3D, at: Vector3, scale_factor: float, mats: Dictionary, seed_value: int = 73) -> Node3D:
	var tree_mats := mats.duplicate()
	tree_mats["tree_leaves"] = _tree_leaf_material(mats)
	var build := Builder.new(parent,at,scale_factor,tree_mats,"WindShapedMountainTree")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# The trunk changes direction several times, exposing the bends between crowns.
	var trunk: Array[Vector3] = [Vector3(0,0,0),Vector3(0.16,0.53,0.04),Vector3(-0.10,1.05,0.02),Vector3(0.15,1.64,-0.04),Vector3(0.54,2.23,-0.08),Vector3(0.73,2.83,-0.04),Vector3(0.58,3.46,0.02),Vector3(0.80,3.87,-0.02)]
	for i in trunk.size()-1:
		var radius := lerpf(0.21,0.045,float(i)/float(trunk.size()-2))
		build.tube("wood",trunk[i],trunk[i+1],radius,radius*0.80,7)
	# Low spreading roots help the trunk sit on the terrace or rock shelf.
	for i in 5:
		var angle := float(i)*TAU/5.0+0.3
		var end := Vector3(cos(angle)*rng.randf_range(0.43,0.65),0.025,sin(angle)*0.40)
		build.tube("wood",Vector3(0.02,0.23,0.01),end,0.095,0.018,5)
	var branches: Array = [
		[trunk[3],Vector3(-0.48,1.92,0.07),Vector3(-1.17,2.22,0.03),Vector3(-1.40,2.48,0.01)],
		[trunk[4],Vector3(1.09,2.36,0.0),Vector3(1.48,2.70,-0.02),Vector3(1.59,2.89,-0.04)],
		[trunk[5],Vector3(0.16,2.94,-0.10),Vector3(-0.51,3.18,-0.05),Vector3(-0.73,3.39,-0.04)],
		[trunk[6],Vector3(1.15,3.44,0.11),Vector3(1.40,3.60,0.04),Vector3(1.36,3.73,0.02)]
	]
	for branch: Array in branches:
		for i in branch.size()-1:
			build.tube("wood",branch[i],branch[i+1],0.105-float(i)*0.027,0.076-float(i)*0.024,6)
		var fork_start: Vector3 = branch[1]
		var fork_end: Vector3 = branch[2]+Vector3(-0.12,0.14,0.40)
		build.tube("wood",fork_start,fork_end,0.047,0.012,5)
	# A few inset bark ridges follow the bends; no noisy repeating texture is needed.
	for i in range(1,trunk.size()-2):
		var offset := Vector3(0.035,0,0.13-float(i)*0.012)
		build.tube("dark",trunk[i]+offset,trunk[i+1]+offset,0.012,0.010,4)
	_tree_crown(build,Vector3(-1.34,2.50,0.04),0.94,0.62,rng)
	_tree_crown(build,Vector3(1.50,2.92,-0.04),0.83,0.65,rng)
	_tree_crown(build,Vector3(-0.60,3.40,-0.06),1.03,0.70,rng)
	_tree_crown(build,Vector3(1.27,3.73,0.04),0.79,0.59,rng)
	_tree_crown(build,Vector3(0.68,3.96,-0.03),0.96,0.64,rng)
	return build.finish()

static func garden_rock_cluster(parent: Node3D, at: Vector3, scale_factor: float, mats: Dictionary, seed_value: int) -> Node3D:
	var build := Builder.new(parent,at,scale_factor,mats,"GardenRockCluster")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := rng.randi_range(3,5)
	for rock_index in count:
		var across := float(rock_index)/float(count-1)
		var center := Vector3(lerpf(-0.83,0.83,across),0,rng.randf_range(-0.22,0.24))
		var large := rock_index==count/2
		var width := rng.randf_range(0.46,0.57) if large else rng.randf_range(0.32,0.43)
		var depth := rng.randf_range(0.39,0.53)
		var height := rng.randf_range(0.58,0.73) if large else rng.randf_range(0.30,0.52)
		var sides := rng.randi_range(7,9)
		var angle_offset := rng.randf_range(-0.45,0.45)
		var bottom: Array[Vector3] = []
		var shoulder: Array[Vector3] = []
		var top: Array[Vector3] = []
		for i in sides:
			var angle := TAU*float(i)/float(sides)+angle_offset
			var irregular := rng.randf_range(0.86,1.06)
			var radial := Vector3(cos(angle)*width*irregular,0,sin(angle)*depth*irregular)
			bottom.append(center+radial*0.82+Vector3.UP*0.015)
			shoulder.append(center+radial+Vector3.UP*height*rng.randf_range(0.32,0.44))
			top.append(center+radial*rng.randf_range(0.55,0.70)+Vector3.UP*height*rng.randf_range(0.81,0.88))
		# Broad, nearly level crowns avoid the pointed silhouette of crystal meshes.
		var cap := center+Vector3(width*0.07,height*0.87,-depth*0.05)
		for i in sides:
			var next := (i+1)%sides
			var normal := Vector3((shoulder[i]+shoulder[next]-center*2.0).x,0,(shoulder[i]+shoulder[next]-center*2.0).z).normalized()
			build.quad("dark" if i%3==0 else "stone",bottom[i],bottom[next],shoulder[next],shoulder[i],normal)
			var slope := (shoulder[next]-shoulder[i]).cross(top[i]-shoulder[i]).normalized()
			if slope.dot(normal)<0.0: slope=-slope
			build.quad("stone",shoulder[i],shoulder[next],top[next],top[i],slope)
			var up := (top[next]-top[i]).cross(cap-top[i]).normalized()
			if up.y<0.0: up=-up
			build.tri("stone",top[i],top[next],cap,up)
		# A small irregular moss patch sits on the flat crown, away from outer edges.
		var moss_center := cap+Vector3(-width*0.10,0.006,depth*0.08)
		var moss_width := width*rng.randf_range(0.23,0.38)
		var moss_depth := depth*rng.randf_range(0.21,0.31)
		for i in 7:
			var angle := TAU*float(i)/7.0
			var next_angle := TAU*float(i+1)/7.0
			var a := moss_center+Vector3(cos(angle)*moss_width,0.0,sin(angle)*moss_depth)
			var b := moss_center+Vector3(cos(next_angle)*moss_width,0.0,sin(next_angle)*moss_depth)
			build.tri("leaf",moss_center,a,b,Vector3.UP)
		# A few short folded blades grow from the moss; no giant billboard grass.
		if rock_index%2==0:
			for blade in 5:
				var angle := rng.randf_range(0.0,TAU)
				var base := moss_center+Vector3(cos(angle)*0.06,0.003,sin(angle)*0.05)
				var blade_height := rng.randf_range(0.075,0.14)
				var bend := Vector3(cos(angle)*0.06,blade_height,sin(angle)*0.06)
				var across_blade := Vector3(-sin(angle),0,cos(angle))*rng.randf_range(0.009,0.018)
				var middle := base+bend*0.47
				var tip := base+bend
				var normal := across_blade.cross(bend).normalized()
				for side in [-1.0,1.0]:
					var leaf_normal: Vector3 = normal*float(side)
					build.tri("leaf",base-across_blade,base+across_blade,middle+across_blade*0.6,leaf_normal)
					build.tri("leaf",base-across_blade,middle+across_blade*0.6,tip,leaf_normal)
	return build.finish()
