extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Sentience = preload("res://scripts/sentience_combat.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Combat.new()
	game.start_sparring()
	game.enemy.x=1.5
	for next_round in range(1,6):
		if Sentience.weapon_for(game.enemy,next_round)=="chain":
			game.enemy.aiRound=next_round-1
			break
	game.player.x=0.0
	game.player.hp=1000.0
	var log: Array = []
	var callback := func(data:Dictionary):
		if data.type=="parry" or (data.type=="attack" and data.side=="enemy") or (data.type=="hit" and data.side=="enemy"):
			log.append({"type":data.type,"time":game.time,"punishUntil":game.enemy.get("punishUntil"),"motion":data.get("motion","")})
	game.event.connect(callback)
	var guarded:=false
	var parried:=false
	for frame in 60*6:
		if not guarded and game.enemy.state=="attack" and game.enemy.stateTime>=float(game.enemy.attack.windup)-.08:
			guarded=true
		game.update(1.0/60.0,0.0,guarded and not parried)
		if int(game.stats.parries)>0:parried=true
	game.event.disconnect(callback)
	var violations := log.filter(func(item:Dictionary):return item.type=="attack" and float(item.punishUntil)>0.0 and float(item.time)<float(item.punishUntil))
	var report := {"passed":parried and violations.is_empty(),"parried":parried,"violations":violations,"events":log}
	FileAccess.open("res://build/reports/sentience-parry-turn-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	await process_frame
	quit(0 if report.passed else 1)
