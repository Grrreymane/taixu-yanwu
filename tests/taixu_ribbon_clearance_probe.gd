extends "res://tests/skin_menu_triangle_audit.gd"
## Headless attachment geometry at the exact menu screenshot time.
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void:pass
	func _save_record() -> void:pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve("fuhua","azure_empyrea","taixu_memory")
		appearance_choices={"azure_empyrea":"taixu_memory"}
	func _save_fighter_choice() -> void:pass
	func _notification(_what:int) -> void:pass
class QuietMusic extends Node:
	func unlock() -> void:pass
	func toggle() -> void:pass
	func set_context(_phase:String,_paused:bool,_ultimate:bool) -> void:pass
	func tick(_delta:float) -> void:pass
	func set_focused(_focused:bool) -> void:pass
	func snapshot() -> Dictionary:return {"enabled":false}
func _run() -> void:
	root.size=Vector2i(2880,2000)
	var world=ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED;world.campaign=VolatileCampaign.new()
	world.music._player.free();world.music.free();world.music=QuietMusic.new()
	root.add_child(world);world.effects.sounds.clear();world._action("menu")
	var actor=world.player
	var clock:=0.0
	for tick in 12:
		var remaining:=0.73
		while remaining>0.000001:
			var dt:=minf(1.0/60.0,remaining);clock+=dt;remaining-=dt
			world._process(dt)
	var triangles:=_triangles(actor)
	var data:Array=[]
	for tri in triangles:
		var ps:Array=[]
		for p:Vector3 in tri.p:ps.append([p.x,p.y,p.z])
		data.append({"surface":tri.surface,"triangle":tri.triangle,"group":tri.group,"p":ps,"weights":tri.weights})
	var bones:Array=[]
	for i in actor.skeleton.get_bone_count():
		var name:String=actor.skeleton.get_bone_name(i)
		if not ("Ribbon_" in name or "Skirt_" in name):continue
		var p:Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(i).origin
		bones.append({"id":i,"name":name,"point":[p.x,p.y,p.z]})
	_audit(actor,clock,"exact_sweep_8.76")
	FileAccess.open("res://build/reports/taixu-ribbon-contact.json",FileAccess.WRITE).store_string(JSON.stringify({"time":clock,"triangles":data,"bones":bones,"intersections":reports}))
	print("RIBBON EXACT POSE ",clock," visual ",world.visual_time," attachment triangles ",data.size())
	world.free();quit()
