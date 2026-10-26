extends SceneTree
const Director=preload("res://scripts/ultimate_camera.gd")
var checks:=0
var failures: Array[String]=[]

func check(condition: bool,message: String) -> void:
 checks+=1
 if not condition:
  failures.append(message)
  push_error(message)

func _initialize() -> void:
 var entry: Dictionary={"position":Vector3(0,3.1,11.8),"target":Vector3(0,1.4,0),"fov":34.0,"roll":0.0}
 var battle: Dictionary=entry.duplicate(true)
 for t in [0.0,0.14,0.35,0.60,1.0,1.5,1.65,1.9,2.35,2.65,2.75,2.83,3.05,3.3]:
  var right: Dictionary=Director.sample(t,-0.675,0.675,1.0,16.0/9.0,entry,battle)
  var left: Dictionary=Director.sample(t,0.675,-0.675,-1.0,16.0/9.0,entry,battle)
  check(Vector3(right.position).is_finite() and Vector3(right.target).is_finite(),"finite camera at "+str(t))
  check(right.position.z>3.0,"shot stays in front of the combat axis at "+str(t))
  check(Vector3(right.position).distance_to(right.target)>3.0,"camera stays outside actors at "+str(t))
  check(is_equal_approx(right.position.x,-left.position.x) and is_equal_approx(right.position.z,left.position.z),"mirrored camera position at "+str(t))
  check(is_equal_approx(right.target.x,-left.target.x) and is_equal_approx(right.roll,-left.roll),"mirrored target and roll at "+str(t))
  check(right.fov>=30.0 and right.fov<=42.0 and absf(right.roll)<=3.0,"bounded lens and roll at "+str(t))
  var paused: Dictionary=Director.sample(t,-0.675,0.675,1.0,16.0/9.0,entry,battle)
  check(right==paused,"same simulation time produces identical shot at "+str(t))
 var start: Dictionary=Director.sample(0,0,1.35,1,16.0/9.0,entry,battle)
 var end: Dictionary=Director.sample(3.3,0,1.35,1,16.0/9.0,entry,battle)
 check(start.position==entry.position and start.target==entry.target,"entry starts from the actual gameplay camera")
 check(end.position==battle.position and end.target==battle.target and end.fov==34 and end.roll==0,"timeline ends on the gameplay frame")
 var wide: Dictionary=Director.sample(1.0,0,1.35,1,16.0/9.0,entry,battle)
 var narrow: Dictionary=Director.sample(1.0,0,1.35,1,0.75,entry,battle)
 check(Vector3(narrow.position).distance_to(narrow.target)>Vector3(wide.position).distance_to(wide.target),"narrow browsers get extra framing room")
 var origin: Dictionary=Director.sample(1.9,0,1.35,1,16.0/9.0,entry,battle)
 var edge: Dictionary=Director.sample(1.9,3.65,5.0,1,16.0/9.0,entry,battle)
 check(is_equal_approx(edge.position.x-origin.position.x,3.65) and is_equal_approx(edge.target.x-origin.target.x,3.65),"edge shots follow the fighters without an arena clamp")
 print("CAMERA_CHECKS ",checks," FAILURES ",failures.size())
 quit(0 if failures.is_empty() else 1)
