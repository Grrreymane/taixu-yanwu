extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Sentience = preload("res://scripts/sentience_combat.gd")
const Focus = preload("res://scripts/ultimate_focus.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func fixture(tactic: String, interval: float=1.0) -> RefCounted:
	var game := Combat.new()
	game.start_encounter({"playerX":0.0,"encounterRule":{"attackIntervalScale":interval,"turnGapScale":1.0},"enemies":[{"id":"probe","x":1.5,"hp":10000,"type":"striker","tactic":tactic,"weaponLock":"spear" if tactic=="range" else "sword"}]},{"hp":10000,"maxHp":10000})
	# Duel placement centers the pair; spacing probes specify their own close range.
	game.player.x=0.0
	game.enemy.x=1.5
	return game

func _initialize() -> void:
	var ranger = fixture("range")
	ranger._ai_gap=1.0
	ranger.enemy.aiCooldown=1.0
	ranger._encounter_ai(0.1)
	check(ranger.enemy.x>1.5,"ranged carrier steps away during recovery")
	check(ranger.enemy.x>ranger.player.x+Combat.GAP,"ranged carrier preserves lane order")
	var punish = fixture("range")
	punish.enemy.punishUntil=2.0
	punish._ai_gap=1.0
	punish._encounter_ai(0.1)
	check(is_equal_approx(punish.enemy.x,1.5),"ranged retreat cannot steal a parry/posture punish")
	for tactic: String in ["guard","press"]:
		var game = fixture(tactic)
		game.enemy.aiCooldown=0.0; game._ai_gap=0.0
		game._encounter_ai(0.01)
		check(game.enemy.state==("guard" if tactic=="guard" else "attack"),"tactical role changes the actual first response: "+tactic)
		if tactic=="guard": check(game.enemy.parryUntil<0.0,"guard phantom cannot perfect-parry a player's input")
	var timings: Array = []
	var attack_counts: Array[int] = []
	for interval: float in [0.8,1.2]:
		var game = fixture("press",interval)
		var attacks: Array = []
		game.event.connect(func(event: Dictionary):
			if event.type=="attack" and event.side=="enemy": attacks.append(event.duplicate(true)))
		for frame in 2400: game.update(1.0/120.0)
		check(not attacks.is_empty(),"encounter engages without player input")
		if not attacks.is_empty(): timings.append([attacks[0].windup,attacks[0].duration])
		attack_counts.append(attacks.size())
	check(timings.size()==2 and timings[0]==timings[1],"pressure changes recovery, never source strike timing or warning")
	check(attack_counts[0]>attack_counts[1],"pressure rule creates measurably more attacks")
	for scale: float in [0.78,1.12]:
		var relay := Combat.new()
		relay.start_encounter({"playerX":0.0,"encounterRule":{"id":"relay_probe","turnGapScale":scale},"enemies":[{"id":"first","x":1.4,"hp":1000,"weaponLock":"sword"},{"id":"second","x":-1.4,"hp":1000,"weaponLock":"sword"}]})
		relay._sentience_attack(relay.enemies[0],"light",1,false)
		var current: Dictionary=relay.enemies[0]
		current.stateTime=float(current.attack.windup)+float(current.attack.active)+0.25
		relay.enemies[1].aiCooldown=0.0
		relay._ai_gap=0.0
		relay._encounter_ai(0.001)
		check((relay.enemies[1].state=="attack")== (scale<1.0),"relay scale changes the real handoff after a final contact")
	var cycle := ["chain","sword","spear","sword"]
	var guarding_boss = fixture("guard")
	guarding_boss.enemy.boss=true
	guarding_boss.enemy.type="boss"
	guarding_boss.enemy.weaponLock=""
	guarding_boss.enemy.weaponCycle=cycle
	guarding_boss.enemy.aiCooldown=0.0; guarding_boss._ai_gap=0.0
	guarding_boss._encounter_ai(0.01)
	check(guarding_boss.enemy.attack.get("weapon","")=="chain","guard boss still opens with the weapon promised by the briefing")
	guarding_boss._state(guarding_boss.enemy,"idle")
	guarding_boss.enemy.phase=2
	guarding_boss.enemy.aiRound=4
	guarding_boss.enemy.aiCooldown=0.0; guarding_boss._ai_gap=0.0
	guarding_boss._encounter_ai(0.01)
	check(guarding_boss.enemy.state=="attack" and guarding_boss.enemy.attack.get("weapon","")=="burst","guard tactic never consumes the boss's phase-two ultimate turn")
	for phase in [1,2]:
		var boss := {"boss":true,"phase":phase,"weaponCycle":cycle}
		for index in 4: check(Sentience.weapon_for(boss,index+1)==cycle[index],"boss respects this run's original weapon sequence")
		check(Sentience.weapon_for(boss,5)==("burst" if phase==2 else "chain"),"phase-two fifth turn retains the native ultimate")
	for profile: String in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
		var frame := Focus.sample(profile,0.35)
		check(frame.active and frame==Focus.sample(profile,0.35),"presentation holds exactly on a paused clock: "+profile)
		check(not Focus.sample(profile,-1.0).active and not Focus.sample(profile,float(frame.duration)).active,"presentation clears outside the ultimate: "+profile)
	var report := {"checks":checks,"passed":failures.is_empty(),"failures":failures,"attackCounts":attack_counts}
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	FileAccess.open("res://build/reports/encounter-tactics-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
