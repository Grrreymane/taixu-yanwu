extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Combat=preload("res://scripts/combat.gd")
const STEP:=1.0/120.0
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run()->void:
	var selection:Dictionary=Roster.resolve("fuhua","night_squire","default")
	check(not selection.is_empty(),"playable white-night selection resolves")
	if selection.is_empty():quit(1);return
	var actor=Actor.new();root.add_child(actor);actor.setup(false,selection)
	check(actor.ready_for_combat,"native C3 model and all configured animation libraries load")
	for burst in [false,true]:
		for entry in [["light",0],["light",1],["light",2],["heavy",0],["ability",0]]:
			var game=Combat.new();game.set_player_profile("night_squire");game.set_training(true);game.start()
			game.player.x=-0.55;game.enemy.x=0.55;game.enemy.hp=500.0;game.enemy.maxHp=500.0
			if burst:game.player.nightBurstRemaining=8.0
			var pending:Array=[];var sources:Array=[]
			game.event.connect(func(data):
				if data.type=="hit" and data.side=="player":pending.append(data))
			actor.reset_presentation()
			game._attack(game.player,str(entry[0]),int(entry[1]))
			var motion:String=game.player.attack.motion
			if entry[0]!="ability":check(motion.begins_with("kick_")==burst,"burst flag chooses the correct original A/B clip family")
			check(actor.animation_player.has_animation(actor._prefix+str(actor._motions[motion].clip)),motion+" references an existing original take")
			for frame in 360:
				var previous:float=game.time;game.update(STEP)
				actor.animate_fighter(game.player,game.time-previous,game.time)
				if not pending.is_empty():
					for ignored in pending:sources.append(actor.source_time)
					pending.clear()
				if game.player.state=="idle":break
			if str(entry[0])=="ability":
				check(sources.size()==3,motion+" receives all three native contacts")
				if sources.size()==3:
					for i in 3:check(absf(float(sources[i])-[0.4,0.6,0.833333][i])<0.015,"E hit %d matches its original foot/hand source time"%i)
			else:
				check(sources.size()==1,motion+" has one authoritative melee contact")
				if sources.size()==1:check(absf(float(sources[0])-float(actor._motions[motion].contact))<0.025,motion+" gameplay contact samples its native contact pose")
	var game=Combat.new();game.set_player_profile("night_squire");game.set_training(true);game.start();game.action("ultimate")
	actor.reset_presentation()
	for frame in 120:
		game.update(STEP);actor.animate_fighter(game.player,STEP,game.time,float(game.ultimate.get("time",-1.0)))
	check(actor.current_motion=="ultimate" and absf(actor.source_time-1.0)<0.015,"ND_Ultra activation runs at original speed without cloud-ink timing")
	actor.free()
	var report={"suite":"night_squire_contact","checks":checks,"passed":failures.is_empty(),"failures":failures}
	var file=FileAccess.open("res://build/reports/night-squire-contact.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
