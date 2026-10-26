extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Bounds=preload("res://scripts/model_bounds.gd")
const CameraPlan=preload("res://scripts/lightning_camera.gd")
var failures:Array[String]=[]
var rows:Array=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run()->void:
 for skin in ["default","blood_moon"]:
  var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua","shadow_knight",skin))
  var camera=Camera3D.new();root.add_child(camera)
  var pose={"x":0.0,"facing":1.0,"state":"ultimate","stateTime":0.0,"stateDuration":3.116667,"side":"player","eclipseRemaining":0.0}
  var highest:=0.0
  var max_projection:=0.0
  var worst_time:=0.0
  for i in 96:
   var time:=float(i)/30.0
   actor.animate_fighter(pose,1.0/30.0,time,time)
   var measured:Dictionary=Bounds.measure(actor.model,actor.skeleton,actor._visual.get("hiddenSurfaces",[]))
   var box:AABB=measured.bounds
   var bottom:float=INF
   var top:float=-INF
   var framing:Dictionary=CameraPlan.sample(time,{"playerX":0.0,"targetX":1.35,"facing":1.0,"aspect":1.6},"shadow_knight")
   var view:Transform3D=Transform3D(Basis.IDENTITY,framing.position).looking_at(framing.target).affine_inverse()
   for n in 8:
    var point:Vector3=actor.model.global_transform*box.get_endpoint(n)
    bottom=minf(bottom,point.y);top=maxf(top,point.y)
    var projected:Vector3=view*point
    var extent:float=absf(projected.y)/maxf(.001,-projected.z*tan(deg_to_rad(float(framing.fov)*.5)))
    if extent>max_projection:
     max_projection=extent;worst_time=time
   highest=maxf(highest,top)
   check(top<4.6 and bottom<1.4,"Moon body remains in the combat-stage vertical range %s %.3f"%[skin,time])
  check(max_projection<.98,"native eclipse wings and full body fit the cinematic for "+skin)
  rows.append({"skin":skin,"highest":highest,"maxProjectionY":max_projection,"worstTime":worst_time,"worldScale":actor.skeleton.global_transform.basis.y.length()})
  actor.free();camera.free()
 var result={"checks":checks,"passed":failures.is_empty(),"failures":failures,"rows":rows}
 FileAccess.open("res://build/reports/moon-ultimate-framing.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
