extends SceneTree
const Framing = preload("res://scripts/battle_camera.gd")
const Accent = preload("res://scripts/combat_accent.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var accent = Accent.new()
	root.add_child(accent)
	for event_kind in ["attack", "block", "dodge", "hit"]:
		accent.handle_event({"type":event_kind, "heavy":false})
		check(is_zero_approx(accent.amount()), "no strong screen accent for " + event_kind)
	for event_kind in ["hit", "parry", "guardBreak"]:
		accent.handle_event({"type":event_kind, "heavy":true, "contactX":-3.2, "facing":-1})
		check(accent.amount() > 0.8, event_kind + " has immediate contact emphasis")
		check(is_equal_approx(accent.origin.x, -3.2), event_kind + " follows the actual contact")
		var frozen: Dictionary = accent.snapshot()
		for i in 10: accent.tick(0.0)
		check(accent.snapshot() == frozen, event_kind + " freezes with action during pause and hitstop")
		accent.tick(0.3)
		check(is_zero_approx(accent.amount()), event_kind + " fades completely after contact")
	for reset_kind in ["reset", "ultimate", "spawnStage"]:
		accent.handle_event({"type":"hit", "heavy":true})
		accent.handle_event({"type":reset_kind})
		check(is_zero_approx(accent.amount()), reset_kind + " removes old contact composition")
	for aspect in [16.0/9.0, 4.0/3.0, 0.75]:
		for pair in [[-0.6,0.6], [-5.0,5.0], [3.5,5.0]]:
			var shot: Dictionary = Framing.frame(pair[0], [pair[1]], aspect)
			var reach: float = shot.position.z * tan(deg_to_rad(32.6 * 0.5)) * aspect
			check(absf(pair[0] - shot.position.x) + 1.65 < reach, "player pose remains framed at peak lens punch " + str(pair) + "/" + str(aspect))
			check(absf(pair[1] - shot.position.x) + 1.65 < reach, "enemy pose remains framed at peak lens punch " + str(pair) + "/" + str(aspect))
			check(shot.position.z >= 9.7 - 0.00001, "camera keeps vertical room for raised arms")
		var multi: Dictionary = Framing.frame(1.0, [-5.0,0.5,4.0], aspect)
		var reach: float = multi.position.z * tan(deg_to_rad(32.6 * 0.5)) * aspect
		check(absf(-5.0-multi.position.x)+1.65 < reach and absf(4.0-multi.position.x)+1.65 < reach, "multienemy flankers remain visible /" + str(aspect))
	var right: Dictionary = Framing.frame(3.0, [4.0], 1.6)
	var left: Dictionary = Framing.frame(-3.0, [-4.0], 1.6)
	check(right.position.x == -left.position.x and right.position.z == left.position.z, "battle framing mirrors at both arena edges")
	var close: Dictionary = Framing.frame(-0.6, [0.6], 1.6)
	check(close.position.z < 11.8, "close combat is larger than the old far camera")
	accent.queue_free()
	await process_frame
	print("VISUAL_PRESENTATION_CHECKS ", checks, " FAILURES ", failures.size())
	quit(0 if failures.is_empty() else 1)
