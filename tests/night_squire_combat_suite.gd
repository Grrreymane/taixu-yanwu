extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const STEP:=1.0/120.0
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func setup(profile:String="night_squire"):
	var game=Combat.new();game.set_player_profile(profile);game.set_training(true);game.start()
	game.player.x=-0.55;game.enemy.x=0.55;game.enemy.maxHp=500.0;game.enemy.hp=500.0
	return game
func advance(game,seconds:float)->void:
	var left:=seconds
	while left>0.000001:
		var dt:=minf(STEP,left);game.update(dt);left-=dt
func until(game,predicate:Callable,seconds:float=5.0)->bool:
	for frame in ceili(seconds/STEP):
		if predicate.call():return true
		game.update(STEP)
	return predicate.call()
func combo(game)->Array:
	var motions:Array=[]
	game.action("light");motions.append(game.player.attack.motion)
	game.action("light")
	check(until(game,func():return game.player.state=="attack" and game.player.combo==1),"first confirmed link reaches second native strike")
	motions.append(game.player.attack.get("motion",""));game.action("light")
	check(until(game,func():return game.player.state=="attack" and game.player.combo==2),"second confirmed link reaches third native strike")
	motions.append(game.player.attack.get("motion",""))
	check(until(game,func():return game.player.state=="idle"),"third strike recovers to idle")
	return motions
