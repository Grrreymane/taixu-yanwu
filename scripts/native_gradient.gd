extends RefCounted
## Decode source gradient keys once. Retain their exact order, times and colors.
const CACHE_KEY:="_runtime_gradient"
static func prepare(value:Variant) -> void:
 if value is Dictionary:
  if value.has("m_NumColorKeys") or value.has("m_NumAlphaKeys"):
   _keys(value);return
  for child in value.values():prepare(child)
 elif value is Array:
  for child in value:prepare(child)
static func _keys(source:Dictionary) -> Array:
 if source.has(CACHE_KEY):return source[CACHE_KEY]
 var result:Array=[]
 for alpha:bool in [false,true]:
  var times:=PackedFloat64Array();var colors:=PackedColorArray()
  var count:=int(source.get("m_NumAlphaKeys" if alpha else "m_NumColorKeys",0))
  for i in count:
   times.append(float(source.get(("atime" if alpha else "ctime")+str(i),0))/65535.0)
   var c:Dictionary=source["key"+str(i)]
   colors.append(Color(c.r,c.g,c.b,c.a))
  result.append([times,colors])
 if not source.is_read_only():source[CACHE_KEY]=result
 return result
static func sample(source:Dictionary,p:float,alpha:bool=false) -> Color:
 var data:Array=_keys(source)[1 if alpha else 0]
 var times:PackedFloat64Array=data[0];var colors:PackedColorArray=data[1]
 var previous:=0
 for i in times.size():
  if times[i]>=p or i==times.size()-1:
   var u:=clampf((p-times[previous])/maxf(times[i]-times[previous],0.0001),0,1)
   return colors[previous].lerp(colors[i],u)
  previous=i
 return Color.WHITE
