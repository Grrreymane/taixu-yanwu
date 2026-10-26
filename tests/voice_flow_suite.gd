extends SceneTree
## Actual Main/Combat/Story integration with an in-memory audio output spy.
## Native audio decoding, priorities and signal endings live in the voice unit
## suite; this test verifies the main scene supplies events and context safely.
const Story = preload("res://scripts/sentience_story.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var approved_count := 0
var world

class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass

class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter = FighterRoster.resolve("fuhua", "azure_empyrea", "default")
		appearance_choices = {"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what: int) -> void: pass
	func simulate_focus(value: bool) -> void:
		super._notification(NOTIFICATION_APPLICATION_FOCUS_IN if value else NOTIFICATION_APPLICATION_FOCUS_OUT)

class MusicSpy extends Node:
	var enabled := true
	var unlocked := false
	var focused := true
	var voice_duck := false
	var context: Dictionary = {}
	func unlock() -> void: unlocked = true
	func toggle() -> void: enabled = not enabled
	func set_voice_duck(value: bool) -> void: voice_duck = value
	func set_context(phase: String, paused: bool, ultimate: bool) -> void:
		context = {"phase":phase, "paused":paused, "ultimate":ultimate}
	func tick(_delta: float) -> void: pass
	func set_focused(value: bool) -> void: focused = value
	func snapshot() -> Dictionary: return {"enabled":enabled, "voiceDuck":voice_duck}

class VoiceSpy extends Node:
	var enabled := true
	var unlocked := false
	var focused := true
	var playing := false
	var channel := ""
	var clock := 0.0
	var raw_ticks: Array[float] = []
	var context: Dictionary = {}
	var contexts: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var requests: Array[Dictionary] = []
	var played: Array[Dictionary] = []
	var clears: Array[String] = []
	var stops := 0
	var toggles := 0
	func unlock() -> void: unlocked = true
	func toggle() -> void:
		toggles += 1
		unlock()
		enabled = not enabled
		if not enabled: clear("muted")
	func clear(reason: String = "clear") -> void:
		clears.append(reason)
		playing = false
		channel = ""
	func stop_dialogue() -> void:
		stops += 1
		if channel == "dialogue":
			playing = false
			channel = ""
	func set_focused(value: bool) -> void: focused = value
	func set_context(value: Dictionary) -> void:
		context = value.duplicate(true)
		contexts.append(context)
	func handle_event(data: Dictionary) -> bool:
		events.append({"data":data.duplicate(true), "context":context.duplicate(true)})
		if str(data.get("type", "")) in ["reset", "start", "spawnStage"]:
			clear("event:" + str(data.type))
			return false
		if str(data.get("type", "")) in ["attack", "hit", "ultimate"] and enabled and unlocked and focused and not context.get("paused", false) and not context.get("storyActive", false):
			playing = true
			channel = "combat"
		return playing
	func play_dialogue(data: Dictionary) -> bool:
		requests.append(data.duplicate(true))
		playing = false
		channel = ""
		if not enabled or not unlocked or not focused or context.get("paused", false): return false
		played.append(data.duplicate(true))
		playing = true
		channel = "dialogue"
		return true
	func tick(delta: float) -> void:
		raw_ticks.append(delta)
		if focused and not context.get("paused", false): clock += delta
	func snapshot() -> Dictionary:
		return {"enabled":enabled, "unlocked":unlocked, "playing":playing and focused and not context.get("paused", false),
			"loaded":1, "clock":clock, "language":"zh-CN", "recent":[], "current":[]}

class ErrorRecorder extends Logger:
	var errors: Array = []
	func _log_error(_function: String, file: String, line: int, code: String, _rationale: String, _notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING: errors.append({"file":file, "line":line, "code":code})
var recorder := ErrorRecorder.new()

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("CHECK FAILED: ", label)
func step(seconds: float) -> void:
	var remaining := seconds
	if seconds == 0.0: world._process(0.0)
	while remaining > 0.000001:
		var delta := minf(1.0 / 60.0, remaining)
		world._process(delta)
		remaining -= delta
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	event.keycode = code
	world._input(event)
func last_event(kind: String) -> Dictionary:
	for index in range(world.voice.events.size() - 1, -1, -1):
		var item: Dictionary = world.voice.events[index]
		if str(item.data.type) == kind: return item
	return {}

func run() -> void:
	OS.add_logger(recorder)
	root.size = Vector2i(1440, 900)
	world = ProbeMain.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.campaign = VolatileCampaign.new()
	world.music._player.free()
	world.music.free()
	world.music = MusicSpy.new()
	world.voice.free()
	world.voice = VoiceSpy.new()
	root.add_child(world)
	world.effects.sounds.clear()
	step(0.0)
	check(world.ready_to_play, "actual Main loads the native roster")
	_menu_toggle_contract()
	_dialogue_contract()
	_combat_contract()
	_approved_text_contract()
	await process_frame
	await process_frame
	check(recorder.errors.is_empty(), "Main voice flow reports no engine/script errors")
	var report := {"suite":"voice_flow", "checks":checks, "passed":failures.is_empty(), "failures":failures,
		"errors":recorder.errors, "observations":observations, "approvedLines":approved_count,
		"audioOutput":"in-memory API spy, no claim of audible rendering", "gpuUsed":false, "userSettingsWritten":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/voice-flow.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	OS.remove_logger(recorder)
	world.free()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _menu_toggle_contract() -> void:
	var phase: String = world.campaign.phase
	var music_enabled: bool = world.music.enabled
	world.hud._voice_button.pressed.emit()
	check(not world.voice.enabled and world.voice.toggles == 1, "actual menu voice button toggles voice only")
	check(world.music.enabled == music_enabled and world.campaign.phase == phase, "menu voice button leaves music and campaign unchanged")
	key(KEY_V)
	check(world.voice.enabled and world.voice.unlocked, "V re-enables and unlocks voice")
	check(world.music.enabled == music_enabled and not world.game.started, "V never starts gameplay or toggles music")
	world.hud.open_fighter_guide()
	check(world.hud.is_guide_open(), "guide setup opened the real HUD modal")
	key(KEY_V)
	check(not world.voice.enabled and world.hud.is_guide_open(), "V remains available inside guide without dismissing it")
	key(KEY_V)
	world.hud.close_fighter_guide()
	check(world.voice.enabled and world.music.enabled == music_enabled, "voice restored independently before play")

func _dialogue_contract() -> void:
	world._action("start")
	check(world.story.active and world.voice.requests.is_empty(), "start initializes story before its first presented frame")
	step(0.0)
	check(world.voice.requests.size() == 1 and world.voice.played.size() == 1, "first story line is dispatched at its first frame")
	check(world.voice.context.storyActive and world.voice.context.playerProfile == "azure_empyrea", "dialogue receives current story and armor context")
	var first: Dictionary = world.voice.requests[-1]
	check(first.speaker == "fuhua" and first.profile == "azure_empyrea" and first.emotion == "question", "real opening question selects Fu Hua question metadata")
	check(world.music.voice_duck, "active voice asks music to duck without toggling it")
	var initial_text: String = world.story.lines[0].text
	world._action("story_next")
	step(0.2)
	check(world.story.revealed and world.story.index == 0 and world.voice.requests.size() == 1, "revealing full text never repeats its voice")
	world._action("story_next")
	step(0.0)
	check(world.story.index == 1 and world.voice.requests.size() == 2, "next actual line dispatches one new cue")
	check(world.voice.requests[-1].speaker == "senti" and world.voice.requests[-1].profile == "sentience", "Senti does not borrow the selected Fu Hua voice")
	var old_requests: int = world.voice.requests.size()
	var old_played: int = world.voice.played.size()
	key(KEY_V)
	world._action("story_next")
	world._action("story_next")
	step(0.0)
	check(world.voice.requests.size() == old_requests + 1 and world.voice.played.size() == old_played, "muted new line is consumed without playback")
	key(KEY_V)
	step(0.1)
	check(world.voice.requests.size() == old_requests + 1 and world.voice.played.size() == old_played, "unmuting does not retroactively speak a consumed line")
	world.simulate_focus(false)
	world._action("story_next")
	world._action("story_next")
	step(0.1)
	check(not world.voice.focused and not world.music.focused and world.voice.requests.size() == old_requests + 1, "unfocused new line is not consumed or played")
	world.simulate_focus(true)
	step(0.0)
	check(world.voice.focused and world.voice.requests.size() == old_requests + 2, "new line starts when its story regains focus")
	check(world.story.lines[0].text == initial_text, "voice routing leaves actual story text untouched")
	var stops: int = world.voice.stops
	world._action("story_skip")
	check(not world.story.active and world.voice.stops == stops + 1 and not world.voice.playing, "skip stops old dialogue immediately")
	step(0.0)
	check(not world.music.voice_duck, "music returns from duck after dialogue stops")
	world._begin_story("intro")
	step(0.0)
	check(world.voice.requests[-1].lineKey != first.lineKey, "restarting the same dialogue yields a fresh audio key")
	world._action("menu")
	check(world.campaign.phase == "menu" and not world.story.active and not world.voice.playing, "returning to menu clears story and active voice")
	var clear_count: int = world.voice.clears.size()
	world._action("select_style:night_squire")
	step(0.0)
	check(world.voice.clears.size() > clear_count and world.voice.context.playerProfile == "night_squire", "changing armor clears voice and supplies new profile")
	world._action("select_appearance:autumn_leaves")
	world._action("start")
	step(0.0)
	# A repeat run opens with Senti; advance through actual dialogue to the
	# first Fu Hua line instead of assuming the first-run speaker ordering.
	while world.story.active and str(world.story.lines[world.story.index].speaker) != "fuhua":
		if not world.story.revealed: world._action("story_next")
		world._action("story_next")
		step(0.0)
	check(world.voice.requests[-1].profile == "night_squire", "Autumn Leaves shares White Night dialogue identity")
	world._action("menu")
	observations.append({"dialogueRequests":world.voice.requests.size(), "playedDialogueRequests":world.voice.played.size(), "revealsDoNotRepeat":true, "silenceDoesNotReplayOldLine":true})

func _combat_contract() -> void:
	world._action("practice")
	world.game.set_training(true)
	world.game.player.x = -0.6
	world.game.enemy.x = 0.8
	step(0.0)
	world._action("light")
	var attack: Dictionary = last_event("attack")
	check(not attack.is_empty() and attack.data.side == "player" and attack.data.style == "night_squire", "real player attack arrives with native armor metadata")
	check(attack.context.phase == "fight" and not attack.context.storyActive, "battle event gets fight context before dispatch")
	world.game._state(world.game.player, "idle")
	world.game._state(world.game.enemy, "idle")
	var hp: float = world.game.player.hp
	var source_attack := {"name":"light", "damage":7.0, "postureDamage":5.0, "push":0.15, "stun":0.3, "comboIndex":0, "range":2.0}
	world.game._receive(world.game.enemy, world.game.player, source_attack)
	var hit: Dictionary = last_event("hit")
	check(world.game.player.hp < hp and not hit.is_empty(), "real combat receive path both damages player and reaches voice")
	check(hit.data.targetSide == "player" and hit.data.targetId == "player" and hit.data.sourceId == world.game.enemy.id and hit.data.style == "sentience", "hurt event retains defender identity despite attacker style")
	var forwarded: Dictionary = {}
	for item: Dictionary in world.events:
		if item.type == "hit": forwarded = item
	check(forwarded == hit.data, "Main forwards the entire original contact event without dropping fields")
	var before_time: float = world.game.time
	var before_voice: float = world.voice.clock
	world.game.hit_stop = 0.5
	step(0.05)
	check(world.game.time == before_time and is_equal_approx(world.voice.clock - before_voice, 0.05), "contact hitstop never freezes or chops the voice clock")
	world._action("pause")
	check(world.game.paused and world.voice.context.paused, "pause reaches voice immediately on the combat event")
	before_voice = world.voice.clock
	step(0.1)
	check(world.voice.clock == before_voice, "explicit pause freezes voice playback time")
	world._action("pause")
	step(0.05)
	check(not world.voice.context.paused and world.voice.clock > before_voice, "resume restores the same voice clock")
	world.simulate_focus(false)
	check(not world.voice.focused and world.game.paused and world.voice.context.paused, "focus loss immediately pauses battle and voice")
	world.simulate_focus(true)
	check(world.voice.focused and world.game.paused, "focus return restores output focus while preserving deliberate game pause")
	world._action("pause")
	var clears: int = world.voice.clears.size()
	world._action("restart")
	check(world.voice.clears.size() > clears and not world.voice.playing, "restart forwards reset/start clearing before new combat")
	step(0.0)
	check(world.voice.context.playerProfile == "night_squire" and world.voice.context.phase == "fight", "restarted practice retains the selected armor")
	var before_music: bool = world.music.enabled
	var before_phase: String = world.campaign.phase
	key(KEY_V)
	check(not world.voice.enabled and world.music.enabled == before_music and world.campaign.phase == before_phase, "combat V mute leaves music and combat phase alone")
	key(KEY_V)
	world._action("menu")
	check(not world.voice.playing, "menu transition ends any remaining combat effort")
	observations.append({"incomingHit":hit.data, "hitstopVoiceDelta":0.05, "resetClears":world.voice.clears.duplicate()})

func _approved_text_contract() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/dialogue-editing/user-integrated.json"))
	check(baseline.revision == Dialogue.REVISION and baseline.lineCount == 188, "voice integration uses the accepted dialogue revision")
	for section: Dictionary in baseline.sections:
		var source: String = section.source
		var parts := source.split(".")
		var actual: Array = []
		var route_ids: Array = {"press":["fist"], "guard":["reflection"], "flow":["flow"], "balanced":[]}.get(parts[-1], [])
		if parts[0] in ["card", "combination", "turn"]:
			var table: Dictionary = {"card":Dialogue.CARDS, "combination":Dialogue.COMBINATIONS, "turn":Dialogue.TURNS}[parts[0]]
			actual = Story._rows(table[parts[1]])
		elif source == "intro.first.common": actual = Story.lines("intro").slice(0, -1)
		elif source == "intro.repeat.common": actual = Story.lines("intro", {"runNumber":2}).slice(0, -1)
		elif source.begins_with("intro.contract."): actual = [Story.lines("intro", {"contractId":parts[-1]})[-1]]
		elif parts[0] == "final_exchange": actual = Story._final_exchange(parts[1])
		elif parts[0] == "victory": actual = Story.lines("victory", {"rewardIds":route_ids})
		elif parts[0] == "defeat":
			if parts[-1] == "prefix": actual = [Story.lines("defeat", {"stageIndex":5 if parts[1] == "boss" else 0})[0]]
			else:
				route_ids = {"press":["fist"], "guard":["reflection"], "flow":["flow"], "balanced":[]}[parts[1]]
				actual = Story.lines("defeat", {"rewardIds":route_ids}).slice(1)
		elif source == "compatibility.final.prefix": actual = Story.lines("final").slice(0, 2)
		elif parts[0] == "compatibility": actual = Story.lines(parts[1])
		var wanted: Array = section.lines.map(func(row: Dictionary): return [str(row.speaker), str(row.text)])
		check(actual.map(func(row: Dictionary): return [str(row.speaker), str(row.text)]) == wanted, "accepted text remains unchanged: " + str(section.id))
		approved_count += section.lines.size()
	check(approved_count == 188, "all 188 accepted lines verified after real Main flow")
