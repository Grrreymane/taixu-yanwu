extends Node3D
## Three courtyards share a level fighting lane; all scenery belongs to one
## visibility root so the native ink cinematic can replace the entire setting.
const Props = preload("res://scripts/stage_props.gd")
const NativeStageMaterials = preload("res://scripts/native_stage_materials.gd")
const SURFACE = preload("res://shaders/stage_surface.gdshader")
const MIST = preload("res://shaders/stage_mist.gdshader")
const NATIVE_CARD = preload("res://shaders/stage_native_card.gdshader")
const NATIVE_DIR = "res://assets/stage/native/"
const NATIVE_PROPS = "res://assets/stage/native-props/"
const PALETTES = [
	{"stone":Color("b8bfc7"),"shade":Color("8492a3"),"edge":Color("526579"),"wood":Color("635449"),"roof":Color("405a5b"),"bronze":Color("b4a47b"),"leaf":Color("455f51"),"sky":Color("85b4d3"),"horizon":Color("e2eaf0"),"mist":Color("b8cedb"),"mountain":Color("6c9bad"),"sun":Color("fff7eb")},
	{"stone":Color("aebbbd"),"shade":Color("788f96"),"edge":Color("45656e"),"wood":Color("53584a"),"roof":Color("38594f"),"bronze":Color("9ca88a"),"leaf":Color("355b46"),"sky":Color("7da8b1"),"horizon":Color("d6e5df"),"mist":Color("b4cfc9"),"mountain":Color("587d82"),"sun":Color("f2f7e9")},
	{"stone":Color("8b8490"),"shade":Color("57596d"),"edge":Color("323c51"),"wood":Color("60454b"),"roof":Color("354157"),"bronze":Color("c49d70"),"leaf":Color("955653"),"sky":Color("303950"),"horizon":Color("ce9a84"),"mist":Color("8c8896"),"mountain":Color("515c75"),"sun":Color("ffd3a0")}
]
var _region := -1
var _ink_cinematic := false
var _scenery: Node3D
var _sky_material: ProceduralSkyMaterial
var _environment: Environment
var _sun: DirectionalLight3D
var _mats: Dictionary = {}
var _animated: Array[ShaderMaterial] = []
var _mist_materials: Array[ShaderMaterial] = []
var _ultimate_exposure:=1.0

func set_ultimate_focus(profile: String,time: float) -> void:
	var frame: Dictionary=preload("res://scripts/ultimate_focus.gd").sample(profile,time)
	var floor_value: float={"hawk_of_the_fog":0.18,"shadow_knight":0.21,"fenghuang":0.28,"night_squire":0.42}.get(profile,1.0)
	var exposure:=lerpf(1.0,floor_value,float(frame.weight))
	if is_equal_approx(exposure,_ultimate_exposure):return
	_ultimate_exposure=exposure
	RenderingServer.global_shader_parameter_set("stage_exposure",exposure)
	# Darken scenery only. Character shaders and particle artwork keep their
	# original values, as in the official FK ultimate demonstration.
	_sky_material.sky_energy_multiplier=exposure
	_sky_material.ground_energy_multiplier=exposure
	_environment.fog_light_color=Color(PALETTES[maxi(_region,0)].mist)*exposure

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("stage_exposure",1.0)

func _ready() -> void:
	name = "TaixuCourtyard"
	_build_environment()
	set_region(0)

func set_ink_cinematic(enabled: bool) -> void:
	_ink_cinematic = enabled
	if is_instance_valid(_scenery): _scenery.visible = not enabled

func _build_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = 0.12
	_sky_material.ground_curve = 0.22
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_sky_contribution = 0.0
	_environment.ambient_light_energy = 0.36
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_density = 0.0032
	_environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48,-32,0)
	_sun.light_energy = 0.85
	_sun.light_specular = 0.0
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)

