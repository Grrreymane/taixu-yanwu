extends RefCounted
## Source FK/QYHY and NL Dress01 modules, retimed at our combat cue boundaries.
## Original emitter modules and mesh geometry; screen distortion is omitted.
const Curves=preload("res://scripts/native_burst_emitters.gd")
var host: Node3D
var catalog: Dictionary={}
var meshes: Dictionary={}
var emitters: Array[Dictionary]=[]
var follow_style: String=""
var appearance: String="default"
var fog_release_remaining:=0.0
var rng:=RandomNumberGenerator.new()
func setup(owner: Node3D) -> void:
	host=owner;rng.seed=3103
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/remaining-native/emitters.json"))
	var source_meshes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/remaining-native/meshes.json"))
	for key: String in source_meshes:
		var data: Dictionary=source_meshes[key]
		var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
		for i in range(0,data.vertices.size(),3): vertices.append(Vector3(data.vertices[i],data.vertices[i+1],-float(data.vertices[i+2])))
		for i in range(0,data.uv0.size(),2): uvs.append(Vector2(data.uv0[i],1.0-float(data.uv0[i+1])))
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(data.indices)
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		meshes[key]=mesh
	for group: String in catalog:
		for row: Dictionary in catalog[group]:
			host.native_textures[row.node]=load(row.texture)
			var transform:=Transform3D.IDENTITY
			for tr: Dictionary in row.transforms:
				var q: Dictionary=tr.rotation;var s: Dictionary=tr.scale;var p: Dictionary=tr.position
				transform*=Transform3D(Basis(Quaternion(-float(q.X),-float(q.Y),float(q.Z),float(q.W)).normalized()).scaled_local(Vector3(s.X,s.Y,s.Z)),Vector3(p.X,p.Y,-float(p.Z)))
			row.nativeTransform=transform
func clear() -> void:
	emitters.clear();follow_style="";appearance="default";fog_release_remaining=0.0
func variant(data: Dictionary) -> String:
	var fighter: Dictionary=host._fighters.get("player",{})
	var style:=str(data.get("style",fighter.get("style","")))
	if data.has("appearanceId"):appearance=str(data.appearanceId)
	if style=="hawk_of_the_fog":return "fog"
	if style=="shadow_knight" and appearance=="blood_moon":return "blood"
	return ""
func start(group: String, data: Dictionary, follow: bool=false) -> void:
	for row: Dictionary in catalog.get(group,[]):
		emitters.append({"row":row,"time":-float(row.data.startDelay.scalar),"credit":0.0,"bursts":{},"data":data.duplicate(),"follow":follow})
func event(data: Dictionary) -> bool:
	var profile:=variant(data)
	if profile.is_empty():return false
	match str(data.type):
		"ultimate":
			if profile=="fog":
				start("fog_charge",data)
				fog_release_remaining=2.0
			else:host.lightning.ultimate(data)
			host._sound("ultimate")
		"ultimateImpact":
			start(profile+"_impact",data)
			if profile=="fog":start("fog_strike",data)
			host._sound("heavy")
	return true
func sample(curve: Dictionary) -> float:
	if int(curve.minMaxState)==3:return rng.randf_range(float(curve.minScalar),float(curve.scalar))
	return Curves.curve_at(curve,rng.randf()) if int(curve.minMaxState)==1 else float(curve.scalar)
func gradient(g: Dictionary,p: float,alpha: bool=false) -> Color:
	var count:=int(g.get("m_NumAlphaKeys" if alpha else "m_NumColorKeys",0))
	if count==0:return Color.WHITE
	var prefix: String="atime" if alpha else "ctime"
	var previous:=0
	for i in count:
		var time:=float(g.get(prefix+str(i),0))/65535.0
		if time>=p or i==count-1:
			var a: Dictionary=g["key"+str(previous)];var b: Dictionary=g["key"+str(i)]
			var start_time:=float(g.get(prefix+str(previous),0))/65535.0
			var u:=clampf((p-start_time)/maxf(time-start_time,0.0001),0,1)
			return Color(a.r,a.g,a.b,a.a).lerp(Color(b.r,b.g,b.b,b.a),u)
		previous=i
	return Color.WHITE
