extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Variants=preload("res://scripts/encounter_variants.gd")
var checks:=0
var failures:Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)

func _check_duel(game,label:String) -> void:
 check(game.enemies.size()==1,label+" has exactly one opponent")
 check(game.player.x<0.0 and game.enemy.x>0.0,label+" starts on opposite sides with player left")
 check(game.player.facing==1 and game.enemy.facing==-1,label+" faces inward before the first tick")
 check(game.time==0.0,label+" does not need a simulation tick to correct spawning")
 check(absf(game.player.x)<=Combat.LIMIT and absf(game.enemy.x)<=Combat.LIMIT,label+" keeps both fighters inside the arena")

func _fixtures() -> Array:
 var result:Array=[]
 for index:int in 6:
  var foes:Array=[]
  for slot:int in [1,2,2,3,2,1][index]:
   foes.append({"id":"foe_%d_%d"%[index,slot],"x":1.8+slot,"hp":100.0,"boss":index==5,"type":"boss" if index==5 else "striker"})
  result.append({"playerX":-2.0,"enemies":foes,"training":true})
 return result

func _run() -> void:
 var game:=Combat.new()
 _check_duel(game,"menu reset")
 game.start()
 _check_duel(game,"legacy sparring")
 game.start_sparring()
 _check_duel(game,"Sentience sparring")
 var mirrored_duels:=0
 for seed_value:int in 64:
  var stages:=_fixtures()
  Variants.apply(stages,seed_value)
  for index:int in stages.size():
   var config:Dictionary=stages[index]
   var unchanged:=config.duplicate(true)
   game.start_encounter(config,{"hp":63.0,"maxHp":140.0,"energy":37.0})
   check(config==unchanged,"spawn correction does not change the saved seeded encounter")
   check(is_equal_approx(game.player.hp,63.0) and is_equal_approx(game.player.energy,37.0),"spawn correction preserves carried health and energy")
   if game.enemies.size()==1:
    if float(config.playerX)>float(config.enemies[0].x): mirrored_duels+=1
    _check_duel(game,"seed %d stage %d"%[seed_value,index])
    var expected_distance:=absf(float(config.playerX)-float(config.enemies[0].x))
    check(is_equal_approx(game.enemy.x-game.player.x,expected_distance),"single-enemy spawn preserves authored attack spacing")
    game.player.x=1.5
    game.enemy.x=-1.5
    game.update(1.0/120.0)
    check(game.player.x>game.enemy.x,"fighters may switch sides during the fight without being recentered")
    game.start_encounter(config,{"hp":63.0,"maxHp":140.0,"energy":37.0})
    _check_duel(game,"restarted seed %d stage %d"%[seed_value,index])
   else:
    check(is_equal_approx(game.player.x,float(config.playerX)),"multi-enemy formation retains player placement")
    for slot:int in game.enemies.size():
     check(is_equal_approx(game.enemies[slot].x,float(config.enemies[slot].x)),"multi-enemy formation retains every flank position")
 check(mirrored_duels>0,"seed fixtures actually cover right-side duel openings")
 game.start_encounter({"playerX":5.5,"enemies":[{"x":5.5}],"training":true})
 _check_duel(game,"overlapping input")
 check(game.enemy.x-game.player.x>=Combat.GAP-0.00001,"degenerate single spawn remains separated")
 game.start_encounter({"playerX":-3.0,"enemies":[{"id":"left","x":-2.0},{"id":"right","x":2.0}],"training":true})
 game.player.x=1.0
 game.enemies[0].hp=0.0
 game.enemies[1].x=-1.0
 game.update(1.0/120.0)
 check(game.player.x>game.enemies[1].x,"defeating a bystander never respawns the remaining duel")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 var report:Dictionary={"suite":"duel_spawn","checks":checks,"passed":failures.is_empty(),"failures":failures,"mirroredDuels":mirrored_duels}
 FileAccess.open("res://build/reports/duel-spawn.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
