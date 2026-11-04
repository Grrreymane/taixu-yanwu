extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
const PATH="res://build/screenshots/armor-paths-native"
func capture(name:String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(PATH+"/"+name+".png")
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(PATH)
 world=ProbeMain.new();world.campaign=VolatileCampaign.new();root.add_child(world)
 await process_frame
 world._action("trial");await capture("azure-core")
 world._action("night_core:az_balance");world._action("story_skip")
 world.stage_countdown=0;world.game.set_training(true);world.game.player.armorState.yang=2;world.game.player.armorState.yin=1
 await capture("azure-hud")
 world.campaign.phase="reward"
 world.campaign.reward_options=[world.campaign.REWARDS.az_echo.duplicate(true),world.campaign.REWARDS.az_bind.duplicate(true),world.campaign.REWARDS.risk.duplicate(true)]
 await capture("rewards")
 root.size=Vector2i(960,540);await capture("rewards-960")
 world._action("menu");world._action("select_style:shadow_knight");world._action("trial");await capture("moon-core-960")
 world._action("menu");world.free();world=null
 await process_frame
 print("ARMOR_VISUAL_PASS");quit()
