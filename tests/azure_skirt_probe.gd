extends SceneTree
const OUTPUT="res://build/screenshots/azure-skirt"
var world
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void:pass
	func _save_record() -> void:pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		var appearance:="taixu_memory" if "--taixu" in OS.get_cmdline_user_args() else "default"
		fighter=FighterRoster.resolve("fuhua","azure_empyrea",appearance)
		appearance_choices={"azure_empyrea":appearance}
	func _save_fighter_choice() -> void:pass
	func _notification(_what:int) -> void:pass
class QuietMusic extends Node:
	func unlock() -> void:pass
	func toggle() -> void:pass
	func set_context(_phase:String,_paused:bool,_ultimate:bool) -> void:pass
	func tick(_delta:float) -> void:pass
	func set_focused(_focused:bool) -> void:pass
	func snapshot() -> Dictionary:return {"enabled":false}
func _initialize() -> void:call_deferred("_run")
func _shot(label:String) -> void:
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
func _run() -> void:
	root.size=Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free();world.music.free();world.music=QuietMusic.new()
	root.add_child(world);world.effects.sounds.clear();world._action("menu")
	if "--review" in OS.get_cmdline_user_args():
		for at:float in [0.5,2.0,8.76]:
			while world.visual_time<at-0.000001:world._process(minf(1.0/60.0,at-world.visual_time))
			for angle:float in [-0.20,PI/2.0,PI,-PI/2.0]:
				world.character_preview.yaw=angle;world._process(0.0)
				await _shot("fixed-menu-%s-yaw%s"%[str(at),str(snappedf(angle,0.01))])
		world.hud.visible=false
		for at:float in [0.5,1.5]:
			world.player.animate_native_dialogue("Avatar_Fuka_Ani_C5_StandBy",2.016667,at,1.9,-0.2)
			await _shot("dialogue-%s"%str(at))
		world.campaign.phase="cleared"
		world._begin_victory()
		for at:float in [0.5,1.5,2.5,3.5]:
			while world.victory.time<at-0.000001:world._process(minf(1.0/60.0,at-world.victory.time))
			await _shot("fixed-victory-%s"%str(at))
		print("AZURE_SKIRT_ALL_ANGLES_COMPLETE")
		world.free();quit();return
	var body:MeshInstance3D=world.player.model.find_child("Body",true,false)
	var materials:Array=[];var outlines:Array=[]
	for surface in body.mesh.get_surface_count():
		var mat:ShaderMaterial=body.get_active_material(surface)
		materials.append(mat);outlines.append(mat.next_pass)
	var times:Array=[0.02,0.5,1.0,1.5,2.0,5.0,8.76]
	var prefix:="taixu-" if "--taixu" in OS.get_cmdline_user_args() else "default-"
	for at:float in times:
		while world.visual_time<at-0.000001:world._process(minf(1.0/60.0,at-world.visual_time))
		await _shot(prefix+"before-"+str(at))
		for mat in materials:mat.next_pass=null
		await _shot(prefix+"no-outline-"+str(at))
		for index in materials.size():materials[index].next_pass=outlines[index]
	print("AZURE_SKIRT_CAPTURE_COMPLETE surfaces=",materials.size())
	world.free();quit()
