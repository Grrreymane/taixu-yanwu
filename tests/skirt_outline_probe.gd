extends SceneTree
## Actual menu renderer, deterministic clock. Outline A/B never changes pose.
const OUTPUT := "res://build/screenshots/skirt-outline"
var world
var label := "before"
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","taixu_memory")
		appearance_choices={"azure_empyrea":"taixu_memory"}
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
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+"-"+id+".png")
	print("CAPTURE ",label,"-",id)
func run() -> void:
	var sweep := "--sweep" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	root.size=Vector2i(2880,2000) if sweep else Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free();world.music.free();world.music=QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	world._action("menu")
	var body: MeshInstance3D=world.player.model.find_child("Body",true,false)
	var mats: Array[ShaderMaterial]=[]
	var outlines: Array[Material]=[]
	for surface in body.mesh.get_surface_count():
		var mat: ShaderMaterial=body.get_active_material(surface)
		mats.append(mat)
		outlines.append(mat.next_pass)
	print("BODY_SURFACES ",mats.size())
	if sweep:
		var full:=Image.create(8*250,4*380,false,Image.FORMAT_RGBA8)
		var clean:=Image.create(8*250,4*380,false,Image.FORMAT_RGBA8)
		for i in 32:
			step(0.73)
			await process_frame
			await RenderingServer.frame_post_draw
			var region:=Rect2i(1690,940,250,380)
			var dest:=Vector2i((i%8)*250,(i/8)*380)
			full.blit_rect(root.get_texture().get_image(),region,dest)
			for mat in mats: mat.next_pass=null
			await process_frame
			await RenderingServer.frame_post_draw
			clean.blit_rect(root.get_texture().get_image(),region,dest)
			for surface in mats.size(): mats[surface].next_pass=outlines[surface]
		full.save_png(OUTPUT+"/"+label+"-sweep.png")
		clean.save_png(OUTPUT+"/"+label+"-sweep-no-outline.png")
		quit()
		return
	for tick: float in [2.0,5.0,12.0]:
		step(tick-world.visual_time)
		await shot("menu-"+str(int(tick)))
		for mat in mats: mat.next_pass=null
		await shot("no-body-outline-"+str(int(tick)))
		for surface in mats.size(): mats[surface].next_pass=outlines[surface]
	# Inspect the same source StandBy without the rebuilt secondary solver.
	world.player._secondary.reset()
	world.player._secondary_enabled=false
	step(1.0)
	await shot("native-cloth")
	for mat in mats: mat.next_pass=null
	await shot("native-cloth-no-outline")
	quit()

