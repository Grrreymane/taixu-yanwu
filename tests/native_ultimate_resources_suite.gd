extends SceneTree
const Effects=preload("res://scripts/effects.gd")
func _initialize():call_deferred("run")
func run():
	var fx=Effects.new();root.add_child(fx);fx.sounds.clear()
	var fighter={"id":"player","side":"player","style":"night_squire","hp":100.0,"x":0.0,"state":"idle","nightBurstRemaining":5.0}
	fx.update_fighters(fighter,[])
	for i in 120:fx.tick(1.0/120.0)
	assert(fx.active.any(func(item):return item.settings.get("role","")=="native_burst_follow"))
	assert(fx.active.size()<fx.MAX_ACTIVE)
	var count=fx.active.size();fx.tick(0);assert(fx.active.size()==count)
	fighter.nightBurstRemaining=0.0
	for i in 240:fx.tick(1.0/120.0)
	assert(fx.active.is_empty())
	fx.native_phoenix.begin({"x":-0.5,"targetX":0.5})
	fx.tick(1.55);assert(fx.native_phoenix.visible)
	var clock=fx.native_phoenix.clock;fx.tick(0);assert(fx.native_phoenix.clock==clock)
	fx.clear();assert(not fx.native_phoenix.visible and fx.active.is_empty())
	for profile in ["blood","shadow","fog"]:
		fighter={"id":"player","side":"player","style":"shadow_knight" if profile!="fog" else "hawk_of_the_fog","hp":120.0,"x":0.0,"state":"idle","facing":1,"appearanceId":"blood_moon" if profile=="blood" else "default","eclipseRemaining":4.0 if profile!="fog" else 0.0,"fogCharges":1 if profile=="fog" else 0}
		fx.update_fighters(fighter,[])
		fx.remaining_native.event({"type":"ultimateImpact" if profile!="fog" else "ultimate","style":fighter.style,"appearanceId":fighter.appearanceId,"x":0.7})
		var source_seen:=false
		for i in 120:
			fx.tick(1.0/120.0)
			assert(fx.active.size()<fx.MAX_ACTIVE)
			source_seen=source_seen or fx.active.any(func(item):return str(item.settings.get("nativeNode","")).begins_with("Avatar_Fuka_FK_AF01_Ultra/"))
		if profile!="fog":assert(fx.active.any(func(item):return item.settings.get("role","")=="source_ultimate_follow"))
		else:assert(source_seen)
		var poses=fx.active.map(func(item):return item.node.transform)
		fx.tick(0);assert(fx.active.map(func(item):return item.node.transform)==poses)
		fighter.eclipseRemaining=0.0;fighter.fogCharges=0
		for i in 480:fx.tick(1.0/120.0)
		assert(fx.active.is_empty() and fx.remaining_native.emitters.is_empty())
		fx.clear()
	assert(fx.remaining_native.meshes.size()==14)
	assert(not fx.remaining_native.catalog.has("fog_follow"))
	assert(fx.remaining_native.catalog.fog_release.all(func(row):return row.node.begins_with("Avatar_Fuka_FK_AF01_Ultra/")))
	fx.free();print("NATIVE_ULTIMATE_RESOURCES_PASS");quit()