func tick(delta: float) -> void:
	if delta<=0.0:return
	fog_release_remaining=maxf(0.0,fog_release_remaining-delta)
	var fighter: Dictionary=host._fighters.get("player",{})
	var profile:=variant(fighter)
	var active: bool=float(fighter.get("hp",0.0))>0.0 and ((profile=="fog" and (int(fighter.get("fogCharges",0))>0 or fog_release_remaining>0.0)) or (profile=="blood" and float(fighter.get("eclipseRemaining",0.0))>0))
	if not active:profile=""
	if profile!=follow_style:
		emitters=emitters.filter(func(e):return not e.follow)
		follow_style=profile
		if not profile.is_empty():start(profile+"_follow",fighter,true)
	for index in range(emitters.size()-1,-1,-1):
		var e: Dictionary=emitters[index];var d: Dictionary=e.row.data
		e.time=float(e.time)+delta
		if float(e.time)<0:continue
		if not e.follow and float(e.time)>float(d.lengthInSec):
			emitters.remove_at(index);continue
		if not bool(d.EmissionModule.enabled):continue
		var credit:=float(e.credit)+maxf(0.0,Curves.curve_at(d.EmissionModule.rateOverTime,fposmod(float(e.time),float(d.lengthInSec))/float(d.lengthInSec)))*delta
		var count:=floori(credit);e.credit=credit-count
		for i in d.EmissionModule.m_Bursts.size():
			var burst: Dictionary=d.EmissionModule.m_Bursts[i]
			if not e.bursts.has(i) and float(e.time)>=float(burst.time):
				count+=roundi(sample(burst.countCurve));e.bursts[i]=true
		var live:=0
		for item: Dictionary in host.active:
			if item.settings.get("nativeNode","")==e.row.node:live+=1
		count=mini(count,mini(12,int(d.InitialModule.maxNumParticles)-live))
		for unused in maxi(0,count):
			if host.active.size()>=host.MAX_ACTIVE-12:break
			spawn(e,fighter)
func spawn(e: Dictionary,fighter: Dictionary) -> void:
	var row: Dictionary=e.row;var d: Dictionary=row.data;var init: Dictionary=d.InitialModule
	var shape: Dictionary=d.ShapeModule
	var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
	var offset:=Vector3.ZERO
	if bool(shape.enabled):
		offset=direction*float(shape.radius.value)*pow(rng.randf(),1.0/3.0)
		if int(shape.type) in [2,4]:
			var angle:=rng.randf()*TAU
			var radius:=float(shape.radius.value)*sqrt(rng.randf())
			var depth:=rng.randf()*float(shape.length) if int(shape.type)==4 else 0.0
			var spread:=tan(deg_to_rad(float(shape.angle)))
			offset=Vector3(cos(angle)*(radius+depth*spread),sin(angle)*(radius+depth*spread),-depth)
			direction=Vector3(cos(angle)*spread,sin(angle)*spread,-1).normalized()
		elif int(shape.type)==5:
			offset=Vector3(direction.x*float(shape.m_Scale.x),direction.y*float(shape.m_Scale.y),direction.z*float(shape.m_Scale.z))*0.5
			direction=Vector3.FORWARD
		elif int(shape.type)==10:
			var angle:=rng.randf()*deg_to_rad(float(shape.arc.value))
			direction=Vector3(cos(angle),sin(angle),0)
			offset=direction*float(shape.radius.value)*sqrt(rng.randf())
		if float(shape.randomDirectionAmount)>0.0:
			direction=direction.lerp(Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized(),float(shape.randomDirectionAmount)).normalized()
	else:direction=Vector3.FORWARD
	var x:=float(fighter.get("x",0.0)) if e.follow else float(e.data.get("x",0.0))
	var renderer: Dictionary=row.renderer
	var mode:=int(renderer.mode)
	var ground: bool=mode==2
	var impact: bool=str(row.node).contains("_Ground/") or str(row.node).contains("UltraThunder_")
	var position:=Vector3(x,0.05 if impact or ground else 1.1,0.0)
	var native_transform: Transform3D=row.nativeTransform
	var source_scale:=native_transform.basis.get_scale().abs()
	# Uniform arena conversion, retaining source relative scale and timing.
	var unit: float=0.45 if not e.follow else 1.0
	var basis:=native_transform.basis.orthonormalized()
	var facing:=float(e.data.get("facing",fighter.get("facing",1.0)))
	var facing_basis:=Basis(Vector3.UP,-facing*PI*0.5)
	position+=facing_basis*native_transform.origin*unit
	position+=facing_basis*basis*offset*unit
	var c: Dictionary=init.startColor.maxColor;var m: Dictionary=row.tint
	var color:=Color(c.r*m.R,c.g*m.G,c.b*m.B,c.a*m.A)
	var size:=sample(init.startSize)*unit
	var velocity:=facing_basis*basis*direction*sample(init.startSpeed)*unit
	var settings: Dictionary={"style":e.data.get("style",fighter.get("style","")),"role":"source_ultimate_follow" if e.follow else "source_ultimate","nativeNode":row.node,"source_module":d,"source_tint":color,"billboard":mode in [0,1],"ground":ground,"rgb":true,"additive":not str(row.texture).contains("Smoke") and not str(row.texture).contains("Ground"),"instant":true,"grow":1.0,"velocity":velocity,"angle":sample(init.startRotation),"source_renderer":renderer,"source_basis":facing_basis*basis}
	if e.follow:settings.merge({"follow_id":"player","follow_offset":position.x-x})
	var item: Dictionary=host._stamp(row.node,position,Vector2(size*maxf(source_scale.x,0.01),size*maxf(source_scale.y,0.01)),color,maxf(0.02,sample(init.startLifetime)),settings)
	if item.is_empty():return
	if mode==4:
		if not renderer.meshes.is_empty():item.node.mesh=meshes[renderer.meshes[rng.randi_range(0,renderer.meshes.size()-1)]]
		var scale:=Vector3.ONE*size
		if bool(init.size3D):scale=Vector3(size,sample(init.startSizeY)*unit,sample(init.startSizeZ)*unit)
		item.base_scale=scale*source_scale
		var rotation:=Vector3(0,0,float(settings.angle))
		if bool(init.rotation3D):rotation=Vector3(-sample(init.startRotationX),-sample(init.startRotationY),float(settings.angle))
		item.settings.source_basis=facing_basis*basis*Basis.from_euler(rotation)
	elif mode==1:
		# Unity stretched billboards align their long axis with particle velocity.
		item.base_scale.y*=maxf(1.0,absf(float(renderer.lengthScale)))
	var st: Array=row.textureST
	item.settings.source_st=Vector4(st[0],st[1],st[2],1.0-float(st[1])-float(st[3]))
	var colors: Dictionary=row.materialColors
	if colors.has("_TintColor0"):
		item.mat.set_shader_parameter("channel_tints",true)
		for i in 3:
			var channel: Dictionary=colors.get("_TintColor"+str(i),{"R":1,"G":1,"B":1,"A":1})
			item.mat.set_shader_parameter("channel_"+str(i),Color(channel.R,channel.G,channel.B,channel.A))
	present_particle(item,0.0)
