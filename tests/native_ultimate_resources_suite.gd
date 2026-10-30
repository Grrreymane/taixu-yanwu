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
	fx.free();print("NATIVE_ULTIMATE_RESOURCES_PASS");quit()
