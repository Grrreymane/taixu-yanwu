extends SceneTree
## Preserve the original particle colors and two-curve sampling while caching.
const NativeGradient=preload("res://scripts/native_gradient.gd")
const Curves=preload("res://scripts/native_burst_emitters.gd")
const Effects=preload("res://scripts/remaining_native_effects.gd")
var gradients:Array[Dictionary]=[]
var curves:Array[Dictionary]=[]
var checks:=0
var failures:=0
func collect(value:Variant) -> void:
 if value is Dictionary:
  if value.has("m_NumColorKeys") or value.has("m_NumAlphaKeys"):gradients.append(value)
  if int(value.get("minMaxState",-1))==2 and value.has("minCurve"):curves.append(value)
  for child in value.values():collect(child)
 elif value is Array:
  for child in value:collect(child)
func uncached_gradient(g:Dictionary,p:float,alpha:bool) -> Color:
 var count:=int(g.get("m_NumAlphaKeys" if alpha else "m_NumColorKeys",0))
 var prefix:="atime" if alpha else "ctime"
 var previous:=0
 for i in count:
  var time:=float(g.get(prefix+str(i),0))/65535.0
  if time>=p or i==count-1:
   var a:Dictionary=g["key"+str(previous)];var b:Dictionary=g["key"+str(i)]
   var start:=float(g.get(prefix+str(previous),0))/65535.0
   return Color(a.r,a.g,a.b,a.a).lerp(Color(b.r,b.g,b.b,b.a),clampf((p-start)/maxf(time-start,0.0001),0,1))
  previous=i
 return Color.WHITE
func _initialize() -> void:
 for path in ["res://assets/vfx/native-burst/source-emitters.json","res://assets/vfx/remaining-native/emitters.json"]:
  collect(JSON.parse_string(FileAccess.get_file_as_string(path)))
 gradients.append({"m_NumColorKeys":0,"m_NumAlphaKeys":0})
 for g in gradients:
  NativeGradient.prepare(g)
  for step in range(-1,102):
   for alpha:bool in [false,true]:
    checks+=1
    if NativeGradient.sample(g,float(step)/100,alpha)!=uncached_gradient(g,float(step)/100,alpha):failures+=1
 for curve in curves:
  var minimum:=curve.duplicate();minimum.minMaxState=1;minimum.maxCurve=curve.minCurve
  for step in 21:
   for random_value:float in [0.0,0.37,1.0]:
    var time:=float(step)/20.0
    var expected:=lerpf(Curves.curve_at(minimum,time),Curves.curve_at(curve,time),random_value)
    checks+=1
    if Effects.curve_value(curve,time,random_value)!=expected:failures+=1
 print("NATIVE_PARTICLE_SAMPLING ",checks," checks; ",failures," failures; ",gradients.size()," gradients; ",curves.size()," paired curves")
 quit(0 if failures==0 else 1)
