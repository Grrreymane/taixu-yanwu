extends SceneTree
const Music = preload("res://scripts/music.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("CHECK FAILED: ",label)
func run() -> void:
	var music := Music.new()
	music.settings_path = "user://missing-encounter-test.cfg"
	root.add_child(music)
	music.set_enabled(true,false)
	check(music._streams.size() == 3, "all three original music tracks decode")
	check(not music.snapshot().playing, "no music auto-plays before input")
	music.unlock()
	music.set_context("fight",false,false)
	music.set_encounter("trial",3,"fight")
	await create_timer(.12).timeout
	check(music.snapshot().track == "battle_theme.ogg", "first four stages use original shrine music")
	check(music.snapshot().starts == 1, "first input starts one track")
	music.set_encounter("trial",4,"fight")
	check(music.snapshot().track == "sentience_nrbl.ogg", "fifth stage selects verified Nrbl")
	check(music.snapshot().activePlayers == 2, "switch uses a bounded two-player crossfade")
	check(absf(music.snapshot().length - 58.666667) < .03, "Nrbl uses full original musical period")
	for index in 60:
		music.set_encounter("trial",4,"fight")
		music.tick(1.0/60.0)
	check(music.snapshot().trackChanges == 1 and music.snapshot().starts == 2, "per-frame encounter update never restarts the track")
	check(music.snapshot().activePlayers == 1 and music.snapshot().crossfade == 1.0, "outgoing track stops after the short fade")
	await create_timer(.1).timeout
	var position := float(music.snapshot().position)
	music.set_encounter("trial",4,"reward")
	music.set_context("reward",false,false)
	await create_timer(.1).timeout
	check(music.snapshot().trackChanges == 1 and music.snapshot().position > position, "reward and story overlays retain the current music cursor")
	music.set_context("fight",true,false)
	await create_timer(.06).timeout
	position = float(music.snapshot().position)
	await create_timer(.1).timeout
	check(absf(music.snapshot().position-position) < .025, "pause freezes the selected boss track")
	music.set_context("fight",false,false)
	music.set_focused(false)
	check(not music.snapshot().playing, "focus loss pauses boss music")
	music.set_focused(true)
	music.set_enabled(false,false)
	check(music._player.volume_linear == 0.0 and music._previous_player.volume_linear == 0.0, "music toggle mutes both sides of a transition")
	music.set_enabled(true,false)
	check(music.snapshot().starts == 2, "mute, focus and pause never restart boss music")
	music.set_encounter("trial",5,"fight")
	music.tick(1.0)
	check(music.snapshot().track == "sentience_hard_bone.ogg", "sixth stage escalates to verified Hard Bone")
	check(absf(music.snapshot().length-76.799977) < .03, "Hard Bone uses full original period")
	check(music.snapshot().trackChanges == 2 and music.snapshot().activePlayers == 1, "second stage change leaves one music source")
	music.set_encounter("trial",5,"cleared")
	check(music.snapshot().track == "sentience_hard_bone.ogg" and music.snapshot().starts == 3, "boss victory keeps the final music")
	music.set_encounter("trial",5,"menu")
	music.tick(1.0)
	check(music.snapshot().track == "battle_theme.ogg", "return to menu restores shrine music")
	music.set_encounter("practice",5,"fight")
	check(music.snapshot().track == "battle_theme.ogg" and music.snapshot().starts == 4, "practice retains shrine music without another restart")
	var report := {"suite":"music_encounter","checks":checks,"passed":failures.is_empty(),"failures":failures,"snapshot":music.snapshot()}
	FileAccess.open("res://build/reports/music-encounter.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	music._player.stop()
	music._previous_player.stop()
	await create_timer(.1).timeout
	music.free()
	await create_timer(.08).timeout
	quit(0 if failures.is_empty() else 1)
