extends SceneTree

const Roster = preload("res://scripts/fighter_roster.gd")
var checks := 0
var failures: Array[String] = []
var pending_styles: Array[String] = []
var storage_dir := ""
var original_storage_dir := ""
var original_preferences_hash := ""
var Main

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _isolate_storage() -> bool:
	original_storage_dir = OS.get_user_data_dir()
	var original_file := original_storage_dir.path_join("fighter-preferences.cfg")
	original_preferences_hash = FileAccess.get_sha256(original_file) if FileAccess.file_exists(original_file) else "absent"
	var token := "TaixuSelectionSuite/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", token)
	storage_dir = OS.get_user_data_dir()
	var isolated := storage_dir != original_storage_dir and "TaixuSelectionSuite" in storage_dir and ProjectSettings.globalize_path("user://fighter-preferences.cfg").begins_with(storage_dir)
	_check(isolated, "all user:// settings are redirected to a unique test-only directory before main is instantiated")
	if isolated:
		_check(DirAccess.make_dir_recursive_absolute(storage_dir) == OK, "the isolated test directory can be created")
	return isolated

func _new_world():
	var world = Main.new()
	root.add_child(world)
	world.set_process(false)
	world._process(0.0)
	_check(world.ready_to_play and world.player.ready_for_combat, "real main creates a ready actor from the selected catalog entry")
	return world

func _dispose(world) -> void:
	world.queue_free()
	await process_frame
	await process_frame

func _identity(world) -> Array:
	return [world.fighter.characterId, world.fighter.styleId, world.fighter.appearanceId]

func _frames(world, count: int, delta: float = 1.0 / 30.0) -> void:
	for ignored in count: world._process(delta)

func _body_vertex_count(actor) -> int:
	var body := actor.model.find_child("Body", true, false) as MeshInstance3D
	if body == null: return 0
	var count := 0
	for surface in body.mesh.get_surface_count(): count += body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
	return count

func _recipe(world) -> Dictionary:
	world._action("practice")
	world._action("ability")
	return {"profile": world.game.player_profile, "cooldown": world.game.player.skillCooldownMax,
		"attack": world.game.player.attack.duplicate(true), "motions": world.player._motions.duplicate(true)}

func _win_normally(world) -> bool:
	world._action("practice")
	if not world.game.training: world._action("training")
	# A normal T toggle only disables enemy AI. No HP, damage, winner or phase is injected.
	for frame in 1200:
		if world.campaign.phase == "cleared": return true
		if world.campaign.phase == "failed": return false
		if not world.game.ended and world.game.ultimate.is_empty():
			var p: Dictionary = world.game.player
			var e: Dictionary = world.game.enemy
			var distance := absf(float(e.x) - float(p.x))
			world._js_action(["move", signf(float(e.x)-float(p.x)) if distance > 1.25 else 0.0])
			if p.state in ["idle", "move", "guard"]:
				if p.energy >= 100.0 and distance < 2.2: world._action("ultimate")
				elif p.skillCooldown <= 0.0 and distance < 2.5: world._action("ability")
				elif distance < 1.7: world._action("light")
			elif p.state == "attack" and p.attack.get("name", "") == "light" and p.stateTime > 0.1:
				world._action("light")
		world._process(1.0 / 30.0)
	world._js_action(["move", 0.0])
	return false