func present_particle(item: Dictionary,p: float) -> void:
	var d: Dictionary=item.settings.source_module
	var tint: Color=item.settings.source_tint
	if bool(d.ColorModule.enabled):
		var g: Dictionary=d.ColorModule.gradient.maxGradient
		var rgb:=gradient(g,p);var alpha:=gradient(g,p,true)
		tint*=Color(rgb.r,rgb.g,rgb.b,alpha.a)
	item.mat.set_shader_parameter("tint",tint)
	item.mat.set_shader_parameter("opacity",1.0)
	item.mat.set_shader_parameter("uv_transform",item.settings.get("source_st",Vector4(1,1,0,0)))
	if bool(d.SizeModule.enabled):item.node.scale=item.base_scale*maxf(0.001,Curves.curve_at(d.SizeModule.curve,p))
	var uv: Dictionary=d.UVModule
	if bool(uv.enabled):
		var nx:=maxi(1,int(uv.tilesX));var ny:=maxi(1,int(uv.tilesY))
		var frame:=floori(Curves.curve_at(uv.frameOverTime,p)*float(uv.cycles)*nx*ny)% (nx*ny)
		var st: Vector4=item.settings.get("source_st",Vector4(1,1,0,0))
		item.mat.set_shader_parameter("uv_transform",Vector4(st.x/nx,st.y/ny,float(frame%nx)/nx+st.z,float(frame/nx)/ny+st.w))
	var renderer: Dictionary=item.settings.source_renderer
	if int(renderer.mode)==4:
		var scale: Vector3=item.node.scale
		item.node.basis=item.settings.source_basis
		item.node.scale=scale
	elif int(renderer.mode)==1:
		var camera: Camera3D=host.get_viewport().get_camera_3d()
		var velocity: Vector3=item.settings.velocity
		if camera!=null and velocity.length_squared()>0.00001:
			var towards: Vector3=(camera.global_position-item.node.global_position).normalized()
			var up: Vector3=velocity.normalized()
			var right:=up.cross(towards).normalized()
			if right.length_squared()>0.01:
				var scale: Vector3=item.node.scale
				item.node.basis=Basis(right,towards.cross(right).normalized(),towards)
				item.node.scale=scale
