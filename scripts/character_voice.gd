extends Node
## Original Chinese voice clips. One player voice and one shared enemy voice;
## dialogue owns the mix and never borrows combat cries for missing emotions.
const CATALOG_PATH := "res://assets/audio/voice/manifest.json"
const SETTINGS_PATH := "user://voice-preferences.cfg"
const WEB_SETTING := "taixu.voice.enabled"
const BASE_DB := -3.0
const ENEMY_DB := -2.5
const CATEGORY_PRIORITY := {"attack":20,"dodge":25,"heavy":35,"ability":45,"parry":65,"hurt":60,"ultimate":100,"entrance":150,"dialogue":200}
const CATEGORY_GAP := {"attack":0.56,"heavy":0.65,"ability":0.85,"hurt":0.68,"parry":1.1,"dodge":1.15,"ultimate":1.0}

var catalog_path := CATALOG_PATH
var settings_path := SETTINGS_PATH
var enabled := true
var unlocked := false
var voice_db := BASE_DB
var _focused := true
var _paused := false
var _phase := "menu"
var _story_active := false
var _player_profile := "azure_empyrea"
var _boss_id := ""
var _enemy_count := 1
var _clock := 0.0
var _suppress_enemy_until := 0.0
var _ultimate_active := false
var _players: Dictionary = {}
var _current: Dictionary = {}
var _clips: Dictionary = {}
var _cooldowns: Dictionary = {}
var _last_file: Dictionary = {}
var _last_line_key := ""
var _rng := RandomNumberGenerator.new()
var _played := 0
var _blocked := 0
var _block_reasons: Dictionary = {}
var _recent: Array[Dictionary] = []
var _catalog_errors: Array[String] = []
var _last_clear := "initial"
var _language := ""

func _ready() -> void:
	name = "CharacterVoice"
	_rng.randomize()
	for channel: String in ["player","enemy","dialogue"]:
		var output := AudioStreamPlayer.new()
		output.name = "Voice_" + channel
		output.max_polyphony = 1
		add_child(output)
		_players[channel] = output
		output.finished.connect(_finished.bind(channel))
	_load_preference()
	load_catalog()
	_apply_pause()

func load_catalog() -> void:
	clear("catalog")
	_clips.clear()
	_catalog_errors.clear()
	_language = ""
	if not FileAccess.file_exists(catalog_path): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not value is Dictionary:
		_catalog_errors.append("Voice manifest is not a dictionary")
		return
	_language = str(value.get("language", ""))
	if _language != "zh-CN":
		_catalog_errors.append("Only a verified zh-CN voice manifest can be used")
		return
	for row: Variant in value.get("clips", []):
		if not row is Dictionary: continue
		var identity := str(row.get("id", ""))
		var file := str(row.get("file", ""))
		var path := file if file.begins_with("res://") else catalog_path.get_base_dir().path_join(file)
		if identity.is_empty() or file.is_empty() or _clips.has(identity):
			_catalog_errors.append("Missing or duplicate clip identity: " + identity)
			continue
		if not path.begins_with("res://assets/audio/voice/") or not ResourceLoader.exists(path):
			_catalog_errors.append("Missing voice clip: " + path)
			continue
		var stream := load(path) as AudioStream
		if stream == null or stream.get_length() <= 0.0:
			_catalog_errors.append("Invalid voice stream: " + path)
			continue
		if stream is AudioStreamOggVorbis:
			stream = stream.duplicate()
			stream.loop = false
		var clip: Dictionary = row.duplicate(true)
		clip.path = path
		clip.stream = stream
		clip.duration = stream.get_length()
		clip.profiles = row.get("profiles", [])
		clip.category = str(row.get("category", ""))
		clip.moods = row.get("moods", [])
		_clips[identity] = clip

func unlock() -> void:
	# Invoke from the same genuine keyboard / pointer path as music.unlock().
	unlocked = true

func toggle() -> void:
	unlock()
	set_enabled(not enabled)

func set_enabled(value: bool, persist: bool = true) -> void:
	enabled = value
	if not enabled: clear("muted")
	if persist: _save_preference()

