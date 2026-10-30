extends RefCounted
## Deterministic framing for the two complete original lightning takes.
## Native clips stay intact; these camera beats follow their contact frames.
const Blend := preload("res://scripts/fenghuang_camera.gd")
const SHADOW_DURATION := 3.116667
const FOG_DURATION := 2.733333

static func cuts(profile: String) -> Array:
	return [0.38,1.233333] if profile == "shadow_knight" else [0.24,0.47]

static func return_at(profile: String) -> float:
	return 2.48 if profile == "shadow_knight" else 2.08

static func sample(time: float, focus: Dictionary, profile: String) -> Dictionary:
	var shadow := profile == "shadow_knight"
	var duration := SHADOW_DURATION if shadow else FOG_DURATION
	var impact := 1.233333 if shadow else 0.47
	var t := clampf(time,0.0,duration)
	var x := float(focus.get("playerX",0.0))
	var target_x := float(focus.get("targetX",x+1.35))
	var facing := -1.0 if float(focus.get("facing",1.0)) < 0.0 else 1.0
	var aspect := float(focus.get("aspect",16.0/9.0))
	var middle := (x+target_x)*0.5
	var fallback := Blend._shot(Vector3(middle,2.65,9.7),Vector3(middle,1.48,0),34.0,0.0,"battle")
	var battle: Dictionary = focus.get("battle",fallback)
	if battle.is_empty(): battle = fallback
	var entry: Dictionary = focus.get("entry",battle)
	if entry.is_empty(): entry = battle
	var prefix := "eclipse_" if shadow else "fog_"
	# Leave room for the jump, hands and native wing assembly. Camera stays on
	# the arena's viewing side even when player facing and location are mirrored.
	var ready := Blend._fit(Blend._shot(Vector3(x+facing*2.0,2.4,4.2),Vector3(x+facing*0.05,1.95,0),32.0,-1.5*facing,prefix+"ready","portrait"),aspect)
	if shadow:
		ready = Blend._fit(Blend._shot(Vector3(x+facing*2.4,3.20,4.0),Vector3(x+facing*0.10,2.40,0),32.0,-1.8*facing,prefix+"ready","portrait"),aspect)
	var rise := Blend._fit(Blend._shot(Vector3(middle+facing*1.55,1.60,7.3),Vector3(middle,1.90,0),40.0,-1.5*facing,prefix+"rise"),aspect)
	if shadow:
		rise = Blend._fit(Blend._shot(Vector3(middle+facing*1.65,2.05,8.2),Vector3(middle,2.10,0),40.0,-1.5*facing,prefix+"rise"),aspect)
	var apex := Blend._fit(Blend._shot(Vector3(middle-facing*0.25,3.10,8.1),Vector3(middle,2.0,0),40.0,1.1*facing,prefix+"apex"),aspect)
	var strike := Blend._fit(Blend._shot(Vector3(middle+facing*0.75,1.50,9.4),Vector3(middle,1.65,0),43.0,1.5*facing,prefix+"impact"),aspect)
	if shadow:
		strike = Blend._fit(Blend._shot(Vector3(middle-facing*0.5,1.65,8.3),Vector3(middle,2.05,0),40.0,1.5*facing,prefix+"impact"),aspect)
	var settle := Blend._fit(Blend._shot(Vector3(middle+facing*0.15,1.8,6.7),Vector3(middle,1.55,0),37.5,0.0,prefix+"settle"),aspect)
	var push_end := 0.10 if shadow else 0.07
	var rise_start := 0.38 if shadow else 0.24
	var settle_at := impact+0.28
	var return_time := return_at(profile)
	var shot: Dictionary
	if t < push_end:
		shot = Blend._blend(entry,ready,t/push_end,prefix+"push_in")
	elif t < rise_start:
		shot = ready.duplicate(true)
	elif t < impact:
		shot = Blend._blend(rise,apex,(t-rise_start)/(impact-rise_start),prefix+"rise")
	elif t < settle_at:
		shot = strike.duplicate(true)
	elif t < return_time:
		shot = Blend._blend(strike,settle,(t-settle_at)/(return_time-settle_at),prefix+"settle")
	else:
		shot = Blend._blend(settle,battle,(t-return_time)/(duration-return_time),"return")
	# One restrained lens pulse on the original impact. No premature hit cue.
	var progress := (t-impact)/0.18
	if progress >= 0.0 and progress <= 1.0:
		var pulse := sin(progress*PI)*pow(1.0-progress,0.7)
		shot.fov = float(shot.fov)-2.6*pulse
		shot.roll = float(shot.roll)+0.65*facing*pulse
	return shot
