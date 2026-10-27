extends RefCounted
## Fits the complete 1.5833-second ND_Ultra activation. Combat burst follows it.
const DURATION := 1.5833333
const RETURN_AT := 1.05
const CUTS := [0.58]
const Blend := preload("res://scripts/fenghuang_camera.gd")

static func sample(time: float, focus: Dictionary) -> Dictionary:
	var t:=clampf(time,0.0,DURATION)
	var x:=float(focus.playerX)
	var facing:=float(focus.facing)
	var aspect:=float(focus.aspect)
	var battle: Dictionary=focus.battle
	var entry: Dictionary=focus.entry
	if entry.is_empty(): entry=battle
	var ready:=Blend._fit(Blend._shot(Vector3(x+facing*2.1,2.2,3.55),Vector3(x,1.90,0),32.0,-1.8*facing,"night_ready","portrait"),aspect)
	var close:=Blend._fit(Blend._shot(Vector3(x+facing*1.6,2.25,3.55),Vector3(x,1.90,0),31.5,-0.6*facing,"night_focus","portrait"),aspect)
	var release:=Blend._fit(Blend._shot(Vector3(x+facing*0.5,1.15,5.7),Vector3(x,1.45,0),37.0,1.0*facing,"night_release"),aspect)
	var settle:=Blend._fit(Blend._shot(Vector3(x+facing*0.2,1.55,6.0),Vector3(x,1.45,0),37.0,0.0,"night_release"),aspect)
	if t<0.10: return Blend._blend(entry,ready,t/0.10,"night_push_in")
	if t<0.58: return Blend._blend(ready,close,(t-0.10)/0.48,"night_focus")
	if t<RETURN_AT: return Blend._blend(release,settle,(t-0.58)/(RETURN_AT-0.58),"night_release")
	return Blend._blend(settle,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
