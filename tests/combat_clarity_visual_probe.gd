extends SceneTree
## Deterministic visual fixtures. Browser acceptance uses ordinary play separately.
const OUTPUT:="res://build/screenshots/combat-clarity-native"
var world
var captures: Array=[]
class VolatileCampaign extends "res://scripts/campaign.gd":
 func _load_record() -> void: pass
 func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
 func _load_fighter_choice() -> void:
  fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
  appearance_choices={"azure_empyrea":"default"}
 func _save_fighter_choice() -> void: pass
 func _notification(_what: int) -> void: pass
class QuietMusic extends Node:
 func unlock() -> void: pass
 func toggle() -> void: pass
 func set_context(_phase: String,_paused: bool,_ultimate: bool) -> void: pass
 func tick(_delta: float) -> void: pass
 func set_focused(_focused: bool) -> void: pass
 func snapshot() -> Dictionary: return {"enabled":false}
func _initialize() -> void: call_deferred("run")
func step(seconds: float) -> void:
 var elapsed:=0.0
 while elapsed<seconds-0.000001:
  var dt:=minf(1.0/60.0,seconds-elapsed)
  world._process(dt)
  world.hud._process(dt)
  elapsed+=dt
func shot(name: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")
 captures.append({"name":name,"ko":world.knockout.snapshot(),"phase":world.campaign.phase,"healthDisplay":world.EnemyHealthDisplay.plan(world.game.enemies),"guideOpen":world.hud.is_guide_open()})
 print("CAPTURE ",name)
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 world=ProbeMain.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 world.music._player.free();world.music.free();world.music=QuietMusic.new()
 root.add_child(world)
 world.effects.sounds.clear()
 step(1.1)
 await shot("01-home")
 for style: String in ["azure_empyrea","fenghuang","night_squire"]:
  world._action("select_style:"+style)
  step(0.1)
  world.hud.open_fighter_guide()
  step(0.1)
  await shot("02-guide-"+style)
  world.hud.close_fighter_guide()
 root.size=Vector2i(960,540)
 await process_frame
 step(0.1)
 world.hud.open_fighter_guide()
 await shot("03-guide-small")
 world.hud._guide_scroll.scroll_vertical=9999
 await shot("04-guide-small-bottom")
 world.hud.close_fighter_guide()
 root.size=Vector2i(1440,900)
 await process_frame
 world._action("select_style:azure_empyrea")
 world._action("practice")
 step(0.1)
 world.game.set_training(true)
 world.game.player.x=-0.6
 world.game.enemy.x=0.8
 world.game.enemy.hp=1.0
 world.stage_countdown=0.0
 world._process(0.0)
 await shot("05-single-hp")
 world._action("light")
 for _index in 120:
  step(1.0/60.0)
  if world.knockout.active: break
 step(0.18)
 await shot("06-ko")
 world._action("pause")
 step(0.15)
 await shot("07-ko-paused")
 world._action("pause")
 step(1.3)
 await shot("08-victory")
 world._action("menu")
 world.campaign.begin_trial("mirror",104)
 world.campaign.stage_index=1
 world._begin_encounter(false)
 world.stage_countdown=0.0
 world.game.set_training(true)
 step(2.8)
 await shot("09-group-hp")
 world.game.ended=true;world.game.winner="player"
 world.campaign.finish(world.game.snapshot())
 world._process(0.0)
 await shot("10-rewards")
 root.size=Vector2i(960,540)
 await process_frame
 world._process(0.0)
 await shot("11-rewards-small")
 root.size=Vector2i(1440,900)
 await process_frame
 world._action("menu")
 world.campaign.begin_trial("mirror",104)
 world.campaign.stage_index=5
 world._begin_encounter(false)
 world.boss_entrance.clear()
 world.stage_countdown=0.0
 world.game.set_training(true)
 step(2.8)
 await shot("12-boss-hp")
 FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":"Actual Main with explicit visual scenario setup; no user saves changed.","captures":captures},"\t"))
 world.free()
 await process_frame
 quit()
