extends RefCounted
## Rotate the whole model; native skeletal animation is never modified.
const FRONT := -0.20
var yaw := FRONT
var dragging := false
var pointer := -1

func reset() -> void:
 yaw=FRONT
 cancel()

func cancel() -> void:
 dragging=false
 pointer=-1

func handle(event: InputEvent, area: Rect2) -> bool:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if dragging and pointer!=-1: return false
  if not event.pressed:
   var was:=dragging and pointer==-1
   if pointer==-1: cancel()
   return was
  if not area.has_point(event.position): return false
  if event.double_click:
   reset()
   return true
  dragging=true
  pointer=-1
  return true
 if event is InputEventMouseMotion and dragging and pointer==-1:
  yaw=wrapf(yaw+event.relative.x*0.008,-PI,PI)
  return true
 if event is InputEventScreenTouch:
  if event.pressed and not dragging and area.has_point(event.position):
   dragging=true
   pointer=event.index
   return true
  if not event.pressed and dragging and pointer==event.index:
   cancel()
   return true
 if event is InputEventScreenDrag and dragging and pointer==event.index:
  yaw=wrapf(yaw+event.relative.x*0.008,-PI,PI)
  return true
 return false

func snapshot() -> Dictionary:
 return {"yaw":yaw,"dragging":dragging,"front":FRONT}
