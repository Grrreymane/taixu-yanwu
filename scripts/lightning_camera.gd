extends RefCounted
## Deterministic framing for the two complete original lightning takes.
## Native clips stay intact; these camera beats follow their contact frames.
const Blend := preload("res://scripts/fenghuang_camera.gd")
const SHADOW_DURATION := 3.116667
const FOG_DURATION := 2.733333

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
	var ready := Blend._fit(Blend._shot(Vector3(x+facing*1.5,2.55,7.1),Vector3(x+facing*0.10,1.65,0),37.0,-0.9*facing,prefix+"ready"),aspect)
	if shadow:
		ready = Blend._fit(Blend._shot(Vector3(x+facing*1.5,3.0,8.1),Vector3(x+facing*0.10,2.0,0),37.0,-0.9*facing,prefix+"ready"),aspect)
	var rise := Blend._fit(Blend._shot(Vector3(middle+facing*0.55,2.9,8.9),Vector3(middle,1.90,0),39.0,-0.5*facing,prefix+"rise"),aspect)
	var strike := Blend._fit(Blend._shot(Vector3(middle+facing*0.25,1.75,8.3),Vector3(middle,1.44,0),39.0,0.6*facing,prefix+"impact"),aspect)
	if shadow:
		strike = Blend._fit(Blend._shot(Vector3(middle+facing*0.25,2.1,9.0),Vector3(middle,1.8,0),39.0,0.6*facing,prefix+"impact"),aspect)
	var settle := Blend._fit(Blend._shot(Vector3(middle+facing*0.4,2.0,8.5),Vector3(middle,1.52,0),37.5,0.0,prefix+"settle"),aspect)
	var push_end := 0.20 if shadow else 0.12
	var rise_end := 0.94 if shadow else 0.30
	var settle_at := impact+0.28
	var return_time := return_at(profile)
	var shot: Dictionary
	if t < push_end:
		shot = Blend._blend(entry,ready,t/push_end,prefix+"push_in")
	elif t < rise_end:
		shot = Blend._blend(ready,rise,(t-push_end)/(rise_end-push_end),prefix+"rise")
	elif t < impact:
		shot = Blend._blend(rise,strike,(t-rise_end)/(impact-rise_end),prefix+"descent")
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
		shot.fov = float(shot.fov)-1.7*pulse
		shot.roll = float(shot.roll)+0.45*facing*pulse
	return shot
