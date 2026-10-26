extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Voice = preload("res://scripts/character_voice.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	var results: Array = []
	for fps: float in [30.0,50.0,60.0,120.0,144.0]:
		var voice := Voice.new()
		voice.settings_path = ""
		root.add_child(voice)
		voice.set_enabled(true,false)
		voice.unlock()
		var game := Combat.new()
		game.start_sparring()
		game.enemy.hp = 100.0
		game.enemy.x = 1.5
		game.player.x = 0.0
		voice.set_context({"phase":"fight","playerProfile":"azure_empyrea","bossId":game.enemy.id,"enemyCount":1})
		var burst_records: Array = []
		var callback := func(data: Dictionary):
			voice.set_context({"ultimateActive":not game.ultimate.is_empty()})
			var played := voice.handle_event(data)
			if str(data.get("type","")) == "attack" and str(data.get("weapon","")) == "burst":
				burst_records.append({"played":played,"clock":voice._clock,"suppression":voice._suppress_enemy_until,"pendingUltimate":not game.ultimate.is_empty(),"snapshot":voice.snapshot()})
		game.event.connect(callback)
		game._begin_ultimate()
		for frame in int(fps*4.4):
			game.update(1.0/fps)
			# This is intentionally AFTER Combat.update, matching Main._process.
			voice.tick(1.0/fps)
			if not burst_records.is_empty(): break
		check(burst_records.size()==1,"boss half-health burst emitted after Q at %d FPS"%int(fps))
		if not burst_records.is_empty():
			check(bool(burst_records[0].played),"boss ultimate voice is not lost on the Q handoff frame at %d FPS"%int(fps))
			var current: Array = burst_records[0].snapshot.current
			check(current.any(func(row:Dictionary):return row.channel == "player" and row.category == "ultimate"),"player original phrase finishes without being cut by boss handoff at %d FPS"%int(fps))
		results.append({"fps":fps,"bursts":burst_records})
		game.event.disconnect(callback)
		voice.clear("test_done")
		await create_timer(.1).timeout
		voice.free()
		await create_timer(.08).timeout
	var report := {"suite":"voice_ultimate_handoff","checks":checks,"passed":failures.is_empty(),"failures":failures,"cases":results}
	FileAccess.open("res://build/reports/voice-ultimate-handoff.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
