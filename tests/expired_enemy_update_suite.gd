extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
class CountedActor extends "res://scripts/actor.gd":
 var samples:=0
 func animate_fighter(f:Dictionary,d:float,t:float,u:float=-1.0) -> void:
  samples+=1;super(f,d,t,u)
func run() -> void:
 world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new();root.add_child(world);world.effects.sounds.clear()
 world.campaign.begin_trial("mirror",105);world.campaign.stage_index=3;world._begin_encounter(false)
 world.game.set_training(true);world.stage_countdown=0
 var foe:Dictionary=world.game.enemies[0];var id:=str(foe.id)
 world.enemy_nodes[id].free()
 var actor:=CountedActor.new();world.add_child(actor);actor.setup(false,world.SentienceProfile.selection())
 world.enemy_nodes[id]=actor;world.enemy_markers[id]=world._create_marker(actor,foe)
 foe.hp=0.0
 step(0.2)
 assert(actor.samples>0 and actor.visible,"the original defeat animation still plays")
 step(actor.death_duration()+0.1)
 assert(not actor.visible and not world.enemy_markers[id].holder.visible,"expired enemy and its health marker are hidden")
 var samples:=actor.samples;var sim_time:float=world.game.time
 step(1.0)
 assert(actor.samples==samples,"an invisible completed defeat no longer resamples its skeleton")
 assert(world.game.time>sim_time and not world.game.ended,"the remaining live fight continues normally")
 world._action("menu");world._action("practice");step(0.2)
 assert(world.enemy_nodes.size()==1 and world.enemy_nodes.values()[0].visible,"a new encounter has a visible fresh opponent")
 world.free();world=null;await process_frame
 print("EXPIRED_ENEMY_UPDATE_PASS");quit()
