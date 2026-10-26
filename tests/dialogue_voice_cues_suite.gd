extends SceneTree
const Cues = preload("res://scripts/dialogue_voice_cues.gd")
const Story = preload("res://scripts/sentience_story.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
var checks := 0
var failures: Array[String] = []
var categories: Dictionary = {}
var approved_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("CHECK FAILED: ", label)

func run() -> void:
	_emotion_contract()
	_once_per_line_contract()
	_approved_text_contract()
	var report := {"suite":"dialogue_voice_cues", "checks":checks, "passed":failures.is_empty(),
		"failures":failures, "approvedLines":approved_count, "categories":categories,
		"scope":"Metadata and line identity only; availability and playback are tested by CharacterVoice. No accepted dialogue edits.", "gpuUsed":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/dialogue-voice-cues.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _emotion_contract() -> void:
	var cases := [
		["fuhua", "好！", "calm", "ack"],
		["senti", "好！", "confident", "confident"],
		["senti", "嘿嘿，这你就别管了。", "confident", "amused"],
		["senti", "……等等，那可不行！", "serious", "surprise"],
		["senti", "哎？怎么回事？", "question", "surprise"],
		["fuhua", "嗯？", "calm", "question"],
		["fuhua", "你想去哪家？", "question", "question"],
		["senti", "看来你今天也打上瘾了嘛。", "teasing", "amused"],
		["senti", "谁怕了！", "confident", "displeased"],
		["senti", "来，开始吧！", "serious", "ack"],
		["fuhua", "放心，我记得。", "calm", "ack"]]
	for row in cases:
		var cue: Dictionary = Cues.resolve({"speaker":row[0], "text":row[1], "mood":row[2]})
		check(cue.is_empty(), "no automatic emotion prefix: " + str(row[1]))
	check(Cues.resolve({"speaker":"narrator", "text":"旁白"}).is_empty(), "unknown speaker cannot borrow a character voice")
	check(Cues.resolve({"speaker":"fuhua", "text":" "}).is_empty(), "blank line has no voice")
	var approved := {"speaker":"fuhua", "text":"好。", "voiceCue":{"reviewed":true,"clipId":"dialogue_fuhua_ack","textHash":"好。".sha256_text()}}
	check(Cues.resolve(approved, "missing").profile == "azure_empyrea", "explicit review retains Fu Hua identity")
	approved.speaker = "senti"
	check(Cues.resolve(approved, "night_squire").profile == "sentience", "explicit Senti clip never inherits player armor")
	approved.text = "不行。"
	check(Cues.resolve(approved).is_empty(), "edited sentence invalidates stale audio review")

func _once_per_line_contract() -> void:
	var tracker := Cues.new()
	var state := {"active":true, "focused":true, "scene":"intro", "branchId":"first", "index":0,
		"speaker":"fuhua", "text":"你说有东西要给我看……就是这儿？", "mood":"question", "time":0.0, "lineTime":0.0, "revealed":false}
	state.voiceCue = {"reviewed":true,"clipId":"fixture_explicit_original","textHash":str(state.text).sha256_text()}
	var original := state.duplicate(true)
	var first: Dictionary = tracker.next(state, "night_squire")
	check(not first.is_empty() and first.profile == "night_squire", "first visible line emits immediately")
	check(state == original, "classification never mutates line content")
	for frame in 120:
		state.time = float(frame) / 60.0
		state.lineTime = state.time
		state.revealed = frame >= 20
		check(tracker.next(state, "night_squire").is_empty(), "reveal and frame ticks cannot replay a line %d" % frame)
	state.mood = "calm"
	check(tracker.next(state, "night_squire").is_empty(), "late metadata cannot replay the same spoken start")
	state.index = 1
	state.lineTime = 0.0
	var second: Dictionary = tracker.next(state, "night_squire")
	check(not second.is_empty() and second.lineKey != first.lineKey, "identical text on a distinct line has a distinct cue")
	state.index = 2
	state.focused = false
	check(tracker.next(state).is_empty(), "new line remains unheard while unfocused")
	state.focused = true
	check(not tracker.next(state).is_empty(), "line begins on return to a visible scene")
	state.index = 3
	state.paused = true
	check(tracker.next(state).is_empty(), "new paused line does not get consumed")
	state.paused = false
	check(not tracker.next(state).is_empty(), "resumed new line can start once")
	tracker.reset()
	state = original.duplicate(true)
	var replay: Dictionary = tracker.next(state, "night_squire")
	check(replay.lineKey != first.lineKey and replay.session > first.session, "explicit scene replay is not suppressed by old audio keys")
	state.time = 1.0
	check(tracker.next(state).is_empty(), "replay still emits only at start")
	state.time = 0.0
	var rewound: Dictionary = tracker.next(state)
	check(not rewound.is_empty() and rewound.session > replay.session, "rewound scene clock starts a new session safely")
	state.active = false
	check(tracker.next(state).is_empty() and not tracker.snapshot().active, "scene close clears tracked dialogue identity")
	state.active = true
	check(not tracker.next(state).is_empty(), "return to same chapter after close can play again")

func _actual_rows(section: Dictionary) -> Array:
	var source: String = str(section.source)
	var parts := source.split(".")
	var route_ids: Array = {"press":["fist"], "guard":["reflection"], "flow":["flow"], "balanced":[]}.get(parts[-1], [])
	if parts[0] in ["card", "combination", "turn"]:
		var table: Dictionary = {"card":Dialogue.CARDS, "combination":Dialogue.COMBINATIONS, "turn":Dialogue.TURNS}[parts[0]]
		return Story._rows(table[parts[1]])
	if source == "intro.first.common": return Story.lines("intro").slice(0, -1)
	if source == "intro.repeat.common": return Story.lines("intro", {"runNumber":2}).slice(0, -1)
	if source.begins_with("intro.contract."): return [Story.lines("intro", {"contractId":parts[-1]})[-1]]
	if parts[0] == "final_exchange": return Story._final_exchange(parts[1])
	if parts[0] == "victory": return Story.lines("victory", {"rewardIds":route_ids})
	if parts[0] == "defeat":
		if parts[-1] == "prefix": return [Story.lines("defeat", {"stageIndex":5 if parts[1] == "boss" else 0})[0]]
		route_ids = {"press":["fist"], "guard":["reflection"], "flow":["flow"], "balanced":[]}[parts[1]]
		return Story.lines("defeat", {"rewardIds":route_ids}).slice(1)
	if source == "compatibility.final.prefix": return Story.lines("final").slice(0, 2)
	if parts[0] == "compatibility": return Story.lines(parts[1])
	return []

func _approved_text_contract() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/dialogue-editing/user-integrated.json"))
	check(baseline.revision == Dialogue.REVISION and baseline.lineCount == 188, "accepted dialogue revision remains user-dialogue-1")
	var tracker := Cues.new()
	var seen_keys: Dictionary = {}
	for section: Dictionary in baseline.sections:
		var actual := _actual_rows(section)
		var actual_text: Array = actual.map(func(row: Dictionary): return [str(row.speaker), str(row.text)])
		var approved_text: Array = section.lines.map(func(row: Dictionary): return [str(row.speaker), str(row.text)])
		check(actual_text == approved_text, "approved speakers and text unchanged: " + str(section.id))
		tracker.reset()
		for index in actual.size():
			var line: Dictionary = actual[index].duplicate(true)
			var before := line.duplicate(true)
			line.merge({"active":true, "scene":str(section.id), "index":index, "time":float(index), "revision":Dialogue.REVISION})
			var cue: Dictionary = tracker.next(line)
			check(cue.is_empty(), "approved text does not receive an automatic vocal prefix")
			check(actual[index] == before, "automatic silence preserves exact approved text")
			for style: String in Cues.PLAYER_PROFILES:
				var styled: Dictionary = Cues.resolve(line, style)
				check(styled.is_empty(), "all armor variants remain silent without explicit review")
			check(tracker.next(line).is_empty(), "approved line can be polled again without replay")
			approved_count += 1
	check(approved_count == 188, "all 188 approved lines checked")
