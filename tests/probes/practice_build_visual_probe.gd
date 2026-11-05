extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute("res://build/screenshots/practice-builds-native")
 world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new();root.add_child(world)
 for style in preload("res://scripts/armor_paths.gd").STYLES:
  world._action("menu");world._action("select_style:"+style);world._action("practice")
  world._action("practice_build")
  var row:Dictionary=world.practice_view.options[0]
  world._action("practice_core:"+str(row.id))
  for id in row.rewards:world._action("practice_perk:"+str(id))
  world._process(0.05)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/screenshots/practice-builds-native/"+style+".png")
  world._action("practice_build_cancel")
 world.free();world=null
 await process_frame;await process_frame
 print("PRACTICE_BUILD_VISUAL_PASS")
 quit()
