extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Kit=preload("res://scripts/lightning_combat.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures.append(label);push_error(label)
func setup(profile:String):
 var game=Combat.new();game.set_player_profile(profile);game.set_training(true);game.start()
 game.player.x=-.55;game.enemy.x=.55;game.enemy.hp=1000.0;game.enemy.maxHp=1000.0
 return game
func advance(game,seconds:float)->void:
 var remaining:=seconds
 while remaining>0.000001:
  var dt:=minf(1.0/120.0,remaining);game.update(dt);remaining-=dt
func until(game,predicate:Callable,seconds:float=5.0)->bool:
 for i in ceili(seconds*120):
  if predicate.call():return true
  game.update(1.0/120.0)
 return predicate.call()
func chain(game)->Array:
 var motions:Array=[]
 game.action("light");motions.append(game.player.attack.motion);game.action("light")
 check(until(game,func():return game.player.state=="attack" and game.player.combo==1),"J1 links to J2")
 motions.append(game.player.attack.motion);game.action("light")
 check(until(game,func():return game.player.state=="attack" and game.player.combo==2),"J2 links to J3")
 motions.append(game.player.attack.motion)
 check(until(game,func():return game.player.state=="idle"),"J3 returns control")
 return motions
func _initialize()->void:
 for profile:String in Kit.PROFILES:
  var game=setup(profile)
  var hits:Array=[]
  game.event.connect(func(data):
   if data.type in ["hit","ultHit"] and data.side=="player":hits.append(data))
  check(chain(game)==["light1","light2","light3"],profile+" three original normal clips")
  check(hits.size()==3,profile+" three distinct normal hits")
  game.player.x=-.55;game.enemy.x=.55;hits.clear()
  check(game.action("ability"),profile+" E accepts input")
  advance(game,.15);check(hits.is_empty(),profile+" no premature skill damage")
  check(until(game,func():return game.player.state=="idle"),profile+" E returns control")
  check(hits.size()==3,profile+" exactly three skill contacts")
  check(not game.action("ability"),profile+" cooldown enforced")
  check(game.player.fogCharges==2 if profile=="hawk_of_the_fog" else game.player.lightningHits==0,profile+" kit resources paid only for landed attacks")
  game.player.x=-.55;game.enemy.x=.55;hits.clear();game.player.energy=100
  check(game.action("ultimate"),profile+" original Q begins")
  var cue:float=Kit.ultimate_cues(profile)[0]
  advance(game,cue-.02);check(hits.is_empty(),profile+" no Q damage before source landing")
  advance(game,.03);check(hits.size()==1,profile+" one landing impact")
  check(until(game,func():return game.ultimate.is_empty()),profile+" Q ends")
  check(hits.size()==1,profile+" no borrowed cloud multi-hit sequence")
  if profile=="shadow_knight":
   check(game.player.eclipseRemaining>9.99 and game.player.skillCooldown==0, "Q opens moon eclipse and refreshes E")
   game.player.x=-.55;game.enemy.x=.55;hits.clear()
   check(chain(game)==["burst_light1","burst_light2","burst_light3"],"eclipse uses original burst chain")
   check(game.player.lightningHits==3,"three eclipse contacts counted")
   game.player.eclipseRemaining=.04;game.player.x=-.55;game.enemy.x=.55
   check(chain(game)==["burst_light1","burst_light2","burst_light3"],"eclipse expiration preserves current native chain")
   game.action("light");check(game.player.attack.motion=="light1","next chain restores normal")
  else:
   game.action("heavy")
   check(game.player.fogCharges==0 and game.player.attack.fogCharges==2 and game.player.attack.damage==25.0,"K consumes two saved charges once")
  game=setup(profile);game.action("guard");game._receive(game.enemy,game.player,Combat.LIGHTS[0].duplicate(true))
  check(game.stats.parries==1 and game.action("ability"),profile+" parry buffers E")
  check(until(game,func():return game.player.state=="attack"),profile+" buffered E takes over")
  check(game.player.attack.parryFollowup and game.player.attack.motion=="ability",profile+" parry retains own skill")
  game=setup(profile);game.player.x=-5;game.enemy.x=5;game.action("ability");advance(game,2)
  check(game.enemy.hp==1000 and game.player.fogCharges==0,profile+" missed skill awards nothing")
  game.reset();check(game.player.eclipseRemaining==0 and game.player.fogCharges==0,profile+" reset clears transient state")
 var game=setup("shadow_knight");game.player.hp=5;game.player.eclipseRemaining=10
 var strike:Dictionary=Combat.HEAVY.duplicate(true);strike.damage=20
 game._receive(game.enemy,game.player,strike)
 check(game.player.hp==0,"eclipse damage reduction cannot make a lethal hit nonlethal by capping first")
 var report={"suite":"lightning_combat","checks":checks,"failures":failures,"passed":failures.is_empty()}
 FileAccess.open("res://build/reports/lightning-combat.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