func _initialize()->void:
	_profiles()
	_normal_chain()
	_skill()
	_activation_and_burst()
	_defense_and_isolation()
	var report={"suite":"night_squire_combat","checks":checks,"passed":failures.is_empty(),"failures":failures}
	var file=FileAccess.open("res://build/reports/night-squire-combat.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _profiles()->void:
	var game=Combat.new()
	check(game.set_player_profile("night_squire"),"Night Squire is a selectable combat profile")
	game.start()
	check(game.player.style=="night_squire" and game.player.nightBurstRemaining==0.0 and game.player.nightFocus==0,"new run initializes Night Squire without stale burst or charges")
	check(not game.set_player_profile("fenghuang"),"active combat cannot change armor")
	game.reset()
	game.start_encounter({"training":true,"enemies":[{"id":"dummy","x":1.0,"hp":250.0}]},{"hp":75.0,"maxHp":150.0,"energy":42.0,"skillCooldownScale":0.8,"damageMultiplier":1.2})
	check(game.player.hp==75.0 and game.player.energy==42.0 and game.player.damageMultiplier==1.2,"trial health, energy and attack boons reach Night Squire")
	check(is_equal_approx(game.player.skillCooldownMax,4.4),"cooldown boon scales Night Squire's own skill")
	game.player.nightBurstRemaining=4.0;game.player.nightFocus=2
	game.reset()
	check(game.player.style=="night_squire" and game.player.nightBurstRemaining==0.0 and game.player.nightFocus==0 and game.player.skillCooldown==0.0,"reset preserves armor and clears temporary battle enhancements")
	game.set_player_profile("azure_empyrea");game.start();game.action("ability")
	check(game.player.attack.damage==18.0 and game.player.skillCooldownMax==8.0 and not game.player.attack.has("hitWindows"),"cloud-ink retains original single-hit skill and cooldown")
func _normal_chain()->void:
	var game=setup()
	var hits:Array=[]
	game.event.connect(func(data):
		if data.type=="hit" and data.side=="player":hits.append(data))
	var motions:=combo(game)
	check(motions==["light1","light2","light3"],"normal chain selects the three C3 A fist clips")
	check(hits.size()==3 and is_equal_approx(game.enemy.hp,476.0),"normal fist chain has three distinct contacts with no duplicate damage")
	check(hits.all(func(data):return data.style=="night_squire" and not data.nightBurst),"damage events preserve the independent armor identity")
	game=setup();game.player.skillCooldown=5.0
	var before:float=game.player.skillCooldown
	combo(game)
	check(game.player.skillCooldown<before-game.time-0.6,"confirmed third hit refunds skill cooldown beyond passive ticking")
	game=setup();game.action("light");game.action("heavy")
	check(until(game,func():return game.player.state=="attack" and game.player.attack.name=="heavy"),"K queued during a fist chain executes the native AAB branch")
	check(game.player.attack.motion=="heavy" and game.player.attack.range<2.5,"normal heavy keeps a close-range branch hitbox")
func _skill()->void:
	var game=setup();var hits:Array=[];var charges:Array=[]
	game.event.connect(func(data):
		if data.type=="hit" and data.side=="player":hits.append(data)
		if data.type=="nightFocus":charges.append(data))
	check(game.action("ability"),"E begins native BAA attack")
	check(game.player.attack.hitWindows==[0.40,0.60,0.833333] and game.player.attack.duration==1.25,"E uses three original contact times without compressing the active animation")
	advance(game,0.39);check(hits.is_empty(),"E cannot damage before its first original contact")
	check(not game.action("dodge"),"E cannot cancel out before its committed contact sequence")
	check(until(game,func():return game.player.state=="idle"),"E completes its native follow-through")
	check(hits.size()==3 and is_equal_approx(game.enemy.hp,477.0),"E deals 6/7/10 across exactly three contacts")
	check(hits.size()==3 and hits[0].hitIndex==0 and hits[1].hitIndex==1 and hits[2].hitIndex==2,"each E hit carries its native contact index")
	check(charges.size()==1 and game.player.nightFocus==3,"a landed skill fills three follow-up charges once")
	check(not game.action("ability"),"E remains gated by its cooldown")
	game.action("light")
	check(game.player.nightFocus==2 and game.player.attack.nightFocused and is_equal_approx(game.player.attack.damage,7.08),"next strike consumes one charge and receives its damage bonus")
	game=setup();game.player.x=-5.0;game.enemy.x=5.0
	game.action("ability");advance(game,2.0)
	check(game.enemy.hp==500.0 and game.player.nightFocus==0,"a missed skill cannot award charges or damage from across the arena")
	game=setup();game.action("ability");advance(game,0.2);game.action("pause")
	var frozen:Dictionary=game.snapshot();advance(game,1.0)
	check(game.snapshot()==frozen,"pause freezes multi-hit contact scheduling and cooldowns")
func _activation_and_burst()->void:
	var game=setup();game.player.x=-3.0;game.enemy.x=3.0
	var events:Array=[];game.event.connect(func(data):events.append(data))
	var before_player:float=game.player.x;var before_enemy:float=game.enemy.x
	check(game.action("ultimate"),"Q starts ND_Ultra activation at full energy")
	check(game.player.energy==0.0 and is_equal_approx(game.ultimate.duration,1.583333),"Q consumes energy and keeps the native activation duration")
	advance(game,1.0)
	check(game.player.x==before_player and game.enemy.x==before_enemy and game.enemy.hp==500.0,"activation neither teleports the fighters nor applies a borrowed arena-wide attack")
	check(not game.action("light") and game.player.nightBurstRemaining==0.0,"burst strikes wait until the native activation completes")
	check(until(game,func():return game.ultimate.is_empty()),"activation releases player control")
	check(game.player.nightBurstRemaining>7.99 and game.player.nightFocus==3 and game.player.skillCooldown==0.0,"activation starts eight seconds of burst and refreshes E and follow-up charges")
	check(events.filter(func(data):return data.type=="ultHit").is_empty(),"activation never emits cloud-ink or phoenix ultimate damage events")
	check(events.filter(func(data):return data.type=="burstBegin").size()==1,"burst begins exactly once")
	game.player.energy=100.0;check(not game.action("ultimate"),"an active burst cannot be nested or restarted")
	game.player.x=-0.55;game.enemy.x=0.55;game.player.nightFocus=0
	var hp:float=game.enemy.hp
	check(combo(game)==["kick_light1","kick_light2","kick_light3"],"burst uses all three C3 B kick clips")
	check(is_equal_approx(hp-game.enemy.hp,36.0),"burst chain changes actual combat damage")
	game.action("heavy");check(game.player.attack.motion=="kick_heavy","burst K uses the original BBA finisher")
	check(until(game,func():return game.player.state=="idle"),"burst heavy finishes normally")
	var remaining:float=game.player.nightBurstRemaining;game.action("pause");advance(game,1.0)
	check(game.player.nightBurstRemaining==remaining,"paused time never consumes burst duration")
	game.action("pause");advance(game,remaining+0.1)
	check(game.player.nightBurstRemaining==0.0 and events.filter(func(data):return data.type=="burstEnd").size()==1,"burst expires once and restores ordinary combat")
	game.action("light");check(game.player.attack.motion=="light1","a new post-burst chain returns to original A clips")
	game=setup();game.player.nightBurstRemaining=0.04
	check(combo(game)==["kick_light1","kick_light2","kick_light3"],"burst expiry does not splice a running B chain into incompatible A poses")
func _defense_and_isolation()->void:
	var game=setup();game.action("guard")
	var strike:Dictionary=Combat.LIGHTS[0].duplicate(true)
	game._receive(game.enemy,game.player,strike)
	check(game.stats.parries==1 and game.action("light"),"Night Squire retains successful parry buffering")
	check(until(game,func():return game.player.state=="attack"),"parry buffer hands control to a native Night Squire attack")
	check(game.player.attack.motion=="light1" and game.player.attack.parryFollowup,"parry follow-up selects C3 fist motion and its chase rules")
	var other=setup("fenghuang");other.action("ability")
	check(other.player.stance=="kick" and other.player.attack.motion=="switch_kick" and other.player.skillCooldownMax==1.35,"Phoenix E remains its own stance switch")
	game=setup();game.action("ability")
	var fresh=setup();fresh.action("ability")
	game.player.attack.hitWindows[0]=9.0
	check(fresh.player.attack.hitWindows[0]==0.4,"each multi-hit skill owns independent contact data")