func _run() -> void:
	if not _isolate_storage():
		_finish()
		return
	Main = load("res://scripts/main.gd")
	_check(Main != null and Main.can_instantiate(), "main and current selection HUD parse")
	if Main == null or not Main.can_instantiate():
		_finish()
		return
	var skin := Roster.resolve("fuhua", "azure_empyrea", "taixu_memory")
	_check(not skin.is_empty(), "the requested real Azure Empyrea skin is registered")
	if skin.is_empty():
		_finish()
		return
	var world = _new_world()
	_check(world._roster_snapshot().styles.map(func(style): return str(style.id)) == ["azure_empyrea", "fenghuang", "night_squire"], "the normal menu exposes exactly Azure Empyrea, Phoenix and Night Squire")
	_check(_identity(world) == ["fuhua", "azure_empyrea", "default"], "a clean isolated install starts with the catalog default")
	_check(world._roster_snapshot().canSelect, "menu exposes selection availability")
	var default_vertices := _body_vertex_count(world.player)
	var default_recipe := _recipe(world)
	world._action("menu")
	var old_actor = world.player
	var old_instance: int = old_actor.get_instance_id()
	world._action("select_appearance:taixu_memory")
	_check(world.player.get_instance_id() != old_instance and old_actor.is_queued_for_deletion() and not old_actor.visible, "menu skin selection replaces and hides the old actor immediately")
	_check(world.player._profile.modelPath == skin.actor.modelPath and _body_vertex_count(world.player) != default_vertices, "selection loads genuinely different body geometry")
	_check(_identity(world) == ["fuhua", "azure_empyrea", "taixu_memory"], "the selected skin becomes the active runtime identity")
	await process_frame
	await process_frame
	_check(not is_instance_valid(old_actor), "the previous actor is actually freed after the queued deletion")
	var skin_instance: int = world.player.get_instance_id()
	world._action("select_appearance:taixu_memory")
	_check(world.player.get_instance_id() == skin_instance, "reselecting the same skin does not reload the actor")
	for command in ["select_style:invalid_style", "select_appearance:invalid_skin", "select_style:../../unexpected"]:
		world._action(command)
		_check(world.player.get_instance_id() == skin_instance and world.fighter.appearanceId == "taixu_memory", "invalid selection is rejected without replacing the current actor: " + command)
	var skin_recipe := _recipe(world)
	_check(skin_recipe == default_recipe, "a cosmetic skin preserves the exact E recipe, cooldown and motion sampling")
	_check(world.game.player_profile == "azure_empyrea" and world.game.player.skillCooldownMax == 8.0, "Azure Empyrea's combat profile and eight-second E cooldown remain synchronized")
	world._action("select_appearance:default")
	world._action("select_style:fenghuang")
	_check(world.fighter.appearanceId == "taixu_memory" and world.player.get_instance_id() == skin_instance and not world._roster_snapshot().canSelect, "combat rejects skin and style changes")
	world._action("pause")
	world._action("select_appearance:default")
	_check(world.game.paused and world.fighter.appearanceId == "taixu_memory" and world.player.get_instance_id() == skin_instance, "pausing a fight does not make selection available")
	world._action("pause")
	for command in ["restart", "menu", "practice"]:
		world._action(command)
		_check(world.fighter.appearanceId == "taixu_memory" and world.player.get_instance_id() == skin_instance and world.game.player_profile == "azure_empyrea", "normal flow keeps the selected skin: " + command)
	world.game.reset()
	_check(world.fighter.appearanceId == "taixu_memory" and world.game.player_profile == "azure_empyrea", "combat reset keeps the active visual choice and profile")
	var won := _win_normally(world)
	_check(won and world.victory.visible and world.game.winner == "player", "normal practice inputs reach the real victory presentation")
	if won:
		_check(world.fighter.appearanceId == "taixu_memory" and world.player.get_instance_id() == skin_instance, "victory retains the selected actor")
		_check(world.player.presentation_snapshot().victoryAvailable and world.player.animation_player.has_animation("presentation/Victory"), "the new skin uses its embedded native victory library")
		world._action("select_appearance:default")
		_check(world.fighter.appearanceId == "taixu_memory", "result and victory phases reject selection too")
		world._action("victory_skip")
		world._action("victory_replay")
		_check(world.fighter.appearanceId == "taixu_memory" and world.victory.playing(), "victory replay preserves the skin")
	world._action("menu")
	await _style_switches(world)
	# Persist a nondefault appearance and recreate main, including its actor.
	world._action("select_style:azure_empyrea")
	world._action("select_appearance:taixu_memory")
	world._save_fighter_choice()
	var expected_choices: Dictionary = world.appearance_choices.duplicate(true)
	var saved := ConfigFile.new()
	_check(saved.load("user://fighter-preferences.cfg") == OK and saved.get_value("fighter", "appearance", "") == "taixu_memory", "selection is written to the isolated preference file")
	_check(saved.get_value("fighter", "appearances", {}) == expected_choices, "the saved file includes each style's appearance preference")
	await _dispose(world)
	world = _new_world()
	_check(world.fighter.appearanceId == "taixu_memory" and world.player._profile.modelPath == skin.actor.modelPath, "recreating main restores the selected skin and its real model")
	_check(world.appearance_choices == expected_choices, "recreating main restores the per-style appearance map")
	await _dispose(world)
	# Corrupt data is contained in this process's unique user:// directory.
	var stale := ConfigFile.new()
	stale.set_value("fighter", "style", "missing_style")
	stale.set_value("fighter", "appearance", "missing_skin")
	stale.set_value("fighter", "appearances", {"azure_empyrea": "taixu_memory", "missing_style": "default", "fenghuang": "not_a_skin"})
	stale.save("user://fighter-preferences.cfg")
	world = _new_world()
	_check(_identity(world) == ["fuhua", "azure_empyrea", "default"], "stale invalid current IDs fall back to the default playable selection")
	_check(not world.appearance_choices.has("missing_style") and not world.appearance_choices.has("fenghuang"), "invalid remembered styles and skins are removed on load")
	world._action("select_appearance:taixu_memory")
	var broken := FileAccess.open("user://fighter-preferences.cfg", FileAccess.WRITE)
	broken.store_string("[fighter\nstyle = @broken"); broken.close()
	print("EXPECTED_CONFIG_PARSE_ERROR: the next load checks corrupted-file fallback")
	world._load_fighter_choice()
	_check(_identity(world) == ["fuhua", "azure_empyrea", "default"], "a malformed file cannot retain a previous nondefault selection during reload")
	await _dispose(world)
	world = _new_world()
	_check(_identity(world) == ["fuhua", "azure_empyrea", "default"] and world.player._profile.modelPath == Roster.MODEL_PATH, "a corrupt file on fresh startup still produces a working default actor")
	await _dispose(world)
	_finish()