func _surface(base: Color, shade: Color, grain: float=0.06, native_file: String="") -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("base_color",base)
	material.set_shader_parameter("shade_color",shade)
	material.set_shader_parameter("grain_strength",grain)
	var source_path := native_file if native_file.begins_with("res://") else NATIVE_DIR+native_file
	if not native_file.is_empty() and ResourceLoader.exists(source_path):
		material.set_shader_parameter("surface_texture",load(source_path))
		material.set_shader_parameter("use_texture",true)
	return material

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _mesh(shape: Mesh, material: Material, position_value: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = position_value
	_scenery.add_child(node)
	return node

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(shape,material,at)

func _vertex(surface: SurfaceTool, at: Vector3, normal: Vector3, color: Color=Color.WHITE) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	surface.set_uv(Vector2(at.x,at.z))
	surface.add_vertex(at)

func _box_faces(surface: SurfaceTool, size: Vector3, at: Vector3, color: Color=Color.WHITE) -> void:
	var h := size*0.5
	for face in [[Vector3.UP,Vector3.RIGHT,Vector3.BACK,h.y,h.x,h.z],[Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD,h.y,h.x,h.z],[Vector3.RIGHT,Vector3.BACK,Vector3.UP,h.x,h.z,h.y],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP,h.x,h.z,h.y],[Vector3.BACK,Vector3.RIGHT,Vector3.DOWN,h.z,h.x,h.y],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP,h.z,h.x,h.y]]:
		var normal: Vector3 = face[0]
		var center: Vector3 = at+normal*float(face[3])
		var u: Vector3 = face[1]*float(face[4])
		var v: Vector3 = face[2]*float(face[5])
		for point in [center-u-v,center+u-v,center+u+v,center-u-v,center+u+v,center-u+v]:
			_vertex(surface,point,normal,color)

func _slab(surface: SurfaceTool, at: Vector3, width: float, depth: float, bevel: float, top: float, bottom: float, color: Color=Color.WHITE) -> void:
	var x := width*0.5
	var z := depth*0.5
	var ring: Array[Vector2] = [Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),Vector2(x,z-bevel),Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)]
	for i in ring.size():
		var a := at+Vector3(ring[i].x,top,ring[i].y)
		var b := at+Vector3(ring[(i+1)%ring.size()].x,top,ring[(i+1)%ring.size()].y)
		for p in [at+Vector3(0,top,0),a,b]: _vertex(surface,p,Vector3.UP,color)
		var low_a := Vector3(a.x,bottom+at.y,a.z)
		var low_b := Vector3(b.x,bottom+at.y,b.z)
		var normal := Vector3((a+b-at*2.0).x,0,(a+b-at*2.0).z).normalized()
		for p in [a,low_a,b,b,low_a,low_b]: _vertex(surface,p,normal,color.darkened(0.08))

func _build_platform() -> void:
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_slab(stone,Vector3.ZERO,17.8,8.6,0.85,-0.20,-0.70)
	_slab(stone,Vector3.ZERO,17.4,8.2,0.72,-0.055,-0.23,Color("dce1df"))
	_mesh(stone.commit(),_mats.edge)
	var floor_mesh := SurfaceTool.new()
	floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7053
	for row in 5:
		for col in 11:
			var color := Color.WHITE.darkened(rng.randf_range(0.0,0.065))
			_slab(floor_mesh,Vector3((col-5)*1.50,0,(row-2)*1.38),1.497,1.377,0.006,-0.006,-0.045,color)
	_mesh(floor_mesh.commit(),_mats.floor)
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		_box_faces(trim,Vector3(16.7,0.08,0.32),Vector3(0,-0.015,side*3.66))
		_box_faces(trim,Vector3(0.35,0.08,6.98),Vector3(side*8.27,-0.015,0))
		for i in 7:
			_box_faces(trim,Vector3(1.82,0.18,0.22),Vector3((i-3)*2.35,-0.34,side*4.18))
	_mesh(trim.commit(),_mats.edge)
	var inlay := SurfaceTool.new()
	inlay.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		_box_faces(inlay,Vector3(15.9,0.008,0.018),Vector3(0,0.031,side*3.67))
		_box_faces(inlay,Vector3(0.018,0.008,6.72),Vector3(side*8.27,0.031,0))
	_mesh(inlay.commit(),_mats.bronze)
	_ring(Vector3(0,0.002,0),2.04,0.022,_mats.bronze)
	_ring(Vector3(0,0.002,0),2.18,0.018,_mats.edge)
	_ring(Vector3(0,0.003,0),0.64,0.016,_mats.edge)
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var angle := float(i)*TAU/8.0
		for j in 3:
			var center := Vector3(cos(angle),0,sin(angle))*(2.30+float(j)*0.065)
			var u := Vector3(-sin(angle),0,cos(angle))*0.115
			var v := Vector3(cos(angle),0,sin(angle))*0.012
			center.y = 0.004
			for p in [center-u-v,center+u-v,center+u+v,center-u-v,center+u+v,center-u+v]: _vertex(marks,p,Vector3.UP)
	_mesh(marks.commit(),_mats.bronze)
	_build_balustrade()

