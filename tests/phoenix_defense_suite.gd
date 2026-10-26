extends "res://tests/actor_presentation_suite.gd"

func _run() -> void:
	var Roster = load("res://scripts/fighter_roster.gd")
	var selected: Dictionary = Roster.resolve("fuhua", "fenghuang")
	_check(not selected.is_empty(), "Phoenix is a registered playable style")
	if selected.is_empty():
		quit(1)
		return
	_check(selected.actor.defense.libraryPath == "res://assets/motions/phoenix-defense.res", "Phoenix loads its independently baked target-rest library")
	_check(bool(selected.actor.defense.get("fullGrounding", false)), "the Phoenix profile fully corrects the blended supporting foot")
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup(false, selected)
	_check(actor.ready_for_combat, "the actual Phoenix actor and its native body motions load")
	_check_native_defense(actor)
	var report := {"suite":"phoenix_defense", "checks":checks, "failures":failures,"passed":failures.is_empty(),"gpuUsed":false}
	var output := FileAccess.open("res://build/phoenix-defense-runtime-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "));output.close()
	print(JSON.stringify(report))
	actor.free()
	quit(0 if failures.is_empty() else 1)