func _style_switches(world) -> void:
	var phoenix := Roster.resolve("fuhua", "fenghuang")
	if phoenix.is_empty():
		pending_styles.append("fenghuang")
		if "--require-fenghuang" in OS.get_cmdline_user_args(): _check(false, "Fenghuang is not ready, so style switching and its runtime profile remain unverified")
		return
	var previous_actor = world.player
	world._action("select_style:fenghuang")
	_check(world.fighter.styleId == "fenghuang" and world.player._profile.modelPath == phoenix.actor.modelPath, "menu style switching loads the actual Fenghuang model")
	_check(world.game.player_profile == "fenghuang" and world.game.player.style == "fenghuang", "the style change synchronizes both combat profile identifiers")
	var FenghuangCombat = load("res://scripts/fenghuang_combat.gd")
	_check(is_equal_approx(world.game.player.skillCooldownMax, FenghuangCombat.SWITCH_COOLDOWN), "Fenghuang's E cooldown is taken from its own combat profile")
	await process_frame
	await process_frame
	_check(not is_instance_valid(previous_actor), "switching styles frees the previous skin actor")
	world._action("practice")
	world._action("ability")
	_check(world.game.player.stance == "kick" and is_equal_approx(world.game.player.skillCooldown, FenghuangCombat.SWITCH_COOLDOWN), "Fenghuang E activates its real stance switch and cooldown")
	var phoenix_instance: int = world.player.get_instance_id()
	world._action("restart")
	world.game.reset()
	_check(world.fighter.styleId == "fenghuang" and world.player.get_instance_id() == phoenix_instance and world.game.player_profile == "fenghuang", "restart and combat reset retain Phoenix's selected actor and combat profile")
	var won := _win_normally(world)
	_check(won and world.victory.visible and world.game.winner == "player", "normal Phoenix practice inputs reach its own victory presentation")
	if won:
		_check(world.fighter.styleId == "fenghuang" and world.player.get_instance_id() == phoenix_instance and world.player.presentation_snapshot().victoryAvailable, "Phoenix victory retains the selected actor and an available native victory clip")
		_check(world.player._victory_prefix == phoenix.actor.prefix and world.player.animation_player.has_animation(phoenix.actor.prefix + str(phoenix.actor.victory.clip)), "Phoenix victory uses its original C4 clip rather than the Azure library")
	world._action("menu")
	world._action("select_style:azure_empyrea")
	_check(world.fighter.appearanceId == "taixu_memory" and world.game.player_profile == "azure_empyrea" and world.game.player.skillCooldownMax == 8.0, "returning to Azure Empyrea restores its skin preference and original cooldown")
	world._action("select_style:fenghuang")
	_check(world.fighter.appearanceId == "default", "Fenghuang separately remembers its own default appearance")
	world._save_fighter_choice()
	var loaded = _new_world()
	_check(loaded.fighter.styleId == "fenghuang" and loaded.appearance_choices.get("azure_empyrea", "") == "taixu_memory", "saved Fenghuang selection retains Azure Empyrea's different remembered skin")
	# Run Main's real lifecycle so newly added presentation nodes are parented
	# and released normally, rather than leaking pre-ready orphan objects.
	await _dispose(loaded)
	world._action("select_style:azure_empyrea")

func _finish() -> void:
	if not original_storage_dir.is_empty():
		var original_file := original_storage_dir.path_join("fighter-preferences.cfg")
		var after := FileAccess.get_sha256(original_file) if FileAccess.file_exists(original_file) else "absent"
		_check(after == original_preferences_hash, "the actual user's preference file is unchanged")
	var report := {"suite": "roster_selection", "checks": checks, "failures": failures, "passed": failures.is_empty(), "pendingStyles": pending_styles, "requestedRosterComplete": pending_styles.is_empty(), "isolatedUserDirectory": storage_dir, "gpuUsed": false, "browserUsed": false}
	var output := FileAccess.open("res://build/roster-selection-report.json", FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report, "  ")); output.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
