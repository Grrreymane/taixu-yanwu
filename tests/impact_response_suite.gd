extends SceneTree
## Headless action contracts plus the actual Main camera projection, not its
## internal strength number. Fixtures never load models or write preferences.
const Combat = preload("res://scripts/combat.gd")
const BattleCamera = preload("res://scripts/battle_camera.gd")
const STEP := 1.0/120.0
const COMMANDS := ["light","heavy","ability","ultimate","dodge"]

class ErrorRecorder extends Logger:
	var errors: Array[Dictionary] = []
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type})
	func _log_message(_message: String,_error: bool) -> void: pass

class CameraMain extends "res://scripts/main.gd":
	func _ready() -> void:
		# This isolated camera fixture never enters Music._ready(), which normally
		# parents its two eagerly allocated crossfade players. Free both orphans.
		music._player.free()
		music._previous_player.free()
		music.free()
		music=null
		add_child(camera)
		camera.current=true
		add_child(combat_accent)
	func _process(_delta: float) -> void: pass
	func _input(_event: InputEvent) -> void: pass

var checks := 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {"chains":[],"enemyWarnings":[],"buffers":[],"deadImpulses":[],"camera":[]}
var recorder := ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		print("CHECK FAILED: ",label)

func _run() -> void:
	OS.add_logger(recorder)
	_chains()
	_buffers()
	_dead_impulses()
	await _camera_projection()
	_check(completed==["chains","buffers","dead","camera"],"all four independent sections reached completion")
	_check(observations.chains.size()==9 and observations.enemyWarnings.size()==12 and observations.buffers.size()==15 and observations.deadImpulses.size()==4 and observations.camera.size()==4,"every expected scenario produced a complete observation")
	_check(recorder.errors.is_empty(),"no engine or script errors were hidden by a nested-method early exit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var report: Dictionary={"suite":"impact_response","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors,"completed":completed,"observations":observations}
	var file:=FileAccess.open("res://build/reports/impact-response-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	OS.remove_logger(recorder)
	print(JSON.stringify({"suite":"impact_response","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors.size(),"completed":completed}))
	quit(0 if failures.is_empty() else 1)

func _fixture(profile: String="azure_empyrea",stance: String="punch"):
	var game=Combat.new()
	game.set_player_profile(profile)
	game.set_training(true)
	game.start()
	game.player.stance=stance
	game.player.x=-0.6
	game.enemy.x=0.6
	return game

func _advance(game,seconds: float) -> void:
	var remaining:=seconds
	while remaining>0.000001:
		var step:=minf(STEP,remaining)
		game.update(step)
		remaining-=step

func _until(game,predicate: Callable,seconds: float=3.0) -> bool:
	for frame in ceili(seconds/STEP):
		if predicate.call(): return true
		game.update(STEP)
	return bool(predicate.call())

func _watch(game) -> Array[Dictionary]:
	var events: Array[Dictionary]=[]
	game.event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	return events

func _events(events: Array[Dictionary],kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	for event: Dictionary in events:
		if event.type==kind and event.get("side","")=="player": found.append(event)
	return found

func _free_fixture_orphans(owner: Node) -> void:
	# CameraMain intentionally bypasses Main._ready(). Its eagerly allocated
	# presentation nodes (and their not-yet-parented controls) still need a
	# lifecycle even though this test must not open menus, audio or models.
	for property in owner.get_property_list():
		if not int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:continue
		var value=owner.get(property.name)
		if value is Node and is_instance_valid(value) and value!=owner and value.get_parent()==null:
			_free_fixture_orphans(value)
			value.free()

func _chains() -> void:
	for variant: Array in [["azure_empyrea","punch"],["fenghuang","punch"],["fenghuang","kick"]]:
		for outcome: String in ["hit","block","whiff"]:
			var game=_fixture(variant[0],variant[1])
			var label:=str(variant[0])+"/"+str(variant[1])+"/"+outcome
			if outcome=="block":
				game._state(game.enemy,"guard",20.0)
				game.enemy.parryUntil=-1.0
			elif outcome=="whiff":
				game.player.x=-3.0
				game.enemy.x=4.5
			var base=_fixture(variant[0],variant[1])
			base._attack(base.player,"light",2)
			var original_finisher_windup: float=base.player.attack.windup
			var events:=_watch(game)
			game.action("light")
			_advance(game,0.05)
			_check(game.action("light"),label+": second light input queues")
			var queued_third:=false
			var gaps: Array[Dictionary]=[]
			var hit_wall_times: Array[float]=[]
			for frame in 600:
				game.update(STEP)
				if game.player.state=="attack" and game.player.combo==1 and game.player.stateTime>=0.05 and not queued_third:
					queued_third=game.action("light")
				var hits:=_events(events,"hit")
				if hits.size()>hit_wall_times.size(): hit_wall_times.append(0.05+float(frame+1)*STEP)
				if outcome=="hit" and hits.size()>0 and hits.size()<3 and game.enemy.state!="stagger":
					gaps.append({"time":game.time,"enemyState":game.enemy.state,"hitCount":hits.size()})
				if _events(events,"attack").size()==3 and game.player.state=="idle": break
			var attacks:=_events(events,"attack")
			_check(attacks.size()==3 and queued_third,label+": exactly three attacks execute once")
			if attacks.size()==3:
				for index in 2:
					var interval: float=float(attacks[index+1].time)-float(attacks[index].time)
					if outcome=="whiff": _check(interval>=float(attacks[index].duration)-STEP,label+": a missed swing never gains early recovery cancel")
					else: _check(interval<float(attacks[index].duration)-STEP,label+": confirmed contact links before the old full duration")
				_check(float(attacks[2].windup)<original_finisher_windup if outcome=="hit" else is_equal_approx(float(attacks[2].windup),original_finisher_windup),label+": only a real previous hit shortens finisher startup, including its event payload")
			if outcome=="hit":
				_check(_events(events,"hit").size()==3 and gaps.is_empty(),label+": target remains staggered continuously between all three contacts")
			elif outcome=="whiff": _check(game.enemy.hp==100.0 and _events(events,"hit").is_empty(),label+": empty swings create no damage")
			observations.chains.append({"case":label,"attacks":attacks,"hits":_events(events,"hit"),"hitWallTimes":hit_wall_times,"staggerGaps":gaps})
		_native_enemy_warnings(variant)
	completed.append("chains")

func _native_enemy_warnings(variant: Array) -> void:
	# The opponent now uses complete original C6 weapon kits. A legacy
	# _attack(enemy,"heavy") request does not turn a spear into the old generic
	# .94s heavy template. Verify the actual warning/contact contract instead.
	for spec: Array in [["sword",0,"light","senti_sword_1",false],["spear",0,"light","senti_spear_1",false],["chain",0,"heavy","senti_chain_1",false],["chain",1,"heavy","senti_chain_2",true]]:
		var game=_fixture(variant[0],variant[1])
		game.enemy.weaponLock=spec[0]
		game.enemy.weapon=spec[0] # A native continuation preserves its weapon.
		var events:=_watch(game)
		var label:=str(variant)+"/"+str(spec[3])
		var initial_hp:float=game.player.hp
		game._attack(game.enemy,spec[2],spec[1])
		var attack:Dictionary=game.enemy.attack.duplicate(true)
		var warnings=events.filter(func(event:Dictionary):return event.type=="attack" and event.get("side","")=="enemy")
		_check(warnings.size()==1,label+": one warning precedes the native attack")
		if warnings.size()!=1:continue
		var warning:Dictionary=warnings[0]
		_check(warning.motion==spec[3] and warning.weapon==spec[0] and warning.name==spec[2],label+": warning identifies the actual native contact type")
		_check(warning.telegraph and warning.unblockable==spec[4] and warning.telegraphColor==("red" if spec[4] else "amber"),label+": amber/red warning communicates the actual defensive rule")
		_check(attack.windup>0.0 and attack.windup+attack.active<=attack.duration and is_equal_approx(float(warning.windup),float(attack.windup)),label+": warning exposes the whole real preparation interval")
		_check(game.player.hp==initial_hp and not attack.hasHit,label+": announcing an attack causes no damage")
		_advance(game,float(attack.windup)-STEP*0.5)
		var contacts=events.filter(func(event:Dictionary):return event.type=="hit" and event.get("side","")=="enemy")
		_check(game.enemy.state=="attack" and game.enemy.stateTime<attack.windup and game.player.hp==initial_hp and contacts.is_empty(),label+": no damage anywhere before the announced contact")
		_advance(game,STEP)
		contacts=events.filter(func(event:Dictionary):return event.type=="hit" and event.get("side","")=="enemy")
		_check(contacts.size()==1 and game.player.hp<initial_hp,label+": in-range native strike hits when its warning expires")
		if contacts.size()==1:
			var elapsed:float=float(contacts[0].time)-float(warning.time)
			_check(elapsed>=float(warning.windup)-0.00001 and elapsed<=float(warning.windup)+STEP,label+": first damage lands at the advertised time within one simulation tick")
			_check(contacts[0].get("targetSide","")=="player",label+": real contact identifies its player target")
		observations.enemyWarnings.append({"case":label,"warning":warning,"attack":attack,"contacts":contacts,"initialHp":initial_hp,"contactHp":game.player.hp})

func _tail_fixture(state: String="dodge"):
	var game=_fixture()
	if state=="dodge": game.action("dodge")
	elif state=="attack":
		game.player.x=-3.0
		game.enemy.x=4.5
		game.action("heavy")
	else: game._state(game.player,"stagger",0.4)
	_advance(game,game.player.stateDuration-0.08)
	game.player.nextDodgeAt=0.0 # Test the buffer, not the independent cooldown.
	return game

func _command_count(events: Array[Dictionary],command: String) -> int:
	var count:=0
	for event: Dictionary in events:
		if event.get("side","")!="player" and event.type!="ultimate": continue
		if command in ["light","heavy","ability"] and event.type=="attack" and event.name==command: count+=1
		elif command=="ultimate" and event.type=="ultimate": count+=1
		elif command=="dodge" and event.type=="dodge": count+=1
	return count

func _buffers() -> void:
	for state: String in ["dodge","stagger","attack"]:
		for command: String in COMMANDS:
			var game=_tail_fixture(state)
			var events:=_watch(game)
			var recovery_at: float=game.time+game.player.stateDuration-game.player.stateTime
			if state=="attack" and command=="dodge":
				# Existing deliberate defense cancels remain legal before full
				# recovery; buffering must not delay this responsive input.
				_check(game.action(command) and game.player.state=="dodge","heavy recovery retains its immediate legal dodge cancel")
				var consumed_at: float=game.time
				_advance(game,1.8)
				_check(_command_count(events,command)==1,"immediate defense cancel does not also leave a queued duplicate")
				observations.buffers.append({"state":state,"command":command,"recoveryAt":recovery_at,"consumedAt":consumed_at,"count":_command_count(events,command),"defenseCancel":true})
				continue
			_check(game.action(command),state+" tail accepts "+command+" into the short buffer")
			_check(game.player.state==state and _command_count(events,command)==0,state+" buffered "+command+" cannot erase the remaining committed action")
			_advance(game,0.05)
			_check(_command_count(events,command)==0,state+" buffered "+command+" waits until recovery")
			_check(_until(game,func(): return _command_count(events,command)>0,0.15),state+" buffered "+command+" executes on first legal recovery")
			var consumed_at: float=game.time
			_check(consumed_at>=recovery_at-STEP and consumed_at<=recovery_at+STEP*2.0,state+" buffered "+command+" is not delayed by an idle frame")
			_advance(game,1.8)
			_check(_command_count(events,command)==1,state+" buffered "+command+" consumes exactly once")
			observations.buffers.append({"state":state,"command":command,"recoveryAt":recovery_at,"consumedAt":consumed_at,"count":_command_count(events,command)})
	for command: String in COMMANDS:
		var early=_fixture()
		early.action("dodge")
		_advance(early,0.15)
		early.player.nextDodgeAt=0.0
		var events:=_watch(early)
		_check(not early.action(command),"too-early "+command+" input is not retained indefinitely")
		_advance(early,1.6)
		_check(_command_count(events,command)==0,"too-early "+command+" never auto-executes later")
	for cancellation: String in ["pause","reset","hit"]:
		var game=_tail_fixture()
		var events:=_watch(game)
		_check(game.action("heavy"),cancellation+": fixture queues an attack")
		if cancellation=="pause":
			game.action("pause")
			var frozen: float=game.time
			_advance(game,0.3)
			_check(game.time==frozen,"pause freezes simulation while clearing pending input")
			game.action("pause")
		elif cancellation=="reset": game.start()
		else:
			var strike: Dictionary=Combat.LIGHTS[0].duplicate(true)
			strike.stun=0.04 # Would recover within the old buffer's lifetime.
			game._receive(game.enemy,game.player,strike)
		_advance(game,1.5)
		_check(_command_count(events,"heavy")==0,cancellation+" clears the old buffered attack")
	for unavailable: String in ["ability","ultimate","dodge"]:
		var game=_tail_fixture()
		if unavailable=="ability": game.player.skillCooldown=2.0
		elif unavailable=="ultimate": game.player.energy=0.0
		else: game.player.nextDodgeAt=game.time+2.0
		var events:=_watch(game)
		game.action(unavailable)
		_advance(game,2.5)
		_check(_command_count(events,unavailable)==0,"buffer cannot bypass or outlive "+unavailable+" resource/cooldown requirements")
	for excluded: String in ["guard","training","unknown"]:
		var game=_tail_fixture()
		_check(not game.action(excluded),"short buffer rejects non-bufferable command "+excluded)
		_advance(game,0.5)
		_check(game.player.state=="idle","excluded "+excluded+" leaves no delayed action")
	completed.append("buffers")

func _dead_impulses() -> void:
	for facing in [-1.0,1.0]:
		for edge in [false,true]:
			var game=_fixture()
			game.player.x=facing*(4.0 if edge else -0.6)
			game.enemy.x=facing*(5.45 if edge else 0.6)
			game.player.facing=facing
			game.enemy.hp=1.0
			var events:=_watch(game)
			game.action("heavy")
			_check(_until(game,func(): return game.ended),"lethal heavy reaches its final contact")
			var x: float=game.enemy.x
			var clock: float=game.time
			var stats: Dictionary=game.stats.duplicate(true)
			_advance(game,0.025)
			_check(game.hit_stop>0.0 and is_equal_approx(float(game.enemy.x),x),"dead target stays planted through contact hitstop")
			_advance(game,0.65)
			_check((game.enemy.x-x)*facing>0.01,"dead target carries the strike after hitstop")
			_check(absf(float(game.enemy.x))<=Combat.LIMIT and absf(float(game.player.x))<=Combat.LIMIT,"dead impulse never crosses the arena edge")
			_check(game.time==clock and game.stats==stats,"post-finish impulse does not resume time or count score/damage twice")
			_check(events.filter(func(event: Dictionary): return event.type=="end").size()==1,"death impulse emits no duplicate result")
			observations.deadImpulses.append({"facing":facing,"edge":edge,"contactX":x,"finalX":game.enemy.x,"time":game.time,"stats":game.stats})
	completed.append("dead")

func _camera_projection() -> void:
	root.content_scale_size=Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1440,900)
	var main=CameraMain.new()
	root.add_child(main)
	main.set_process(false)
	main.campaign.phase="fight"
	main.game=_fixture()
	await process_frame
	var framing: Dictionary=BattleCamera.frame(main.game.player.x,[main.game.enemy.x],1.6)
	for strong in [false,true]:
		for delta in [1.0/60.0,0.05]:
			main.camera_base=framing.position
			main.menu_target=framing.target
			main.impact_strength=0.0
			main.impact_age=1.0
			main.combat_accent.clear()
			main._camera(0.0,0.0,-1.0)
			var contact:=Vector3(0.0,1.33,0.35)
			var before: Vector2=main.camera.unproject_position(contact)
			main._event({"type":"hit","side":"player","targetSide":"enemy","targetId":"test","heavy":strong,"facing":1.0,"contactX":0.0})
			_check(is_equal_approx(float(main.impact_strength),0.075 if strong else 0.035),"real hit event supplies the revised camera strength")
			main._camera(delta,delta,-1.0)
			var after: Vector2=main.camera.unproject_position(contact)
			var displacement:=after-before
			_check(absf(displacement.x)>3.0 and absf(displacement.x)<20.0,"confirmed contact causes bounded visible screen-space displacement")
			var maximum: float=main.impact_strength
			_check(is_equal_approx(float(main.shake),maximum),"first impact frame is presented at age zero even on a 50ms frame")
			var paused_transform: Transform3D=main.camera.transform
			var paused_fov: float=main.camera.fov
			var paused_age: float=main.impact_age
			for tick in 8: main._camera(delta,0.0,-1.0)
			_check(main.camera.transform.is_equal_approx(paused_transform) and main.camera.fov==paused_fov and main.impact_age==paused_age,"paused impact camera transform, FOV and clock stay fixed")
			observations.camera.append({"heavy":strong,"frameDelta":delta,"screenDisplacement":[displacement.x,displacement.y],"firstFrameStrength":main.shake})
			for tick in 60:
				main.combat_accent.tick(1.0/60.0)
				main._camera(1.0/60.0,1.0/60.0,-1.0)
			_check(main.camera.position.distance_to(framing.position)<0.00001 and is_equal_approx(main.camera.fov,34.0),"impact camera fully returns to the unchanged battle framing")
	main.combat_accent.clear()
	main._event({"type":"attack","side":"player","name":"heavy","facing":1.0})
	main._camera(1.0/60.0,1.0/60.0,-1.0)
	_check(main.shake==0.0 and main.camera.position.distance_to(framing.position)<0.00001,"an empty attack event produces no camera impact")
	_free_fixture_orphans(main)
	main.free()
	await process_frame
	completed.append("camera")
