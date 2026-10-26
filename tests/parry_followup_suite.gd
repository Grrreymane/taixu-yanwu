extends SceneTree
## Real timed guard contacts followed by player commands; no fabricated parry
## event, direct damage or presentation-only state is used to grant an opening.
const Combat = preload("res://scripts/combat.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const STEP := 1.0 / 120.0
const VARIANTS := [["azure_empyrea","punch"],["fenghuang","punch"],["fenghuang","kick"]]
const COMMANDS := ["light","heavy","ability","ultimate","dodge"]

class ErrorRecorder extends Logger:
	var errors: Array[Dictionary] = []
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type})
	func _log_message(_message: String,_error: bool) -> void: pass

var checks := 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {"contacts":[],"followups":[],"resources":[],"lifecycle":[],"protection":[],"counterChains":[],"queueTokens":[],"targets":[],"targetChains":[],"reach":[],"nativeSources":[]}
var recorder := ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		print("CHECK FAILED: ",label)

func _run() -> void:
	OS.add_logger(recorder)
	if "--target-probe" in OS.get_cmdline_user_args():
		_multiple_enemy_probe()
		OS.remove_logger(recorder)
		quit(0)
		return
	if "--reach-probe" in OS.get_cmdline_user_args():
		_reach_probe()
		OS.remove_logger(recorder)
		quit(0)
		return
	_contact_contract()
	_followup_matrix()
	_resources()
	_lifecycle()
	_opening_protection()
	_counter_chains()
	_tokens_and_queue()
	_multiple_enemy_targets()
	_reach_contract()
	_native_source_contract()
	_check(completed==["contacts","followups","resources","lifecycle","protection","counterChains","queueTokens","targets","reach","nativeSources"],"all independent sections reached completion")
	_check(observations.contacts.size()==6 and observations.followups.size()==30 and observations.resources.size()==9 and observations.lifecycle.size()==9 and observations.protection.size()==12 and observations.counterChains.size()==12 and observations.queueTokens.size()==3 and observations.targets.size()==30 and observations.targetChains.size()==6 and observations.reach.size()==12 and observations.nativeSources.size()==2,"every expected case produced an observation")
	_check(recorder.errors.is_empty(),"no engine/script error escaped through an early method return")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var report: Dictionary={"suite":"parry_followup","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors,"completed":completed,"observations":observations}
	var file:=FileAccess.open("res://build/reports/parry-followup-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	OS.remove_logger(recorder)
	print(JSON.stringify({"suite":"parry_followup","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors.size(),"completed":completed}))
	quit(0 if failures.is_empty() else 1)

func _fixture(variant: Array,encounter: bool=false) -> Dictionary:
	var game=Combat.new()
	game.set_player_profile(variant[0])
	if encounter:
		game.start_encounter({"training":true,"playerX":-0.6,"enemies":[{"id":"opponent","type":"striker","x":0.6,"hp":100.0}]})
	else:
		game.set_training(true)
		game.start()
	var sample: Dictionary={"game":game,"events":[],"wall":0.0,"label":str(variant[0])+"/"+str(variant[1])+("/trial" if encounter else "/practice")}
	# Capture a separate small clock object, not sample/game, to avoid a signal
	# reference cycle that would conceal fixture leaks at engine shutdown.
	var clock: Dictionary={"wall":0.0}
	var events: Array=sample.events
	game.event.connect(func(event: Dictionary):
		var copy:=event.duplicate(true)
		copy.wall=clock.wall
		events.append(copy))
	sample.clock=clock
	if variant[1]=="kick":
		game.player.x=-4.0
		game.enemy.x=4.0
		_check(game.action("ability"),sample.label+": select kick with the real E action")
		_advance(sample,1.6)
	game.player.x=-0.6
	game.enemy.x=0.6
	events.clear()
	game._attack(game.enemy,"light")
	_check(_until(sample,func(): return game.enemy.state=="attack" and game.enemy.stateTime>=game.enemy.attack.windup-0.05,1.2),sample.label+": enemy reaches its real guard timing")
	_check(game.action("guard"),sample.label+": L enters guard")
	_check(_until(sample,func(): return game.stats.parries==1,1.0,true),sample.label+": actual enemy contact triggers a timed parry")
	sample.parryTime=game.time
	sample.parryWall=clock.wall
	return sample

func _advance(sample: Dictionary,seconds: float,guard: bool=false) -> void:
	var remaining:=seconds
	while remaining>0.000001:
		var delta:=minf(STEP,remaining)
		sample.clock.wall+=delta
		sample.game.update(delta,0.0,guard)
		remaining-=delta

func _until(sample: Dictionary,predicate: Callable,seconds: float=3.0,guard: bool=false) -> bool:
	for index in ceili(seconds/STEP):
		if predicate.call(): return true
		_advance(sample,STEP,guard)
	return bool(predicate.call())

func _events(sample: Dictionary,kind: String) -> Array:
	return sample.events.filter(func(event: Dictionary):
		return event.type==kind and (event.get("side","")=="player" or kind=="ultimate"))

func _command_events(sample: Dictionary,command: String) -> Array:
	if command in ["ultimate","dodge"]: return _events(sample,command)
	var counter_light: bool=command=="light" and sample.game.player_profile=="fenghuang"
	return _events(sample,"attack").filter(func(event: Dictionary):
		return event.get("name","")==command or (counter_light and event.get("name","")=="heavy" and event.get("combo",-1)==0))

func _contact_contract() -> void:
	for variant: Array in VARIANTS:
		for encounter in [false,true]:
			var sample:=_fixture(variant,encounter)
			var game=sample.game
			var label: String=sample.label
			_check(_events(sample,"parry").size()==1 and game.hit_stop>0.0,label+": one actual parry produces contact stop")
			_check(is_equal_approx(float(game.player.get("riposteReadyAt",-1.0))-game.time,0.075) and is_equal_approx(float(game.player.get("riposteUntil",-1.0))-game.time,1.0),label+": real success establishes a short handoff and one-second opening")
			_check(game.player.get("riposteTarget","")==game.enemy.id,label+": opening belongs to the actual parried opponent")
			_check(game.player.hp==game.player.maxHp and game.enemy.hp==100.0 and game.stats.damageDealt==0.0,label+": success alone never deals automatic HP damage")
			var stopped_clock: float=game.time
			_advance(sample,0.04,true)
			_check(game.time==stopped_clock and game.enemy.state=="stagger",label+": parry stop freezes the opening clock")
			_check(_until(sample,func(): return game.time>=sample.parryTime+0.3,1.0,true),label+": holding guard resumes normally")
			_check(_events(sample,"attack").is_empty() and game.enemy.hp==100.0,label+": waiting never fabricates a pursuit attack")
			_check(_until(sample,func(): return game.enemy.state=="idle",2.0,true),label+": unused enemy stagger eventually recovers")
			observations.contacts.append({"case":label,"parryTime":sample.parryTime,"recoveredAt":game.time,"parryEvents":_events(sample,"parry").size()})
	completed.append("contacts")

func _followup_matrix() -> void:
	for variant: Array in VARIANTS:
		for command: String in COMMANDS:
			for delay in [0.0,0.24]:
				var sample:=_fixture(variant)
				var game=sample.game
				var label: String=sample.label+"/"+command+("/early" if delay==0.0 else "/late")
				if delay>0.0:
					_check(_until(sample,func(): return game.time>=sample.parryTime+delay,1.0,true),label+": advance to deliberate follow-up input")
				var input_time: float=game.time
				var input_wall: float=sample.clock.wall
				var ready_at: float=game.player.get("riposteReadyAt",-1.0)
				var energy_before: float=game.player.energy
				_check(game.action(command),label+": a legal follow-up command is accepted")
				var instant_count:=_command_events(sample,command).size()
				if delay==0.0:
					_check(instant_count==0 and game.player.state=="guard",label+": early input preserves the parry pose during hitstop")
					_check(game.player.energy==energy_before and game.player.skillCooldown==0.0,label+": deferred input spends no resources before actual action start")
					_advance(sample,0.04,true)
					_check(_command_events(sample,command).is_empty() and game.time==input_time,label+": contact freeze holds both handoff and queued attack")
				else: _check(instant_count==1,label+": later input starts immediately after the handoff")
				_check(_until(sample,func(): return not _command_events(sample,command).is_empty(),1.0),label+": accepted command reaches its actual action event")
				var starts:=_command_events(sample,command)
				var start: Dictionary=starts[0] if not starts.is_empty() else {}
				if delay==0.0 and not start.is_empty():
					_check(float(start.time)>=ready_at-STEP and float(start.time)<=ready_at+STEP*2.0,label+": buffered pursuit starts on the first legal handoff")
				if command in ["light","heavy","ability"]:
					var cap:=0.19 if command=="light" and variant[0]=="fenghuang" else 0.16 if command=="light" else 0.28 if command=="heavy" else 0.30
					_check(game.player.attack.get("parryFollowup",false) and game.player.attack.windup<=cap+0.00001,label+": the actual attack carries the timely pursuit startup")
					_check(start.get("parryFollowup",false) and is_equal_approx(float(start.windup),float(game.player.attack.windup)),label+": presentation event advertises the same pursuit and contact timing")
				_check(game.player.get("riposteUntil",-1.0)<game.time and game.player.counterUntil<0.0,label+": an executed pursuit or escape consumes both opening qualifications")
				var idle_before_contact: Array[float]=[]
				var expects_hit:=command!="dodge"
				for tick in 720:
					if expects_hit and _events(sample,"hit").is_empty() and _events(sample,"ultHit").is_empty() and game.enemy.state=="idle":
						idle_before_contact.append(game.time)
					_advance(sample,STEP)
					if sample.clock.wall-input_wall>5.0: break
				var hits:=_events(sample,"hit")
				var ultimate_hits:=_events(sample,"ultHit")
				_check(_command_events(sample,command).size()==1,label+": one input consumes once without a delayed duplicate")
				_check(not hits.is_empty() or not ultimate_hits.is_empty() if expects_hit else hits.is_empty(),label+": pursuit contacts only through its normal active frames")
				if not start.is_empty() and not hits.is_empty():
					_check(float(hits[0].time)-float(start.time)>=float(start.windup)-STEP,label+": no damage is pulled earlier than the advertised contact")
				observations.followups.append({"case":label,"inputTime":input_time,"inputWall":input_wall,"instantCount":instant_count,"start":start,"hits":hits,"ultimateHits":ultimate_hits,"idleBeforeContact":idle_before_contact})
	completed.append("followups")

func _resources() -> void:
	for variant: Array in VARIANTS:
		for command: String in ["ability","ultimate","dodge"]:
			var sample:=_fixture(variant)
			var game=sample.game
			if command=="ability": game.player.skillCooldown=2.0
			elif command=="ultimate": game.player.energy=0.0
			else: game.player.nextDodgeAt=game.time+2.0
			var stance: String=game.player.stance
			_check(not game.action(command),sample.label+": parry does not waive "+command+" resources")
			_advance(sample,3.2,true)
			_check(_command_events(sample,command).is_empty(),sample.label+": rejected "+command+" does not execute after cooldown later clears")
			_check(game.player.stance==stance,sample.label+": rejected command does not change stance")
			observations.resources.append({"case":sample.label,"command":command,"starts":_command_events(sample,command).size()})
	completed.append("resources")

func _lifecycle() -> void:
	for variant: Array in VARIANTS:
		for operation: String in ["pause","reset","hit"]:
			var sample:=_fixture(variant)
			var game=sample.game
			var label: String=sample.label+"/"+operation
			_check(game.action("heavy"),label+": early follow-up input is accepted")
			var before_events:=_command_events(sample,"heavy").size()
			_check(before_events==0,label+": interruption fixture truly has a pending input, not a started attack")
			if operation=="pause":
				game.action("pause")
				var frozen: Dictionary=game.snapshot().duplicate(true)
				_advance(sample,0.5,true)
				_check(game.snapshot()==frozen,label+": pause freezes the entire combat snapshot")
				game.action("pause")
				_check(game.player.get("riposteUntil",-1.0)>game.time,label+": pause preserves the unspent opening token")
			elif operation=="reset":
				game.start()
				_check(game.player_profile==variant[0] and game.player.counterUntil<0.0,label+": reset keeps profile and clears old opening")
			else:
				# A second incoming strike may interrupt the pending response.
				# The parry was earned normally; only this adversarial collision
				# is injected to isolate invalidation from AI scheduling.
				game._state(game.player,"idle")
				game._receive(game.enemy,game.player,Combat.LIGHTS[0].duplicate(true))
				_check(game.player.get("riposteUntil",-1.0)<game.time,label+": a fresh hit revokes the old opening")
			_advance(sample,1.5,true)
			_check(_command_events(sample,"heavy").size()==before_events,label+": lifecycle change cannot emit a newly delayed old attack")
			observations.lifecycle.append({"case":label,"eventsAtInterruption":before_events,"eventsAfter":_command_events(sample,"heavy").size()})
	completed.append("lifecycle")

func _opening_protection() -> void:
	for variant: Array in VARIANTS:
		for command: String in ["light","heavy","ability"]:
			var sample:=_fixture(variant)
			var game=sample.game
			var label: String=sample.label+"/"+command
			_check(_until(sample,func(): return game.time>=sample.parryTime+0.48,1.2,true),label+": reach the late part of the original stagger")
			_check(game.enemy.state=="stagger",label+": late pursuit starts against the same still-staggered opponent")
			_check(game.action(command),label+": deliberate late pursuit is accepted inside its token")
			var gaps: Array[float]=[]
			for index in 180:
				if not _events(sample,"hit").is_empty(): break
				if game.enemy.state!="stagger": gaps.append(game.time)
				_advance(sample,STEP)
			_check(not _events(sample,"hit").is_empty() and gaps.is_empty(),label+": only the existing parry stagger is extended through actual contact")
			observations.protection.append({"case":label,"mode":"same-stagger","gaps":gaps,"hits":_events(sample,"hit")})
		var sample:=_fixture(variant)
		var game=sample.game
		_check(_until(sample,func(): return game.enemy.state=="idle",1.2,true),sample.label+": original unused parry stagger fully recovers")
		_check(game.time<game.player.get("riposteUntil",-1.0),sample.label+": token can still exist after enemy recovery")
		_check(game.action("heavy") and game.enemy.state=="idle",sample.label+": follow-up cannot force a recovered enemy back into stagger before contact")
		_advance(sample,0.04)
		_check(game.enemy.state=="idle" and game.enemy.hp==100.0,sample.label+": recovered opponent remains free throughout pursuit startup")
		observations.protection.append({"case":sample.label,"mode":"already-recovered","time":game.time,"state":game.enemy.state})
	completed.append("protection")

func _counter_chains() -> void:
	for stance: String in ["punch","kick"]:
		for outcome: String in ["hit","block","whiff"]:
			for command: String in ["light","heavy"]:
				var sample:=_fixture(["fenghuang",stance])
				var game=sample.game
				var label:=stance+"/"+outcome+"/"+command
				game.action("light")
				_check(_until(sample,func(): return game.player.state=="attack",1.0),label+": buffered J reaches the native counter")
				_check(game.player.attack.get("motion","")=="counter_"+stance,label+": native counter selection survives handoff")
				var counter_start: float=game.time
				var counter_duration: float=game.player.attack.duration
				if outcome=="whiff":
					game.player.x=-4.0
					game.enemy.x=4.0
				elif outcome=="block":
					game._state(game.enemy,"guard",3.0)
					game.enemy.parryUntil=-1.0
				_advance(sample,0.05,true)
				_check(game.action(command),label+": input during native counter queues a continuation")
				_check(_until(sample,func(): return _events(sample,"attack").size()>=2,2.0,true),label+": queued pursuit starts even while L remains physically held")
				var attacks:=_events(sample,"attack")
				if attacks.size()>=2:
					if command=="light":
						_check(attacks[1].get("name","")=="light" and attacks[1].get("combo",-1)==1,label+": native counter continues at light two rather than restarting")
						_check(attacks[1].get("motion","")==("kick_light1" if stance=="kick" else "light1"),label+": the second hit uses an alternate native source instead of replaying its counter clip")
					else:
						_check(attacks[1].get("name","")=="heavy" and attacks[1].get("motion","")=="",label+": K continues into a normal heavy without reusing the native counter")
					var interval: float=attacks[1].time-counter_start
					_check(interval>=counter_duration-STEP if outcome=="whiff" else interval<counter_duration-STEP,label+": only connected counters gain early recovery cancellation")
				_advance(sample,1.5)
				_check(_events(sample,"attack").size()==2,label+": one counter follow-up input cannot duplicate a third attack")
				observations.counterChains.append({"case":label,"attacks":attacks,"hits":_events(sample,"hit")})
	completed.append("counterChains")

func _tokens_and_queue() -> void:
	for variant: Array in VARIANTS:
		var sample:=_fixture(variant)
		var game=sample.game
		_check(game.action("light") and game.action("heavy"),sample.label+": a later valid command replaces the pending first input")
		game.player.energy=0.0
		_check(not game.action("ultimate"),sample.label+": a later illegal command cannot replace the valid slot")
		_check(_until(sample,func(): return not _events(sample,"attack").is_empty(),1.0),sample.label+": last valid single-slot choice is consumed")
		_check(game.player.attack.name=="heavy" and game.player.attack.get("motion","")=="",sample.label+": single slot executes K rather than the replaced J/counter or illegal Q")
		_advance(sample,1.6)
		_check(_events(sample,"attack").size()==1 and _events(sample,"ultimate").is_empty(),sample.label+": replaced and rejected commands never execute afterward")
		var replacement_events:=_events(sample,"attack")

		sample=_fixture(variant)
		game=sample.game
		_check(_until(sample,func(): return game.time>sample.parryTime+1.01,2.0,true),sample.label+": unused opening reaches its real expiry")
		_check(game.action("light") and not game.player.attack.get("parryFollowup",false) and not str(game.player.attack.get("motion","")).begins_with("counter_"),sample.label+": expired opening restores ordinary J")

		# An ordinary held block must never enter the success-only handoff.
		game.start()
		game.player.stance=variant[1]
		game.player.x=-0.6
		game.enemy.x=0.6
		sample.events.clear()
		game.action("guard")
		_advance(sample,0.2,true)
		game._attack(game.enemy,"light")
		_check(_until(sample,func(): return not _events(sample,"block").is_empty(),1.0,true),sample.label+": ordinary held guard receives a genuine blocked attack")
		_check(game.stats.parries==0 and game.player.get("riposteUntil",-1.0)<game.time,sample.label+": block grants no parry opening")
		_check(game.action("light") and game.player.state=="attack" and not game.player.attack.get("parryFollowup",false),sample.label+": block-to-J remains an ordinary immediate attack")

		# Replacing the old stagger is an independent event; a token must not
		# extend that new state simply because it belongs to the same enemy.
		for replacement: String in ["stagger","attack"]:
			sample=_fixture(variant)
			game=sample.game
			_until(sample,func(): return game.time>=sample.parryTime+0.1,1.0,true)
			if replacement=="stagger": game._state(game.enemy,"stagger",0.05)
			else: game._attack(game.enemy,"light")
			var duration_before: float=game.enemy.stateDuration
			game.action("heavy")
			_check(game.enemy.state==replacement and game.enemy.stateDuration==duration_before,sample.label+": pursuit cannot extend or replace a subsequent enemy "+replacement)
		observations.queueTokens.append({"case":sample.label,"replacementEvents":replacement_events,"expiryAndBlockChecked":true,"independentStatesChecked":2})
	completed.append("queueTokens")

func _multiple_enemy_probe() -> void:
	var cases: Array[Dictionary]=[]
	for direction in [-1.0,1.0]:
		cases.append(_target_case(["azure_empyrea","punch"],direction,"live"))
	var report: Dictionary={"suite":"parry-target-probe","cases":cases,"engineErrors":recorder.errors}
	var file:=FileAccess.open("res://build/reports/parry-target-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))

func _target_case(variant: Array,direction: float,mutation: String) -> Dictionary:
	var game=Combat.new()
	game.set_player_profile(variant[0])
	game.start_encounter({"training":true,"playerX":0.0,"enemies":[
		{"id":"parried","type":"striker","x":direction*1.25,"hp":100.0},
		{"id":"bystander","type":"striker","x":direction*-1.01,"hp":100.0}]})
	game.player.stance=variant[1]
	var label:=str(variant[0])+"/"+str(variant[1])+"/"+str(direction)+"/"+mutation
	var opponent: Dictionary=game.enemies[0]
	var sample: Dictionary={"game":game,"events":[],"clock":{"wall":0.0}}
	var events: Array=sample.events
	game.event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	game._attack(opponent,"light")
	_check(_until(sample,func(): return opponent.state=="attack" and opponent.stateTime>=opponent.attack.windup-0.05,1.0),label+": enemy reaches timed guard cue")
	game.action("guard")
	_check(_until(sample,func(): return game.stats.parries==1,1.0,true),label+": target fixture earns its real parry")
	var parries:=_events(sample,"parry")
	if parries.is_empty(): return {"case":label,"incomplete":true}
	var parry: Dictionary=parries[0]
	var target_at_parry: String=game.enemy.id
	var parry_facing: float=game.player.facing
	if mutation=="dead-before": opponent.hp=0.0
	elif mutation=="far-before": opponent.x=direction*4.6
	game.action("light")
	_check(_until(sample,func(): return not _events(sample,"attack").is_empty(),1.0),label+": follow-up reaches action startup")
	var starts:=_events(sample,"attack")
	if starts.is_empty(): return {"case":label,"incomplete":true}
	var start: Dictionary=starts[0]
	if mutation=="dead-startup": opponent.hp=0.0
	elif mutation=="far-startup": opponent.x=direction*4.6
	if mutation=="chain": game.action("light")
	_check(_until(sample,func(): return not _events(sample,"hit").is_empty(),1.0),label+": a living reachable target receives the actual contact")
	var wrong_facing: Array[float]=[]
	if mutation=="chain":
		var third_queued:=false
		for tick in 600:
			if game.player.state=="attack":
				if game.player.facing!=direction: wrong_facing.append(game.time)
				if game.player.combo==1 and game.player.stateTime>=0.05 and not third_queued:
					third_queued=game.action("light")
			if _events(sample,"attack").size()==3 and game.player.state=="idle": break
			_advance(sample,STEP)
		_check(third_queued and _events(sample,"attack").size()==3 and _events(sample,"hit").size()==3,label+": full J chain actually reaches all three contacts")
		_check(wrong_facing.is_empty(),label+": no mid-recovery turn toward the closer opposite enemy")
		for hit: Dictionary in _events(sample,"hit"):
			_check(hit.targetId=="parried",label+": each continued light reaches the original parried opponent")
		var chain_attacks:=_events(sample,"attack")
		if chain_attacks.size()==3:
			_check(not chain_attacks[1].parryFollowup and not chain_attacks[2].parryFollowup,label+": target continuity cannot duplicate the first pursuit timing bonus")
	var hits:=_events(sample,"hit")
	var expected: String="parried" if mutation in ["live","chain"] else "bystander"
	_check(not hits.is_empty() and hits[0].targetId==expected,label+": pursuit preserves its original target or immediately falls back when invalid")
	if mutation in ["live","chain"]:
		_check(start.targetId=="parried" and float(start.facing)==direction,label+": pushback does not turn the follow-up toward the closer opposite enemy")
		_check(game.enemies[1].hp==100.0,label+": the opposite bystander takes no accidental damage")
	else:
		_check(float(game.player.facing)==-direction,label+": invalid-target fallback updates the strike facing")
	if mutation=="chain":
		game.enemies[1].x=game.player.x-direction*(Combat.GAP+0.02)
		_advance(sample,STEP)
		_check(game.enemy.id=="bystander" and game.player.facing==-direction,label+": finishing recovery releases target focus to the nearest living enemy")
	return {"case":label,"direction":direction,"parry":parry,"targetAtParry":target_at_parry,"facingAtParry":parry_facing,"attack":start,"hits":hits,
		"opponentX":opponent.x,"bystanderX":game.enemies[1].x,"playerX":game.player.x,
		"expectedTarget":expected,"targetMismatch":not hits.is_empty() and hits[0].targetId!=expected,"wrongFacing":wrong_facing}

func _multiple_enemy_targets() -> void:
	for variant: Array in VARIANTS:
		for direction in [-1.0,1.0]:
			for mutation: String in ["live","dead-before","far-before","dead-startup","far-startup"]:
				observations.targets.append(_target_case(variant,direction,mutation))
			observations.targetChains.append(_target_case(variant,direction,"chain"))
	completed.append("targets")

func _reach_probe() -> void:
	var samples: Array[Dictionary]=[]
	for retreat in [0.0,0.20,0.25,0.30,0.35]:
		samples.append(_reach_case(retreat,1.0))
	var report: Dictionary={"suite":"parry-reach-probe","cases":samples,"engineErrors":recorder.errors}
	var file:=FileAccess.open("res://build/reports/parry-reach-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))

func _reach_case(retreat: float,direction: float,mode: String="pursuit") -> Dictionary:
	var game=Combat.new()
	if mode=="blocked":
		game.start_encounter({"training":true,"playerX":0.0,"enemies":[
			{"id":"parried","type":"striker","x":direction*1.92,"hp":100.0},
			{"id":"blocker","type":"striker","x":direction*0.96,"hp":100.0}]})
	else:
		game.set_training(true)
		game.start()
		var shift: float=direction*4.0 if mode=="edge" else 0.0
		game.player.x=shift
		game.enemy.x=shift+direction*1.5
	var opponent: Dictionary=game.enemies[0]
	var sample: Dictionary={"game":game,"events":[],"clock":{"wall":0.0}}
	var events: Array=sample.events
	game.event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	game._attack(opponent,"heavy")
	var incoming_range: float=opponent.attack.range
	for tick in roundi(retreat/STEP):
		sample.clock.wall+=STEP
		game.update(STEP,-direction,false)
	_until(sample,func(): return opponent.state=="attack" and opponent.stateTime>=opponent.attack.windup-0.05,2.0)
	game.action("guard")
	_until(sample,func(): return game.stats.parries==1,1.0,true)
	var parry_distance: float=absf(opponent.x-game.player.x)
	var pursuit_cap: float=game.player.get("riposteAdvance",0.55)
	var parry_time: float=game.time
	if mode=="ordinary": _until(sample,func(): return game.time>parry_time+1.01,2.0,true)
	game.action("light")
	_until(sample,func(): return not _events(sample,"attack").is_empty(),1.0)
	var starts:=_events(sample,"attack")
	var allowed_advance: float=game.player.attack.get("followupAdvance",0.0)
	var minimum_gap:=100.0
	var maximum_extent:=0.0
	for tick in 180:
		_advance(sample,STEP)
		maximum_extent=maxf(maximum_extent,absf(game.player.x))
		for foe: Dictionary in game.enemies:
			minimum_gap=minf(minimum_gap,absf(foe.x-game.player.x))
			maximum_extent=maxf(maximum_extent,absf(foe.x))
	return {"mode":mode,"direction":direction,"retreatSeconds":retreat,"parries":game.stats.parries,"parryDistance":parry_distance,"incomingRange":incoming_range,"pursuitCap":pursuit_cap,"finalDistance":absf(opponent.x-game.player.x),
		"start":starts[0] if not starts.is_empty() else {},"hits":_events(sample,"hit"),"enemyHp":opponent.hp,"advance":allowed_advance,"minimumGap":minimum_gap,"maximumExtent":maximum_extent}

func _reach_contract() -> void:
	for direction in [-1.0,1.0]:
		for retreat in [0.25,0.30,0.35]:
			var result:=_reach_case(retreat,direction)
			_check(result.parries==1 and result.parryDistance>Combat.LIGHTS[0].range and result.parryDistance<=result.incomingRange,"normal retreat produces a genuine parry outside fist reach but inside the actual enemy weapon range")
			_check(result.hits.size()==1 and result.enemyHp==94.0,"timely Azure J actually reaches the legally parried long-range attacker")
			_check(result.advance>0.0 and result.advance<=result.pursuitCap and result.start.range==1.75,"only the earned bounded startup step supplies reach; punch range stays unchanged")
			_check(result.minimumGap>=Combat.GAP-0.00001 and result.maximumExtent<=Combat.LIMIT,"pursuit advancement obeys body separation and arena limits")
			observations.reach.append(result)
		for mode: String in ["ordinary","edge","blocked"]:
			var result:=_reach_case(0.0 if mode=="blocked" else 0.35,direction,mode)
			_check(result.parries==1,mode+": reach fixture earns a real parry")
			_check(result.minimumGap>=Combat.GAP-0.00001 and result.maximumExtent<=Combat.LIMIT,mode+": follow-up never crosses another body or arena boundary")
			if mode=="ordinary":
				_check(result.advance==0.0 and result.hits.is_empty() and not result.start.parryFollowup,"expired ordinary J receives neither pursuit movement nor extra range")
			elif mode=="blocked":
				_check(result.enemyHp==100.0 and result.hits.size()==1 and result.hits[0].targetId=="blocker","intervening opponent blocks the approach rather than being crossed to reach the distant target")
			else: _check(result.hits.size()==1 and result.enemyHp==94.0,"pursuit still contacts when the exchange begins at the arena edge")
			observations.reach.append(result)
	completed.append("reach")

func _native_source_contract() -> void:
	var profile: Dictionary=Roster.resolve("fuhua","fenghuang","default").actor
	var packed:=load(str(profile.modelPath)) as PackedScene
	_check(packed!=null,"actual Phoenix source scene exists")
	if packed==null: return
	var model:=packed.instantiate()
	var players:=model.find_children("*","AnimationPlayer",true,false)
	_check(not players.is_empty(),"actual Phoenix source exposes its imported animation library")
	if players.is_empty():
		model.free()
		return
	var animations:=players[0] as AnimationPlayer
	for stance: String in ["punch","kick"]:
		var counter_name: String=profile.prefix+profile.motions["counter_"+stance].clip
		var continuation_name: String=profile.prefix+profile.motions["kick_light1" if stance=="kick" else "light1"].clip
		_check(counter_name!=continuation_name and animations.has_animation(counter_name) and animations.has_animation(continuation_name),stance+": counter and continuation resolve to two available native clips")
		if not animations.has_animation(counter_name) or not animations.has_animation(continuation_name): continue
		var counter:=animations.get_animation(counter_name)
		var continuation:=animations.get_animation(continuation_name)
		var differences:=0
		for track in counter.get_track_count():
			if counter.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
			var next_track:=continuation.find_track(counter.track_get_path(track),Animation.TYPE_ROTATION_3D)
			if next_track<0: continue
			for clock in [0.10,0.25,0.40]:
				var first:=counter.rotation_track_interpolate(track,clock)
				var second:=continuation.rotation_track_interpolate(next_track,clock)
				if absf(first.dot(second))<0.9999: differences+=1
		_check(differences>5,stance+": the two original sources contain meaningfully different bone poses, not renamed duplicates")
		observations.nativeSources.append({"stance":stance,"counter":counter_name,"continuation":continuation_name,"differentRotationSamples":differences})
	model.free()
	completed.append("nativeSources")
