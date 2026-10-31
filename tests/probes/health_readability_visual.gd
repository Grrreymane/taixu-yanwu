extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 world=ProbeMain.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 root.add_child(world)
 world.effects.sounds.clear()
 world.campaign.begin_trial("mirror",105)
 world.campaign.stage_index=1
 world._begin_encounter(false)
 world.game.set_training(true)
 world.stage_countdown=0
 world.game.enemies[0].hp=world.game.enemies[0].maxHp*0.5
 step(2.5)
 for foe: Dictionary in world.game.enemies:
  var marker: Dictionary=world.enemy_markers[foe.id]
  assert(marker.holder.visible)
  assert(marker.health.text=="HP %d / %d"%[ceili(foe.hp),ceili(foe.maxHp)])
  assert(is_equal_approx(marker.fill.scale.x,foe.hp/foe.maxHp))
  assert(marker.fill.material_override.billboard_keep_scale)
 assert(not world.hud._enemy_panel.visible)
 await shot("health-group")
 root.size=Vector2i(960,540)
 await process_frame
 step(0.1)
 await shot("health-group-small")
 world.game.enemies[0].hp=0
 step(0.1)
 assert(not world.enemy_markers[world.game.enemies[0].id].holder.visible)
 assert(world.enemy_markers[world.game.enemies[1].id].holder.visible)
 assert(not world.hud._enemy_panel.visible)
 root.size=Vector2i(1440,900)
 await process_frame
 world.campaign.stage_index=5
 world._begin_encounter(false)
 step(0.01)
 world._action("boss_skip")
 world.game.set_training(true)
 step(1.2)
 assert(not world.boss_entrance.active)
 world.stage_countdown=0
 world.game.enemy.hp=130
 world.game.enemy.posture=75
 step(0.1)
 assert(world.hud._enemy_resources.text=="HP 130 / 260   ·   架势 %d / 100" % roundi(world.game.enemy.posture))
 assert(world.hud.visible and world.hud._enemy_panel.is_visible_in_tree())
 assert(not world.enemy_markers[world.game.enemy.id].holder.visible)
 await shot("health-boss")
 world.free()
 world=null
 await process_frame
 print("HEALTH_READABILITY_VISUAL_PASS")
 quit()
