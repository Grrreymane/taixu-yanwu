extends SceneTree
## Actual Main renderer. Menu/dialogue use real selection; combat poses are
## deterministic fixtures, separately checked through ordinary web inputs.
var output_path := "res://build/screenshots/night-squire-native"
var world
var records: Array=[]
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
	var preferred_appearance:="default"
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","night_squire",preferred_appearance)
		appearance_choices={"night_squire":preferred_appearance}
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
func shot(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_path+"/"+id+".png")
	print("CAPTURE ",id)
	records.append({"id":id,"player":world.game.player.duplicate(true),"ultimate":world.game.ultimate.duplicate(true),"motion":world.player.presentation_snapshot(),"vfx":world.effects.snapshot()})
func run() -> void:
	var appearance:="default"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--appearance="): appearance=arg.trim_prefix("--appearance=")
		if arg.begins_with("--output="): output_path="res://build/screenshots/"+arg.trim_prefix("--output=")
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	world=ProbeMain.new()
	world.preferred_appearance=appearance
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free();world.music.free();world.music=QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	step(0.8)
	await shot("01-menu")
	if "--menu" in OS.get_cmdline_user_args():
		quit();return
	world._action("start")
	step(2.0)
	await shot("02-dialogue")
	world._action("menu")
	world._action("practice")
	world.game.set_training(true)
	world.stage_countdown=0.0
	world.game.player.x=-0.65
	world.game.enemy.x=1.05
	step(0.2)
	world._action("light")
	step(0.28)
	await shot("03-punch")
	step(0.7)
	world._action("ability")
	step(0.42)
	await shot("04-ability")
	step(1.0)
	for i in 240:
		if world.game.player.state=="idle": break
		step(1.0/60.0)
	world.game.player.energy=100.0
	world._action("ultimate")
	assert(not world.game.ultimate.is_empty(),"White Night activation must actually start")
	step(0.55)
	await shot("05-burst-activation")
	step(1.1)
	world._action("light")
	step(0.28)
	await shot("06-burst-kick")
	world.game.ended=true
	world.game.winner="player"
	world.campaign.finish(world.game.snapshot())
	world._begin_victory()
	step(1.5)
	await shot("07-victory")
	step(3.3)
	await shot("08-result")
	var report:=FileAccess.open(output_path+"/report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(records,"  "))
	report.close()
	quit()
