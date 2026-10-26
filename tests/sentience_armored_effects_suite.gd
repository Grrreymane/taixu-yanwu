extends SceneTree
## Exercise the actual combat event flag, without a renderer or saved profile.
const Combat=preload("res://scripts/combat.gd")
const Effects=preload("res://scripts/sentience_effects.gd")
var checks:=0
var failures:Array[String]=[]
var evidence:Array=[]

func _initialize() -> void:call_deferred("_run")
func _check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _fixture() -> Dictionary:
	var game:=Combat.new()
	game.start_encounter({"playerX":0.0,"training":false,"enemies":[{"id":"boss","boss":true,"hp":400.0,"x":1.3,"weaponLock":"sword"}]})
	game._ai_gap=100.0
	var fx:=Effects.new()
	# Cues are the subject of this test; no textures or GPU resources needed.
	var events:Array=[]
	game.event.connect(func(event:Dictionary):
		events.append(event.duplicate(true))
		fx.handle_event(event)
	)
	game.enemy.adaptiveCounter=true
	game._attack(game.enemy,"light")
	fx.update_fighters(game.player,game.enemies)
	return {"game":game,"fx":fx,"events":events}

func _run() -> void:
	for response:String in ["light","heavy","ability","parry","posture","lethal"]:
		var fixture:=_fixture()
		var game=fixture.game
		var fx=fixture.fx
		_check(game.enemy.attack.get("counter",false) and fx.snapshot().pending==1,response+": real announced counter queues its weapon cue")
		if response=="parry":
			game.action("guard")
			game._receive(game.enemy,game.player,game.enemy.attack)
		else:
			var hit:Dictionary=(Combat.HEAVY if response=="heavy" else Combat.ABILITY if response=="ability" else Combat.LIGHTS[0]).duplicate(true)
			if response=="posture":game.enemy.posture=99.0
			if response=="lethal":hit.damage=1000.0
			game._receive(game.player,game.enemy,hit)
		fx.update_fighters(game.player,game.enemies)
		if response=="light":
			_check(game.enemy.state=="attack" and fixture.events[-1].get("armored",false),"ordinary light hit preserves mechanical native retaliation")
			_check(fx.snapshot().pending==1,"armored health damage preserves the matching swing cue")
			game.enemy.stateTime=float(game.enemy.attack.windup)-0.04
			fx.update_fighters(game.player,game.enemies);fx.tick(0.01)
			_check(fx.snapshot().emittedSwings==1,"preserved cue actually fires at the counter's contact clock")
			fx.tick(0.01)
			_check(fx.snapshot().emittedSwings==1,"retained cue cannot replay its swing")
		else:
			_check(game.enemy.state!="attack",response+": real interrupt cancels the native attack")
			_check(fx.snapshot().pending==0,response+": actual interruption clears its weapon cue")
		evidence.append({"response":response,"state":game.enemy.state,"effects":fx.snapshot(),"events":fixture.events})
		fx.free()
	var report:={"suite":"sentience_armored_effects","checks":checks,"passed":failures.is_empty(),"failures":failures,"gpuUsed":false,"evidence":evidence}
	FileAccess.open("res://build/reports/sentience-armored-effects.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
