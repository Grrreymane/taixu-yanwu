extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var passed:=0

func advance(game,seconds: float,movement: float=0.0,guard: bool=false) -> void:
 var remaining: float=seconds
 while remaining>0.000001:
  var dt: float=minf(remaining,1.0/120.0)
  game.update(dt,movement,guard)
  remaining-=dt

func close_range(game) -> void:
 game.player.x=-0.6
 game.enemy.x=0.6

func setup(training: bool=true):
 var game=Combat.new()
 game.set_training(training)
 game.start()
 close_range(game)
 return game

func check(ok: bool,message: String) -> void:
 if not ok:
  push_error("FAIL: "+message)
  quit(1)
  assert(ok,message)
 passed+=1

func wait_attack(game) -> void:
 for i in 480:
  if game.enemy.state=="attack": return
  game.update(1.0/120.0)

func _initialize() -> void:
 var game=Combat.new()
 check(not game.action("light"),"menu gates attacks")
 game=setup()
 game.action("light")
 advance(game,0.12)
 check(game.enemy.hp==100.0,"windup has no premature contact")
 check(game.action("light"),"buffer the second strike")
 for i in 240:
  if game.player.combo==1: break
  game.update(1.0/120.0)
 advance(game,0.1)
 check(game.action("light"),"buffer the third strike")
 advance(game,2.0)
 check(game.enemy.hp==77.0,"three source-timed attacks deal 23 damage")
 game.action("pause")
 var snapshot: String=JSON.stringify(game.snapshot())
 advance(game,0.5,1.0)
 check(snapshot==JSON.stringify(game.snapshot()),"pause freezes the entire simulation")
 game=setup(false)
 wait_attack(game)
 advance(game,game.enemy.attack.windup-0.045)
 game.action("guard")
 advance(game,0.1,0.0,true)
 check(game.player.hp==100.0 and game.enemy.state=="stagger","timed guard parries")
 game=setup(false)
 game.action("guard")
 for i in 300:
  game.update(1.0/120.0,0.0,true)
  if game.player.posture>0.0: break
 check(game.player.hp==100.0 and game.player.posture>0.0,"held guard accumulates posture")
 game=setup(false)
 wait_attack(game)
 advance(game,game.enemy.attack.windup-0.045)
 game.action("dodge")
 advance(game,0.45)
 check(game.player.hp==100.0,"timed dodge avoids contact")
 check(not game.action("dodge"),"dodge cooldown prevents spam")
 game=setup()
 game.enemy.state="guard"
 game.enemy.stateDuration=10.0
 game.enemy.posture=80.0
 game.action("heavy")
 advance(game,0.9)
 check(game.enemy.hp==100.0 and game.enemy.state=="stagger","heavy breaks guard")
 game=setup(false)
 check(game.action("ultimate"),"ultimate starts with full energy")
 advance(game,3.0)
 check(game.enemy.hp==64.0 and game.player.energy==0.0,"four ultimate cues total 36 damage")
 check(not game.ultimate.is_empty(),"cinematic remains active before its end")
 advance(game,0.4)
 check(game.ultimate.is_empty() and game.player.state=="idle","ultimate restores control")
 game=setup()
 game.enemy.hp=10.0
 game.action("ultimate")
 advance(game,1.6)
 check(not game.ended and game.enemy.hp==0.0,"lethal cinematic waits for the finish")
 advance(game,1.8)
 check(game.ended and game.winner=="player","cinematic victory resolves")
 game.start()
 check(game.player.hp==100.0 and game.enemy.hp==100.0,"restart restores both fighters")
 advance(game,6.0,-1.0)
 check(game.player.x==-5.5,"arena boundary clamps movement")
 advance(game,6.0,1.0)
 check(game.enemy.x-game.player.x>=0.6999,"fighters cannot cross through each other")
 print("PASS: ",passed," Godot combat checks")
 quit(0)
