extends CanvasLayer
## Screen-space framing follows the native ultimate clock. No wall-clock shader
## animation: pausing, hit-stop and tab suspension preserve the same image.
const SHADER = preload("res://shaders/ultimate_focus.gdshader")
const Lightning = preload("res://scripts/lightning_combat.gd")
var _panel := ColorRect.new()
var _material := ShaderMaterial.new()
var _frame: Dictionary = {}

func _ready() -> void:
	layer = 4
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	_panel.material = _material
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.hide()

static func sample(profile: String, time: float) -> Dictionary:
	var duration := 3.8 if profile == "fenghuang" else 1.583333 if profile == "night_squire" else Lightning.ultimate_duration(profile) if Lightning.supported(profile) else 3.3
	var release := 2.10 if profile == "fenghuang" else 1.14 if profile == "night_squire" else 1.233333 if profile == "shadow_knight" else 0.47 if profile == "hawk_of_the_fog" else 1.65
	var finish := 2.82 if profile == "fenghuang" else 2.65 if profile == "azure_empyrea" else release
	var fade_out := 0.35 if duration > 2.0 else 0.22
	var envelope := smoothstep(0.0, 0.12, time) * (1.0 - smoothstep(duration - fade_out, duration, time))
	if time < 0.0 or time >= duration: envelope = 0.0
	var release_pulse := maxf(0.0, 1.0 - (time - release) / 0.32) if time >= release else 0.0
	var final_pulse := maxf(0.0, 1.0 - (time - finish) / 0.22) if time >= finish else 0.0
	var accent: Color = {"azure_empyrea":Color("b5dce4"), "fenghuang":Color("ffc47c"), "night_squire":Color("a6ddff"), "shadow_knight":Color("94d7ff"), "hawk_of_the_fog":Color("ffc46b")}.get(profile, Color("b5dce4"))
	return {"active":envelope > 0.001, "weight":envelope, "pulse":maxf(release_pulse, final_pulse), "ink":profile == "azure_empyrea", "accent":accent, "released":time >= release, "duration":duration}

func present(camera: Camera3D, profile: String, time: float, player_x: float, target_x: float, enabled: bool) -> void:
	_frame = sample(profile, time if enabled else -1.0)
	_panel.visible = bool(_frame.active)
	if not _panel.visible: return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	# Follow the face/hands during the cut-in, then the actual strike. The
	# open center keeps facial features and the native impact silhouette clear.
	var focus_x := target_x if _frame.released and profile != "night_squire" else player_x
	var focus_height := 1.65 if _frame.released else 2.2
	var center := camera.unproject_position(Vector3(focus_x, focus_height, 0.0)) / viewport_size
	_material.set_shader_parameter("center", center.clamp(Vector2(0.15,0.2), Vector2(0.85,0.8)))
	_material.set_shader_parameter("aspect", viewport_size.x / maxf(1.0,viewport_size.y))
	_material.set_shader_parameter("weight", _frame.weight)
	_material.set_shader_parameter("pulse", _frame.pulse)
	_material.set_shader_parameter("ink", _frame.ink)
	_material.set_shader_parameter("accent", _frame.accent)

func snapshot() -> Dictionary:
	return _frame.duplicate()
