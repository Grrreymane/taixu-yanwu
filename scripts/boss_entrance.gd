extends CanvasLayer
## Presentation only: the encounter, rewards and native combat state stay frozen.
signal finished
signal skip_requested
const DURATION := 5.3
const RETURN_AT := 4.25
const BattleCamera := preload("res://scripts/battle_camera.gd")
const FONT := preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
var active := false
var pending := false
var time := 0.0
var focused := true
var player_x := -3.0
var boss_x := 3.0
var _return_from: Dictionary = {}
var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _plate: Panel
var _name: Label
var _subtitle: Label
var _skip: Button

func _ready() -> void:
	layer = 26
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top = ColorRect.new()
	_bottom = ColorRect.new()
	for bar in [_top, _bottom]:
		bar.color = Color(0.018, 0.014, 0.025, 0.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
	_plate = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.025, 0.055, 0.76)
	box.border_color = Color("c54767")
	box.border_width_left = 4
	_plate.add_theme_stylebox_override("panel", box)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)
	_name = Label.new()
	_name.text = "识之律者"
	_subtitle = Label.new()
	_subtitle.text = "最终试炼  /  识之律者本尊"
	for label in [_name, _subtitle]:
		label.add_theme_font_override("font", FONT)
		label.add_theme_color_override("font_color", Color("fff4ec"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(label)
	_skip = Button.new()
	_skip.text = "跳过演出  Enter"
	_skip.add_theme_font_override("font", FONT)
	_skip.pressed.connect(func(): skip_requested.emit())
	_root.add_child(_skip)
	visible = false

func queue_entrance() -> void:
	clear()
	pending = true

func begin(player_position: float, boss_position: float) -> void:
	pending = false
	active = true
	visible = true
	time = 0.0
	player_x = player_position
	boss_x = boss_position
	_return_from.clear()
	_layout()

func clear() -> void:
	active = false
	pending = false
	visible = false
	time = 0.0
	_return_from.clear()

func tick(delta: float, paused: bool = false) -> void:
	if not active: return
	if focused and not paused: time = minf(DURATION, time + maxf(0.0, delta))
	_layout()
	if time >= DURATION:
		active = false
		visible = false
		finished.emit()

func skip(aspect: float) -> void:
	if not active or time >= RETURN_AT: return
	_return_from = frame(aspect)
	time = RETURN_AT

func actor_state(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var yaw := lerpf(-0.28, -PI/2.0+0.23, smoothstep(RETURN_AT,DURATION,time))
	result.presentationYaw = yaw
	result.stateTime = maxf(0.0,time-0.25)
	if time < 2.75:
		# Original C6 charged sword flourish. The actor samples the native clip;
		# no attack is dispatched to Combat and no damage can occur here.
		result.state = "attack"
		result.stateDuration = 2.5
		result.attack = {"name":"entrance", "motion":"senti_sword_charge", "weapon":"sword", "duration":2.5, "windup":0.0}
	else:
		result.state = "intro" if time < RETURN_AT else "idle"
		result.stateTime = time - (2.75 if time < RETURN_AT else RETURN_AT)
	return result

static func _shot(pos: Vector3, target: Vector3, fov: float, label: String) -> Dictionary:
	return {"position":pos,"target":target,"fov":fov,"roll":0.0,"shot":label}

static func _blend(a: Dictionary,b: Dictionary,t: float,label: String) -> Dictionary:
	var weight := smoothstep(0.0,1.0,clampf(t,0.0,1.0))
	return _shot(Vector3(a.position).lerp(b.position,weight),Vector3(a.target).lerp(b.target,weight),lerpf(a.fov,b.fov,weight),label)

func frame(aspect: float) -> Dictionary:
	var aspect_scale := maxf(1.0,1.4/maxf(aspect,0.4))
	var arrival := _shot(Vector3(boss_x+1.2,2.1,8.7*aspect_scale),Vector3(boss_x-0.55,1.8,0),32,"boss_flourish")
	var reveal := _shot(Vector3(boss_x+0.35,2.48,7.2*aspect_scale),Vector3(boss_x-0.65,2.1,0),30,"boss_reveal")
	var portrait := _shot(Vector3(boss_x-0.1,2.75,6.4*aspect_scale),Vector3(boss_x-0.6,2.48,0),30,"boss_portrait")
	if time < 2.45: return _blend(arrival,reveal,time/2.45,"boss_flourish")
	if time < RETURN_AT: return _blend(reveal,portrait,(time-2.45)/(RETURN_AT-2.45),"boss_portrait")
	var battle := BattleCamera.frame(player_x,[boss_x],aspect)
	return _blend(portrait if _return_from.is_empty() else _return_from,battle,(time-RETURN_AT)/(DURATION-RETURN_AT),"boss_return")

func snapshot() -> Dictionary:
	return {"active":active,"pending":pending,"time":time,"duration":DURATION,"focused":focused,"nativeClip":"Attack_A_Charge" if time<2.75 else "Standby_2" if time<RETURN_AT else "Standby"}

func _layout() -> void:
	if not is_instance_valid(_root): return
	var size := get_viewport().get_visible_rect().size
	var unit := clampf(minf(size.x/1280.0,size.y/800.0),0.4,1.8)
	var opening := smoothstep(0.0,0.22,time)
	var ending := 1.0-smoothstep(RETURN_AT,DURATION,time)
	var bars := size.y*0.085*opening*ending
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x,bars)
	_bottom.position = Vector2(0,size.y-bars)
	_bottom.size = Vector2(size.x,bars)
	var title_weight := smoothstep(0.85,1.3,time)*(1.0-smoothstep(3.8,4.3,time))
	var left := size.x*0.085-28.0*unit*(1.0-title_weight)
	_plate.position = Vector2(left,size.y*0.59)
	_plate.size = Vector2(385,125)*unit
	_name.position = _plate.position+Vector2(24,30)*unit
	_subtitle.position = _plate.position+Vector2(26,11)*unit
	_name.add_theme_font_size_override("font_size",int(54*unit))
	_subtitle.add_theme_font_size_override("font_size",int(16*unit))
	for item in [_plate,_name,_subtitle]: item.modulate.a=title_weight
	_skip.position = Vector2(size.x-220*unit,size.y-48*unit)
	_skip.size = Vector2(195,32)*unit
	_skip.add_theme_font_size_override("font_size",int(16*unit))
	_skip.modulate.a = ending
	_skip.disabled = time >= RETURN_AT
