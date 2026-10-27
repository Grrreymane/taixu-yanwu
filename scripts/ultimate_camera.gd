extends RefCounted

# Authored against the original 3.3-second Ultra action. The same simulation
# clock drives camera, animation and ink; pausing never advances this timeline.
# All shots stay on +Z, preserving the side-view axis and the ink card faces.
const DURATION:=3.3
const RETURN_AT:=2.83
const CUTS:=[0.56,1.65,2.65]
const Blend:=preload("res://scripts/fenghuang_camera.gd")

static func _shot(position: Vector3,target: Vector3,fov: float,roll: float,name: String,composition: String="full") -> Dictionary:
 return Blend._shot(position,target,fov,roll,name,composition)

static func _blend(a: Dictionary,b: Dictionary,amount: float,name: String) -> Dictionary:
 return Blend._blend(a,b,amount,name)

static func _frame(shot: Dictionary,aspect: float) -> Dictionary:
 # A narrow browser gets more breathing room without changing shot direction.
 var factor: float=maxf(1.0,1.35/maxf(aspect,0.5))
 shot.position=Vector3(shot.target)+(Vector3(shot.position)-Vector3(shot.target))*factor
 return shot

static func sample(time: float,player_x: float,target_x: float,facing: float,aspect: float,entry: Dictionary,battle: Dictionary) -> Dictionary:
 var t: float=clampf(time,0.0,DURATION)
 var f: float=-1.0 if facing<0.0 else 1.0
 var mid: float=(player_x+target_x)*0.5
 var opening: Dictionary=_frame(_shot(Vector3(player_x+f*3.8,1.95,3.15),Vector3(player_x,2.15,0),31.0,-2.1*f,"seal","portrait"),aspect)
 var portrait: Dictionary=_frame(_shot(Vector3(player_x+f*3.35,1.90,3.15),Vector3(player_x+f*0.08,2.18,0),30.0,-0.7*f,"seal","portrait"),aspect)
 if t<0.10: return _blend(entry,opening,t/0.10,"push_in")
 if t<0.56: return _blend(opening,portrait,(t-0.10)/0.46,"seal")
 if t<1.65:
  var low: Dictionary=_frame(_shot(Vector3(player_x+f*2.4,1.65,5.75),Vector3(player_x+f*0.12,2.15,0),37.0,-2.0*f,"gather"),aspect)
  var high: Dictionary=_frame(_shot(Vector3(player_x+f*0.65,2.45,6.1),Vector3(player_x+f*0.12,2.15,0),38.0,1.2*f,"gather"),aspect)
  return _blend(low,high,(t-0.56)/1.09,"gather")
 var launch: Dictionary=_frame(_shot(Vector3(mid+f*2.15,3.25,6.6),Vector3(mid+f*0.20,1.85,0),39.0,1.8*f,"release"),aspect)
 var track: Dictionary=_frame(_shot(Vector3(mid+f*0.5,2.15,6.8),Vector3(mid+f*0.15,1.65,0),39.5,-0.6*f,"release"),aspect)
 if t<2.65: return _blend(launch,track,(t-1.65)/1.0,"release")
 var landing: Dictionary=_frame(_shot(Vector3(mid-f*0.65,1.1,6.65),Vector3(target_x-f*0.55,1.45,0),39.0,-1.3*f,"impact"),aspect)
 if t<RETURN_AT:
  # The cut and short lens kick land on the real final damage cue.
  var progress: float=(t-2.65)/0.18
  var pulse: float=sin(progress*PI)*pow(maxf(0.0,1.0-progress),0.7)
  landing.fov-=3.0*pulse
  landing.roll+=1.4*f*pulse
  return landing
 return _blend(landing,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
