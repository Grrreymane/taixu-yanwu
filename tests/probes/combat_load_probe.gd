extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
## Deterministic group-fight CPU costs and pose/VFX evidence, without user saves.
class TimedActor extends "res://scripts/actor.gd":
 var costs:Dictionary={}
 func record(key:String,start:int) -> void:costs[key]=int(costs.get(key,0))+Time.get_ticks_usec()-start
 func animate_fighter(f:Dictionary,d:float,t:float,u:float=-1.0) -> void:
  var start:=Time.get_ticks_usec();super(f,d,t,u);record("actor",start)
 func _restore_source_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("reset",start)
 func _blend_source_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("blend",start)
 func _apply_guard_pose() -> void:
  var start:=Time.get_ticks_usec();super();record("guard",start)
 func _update_face_vectors() -> void:
  var start:=Time.get_ticks_usec();super();record("face",start)
class TimedEffects extends "res://scripts/effects.gd":
 var elapsed:=0
 var spawn_elapsed:=0
 var spawn_count:=0
 func tick(d:float) -> void:
  var start:=Time.get_ticks_usec();super(d);elapsed+=Time.get_ticks_usec()-start
 func _stamp(k:String,o:Vector3,s:Vector2,c:Color,l:float,options:Dictionary={}) -> Dictionary:
  var start:=Time.get_ticks_usec();var item:=super(k,o,s,c,l,options)
  spawn_elapsed+=Time.get_ticks_usec()-start;spawn_count+=1;return item
class TimedCombat extends "res://scripts/combat.gd":
 var elapsed:=0
 func update(d:float,m:float=0.0,g:bool=false) -> void:
  var start:=Time.get_ticks_usec();super(d,m,g);elapsed+=Time.get_ticks_usec()-start
func pose(actor:Node3D) -> Array:
 var values:Array=[]
 for bone in actor.skeleton.get_bone_count():
  var transform:Transform3D=actor.skeleton.get_bone_pose(bone)
  for vec:Vector3 in [transform.origin,transform.basis.x,transform.basis.y,transform.basis.z]:
   values.append_array([vec.x,vec.y,vec.z])
 return values
func run() -> void:
 var label:="sample"
 if not OS.get_cmdline_user_args().is_empty():label=OS.get_cmdline_user_args()[0]
 var core:String=OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size()>1 else ""
 assert(core.is_empty() or preload("res://scripts/night_paths.gd").CORES.has(core))
 var report:Array=[];var evidence:Array=[]
 for style:String in (["night_squire"] if not core.is_empty() else ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]):
  world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
  world.campaign=VolatileCampaign.new();world.game=TimedCombat.new();root.add_child(world)
  world._action("select_style:"+style)
  world.effects.free();world.effects=TimedEffects.new();world.add_child(world.effects);world.effects.sounds.clear()
  world.campaign.begin_trial("mirror",105,world.FighterRoster.presentation_from_selection(world.fighter),core)
  if not core.is_empty():world.campaign.reward_ids.assign(preload("res://scripts/night_paths.gd").CORES[core].rewards)
  world.campaign.stage_index=3;world._begin_encounter(false)
  world.stage_countdown=0;world.game.player.x=-0.6
  world.player.free();world.player=TimedActor.new();world.add_child(world.player);world.player.setup(false,world.fighter)
  world.game.player.hp=10000.0;world.game.player.maxHp=10000.0
  world.game.player.energy=100.0
  var i:=0
  for foe:Dictionary in world.game.enemies:
   var id:=str(foe.id);world.enemy_nodes[id].free()
   var actor:=TimedActor.new();world.add_child(actor);actor.setup(false,world.SentienceProfile.selection())
   world.enemy_nodes[id]=actor;world.enemy_markers[id]=world._create_marker(actor,foe)
   foe.x=0.6+float(i)*0.6;foe.hp=10000.0;foe.maxHp=10000.0;i+=1
  var actors:Array=[world.player]+world.enemy_nodes.values()
  var elapsed:=0;var peak_fx:=0;var peak_us:=0;var ultimate_frames:=0
  for frame in 720:
   var start:=Time.get_ticks_usec()
   if frame==0:world._action("ultimate")
   elif frame%120==0:world._action("ability")
   elif frame%90==0:world._action("heavy")
   elif frame%12==0:world._action("light")
   world.touch_guard=frame%180>=150
   world._process(1.0/60.0);world.hud._process(1.0/60.0)
   if not world.game.ultimate.is_empty():ultimate_frames+=1
   var cost:=Time.get_ticks_usec()-start;elapsed+=cost;peak_us=maxi(peak_us,cost)
   peak_fx=maxi(peak_fx,world.effects.active.size())
   if frame%30==0:
    var row:Dictionary={"style":style,"frame":frame,"poses":[],"fx":world.effects.active.size(),"sim":world.game.snapshot()}
    for actor in actors:row.poses.append(pose(actor))
    evidence.append(row)
  assert(ultimate_frames>0,"Each armor must actually perform its ultimate")
  var metrics:Dictionary={"style":style,"mean_us":float(elapsed)/720,"peak_us":peak_us,"combat_us":float(world.game.elapsed)/720,"effects_us":float(world.effects.elapsed)/720,"spawn_us":float(world.effects.spawn_elapsed)/maxi(1,world.effects.spawn_count),"spawns":world.effects.spawn_count,"peak_fx":peak_fx,"ultimate_frames":ultimate_frames,"actors":[]}
  for actor in actors:
   var entry:Dictionary={"bones":actor.skeleton.get_bone_count()}
   for key:String in actor.costs:entry[key+"_us"]=float(actor.costs[key])/720
   metrics.actors.append(entry)
  report.append(metrics);print(JSON.stringify(metrics))
  world.free();world=null;actors.clear();await process_frame
 FileAccess.open("res://build/combat-load-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
 FileAccess.open("res://build/combat-evidence-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(evidence))
 await process_frame
 await RenderingServer.frame_post_draw
 print("COMBAT_LOAD_PROBE_COMPLETE");quit()