func _ring(at: Vector3, radius: float, thickness: float, material: Material, vertical: bool=false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a := float(i)*TAU/128.0
		var b := float(i+1)*TAU/128.0
		var p0 := Vector3(cos(a)*radius,0,sin(a)*radius)
		var p1 := Vector3(cos(a)*(radius+thickness),0,sin(a)*(radius+thickness))
		var p2 := Vector3(cos(b)*(radius+thickness),0,sin(b)*(radius+thickness))
		var p3 := Vector3(cos(b)*radius,0,sin(b)*radius)
		for p in [p0,p1,p2,p0,p2,p3]:
			_vertex(surface,at+(Vector3(p.x,p.z,0) if vertical else p),Vector3.BACK if vertical else Vector3.UP)
	_mesh(surface.commit(),material)

func _build_balustrade() -> void:
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for j in 4:
			var x: float = side*(3.6+float(j)*1.45)
			_box_faces(rails,Vector3(0.24,0.72,0.28),Vector3(x,0.29,-3.95))
			_slab(rails,Vector3(x,0,-3.95),0.38,0.40,0.08,0.72,0.61)
			if j<3:
				_box_faces(rails,Vector3(1.27,0.13,0.18),Vector3(x+side*0.72,0.55,-3.95))
				_box_faces(rails,Vector3(1.27,0.10,0.14),Vector3(x+side*0.72,0.14,-3.95))
				_box_faces(rails,Vector3(0.08,0.31,0.12),Vector3(x+side*0.72,0.34,-3.95))
	_mesh(rails.commit(),_mats.stone)
	# The central stairs leave a clean horizon behind the active fighting lane.
	for i in 4:
		_box(Vector3(6.2-float(i)*0.18,0.18,0.36),Vector3(0,-0.16-float(i)*0.17,-4.25-float(i)*0.29),_mats.edge)

func _rock_island(at: Vector3, width: float, depth: float, height: float, seed_value: int) -> void:
	# A flat planted shelf and irregular strata give every building a physical
	# footing. The tapered cliff continues down into the cloud bank.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array = []
	var segments := 22
	var profile := [Vector3(0.0,0.93,0.0),Vector3(-0.15,1.0,0.05),Vector3(-0.38,0.96,-0.02),Vector3(-0.72,0.77,0.07),Vector3(-1.0,0.45,0.15)]
	var irregular: Array[float] = []
	for i in segments: irregular.append(rng.randf_range(0.88,1.10))
	for layer: Vector3 in profile:
		var ring: Array[Vector3] = []
		for i in segments:
			var angle := float(i)*TAU/float(segments)
			var radius: float = irregular[i]*layer.y
			var y: float = layer.x*height
			if layer.x < -0.01: y += rng.randf_range(-0.10,0.10)*height
			ring.append(at+Vector3(cos(angle)*width*0.5*radius+layer.z*width,y,sin(angle)*depth*0.5*radius))
		rings.append(ring)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for point in [at,rings[0][i],rings[0][(i+1)%segments]]: _vertex(top,point,Vector3.UP)
	_mesh(top.commit(),_mats.garden)
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(rings.size()-1):
		for i in segments:
			var j := (i+1)%segments
			var a: Vector3 = rings[layer][i]
			var b: Vector3 = rings[layer][j]
			var c: Vector3 = rings[layer+1][i]
			var d: Vector3 = rings[layer+1][j]
			var normal := (b-a).cross(c-a).normalized()
			var color := Color.WHITE.darkened(0.04+float(layer)*0.09+rng.randf_range(0.0,0.08))
			for point in [a,c,b,b,c,d]: _vertex(cliff,point,normal,color)
	_mesh(cliff.commit(),_mats.rock)

func _build_rear_terrace() -> void:
	# The path joins the fighting platform to the garden, below the fighters'
	# silhouettes. Broad, overlapping shelves avoid isolated floating props.
	_rock_island(Vector3(0,-0.76,-11.8),25.0,14.0,10.0,130+_region)
	var walkway := SurfaceTool.new()
	walkway.begin(Mesh.PRIMITIVE_TRIANGLES)
	_slab(walkway,Vector3(0,0,-7.8),4.8,5.6,0.22,-0.67,-0.94)
	for side in [-1.0,1.0]:
		_box_faces(walkway,Vector3(0.18,0.16,5.1),Vector3(side*2.46,-0.64,-7.8))
	_mesh(walkway.commit(),_mats.stone)
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 6:
		for col in 3:
			_slab(paving,Vector3((col-1)*1.48,0,-5.55-float(row)*0.86),1.465,0.845,0.01,-0.655,-0.68)
	_mesh(paving.commit(),_mats.floor)
	# Short retaining steps anchor the lateral garden terraces.
	for side in [-1.0,1.0]:
		_rock_island(Vector3(side*8.8,-0.25,-12.8),10.2,10.0,9.0,190+int(side)*13+_region)

func _mist(at: Vector3, size: Vector2, color: Color, phase: float) -> void:
	var plane := QuadMesh.new()
	plane.size = size
	var material := ShaderMaterial.new()
	material.shader = MIST
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("phase",phase)
	var node := _mesh(plane,material,at)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist_materials.append(material)

func _build_distance(palette: Dictionary) -> void:
	var haze: Color = palette.mist
	# Keep the original complete strip: cutting at quarter boundaries exposes
	# opaque cropped cliffs as vertical seams. Its 4:1 proportions stay intact.
	_native_mountain(Vector3(-25,-12.0,-96),Vector2(144,36),true,haze,0.78)
	# Preserve the source mountain/temple group's relative world transforms.
	# The base sits below the cloud bank; the foreground fighting lane stays flat.
	_native_prop("NativeMountainTemple",Vector3(0,-13.0,-38),0.045,0.0)
	_mist(Vector3(0,-4.5,-29),Vector2(75,7.5),Color(haze.lightened(0.08),0.82),2.0)
	_mist(Vector3(0,-3.9,-8.0),Vector2(48,4.8),Color(haze.lightened(0.12),0.60),5.0)
	_mist(Vector3(-8,3.4,-48),Vector2(65,3.0),Color(haze.lightened(0.18),0.23),8.0)
	_mist(Vector3(-16,8.1,-58),Vector2(62,3.8),Color(palette.horizon,0.48),4.0)
	_mist(Vector3(24,5.4,-51),Vector2(34,1.6),Color(palette.horizon,0.38),9.0)
	if _region!=1:
		var disk := CylinderMesh.new()
		disk.top_radius = 3.0 if _region==2 else 1.55
		disk.bottom_radius = disk.top_radius
		disk.height = 0.01
		disk.radial_segments = 96
		var sun_disk := _mesh(disk,_flat(Color("dfa578") if _region==2 else Color("f4e8be")),Vector3(-14 if _region==2 else 17,5.6,-49))
		sun_disk.rotation.x = PI/2.0
		sun_disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _native_mountain(at: Vector3, size: Vector2, flip: bool, haze: Color, amount: float) -> void:
	var path := NATIVE_DIR+"Stage_TaiXu_C_FarMountain_Tex.png"
	if not ResourceLoader.exists(path): return
	var material := ShaderMaterial.new()
	material.shader = NATIVE_CARD
	material.set_shader_parameter("source_texture",load(path))
	material.set_shader_parameter("region",Vector4(1,1,0,0))
	material.set_shader_parameter("flip_x",flip)
	material.set_shader_parameter("haze",haze)
	material.set_shader_parameter("haze_amount",amount)
	material.set_shader_parameter("tint",Color("b3a0bc") if _region==2 else Color("a2bdba"))
	var plane := QuadMesh.new()
	plane.size = size
	var node := _mesh(plane,material,at)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_landmarks(palette: Dictionary) -> void:
	_build_rear_terrace()
	if _region==0:
		_native_prop("TempleUpper",Vector3(-9.0,-0.35,-14.5),0.43,0.15)
		_native_prop("TempleUpper",Vector3(18,-1.65,-32),0.38,-0.28)
		_native_prop("BigTree",Vector3(9.2,-0.25,-12.5),0.42,PI)
		_rock_island(Vector3(18,-1.7,-32),15.0,12.0,20.0,137)
	elif _region==1:
		var bamboo_mats := {"wood":_surface(Color("52765b"),Color("304e43")),"leaf":_mats.leaf}
		for side in [-1.0,1.0]:
			Props.bamboo_grove(_scenery,Vector3(side*8.3,-0.3,-6.8),731+int(side),bamboo_mats)
			Props.bamboo_grove(_scenery,Vector3(side*13.2,-0.6,-11),751+int(side),bamboo_mats)
		var wall := _surface(Color("a5b2a4"),Color("677f72"),0.04)
		_box(Vector3(14,1.00,0.35),Vector3(0,-0.1,-11.8),wall)
		_box(Vector3(14.2,0.12,0.52),Vector3(0,0.46,-11.8),_mats.roof)
		for i in 9:
			_box(Vector3(0.16,1.04,0.43),Vector3((i-4)*1.72,-0.1,-11.8),_mats.edge)
		_box(Vector3(14.2,0.18,0.52),Vector3(0,-0.59,-11.8),_mats.stone)
		_native_prop("TempleUpper",Vector3(-12,-0.2,-16),0.44,0.4)
		_native_prop("BigTree",Vector3(13,-0.4,-18),0.36,-0.7)
		_native_prop("TempleUpper",Vector3(22,-1.65,-35),0.40,-0.28)
		_rock_island(Vector3(22,-1.7,-35),15.0,12.0,20.0,237)
		_rock_island(Vector3(-12,-0.30,-15),8.4,7.5,8.0,207)
	else:
		_native_prop("TempleUpper",Vector3(9.2,-0.35,-15),0.45,-0.25)
		_native_prop("TempleUpper",Vector3(-18,-1.15,-32),0.38,0.28)
		_rock_island(Vector3(-18,-1.2,-32),15.0,12.0,20.0,147)
		_native_prop("BigTree",Vector3(-10,-0.25,-13),0.42,0.0)
		_build_seal_gate()
	for side in [-1.0,1.0]:
		Props.lantern(_scenery,Vector3(side*6.4,0,-4.5),0.75,_mats)
		_native_prop("RockGroup",Vector3(side*10.8,-1.70,-14),0.12,side*0.63+float(_region))
		if _region==2: Props.lantern(_scenery,Vector3(side*8.1,-0.15,-6.2),1.05,_mats)

func _native_prop(asset: String, at: Vector3, size: float, yaw: float=0.0) -> Node3D:
	var scene := load(NATIVE_PROPS+asset+".scn") as PackedScene
	if scene==null: return null
	var prop := scene.instantiate() as Node3D
	prop.position=at
	prop.scale=Vector3.ONE*size
	prop.rotation.y=yaw
	NativeStageMaterials.apply(prop,Color("c6b3aa") if _region==2 else Color.WHITE)
	_scenery.add_child(prop)
	return prop

func _build_seal_gate() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		var x: float = side*7.0
		_slab(surface,Vector3(x,0,-9.0),1.3,1.3,0.18,0.3,-0.4)
		_box_faces(surface,Vector3(0.54,3.5,0.62),Vector3(x,2.05,-9))
		_slab(surface,Vector3(x,0,-9),1.0,0.85,0.12,3.9,3.67)
		_box_faces(surface,Vector3(0.84,0.12,0.76),Vector3(x,3.50,-9))
	_mesh(surface.commit(),_mats.edge)
	_ring(Vector3(-3.4,2.4,-17),1.72,0.045,_mats.bronze,true)
	_ring(Vector3(-3.4,2.4,-17.01),1.57,0.014,_mats.bronze,true)

func set_region(index: int) -> void:
	index = clampi(index,0,2)
	if index==_region: return
	_region = index
	if is_instance_valid(_scenery):
		_scenery.hide()
		_scenery.queue_free()
	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	_scenery.visible = not _ink_cinematic
	add_child(_scenery)
	_animated.clear()
	_mist_materials.clear()
	var p: Dictionary = PALETTES[index]
	_mats = {"floor":_surface(p.stone,p.shade,0.045,"Stage_TaiXu_Grass03_Tex.png"),"stone":_surface(p.stone,p.shade,0.035,"Stage_TaiXu_Props02_Tex.png"),"edge":_surface(p.edge,p.shade,0.04,"Stage_TaiXu_Props02_Tex.png"),"dark":_surface(p.edge.darkened(0.12),p.edge),"wood":_surface(p.wood,p.edge,0.06,"Stage_TaiXu_house04_Tex.png"),"roof":_surface(p.roof,p.edge,0.04,"Stage_TaiXu_house02_Tex.png"),"bronze":_surface(p.bronze,p.edge,0.035),"leaf":_surface(p.leaf,p.edge,0.03),"light":_flat(p.sun),"tree_tint":p.leaf}
	# Large, quiet paving in the active lane; the source's mossy field stone
	# belongs to the garden terraces rather than every foreground slab.
	_mats.floor.set_shader_parameter("surface_texture",load(NATIVE_PROPS+"textures/Stage_TaiXu_Stone02_Tex.png"))
	_mats.floor.set_shader_parameter("native_region",Vector4(1.0,1.0,0.0,0.0))
	_mats.floor.set_shader_parameter("texture_scale",0.35)
	_mats.floor.set_shader_parameter("texture_saturation",0.15)
	_mats.floor.set_shader_parameter("texture_contrast",0.32)
	_mats.floor.set_shader_parameter("base_color",[Color("9ba9b6"),Color("91a5aa"),Color("86838e")][index])
	_mats.floor.set_shader_parameter("weathering",0.06)
	_mats.floor.set_shader_parameter("grain_strength",0.012)
	_mats.garden = _surface(p.stone,p.shade,0.025,NATIVE_PROPS+"textures/Stage_TaiXu_Stone02_Tex.png")
	_mats.garden.set_shader_parameter("texture_scale",0.27)
	_mats.garden.set_shader_parameter("texture_saturation",0.72)
	_mats.garden.set_shader_parameter("base_color",[Color("99aaa8"),Color("8aa49a"),Color("817c89")][index])
	_mats.stone.set_shader_parameter("native_region",Vector4(0.32,0.30,0.02,0.02))
	_mats.edge.set_shader_parameter("native_region",Vector4(0.32,0.30,0.02,0.02))
	_mats.edge.set_shader_parameter("texture_scale",0.45)
	_mats.rock = _surface(p.shade.darkened(0.12),p.edge,0.10,"Stage_TaiXu_Props02_Tex.png")
	_mats.rock.set_shader_parameter("native_region",Vector4(0.32,0.30,0.02,0.02))
	_mats.rock.set_shader_parameter("texture_scale",0.22)
	_mats.leaf.set_shader_parameter("wind_strength",0.035)
	_animated.append(_mats.leaf)
	_sky_material.sky_top_color = p.sky
	_sky_material.sky_horizon_color = p.horizon
	_sky_material.ground_horizon_color = p.horizon
	_sky_material.ground_bottom_color = p.mountain
	_environment.ambient_light_color = Color("e2e9f3") if index!=2 else Color("c7c6d7")
	_environment.fog_light_color = p.mist
	_sun.light_color = p.sun
	_sun.light_energy = 0.70 if index!=2 else 0.58
	_build_platform()
	_build_distance(p)
	_build_landmarks(p)

func update_arena(_delta: float, time: float) -> void:
	for material: ShaderMaterial in _animated: material.set_shader_parameter("elapsed",time)
	for material: ShaderMaterial in _mist_materials: material.set_shader_parameter("elapsed",time)
