extends Node
## Stage music continues through dialogue/results; two players only overlap
## briefly when changing to another encounter's original music.

const THEME_PATH := "res://assets/music/battle_theme.ogg"
const SENTI_NRBL_PATH := "res://assets/music/sentience_nrbl.ogg"
const SENTI_HARD_BONE_PATH := "res://assets/music/sentience_hard_bone.ogg"
const CROSSFADE_SECONDS := 0.8
# Source peaks were preserved with extra encode headroom; match the original
# bed's -10.5 dBFS RMS at runtime, well below 0 dBFS after the music bus gain.
const TRACK_LEVEL_DB := {SENTI_NRBL_PATH:5.2104, SENTI_HARD_BONE_PATH:4.4231}
const SETTINGS_PATH := "user://music-preferences.cfg"
const WEB_SETTING := "taixu.music.enabled"
# Delivered OGG RMS is -10.5 dBFS. This puts the bed near -26.5 dBFS,
# several dB below the short hits, without burying the original arrangement.
const BATTLE_DB := -16.0
const MENU_DB := -22.0
const REWARD_DB := -20.0
const ULTIMATE_DUCK_DB := -4.0
const VOICE_DUCK_DB := -4.0
const SILENT_DB := -80.0

var settings_path := SETTINGS_PATH
var theme_path := THEME_PATH
var enabled := true
var unlocked := false
var _player := AudioStreamPlayer.new()
var _previous_player := AudioStreamPlayer.new()
var _streams: Dictionary = {}
var _track_path := ""
var _requested_path := ""
var _previous_path := ""
var _fade := 1.0
var _track_changes := 0
var _stage_index := -1
var _mode := ""
var _focused := true
var _paused := false
var _phase := "menu"
var _ultimate := false
var _voice_duck := false
var _started := false
var _starts := 0
var _volume_db := -40.0
var _target_db := MENU_DB

func _ready() -> void:
	name = "BackgroundMusic"
	_player.name = "ThemePlayer"
	_player.autoplay = false
	_player.max_polyphony = 1
	_player.volume_db = _volume_db
	add_child(_player)
	_previous_player.name = "PreviousThemePlayer"
	_previous_player.max_polyphony = 1
	_previous_player.volume_linear = 0.0
	add_child(_previous_player)
	_load_preference()
	# Dynamic lookup keeps the game playable if an optional music asset is absent.
	for path: String in [theme_path, SENTI_NRBL_PATH, SENTI_HARD_BONE_PATH]:
		if not ResourceLoader.exists(path): continue
		var stream := load(path) as AudioStream
		if stream is AudioStreamOggVorbis:
			stream = stream.duplicate()
			stream.loop = true
			stream.loop_offset = 0.0
		if stream != null: _streams[path] = stream
	_track_path = theme_path
	_requested_path = theme_path
	_player.stream = _streams.get(theme_path)
	_apply_state()

func set_encounter(mode: String, stage_index: int, phase: String) -> void:
	_mode = mode
	_stage_index = stage_index
	var desired := theme_path
	if mode == "trial" and phase != "menu" and stage_index >= 4:
		desired = SENTI_NRBL_PATH if stage_index == 4 else SENTI_HARD_BONE_PATH
	_requested_path = desired
	if desired == _track_path or not _streams.has(desired): return
	# Reusing the two output nodes prevents per-frame setup or stacked tracks.
	_previous_player.stop()
	_previous_player.stream = null
	var outgoing := _player
	_player = _previous_player
	_previous_player = outgoing
	_previous_path = _track_path
	_track_path = desired
	_player.stream = _streams[desired]
	_started = false
	_fade = 0.0 if _previous_player.has_stream_playback() else 1.0
	_track_changes += 1
	_apply_state()

func unlock() -> void:
	# Called only from the existing keyboard / HUD action path, never on load.
	unlocked = true
	_ensure_playing()

func toggle() -> void:
	unlocked = true
	set_enabled(not enabled)

func set_enabled(value: bool, persist: bool = true) -> void:
	if enabled != value and value:
		_volume_db = minf(_volume_db, -40.0)
	enabled = value
	if persist:
		_save_preference()
	_apply_state()

