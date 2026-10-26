extends CanvasLayer
## Presentation only. The caller owns combat, slow motion and the result flow.
## tick() always receives UNSCALED presentation delta, including during hit-stop.
signal finished
const DURATION:=1.35
const FREEZE_UNTIL:=0.09
const SLOW_UNTIL:=0.34
const BADGE_DURATION:=0.55
const FONT:=preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
const DISPLAY_FONT:=preload("res://assets/fonts/hi3-anton-regular.ttf")
var active:=false
var time:=0.0
var focused:=true
var winner:="player"
var count:=0
var total:=0
var plays:=0
var _badge_time:=BADGE_DURATION
var _paused:=false
var _canvas:KnockoutCanvas

class KnockoutCanvas extends Control:
	var presentation
	func _draw() -> void:
		if is_instance_valid(presentation):presentation._paint(self)

func _ready() -> void:
	layer=34
	_canvas=KnockoutCanvas.new()
	_canvas.presentation=self
	_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_canvas.resized.connect(func():_canvas.queue_redraw())
	_refresh()

func begin(data:Dictionary={}) -> void:
	# A late non-final KO must never reset or downgrade the finishing sequence.
	var final_hit:=bool(data.get("final",true))
	if active and not final_hit:return
	count=maxi(0,int(data.get("count",count+1)))
	total=maxi(0,int(data.get("total",total)))
	if total>0:count=mini(count,total)
	if not final_hit:
		_badge_time=0.0
		_refresh()
		return
	active=true
	time=0.0
	_badge_time=BADGE_DURATION
	_paused=false
	winner="enemy" if str(data.get("winner","player"))=="enemy" else "player"
	plays+=1
	_refresh()

func clear() -> void:
	active=false
	time=0.0
	count=0
	total=0
	_badge_time=BADGE_DURATION
	_paused=false
	_refresh()

func set_focused(value:bool) -> void:
	focused=value

func tick(delta:float,paused:bool=false) -> void:
	var pause_changed:=_paused!=paused
	_paused=paused
	if pause_changed:_refresh()
	if not focused or paused or not is_finite(delta) or delta<=0.0:return
	if active:
		time=minf(DURATION,time+delta)
		if time>=DURATION:
			active=false
			finished.emit()
	if _badge_time<BADGE_DURATION:_badge_time=minf(BADGE_DURATION,_badge_time+delta)
	_refresh()

func _refresh() -> void:
	visible=active or _badge_time<BADGE_DURATION
	if is_instance_valid(_canvas):_canvas.queue_redraw()

static func timing(at:float) -> Dictionary:
	var t:=clampf(at,0.0,DURATION)
	var entry:=smoothstep(0.02,0.16,t)
	var ending:=smoothstep(0.72,DURATION,t)
	var opacity:=entry*(1.0-ending)
	var strike:=1.0-smoothstep(0.02,0.18,t)
	var freezing:=t<FREEZE_UNTIL-0.00000001
	var slowing:=t<SLOW_UNTIL-0.00000001
	return {"phase":"impact" if freezing else "slow" if slowing else "hold" if t<0.72 else "out" if t<DURATION else "done",
		"timeScale":0.0 if freezing else 0.25 if slowing else 1.0,
		"cameraPulse":pow(1.0-clampf(t/0.24,0.0,1.0),2.0),
		"opacity":opacity,"entry":entry,"ending":ending,
		"scale":lerpf(1.34,1.0,smoothstep(0.02,0.19,t))+ending*0.045,
		"flash":0.24*strike,"rays":(1.0-smoothstep(0.12,0.40,t))*entry,
		"caption":smoothstep(0.12,0.23,t)*(1.0-ending)}

