extends SceneTree
## Actual main-game presentation at deterministic native-animation keyframes.
const OUTPUT := "res://build/screenshots/ultimate-refresh"
var world
var captures: Array = []
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what: int) -> void: pass
func _initialize() -> void: call_deferred("run")
func step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.000001:
		var dt := minf(1.0/120.0,seconds-elapsed)
		world._process(dt)
		world.hud._process(dt)
		elapsed+=dt
func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
	captures.append({"name":label,"profile":world.game.player_profile,"ultimateTime":world.game.ultimate.get("time",-1.0),"camera":world.cinematic_frame,"vfx":world.effects.snapshot(),"focus":world.ultimate_focus.snapshot()})
	print("CAPTURE ",label)
func run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	root.add_child(world)
	world.effects.sounds.clear()
	var profiles := {"azure_empyrea":[0.38,1.35,2.70],"fenghuang":[0.38,1.55,2.85],"night_squire":[0.35,0.90,1.35],"shadow_knight":[0.36,1.25,1.65],"hawk_of_the_fog":[0.20,0.50,0.85]}
	for profile: String in profiles:
		world._action("menu")
		world._action("select_style:"+profile)
		world._action("select_appearance:default")
		world._action("practice")
		world.game.set_training(true)
		world.game.player.x=-0.65
		world.game.enemy.x=0.70
		world.game.enemy.hp=500.0
		world.game.enemy.maxHp=500.0
		step(0.3)
		world._action("ultimate")
		var previous:=0.0
		for keyframe: float in profiles[profile]:
			step(keyframe-previous)
			await shot(profile+"-"+str(roundi(keyframe*100)))
			previous=keyframe
		step(4.2-previous)
		assert(is_equal_approx(world.arena._ultimate_exposure,1.0),"The courtyard must recover after every ultimate")
	world._action("menu")
	world.campaign.begin_trial("mirror",142)
	world.campaign.stage_index=3
	world._begin_encounter(false)
	world.game.set_training(true)
	step(0.1)
	await shot("encounter-banner")
	step(2.5)
	await shot("encounter-hud")
	root.size=Vector2i(960,540)
	await process_frame
	step(0.0)
	world.hud._layout()
	await shot("encounter-small")
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	FileAccess.open("res://build/reports/ultimate-refresh-visual.json",FileAccess.WRITE).store_string(JSON.stringify(captures,"  "))
	world.free()
	world=null
	await process_frame
	await process_frame
	print("ULTIMATE_REFRESH_VISUAL_PASS")
	quit()
