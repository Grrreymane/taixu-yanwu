extends SceneTree

const Combat = preload("res://scripts/combat.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const Campaign = preload("res://scripts/campaign.gd")
const STEP := 1.0 / 120.0
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_profiles_and_carry()
	_chains_and_reach()
	_switch_and_cancel()
	_active_counters()
	_enemy_isolation()
	_ultimate_contract()
	print(JSON.stringify({"suite": "fenghuang_combat", "checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func setup(profile: String = "fenghuang", stance: String = "punch"):
	var game = Combat.new()
	game.set_player_profile(profile)
	game.set_training(true)
	game.start()
	if stance == "kick":
		# Select kick through the real E action, with the dummy safely out of reach.
		game.player.x = -4.0
		game.enemy.x = 4.0
		game.action("ability")
		advance(game, 1.6)
	game.player.x = -0.55
	game.enemy.x = 0.55
	return game

func advance(game, seconds: float, guard: bool = false) -> void:
	var left := seconds
	while left > 0.000001:
		var delta := minf(STEP, left)
		game.update(delta, 0.0, guard)
		left -= delta

func until(game, predicate: Callable, limit: float = 4.0, guard: bool = false) -> bool:
	for ignored in ceili(limit / STEP):
		if predicate.call():
			return true
		game.update(STEP, 0.0, guard)
	return bool(predicate.call())

func _profiles_and_carry() -> void:
	var game = Combat.new()
	check(game.player.style == "azure_empyrea", "default profile remains cloud-ink")
	check(not game.set_player_profile("unknown") and game.player_profile == "azure_empyrea", "unsupported profiles cannot replace the current style")
	check(game.set_player_profile("fenghuang"), "the new profile can be selected before battle")
	game.reset()
	check(game.player_profile == "fenghuang" and game.player.style == "fenghuang" and game.player.stance == "punch", "reset retains the profile and begins in fist stance")
	game.start()
	check(game.player.style == "fenghuang" and is_equal_approx(game.player.skillCooldownMax, 1.35), "practice start retains the 1.35-second switch skill")
	check(not game.set_player_profile("azure_empyrea") and game.player.style == "fenghuang", "a live battle cannot swap its combat profile")
	game.reset()
	var carry := {"hp": 63.0, "maxHp": 140.0, "energy": 42.0, "damageMultiplier": 1.16,
		"postureMultiplier": 1.3, "energyGain": 1.25, "skillCooldownScale": 0.82, "parryHeal": 6.0}
	var encounter := {"training": true, "playerX": -0.6,
		"enemies": [{"id": "test_guard", "type": "guardian", "x": 0.6, "hp": 120.0}]}
	game.start_encounter(encounter, carry)
	check(game.player.style == "fenghuang" and game.player.hp == 63.0 and game.player.maxHp == 140.0 and game.player.energy == 42.0, "new encounters preserve style and carried resources")
	check(is_equal_approx(game.player.skillCooldownMax, 1.107) and game.player.skillCooldown == 0.0, "cooldown upgrade scales the new skill's own base duration")
	check(game.player.damageMultiplier == 1.16 and game.player.postureMultiplier == 1.3 and game.player.parryHeal == 6.0, "other trial boons also reach the new profile")
	game.action("ability")
	check(is_equal_approx(game.player.skillCooldown, 1.107), "upgraded E uses the carried cooldown")
	game.reset()
	game.start()
	check(game.player.stance == "punch" and game.player.counterUntil < 0.0 and game.player.skillCooldown == 0.0, "restart clears stance, counter entitlement and cooldown")
	check(is_equal_approx(game.player.skillCooldownMax, 1.35), "new practice does not inherit the old trial's upgrade")
	game.reset()
	check(game.set_player_profile("azure_empyrea"), "returning to cloud-ink remains supported")
	game.start_encounter(encounter, carry)
	check(is_equal_approx(game.player.skillCooldownMax, 6.56), "the same cooldown boon scales cloud-ink's eight-second skill independently")
	game.action("ability")
	check(game.player.attack.damage == 18.0 and game.player.stance == "punch" and not game.player.attack.has("motion"), "cloud-ink E remains its original attack rather than a stance switch")
	for style: Dictionary in Roster.list_styles():
		var profile: String = str(style.combatProfile)
		for skin: Dictionary in Roster.list_appearances("fuhua", str(style.id)):
			var selection: Dictionary = Roster.resolve("fuhua", str(style.id), str(skin.id))
			check(str(selection.actor.combatProfile) == profile, "appearance keeps its style's combat profile: " + str(style.id) + "/" + str(skin.id))
	var campaign = Campaign.new()
	campaign.begin_trial()
	campaign.phase = "reward"
	campaign.reward_options = [Campaign.REWARDS.swift.duplicate(true)]
	check(campaign.choose_reward(0), "the existing cooldown reward can be chosen")
	game.reset()
	game.set_player_profile("fenghuang")
	game.start_encounter(encounter, campaign.carry)
	check(is_equal_approx(game.player.skillCooldownMax, 1.107), "the actual campaign reward reaches the switch skill on the next stage")

func _chains_and_reach() -> void:
	for stance: String in ["punch", "kick"]:
		var game = setup("fenghuang", stance)
		var attacks: Array[Dictionary] = []
		game.event.connect(func(event: Dictionary):
			if event.type == "attack" and event.side == "player": attacks.append(event))
		check(game.action("light"), stance + " begins its first light strike")
		check(game.action("light") and game.player.queuedCombo and game.player.combo==0 and game.player.stateTime==0.0, stance + " accepts an early second press without advancing the current strike")
		advance(game, 0.05)
		check(game.action("light") and game.player.queuedCombo, stance + " buffers the second strike")
		check(until(game, func(): return game.player.state == "attack" and game.player.combo == 1), stance + " advances to strike two")
		advance(game, 0.05)
		check(game.action("light"), stance + " buffers the third strike")
		check(until(game, func(): return game.player.state == "attack" and game.player.combo == 2), stance + " advances to strike three")
		advance(game, 0.05)
		check(not game.action("light"), stance + " has no accidental fourth combo")
		check(until(game, func(): return game.player.state == "idle"), stance + " finishes recovery")
		check(attacks.size() == 3 and attacks[0].combo == 0 and attacks[1].combo == 1 and attacks[2].combo == 2, stance + " emits exactly three ordered attack events")
		check(game.enemy.hp == (76.0 if stance == "punch" else 71.0), stance + " chain applies each hit once")
		game = setup("fenghuang", stance)
		game.action("light")
		advance(game, 0.05)
		game.action("light")
		check(game.action("heavy") and game.player.queuedHeavy and not game.player.queuedCombo, stance + " buffered heavy replaces the next light")
		check(not game.action("light") and game.player.queuedHeavy, stance + " later J cannot overwrite a committed heavy queue")
		check(until(game, func(): return game.player.state == "attack" and game.player.attack.name == "heavy"), stance + " heavy queue actually executes")
		check(game.player.attack.stance == stance, stance + " heavy preserves the current stance")
	var punch = setup()
	var kick = setup("fenghuang", "kick")
	punch.action("light")
	kick.action("light")
	check(kick.player.attack.range > punch.player.attack.range and kick.player.attack.duration > punch.player.attack.duration, "kicks exchange slower recovery for extra reach")
	# At two meters, stance range must change actual collision results, not just UI.
	punch = setup()
	kick = setup("fenghuang", "kick")
	for game in [punch, kick]:
		game.player.x = -1.0
		game.enemy.x = 1.0
		game.action("light")
		advance(game, 0.9)
	check(punch.enemy.hp == 100.0 and kick.enemy.hp == 93.0, "kick first strike reaches a target the fist first strike misses")
	for game in [punch, kick]:
		game.action("heavy")
	check(kick.player.attack.range > punch.player.attack.range and kick.player.attack.duration > punch.player.attack.duration, "heavy kicks also retain their distinct range and recovery")

func _switch_and_cancel() -> void:
	for stance: String in ["punch", "kick"]:
		for defense: String in ["guard", "dodge"]:
			var game = setup("fenghuang", stance)
			game.action("heavy")
			advance(game, 0.05)
			check(not game.action(defense) and game.player.state == "attack", stance + " heavy startup cannot be erased by " + defense)
			check(until(game, func(): return game._can_defend(game.player)), stance + " heavy reaches its cancel window")
			check(game.action(defense) and game.player.state == defense, stance + " recovery accepts " + defense)
	var game = setup()
	var switches: Array[Dictionary] = []
	game.event.connect(func(event: Dictionary):
		if event.type == "stanceChange": switches.append(event))
	game.action("light")
	advance(game, 0.05)
	check(not game.action("ability") and game.player.stance == "punch" and game.player.skillCooldown == 0.0, "E cannot cancel committed startup or spend cooldown on rejection")
	check(until(game, func(): return game._can_defend(game.player)), "light recovery opens the E cancel window")
	check(game.action("ability") and game.player.stance == "kick" and game.player.attack.motion == "switch_kick", "recovery E switches into the native kick transition attack")
	check(is_equal_approx(game.player.skillCooldown, 1.35) and switches.size() == 1, "switch spends its cooldown and emits one stance event")
	var old_time: float = game.time
	var old_hp: float = game.enemy.hp
	check(not game.action("ability") and game.player.stance == "kick", "repeated E cannot switch back immediately")
	check(game.enemy.hp == old_hp and game.time == old_time, "rejected E cannot inflict instant damage or advance time")
	game.action("pause")
	var paused: Dictionary = game.snapshot()
	advance(game, 1.0)
	check(paused == game.snapshot() and not game.action("ability"), "pause freezes the switch attack and cooldown and rejects E")
	game.action("pause")
	check(until(game, func(): return game.player.attack.get("hasHit", false)), "switch attack makes contact after its own windup")
	check(game.enemy.hp == old_hp - 5.0, "switch attack deals only its intended contact damage")
	var cooldown: float = game.player.skillCooldown
	old_time = game.time
	advance(game, 0.025)
	check(game.time == old_time and game.player.skillCooldown == cooldown, "switch contact hitstop freezes its cooldown")
	check(until(game, func(): return game._can_defend(game.player)), "switch attack reaches recovery")
	var before: Dictionary = game.player.duplicate(true)
	check(not game.action("ability") and before == game.player, "E on cooldown does not cancel recovery as a side effect")
	check(game.action("guard") and game.player.state == "guard", "switch recovery remains cancelable into defense")
	advance(game, 1.6)
	check(game.player.skillCooldown == 0.0 and game.action("ability"), "E becomes available again after simulation cooldown")
	check(game.player.stance == "punch" and game.player.attack.motion == "switch_punch" and switches.size() == 2, "the next switch returns through the native fist transition")

func _parry_fixture(stance: String):
	var game = setup("fenghuang", stance)
	game._attack(game.enemy, "light")
	until(game, func(): return game.enemy.stateTime >= game.enemy.attack.windup - 0.05)
	game.action("guard")
	check(until(game, func(): return game.stats.parries == 1, 1.0, true), stance + " fixture reaches a genuine timed parry")
	return game

func _active_counters() -> void:
	for stance: String in ["punch", "kick"]:
		var game = _parry_fixture(stance)
		check(game.enemy.hp == 100.0 and game.stats.damageDealt == 0.0 and game.player.hp == 100.0, stance + " parry grants an opening without automatic HP damage")
		check(is_equal_approx(game.player.counterUntil - game.time, 1.0), stance + " counter entitlement lasts one simulation second")
		advance(game, 0.25, true)
		check(game.enemy.hp == 100.0 and game.player.state == "guard", stance + " waiting after a parry never automatically counterattacks")
		game.action("pause")
		var window: float = game.player.counterUntil - game.time
		advance(game, 1.1, true)
		check(is_equal_approx(game.player.counterUntil - game.time, window), stance + " paused time cannot consume the counter window")
		game.action("pause")
		check(game.action("light") and game.player.attack.get("motion", "") == "counter_" + stance, stance + " requires an explicit J to start its native counter")
		check(game.player.counterUntil < 0.0 and game.enemy.hp == 100.0, stance + " counter token is consumed on input but damage still waits for contact")
		advance(game, 0.14)
		check(game.enemy.hp == 100.0, stance + " counter cannot hit before its windup")
		check(until(game, func(): return game.enemy.hp < 100.0), stance + " counter eventually contacts")
		check(game.enemy.hp == 84.0, stance + " counter applies one sixteen-damage contact")
		until(game, func(): return game.player.state == "idle")
		game.action("light")
		check(not str(game.player.attack.get("motion", "")).begins_with("counter_"), stance + " next J cannot reuse the consumed counter")
		game = _parry_fixture(stance)
		until(game, func(): return game.time > game.player.counterUntil + 0.01, 2.0, true)
		check(game.enemy.hp == 100.0 and game.action("light") and game.player.attack.name == "light" and not game.player.attack.has("motion"), stance + " expired opening returns J to its ordinary first strike")
	var game = _parry_fixture("punch")
	check(game.action("ability"), "a switch input during the parry handoff is accepted")
	until(game, func(): return game.player.state == "attack", 0.4)
	check(game.player.stance == "kick" and game.player.counterUntil < 0.0, "executing the switch consumes the old parry counter entitlement")
	game = setup()
	game.action("guard")
	advance(game, 0.20, true)
	game._attack(game.enemy, "light")
	until(game, func(): return game.player.posture > 0.0, 1.0, true)
	check(game.stats.parries == 0 and game.player.counterUntil < 0.0, "ordinary held block does not grant a counter")
	game = setup("azure_empyrea")
	game._attack(game.enemy, "light")
	until(game, func(): return game.enemy.stateTime >= game.enemy.attack.windup - 0.05)
	game.action("guard")
	until(game, func(): return game.stats.parries == 1, 1.0, true)
	game.action("light")
	until(game, func(): return game.player.state == "attack", 0.4)
	check(game.player.attack.name == "light" and not game.player.attack.has("motion"), "cloud-ink parry retains its ordinary J behavior")

func _enemy_isolation() -> void:
	for type: String in ["legacy", "striker", "guardian", "duelist", "boss"]:
		for kind: String in ["light", "heavy"]:
			var azure = Combat.new()
			var fire = Combat.new()
			fire.set_player_profile("fenghuang")
			for game in [azure, fire]:
				if type == "legacy":
					game.start()
				else:
					game.start_encounter({"training": true, "enemies": [{"id": "enemy", "type": type, "x": 1.0}]})
				game._attack(game.enemy, kind)
			check(azure.enemy.attack == fire.enemy.attack and not fire.enemy.has("stance"), "player profile cannot alter enemy " + type + " " + kind)

func _ultimate_contract() -> void:
	var game = setup()
	game.player.energy = 99.0
	check(not game.action("ultimate") and game.player.energy == 99.0 and game.ultimate.is_empty(), "new Q requires the full 100 SP")
	game.player.energy = 100.0
	var hits: Array[Dictionary] = []
	var end_events: Array[Dictionary] = []
	var observe: Callable = func(event: Dictionary):
		if event.type == "ultHit": hits.append({"cueTime": game.ultimate.time, "event": event.duplicate(true)})
		elif event.type == "ultimateEnd": end_events.append(event)
	game.event.connect(observe)
	check(game.action("ultimate") and game.player.energy == 0.0, "new Q consumes its SP once at start")
	check(is_equal_approx(game.ultimate.duration, 3.8) and is_equal_approx(game.player.stateDuration, 3.8), "new Q uses the 3.8-second combat and presentation duration")
	check(not game.action("ultimate") and not game.action("ability") and not game.action("light"), "Q cannot be retriggered or canceled into ordinary attacks")
	advance(game, 2.09)
	check(game.enemy.hp == 100.0 and hits.is_empty(), "new Q has no premature first hit before 2.10 seconds")
	advance(game, 0.02)
	check(game.enemy.hp == 90.0 and hits.size() == 1 and not hits[0].event.final, "first Q cue applies exactly ten base damage")
	check(float(hits[0].cueTime) >= 2.10 and float(hits[0].cueTime) <= 2.10 + STEP + 0.00001, "first Q contact occurs on the 2.10-second simulation cue")
	game.action("pause")
	var paused: Dictionary = game.snapshot()
	advance(game, 0.8)
	check(paused == game.snapshot() and hits.size() == 1, "pause freezes Q source time, enemies, SP and damage scheduling")
	game.action("pause")
	# Isolate the existing global contact-freeze contract. The cinematic does not
	# manufacture extra hitstop itself, but must honor one if already present.
	game.hit_stop = 0.065
	var frozen_time: float = game.time
	var frozen_cue: float = game.ultimate.time
	var frozen_pose_time: float = game.player.stateTime
	advance(game, 0.025)
	check(game.time == frozen_time and game.ultimate.time == frozen_cue and game.player.stateTime == frozen_pose_time and hits.size() == 1, "global hitstop also freezes the new Q clock and cue progression")
	check(until(game, func(): return game.ultimate.time >= 2.81), "Q continues after the contact freeze")
	check(game.enemy.hp == 90.0 and hits.size() == 1, "second Q hit does not arrive before 2.82 seconds")
	advance(game, 0.02)
	check(game.enemy.hp == 60.0 and hits.size() == 2 and hits[1].event.final, "second Q cue adds exactly thirty base damage")
	check(float(hits[1].cueTime) >= 2.82 and float(hits[1].cueTime) <= 2.82 + STEP + 0.00001, "second Q contact occurs on the 2.82-second simulation cue")
	check(game.stats.damageDealt == 40.0 and game.combo_count == 2 and not game.ultimate.is_empty(), "two Q cues total forty damage and preserve the remaining follow-through")
	check(until(game, func(): return game.ultimate.is_empty(), 2.0), "Q returns control at the end of the sequence")
	check(game.player.state == "idle" and not game.ended and end_events.size() == 1 and hits.size() == 2, "surviving target resumes battle after one Q-end event")
	advance(game, 0.5)
	check(game.enemy.hp == 60.0 and hits.size() == 2 and end_events.size() == 1, "completed Q cannot repeat either cue on later frames")
	game.event.disconnect(observe)
	game = setup("fenghuang", "kick")
	game.player.damageMultiplier = 1.16
	game.action("ultimate")
	advance(game, 3.9)
	check(is_equal_approx(game.enemy.hp, 53.6) and is_equal_approx(game.stats.damageDealt, 46.4), "both Q hits receive the trial damage multiplier")
	check(game.player.stance == "kick" and game.player.state == "idle", "Q returns to the previous stance instead of resetting to fists")
	for initial_hp in [5.0, 40.0]:
		game = setup()
		game.enemy.hp = initial_hp
		game.action("ultimate")
		advance(game, 2.12 if initial_hp == 5.0 else 2.84)
		check(game.enemy.hp == 0.0 and not game.ended and not game.ultimate.is_empty(), "lethal Q hit waits for the finale before victory, initial HP %.0f" % initial_hp)
		check(is_equal_approx(game.stats.damageDealt, initial_hp) and game.stats.kills == 1, "lethal Q caps damage and counts one defeat, initial HP %.0f" % initial_hp)
		until(game, func(): return game.ultimate.is_empty(), 2.0)
		check(game.ended and game.winner == "player" and game.time >= 3.8, "Q declares victory only after 3.8 seconds, initial HP %.0f" % initial_hp)
	game = Combat.new()
	game.set_player_profile("fenghuang")
	game.start_encounter({"training": true, "playerX": -1.0, "enemies": [
		{"id": "weak", "x": 0.4, "hp": 5.0}, {"id": "medium", "x": 1.6, "hp": 25.0}, {"id": "healthy", "x": 3.0, "hp": 100.0}]},
		{"energy": 100.0, "damageMultiplier": 1.5})
	game.action("ultimate")
	advance(game, 3.9)
	check(game.enemies[0].hp == 0.0 and game.enemies[1].hp == 0.0 and game.enemies[2].hp == 40.0, "each Q cue reaches all living encounter targets and skips already defeated ones")
	check(game.stats.damageDealt == 90.0 and game.stats.kills == 2 and not game.ended, "multi-target Q counts capped damage and kills without ending a live encounter")
