extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
class TimedActor extends "res://scripts/actor.gd":
 var timings: Dictionary={}
 func record(key: String, start: int) -> void:
  timings[key]=int(timings.get(key,0))+Time.get_ticks_usec()-start
 func animate_fighter(f:Dictionary,d:float,t:float,u:float=-1.0) -> void:
  var start:=Time.get_ticks_usec();super(f,d,t,u);record("actor",start)
 func _restore_source_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("reset_pose",start)
 func _apply_chain_extent(f:float) -> void:
  var start:=Time.get_ticks_usec();super(f);record("chain",start)
 func _blend_source_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("blend",start)
 func _apply_guard_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("guard",start)
 func _update_face_vectors() -> void:
  var start:=Time.get_ticks_usec();super();record("face",start)
func run() -> void:
 world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new();root.add_child(world)
 world.effects.sounds.clear()
 var rows: Array=[]
 for style: String in ["azure_empyrea","night_squire","shadow_knight"]:
  world._action("menu");world._action("select_style:"+style);world._action("practice")
  world.game.set_training(true);world.game.set_infinite_hp(true);world.stage_countdown=0
  world.player.free();world.player=TimedActor.new();world.add_child(world.player);world.player.setup(false,world.fighter)
  for foe: Dictionary in world.game.enemies:
   var id:=str(foe.id);world.enemy_nodes[id].free()
   var actor:=TimedActor.new();world.add_child(actor);actor.setup(false,world.SentienceProfile.selection())
   world.enemy_nodes[id]=actor;world.enemy_markers[id]=world._create_marker(actor,foe)
  world.game.player.x=-0.6;world.game.enemy.x=0.6
  step(0.1)
  var actors: Array=[world.player]+world.enemy_nodes.values()
  for actor in actors:actor.timings.clear()
  var total:=0
  for frame in 600:
   var start:=Time.get_ticks_usec()
   if frame==60:world._action("ultimate")
   elif frame%20==0:world._action("light")
   world._process(1.0/60.0);world.hud._process(1.0/60.0)
   total+=Time.get_ticks_usec()-start
  var row: Dictionary={"style":style,"main_mean_us":float(total)/600.0,"actors":[]}
  for actor in actors:
   var entry: Dictionary={"bones":actor.skeleton.get_bone_count()}
   for key: String in actor.timings:entry[key+"_us"]=float(actor.timings[key])/600.0
   row.actors.append(entry)
  rows.append(row)
  print(JSON.stringify(row))
 world.free();world=null
 await process_frame
 print("FRAME_COST_PROBE_PASS")
 quit()
