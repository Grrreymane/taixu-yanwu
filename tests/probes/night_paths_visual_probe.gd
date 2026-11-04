extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
 root.size=Vector2i(1440,900)
 world=ProbeMain.new();world.campaign=VolatileCampaign.new();root.add_child(world)
 await process_frame
 world._action("select_style:night_squire")
 world._action("trial")
 await process_frame
 assert(world.night_picker.visible)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/screenshots/night-paths"))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/screenshots/night-paths/core.png")
 world._action("night_core:chain")
 assert(not world.night_picker.visible and world.game.player.nightCore=="chain")
 world.story.skip();world.stage_countdown=0.0
 world.game.set_training(true)
 world.game.player.hp=10000.0;world.game.player.maxHp=10000.0
 world.game.enemy.hp=10000.0;world.game.enemy.maxHp=10000.0
 world.game.player.x=-1.0;world.game.enemy.x=0.3
 world._action("light")
 for frame in 500:
  if world.game.player.state=="attack" and world.game.player.combo<2:world._action("light")
  await process_frame
  if world.game.player.nightFlowUntil>world.game.time:break
 assert(world.game.player.nightFlowUntil>world.game.time)
 world.game.paused=true
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/screenshots/night-paths/flow-ready.png")
 world.game.paused=false
 world.campaign.stage_index=4
 world.campaign.reward_ids.assign(["fist","flow","swift","iron"])
 world.campaign.phase="reward"
 world.campaign.reward_options=[world.campaign.REWARDS.night_open.duplicate(true),world.campaign.REWARDS.night_finish.duplicate(true),world.campaign.REWARDS.breath.duplicate(true)]
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/screenshots/night-paths/rewards.png")
 world._action("reward_0")
 assert(world.campaign.stage_index==5 and world.game.enemy.get("bossPattern","")!="")
 world._action("menu")
 assert(world.campaign.has_resume())
 world._action("continue")
 assert(world.game.player.nightCore=="chain")
 world.queue_free()
 await process_frame
 print("NIGHT_PATHS_VISUAL_PASS")
 quit()
