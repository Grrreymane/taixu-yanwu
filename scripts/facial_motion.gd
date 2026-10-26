extends RefCounted
## Original Fu Hua eye/mouth atlas with project-authored expression timing.
## Body FBX clips do not contain the separate native facial-controller tracks.
## Never interpolate UV offsets: neighbouring atlas cells have unrelated art.

var _materials: Dictionary = {}
var _frames: Dictionary = {}
var _source := ""
var _enabled := false
var _clock := 0.0
var _frame := "neutral"
var _blink := false
var _offsets: Dictionary = {}

func register_material(mesh_name: String, material: ShaderMaterial) -> void:
	var lower := mesh_name.to_lower()
	var role := "mouth" if "mouth" in lower else "eyeL" if "eye_l" in lower else "eyeR"
	if not _materials.has(role): _materials[role] = []
	_materials[role].append(material)

func setup(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("frames") is Dictionary: return false
	_frames = data.frames
	_source = str(data.get("source", "native-textures-adapted-timing"))
	_enabled = _frames.has("neutral") and _materials.has("eyeL") and _materials.has("eyeR") and _materials.has("mouth")
	reset()
	return _enabled

func reset() -> void:
	_clock = 0.0
	_blink = false
	_apply("neutral")

func update(delta: float, context: Dictionary) -> void:
	if not _enabled: return
	_clock += maxf(0.0, delta) if is_finite(delta) else 0.0
	var motion := str(context.get("motion", "idle"))
	var time := maxf(0.0, float(context.get("clock", 0.0)))
	var duration := maxf(0.001, float(context.get("duration", 1.0)))
	var frame := "neutral"
	_blink = false
	if motion == "dead":
		frame = "closed"
	elif motion == "stagger":
		frame = "hurt" if _frames.has("hurt") else "closed"
		if time / duration > 0.65: frame = "focused"
	elif motion == "ultimate":
		# Eyes settle for the gathering shot, then open before the release.
		frame = "closed" if time > 0.20 and time < 0.85 else "focused"
		if time > 1.10 and time < 1.80 and _frames.has("effort"): frame = "effort"
	elif motion in ["guard", "dodge", "dodgeBack"]:
		frame = "focused"
	elif motion not in ["idle", "intro", "move"]:
		frame = "focused"
		if time / duration > 0.18 and time / duration < 0.62 and _frames.has("effort"): frame = "effort"
	else:
		# Unequal intervals avoid a metronomic blink. The clock only advances
		# with simulation delta, so hitstop, pause and inactive tabs freeze it.
		var cycle := fposmod(_clock, 14.8)
		for at in [2.2, 6.25, 9.0, 13.6]:
			var elapsed := cycle - float(at)
			if elapsed >= 0.0 and elapsed < 0.18:
				frame = "closed" if elapsed >= 0.04 and elapsed < 0.10 else "halfBlink"
				_blink = true
				break
	_apply(frame)

func animate_victory(time: float, _profile: String = "") -> void:
	if not _enabled: return
	# Absolute presentation time also supports replay, skip and random seeking.
	_clock = maxf(0.0, time)
	_blink = false
	var frame := "smile" if time > 1.55 and _frames.has("smile") else "neutral"
	var mouth_frame := frame
	var blink_at := fposmod(maxf(0.0, time - 2.15), 3.9) if time >= 2.15 else -1.0
	if blink_at >= 0.0 and blink_at < 0.18:
		frame = "closed" if blink_at >= 0.04 and blink_at < 0.10 else "halfBlink"
		_blink = true
	_apply(frame, mouth_frame)

func animate_dialogue(mood: String, talking: bool, time: float) -> void:
	if not _enabled: return
	var frame := "smile" if mood in ["confident","tease","happy"] else "focused" if mood in ["serious","surprised"] else "neutral"
	if not _frames.has(frame): frame="neutral"
	var mouth := "effort" if talking and sin(time*14.0)>0.15 and _frames.has("effort") else frame
	var blink := fposmod(time+1.7,4.7)
	if blink<0.13: frame="closed"
	_apply(frame,mouth)

func _apply(frame: String, mouth_frame: String = "") -> void:
	if not _enabled: return
	_frame = frame if _frames.has(frame) else "neutral"
	var selected: Dictionary = _frames[_frame]
	_offsets.clear()
	for role: String in _materials:
		var offset: Array = selected.get(role, _frames.neutral[role])
		if role == "mouth" and _frames.has(mouth_frame): offset = _frames[mouth_frame].get(role, offset)
		_offsets[role] = offset.duplicate()
		for material: ShaderMaterial in _materials[role]:
			material.set_shader_parameter("uv_offset", Vector2(float(offset[0]), float(offset[1])))

func snapshot() -> Dictionary:
	var result := {"enabled":_enabled, "source":_source, "frame":_frame, "clock":_clock, "blink":_blink}
	result.merge(_offsets.duplicate(true))
	return result
