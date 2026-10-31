extends RefCounted
## Native JW bird motion. Only forward travel is compressed into the duel lane;
## height, wing animation and the dive come from the original skeleton.
const START := 0.30
const CONTACT := 2.10
const SOURCE_START := 0.10
const SOURCE_END := 1.916667
const SCALE := 0.65
static var samples: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/phoenix-native/flight.json"))

static func active(time: float) -> bool:
	return time>=START and time<CONTACT

static func source_time(time: float) -> float:
	return lerpf(SOURCE_START,SOURCE_END,clampf((time-START)/(CONTACT-START),0.0,1.0))

static func vector(row: Dictionary,key: String) -> Vector3:
	var v: Array=row[key]
	return Vector3(v[0],v[1],v[2])

static func sample(time: float, x: float) -> Dictionary:
	var source:=source_time(time)
	var i:=mini(samples.size()-2,floori(source*60.0))
	var a: Dictionary=samples[i]
	var b: Dictionary=samples[i+1]
	var blend:=clampf((source-float(a.time))/maxf(0.00001,float(b.time)-float(a.time)),0.0,1.0)
	var anchor:=vector(a,"anchor").lerp(vector(b,"anchor"),blend)
	var center:=vector(a,"center").lerp(vector(b,"center"),blend)
	var size:=vector(a,"size").lerp(vector(b,"size"),blend)*SCALE
	var depth:=lerpf(-0.35,0.0,clampf((anchor.z+0.130815)/8.55,0.0,1.0))
	var origin:=Vector3(x,0.30,depth-anchor.z*SCALE)
	return {"sourceTime":source,"origin":origin,"anchor":origin+anchor*SCALE,"center":origin+center*SCALE,"size":size}
