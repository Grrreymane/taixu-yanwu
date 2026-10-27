extends SceneTree
const Effects = preload("res://scripts/effects.gd")
var fx: Node3D
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	fx = Effects.new()
	root.add_child(fx)
	# This is a VFX lifecycle test; avoid starting 40 overlapping test sounds.
	fx.sounds.clear()
	var p: Dictionary = {"id":"p","x":-1.0,"facing":1.0,"state":"idle","stateTime":0.0}
	var b: Dictionary = {"id":"b","x":1.0,"facing":-1.0,"state":"attack","stateTime":0.0,"attack":{"name":"heavy","comboIndex":0,"windup":0.6}}
	fx.update_fighters(p,[b])
	fx.handle_event({"type":"attack","side":"enemy","sourceId":"b","x":1.0,"facing":-1.0,"name":"heavy","windup":0.6,"telegraph":true})
	fx.tick(0.05)
	assert(fx.active.size()==1)
	var t: float = fx.active[0].time
	fx.tick(0.0)
	assert(fx.active[0].time==t, "Pause advanced VFX")
	b.x = 2.0
	b.stateTime = 0.2
	fx.update_fighters(p,[b])
	fx.tick(0.05)
	assert(absf(fx.active[0].node.position.x-(2.0-2.5*0.43))<0.001, "Wrong sourceId telegraph")
	b.state = "stagger"
	fx.update_fighters(p,[b])
	fx.tick(0.01)
	assert(fx.active.is_empty() and fx._cues.is_empty(), "Interrupted attack left VFX")
	p.state="attack"
	p.stateTime=0.0
	p.attack={"name":"ability","comboIndex":0,"windup":0.68}
	fx.update_fighters(p,[b])
	fx.handle_event({"type":"ability","side":"player","sourceId":"p","x":-1.0,"windup":0.68,"range":2.65})
	p.stateTime=0.67
	fx.update_fighters(p,[b])
	fx.tick(0.05)
	assert(fx.active.size()==2, "Ability released too early")
	p.stateTime=0.68
	fx.tick(0.01)
	assert(fx.snapshot().nativeCount>2 and fx.snapshot().textureKeys.has("fluid") and fx._cues.is_empty(), "Native ability release missing")
	fx.clear()
	for i in 40: fx.handle_event({"type":"hit","x":0.0,"heavy":true})
	assert(fx.active.size()<=112, "VFX budget exceeded")
	fx.clear()
	assert(fx.active.is_empty() and fx._cues.is_empty())
	fx.handle_event({"type":"ultimate","side":"player","sourceId":"p","x":-1.0,"targetX":1.0})
	assert(fx.native_sphere.get_blend_shape_count()==1,"Native sphere morph was lost")
	fx.tick(1.95)
	assert(fx.snapshot().textureKeys.has("Sphere002 / SFX_Noise_310"), "Original ultimate mesh stage missing")
	assert(not fx.snapshot().textureKeys.has("taiji"), "Charge Taiji incorrectly used as ultimate core")
	var frozen: float=fx.snapshot().nativeTime
	fx.tick(0.0)
	assert(fx.snapshot().nativeTime==frozen,"Ultimate native mesh moved during pause")
	fx.tick(4.0)
	assert(fx.active.is_empty(),"Ultimate scenery/mesh was not released")
	print("VFX_CHECK_OK pause/source_follow/interrupt/ability_contact/budget/clear")
	if "--render" in OS.get_cmdline_user_args():
		await _render()
	fx.clear()
	fx.queue_free()
	await process_frame
	await process_frame
	quit()
func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1200,800)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root.remove_child(fx)
	viewport.add_child(fx)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(0.50,0.62,0.68)
	viewport.add_child(world)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.position=Vector3(0,5,10)
	camera.look_at(Vector3(0,1,0))
	camera.fov=38
	for i in 8:
		fx._card(i,Vector3(-3.6+float(i%4)*2.4,2.3-float(i/4)*2.1,0),Vector2(2.0,1.8),Color(0.06,0.64,0.75,1),2.0,{"secondary":Color(1,.76,.25),"ground":false})
	fx._particles(Vector3(1.2,1.3,.1),Color(1,.75,.25),24,1,true,false,true)
	fx.tick(0.4)
	for i in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://assets/vfx/vfx-shader-proof.png")
	print("VFX_RENDER_OK")