func set_focused(value: bool) -> void:
	_focused = value
	_apply_pause()

func set_context(data: Dictionary) -> void:
	# Combat emits a deferred boss counter before ultimateEnd, while Main's
	# real-time audio clock still belongs to the previous frame. The actual
	# cinematic state is authoritative; release suppression without stopping
	# the player's longer original phrase, which may finish on its own channel.
	if data.has("ultimateActive"):
		var active := bool(data.ultimateActive)
		if _ultimate_active and not active: _suppress_enemy_until = 0.0
		_ultimate_active = active
	var phase := str(data.get("phase", _phase))
	var story_active := bool(data.get("storyActive", _story_active))
	var profile := str(data.get("playerProfile", _player_profile))
	if profile != _player_profile:
		clear("profile_changed")
	if phase == "menu" and _phase != "menu":
		clear("menu")
	elif story_active and not _story_active:
		_stop_channel("player")
		_stop_channel("enemy")
	elif not story_active and _story_active:
		stop_dialogue()
	if phase in ["reward","cleared","failed"] and phase != _phase:
		# A finishing native ultimate phrase may finish over the K.O. / reward.
		# Other combat efforts should not leak into a quiet results panel.
		for channel: String in ["player","enemy"]:
			if _current.has(channel) and str(_current[channel].category) != "ultimate":
				_stop_channel(channel)
	_phase = phase
	_story_active = story_active
	_player_profile = profile
	_paused = bool(data.get("paused", _paused))
	_boss_id = str(data.get("bossId", _boss_id))
	_enemy_count = maxi(1, int(data.get("enemyCount", _enemy_count)))
	_apply_pause()

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _paused or not _focused: return
	# Do not use combat's simulation delta: hitstop must not stutter a voice.
	_clock += delta
	for channel: String in _current.keys():
		var item: Dictionary = _current[channel]
		item.elapsed = maxf(0.0, _clock - float(item.startedAt))
		# The real finished signal normally owns cleanup. The upper bound also
		# works with Godot's Dummy driver in deterministic headless flow tests.
		if float(item.elapsed) >= float(item.duration) + 0.08:
			_stop_channel(channel)

func handle_event(data: Dictionary) -> bool:
	var kind := str(data.get("type", ""))
	if kind in ["reset","start","spawnStage"]:
		clear(kind)
		if kind == "start": _phase = "fight"
		return false
	if kind == "pause":
		_paused = bool(data.get("paused", false))
		_apply_pause()
		return false
	if kind == "end": return false
	if kind == "ultimateEnd":
		_ultimate_active = false
		_suppress_enemy_until = 0.0
		return false
	if _phase != "fight" or _story_active: return false
	var channel := "enemy" if str(data.get("side", "player")) == "enemy" else "player"
	var source_id := str(data.get("sourceId", channel))
	var category := ""
	match kind:
		"bossEntrance": category = "entrance"
		"attack":
			var action := str(data.get("name", "light"))
			category = "ability" if action == "ability" else "heavy" if action == "heavy" else "attack"
			if channel == "enemy" and (bool(data.get("phaseTransition", false)) or str(data.get("weapon", "")) == "burst"):
				category = "ultimate"
		"hit":
			if bool(data.get("armored", false)): return false
			channel = "player" if str(data.get("targetSide", "enemy")) == "player" else "enemy"
			source_id = str(data.get("targetId", channel))
			category = "hurt"
		"ultimate": category = "ultimate"
		"parry": category = "parry"
		"dodge", "evade":
			category = "dodge"
			if kind == "evade": source_id = str(data.get("targetId", channel))
		_: return false
	if channel == "enemy" and not _boss_id.is_empty() and source_id != _boss_id:
		return _block("boss_owns_enemy_voice")
	var profile := "sentience" if channel == "enemy" else _player_profile
	if category == "ultimate" and channel == "player":
		if _current.has("enemy") and str(_current.enemy.category) == "entrance":
			return _block("entrance_focus")
		_stop_channel("enemy")
		_ultimate_active = true
		_suppress_enemy_until = maxf(_suppress_enemy_until, _clock + float(data.get("duration", 1.6)))
	if category == "entrance":
		_stop_channel("player")
		_suppress_enemy_until = 0.0
	var weapon := str(data.get("weapon", "")) if channel == "enemy" and category in ["attack","heavy","ability","ultimate"] else ""
	return _request(channel, profile, category, "", source_id, "", weapon)

