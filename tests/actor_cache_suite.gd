extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new();root.add_child(world)
 var original=world.player
 var original_normalization:Dictionary=original._normalization.duplicate(true)
 world._action("select_style:night_squire")
 var night=world.player
 check(night!=original and not original.visible,"outgoing actor hidden without drawing another copy")
 check(world.actor_cache.size()==1 and world.actor_cache.values().has(original),"outgoing actor retained in bounded cache")
 world._action("select_style:azure_empyrea")
 check(world.player==original,"repeat selection reuses exact original actor and resource instances")
 check(world.player._normalization==original_normalization,"native scale and grounding do not change on reuse")
 night.react_impact("parry",1.0,true)
 night.flash()
 world._action("select_style:night_squire")
 check(world.player==night and night._flash_remaining==0.0 and night._guard_weight==0.0,"reused actor resets flash and guard state")
 var mesh=night.model.find_child("Body",true,false).mesh
 world._action("select_style:fenghuang")
 world._action("select_style:night_squire")
 check(world.player==night and night.model.find_child("Body",true,false).mesh==mesh,"reuse preserves native mesh, rig and material resources")
 world._action("select_style:invalid")
 check(world.player==night,"invalid request cannot alter cached or active selection")
 world._action("practice")
 world._action("select_style:azure_empyrea")
 check(world.player==night,"combat cannot swap to a cached armor")
 world._action("menu")
 world._action("select_style:shadow_knight")
 var moon=world.player
 moon._set_native_form(true)
 world._action("select_style:night_squire")
 world._action("select_style:shadow_knight")
 check(world.player==moon and not moon._eclipse_form,"return from burst appearance restores normal form")
 for style:Dictionary in world.FighterRoster.list_styles():
  world._action("select_style:"+str(style.id))
  for skin:Dictionary in world.FighterRoster.list_appearances("fuhua",str(style.id)):
   world._action("select_appearance:"+str(skin.id))
   check(world.player.ready_for_combat,"all skins remain selectable")
   check(world.actor_cache.size()<=world.ACTOR_CACHE_LIMIT,"cache cannot grow with wardrobe browsing")
   check(not world.player in world.actor_cache.values(),"active actor is never an eviction candidate")
   for cached in world.actor_cache.values():check(not cached.visible,"cached actors remain hidden")
   await process_frame
 check(not is_instance_valid(original),"least recently used actor is actually freed after wardrobe traversal")
 mesh=null # Release the test's retained mesh reference before shutting down.
 world.free();world=null;await process_frame
 await process_frame
 print("ACTOR_CACHE_SUITE ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
