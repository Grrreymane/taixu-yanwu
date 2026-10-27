extends "res://tests/probes/skin_menu_triangle_audit.gd"
const Probe=preload("res://tests/probes/azure_skirt_probe.gd")
func _run() -> void:
	root.size=Vector2i(1440,1000)
	var rows:Array=[]
	for mode:String in ["current","mesh_radius"]:
		var world=Probe.ProbeMain.new();world.process_mode=Node.PROCESS_MODE_DISABLED;world.campaign=Probe.VolatileCampaign.new()
		world.music._player.free();world.music.free();world.music=Probe.QuietMusic.new()
		root.add_child(world);world.effects.sounds.clear();world._action("menu")
		world._action("select_appearance:taixu_memory")
		if mode in ["native_menu","native_info"]:
			var library:AnimationLibrary=load("res://build/reports/azure-menu-taixu_memory.res")
			var name:="Avatar_Fuka_Ani_C5_UI_StandBy" if mode=="native_menu" else "Avatar_Fuka_Ani_C5_StandBy_info"
			world.player.animation_player.get_animation_library("").add_animation(name,library.get_animation(name))
			world.player._motions.idle={"clip":name.trim_prefix(world.player._prefix),"end":2.0}
			world.player.current_motion=""
		if mode=="no_secondary":world.player._secondary_enabled=false
		if mode=="no_hang":
			for bone:Dictionary in world.player._secondary._bones:bone.hanging=false
		if mode=="no_collision":world.player._secondary._colliders.clear()
		if mode=="mesh_radius":
			for capsule:Dictionary in world.player._secondary._colliders:
				if capsule.kind=="leg":capsule.radius=0.104 if "Thigh" in world.player.skeleton.get_bone_name(capsule.from) else 0.101
		while world.visual_time<0.5-0.000001:world._process(minf(1.0/60.0,0.5-world.visual_time))
		var triangles:=_triangles(world.player)
		_audit(world.player,0.5,mode)
		var samples:Array=[]
		for pixel:Vector2 in [Vector2(918,462),Vector2(920,478),Vector2(924,504),Vector2(925,515),Vector2(930,480),Vector2(915,470)]:
			var origin:Vector3=world.camera.project_ray_origin(pixel)
			var direction:Vector3=world.camera.project_ray_normal(pixel)
			var hits:Array=[]
			for tri:Dictionary in triangles:
				var hit=Geometry3D.ray_intersects_triangle(origin,direction,tri.p[0],tri.p[1],tri.p[2])
				if hit==null:continue
				hits.append({"distance":origin.distance_to(hit),"surface":tri.surface,"triangle":tri.triangle,"group":tri.group,"weights":tri.weights,"front":tri.normal.dot(direction)<0.0,"point":[hit.x,hit.y,hit.z]})
			hits.sort_custom(func(a:Dictionary,b:Dictionary):return a.distance<b.distance)
			samples.append({"pixel":[pixel.x,pixel.y],"hits":hits})
		rows.append({"mode":mode,"samples":samples,"secondary":world.player._secondary.snapshot(),"appearance":world.fighter.appearanceId})
		world.free()
	FileAccess.open("res://build/reports/taixu-skirt-ray.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	FileAccess.open("res://build/reports/taixu-skirt-native-menu-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	for row:Dictionary in rows:
		var brief:Array=[]
		for sample:Dictionary in row.samples:brief.append({"pixel":sample.pixel,"hits":sample.hits.slice(0,2)})
		print(JSON.stringify({"mode":row.mode,"appearance":row.appearance,"samples":brief}))
	quit()