func snapshot() -> Dictionary:
	var frame:=timing(time)
	return {"active":active,"badgeActive":_badge_time<BADGE_DURATION,"time":time,"duration":DURATION,
		"badgeTime":_badge_time,"badgeDuration":BADGE_DURATION,"phase":frame.phase if active else "badge" if _badge_time<BADGE_DURATION else "idle",
		"winner":winner,"result":"victory" if winner=="player" else "defeat","label":"K.O." if active else "击破" if _badge_time<BADGE_DURATION else "",
		"count":count,"total":total,"plays":plays,"paused":_paused,"focused":focused,
		"pauseHint":"已暂停 · ESC 继续" if active and _paused else "",
		"timeScale":frame.timeScale if active else 1.0,"cameraPulse":frame.cameraPulse if active else 0.0,
		"opacity":frame.opacity if active else _badge_opacity(),"blocksInput":false}

static func layout(view_size:Vector2) -> Dictionary:
	var size:=Vector2(maxf(1.0,view_size.x),maxf(1.0,view_size.y))
	var unit:=minf(size.x/1280.0,size.y/800.0)
	var font_size:=maxi(24,int(minf(size.y*0.36,size.x*0.25)))
	var text_size:=DISPLAY_FONT.get_string_size("K.O.",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var center:=Vector2(size.x*0.5,size.y*0.46)
	var badge_size:=Vector2(246.0,62.0)*unit
	return {"size":size,"unit":unit,"center":center,"fontSize":font_size,"textSize":text_size,
		"textBounds":Rect2(center-text_size*0.5,text_size),
		"badge":Rect2(Vector2(size.x-badge_size.x-34.0*unit,size.y*0.235),badge_size)}

func _badge_opacity() -> float:
	return smoothstep(0.0,0.055,_badge_time)*(1.0-smoothstep(0.32,BADGE_DURATION,_badge_time))

func _paint(canvas:Control) -> void:
	var geometry:=layout(canvas.get_viewport_rect().size)
	if active:_paint_final(canvas,geometry,timing(time))
	elif _badge_time<BADGE_DURATION:_paint_badge(canvas,geometry)
	if active and _paused:
		var hint:="已暂停 · ESC 继续"
		var font_size:=maxi(14,int(20*float(geometry.unit)))
		var width:=FONT.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var point:=Vector2(float(geometry.size.x)*0.5-width*0.5,float(geometry.size.y)*0.88)
		canvas.draw_string_outline(FONT,point,hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(2,int(3*float(geometry.unit))),Color("171b2c"))
		canvas.draw_string(FONT,point,hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff6d5"))

func _paint_final(canvas:Control,g:Dictionary,f:Dictionary) -> void:
	var size:Vector2=g.size
	var center:Vector2=g.center
	var unit:float=g.unit
	var alpha:float=f.opacity
	var gold:=Color("ffd780") if winner=="player" else Color("ff826d")
	var bright:=Color("fff6d5") if winner=="player" else Color("ffe7e0")
	var ink:=Color("171b2c")
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color(0.045,0.035,0.07,0.12*alpha))
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color(bright, float(f.flash)))
	# The split plates cross behind the text; they never intercept game input.
	var slope:=0.075
	var half_height:=size.y*0.115
	var slide:=size.x*(1.0-float(f.entry))*0.7
	var exit:=size.x*float(f.ending)*0.28
	var left:=-size.x*0.1-slide-exit
	var right:=size.x*1.1+slide+exit
	var polygon:=PackedVector2Array([Vector2(left,center.y-half_height+slope*size.x*0.5),Vector2(right,center.y-half_height-slope*size.x*0.5),Vector2(right,center.y+half_height-slope*size.x*0.5),Vector2(left,center.y+half_height+slope*size.x*0.5)])
	canvas.draw_colored_polygon(polygon,Color(ink,0.88*alpha))
	canvas.draw_line(polygon[0]-Vector2(0,7*unit),polygon[1]-Vector2(0,7*unit),Color(gold,0.87*alpha),3.0*unit,true)
	canvas.draw_line(polygon[3]+Vector2(0,7*unit),polygon[2]+Vector2(0,7*unit),Color(gold,0.55*alpha),1.5*unit,true)
	# Deterministic angular impact streaks. No random particles or strobing.
	for i in 8:
		var side:=-1.0 if i<4 else 1.0
		var row:=float(i%4)-1.5
		var start:=center+Vector2(side*size.x*0.23,row*size.y*0.055)
		var end:=center+Vector2(side*size.x*(0.53+float(i%2)*0.08),row*size.y*0.11)
		var width:=Vector2(0,(4.0+float(i%3)*2.5)*unit)
		canvas.draw_colored_polygon(PackedVector2Array([start-width,end,start+width]),Color(gold,0.75*float(f.rays)))
	var scale:float=f.scale
	var origin:=center+Vector2(85.0*(1.0-float(f.entry))+90.0*float(f.ending),-12.0*float(f.ending))*unit
	# Original typography: an italic, slightly rising stamp, with layered edges.
	canvas.draw_set_transform_matrix(Transform2D(Vector2(scale,-0.055*scale),Vector2(-0.20*scale,scale),origin))
	var font_size:int=g.fontSize
	var width:float=(g.textSize as Vector2).x
	var baseline:=Vector2(-width*0.5,(DISPLAY_FONT.get_ascent(font_size)-DISPLAY_FONT.get_descent(font_size))*0.5)
	canvas.draw_string_outline(DISPLAY_FONT,baseline+Vector2(7,9)*unit,"K.O.",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(2,int(17*unit)),Color(ink,0.96*alpha))
	canvas.draw_string_outline(DISPLAY_FONT,baseline,"K.O.",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(2,int(12*unit)),Color(ink,alpha))
	canvas.draw_string_outline(DISPLAY_FONT,baseline,"K.O.",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(1,int(6*unit)),Color(gold,alpha))
	canvas.draw_string(DISPLAY_FONT,baseline,"K.O.",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(bright,alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var caption:="对手击倒" if winner=="player" else "战斗不能"
	var caption_size:=maxi(16,int(24*unit))
	var caption_width:=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x
	var caption_point:=center+Vector2(-caption_width*0.5,size.y*0.187)
	canvas.draw_string_outline(FONT,caption_point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size,maxi(1,int(4*unit)),Color(ink,float(f.caption)))
	canvas.draw_string(FONT,caption_point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size,Color(bright,float(f.caption)))
	var line_y:=caption_point.y-8.0*unit
	canvas.draw_line(Vector2(center.x-caption_width*0.5-64*unit,line_y),Vector2(center.x-caption_width*0.5-18*unit,line_y),Color(gold,float(f.caption)),2*unit,true)
	canvas.draw_line(Vector2(center.x+caption_width*0.5+18*unit,line_y),Vector2(center.x+caption_width*0.5+64*unit,line_y),Color(gold,float(f.caption)),2*unit,true)

func _paint_badge(canvas:Control,g:Dictionary) -> void:
	var alpha:=_badge_opacity()
	var unit:float=g.unit
	var box:Rect2=g.badge
	box.position.x+=32*unit*(1.0-smoothstep(0.0,0.07,_badge_time))
	var cut:=16*unit
	var polygon:=PackedVector2Array([box.position+Vector2(cut,0),Vector2(box.end.x,box.position.y),box.end-Vector2(cut,0),Vector2(box.position.x,box.end.y)])
	canvas.draw_colored_polygon(polygon,Color(0.06,0.085,0.14,0.86*alpha))
	canvas.draw_line(polygon[0],polygon[1],Color(1.0,0.78,0.40,alpha),2.0*unit,true)
	var label:="击破  %02d / %02d" % [count,total] if total>0 else "击破  %02d" % count
	var font_size:=maxi(14,int(25*unit))
	canvas.draw_string(FONT,box.position+Vector2(28,41)*unit,label,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-38*unit,font_size,Color(1.0,0.94,0.80,alpha))
