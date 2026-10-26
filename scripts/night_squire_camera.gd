extends RefCounted
## Fits the complete 1.5833-second ND_Ultra activation. Combat burst follows it.
const DURATION := 1.5833333
const RETURN_AT := 1.05
const Blend := preload("res://scripts/fenghuang_camera.gd")

static func sample(time: float, focus: Dictionary) -> Dictionary:
	var t:=clampf(time,0.0,DURATION)
	var x:=float(focus.playerX)
	var facing:=float(focus.facing)
	var aspect:=float(focus.aspect)
	var battle: Dictionary=focus.battle
	var entry: Dictionary=focus.entry
	if entry.is_empty(): entry=battle
	var ready:=Blend._fit(Blend._shot(Vector3(x+facing*2.7,2.05,4.8),Vector3(x,1.60,0),35.0,-1.0*facing,"night_ready"),aspect)
	var release:=Blend._fit(Blend._shot(Vector3(x+facing*1.8,1.85,5.5),Vector3(x,1.45,0),36.5,0.0,"night_release"),aspect)
	if t<0.20: return Blend._blend(entry,ready,t/0.20,"night_push_in")
	if t<RETURN_AT: return Blend._blend(ready,release,(t-0.20)/(RETURN_AT-0.20),"night_release")
	return Blend._blend(release,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
