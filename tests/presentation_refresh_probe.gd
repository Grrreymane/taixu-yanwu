extends SceneTree
## Deterministic render fixture, separate from the ordinary-input browser run.
const OUTPUT := "res://build/screenshots/presentation-refresh-native"
var world
var records: Array = []
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
	while elapsed<seconds-0.00001:
		var dt:=minf(1.0/60.0,seconds-elapsed)
		world._process(dt)
		elapsed+=dt
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")
	records.append({"name":name,"story":world.story.snapshot(),"boss":world.boss_entrance.snapshot(),"victory":world.victory.snapshot(),"vfx":world.effects.snapshot(),"sentienceVfx":world.sentience_effects.snapshot(),"player":world.player.presentation_snapshot()})
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
	world._action("start")
	step(0.25)
	world.story.advance();world.story.advance()
	step(1.9)
	await shot("01-dialogue-senti-gesture")
	world.story.advance();world.story.advance()
	step(1.2)
	await shot("02-dialogue-listener")
	world._action("menu")
	world._action("select_appearance:taixu_memory")
	world._action("start")
	step(0.25)
	world.story.advance();world.story.advance()
	step(2.0)
	await shot("03-dialogue-skin")
	world._action("menu")
	world._action("select_appearance:default")
	world.campaign.begin_trial("mirror",104)
	world.campaign.stage_index=5
	world._begin_encounter(false)
	step(1.05)
	await shot("04-boss-flourish")
	step(0.55)
	await shot("05-boss-name")
	step(1.75)
	await shot("06-boss-portrait")
	step(1.8)
	await shot("07-boss-return")
	world._action("menu")
	world._action("practice")
	world.game.set_training(true)
	world.game.player.x=-0.8
	world.game.enemy.x=1.1
	world.stage_countdown=0.0
	world._process(0.0)
	world._action("ability")
	step(0.25)
	await shot("08-azure-ability")
	step(0.45)
	await shot("08b-azure-ability-contact")
	step(0.65)
	world.game.player.energy=100.0
	world._action("ultimate")
	step(2.15)
	await shot("09-azure-ultimate")
	for appearance: String in ["default","taixu_memory"]:
		world._action("menu")
		world._action("select_style:azure_empyrea")
		world._action("select_appearance:"+appearance)
		world._action("practice")
		world.game.ended=true
		world.game.winner="player"
		world.campaign.finish(world.game.snapshot())
		world._begin_victory()
		step(0.55)
		await shot("10-victory-"+appearance+"-umbrella")
		step(1.1)
		await shot("11-victory-"+appearance+"-turn")
		step(1.25)
		await shot("12-victory-"+appearance+"-portrait")
		step(1.8)
		await shot("13-victory-"+appearance+"-results")
	world._action("menu")
	world._action("select_style:fenghuang")
	world._action("practice")
	world.game.ended=true;world.game.winner="player"
	world.campaign.finish(world.game.snapshot())
	world._begin_victory()
	step(1.8)
	await shot("14-phoenix-victory")
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":"Actual Main with deterministic scenario setup; no user saves changed. See browser report for normal-input verification.","captures":records},"\t"))
	world.free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
