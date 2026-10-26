extends SceneTree
## Policy tests use short in-memory WAVs, not substitute shipped voice assets.
const Voice = preload("res://scripts/character_voice.gd")
var checks := 0
var failures: Array[String] = []
var voice
class ErrorRecorder extends Logger:
	var errors: Array = []
	func _log_error(_function:String,file:String,line:int,code:String,_rationale:String,_notify:bool,error_type:int,_backtraces:Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
var recorder := ErrorRecorder.new()
func _initialize() -> void: call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("CHECK FAILED: ", label)
func add_clip(profile: String, category: String, index: int, mood: String = "") -> void:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var bytes := PackedByteArray()
	bytes.resize(12000 if category == "ultimate" else 1600)
	bytes.fill(128)
	stream.data = bytes
	var id := profile + "_" + category + "_" + mood + "_" + str(index)
	voice._clips[id] = {"id":id,"profiles":[profile],"category":category,"moods":[mood] if not mood.is_empty() else [],
		"path":"memory://" + id + ".wav","stream":stream,"duration":stream.get_length()}
func event(kind: String, extra: Dictionary = {}) -> bool:
	var data := {"type":kind,"side":"player","sourceId":"player","name":"light"}
	data.merge(extra,true)
	return voice.handle_event(data)
func reset(context: Dictionary = {}) -> void:
	voice.clear("test")
	voice.set_context({"phase":"fight","paused":false,"storyActive":false,"playerProfile":"azure_empyrea","enemyCount":1,"bossId":""})
	voice.set_context(context)
	voice.set_focused(true)
func run() -> void:
	OS.add_logger(recorder)
	voice = Voice.new()
	voice.settings_path = ""
	voice.catalog_path = "res://tests/missing_optional_voice_catalog.json"
	root.add_child(voice)
	voice._rng.seed = 427
	check(not voice.snapshot().available, "missing optional catalog does not crash the game")
	for profile: String in ["azure_empyrea","fenghuang","night_squire","sentience"]:
		for category: String in ["attack","heavy","ability","hurt","ultimate","parry","dodge"]:
			for index in 2: add_clip(profile,category,index)
		for mood: String in ["ack","question","amused","displeased","surprise","confident"]:
			for index in 2: add_clip(profile,"dialogue",index,mood)
	voice._language = "zh-CN"
	reset()
	check(not event("attack"), "combat cannot start audio before an input unlock")
	voice.unlock()
	check(event("attack"), "first genuine unlocked attack speaks")
	check(voice.snapshot().current.size() == 1 and voice.snapshot().current[0].category == "attack", "attack uses one effort channel")
	var first_id: String = voice.snapshot().current[0].id
	check(not event("attack"), "successive attack events cannot layer the same actor")
	check(not event("ability"), "secondary ability event cannot duplicate its attack event")
	check(event("hit", {"side":"enemy","targetSide":"player","sourceId":"foe","targetId":"player","style":"sentience"}), "real player damage may interrupt effort audio")
	check(voice.snapshot().current[0].profile == "azure_empyrea" and voice.snapshot().current[0].category == "hurt", "hurt uses the victim profile instead of the attacker style")
	var count: int = voice.snapshot().played
	check(not event("hit", {"side":"enemy","targetSide":"player","armored":true}), "armored contact does not pretend to hurt")
	check(voice.snapshot().played == count, "armored contact keeps the current native phrase")
	check(event("ultimate", {"duration":3.3}), "ultimate has priority over a short grunt")
	check(not event("hit", {"side":"enemy","targetSide":"player"}), "routine damage cannot chop an ultimate phrase")
	check(not event("attack", {"side":"enemy","sourceId":"foe"}), "enemy chatter stays out of the player ultimate cut-in")
	voice.tick(0.5)
	voice.set_context({"phase":"reward"})
	check(voice.snapshot().current.size() == 1 and voice.snapshot().current[0].category == "ultimate", "native ultimate tail can finish over KO and reward")
	voice.tick(1.2)
	check(not voice.snapshot().active, "one-shot voice retires after its actual stream length")
	reset()
	check(event("attack"), "new encounter resets event gates")
	var next_id: String = voice.snapshot().current[0].id
	voice.tick(0.8)
	check(event("attack"), "another attack can speak after its short cooldown")
	check(voice.snapshot().current[0].id != next_id, "two available recordings do not repeat back-to-back")
	check(not first_id.is_empty(), "source selection exposes a concrete clip identity")
	reset({"enemyCount":3})
	check(event("attack", {"side":"enemy","sourceId":"foe_a"}), "one enemy may speak in a group")
	check(not event("attack", {"side":"enemy","sourceId":"foe_b"}), "different enemies share the one enemy voice channel")
	check(event("hit", {"side":"enemy","targetSide":"player","targetId":"player"}), "player pain may sound beside a single enemy voice")
	check(voice.snapshot().current.size() == 2, "battle permits at most two concurrent speakers")
	voice.tick(0.4)
	check(not event("hit", {"targetSide":"enemy","targetId":"foe_c"}), "group hurt events obey shared enemy density control")
	voice.tick(1.3)
	check(event("hit", {"targetSide":"enemy","targetId":"foe_c"}), "shared enemy voice recovers after density cooldown")
	reset({"bossId":"boss","enemyCount":3})
	check(not event("attack", {"side":"enemy","sourceId":"escort"}), "boss encounter prioritizes the boss over escort chatter")
	check(not event("bossPhase", {"side":"enemy","sourceId":"boss"}), "crossing half HP does not start voice before the deferred phase move")
	check(event("attack", {"side":"enemy","sourceId":"boss","weapon":"burst","phaseTransition":true}), "actual phase attack owns the boss ultimate voice")
	check(voice.snapshot().current[0].profile == "sentience" and voice.snapshot().current[0].category == "ultimate", "boss voice selects the real Sentience ultimate pool")
	reset()
	event("ultimate", {"duration":3.3})
	voice.tick(0.2)
	var clock_before: float = voice.snapshot().clock
	var elapsed_before: float = voice.snapshot().current[0].elapsed
	voice.set_context({"paused":true})
	voice.tick(0.8)
	check(voice.snapshot().clock == clock_before and voice.snapshot().current[0].elapsed == elapsed_before, "pause freezes cooldown and playback bookkeeping")
	check(voice._players.player.stream_paused and not voice.snapshot().playing, "pause reaches the actual audio player")
	voice.set_context({"paused":false})
	check(not voice._players.player.stream_paused, "resume sends the real unpause edge")
	voice.set_focused(false)
	voice.tick(0.5)
	check(voice.snapshot().clock == clock_before and voice._players.player.stream_paused, "focus loss freezes voice independently of game state")
	voice.set_focused(true)
	voice.tick(0.1)
	check(voice.snapshot().clock > clock_before, "focus return continues the existing voice clock")
	voice.set_enabled(false,false)
	check(not voice.snapshot().active and not event("attack"), "voice mute stops active audio and rejects new events")
	voice.set_enabled(true,false)
	for profile: String in ["azure_empyrea","fenghuang","night_squire"]:
		reset({"playerProfile":profile})
		check(event("hit", {"side":"enemy","targetSide":"player","style":"sentience"}), "hurt starts for " + profile)
		check(voice.snapshot().current[0].profile == profile, "hurt belongs to selected armor " + profile)
	reset()
	event("attack", {"side":"enemy","sourceId":"foe"})
	event("attack")
	voice.set_context({"storyActive":true})
	check(not voice.snapshot().active, "entering dialogue clears both combat speakers")
	var line := {"lineKey":"intro:1:0","profile":"azure_empyrea","speaker":"fuhua","reviewed":true,"clipId":"azure_empyrea_dialogue_question_0"}
	check(voice.play_dialogue(line), "individually reviewed dialogue clip can be played explicitly")
	count = voice.snapshot().played
	check(not voice.play_dialogue(line) and voice.snapshot().played == count, "revealing the current line does not replay its prefix")
	line = {"lineKey":"intro:1:1","profile":"sentience","speaker":"senti","reviewed":true,"clipId":"sentience_dialogue_amused_0"}
	check(voice.play_dialogue(line), "next speaker replaces the current short prefix")
	check(voice.snapshot().current.size() == 1 and voice.snapshot().current[0].profile == "sentience", "dialogue never overlaps two actors")
	check(not event("attack"), "combat events stay silent behind a dialogue")
	for index in 12:
		line.lineKey = "fast:" + str(index)
		check(voice.play_dialogue(line) and voice.snapshot().current.size() == 1, "rapid advance has no audio backlog " + str(index))
	line.lineKey = "missing_emotion"
	line.clipId = "unavailable"
	check(not voice.play_dialogue(line), "missing dialogue emotion does not borrow a pain or attack clip")
	check(not voice.snapshot().active, "missing new emotion still stops the previous sentence")
	line.lineKey = "automatic_removed"
	line.erase("reviewed")
	line.clipId = "sentience_dialogue_amused_0"
	check(not voice.play_dialogue(line), "even an existing clip requires explicit review")
	voice.stop_dialogue()
	check(not voice.snapshot().active and voice.snapshot().lastLineKey.is_empty(), "skip clears its dialogue voice and dedupe scope")
	voice.play_dialogue(line)
	voice.set_context({"storyActive":false})
	check(not voice.snapshot().active, "leaving a story cannot leak its prefix into battle")
	reset()
	event("ultimate")
	voice.set_context({"playerProfile":"night_squire"})
	check(not voice.snapshot().active, "switching armor cuts the old actor's voice")
	event("ultimate")
	voice.set_context({"phase":"menu"})
	check(not voice.snapshot().active, "menu clears even a finishing ultimate phrase")
	reset()
	event("ultimate")
	event("reset")
	check(not voice.snapshot().active and voice.snapshot().lastClear == "reset", "restart flushes active voice and cooldowns")
	for index in 3:
		add_clip("sentience", "attack", 20 + index)
		voice._clips["sentience_attack__" + str(20 + index)].weapon = ["sword","spear","chain"][index]
	for weapon: String in ["sword","spear","chain"]:
		reset()
		check(event("attack", {"side":"enemy","sourceId":"foe","weapon":weapon}), "native weapon effort resolves for " + weapon)
		var identity: String = voice.snapshot().current[0].id
		check(voice._clips[identity].weapon == weapon, "weapon-specific source takes precedence over generic effort for " + weapon)
	check(recorder.errors.is_empty(), "no audio or script errors during all routing checks")
	var report := {"suite":"character_voice","passed":failures.is_empty(),"checks":checks,"failures":failures,"errors":recorder.errors,
		"scope":"In-memory one-shot WAVs exercise routing and lifecycle; shipped original Chinese assets are validated separately.","snapshot":voice.snapshot()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/character-voice.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"suite":"character_voice","passed":failures.is_empty(),"checks":checks,"failures":failures,"errors":recorder.errors}))
	voice.clear("test_done")
	await create_timer(0.15).timeout
	voice.free()
	OS.remove_logger(recorder)
	await process_frame
	await create_timer(0.08).timeout
	quit(0 if failures.is_empty() else 1)
