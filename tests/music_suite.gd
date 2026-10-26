extends SceneTree

const Music = preload("res://scripts/music.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var settings := "res://build/music-unit-%d.cfg" % Time.get_ticks_usec()
	var music = Music.new()
	music.theme_path = "res://assets/music/missing-unit-theme.ogg"
	music.settings_path = settings
	root.add_child(music)
	_check(music.enabled and not music.unlocked, "fresh preferences are enabled without autoplay")
	_check(not music.snapshot().available and music.snapshot().starts == 0, "missing optional asset stays silent and usable")
	music.unlock()
	_check(music.snapshot().starts == 0, "unlock without a stream does not create broken playback")
	# A silent fixture exercises the audio clock without requiring the music asset.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	var pcm := PackedByteArray()
	pcm.resize(44100 * 2)
	stream.data = pcm
	music._player.stream = stream
	music.set_context("fight", false, false)
	await create_timer(0.12).timeout
	var beginning: Dictionary = music.snapshot()
	_check(beginning.available and beginning.playing and beginning.activePlayers == 1, "one music player starts after an intentional action")
	for i in range(6):
		music.unlock()
		music.set_context("fight", false, false)
	_check(music.snapshot().starts == 1 and music.snapshot().activePlayers == 1, "repeated actions never stack or restart music")
	await create_timer(0.12).timeout
	_check(music.snapshot().position > beginning.position, "audio cursor advances independently of simulation tick")
	music.set_context("fight", true, false)
	await create_timer(0.06).timeout
	var stopped: float = music.snapshot().position
	await create_timer(0.16).timeout
	_check(music.snapshot().paused and not music.snapshot().playing, "explicit pause suspends music")
	_check(absf(music.snapshot().position - stopped) < 0.025, "pause holds the actual audio cursor")
	music.set_focused(false)
	music.set_context("fight", false, false)
	_check(music.snapshot().paused, "focus loss stays paused when combat pause is cleared")
	music.set_focused(true)
	await create_timer(0.10).timeout
	_check(music.snapshot().playing and music.snapshot().position > stopped, "focus restore resumes from the saved cursor")
	_check(music.snapshot().starts == 1, "pause and resume do not restart the track")
	music.set_context("fight", true, false)
	music.set_focused(false)
	music.set_focused(true)
	_check(music.snapshot().paused, "refocusing cannot bypass the game's pause menu")
	music.set_context("fight", false, false)
	music.tick(1.0)
	var battle_volume: float = music.snapshot().volumeDb
	music.set_context("menu", false, false)
	music.tick(1.0)
	_check(music.snapshot().volumeDb < battle_volume - 4.0, "menus lower the song below battle volume")
	music.set_context("reward", false, false)
	_check(is_equal_approx(music.snapshot().targetDb, Music.REWARD_DB), "reward selection has its own quiet bed")
	music.set_context("fight", false, true)
	music.tick(1.0)
	_check(music.snapshot().ducked and music.snapshot().targetDb < Music.BATTLE_DB, "ultimate gently ducks the music")
	music.set_context("fight", false, false)
	music.tick(1.0)
	_check(not music.snapshot().ducked and absf(music.snapshot().volumeDb - Music.BATTLE_DB) < 0.1, "ultimate returns to normal battle volume")
	var master_muted := AudioServer.is_bus_mute(0)
	var master_volume := AudioServer.get_bus_volume_db(0)
	music.set_enabled(false)
	_check(music.snapshot().muted and is_equal_approx(music.snapshot().volumeDb, Music.SILENT_DB) and is_zero_approx(music._player.volume_linear), "mute silences the music player to actual zero with finite telemetry")
	_check(AudioServer.is_bus_mute(0) == master_muted and is_equal_approx(AudioServer.get_bus_volume_db(0), master_volume), "music preference leaves the SFX/master bus unchanged")
	var restored = Music.new()
	restored.settings_path = settings
	restored.theme_path = music.theme_path
	root.add_child(restored)
	_check(not restored.enabled and not restored.unlocked, "music-off preference survives creating a fresh controller")
	music.toggle()
	_check(music.enabled and music.snapshot().starts == 1, "unmute resumes the same player")
	music._player.stop()
	await create_timer(0.08).timeout
	music._player.stream = null
	stream = null
	music.free()
	restored.free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings))
	print("MUSIC: ", checks - failures.size(), "/", checks, " checks passed")
	quit(0 if failures.is_empty() else 1)
