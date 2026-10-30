extends SceneTree
## Exercises actual combat hit events: no timed fake impact, original texture
## masks, animation pause and bounded cleanup. GPU probe checks appearance.
const Combat=preload("res://scripts/combat.gd")
const Effects=preload("res://scripts/effects.gd")
const STEP:=1.0/120.0
var checks:=0
var failures:Array[String]=[]

class QuietEffects extends Effects:
	func _sound(_key:String)->void:pass

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func run()->void:
	var fx:=QuietEffects.new();root.add_child(fx)
	for style:String in ["fenghuang","shadow_knight","hawk_of_the_fog"]:
		for facing:float in [-1.0,1.0]:
			var game:=Combat.new()
			game.set_player_profile(style)
			game.start_encounter({"training":true,"playerX":-0.7*facing,"enemies":[{"id":"foe","x":0.7*facing,"hp":1000.0}]},{"energy":100.0})
			fx.clear();fx.update_fighters(game.player,game.enemies)
			game.event.connect(fx.handle_event)
			check(game.action("ultimate"),style+" accepts real Q")
			var saw_hit:=false
			var initial_hp:float=game.enemy.hp
			for ignored in 600:
				var previous:float=game.time
				game.update(STEP)
				fx.update_fighters(game.player,game.enemies)
				fx.tick(game.time-previous)
				var core:Array=fx.active.filter(func(item):return item.settings.get("role","") in ["ultimate_flame_core","ultimate_core"] or str(item.settings.get("nativeNode","")).contains("Attack_C2_3_Ultra_Ground/"))
				if game.enemy.hp==initial_hp:
					check(core.is_empty(),style+" no impact before damage")
				elif not saw_hit:
					saw_hit=true
					check(not core.is_empty() and core[0].node.visible and core[0].mat.get_shader_parameter("opacity")>.8,style+" source impact is visible on first actual hit frame")
					var roles:Array=fx.active.map(func(item):return item.settings.get("role",""))
					if style=="fenghuang":
						check(roles.has("ultimate_flame_plume") and roles.has("ultimate_flame_outburst"),"fire impact has original flame silhouette and directional release")
					elif style=="shadow_knight":
						var bolts:Array=fx.active.filter(func(item):return item.settings.get("role","")=="ultimate_bolt_front")
						check(bolts.size()==2,"lightning hit releases paired coarse bolts")
						for bolt:Dictionary in bolts:
							check(bolt.mat.get_shader_parameter("mask_mode")==1,"opaque-alpha black-backed lightning atlas uses luminance, not alpha")
							check(bolt.mat.get_shader_parameter("uv_transform").y==.25,"one lightning row is drawn per ribbon")
					else:
						check(core.any(func(item):return item.node.mesh is ArrayMesh),"fog release uses the source shockwave/smoke geometry")
					var state:Dictionary=fx.snapshot()
					var poses:Array=fx.active.map(func(item):return item.node.transform)
					fx.tick(0)
					check(fx.snapshot()==state and fx.active.map(func(item):return item.node.transform)==poses,"pause freezes the new impact and orbit layers")
				check(fx.active.size()<fx.MAX_ACTIVE,"no VFX layer eviction during actual ultimate")
				if saw_hit and game.ultimate.is_empty():break
			check(saw_hit,style+" reached actual hit")
			fx.tick(4.0)
			check(fx.active.is_empty(),style+" all impact layers clean up")
			game.event.disconnect(fx.handle_event)
	fx.free()
	var result={"checks":checks,"passed":failures.is_empty(),"failures":failures}
	FileAccess.open("res://build/reports/ultimate-impact-layers.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
