extends CanvasLayer
## A short composition accent on confirmed heavy hits and perfect defense.
## The caller advances this on the same clock as poses and native ink.
const FOCUS_SHADER = preload("res://shaders/combat_focus.gdshader")
var age := 1.0
var duration := 0.24
var strength := 0.0
var kind := ""
var origin := Vector3.ZERO
var direction := 1.0
var _panel: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	layer = 5
	_panel = ColorRect.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = FOCUS_SHADER
	_panel.material = _material
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.hide()

func handle_event(data: Dictionary) -> void:
	var event_kind := str(data.get("type", ""))
	if event_kind in ["reset", "ultimate", "spawnStage"]:
		clear()
		return
	var heavy := event_kind == "hit" and bool(data.get("heavy", false))
	if not heavy and event_kind not in ["parry", "guardBreak"]: return
	kind = event_kind
	strength = 0.82 if event_kind == "parry" else 1.0
	duration = 0.22 if event_kind == "parry" else 0.25
	age = 0.0
	origin = Vector3(float(data.get("contactX", data.get("x", 0.0))), 2.05 if event_kind == "parry" else 1.33, 0.35)
	direction = float(data.get("facing", 1.0))

func clear() -> void:
	age = 1.0
	strength = 0.0
	kind = ""
	if is_instance_valid(_panel): _panel.hide()

func tick(delta: float) -> void:
	age += maxf(0.0, delta)

func amount() -> float:
	# The hitstop holds this key image; the rays then disappear in one release.
	return strength * (1.0 - smoothstep(0.025, duration, age))

func present(camera: Camera3D, enabled: bool) -> void:
	var weight := amount() if enabled else 0.0
	_panel.visible = weight > 0.001
	if not _panel.visible: return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var center := camera.unproject_position(origin) / viewport_size
	_material.set_shader_parameter("center", center)
	_material.set_shader_parameter("aspect", viewport_size.x / maxf(1.0, viewport_size.y))
	_material.set_shader_parameter("strength", weight)
	_material.set_shader_parameter("direction", direction)
	_material.set_shader_parameter("parry", kind == "parry")

func snapshot() -> Dictionary:
	return {"kind":kind, "age":age, "amount":amount(), "origin":[origin.x,origin.y,origin.z]}
