extends RefCounted
## Authored 3.8-second fire sequence. No internal clock or scene mutation.
## focus={playerX,targetX,facing,aspect,entry,battle}; +Z stays the viewing side.
const DURATION := 3.8
const RETURN_AT := 3.15

static func _shot(position: Vector3, target: Vector3, fov: float, roll: float, label: String) -> Dictionary:
	return {"position":position,"target":target,"fov":fov,"roll":roll,"shot":label}

static func _blend(a: Dictionary, b: Dictionary, amount: float, label: String) -> Dictionary:
	var p := smoothstep(0.0,1.0,clampf(amount,0.0,1.0))
	return _shot(Vector3(a.position).lerp(Vector3(b.position),p),Vector3(a.target).lerp(Vector3(b.target),p),lerpf(float(a.fov),float(b.fov),p),lerpf(float(a.get("roll",0.0)),float(b.get("roll",0.0)),p),label)

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
	var salute := _fit(_shot(Vector3(x+f*2.3,2.75,5.4),Vector3(x+f*0.08,2.45,0),35.0,-1.5*f,"fire_salute"),aspect)
	var gather := _fit(_shot(Vector3(x+f*1.2,2.7,7.2),Vector3(x+f*0.12,2.35,0),36.5,-1.0*f,"fire_gather"),aspect)
	var wings := _fit(_shot(Vector3(mid+f*0.8,2.15,8.1),Vector3(mid,1.90,0),38.0,1.0*f,"fire_wings"),aspect)
	var launch := _fit(_shot(Vector3(mid+f*0.6,1.9,8.2),Vector3(mid,1.55,0),38.0,0.6*f,"fire_launch"),aspect)
	var landing := _fit(_shot(Vector3(mid+f*0.8,1.65,8.6),Vector3(mid+f*0.18,1.55,0),39.0,-0.8*f,"fire_impact"),aspect)
	var shot: Dictionary
	if t < 0.22:
		shot = _blend(entry,salute,t/0.22,"fire_push_in")
	elif t < 0.75:
		shot = _blend(salute,gather,(t-0.22)/0.53,"fire_gather")
	elif t < 1.65:
		shot = _blend(gather,wings,(t-0.75)/0.90,"fire_wings")
	elif t < 2.10:
		shot = _blend(wings,launch,(t-1.65)/0.45,"fire_launch")
	elif t < 2.45:
		shot = _blend(launch,landing,(t-2.10)/0.35,"fire_first_contact")
	elif t < RETURN_AT:
		shot = landing.duplicate(true)
	else:
		shot = _blend(landing,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
	# Short lens accents start on the damage cues, never on an empty windup.
	# A sine envelope is continuous on entry and exit, and deterministic on pause.
	for cue: Vector2 in [Vector2(2.10,1.6),Vector2(2.82,2.5)]:
		var progress := (t-cue.x)/0.15
		if progress >= 0.0 and progress <= 1.0:
			var pulse := sin(progress*PI)*pow(1.0-progress,0.7)
			shot.fov = float(shot.fov)-cue.y*pulse
			shot.roll = float(shot.roll)+f*0.8*pulse
	return shot
