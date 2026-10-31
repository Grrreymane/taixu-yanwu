extends RefCounted
## Framing follows the official rise / bird / dive / landing sequence.
## This is a side-view adaptation, not an imported Unity camera track.
## focus={playerX,targetX,facing,aspect,entry,battle}; +Z stays the viewing side.
const DURATION := 3.8
const RETURN_AT := 3.15
const CUTS := [0.30,2.10]
const Flight = preload("res://scripts/phoenix_flight.gd")

static func _shot(position: Vector3, target: Vector3, fov: float, roll: float, label: String, composition: String = "full") -> Dictionary:
	return {"position":position,"target":target,"fov":fov,"roll":roll,"shot":label,"composition":composition}

static func _blend(a: Dictionary, b: Dictionary, amount: float, label: String) -> Dictionary:
	if amount<=0.0: return _shot(a.position,a.target,a.fov,float(a.get("roll",0.0)),label,str(a.get("composition","full")))
	if amount>=1.0: return _shot(b.position,b.target,b.fov,float(b.get("roll",0.0)),label,str(b.get("composition","full")))
	var p := smoothstep(0.0,1.0,clampf(amount,0.0,1.0))
	return _shot(Vector3(a.position).lerp(Vector3(b.position),p),Vector3(a.target).lerp(Vector3(b.target),p),lerpf(float(a.fov),float(b.fov),p),lerpf(float(a.get("roll",0.0)),float(b.get("roll",0.0)),p),label,str(b.get("composition","full")) if p>0.0 else str(a.get("composition","full")))

static func _fit(shot: Dictionary, aspect: float) -> Dictionary:
	var factor := maxf(1.0,1.35/maxf(0.5,aspect))
	shot.position = Vector3(shot.target)+(Vector3(shot.position)-Vector3(shot.target))*factor
	return shot

static func sample(time: float, focus: Dictionary) -> Dictionary:
	var t:=clampf(time,0.0,DURATION)
	var x:=float(focus.get("playerX",0.0))
	var target_x:=float(focus.get("targetX",x+1.35))
	var f:=signf(float(focus.get("facing",1.0)))
	var aspect:=float(focus.get("aspect",16.0/9.0))
	var mid: float=(x+target_x)*0.5
	var battle: Dictionary=focus.get("battle",_shot(Vector3(mid,2.65,9.7),Vector3(mid,1.48,0),34.0,0.0,"battle"))
	var entry: Dictionary=focus.get("entry",battle)
	if entry.is_empty():entry=battle
	var ready:=_fit(_shot(Vector3(x+f*0.4,2.55,6.6),Vector3(x,1.90,0),38.0,0.0,"fire_prepare"),aspect)
	if t<Flight.START:return _blend(entry,ready,smoothstep(0.0,0.22,t),"fire_prepare")
	if Flight.active(t):
		var flight:=Flight.sample(t,x)
		var center: Vector3=flight.center
		var size: Vector3=flight.size
		# Fit the animated bird itself. Camera framing never assumes Fu Hua is
		# still standing on the ground while she has transformed.
		var distance:=maxf(6.4,maxf(size.y,size.x/maxf(aspect,0.4))*0.65/tan(deg_to_rad(21.0))+size.z*0.5)
		var label: String="fire_rise" if t<0.82 else "fire_wings" if t<1.68 else "fire_dive"
		return _shot(center+Vector3(f*0.25,0.35,distance),center,42.0,0.0,label,"transformation")
	var landing:=_fit(_shot(Vector3(mid+f*0.25,2.20,7.2),Vector3(mid,1.35,0),39.0,0.0,"fire_landing"),aspect)
	if t>=RETURN_AT:return _blend(landing,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
	for cue: Vector2 in [Vector2(2.10,2.0),Vector2(2.82,3.0)]:
		var progress: float=(t-cue.x)/0.15
		if progress>=0.0 and progress<=1.0:landing.fov-=cue.y*sin(progress*PI)*(1.0-progress)
	return landing