func play_dialogue(data: Dictionary) -> bool:
	var key := str(data.get("lineKey", data.get("key", "")))
	if key.is_empty() or key == _last_line_key: return false
	_last_line_key = key
	# Advancing a line cuts its previous short acknowledgement instead of
	# queuing a backlog. Revealing more text keeps the same key and stays silent.
	_stop_channel("dialogue")
	_stop_channel("player")
	_stop_channel("enemy")
	var speaker := str(data.get("speaker", "fuhua"))
	var profile := str(data.get("profile", "sentience" if speaker == "senti" else _player_profile))
	var clip_id := str(data.get("clipId", ""))
	if not bool(data.get("reviewed", false)) or clip_id.is_empty():
		return _block("dialogue_not_reviewed")
	return _request("dialogue", profile, "dialogue", "", speaker, key, "", clip_id)

func stop_entrance() -> void:
	if _current.has("enemy") and str(_current.enemy.category) == "entrance":
		_stop_channel("enemy")

func stop_dialogue() -> void:
	_stop_channel("dialogue")
	_last_line_key = ""

func clear(reason: String = "clear") -> void:
	for channel: String in _players: _stop_channel(channel)
	_cooldowns.clear()
	_last_line_key = ""
	_suppress_enemy_until = 0.0
	_ultimate_active = false
	_last_clear = reason

func _request(channel: String, profile: String, category: String, mood: String, source_id: String, key: String = "", weapon: String = "", clip_id: String = "") -> bool:
	if not enabled: return _block("disabled")
	if not unlocked: return _block("locked")
	if _paused or not _focused: return _block("paused")
	if not _players.has(channel): return _block("not_ready")
	if channel == "player" and _current.has("enemy") and str(_current.enemy.category) == "entrance": return _block("entrance_focus")
	if channel == "enemy" and _clock < _suppress_enemy_until: return _block("ultimate_focus")
	var priority := int(CATEGORY_PRIORITY.get(category, 20))
	if _current.has(channel) and int(_current[channel].priority) >= priority:
		return _block("channel_busy")
	var cooldown_key := channel + ":" + category
	if category != "dialogue" and _clock < float(_cooldowns.get(cooldown_key, -1.0)):
		return _block("cooldown")
	if channel == "enemy" and priority < 100 and _clock < float(_cooldowns.get("enemy:global", -1.0)):
		return _block("enemy_density")
	var candidates := _candidates(profile, category, mood, weapon)
	if not clip_id.is_empty():
		candidates.assign(candidates.filter(func(item: Dictionary): return str(item.id) == clip_id))
	if candidates.is_empty(): return _block("missing:" + profile + ":" + category + (":" + mood if not mood.is_empty() else ""))
	var previous := str(_last_file.get(channel, ""))
	var alternatives := candidates.filter(func(item: Dictionary): return str(item.path) != previous)
	if not alternatives.is_empty(): candidates = alternatives
	var clip: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_stop_channel(channel)
	var output: AudioStreamPlayer = _players[channel]
	output.stream = clip.stream
	output.volume_db = voice_db + (ENEMY_DB if channel == "enemy" else 0.0) + clampf(float(clip.get("volumeDb", 0.0)), -20.0, 6.0)
	output.play()
	var item := {"id":str(clip.id),"file":str(clip.path),"profile":profile,"category":category,"mood":mood,"sourceId":source_id,
		"lineKey":key,"duration":float(clip.duration),"startedAt":_clock,"elapsed":0.0,"priority":priority,"volumeDb":output.volume_db,"weapon":weapon}
	_current[channel] = item
	_last_file[channel] = clip.path
	_cooldowns[cooldown_key] = _clock + float(CATEGORY_GAP.get(category, 0.0))
	if channel == "enemy": _cooldowns["enemy:global"] = _clock + (1.6 if _enemy_count > 1 else 1.10)
	_played += 1
	_recent.append({"id":item.id,"profile":profile,"category":category,"mood":mood,"channel":channel,"sourceId":source_id,"time":_clock,"lineKey":key})
	if _recent.size() > 24: _recent.pop_front()
	return true

