extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute("res://build/screenshots")
 world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new();root.add_child(world);world.effects.sounds.clear()
 var samples: Array=[]
 var failures:=0
 for pass_index in 12:
  root.size=Vector2i(1440,900) if pass_index%2==0 else Vector2i(960,540)
  world.campaign.begin_trial("mirror",105+pass_index)
  world.campaign.stage_index=3;world._begin_encounter(false)
  world.game.set_training(true);world.stage_countdown=0
  world.game.player.x=-1.3 if pass_index%3==0 else 1.3
  for i in world.game.enemies.size():
   var foe: Dictionary=world.game.enemies[i]
   # Keep the measured bars clear of the stage HUD at the narrow viewport.
   foe.x=-0.6+float(i)*1.5
   foe.hp=foe.maxHp*float(i+1)*0.25
  step(2.5)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var img:=root.get_texture().get_image()
  var viewport_scale:=Vector2(img.get_size())/root.get_visible_rect().size
  if pass_index<2:img.save_png("res://build/screenshots/group-health-fixed-%d.png"%pass_index)
  for foe: Dictionary in world.game.enemies:
   var marker:Dictionary=world.enemy_markers[foe.id]
   var center:Vector3=marker.holder.global_position
   var right:Vector3=world.camera.global_transform.basis.x
   var a:Vector2=world.camera.unproject_position(center-right*0.52)*viewport_scale
   var b:Vector2=world.camera.unproject_position(center+right*0.52)*viewport_scale
   var filled:=0
   for x in range(ceili(a.x),floori(b.x)):
    var color:Color=img.get_pixel(x,roundi(lerpf(a.y,b.y,(float(x)-a.x)/(b.x-a.x))))
    if color.r>0.65 and color.g>0.2 and color.g<0.75 and color.b<0.5:filled+=1
   var expected:float=foe.hp/foe.maxHp
   var observed:=float(filled)/maxf(1.0,b.x-a.x)
   var ok:=absf(observed-expected)<0.06
   samples.append({"pass":pass_index,"enemy":foe.id,"expected":expected,"observed":observed,"ok":ok})
   if not ok:
    failures+=1
    img.save_png("res://build/screenshots/group-health-failure-%d.png"%pass_index)
 world.free();world=null;await process_frame
 FileAccess.open("res://build/group-health-pixels.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"samples":samples},"  "))
 print("GROUP_HEALTH_PIXELS ",failures," / ",samples.size()," failed")
 quit(1 if failures else 0)
