extends SceneTree
class TimedActor extends "res://scripts/actor.gd":
 var costs: Dictionary={}
 func _normalize_model() -> void:
  var start:=Time.get_ticks_usec();super();costs.boundsMs=(Time.get_ticks_usec()-start)/1000.0
 func _make_material(mesh: MeshInstance3D,index:int) -> Material:
  var start:=Time.get_ticks_usec();var result:=super(mesh,index)
  costs.materialsMs=float(costs.get("materialsMs",0.0))+(Time.get_ticks_usec()-start)/1000.0
  return result
const Roster=preload("res://scripts/fighter_roster.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for round_index in 2:
  for style: String in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
   var actor:=TimedActor.new();root.add_child(actor)
   var start:=Time.get_ticks_usec();actor.setup(false,Roster.resolve("fuhua",style,"default"))
   var total:float=(Time.get_ticks_usec()-start)/1000.0
   print(JSON.stringify({"style":style,"round":round_index,"totalMs":total,"costs":actor.costs,"vertices":actor._normalization.get("vertices",0)}))
   actor.free()
 await process_frame
 print("ARMOR_SETUP_COST_PASS")
 quit()