func _candidates(profile: String, category: String, mood: String, weapon: String = "") -> Array[Dictionary]:
	var categories: Array[String] = [category]
	# Only effort sounds may share a fallback. Hurt, ultimate and dialogue
	# never borrow unrelated recordings to hide a missing source asset.
	if category == "heavy": categories.append("attack")
	elif category == "ability": categories.append_array(["heavy","attack"])
	for candidate_category: String in categories:
		var found: Array[Dictionary] = []
		for clip: Dictionary in _clips.values():
			if not profile in clip.profiles or str(clip.category) != candidate_category: continue
			if category == "dialogue" and not mood.is_empty() and not mood in clip.moods: continue
			found.append(clip)
		if not weapon.is_empty():
			var matching := found.filter(func(item: Dictionary): return str(item.get("weapon", "")) == weapon)
			if not matching.is_empty(): found.assign(matching)
			else: found.assign(found.filter(func(item: Dictionary): return str(item.get("weapon", "")).is_empty()))
		if not found.is_empty(): return found
	return []

func _block(reason: String) -> bool:
	_blocked += 1
	_block_reasons[reason] = int(_block_reasons.get(reason, 0)) + 1
	return false

func _stop_channel(channel: String) -> void:
	if _players.has(channel):
		var output: AudioStreamPlayer = _players[channel]
		output.stop()
		output.stream = null
	_current.erase(channel)

func _finished(channel: String) -> void:
	_current.erase(channel)

func _apply_pause() -> void:
	var paused := _paused or not _focused
	for output: AudioStreamPlayer in _players.values():
		# Sending a redundant false restarts Web Sample sources; use edges only.
		if output.stream_paused != paused: output.stream_paused = paused

func _load_preference() -> void:
	if not settings_path.is_empty():
		var config := ConfigFile.new()
		if FileAccess.file_exists(settings_path) and config.load(settings_path) == OK:
			enabled = bool(config.get_value("voice", "enabled", true))
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval("(function(){try{const v=localStorage.getItem('" + WEB_SETTING + "');return v===null?null:v==='true';}catch(e){return null;}})()", true)
		if saved is bool: enabled = saved

func _save_preference() -> void:
	if not settings_path.is_empty():
		var config := ConfigFile.new()
		config.set_value("voice", "enabled", enabled)
		config.save(settings_path)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('" + WEB_SETTING + "','" + str(enabled).to_lower() + "');}catch(e){}", true)

func snapshot() -> Dictionary:
	var current: Array[Dictionary] = []
	var playing_count := 0
	for channel: String in _current:
		var item: Dictionary = _current[channel].duplicate(true)
		var output: AudioStreamPlayer = _players[channel]
		item.channel = channel
		item.playing = output.playing and not output.stream_paused
		item.paused = output.stream_paused
		item.position = maxf(0.0, output.get_playback_position()) if output.playing else 0.0
		if item.playing: playing_count += 1
		current.append(item)
	return {"available":not _clips.is_empty(),"language":_language,"enabled":enabled,"unlocked":unlocked,"focused":_focused,
		"paused":_paused or not _focused,"active":not current.is_empty(),"playing":playing_count > 0,"activePlayers":playing_count,
		"loaded":_clips.size(),"played":_played,"blocked":_blocked,"blockReasons":_block_reasons.duplicate(),"current":current,
		"recent":_recent.duplicate(true),"clock":_clock,"phase":_phase,"storyActive":_story_active,"lastLineKey":_last_line_key,
		"lastClear":_last_clear,"catalogErrors":_catalog_errors.duplicate(),"volumeDb":voice_db}