func set_focused(value: bool) -> void:
	_focused = value
	_apply_state()

func set_context(phase: String, paused: bool, ultimate: bool) -> void:
	_phase = phase
	_paused = paused
	_ultimate = ultimate
	_target_db = BATTLE_DB if phase == "fight" else REWARD_DB if phase == "reward" else MENU_DB
	if ultimate:
		_target_db += ULTIMATE_DUCK_DB
	if _voice_duck:
		_target_db += VOICE_DUCK_DB
	_apply_state()

func set_voice_duck(value: bool) -> void:
	_voice_duck = value

func tick(delta: float) -> void:
	# This is the wall clock, not combat's hitstop clock. A landed punch must not
	# stutter the song; explicit pause / focus loss suspends the audio cursor.
	if not _paused and _focused:
		_volume_db = lerpf(_volume_db, _target_db, 1.0 - exp(-maxf(0.0, delta) * 5.0))
		if _started and _fade < 1.0:
			_fade = minf(1.0, _fade + maxf(0.0, delta) / CROSSFADE_SECONDS)
			if _fade >= 1.0:
				_previous_player.stop()
				_previous_player.stream = null
				_previous_path = ""
	_apply_volume()

func _ensure_playing() -> void:
	if not unlocked or not enabled or _paused or not _focused or _player.stream == null:
		return
	if not _started:
		_player.play()
		_started = true
		_starts += 1

func _apply_state() -> void:
	_apply_volume()
	var should_pause := _paused or not _focused
	# Web Sample playback restarts its source on every unpause setter call,
	# even if already playing. Only send the actual pause/resume edges.
	if _player.stream_paused != should_pause:
		_player.stream_paused = should_pause
	if _previous_player.stream_paused != should_pause:
		_previous_player.stream_paused = should_pause
	_ensure_playing()

func _apply_volume() -> void:
	if enabled:
		_player.volume_linear = db_to_linear(_volume_db + float(TRACK_LEVEL_DB.get(_track_path, 0.0))) * _fade
		_previous_player.volume_linear = db_to_linear(_volume_db + float(TRACK_LEVEL_DB.get(_previous_path, 0.0))) * (1.0 - _fade)
	else:
		_player.volume_linear = 0.0
		_previous_player.volume_linear = 0.0

func _load_preference() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path) and config.load(settings_path) == OK:
		enabled = bool(config.get_value("music", "enabled", true))
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval("(function(){try{const v=localStorage.getItem('" + WEB_SETTING + "');return v===null?null:v==='true';}catch(e){return null;}})()", true)
		if saved is bool:
			enabled = saved

func _save_preference() -> void:
	var config := ConfigFile.new()
	config.set_value("music", "enabled", enabled)
	config.save(settings_path)
	# Immediate browser persistence also survives a reload before user:// sync.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('" + WEB_SETTING + "','" + str(enabled).to_lower() + "');}catch(e){}", true)

func snapshot() -> Dictionary:
	var active := _player.has_stream_playback()
	return {"available": _player.stream != null, "enabled": enabled, "muted": not enabled,
		"unlocked": unlocked, "playing": active and not _player.stream_paused,
		"paused": _paused or not _focused, "focused": _focused,
		"position": _player.get_playback_position() if active else 0.0,
		"track": _track_path.get_file(), "length": _player.stream.get_length() if _player.stream != null else 0.0,
		"requestedTrack":_requested_path.get_file(), "previousTrack":_previous_path.get_file(),
		"crossfade":_fade, "trackChanges":_track_changes, "mode":_mode, "stageIndex":_stage_index,
		"encounterAvailable":_streams.has(_requested_path),
		# Keep JSON finite for a zero linear gain (whose mathematical dB is -INF).
		"volumeDb": maxf(SILENT_DB, _player.volume_db), "gain": _player.volume_linear, "targetDb": _target_db,
		"ducked": _ultimate or _voice_duck, "voiceDucked": _voice_duck, "phase": _phase,
		"activePlayers":(1 if active else 0) + (1 if _previous_player.has_stream_playback() else 0), "starts": _starts}
