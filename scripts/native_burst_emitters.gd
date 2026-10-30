extends RefCounted
## Source particle Initial/Shape/Emission modules. Distortion and mesh emitters
## are intentionally excluded until their source shader/mesh is ported.
var host: Node3D
var catalog: Dictionary
var credits: Dictionary={}
var random:=RandomNumberGenerator.new()
func setup(owner: Node3D) -> void:
	host=owner
	random.seed=3103
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/native-burst/source-emitters.json"))
	for style: String in catalog:
		for row: Dictionary in catalog[style]:
			host.native_textures[row.node]=load(row.texture)
func clear() -> void: credits.clear()
func value(curve: Dictionary) -> float:
	return random.randf_range(float(curve.minScalar),float(curve.scalar)) if int(curve.minMaxState)==3 else float(curve.scalar)
static func curve_at(curve: Dictionary, t: float) -> float:
	if int(curve.get("minMaxState",0)) in [0,3]:return float(curve.get("scalar",1.0))
	var keys: Array=curve.get("maxCurve",{}).get("m_Curve",[])
	if keys.is_empty():return float(curve.get("scalar",1.0))
	if t<=float(keys[0].time):return float(keys[0].value)*float(curve.scalar)
	for i: int in range(1,keys.size()):
		if t>float(keys[i].time):continue
		var a: Dictionary=keys[i-1];var b: Dictionary=keys[i]
		var span:=float(b.time)-float(a.time)
		var u:=clampf((t-float(a.time))/maxf(span,0.0001),0,1)
		return ((2*u*u*u-3*u*u+1)*float(a.value)+(u*u*u-2*u*u+u)*span*float(a.outSlope)+(-2*u*u*u+3*u*u)*float(b.value)+(u*u*u-u*u)*span*float(b.inSlope))*float(curve.scalar)
	return float(keys[-1].value)*float(curve.scalar)
func tick(delta: float) -> void:
	var fighter: Dictionary=host._fighters.get("player",{})
	var style:=str(fighter.get("style",""))
	var remaining:=float(fighter.get("nightBurstRemaining",0.0)) if style=="night_squire" else float(fighter.get("eclipseRemaining",0.0))
	if remaining<=0.0 or float(fighter.get("hp",0.0))<=0.0:
		credits.clear()
		return
	# NL and Dress01 now use their complete native follow modules.
	if host.remaining_native.variant(fighter) in ["blood","shadow"]:return
	for row: Dictionary in catalog.get(style,[]):
		var count:=float(credits.get(row.node,0.0))+float(row.rate)*delta
		var emit:=mini(8,floori(count))
		credits[row.node]=count-floor(count)
		for unused in emit:
			if host.active.size()>=host.MAX_ACTIVE-16:return
			var shape: Dictionary=row.shape
			var radius:=float(shape.radius.value)
			var direction:=Vector3(random.randf_range(-1,1),random.randf_range(-1,1),random.randf_range(-1,1)).normalized()
			var offset:=direction*radius*pow(random.randf(),1.0/3.0)
			if int(shape.type)==5:
				var s: Dictionary=shape.m_Scale
				offset=Vector3(random.randf_range(-0.5,0.5)*float(s.x),random.randf_range(-0.5,0.5)*float(s.y),random.randf_range(-0.5,0.5)*float(s.z))
			var c: Dictionary=row.color.maxColor
			var tint:=Color(float(c.r),float(c.g),float(c.b),float(c.a))
			var speed:=value(row.speed)
			var velocity:=direction*speed if int(shape.type)==0 else Vector3.UP*speed
			var life:=value(row.lifetime)
			var size:=value(row.size)
			var settings: Dictionary={"style":style,"role":"native_burst_follow","billboard":true,"rgb":true,"grow":0.1,"fade_in":0.04,"fade_start":0.65,"velocity":velocity,"follow_id":"player","follow_offset":offset.x,"nativeNode":row.node}
			if row.get("sizeModule",{}).get("enabled",false):settings.native_size=row.sizeModule.curve
			host._stamp(row.node,Vector3(float(fighter.x),1.1,0.0)+offset,Vector2.ONE*size,tint,life,settings)
