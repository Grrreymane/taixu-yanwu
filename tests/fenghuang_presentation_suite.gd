extends SceneTree

const Camera = preload("res://scripts/fenghuang_camera.gd")
var checks := 0
var failures: Array[String] = []

class FlameProbe extends "res://scripts/effects.gd":
	var heard: Array[String] = []
	func _ready() -> void:
		rng.seed = 3103
		_quad.size = Vector2.ONE
	func _sound(key: String) -> void:
		heard.append(key)

class NativeFlameProbe extends FlameProbe:
	func _ready() -> void:
		super._ready()
		# Direct PNG reads let this headless unit run before project reimport.
		for key: String in PHOENIX_FILES:
			var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/phoenix-native/"+str(PHOENIX_FILES[key])+".png"))
			native_textures[key]=ImageTexture.create_from_image(source)

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _roles(fx, role: String) -> Array:
	return fx.active.filter(func(item: Dictionary): return str(item.settings.get("role","")) == role)

func _event(kind: String, stance: String = "punch") -> Dictionary:
	return {"type":kind,"style":"fenghuang","stance":stance,"sourceId":"player","side":"player","facing":1,"x":0.0,"contactX":0.7,"targetX":1.35}

func _run() -> void:
	var fx := FlameProbe.new()
	root.add_child(fx)
	var fighter := {"id":"player","side":"player","style":"fenghuang","stance":"punch","x":0.0,"facing":1,"state":"attack","stateTime":0.0,"attack":{"name":"light","comboIndex":0,"windup":0.14}}
	fx.update_fighters(fighter,[])
	var attack := _event("attack")
	attack.merge({"name":"light","combo":0,"windup":0.14})
	fx.handle_event(attack)
	fx.tick(0.3)
	check(fx.active.is_empty(), "fire swing waits for fighter time instead of wall time")
	fighter.stateTime = 0.13
	fx.tick(0.0)
	check(fx.active.is_empty(), "zero delta also freezes pending flame cues")
	fx.tick(0.01)
	check(_roles(fx,"fist_trail").size()==1 and fx.snapshot().nativeCount==0, "punch uses one compact authored fire trail without ink")
	check(fx.heard==["swing"], "air swing has one wind sound and no fake contact")
	var fist: Dictionary = _roles(fx,"fist_trail")[0]
	check(fist.base_scale.x<1.3 and fist.life<=0.18 and fist.node.position.y<1.7, "fist trail is brief and stays below face height")
	fx.clear()
	var kick := _event("attack","kick")
	kick.merge({"name":"light","combo":0,"windup":0.25})
	fx._fire_sweep(kick)
	check(_roles(fx,"kick_sweep").size()==1 and _roles(fx,"kick_core").size()==1, "kick has its own wider low arc")
	var arc: Dictionary = _roles(fx,"kick_sweep")[0]
	check(arc.base_scale.x>2.0 and arc.node.position.y+arc.base_scale.y*0.5<2.0 and arc.node.position.z<0.0, "kick fire stays behind the body and below the face")
	fx.clear()
	var heavy := _event("attack")
	heavy.name = "heavy"
	fx._fire_sweep(heavy)
	check(_roles(fx,"phoenix_feather").size()==6, "heavy finisher uses a distinct feather-shaped flame fan")
	fx.clear()
	var switch := _event("attack","kick")
	switch.merge({"name":"ability","combo":0,"windup":0.24})
	fighter.attack = {"name":"ability","comboIndex":0,"windup":0.24}
	fighter.stateTime = 0.0
	fighter.stance = "kick"
	fx.handle_event(switch)
	fx.handle_event(_event("stanceChange","kick"))
	check(_roles(fx,"stance").size()==1 and fx._cues.size()==2, "stance event adds a small change marker without scheduling a duplicate attack")
	fighter.stateTime = 0.24
	fx.tick(0.01)
	check(_roles(fx,"kick_sweep").size()==1 and fx._cues.is_empty(), "switch attack releases exactly once at its source windup")
	fx.clear()
	var hit := _event("hit")
	fx.handle_event(hit)
	var contact: Dictionary = _roles(fx,"fire_contact")[0]
	check(is_equal_approx(contact.node.position.x,0.7) and contact.mat.get_shader_parameter("opacity")==1.0, "fire contact appears at the real contact point on the first hitstop frame")
	check(contact.base_scale.x<=0.60 and contact.base_scale.y<=0.40, "ordinary fire contact remains compact")
	var frozen: Dictionary = fx.snapshot()
	var frozen_transform: Transform3D = contact.node.transform
	fx.tick(0.0)
	check(fx.snapshot()==frozen and contact.node.transform==frozen_transform, "pause/hitstop freezes fire ages and transforms")
	fx.tick(0.03)
	check(float(fx.snapshot().fireTime)>float(frozen.fireTime), "fire effects resume on simulation delta")
	fx.clear()
	for facing: float in [-1.0,1.0]:
		var parry := _event("parry")
		parry.facing = facing
		fx.handle_event(parry)
		var catch: Dictionary = _roles(fx,"fire_parry")[0]
		check(is_equal_approx(catch.node.position.x,0.7+facing*0.28) and catch.base_scale.x<=0.72 and catch.base_scale.y<=0.82, "warm parry catch preserves hand clearance facing " + str(facing))
		check(fx.snapshot().nativeCount==0 and fx.heard.back()=="parry", "fire parry keeps defense sound without black ink")
		fx.clear()
	var block := _event("block")
	block.side = "enemy"
	block.sourceId = "enemy"
	block.targetSide = "player"
	fx.handle_event(block)
	check(_roles(fx,"fire_block").size()==1 and fx.heard.back()=="block", "incoming enemy attack uses warm player-block feedback")
	fx.clear()
	fx.handle_event(_event("ultimate"))
	check(fx.active.size()<=30 and fx.snapshot().nativeCount==0, "fire ultimate uses a bounded set of cards without native landscape or sphere")
	check(fx.active.all(func(item: Dictionary): return str(item.mode) in ["card","particles"]), "fire ultimate does not add an opaque backdrop")
	check(_roles(fx,"fire_contact").is_empty(), "the cinematic's decorative timeline cannot manufacture a hit flash")
	for item: Dictionary in fx.active:
		if float(item.time)<0.0:
			check(not item.node.visible or (item.mode=="card" and item.mat.get_shader_parameter("opacity")==0.0), "delayed flame stays hidden until its cue")
	fx.tick(1.0)
	frozen = fx.snapshot()
	fx.tick(0.0)
	check(fx.snapshot()==frozen, "all pending and visible Q effects freeze together")
	fx.clear()
	var final_hit := _event("ultHit")
	final_hit.final = true
	fx.handle_event(final_hit)
	check(_roles(fx,"phoenix_feather").size()==6 and _roles(fx,"fire_contact").size()==1 and fx.heard.back()=="heavy", "final real Q hit releases the phoenix fan and strong contact once")
	check(fx.snapshot().source=="fenghuang-authored", "telemetry identifies these effects as authored rather than native particles")
	fx.tick(0.8)
	check(fx.active.is_empty(), "final fire burst clears before combat resumes")
	fx.clear()
	var warning := _event("attack")
	warning.merge({"side":"enemy","sourceId":"enemy","telegraph":true,"windup":0.5,"name":"heavy","range":2.3},true)
	fx.handle_event(warning)
	check(fx.active.size()==1 and fx.active[0].settings.get("telegraph",false) and fx.snapshot().fireCount==0, "player style does not replace the enemy's warning wedge")
	fx.clear()
	fx.free()
	_native_texture_contract()
	_camera_contract()
	await process_frame
	print(JSON.stringify({"suite":"fenghuang_presentation","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _native_texture_contract() -> void:
	var fx := NativeFlameProbe.new()
	root.add_child(fx)
	for facing: float in [-1.0,1.0]:
		for combo: int in 3:
			var data := _event("attack")
			data.merge({"name":"light","combo":combo,"facing":facing},true)
			fx._fire_sweep(data)
			var fist: Dictionary=_roles(fx,"fist_trail")[0]
			var uv: Vector4=fist.mat.get_shader_parameter("uv_transform")
			check(fist.mode=="native" and fist.texture=="phoenix_fist" and uv.x==0.5 and uv.y==0.5 and uv.z+uv.x<=1.0 and uv.w+uv.y<=1.0,"native punch selects one valid 2x2 cell %.0f / %d" % [facing,combo])
			check(fist.mat.get_shader_parameter("mask_mode")==0 and fist.mat.get_shader_parameter("source_rgb")==true and is_equal_approx(fist.life,0.14),"native punch preserves RGB and original alpha for 0.14 seconds")
			check(fist.mat.get_shader_parameter("flip_x")==(facing>0.0) and fist.base_scale.x<=1.15 and fist.base_scale.y<=0.44,"native punch mirrors its source tip and remains compact")
			fx.clear()
		var kick:=_event("attack","kick")
		kick.merge({"name":"heavy","combo":2,"facing":facing},true)
		fx._fire_sweep(kick)
		var arc: Dictionary=_roles(fx,"kick_sweep")[0]
		check(arc.mode=="native" and arc.texture=="phoenix_arc" and arc.mat.get_shader_parameter("uv_transform")==Vector4(1.0,0.25,0.0,0.75),"native heavy kick selects the fourth horizontal source row")
		check(arc.mat.get_shader_parameter("mask_mode")==0 and arc.base_scale.y<0.5 and arc.node.position.z<0.0,"native kick uses original alpha and a narrow arc behind the body")
		fx.clear()
	fx.handle_event(_event("ultimate"))
	check(fx.active.size()<=30 and fx.snapshot().fireNativeCount==1,"Q replaces its first floor ring without adding excess cards")
	for ring: Dictionary in _roles(fx,"ground_flame"):
		check(ring.mode=="native" and ring.texture=="phoenix_ring" and ring.settings.ground and ring.mat.get_shader_parameter("mask_mode")==0,"Q floor ring uses the original hollow ring alpha")
	var ring_texture: Texture2D=fx.native_textures.phoenix_ring
	var ring_image:=ring_texture.get_image()
	check(ring_image.get_pixel(ring_image.get_width()/2,ring_image.get_height()/2).a==0.0,"original ring center stays transparent instead of becoming an opaque disc")
	check(fx.snapshot().source=="hi3-c4-textures-authored" and not fx.snapshot().textureKeys.has("taiji"),"telemetry distinguishes original C4 textures with authored timing from native particle reconstruction")
	fx.tick(0.1)
	var frozen: Dictionary=fx.snapshot()
	fx.tick(0.0)
	check(fx.snapshot()==frozen,"native fire texture ages freeze on pause and hitstop")
	fx.tick(3.8)
	check(fx.active.is_empty(),"native floor rings expire before combat resumes")
	fx.free()

func _camera_contract() -> void:
	for aspect: float in [16.0/9.0,1.6,0.75]:
		for side: float in [-1.0,1.0]:
			var focus := {"playerX":-0.7*side,"targetX":0.65*side,"facing":side,"aspect":aspect}
			for time: float in [0.0,0.2,0.55,1.0,1.5,2.10,2.17,2.4,2.82,2.89,3.15,3.8]:
				var frame: Dictionary = Camera.sample(time,focus)
				check(frame.position.is_finite() and frame.target.is_finite() and frame.position.z>=3.5 and float(frame.fov)>=31.0 and float(frame.fov)<=40.0, "fire camera keeps finite front-side framing %.2f / %.2f / %.0f" % [time,aspect,side])
				check(frame==Camera.sample(time,focus), "paused fire camera is deterministic at %.2f / %.2f / %.0f" % [time,aspect,side])
			for boundary: float in [0.22,0.75,1.65,2.10,2.25,2.45,2.82,2.97,3.15]:
				var before: Dictionary = Camera.sample(boundary-0.000001,focus)
				var after: Dictionary = Camera.sample(boundary+0.000001,focus)
				check(Vector3(before.position).distance_to(Vector3(after.position))<0.001 and absf(float(before.fov)-float(after.fov))<0.001, "camera shot joins are continuous %.2f / %.2f / %.0f" % [boundary,aspect,side])
	for at: float in [0.2,0.55,1.5,2.17,2.89,3.5]:
		var right: Dictionary = Camera.sample(at,{"playerX":-0.7,"targetX":0.65,"facing":1})
		var left: Dictionary = Camera.sample(at,{"playerX":0.7,"targetX":-0.65,"facing":-1})
		check(is_equal_approx(float(right.position.x),-float(left.position.x)) and is_equal_approx(float(right.target.x),-float(left.target.x)) and is_equal_approx(float(right.roll),-float(left.roll)), "camera mirrors player-facing instead of crossing the axis at %.2f" % at)
	var battle := {"position":Vector3(1.2,2.65,9.7),"target":Vector3(1.2,1.48,0),"fov":34.0,"roll":0.0,"shot":"battle"}
	var final: Dictionary = Camera.sample(3.8,{"playerX":5.5,"targetX":4.1,"facing":-1,"battle":battle})
	check(final.position==battle.position and final.target==battle.target and final.fov==battle.fov and final.roll==battle.roll, "fire sequence returns exactly to the supplied battle camera")
	for edge: float in [-5.5,5.5]:
		var focus := {"playerX":edge,"targetX":edge-signf(edge)*1.4,"facing":-signf(edge),"aspect":16.0/9.0}
		for at: float in [0.22,1.5,2.1,2.82]:
			var frame: Dictionary = Camera.sample(at,focus)
			check(frame.position.z>=4.9 and absf(float(frame.target.x)-edge)<1.5, "arena-edge camera stays clear of actors and near the fight %.2f / %.2f" % [edge,at])
