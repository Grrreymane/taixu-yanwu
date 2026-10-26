extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const NativeCombat=preload("res://scripts/sentience_combat.gd")
var passed:=0
var failures: Array[String]=[]
class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if type!=Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

func check(value: bool,message: String) -> void:
 if not value:
  failures.append(message)
  print("CHECK FAILED: "+message)
 passed+=1

func setup():
 var game=Combat.new()
 game.set_training(true)
 game.start()
 game.player.x=-0.6
 game.enemy.x=0.6
 return game

func advance(game,seconds: float,guard: bool=false) -> void:
 for i in ceili(seconds*120.0): game.update(1.0/120.0,0.0,guard)

func _initialize() -> void:
 OS.add_logger(recorder)
 var game=setup()
 var events: Array=[]
 game.event.connect(func(e: Dictionary): events.append(e))
 game.action("light")
 for i in 60:
  game.update(1.0/120.0)
  if game.hit_stop>0.0: break
 check(game.enemy.hp==94.0 and game.hit_stop>0.05,"contact creates damage and a real pause")
 check(is_equal_approx(game.enemy.x,0.6),"contact does not teleport its target before the freeze")
 var time_before: float=game.time
 var player_clock: float=game.player.stateTime
 var foe_clock: float=game.enemy.stateTime
 advance(game,0.025)
 check(game.time==time_before and game.player.stateTime==player_clock and game.enemy.stateTime==foe_clock,"hitstop freezes both action clocks")
 check(is_equal_approx(game.enemy.x,0.6),"knockback also waits through hitstop")
 advance(game,0.10)
 check(game.enemy.x>0.6 and game.enemy.x<0.73,"body carries the strike over several frames after contact")
 var hit: Dictionary=events.filter(func(e: Dictionary)->bool:return e.type=="hit")[0]
 check(hit.facing==1.0 and hit.contactX<0.6 and hit.hitStop>0.05,"contact reports its surface point and force direction")

 game=setup()
 game.action("light")
 advance(game,0.05)
 check(not game.action("guard") and game.player.state=="attack","guard cannot cancel a committed windup")
 advance(game,0.35)
 check(game.action("guard") and game.player.state=="guard","guard can interrupt attack recovery")
 advance(game,0.1,true)
 check(game.player.state=="guard","holding guard maintains the defensive state")
 advance(game,0.02)
 check(game.player.state=="idle","releasing guard returns control")

 game=setup()
 game.action("heavy")
 check(game.player.attack.windup==0.5,"player heavy has a shorter committed startup")
 game.enemy.weaponLock="chain"
 game._attack(game.enemy,"heavy")
 check(is_equal_approx(game.enemy.attack.windup,NativeCombat.attack("chain",0,false,1).windup) and game.enemy.attack.windup>=0.70,"enemy chain heavy retains its actual native definition and readable warning")
 advance(game,0.16)
 check(not game.action("dodge"),"dodge does not erase a heavy windup")

 game=setup()
 game.enemy.x=-4.0
 game.action("heavy")
 advance(game,0.90)
 check(game.enemy.hp==100.0 and game.hit_stop==0.0,"a missed heavy creates no hitstop or damage")

 game=setup()
 game._receive(game.player,game.enemy,Combat.LIGHTS[0])
 var light_stop: float=game.hit_stop
 game=setup()
 game._receive(game.player,game.enemy,Combat.HEAVY)
 check(game.hit_stop>light_stop,"heavy contact has a stronger pause than a light strike")
 check(game.action("ultimate"),"ultimate can begin after contact in the test setup")
 check(game.player.get("pushRemaining",0.0)==0.0 and game.enemy.pushRemaining==0.0,"cinematic clears pending physical impulses")

 game=setup()
 game.enemy.hp=1.0
 game._receive(game.player,game.enemy,Combat.HEAVY)
 check(game.ended and game.hit_stop>0.0,"the final blow retains its contact pause")
 var end_clock: float=game.time
 advance(game,0.15)
 check(game.hit_stop==0.0 and game.time==end_clock,"final contact pause drains without resuming combat")
 check(recorder.errors.is_empty(),"no nested script or engine errors were swallowed")
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"combat_feel","checks":passed,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors}))
 quit(0 if failures.is_empty() else 1)
