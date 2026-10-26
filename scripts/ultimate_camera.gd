extends RefCounted

# Authored against the original 3.3-second Ultra action. The same simulation
# clock drives camera, animation and ink; pausing never advances this timeline.
# All shots stay on +Z, preserving the side-view axis and the ink card faces.
const DURATION:=3.3
const RETURN_AT:=2.83

static func _shot(position: Vector3,target: Vector3,fov: float,roll: float,name: String) -> Dictionary:
 return {"position":position,"target":target,"fov":fov,"roll":roll,"shot":name}

static func _blend(a: Dictionary,b: Dictionary,amount: float,name: String) -> Dictionary:
 var p: float=smoothstep(0.0,1.0,clampf(amount,0.0,1.0))
 return _shot(Vector3(a.position).lerp(b.position,p),Vector3(a.target).lerp(b.target,p),lerpf(a.fov,b.fov,p),lerpf(a.roll,b.roll,p),name)

static func _frame(shot: Dictionary,aspect: float) -> Dictionary:
 # A narrow browser gets more breathing room without changing shot direction.
 var factor: float=maxf(1.0,1.35/maxf(aspect,0.5))
 shot.position=Vector3(shot.target)+(Vector3(shot.position)-Vector3(shot.target))*factor
 return shot

static func sample(time: float,player_x: float,target_x: float,facing: float,aspect: float,entry: Dictionary,battle: Dictionary) -> Dictionary:
 var t: float=clampf(time,0.0,DURATION)
 var f: float=-1.0 if facing<0.0 else 1.0
 var mid: float=(player_x+target_x)*0.5
 var opening: Dictionary=_frame(_shot(Vector3(player_x+f*3.0,2.35,4.0),Vector3(player_x,2.08,0),36.0,-1.3*f,"seal"),aspect)
 var portrait: Dictionary=_frame(_shot(Vector3(player_x+f*2.6,2.5,3.6),Vector3(player_x+f*0.08,2.20,0),34.0,-1.8*f,"seal"),aspect)
 if t<0.14: return _blend(entry,opening,t/0.14,"push_in")
 if t<0.60: return _blend(opening,portrait,(t-0.14)/0.46,"seal")
 if t<1.65:
  var low: Dictionary=_frame(_shot(Vector3(player_x+f*3.1,1.95,6.5),Vector3(player_x+f*0.12,2.55,0),36.0,-2.0*f,"gather"),aspect)
  var high: Dictionary=_frame(_shot(Vector3(player_x+f*1.0,2.70,6.8),Vector3(player_x+f*0.12,2.60,0),35.0,1.2*f,"gather"),aspect)
  return _blend(low,high,(t-0.60)/1.05,"gather")
 if t<2.35:
  var launch: Dictionary=_frame(_shot(Vector3(target_x+f*2.8,3.4,7.6),Vector3(target_x-f*0.45,2.25,0),40.0,1.6*f,"release"),aspect)
  var track: Dictionary=_frame(_shot(Vector3(target_x+f*1.0,2.8,8.0),Vector3(target_x-f*0.45,2.10,0),40.0,-0.4*f,"release"),aspect)
  return _blend(launch,track,(t-1.65)/0.70,"release")
 var landing: Dictionary=_frame(_shot(Vector3(mid+f*1.25,1.6,8.0),Vector3(target_x-f*0.45,1.5,0),39.0,-0.8*f,"impact"),aspect)
 if t<RETURN_AT:
  if t>=2.65:
   # A quick lens punch lands on the existing fourth damage cue, then releases.
   var pulse: float=pow(maxf(0.0,1.0-(t-2.65)/0.18),3.0)
   landing.fov-=2.6*pulse
   landing.roll+=1.4*f*pulse
  return landing
 return _blend(landing,battle,(t-RETURN_AT)/(DURATION-RETURN_AT),"return")
