extends SceneTree
## Read-only behavioral probe: no balance values or production code are edited.
const Combat = preload("res://scripts/combat.gd")
const Campaign = preload("res://scripts/campaign.gd")
var cases: Array = []
func _initialize() -> void: call_deferred("run")
func run_case(label:String, mode:String, phase:int, behavior:String, separation:float=3.3) -> void:
	var game := Combat.new()
	if mode == "legacy": game.start()
	elif mode == "sparring": game.start_sparring()
	else:
		var campaign := Campaign.new()
		game.start_encounter(campaign.stages[-1],campaign.carry)
	game.training = false
	game.player.hp = 100000.0
	game.player.maxHp = 100000.0
	game.player.x = -separation*.5
	game.enemy.x = separation*.5
	game.enemy.phase = phase
	game.enemy.hp = 100000.0
	game.enemy.maxHp = 100000.0
	var attacks: Array = []
	var contacts: Array = []
	var escapes: Array = []
	var hist: Dictionary = {}
	var durations: Dictionary = {}
	var gaps: Array = []
	var last_open := -1.0
	var callback := func(event:Dictionary):
		if event.type == "attack" and event.side == "enemy":
			attacks.append({"at":game.time,"name":event.get("name"),"weapon":event.get("weapon"),"motion":event.get("motion"),"combo":event.get("combo",0),"counter":event.get("counter",false),"distance":absf(game.enemy.x-game.player.x),"windup":event.get("windup"),"duration":event.get("duration")})
		if event.type in ["hit","block","parry"]:
			contacts.append({"at":game.time,"type":event.type,"side":event.get("side"),"target":event.get("targetSide")})
		if event.type in ["dodge","enemyGuard"] and event.get("side","") == "enemy": escapes.append({"at":game.time,"type":event.type})
	game.event.connect(callback)
	var longest_idle := 0.0
	var idle_time := 0.0
	for frame in 60*40:
		var dt := 1.0/60.0
		var movement := 0.0
		if behavior == "mash":
			if absf(game.enemy.x-game.player.x)>1.55: movement = signf(game.enemy.x-game.player.x)
			if frame%5==0: game.action("light")
		game.update(dt,movement,behavior == "hold_guard")
		var state := str(game.enemy.state)
		durations[state] = float(durations.get(state,0.0))+dt
		if state in ["idle","move"]:
			idle_time += dt
			longest_idle = maxf(longest_idle,idle_time)
		else: idle_time=0.0
		if game.ended: break
	for attack:Dictionary in attacks:
		var key := str(attack.weapon)+":"+str(attack.name)
		hist[key] = int(hist.get(key,0))+1
		if int(attack.combo)==0:
			if last_open>=0.0:gaps.append(float(attack.at)-last_open)
			last_open=float(attack.at)
	var sum_gap := 0.0
	var max_gap := 0.0
	for gap:float in gaps:
		sum_gap += gap
		max_gap = maxf(max_gap,gap)
	var result := {"label":label,"mode":mode,"phase":phase,"behavior":behavior,"seconds":game.time,"histogram":hist,
		"wallSeconds":40.0,"fixture":"Player and boss HP raised to 100000 only to prevent early end; native damage, timings, movement and AI unchanged.",
		"enemyHits":contacts.filter(func(item:Dictionary):return item.type=="hit" and item.side=="enemy").size(),
		"playerHits":contacts.filter(func(item:Dictionary):return item.type=="hit" and item.side=="player").size(),
		"attackEvents":attacks.size(),"chainOpenings":gaps.size()+1 if not attacks.is_empty() else 0,"meanOpeningGap":sum_gap/gaps.size() if not gaps.is_empty() else 0.0,
		"maxOpeningGap":max_gap,"longestIdleOrApproach":longest_idle,"statesSeconds":durations,"escapes":escapes,
		"attacks":attacks,"contacts":contacts,"endDistance":absf(game.enemy.x-game.player.x),"endState":game.enemy.state,"endNextRound":game.enemy.get("aiRound",-1),"remainingCooldown":game.enemy.get("aiCooldown",-1)}
	cases.append(result)
	print(JSON.stringify({"case":label,"histogram":hist,"attackEvents":attacks.size(),"meanOpeningGap":result.meanOpeningGap,"maxOpeningGap":max_gap,"idleMax":longest_idle,"states":durations,"endDistance":result.endDistance}))
	game.event.disconnect(callback)
func run() -> void:
	run_case("legacy_idle","legacy",1,"idle")
	for mode:String in ["sparring","final"]:
		for phase:int in [1,2]:
			for behavior:String in ["idle","hold_guard","mash"]:
				run_case(mode+"_p"+str(phase)+"_"+behavior,mode,phase,behavior)
	for separation:float in [1.45,2.0,2.5,3.0,4.2,6.0,12.0]:
		run_case("spacing_"+str(separation),"sparring",1,"idle",separation)
	var report := {"suite":"sentience_aggression_probe","productionEdits":false,"cases":cases,
		"sourceHashes":{"combat":FileAccess.get_file_as_string("res://scripts/combat.gd").sha256_text(),"sentience":FileAccess.get_file_as_string("res://scripts/sentience_combat.gd").sha256_text()}}
	FileAccess.open("res://build/reports/sentience-aggression-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await process_frame
	quit()
