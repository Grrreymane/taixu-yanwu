extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var passed:=0

func advance(game,seconds: float,movement: float=0.0,guard: bool=false) -> void:
 var remaining: float=seconds
 while remaining>0.000001:
  var dt: float=minf(remaining,1.0/120.0)
  game.update(dt,movement,guard)
  remaining-=dt

func check(ok: bool,message: String) -> void:
 if not ok:
  push_error("FAIL: "+message)
  quit(1)
  assert(ok,message)
 passed+=1

func setup(specs: Array,carry: Dictionary={},training: bool=true):
 var game=Combat.new()
 game.start_encounter({"playerX":0.0,"training":training,"enemies":specs},carry)
 return game

func _initialize() -> void:
 var game=setup([{"id":"near","x":1.1,"hp":100},{"id":"far","x":1.9,"hp":100}])
 check(game.snapshot().enemies.size()==2 and game.snapshot().enemyId=="near","snapshot exposes all actors and nearest live compatibility target")
 game.action("light")
 advance(game,0.5)
 check(game.enemies[0].hp==94.0 and game.enemies[1].hp==100.0,"light strikes only the nearest foe")
 game.enemies[0].hp=0.0
 advance(game,0.05)
 check(not game.ended and game.enemy.id=="far" and game.stats.kills==1,"one enemy down changes target without ending encounter")
 var isolated: Dictionary=game.snapshot()
 isolated.enemies[1].hp=0.0
 check(game.enemies[1].hp==100.0,"snapshot enemy data is isolated")
 game.enemies[1].hp=0.0
 advance(game,0.05)
 check(game.ended and game.winner=="player" and game.stats.kills==2,"only the final enemy ends the encounter")

 game=setup([{"id":"a","x":1.0,"hp":100},{"id":"b","x":1.8,"hp":100}])
 game.action("heavy")
 advance(game,1.0)
 check(game.enemies[0].hp==85.0 and game.enemies[1].hp==85.0,"heavy sweep contacts multiple nearby foes")
 game=setup([{"id":"a","x":1.1,"hp":200}])
 game.action("light")
 advance(game,0.1)
 check(game.action("heavy") and game.player.queuedHeavy,"heavy can be buffered during light attack")
 check(not game.action("light"),"queued heavy takes priority over another light input")
 advance(game,2.4)
 check(game.enemy.hp==179.0,"buffered heavy actually follows and deals damage")

 game=setup([{"id":"left","x":-1.9},{"id":"near","x":0.9},{"id":"far","x":1.8}])
 var ability_events: Array=[]
 game.event.connect(func(e: Dictionary): ability_events.append(e))
 check(game.action("ability") and game.player.attack.name=="ability","E enters ability attack and starts cooldown")
 check(game.player.skillCooldown==8.0 and game.player.skillCooldownMax==8.0,"default E cooldown is eight simulation seconds")
 advance(game,0.60)
 check(game.enemies.all(func(e: Dictionary)->bool:return e.hp==100.0),"ability windup cannot deal premature damage")
 advance(game,0.25)
 check(game.enemies.all(func(e: Dictionary)->bool:return e.hp==82.0),"ability impact damages nearby enemies on both sides")
 check(ability_events.any(func(e: Dictionary)->bool:return e.type=="ability" and e.has("facing") and e.sourceId=="player"),"ability startup event exposes its origin")
 check(ability_events.filter(func(e: Dictionary)->bool:return e.type=="hit" and e.get("skill",false)).size()==3,"ability impacts carry per-target identity and skill flag")
 advance(game,0.8)
 check(not game.action("ability"),"ability cooldown rejects early reuse")
 game.action("pause")
 var frozen: String=JSON.stringify(game.snapshot())
 advance(game,1.0)
 check(frozen==JSON.stringify(game.snapshot()),"pause freezes every enemy, cooldown and encounter statistic")
 game.action("pause")
 advance(game,8.0)
 check(game.action("ability"),"ability becomes available when cooldown expires")

 game=setup([{"id":"target","x":1.1,"hp":200}],{"maxHp":150,"hp":90,"energy":0,"damageMultiplier":2.0,"energyGain":2.0,"postureMultiplier":2.0,"skillCooldownScale":0.5,"parryHeal":7.0})
 check(game.player.hp==90.0 and game.player.maxHp==150.0 and game.player.skillCooldownMax==4.0,"encounter carries health and cooldown upgrades")
 game.action("light")
 advance(game,0.6)
 check(game.enemy.hp==188.0 and game.player.energy==14.0,"damage and energy rewards alter actual contact results")
 check(game.stats.damageDealt==12.0 and game.stats.maxCombo==1,"damage/combo statistics reflect actual damage")
 advance(game,0.3)
 game.enemy.x=1.1
 game.enemy.state="guard"
 game.enemy.stateDuration=10.0
 game.enemy.posture=50.0
 game.action("heavy")
 advance(game,1.0)
 check(game.enemy.state=="stagger" and game.enemy.posture==20.0,"posture reward improves guard breaking")

 game=setup([{"id":"attacker","type":"striker","x":1.1}],{"hp":80,"maxHp":120,"energy":0,"parryHeal":7.0})
 game._attack(game.enemy,"light")
 advance(game,game.enemy.attack.windup-0.045)
 game.action("guard")
 advance(game,0.1,0.0,true)
 check(game.player.hp==87.0 and game.stats.parries==1,"parry healing is applied only on successful parry")
 check(game.stats.damageTaken==0.0 and game.player.energy==12.0,"parry records no received health damage")
 game=setup([{"id":"attacker","type":"guardian","x":1.1}],{"energy":0})
 game._attack(game.enemy,"light")
 advance(game,float(game.enemy.attack.windup)+0.04)
 check(game.stats.damageTaken>0.0 and is_equal_approx(game.player.maxHp-game.player.hp,game.stats.damageTaken),"received-damage stats track real health loss")

 game=setup([{"id":"a","x":1.0},{"id":"b","x":2.0},{"id":"c","x":3.0}])
 var ult_events: Array=[]
 game.event.connect(func(e: Dictionary): ult_events.append(e))
 game.action("ultimate")
 advance(game,3.0)
 check(game.enemies.all(func(e: Dictionary)->bool:return e.hp==64.0),"ultimate hits every living opponent with all four cues")
 check(ult_events.filter(func(e: Dictionary)->bool:return e.type=="ultHit").size()==12,"ultimate events identify three targets across four cue times")
 check(not game.ultimate.is_empty() and game.stats.damageDealt==108.0,"multi-target cinematic retains its full duration and damage accounting")
 advance(game,0.4)
 check(game.ultimate.is_empty() and not game.ended,"nonlethal ultimate returns to encounter")
 game=setup([{"id":"a","x":1.0,"hp":10},{"id":"b","x":2.0,"hp":10}])
 var down_events: Array=[]
 game.event.connect(func(e: Dictionary): down_events.append(e))
 game.action("ultimate")
 advance(game,1.6)
 check(not game.ended and game.stats.kills==2,"multi-kill ultimate delays victory until camera sequence ends")
 advance(game,1.8)
 check(game.ended and game.winner=="player" and down_events.filter(func(e: Dictionary)->bool:return e.type=="enemyDown").size()==2,"each enemy emits down exactly once")

 game=setup([{"id":"boss","type":"boss","hp":100,"x":1.1}])
 var boss_events: Array=[]
 game.event.connect(func(e: Dictionary): boss_events.append(e))
 game.enemy.hp=55.0
 game.action("light")
 advance(game,0.5)
 check(game.enemy.phase==2 and boss_events.filter(func(e: Dictionary)->bool:return e.type=="bossPhase").size()==1,"boss crosses half health into phase two once")
 check(game.enemy.state=="attack" and game.enemy.attack.phaseTransition and game.enemy.attack.windup>=1.3,"phase transition starts a full-length visible counter windup")
 game._attack(game.enemy,"heavy")
 var red: Dictionary=boss_events[-1]
 check(red.type=="attack" and red.telegraph and red.boss and red.unblockable and red.windup>=1.0,"boss phase-two heavy advertises a long red warning")
 check(red.sourceId=="boss" and red.targetId=="player" and red.has("facing"),"enemy attacks carry stable VFX routing identity")
 var health_before: float=game.enemy.hp
 var posture_before: float=game.enemy.posture
 game._receive(game.player,game.enemy,Combat.LIGHTS[0])
 check(game.enemy.state=="attack" and game.enemy.hp==health_before-6.0 and game.enemy.posture==posture_before+12.0,"red-heavy armor preserves startup while punches damage health and posture")
 game._receive(game.player,game.enemy,Combat.ABILITY)
 check(game.enemy.state=="stagger","E breaks heavy armor before its impact")
 game._attack(game.enemy,"heavy")
 game.enemy.posture=95.0
 game._receive(game.player,game.enemy,Combat.LIGHTS[0])
 check(game.enemy.state=="stagger" and game.enemy.posture==20.0,"ordinary punches interrupt heavy armor when they break posture")
 game._attack(game.enemy,"heavy")
 game.enemy.stateTime=game.enemy.attack.windup+0.01
 game._receive(game.player,game.enemy,Combat.LIGHTS[0])
 check(game.enemy.state=="stagger","heavy armor expires at impact and leaves recovery punishable")
 game.set_training(true)
 check(game.enemies.all(func(e: Dictionary)->bool:return e.state=="idle"),"training cancels all enemy attacks")

 game=setup([{"id":"boss","type":"boss","hp":100,"x":1.1}])
 game.enemy.hp=55.0
 game.action("ultimate")
 advance(game,1.6)
 check(game.enemy.phase==2 and game.enemy.get("phaseCounterPending",false) and game.enemy.state!="attack","phase change during ultimate defers the counter until cinematic end")
 advance(game,1.8)
 check(game.ultimate.is_empty() and game.enemy.state=="attack" and game.enemy.attack.phaseTransition and game.enemy.stateTime<0.2,"deferred phase counter receives a fresh complete warning")

 game=setup([{"id":"boss","type":"boss","hp":100,"x":1.1},{"id":"escort","type":"striker","x":2.0}])
 game._attack(game.enemies[1],"light")
 game.enemies[0].hp=55.0
 game._receive(game.player,game.enemies[0],Combat.LIGHTS[0])
 check(game.enemies.filter(func(e: Dictionary)->bool:return e.state=="attack").size()==1 and game.enemies[0].state=="attack","phase counter takes the attacking turn without overlapping an escort")

 game=setup([{"id":"fast","type":"striker","x":-1.1},{"id":"tank","type":"guardian","x":1.1},{"id":"counter","type":"duelist","x":1.9}],{"maxHp":5000,"hp":5000},false)
 var ai_events: Array=[]
 game.event.connect(func(e: Dictionary): ai_events.append(e))
 var safe_spacing:=true
 var safe_attack_count:=true
 for i in 2400:
  game.update(1.0/120.0,0.0,true)
  var active: int=0
  var contact_windows: int=0
  var positions: Array[float]=[float(game.player.x)]
  for foe in game.enemies:
   if foe.state=="attack":
    active+=1
    if foe.stateTime>=foe.attack.windup and foe.stateTime<=foe.attack.windup+foe.attack.active:contact_windows+=1
   if foe.hp>0.0:positions.append(float(foe.x))
  safe_attack_count=safe_attack_count and active<=2 and contact_windows<=1
  positions.sort()
  for j in range(1,positions.size()):safe_spacing=safe_spacing and positions[j]-positions[j-1]>=GAP_EPSILON
 check(safe_attack_count,"enemy scheduler overlaps only warning/recovery, never live contact windows")
 check(safe_spacing,"crowd movement preserves one-dimensional collision spacing")
 check(ai_events.any(func(e: Dictionary)->bool:return e.type=="attack" and e.sourceId=="fast" and e.combo==1),"striker uses a real two-hit chain")
 check(ai_events.any(func(e: Dictionary)->bool:return e.type=="enemyGuard" and e.sourceId=="tank"),"guardian uses defensive turns")
 check(ai_events.any(func(e: Dictionary)->bool:return e.type=="dodge" and e.sourceId=="counter"),"duelist uses evasive turns")
 check(ai_events.any(func(e: Dictionary)->bool:return e.type=="attack" and e.sourceId=="counter"),"duelist follows evasion with a counterattack")
 check(game.stats.elapsed>10.0,"encounter elapsed statistic advances")

 game=setup([{"id":"left","x":-1.2},{"id":"right","x":1.2}])
 advance(game,5.0,1.0)
 check(game.player.x<=game.enemies[1].x-0.6999,"player cannot cross an enemy while moving right")
 advance(game,5.0,-1.0)
 check(game.player.x>=game.enemies[0].x+0.6999,"player cannot cross an enemy while moving left")
 game=setup([{"id":"same","x":1.0},{"id":"same","x":1.0},{"id":"player","x":1.0}])
 check(game.enemies[0].id!=game.enemies[1].id and game.enemies[2].id!="player","duplicate config IDs cannot corrupt event routing")
 game=setup([])
 check(game.ended and game.winner=="player","empty encounter resolves without invalid target access")
 print("PASS: ",passed," expanded encounter checks")
 quit(0)

const GAP_EPSILON:=Combat.GAP-0.0001
