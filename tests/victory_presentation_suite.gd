extends SceneTree

const Victory = preload("res://scripts/victory_presentation.gd")
const Actor = preload("res://scripts/actor.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
var checks := 0
var failures: Array[String] = []

# Main's real flow runs against ephemeral statistics. Never overwrite the
# player's record while testing a controlled final encounter.
class VolatileCampaign extends "res://scripts/campaign.gd":
	var save_calls := 0
	func _load_record() -> void:
		pass
	func _save_record() -> void:
		save_calls += 1

# Music has its own actual-output browser suite. Avoid starting sound or
# touching the user's preference file during this presentation-only test.
class QuietMusic extends Node:
	var context_paused := false
	var focused := true
	func unlock() -> void:
		pass
	func toggle() -> void:
		pass
	func set_context(_phase: String, paused: bool, _ultimate: bool) -> void:
		context_paused = paused
	func tick(_delta: float) -> void:
		pass
	func set_focused(value: bool) -> void:
		focused = value
	func snapshot() -> Dictionary:
		return {"enabled": true, "paused": context_paused}

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	_clock_contract()
	_actor_contract()
	if not "--unit-only" in OS.get_cmdline_user_args():
		await _main_contract()
	await process_frame
	await process_frame
	print(JSON.stringify({"suite": "victory_presentation", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _clock_contract() -> void:
	var controller := Victory.new()
	controller.tick(0.5)
	_check(not controller.visible and controller.time == 0.0, "inactive victory does not advance")
	controller.begin()
	controller.tick(0.6)
	_check(controller.playing() and is_equal_approx(controller.time, 0.6) and controller.plays == 1, "begin starts one independent presentation clock")
	controller.tick(-1.0)
	controller.tick(0.0)
	_check(is_equal_approx(controller.time, 0.6), "negative and zero deltas cannot change the clock")
	controller.toggle_pause()
	controller.tick(0.8)
	_check(controller.paused and is_equal_approx(controller.time, 0.6), "explicit pause freezes the presentation")
	controller.toggle_pause()
	controller.tick(0.2)
	_check(is_equal_approx(controller.time, 0.8), "resume continues from the paused cursor")
	controller.set_focused(false)
	controller.tick(0.5)
	_check(controller.paused and is_equal_approx(controller.time, 0.8), "focus loss pauses and freezes the clock")
	controller.set_focused(true)
	controller.tick(0.5)
	_check(controller.paused and is_equal_approx(controller.time, 0.8), "focus return waits for an explicit resume")
	controller.toggle_pause()
	controller.tick(0.1)
	_check(is_equal_approx(controller.time, 0.9), "focus-paused presentation resumes from its old cursor")
	controller.skip()
	_check(controller.visible and not controller.playing() and controller.time >= Victory.DURATION and not controller.paused, "skip reveals results without hiding the victory scene")
	controller.begin()
	_check(controller.plays == 2 and controller.time == 0.0 and not controller.paused, "replay restarts presentation only")
	controller.tick(Victory.DURATION + 0.5)
	_check(controller.visible and not controller.playing(), "completed animation remains available as the result backdrop")
	controller.clear()
	controller.tick(1.0)
	_check(not controller.visible and controller.time == 0.0 and not controller.paused and controller.plays == 2, "clear resets transient state without manufacturing a new play")
	for at in [0.0, 0.2, 1.3, 2.8, 3.55, 3.8, 4.4, 8.0]:
		for aspect in [16.0 / 9.0, 1.6, 0.75]:
			var shot: Dictionary = Victory.frame(at, aspect)
			_check(shot.position.is_finite() and shot.target.is_finite() and is_finite(float(shot.fov)) and shot.position.distance_to(shot.target) > 0.1, "victory camera is finite at %.2f / %.2f" % [at, aspect])

func _pose(actor) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in actor.skeleton.get_bone_count():
		result.append(actor.skeleton.get_bone_pose(index))
	return result

func _finite_pose(actor) -> bool:
	for bone: Transform3D in _pose(actor):
		if not bone.origin.is_finite() or not bone.basis.x.is_finite() or not bone.basis.y.is_finite() or not bone.basis.z.is_finite():
			return false
	return true

func _actor_contract() -> void:
	var actor = Actor.new()
	var legacy = Actor.new()
	root.add_child(actor)
	root.add_child(legacy)
	actor.setup(false, Roster.resolve())
	legacy.setup(false)
	_check(actor.ready_for_combat and legacy.ready_for_combat, "explicit roster setup and legacy setup both load")
	_check(actor.presentation_snapshot().victoryAvailable and legacy.presentation_snapshot().victoryAvailable, "both setup paths expose the native victory library")
	_check(actor.skeleton.get_bone_count() == legacy.skeleton.get_bone_count() and _pose(actor) == _pose(legacy), "roster integration preserves the default rest pose")
	actor.react_impact("parry", -1.0, true)
	actor.flash()
	actor.reset_presentation()
	for at in [0.0, 0.2, 0.8, 1.5, 2.3, 3.0, 3.799, 3.8, 4.0, 4.4, 5.816667, 7.25]:
		actor.animate_victory(at)
		var data: Dictionary = actor.presentation_snapshot()
		var native_time: float = at + 0.60
		var expected := "victory" if native_time < 3.8 else "victoryIdle"
		_check(data.motion == expected and _finite_pose(actor), "native victory phase and finite bones at %.6f" % at)
		var expected_time: float = native_time if native_time < 3.8 else fposmod(native_time - 3.8, 2.016667)
		_check(is_equal_approx(float(data.sourceTime), expected_time), "native source cursor follows presentation time at %.6f" % at)
		var pose := _pose(actor)
		var transform: Transform3D = actor.transform
		actor.animate_victory(at)
		actor.animate_victory(at)
		_check(pose == _pose(actor) and transform == actor.transform and data == actor.presentation_snapshot(), "zero-delta victory sampling freezes pose and diagnostics at %.6f" % at)
		_check(actor.position == Vector3.ZERO and actor.rotation == Vector3.ZERO, "victory stays at its presentation origin at %.6f" % at)
	actor.reset_presentation()
	legacy.reset_presentation()
	var fighter := {"state": "idle", "stateTime": 0.0, "facing": -1.0, "x": -1.7}
	actor.animate_fighter(fighter, 0.0, 0.0)
	legacy.animate_fighter(fighter, 0.0, 0.0)
	_check(_pose(actor) == _pose(legacy) and actor.transform == legacy.transform, "returning to combat exactly matches a fresh default actor")
	var restored: Dictionary = actor.presentation_snapshot()
	_check(restored.motion == "idle" and restored.guardWeight == 0.0 and restored.recoil == 0.0 and restored.flash == 0.0 and restored.defenseClip == "", "battle reset leaves no victory, impact or defense overlay")
	actor.free()
	legacy.free()

func _frames(world, count: int, delta: float = 0.05) -> void:
	for ignored in count:
		world._process(delta)

func _key(world, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	world._input(event)

func _stats(world) -> Dictionary:
	return {"game": world.game.stats.duplicate(true), "totals": world.campaign.totals.duplicate(true),
		"last": world.campaign.last_stats.duplicate(true), "best": world.campaign.best_score,
		"rank": world.campaign.best_rank, "saves": world.campaign.save_calls}

func _finish_fixture(world, won: bool) -> void:
	# Presentations now surround the encounter, and native C6 Die takes three
	# seconds. Complete those real gates instead of assuming a 1.5s death.
	if world.story.active: world.story.skip()
	world._process(0.05)
	if world.boss_entrance.active:
		world._skip_boss_entrance()
		_frames(world, 24)
	# This is an isolated native development fixture, never a product bridge.
	# The real _check_end and main finish-delay/commit code still handle the win.
	world.stage_countdown = 0.0
	world.game.stats = {"kills": 3 if won else 0, "parries": 2, "dodges": 1, "maxCombo": 7,
		"damageTaken": 12.0, "damageDealt": 160.0, "elapsed": 20.0}
	world.game.ultimate = {}
	world.game.hit_stop = 0.0
	if won:
		for foe in world.game.enemies:
			foe.hp = 0.0
	else:
		world.game.player.hp = 0.0
	world.game._check_end()
	for index in 200:
		world._process(0.05)
		if world.campaign.phase != "fight": break
	if world.story.active: world.story.skip()

func _main_contract() -> void:
	# Keep main dynamic so --unit-only can run while HUD is being edited.
	var Main = load("res://scripts/main.gd")
	_check(Main != null and Main.can_instantiate(), "main and its current HUD parse")
	if Main == null or not Main.can_instantiate():
		return
	var world = Main.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.campaign = VolatileCampaign.new()
	# Music creates its player before _ready attaches it as a child. This test
	# substitutes the controller before _ready, so also release that orphan.
	world.music._player.free()
	world.music.free()
	world.music = QuietMusic.new()
	root.add_child(world)
	_check(world.ready_to_play, "main initializes through the real ready path")
	_frames(world, 2)

	world._action("practice")
	_finish_fixture(world, true)
	_check(world.campaign.phase == "cleared" and world.victory.visible and world.victory.plays == 1, "practice victory begins exactly one presentation")
	var committed := _stats(world)
	_frames(world, 15)
	_check(world.victory.plays == 1 and committed == _stats(world), "the ended battle cannot commit or begin again on later frames")
	var clock: float = world.victory.time
	_key(world, KEY_ESCAPE)
	_frames(world, 8)
	_check(world.victory.paused and world.victory.time == clock and not world.game.paused, "Escape pauses the independent victory clock rather than the finished combat")
	var camera: Transform3D = world.camera.transform
	var pose := _pose(world.player)
	_frames(world, 6)
	_check(camera == world.camera.transform and pose == _pose(world.player), "paused victory freezes camera and bones")
	_check(world.music.context_paused, "victory pause reaches the existing music context")
	_key(world, KEY_ESCAPE)
	_frames(world, 2)
	_check(not world.victory.paused and world.victory.time > clock, "Escape resumes the same victory")
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	clock = world.victory.time
	_frames(world, 8)
	_check(world.victory.paused and world.victory.time == clock, "main focus loss freezes victory")
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_frames(world, 2)
	_check(world.victory.paused and world.victory.time == clock, "main focus return does not bypass pause")
	_key(world, KEY_ENTER)
	_check(not world.victory.playing() and world.victory.visible and world.campaign.phase == "cleared" and world.victory.plays == 1, "Enter during a paused presentation only skips to results")
	_check(committed == _stats(world), "skip never changes committed statistics")
	world._action("victory_replay")
	_check(world.victory.plays == 2 and world.victory.time == 0.0, "replay starts presentation from zero")
	_frames(world, 100)
	_check(not world.victory.playing() and committed == _stats(world), "a full replay never records combat or score again")
	world._action("menu")
	_frames(world, 1)
	_check(world.campaign.phase == "menu" and not world.victory.visible and world.victory.time == 0.0 and not world.game.started, "menu clears presentation and the finished battle")
	_check(world.player.current_motion == "idle" and world.camera.fov == 34.0, "menu restores the normal actor and camera profile")
	world._action("start")
	_check(world.campaign.phase == "fight" and world.stage_countdown > 0.0 and not world.victory.visible, "starting again uses a clean first encounter")
	var plays_before: int = world.victory.plays
	_finish_fixture(world, true)
	_check(world.campaign.phase == "reward" and not world.victory.visible and world.victory.plays == plays_before, "an intermediate trial victory opens rewards without the finale")
	world._action("victory_replay")
	_check(not world.victory.visible and world.victory.plays == plays_before, "reward phase cannot replay a previous victory")
	world._action("menu")
	world._action("start")
	_finish_fixture(world, false)
	_check(world.campaign.phase == "failed" and not world.victory.visible and world.victory.plays == plays_before, "defeat never triggers the winner presentation")
	world._action("victory_replay")
	_check(not world.victory.visible and world.victory.plays == plays_before, "defeat cannot replay a previous victory")
	world._action("retry")
	_check(world.campaign.phase == "fight" and not world.victory.visible and world.game.player.hp > 0.0, "retry starts battle without presentation residue")
	world._action("menu")
	world._action("start")
	world.campaign.stage_index = world.campaign.stages.size() - 1
	world._begin_encounter()
	_finish_fixture(world, true)
	_check(world.campaign.phase == "cleared" and world.victory.plays == plays_before + 1 and world.victory.visible, "the final trial win begins one finale")
	committed = _stats(world)
	_check(world.campaign.save_calls == 1 and world.campaign.best_score > 0, "the final trial commits its new score once")
	_frames(world, 110)
	world._action("victory_replay")
	_frames(world, 5)
	_key(world, KEY_ENTER)
	_frames(world, 5)
	_check(committed == _stats(world) and world.campaign.save_calls == 1, "finale completion, replay and Enter skip never duplicate score or save")
	world.touch_move = 1.0
	world.touch_guard = true
	world._action("restart")
	_check(not world.victory.visible and world.victory.time == 0.0 and not world.victory.paused and world.touch_move == 0.0 and not world.touch_guard, "restart clears the finale and held touch inputs")
	_check(world.campaign.stage_index == 0 and world.campaign.phase == "fight" and world.campaign.save_calls == 1, "restart keeps the record while beginning a fresh trial")
	world.free()
	await process_frame
