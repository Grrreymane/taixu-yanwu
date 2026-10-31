extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 world=ProbeMain.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 root.add_child(world)
 world.effects.sounds.clear()
 world.campaign.begin_trial("mirror",142)
 world.campaign.stage_index=3
 world.campaign.reward_ids.assign(["fist","iron","reflection"])
 world.campaign.boons.assign(["寸心如锋","破阵之势","明镜止水"])
 world._begin_encounter(false)
 world.game.set_training(true)
 world.stage_countdown=0.0
 world.campaign.phase="reward"
 world.campaign.reward_options=[world.campaign.REWARDS.chainflow.duplicate(true),world.campaign.REWARDS.focus.duplicate(true),world.campaign.REWARDS.breath.duplicate(true)]
 world.game.ended=true
 for foe: Dictionary in world.game.enemies: foe.hp=0; foe.downEmitted=true
 world.death_times.clear()
 for foe: Dictionary in world.game.enemies: world.death_times[foe.id]=10.0
 step(0.1)
 await shot("replay-rewards-large")
 root.size=Vector2i(960,540)
 await process_frame
 step(0.1)
 world.hud._layout()
 await shot("replay-rewards-small")
 world._action("reroll_rewards")
 step(0.1)
 await shot("replay-rewards-rerolled")
 world.free()
 world=null
 await process_frame
 print("REPLAY_REWARD_VISUAL_PASS")
 quit()
