extends RefCounted
## Authored 3.8-second fire sequence. No internal clock or scene mutation.
## focus={playerX,targetX,facing,aspect,entry,battle}; +Z stays the viewing side.
const DURATION := 3.8
const RETURN_AT := 3.15
const CUTS := [0.62,2.10,2.82]

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
	var t := clampf(time,0.0,DURATION)
	var x := float(focus.get("playerX",0.0))
	var target_x := float(focus.get("targetX",x+1.35))
	var f := -1.0 if float(focus.get("facing",1.0)) < 0.0 else 1.0
	var aspect := float(focus.get("aspect",16.0/9.0))
	var mid := (x+target_x)*0.5
	var fallback := _shot(Vector3(mid,2.65,9.7),Vector3(mid,1.48,0),34.0,0.0,"battle")
	var battle: Dictionary = focus.get("battle",fallback)
	var entry: Dictionary = focus.get("entry",battle)
	if entry.is_empty(): entry = battle
	# The salute is an upper-body insert, not a full-body safety shot. Cut to
	# the wider rise before the native airborne pose reaches its apex.
	var salute := _fit(_shot(Vector3(x+f*2.25,3.25,3.55),Vector3(x+f*0.05,2.80,0),31.5,-2.0*f,"fire_salute","portrait"),aspect)
	var close := _fit(_shot(Vector3(x+f*1.65,3.50,3.55),Vector3(x+f*0.10,3.10,0),31.0,-1.0*f,"fire_salute","portrait"),aspect)
	var gather := _fit(_shot(Vector3(x+f*2.45,1.80,6.45),Vector3(x+f*0.15,2.15,0),39.0,-1.8*f,"fire_rise"),aspect)
	var wings := _fit(_shot(Vector3(mid+f*0.55,2.6,6.8),Vector3(mid,2.05,0),40.0,1.0*f,"fire_wings"),aspect)
	var launch := _fit(_shot(Vector3(mid-f*0.55,2.35,7.0),Vector3(mid,1.85,0),40.0,0.6*f,"fire_launch"),aspect)
	var contact := _fit(_shot(Vector3(mid+f*1.20,1.35,6.65),Vector3(mid+f*0.10,1.42,0),38.0,-1.4*f,"fire_first_contact"),aspect)
	var landing := _fit(_shot(Vector3(mid-f*0.45,1.42,6.9),Vector3(mid+f*0.18,1.55,0),39.0,1.2*f,"fire_impact"),aspect)
	var shot: Dictionary
	if t < 0.12:
		shot = _blend(entry,salute,t/0.12,"fire_push_in")
	elif t < 0.62:
		shot = _blend(salute,close,(t-0.12)/0.50,"fire_salute")
	elif t < 1.65:
		shot = _blend(gather,wings,(t-0.62)/1.03,"fire_wings")
	elif t < 2.10:
		shot = _blend(wings,launch,(t-1.65)/0.45,"fire_launch")
	elif t < 2.82:
		shot = contact.duplicate(true)
	elif t < RETURN_AT:
		shot = landing.duplicate(true)
	else:
		shot = _blend(landing,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
	# Short lens accents start on the damage cues, never on an empty windup.
	# A sine envelope is continuous on entry and exit, and deterministic on pause.
	for cue: Vector2 in [Vector2(2.10,2.0),Vector2(2.82,3.0)]:
		var progress := (t-cue.x)/0.15
		if progress >= 0.0 and progress <= 1.0:
			var pulse := sin(progress*PI)*pow(1.0-progress,0.7)
			shot.fov = float(shot.fov)-cue.y*pulse
			shot.roll = float(shot.roll)+f*0.8*pulse
	return shot
