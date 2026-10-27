extends Node3D
## Native C5 ink textures use alpha blending; procedural cards remain for enemy warnings.
const CARD_SHADER := preload("res://shaders/vfx_card.gdshader")
const NATIVE_SHADER := preload("res://shaders/native_ink.gdshader")
const SPHERE_SHADER := preload("res://shaders/native_ink_sphere.gdshader")
const SPHERE_MOTION := preload("res://scripts/native_sphere_motion.gd")
const PARTICLE_SHADER := preload("res://shaders/vfx_particles.gdshader")
const LIGHTNING_EFFECTS := preload("res://scripts/lightning_effects.gd")
const MAX_ACTIVE := 112
const INK := Color(0.025, 0.065, 0.095, 0.8)
const GOLD := Color(1.0, 0.73, 0.26, 1.0)
const DANGER := Color(0.92, 0.19, 0.13, 0.92)
const SENTI_RED := Color(0.77, 0.12, 0.28, 0.92)
const BLACK := Color(0.012,0.016,0.023,0.96)
const PAPER := Color(0.96,0.98,1.0,0.94)
const STRIKE_DEPTH := 0.72
const FLAME := Color(1.0,0.28,0.055,0.86)
const EMBER := Color(0.92,0.095,0.025,0.68)
const FIRE_LIGHT := Color(1.0,0.82,0.38,0.92)
const SOUND_LEVELS := {"swing":-16.0,"swing_heavy":-14.0,"hit":-8.0,"hit_alt":-8.3,"kick":-7.8,"heavy":-6.7,"block":-10.0,"block_heavy":-8.8,"parry":-7.8,"ultimate":-11.0}
const SOUND_PRIORITY := {"swing":1,"swing_heavy":1,"hit":2,"hit_alt":2,"kick":2,"heavy":3,"block":2,"block_heavy":3,"parry":4,"ultimate":4}
const SOUND_PITCHES := {"hit":[1.0,0.975,1.025],"hit_alt":[1.0,1.022,0.98],"kick":[1.0,0.98,1.015],"heavy":[1.0,0.985,1.012],"block":[1.0,1.025,0.98],"block_heavy":[1.0,0.985],"swing":[1.0,1.03,0.98]}
const NATIVE_FILES := {"brush":"Fx_Line_54","curl":"Fx_Line_55","drops":"Fx_Line_56","splashes":"Fx_Nature_44","impact":"Fx_Nature_47","taiji":"Fx_Symbol_09","fluid":"SFX_Fluid_304","mountains":"SFX_Nature_626_Cloud","landscape":"SFX_Icon_304","noise":"SFX_Noise_311","smoke":"SFX_Smoke_301","trail":"SFX_Trail_311","swirl":"SFX_Noise_316","victory_feather":"Fx_Symbol_01","victory_glow":"Fx_Glow_03"}
const PHOENIX_FILES := {"phoenix_fist":"SmokeTrail_02","phoenix_arc":"SFX_Ray_503","phoenix_ring":"Bonus Shield-2"}
const NIGHT_FILES := {"night_trail":"trail_2_new","night_burst_trail":"trail_3_new","night_spark":"Spark_3","night_ring":"Circle explosion-2","night_rays":"Optical Radiation","night_glow":"Seele_Glow_505","night_circle":"circle","night_smoke":"SFX_Smoke_503"}
var active: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var audio_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var sound_cursor := 0
var _sound_clock := 0.0
var _last_sounds: Dictionary = {}
var _sound_variants: Dictionary = {}
var palette := Color(0.12, 0.72, 0.83, 0.9)
var _fighters: Dictionary = {}
var _cues: Array[Dictionary] = []
var _dodge_steps: Dictionary = {}
var _particle_meshes: Dictionary = {}
var _quad := QuadMesh.new()
var native_textures: Dictionary = {}
var native_sphere: Mesh
var _arc_shape: ArrayMesh
var _ring_shape: ArrayMesh
var lightning := LIGHTNING_EFFECTS.new()

func _ready() -> void:
	rng.seed = 3103
	_quad.size = Vector2.ONE
	for key: String in NATIVE_FILES:
		native_textures[key]=load("res://assets/vfx/native/"+str(NATIVE_FILES[key])+".png")
	for key: String in PHOENIX_FILES:
		var path: String="res://assets/vfx/phoenix-native/"+str(PHOENIX_FILES[key])+".png"
		if ResourceLoader.exists(path): native_textures[key]=load(path)
	for key: String in NIGHT_FILES:
		var path: String="res://assets/vfx/night-squire-native/"+str(NIGHT_FILES[key])+".png"
		if ResourceLoader.exists(path): native_textures[key]=load(path)
	# These original C4_Dress01 end-burst dependencies were already exported
	# alongside the sword mesh. Their atlas/alpha are shared flame artwork.
	for entry: Array in [["phoenix_flame","Fire_1"],["phoenix_explosion","explosionpoint1"]]:
		var path: String="res://assets/phoenix-fire-sword/vfx/"+str(entry[1])+".png"
		if ResourceLoader.exists(path): native_textures[str(entry[0])]=load(path)
	native_sphere=load("res://assets/vfx/native/Sphere002-morph.res")
	lightning.setup(self)
	for key: String in SOUND_LEVELS:
		var path: String = "res://assets/audio/" + key + ".wav"
		if ResourceLoader.exists(path): sounds[key] = load(path)
	for i: int in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		audio_players.append(player)

func set_palette(color: Color) -> void:
	palette = Color(color, 0.9)

func snapshot() -> Dictionary:
	var count: int=0
	var elapsed: float=0.0
	var keys: Array[String]=[]
	var fire_count := 0
	var fire_native_count := 0
	var fire_time := 0.0
	var fire_roles: Array[String] = []
	var night_count:=0
	for item: Dictionary in active:
		if str(item.settings.get("style",""))=="night_squire" and item.time>=0.0: night_count+=1
		if str(item.settings.get("style","")) == "fenghuang" and item.time >= 0.0:
			fire_count += 1
			fire_time += float(item.time)
			if str(item.mode)=="native": fire_native_count+=1
			var role: String = str(item.settings.get("role","flame"))
			if not fire_roles.has(role): fire_roles.append(role)
		if str(item.mode) in ["native","sphere","native_sword"] and item.time>=0.0:
			count+=1
			elapsed+=float(item.time)
			var key: String=str(item.get("texture",""))
			if not keys.has(key): keys.append(key)
	var result := {"source":"hi3-c3-textures-adapted" if night_count>0 else "hi3-c4-textures-authored" if fire_native_count > 0 else "fenghuang-authored" if fire_count > 0 else "hi3-c5-native" if not native_textures.is_empty() else "procedural","nativeCount":count,"proceduralCount":active.size()-count,"textureKeys":keys,"loadedTextures":native_textures.keys(),"nativeTime":elapsed,"fireCount":fire_count,"fireNativeCount":fire_native_count,"fireTime":fire_time,"fireRoles":fire_roles,"nightCount":night_count,"total":active.size()}
	result.merge(lightning.snapshot())
	if int(result.shadowKnightCount)>0 or int(result.hawkFogCount)>0: result.source="hi3-nl-fk-textures-adapted"
	elif int(result.nativeSwordCount)>0: result.source="hi3-c4-dress01-native-sword-adapted"
	return result

func clear() -> void:
	for item: Dictionary in active:
		if is_instance_valid(item.node): item.node.queue_free()
	active.clear()
	_cues.clear()
	_dodge_steps.clear()
	lightning.clear()
	_last_sounds.clear()
	_sound_variants.clear()
	for player: AudioStreamPlayer in audio_players: player.stop()

func update_fighters(player: Dictionary, enemies: Array) -> void:
	_fighters.clear()
	_store_fighter(player, "player")
	for i: int in enemies.size():
		if enemies[i] is Dictionary:
			_store_fighter(enemies[i], "enemy" if i == 0 else "enemy" + str(i))

func _store_fighter(fighter: Dictionary, fallback: String) -> void:
	var id: String = str(fighter.get("id", fallback))
	_fighters[id] = fighter
	_fighters[fallback] = fighter
	lightning.observe(fighter)
	if str(fighter.get("state", "")) == "dodge":
		var step: int = mini(3, int(float(fighter.get("stateTime", 0.0)) / 0.075))
		if step > int(_dodge_steps.get(id, 0)):
			if lightning.supported(fighter):
				var data := fighter.duplicate()
				data.direction=fighter.get("dodgeDirection",-1.0)
				lightning.dash(data)
			elif fighter.get("side",fallback) == "player" and fighter.get("style","") == "night_squire":
				_night_dash({"x":fighter.get("x",0.0),"direction":fighter.get("dodgeDirection",-1.0)})
			elif fighter.get("side",fallback) == "player" and fighter.get("style","") == "fenghuang":
				_fire_dodge(float(fighter.get("x",0.0)),float(fighter.get("dodgeDirection",-1.0)))
			else:
				_speed_streaks(float(fighter.get("x", 0.0)), float(fighter.get("dodgeDirection", -1.0)), step)
		_dodge_steps[id] = step
	else: _dodge_steps.erase(id)

func _source_id(data: Dictionary) -> String:
	return str(data.get("sourceId", data.get("side", "player")))

func _facing(data: Dictionary) -> float:
	var fighter: Dictionary = _fighters.get(_source_id(data), {})
	return -1.0 if float(data.get("facing", fighter.get("facing", 1.0 if data.get("side", "player") == "player" else -1.0))) < 0.0 else 1.0

func _sound(key: String) -> void:
	if not sounds.has(key) or audio_players.is_empty(): return
	if _sound_clock - float(_last_sounds.get(key, -1.0)) < 0.045: return
	var player: AudioStreamPlayer = _audio_voice(int(SOUND_PRIORITY.get(key,2)))
	if player == null: return
	_last_sounds[key] = _sound_clock
	sound_cursor += 1
	player.stop()
	player.stream = sounds[key]
	var pitches: Array = SOUND_PITCHES.get(key,[1.0])
	var variant: int = int(_sound_variants.get(key,0))
	player.pitch_scale = float(pitches[variant % pitches.size()])
	_sound_variants[key] = variant + 1
	player.volume_db = float(SOUND_LEVELS.get(key, -10.0))
	player.set_meta("feedback_priority",int(SOUND_PRIORITY.get(key,2)))
	player.set_meta("feedback_serial",sound_cursor)
	player.set_meta("feedback_sound",key)
	player.play()

func _audio_voice(priority: int) -> AudioStreamPlayer:
	# A wind cue must not cut the contact it accompanies, or a perfect catch.
	var candidate: AudioStreamPlayer = null
	for player: AudioStreamPlayer in audio_players:
		if not player.playing: return player
		var current: int = int(player.get_meta("feedback_priority",0))
		if current > priority: continue
		if candidate == null or current < int(candidate.get_meta("feedback_priority",0)) or (current == int(candidate.get_meta("feedback_priority",0)) and int(player.get_meta("feedback_serial",0)) < int(candidate.get_meta("feedback_serial",0))):
			candidate = player
	return candidate

func _hit_sound(data: Dictionary) -> String:
	if bool(data.get("heavy",false)) or bool(data.get("skill",false)) or bool(data.get("final",false)): return "heavy"
	if str(data.get("type","")) == "ultHit": return "hit"
	if str(data.get("side","player")) == "player" and str(data.get("stance","punch")) == "kick": return "kick"
	return "hit_alt" if int(data.get("combo",data.get("comboIndex",0))) % 2 == 1 else "hit"

func _block_sound(data: Dictionary) -> String:
	return "block_heavy" if bool(data.get("heavy",false)) or bool(data.get("skill",false)) else "block"

func _contact_origin(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("contactX",data.get("x",0.0))),float(data.get("contactY",data.get("contactHeight",1.33))),0.52)

func _guard_contact(data: Dictionary) -> Dictionary:
	var contact: Dictionary=data.duplicate(true)
	# Combat's generic torso contact is too low for the raised-arm guard.
	contact.contactY=float(data.get("guardContactY",2.05))
	return contact

func _contact_flash(data: Dictionary, blocked: bool = false, parried: bool = false) -> void:
	var strong: bool=bool(data.get("heavy",false)) or bool(data.get("skill",false)) or bool(data.get("final",false))
	var cinematic: bool = str(data.get("type","")) == "ultHit"
	var origin: Vector3=_contact_origin(data)
	var size:=Vector2(0.54,0.30) if blocked else Vector2(0.80,0.46) if strong else Vector2(0.44,0.27)
	if cinematic: size = Vector2(0.88,0.55) if strong else Vector2(0.58,0.38)
	if parried: size=Vector2(0.64,0.48)
	var flash: Dictionary=_card(1,origin,size,Color(0.60,0.87,1.0) if blocked or parried else Color(1.0,0.90,0.68),0.10 if parried else 0.065 if strong or cinematic else 0.05,{"angle":-0.18*_facing(data),"secondary":Color(1.0,0.99,0.92),"grow":1.0,"contact":true})
	# Event callbacks run before tick(0) during hit stop. Show this frame now.
	flash.mat.set_shader_parameter("opacity",1.0)
	flash.mat.render_priority=8
	if parried:
		var edge: Dictionary=_card(1,origin+Vector3(0,0,0.01),Vector2(0.28,0.62),Color(0.78,0.96,1.0),0.10,{"angle":0.55,"secondary":Color.WHITE,"contact":true})
		edge.mat.set_shader_parameter("opacity",1.0)
		edge.mat.render_priority=9

func _block_impact(data: Dictionary) -> void:
	# Combat identifies the attacking source on a block. The guard's element
	# belongs to its defender, so do not use a Sentience attack's style here.
	var defender: Dictionary=_fighters.get(str(data.get("targetId","player")),{})
	if lightning.supported(defender):
		var contact_data := data.duplicate()
		contact_data.style=str(defender.style)
		lightning.impact(contact_data,true)
		return
	if lightning.supported(data):
		lightning.impact(data,true)
		return
	if str(data.get("style",""))=="night_squire" and str(data.get("targetSide","player"))=="player":
		_contact_flash(_guard_contact(data),true)
		_sound(_block_sound(data))
		return
	if str(data.get("style","")) == "fenghuang" and str(data.get("targetSide","player")) == "player":
		_fire_guard(data, false)
		return
	var contact: Dictionary=_guard_contact(data)
	var origin: Vector3=_contact_origin(contact)
	var facing: float=_facing(data)
	_stamp("curl",origin-Vector3(0,0,0.06),Vector2(0.55,0.70),Color(0.73,0.85,0.91,0.70),0.15,{"rgb":true,"angle":0.2*facing,"facing":facing,"instant":true,"grow":0.9})
	_contact_flash(contact,true)
	_sound(_block_sound(data))

func _parry_impact(data: Dictionary) -> void:
	var contact: Dictionary=_guard_contact(data)
	var facing: float=_facing(data)
	# Place the catch just ahead of the guarding hands, clear of the face.
	contact.contactX=float(data.get("contactX",data.get("x",0.0)))+facing*0.28
	var origin: Vector3=_contact_origin(contact)
	# Distinct cold catch, using the original C5 brush alpha as two short arcs.
	# It deliberately has no normal-hit ink burst or black splatter branch.
	_stamp("brush",origin-Vector3(0,0,0.035),Vector2(0.72,0.82),Color(0.25,0.84,0.98,0.90),0.20,{"arc":true,"angle":-0.45*facing,"facing":facing,"instant":true,"grow":0.85,"spin_speed":5.0*facing,"priority":5,"role":"parry"})
	_stamp("brush",origin+Vector3(0,0,0.02),Vector2(0.58,0.68),Color(0.88,0.99,1.0,0.94),0.16,{"arc":true,"angle":2.45*facing,"facing":facing,"instant":true,"grow":0.9,"spin_speed":-4.5*facing,"priority":6,"role":"parry"})
	_particles(origin,Color(0.66,0.94,1.0),12,facing,false,false,true)
	_compact_last_particles(0.22,2.3,TAU)
	_contact_flash(contact,true,true)
	_sound("parry")

func _reserve() -> void:
	if active.size() < MAX_ACTIVE: return
	var expired: Dictionary = active.pop_front()
	if is_instance_valid(expired.node): expired.node.queue_free()

func _card(shape: int, origin: Vector3, size: Vector2, color: Color, life: float, settings: Dictionary = {}) -> Dictionary:
	_reserve()
	var node := MeshInstance3D.new()
	node.mesh = _quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 5.0
	node.position = origin
	var mat := ShaderMaterial.new()
	mat.shader = CARD_SHADER
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("secondary", settings.get("secondary", GOLD))
	mat.set_shader_parameter("seed", rng.randf_range(0.0, 50.0))
	mat.set_shader_parameter("opacity", 0.0)
	node.material_override = mat
	node.scale = Vector3(size.x, size.y, 1.0)
	if bool(settings.get("ground", false)): node.rotation.x = -PI / 2.0
	else: node.rotation.z = float(settings.get("angle", 0.0))
	if float(settings.get("facing", 1.0)) < 0.0: node.scale.x = -node.scale.x
	add_child(node)
	var item: Dictionary = {"node":node, "mat":mat, "time":-float(settings.get("delay", 0.0)), "life":maxf(life, 0.01), "mode":"card", "base_scale":node.scale, "settings":settings}
	active.append(item)
	return item

func _stamp(key: String, origin: Vector3, size: Vector2, color: Color, life: float, settings: Dictionary = {}) -> Dictionary:
	if not native_textures.has(key): return {}
	_reserve()
	var node := MeshInstance3D.new()
	node.mesh = _ring_mesh() if bool(settings.get("annulus",false)) else _ink_arc_mesh() if bool(settings.get("arc",false)) else _quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 10.0
	node.position = origin
	var mat := ShaderMaterial.new()
	mat.shader = NATIVE_SHADER
	mat.set_shader_parameter("source_texture",native_textures[key])
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("mask_mode",int(settings.get("mask",0)))
	mat.set_shader_parameter("source_rgb",bool(settings.get("rgb",false)))
	mat.set_shader_parameter("energy_core",bool(settings.get("energy_core",false)))
	mat.set_shader_parameter("flip_x",not bool(settings.get("arc",false)) and float(settings.get("facing",1.0))<0.0)
	mat.set_shader_parameter("uv_transform",settings.get("uv",Vector4(1,1,0,0)))
	mat.set_shader_parameter("uv_velocity",settings.get("uv_velocity",Vector2.ZERO))
	mat.set_shader_parameter("wrap_uv",bool(settings.get("wrap",false)))
	mat.set_shader_parameter("opacity",1.0 if bool(settings.get("instant",false)) else 0.0)
	mat.render_priority=int(settings.get("priority",0))
	if bool(settings.get("dissolve",false)) and native_textures.has("noise"):
		mat.set_shader_parameter("dissolve_texture",native_textures.noise)
		mat.set_shader_parameter("use_dissolve",true)
		mat.set_shader_parameter("noise_velocity",Vector2(0,0.05 if key=="curl" else -0.05))
	node.material_override=mat
	node.scale=Vector3(size.x,size.y,1.0)
	if bool(settings.get("arc",false)): node.scale.x*=float(settings.get("facing",1.0))
	if bool(settings.get("ground",false)):
		node.rotation.x=-PI/2.0
		node.rotation.y=float(settings.get("angle",0.0))
	else: node.rotation.z=float(settings.get("angle",0.0))
	add_child(node)
	var item: Dictionary={"node":node,"mat":mat,"time":-float(settings.get("delay",0.0)),"life":maxf(life,0.01),"mode":"native","texture":key,"base_scale":node.scale,"origin":origin,"settings":settings}
	# Delayed cinematic layers must remain hidden before their first tick too.
	node.visible = float(item.time) >= 0.0
	if bool(settings.get("instant",false)): node.scale=item.base_scale*float(settings.get("grow",0.75))
	active.append(item)
	return item

func _ring_mesh() -> ArrayMesh:
	# ND's white ring texture needs ring geometry; a billboard quad would
	# incorrectly display its opaque center as a disk or square.
	if _ring_shape!=null: return _ring_shape
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 64:
		var a:=float(index)/64.0*TAU
		var b:=float(index+1)/64.0*TAU
		for sample: Vector2 in [Vector2(a,0.47),Vector2(a,0.5),Vector2(b,0.5),Vector2(a,0.47),Vector2(b,0.5),Vector2(b,0.47)]:
			var point:=Vector2(cos(sample.x),sin(sample.x))*sample.y
			surface.set_uv(Vector2(0.5,0.5)+point*0.5)
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3(point.x,point.y,0))
	_ring_shape=surface.commit()
	return _ring_shape

func _ink_arc_mesh() -> ArrayMesh:
	if _arc_shape!=null: return _arc_shape
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 32:
		var u0: float=float(i)/32.0
		var u1: float=float(i+1)/32.0
		for uv: Vector2 in [Vector2(u0,0),Vector2(u0,1),Vector2(u1,1),Vector2(u0,0),Vector2(u1,1),Vector2(u1,0)]:
			var theta: float=lerpf(-2.5,1.9,uv.x)
			var radius: float=lerpf(0.25,0.50,uv.y)
			mesh.set_uv(uv)
			mesh.add_vertex(Vector3(cos(theta)*radius,sin(theta)*radius,0))
	_arc_shape=mesh.commit()
	return _arc_shape

func _ink_drops(origin: Vector3, facing: float, strong: bool=false, compact: bool=false) -> void:
	for i: int in ((4 if strong else 2) if compact else (7 if strong else 4)):
		var cell: int=rng.randi_range(0,3)
		var uv := Vector4(0.5,0.5,float(cell%2)*0.5,float(cell/2)*0.5)
		var velocity := Vector3(facing*rng.randf_range(0.6,2.5),rng.randf_range(-0.4,1.4),0)
		var size: float=rng.randf_range(0.12 if compact else 0.25,0.30 if compact else 0.65)*(1.15 if compact and strong else 1.3 if strong else 1.0)
		var life: float=0.14+rng.randf()*0.07 if compact else 0.45+rng.randf()*0.25
		_stamp("splashes",origin,Vector2.ONE*size,BLACK if i%3!=0 else PAPER,life,{"uv":uv,"angle":rng.randf()*TAU,"velocity":velocity,"grow":0.5,"fade_start":0.3})

func _native_sweep(data: Dictionary) -> void:
	var facing: float=_facing(data)
	var fighter: Dictionary=_fighters.get(_source_id(data),{})
	var x: float=float(fighter.get("x",data.get("x",0.0)))
	var combo: int=int(data.get("combo",0))
	var strong: bool=str(data.get("name","")) in ["heavy","ability"] or combo==2
	# The old ribbons sat behind the opaque body/coat at z=-0.16. Keep the
	# contact ribbon on the near side, while ground/ambient wash remains behind.
	var origin:=Vector3(x+facing*0.78,1.15 if strong else 1.46,STRIKE_DEPTH)
	var angle: float=(-0.30 if combo==0 else 0.65 if combo==1 else -0.6)*facing
	var size:=Vector2(2.95,2.10) if strong else Vector2(2.0,1.40)
	_stamp("brush",origin+Vector3(0,0,-0.04),size*1.08,BLACK,0.30 if strong else 0.20,{"arc":true,"angle":angle,"facing":facing,"grow":0.82,"spin_speed":-2.2*facing,"dissolve":true,"instant":true,"role":"attack_ribbon","priority":2})
	_stamp("brush",origin+Vector3(0,0,0.04),size*0.74,Color(PAPER,0.84),0.21 if strong else 0.14,{"arc":true,"angle":angle+0.13,"facing":facing,"grow":0.82,"spin_speed":-2.2*facing,"instant":true,"role":"attack_ribbon","priority":3})
	if strong or combo==1:
		_stamp("curl",origin+Vector3(facing*0.12,-0.12,-0.10),Vector2(0.90,1.05) if strong else Vector2(0.75,0.90),Color(0.686,0.686,0.686,0.60 if strong else 0.48),0.24 if strong else 0.17,{"rgb":true,"angle":angle,"facing":facing,"grow":0.7,"dissolve":true})
	if strong:
		_stamp("drops",Vector3(x+facing*0.8,0.06,0),Vector2(2.7,1.65),BLACK,0.48,{"ground":true,"grow":0.5,"dissolve":true})
		if str(data.get("name",""))=="heavy":
			_stamp("taiji",Vector3(x,0.06,0),Vector2.ONE*3.0,Color.WHITE,0.55,{"rgb":true,"ground":true,"grow":0.5,"spin_speed":0.4})

func _native_impact(data: Dictionary) -> void:
	var x: float=float(data.get("contactX",data.get("x",0.0)))
	var facing: float=_facing(data)
	var final: bool=bool(data.get("final",false))
	var strong: bool=bool(data.get("heavy",false)) or bool(data.get("skill",false)) or final
	var cinematic: bool=str(data.get("type",""))=="ultHit"
	var origin: Vector3=_contact_origin(data)
	var scale_factor: float=0.85 if strong else 0.48 if cinematic else 0.38
	_stamp("impact",origin,Vector2.ONE*1.7*scale_factor,Color(BLACK,0.76 if strong or cinematic else 0.66),0.36 if cinematic else 0.24 if strong else 0.145,{"angle":rng.randf()*TAU,"grow":0.45,"dissolve":true,"instant":true,"role":"hit_core"})
	_stamp("impact",origin+Vector3(0,0,0.025),Vector2.ONE*0.9*scale_factor,PAPER,0.20 if cinematic else 0.14 if strong else 0.09,{"angle":rng.randf()*TAU,"grow":0.65,"instant":true,"role":"hit_core"})
	if strong or cinematic:
		_stamp("drops",origin+Vector3(0,0,-0.25),Vector2.ONE*2.0*scale_factor,Color(BLACK,0.66),0.48 if cinematic else 0.22,{"angle":rng.randf()*TAU,"grow":0.6,"dissolve":true})
	if strong and not cinematic:
		# Native HittingOther uses SFX_Fluid_304: select one atlas row and carry
		# the burst away from the contact along the actual strike direction.
		_stamp("fluid",origin+Vector3(facing*0.28,0,-0.04),Vector2(1.85,0.72),BLACK,0.22,{"uv":Vector4(1,0.5,0,0),"facing":-facing,"velocity":Vector3(facing*1.8,0.03,0),"instant":true,"grow":0.65,"dissolve":true,"role":"directional_hit"})
		_stamp("fluid",origin+Vector3(facing*0.24,0,0.04),Vector2(1.35,0.38),PAPER,0.14,{"uv":Vector4(1,0.5,0,0),"facing":-facing,"velocity":Vector3(facing*1.5,0.03,0),"instant":true,"grow":0.75,"role":"directional_hit"})
	_ink_drops(origin,facing,strong,not cinematic)
	_contact_flash(data)
	_sound(_hit_sound(data))
	if final:
		_stamp("impact",Vector3(x,0.075,0),Vector2.ONE*6.0,BLACK,0.68,{"ground":true,"grow":0.4,"dissolve":true})
		_stamp("brush",Vector3(x,0.55,-0.15),Vector2(6.5,2.0),BLACK,0.56,{"arc":true,"angle":-0.4,"spin_speed":-1.8,"grow":0.35,"dissolve":true})
		_stamp("brush",Vector3(x,0.55,0.2),Vector2(5.4,1.6),PAPER,0.42,{"arc":true,"angle":1.4,"spin_speed":-1.8,"grow":0.4})

func _native_ability(data: Dictionary) -> void:
	var fighter: Dictionary=_fighters.get(_source_id(data),{})
	var x: float=float(fighter.get("x",data.get("x",0.0)))
	var facing: float=_facing(data)
	_stamp("taiji",Vector3(x,0.07,0),Vector2.ONE*4.0,Color.WHITE,0.58,{"rgb":true,"ground":true,"grow":0.4,"spin_speed":0.4})
	_stamp("fluid",Vector3(x+facing*0.75,1.1,-0.28),Vector2(3.1,1.55),BLACK,0.36,{"uv":Vector4(1,0.5,0,0),"facing":-facing,"grow":0.45,"dissolve":true})
	_stamp("brush",Vector3(x,0.95,-0.20),Vector2(4.3,2.2),PAPER,0.30,{"arc":true,"angle":0.4,"grow":0.5,"spin_speed":-2.0*facing})
	_stamp("drops",Vector3(x,0.15,0.1),Vector2(3.7,1.5),BLACK,0.48,{"grow":0.3,"dissolve":true})
	# A low, travelling black/white front makes the release legible in side
	# view. The native source points towards -X, hence the opposite UV facing.
	_stamp("fluid",Vector3(x+facing*1.0,0.87,STRIKE_DEPTH),Vector2(3.25,1.12),BLACK,0.40,{"uv":Vector4(1,0.5,0,0),"facing":-facing,"grow":0.78,"velocity":Vector3(facing*1.9,0.03,0),"dissolve":true,"instant":true,"role":"ability_front","priority":2})
	_stamp("fluid",Vector3(x+facing*1.10,0.87,STRIKE_DEPTH+0.04),Vector2(2.6,0.65),PAPER,0.28,{"uv":Vector4(1,0.5,0,0),"facing":-facing,"grow":0.78,"velocity":Vector3(facing*1.9,0.03,0),"instant":true,"role":"ability_front","priority":3})
	_ink_drops(Vector3(x,1.0,0.45),facing,true,true)

func _native_ultimate(data: Dictionary) -> void:
	var x: float=float(data.get("x",0.0))
	var target_x: float=float(data.get("targetX",x+1.0))
	var mid: float=(x+target_x)*0.5
	var facing: float=_facing(data)
	_sound("ultimate")
	# The actual C5 landscape and mountain layers replace the training set during the cinematic.
	_stamp("landscape",Vector3(mid,3.6,-7.0),Vector2(60,24),Color.WHITE,3.42,{"rgb":true,"grow":1.0,"fade_in":0.01,"fade_start":0.99,"priority":-20})
	_stamp("mountains",Vector3(mid,1.2,-2.8),Vector2(24,6),Color.WHITE,3.38,{"rgb":true,"grow":1.0,"fade_in":0.08,"fade_start":0.95,"priority":-10})
	# Reuse the C5 brush/taiji source art in a spatial gathering composition.
	# The emitter paths are authored for this arena; the sphere still uses the
	# extracted mesh, morph and original motion curves below.
	_stamp("taiji",Vector3(x,0.065,0),Vector2.ONE*4.8,Color(1,1,1,0.78),1.75,{"rgb":true,"ground":true,"delay":0.20,"grow":0.3,"spin_speed":-0.65*facing,"fade_start":0.8,"role":"ink_seal"})
	for layer: int in 3:
		var phase: float=float(layer)*TAU/3.0
		_stamp("brush",Vector3(x,3.45,-0.42),Vector2(2.5,0.75),Color(BLACK,0.76),1.35,{"arc":true,"delay":0.26+layer*0.10,"grow":0.5,"angle":phase,"spin_speed":-2.0*facing,"orbit":Vector3(0.60,0.24,0.38),"orbit_phase":phase,"orbit_speed":2.6*facing,"fade_start":0.74,"dissolve":true,"role":"ink_gather"})
		_stamp("fluid",Vector3(x-facing*(1.15+layer*0.22),0.5+layer*0.32,-0.35),Vector2(1.9,0.40),Color(BLACK,0.68),0.72,{"delay":0.35+layer*0.22,"uv":Vector4(1,0.5,0,0),"facing":facing,"angle":facing*0.72,"velocity":Vector3(facing*0.8,1.8,0),"grow":0.35,"dissolve":true,"role":"ink_lift"})
	# Prefab-local stages: 0.25 s opening, 1.65 s Sphere_Ani,
	# 1.85 s End and 2.5 s ground impact. Space is fitted to the side-view arena.
	_native_sphere(Vector3(x,3.55,-0.32),Vector3(x,3.75,-0.32),0.10,1.55,0.72,false)
	_stamp("smoke",Vector3(x,3.6,-0.38),Vector2(2.3,2.2),Color(BLACK,0.72),1.55,{"delay":0.1,"grow":0.1,"fade_in":0.25,"fade_start":0.8})
	_native_sphere(Vector3(target_x,3.65,-0.20),Vector3(target_x,1.8,0.05),1.65,SPHERE_MOTION.DURATION,0.5,true)
	for i: int in 4:
		var delay: float=0.25+float(i)*0.33
		_stamp("brush",Vector3(mid,0.3+float(i%2)*0.35,-0.4),Vector2(4.1,1.45),Color(BLACK,0.6),0.7,{"arc":true,"delay":delay,"angle":float(i)*1.9,"spin_speed":-1.7,"grow":0.3,"dissolve":true})
		_stamp("brush",Vector3(x,3.6,-0.35),Vector2(2.7,1.8),Color(PAPER,0.65),0.7,{"arc":true,"delay":delay,"angle":float(i)*2.1,"spin_speed":2.0,"grow":0.3})
	_stamp("fluid",Vector3(target_x,2.15,-0.1),Vector2(3.0,1.0),Color(BLACK,0.6),0.6,{"uv":Vector4(1,0.5,0,0),"delay":1.85,"angle":PI/2.0,"grow":0.7,"dissolve":true})
	_stamp("brush",Vector3(target_x,2.3,-0.5),Vector2(3.7,2.5),Color(BLACK,0.7),0.60,{"arc":true,"delay":1.72,"angle":0.7,"spin_speed":-4.2*facing,"grow":0.50,"dissolve":true,"role":"ink_release"})
	_stamp("impact",Vector3(target_x,0.08,0),Vector2.ONE*6.6,BLACK,0.65,{"delay":2.5,"ground":true,"grow":0.25,"dissolve":true})
	_stamp("drops",Vector3(target_x,0.65,-0.10),Vector2(5.2,2.2),BLACK,0.6,{"delay":2.63,"grow":0.3,"dissolve":true})

func _native_victory(data: Dictionary) -> void:
	# Verified Avatar_Fuka_IN_Victory_FX YM / YM TW feather and LZ glow.
	# Source references and particle ranges are retained in victory-source-manifest.
	# The source emitter geometry is not ported; these paths fit the camera orbit.
	var x: float=float(data.get("x",0.0))
	for index: int in 8:
		var side: float=-1.0 if index%2==0 else 1.0
		var delay: float=float(index)*0.23
		var origin:=Vector3(x+side*(0.65+float(index%3)*0.17),1.05+float(index%3)*0.27,0.4 if index%2==0 else -0.35)
		_stamp("victory_feather",origin,Vector2(0.50,0.25),Color(0.90,0.72,0.60,0.78),1.65,{"delay":delay,"rgb":true,"billboard":true,"angle":side*0.45,"spin_speed":side*0.7,"velocity":Vector3(side*0.15,-0.23,side*0.06),"grow":1.0,"fade_start":0.70,"role":"victory_feather"})
	for index: int in 14:
		var angle: float=float(index)*2.39996
		var origin:=Vector3(x+cos(angle)*0.92,0.5+float(index%5)*0.29,sin(angle)*0.55)
		_stamp("victory_glow",origin,Vector2.ONE*0.065,Color(0.55,0.16,0.12,0.85),0.65,{"delay":0.15+float(index)*0.19,"rgb":true,"billboard":true,"velocity":Vector3(0,0.24,0),"grow":0.4,"role":"victory_glow"})

func _native_sphere(origin: Vector3, destination: Vector3, delay: float, life: float, radius: float, falling: bool) -> void:
	_reserve()
	var node:=MeshInstance3D.new()
	node.mesh=native_sphere
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position=origin
	node.rotation.x=-PI/2.0
	var mat:=ShaderMaterial.new()
	mat.shader=SPHERE_SHADER
	mat.set_shader_parameter("ink_noise",load("res://assets/vfx/native/SFX_Noise_310.png"))
	mat.set_shader_parameter("smoke_mask",load("res://assets/vfx/native/SFX_Mask_306.png"))
	node.material_override=mat
	add_child(node)
	active.append({"node":node,"mat":mat,"time":-delay,"life":life,"mode":"sphere","texture":"Sphere002 / SFX_Noise_310","origin":origin,"destination":destination,"radius":radius,"settings":{"falling":falling}})

func _sphere_growth(t: float) -> float:
	# Original SM_Q size-over-lifetime X curve, from validated Unity particle data.
	var curve: Array[Vector2]=[Vector2(0,0),Vector2(0.294,0.231),Vector2(0.459,0.217),Vector2(0.600,0.504),Vector2(0.724,0.580),Vector2(0.785,0.897),Vector2(0.844,0.883),Vector2(0.95,1),Vector2(1,0)]
	for i: int in range(1,curve.size()):
		if t<=curve[i].x:
			return lerpf(curve[i-1].y,curve[i].y,inverse_lerp(curve[i-1].x,curve[i].x,t))
	return 0.0

func _particle_mesh(count: int) -> ArrayMesh:
	if _particle_meshes.has(count): return _particle_meshes[count]
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i: int in count:
		var seed_color := Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			vertices.append(Vector3(uv.x - 0.5, uv.y - 0.5, 0.0))
			uvs.append(uv)
			colors.append(seed_color)
		for index: int in [0, 1, 2, 0, 2, 3]: indices.append(i * 4 + index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_particle_meshes[count] = mesh
	return mesh

func _particles(origin: Vector3, color: Color, count: int, facing: float, big: bool = false, ink: bool = false, radial: bool = false) -> void:
	_reserve()
	var node := MeshInstance3D.new()
	node.mesh = _particle_mesh(count)
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 8.0
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("ink", ink)
	mat.set_shader_parameter("direction", 0.15 if facing > 0.0 else PI - 0.15)
	mat.set_shader_parameter("spread", TAU if radial else 2.1)
	mat.set_shader_parameter("speed", 5.0 if big else 3.0)
	mat.set_shader_parameter("gravity", 2.8 if ink else 1.2)
	var life: float = 0.62 if ink else 0.40 if not big else 0.52
	mat.set_shader_parameter("lifetime", life)
	node.material_override = mat
	add_child(node)
	active.append({"node":node, "mat":mat, "time":0.0, "life":life, "mode":"particles", "settings":{}})

func _compact_last_particles(life: float, speed: float, spread: float) -> void:
	if active.is_empty() or str(active.back().mode) != "particles": return
	var item: Dictionary = active.back()
	item.life = life
	item.mat.set_shader_parameter("lifetime",life)
	item.mat.set_shader_parameter("speed",speed)
	item.mat.set_shader_parameter("spread",spread)

func _shock(x: float, radius: float, color: Color, life: float = 0.5) -> void:
	_card(3, Vector3(x, 0.035, 0.0), Vector2.ONE * radius * 2.0, color, life, {"ground":true})
	_card(2, Vector3(x, 0.025, 0.0), Vector2(radius * 1.7, radius * 1.05), Color(INK, 0.34), life * 1.55, {"ground":true, "grow":0.65})

func _speed_streaks(x: float, direction: float, step: int = 0) -> void:
	_stamp("brush",Vector3(x-direction*0.55,0.9,-0.08),Vector2(2.1,0.65),Color(BLACK,0.65),0.35,{"facing":direction,"grow":0.6,"dissolve":true})
	_stamp("smoke",Vector3(x-direction*0.25,0.45,0.12),Vector2(1.6,1.2),Color(BLACK,0.8),0.5,{"grow":0.4,"dissolve":true})
	if step==0: _stamp("drops",Vector3(x,0.05,0),Vector2(2,1.1),BLACK,0.55,{"ground":true,"grow":0.5})

func _schedule(data: Dictionary, time: float, cue: String) -> void:
	var source: String=_source_id(data)
	# Ability has both an attack and an ability event; replace, never double fire.
	for index: int in range(_cues.size()-1,-1,-1):
		if str(_cues[index].source)==source and str(_cues[index].kind)==cue: _cues.remove_at(index)
	_cues.append({"data":data.duplicate(true),"at":maxf(time,0.0),"kind":cue,"source":source,"last_clock":-1.0,"attack_name":str(data.get("name","ability" if cue=="ability" else "light")),"combo":int(data.get("combo",data.get("comboIndex",0)))})
	if _cues.size() > 32: _cues.pop_front()

func _cancel_cues(source: String) -> void:
	for index: int in range(_cues.size()-1,-1,-1):
		if str(_cues[index].source)==source: _cues.remove_at(index)

func _attack_sweep(data: Dictionary) -> void:
	if str(data.get("style",""))=="sentience": return
	if lightning.supported(data):
		lightning.sweep(data)
		return
	if _player_night(data):
		_night_sweep(data)
		return
	if str(data.get("side","player"))=="player":
		if _player_fire(data): _fire_sweep(data)
		else: _native_sweep(data)
		return
	var facing: float = _facing(data)
	var fighter: Dictionary = _fighters.get(_source_id(data), {})
	var x: float = float(fighter.get("x", data.get("x", 0.0)))
	var heavy: bool = bool(data.get("heavy", false)) or str(data.get("name", "")) in ["heavy", "ability"]
	var color: Color = SENTI_RED if str(data.get("style",""))=="sentience" else DANGER if str(data.get("side", "player")) != "player" else palette
	var combo: int = int(data.get("combo", data.get("comboIndex", 0)))
	var origin := Vector3(x + facing * (0.75 if heavy else 0.6), 1.1 if combo == 2 else 1.42, 0.32)
	var angle: float = -0.6 if combo == 1 else 0.6 if combo == 2 else -0.15
	var size := Vector2(2.25, 1.55) if heavy else Vector2(1.65, 1.0)
	_card(0, origin + Vector3(0, 0, -0.04), size * 1.08, Color(INK, 0.65), 0.25 if heavy else 0.16, {"angle":angle, "facing":facing, "spin_speed":-2.0, "secondary":INK})
	_card(0, origin, size, color, 0.23 if heavy else 0.15, {"angle":angle, "facing":facing, "spin_speed":-2.0})
	if heavy: _shock(x + facing * 0.75, 1.35, Color(color, 0.72), 0.42)

func _ability_release(data: Dictionary) -> void:
	if lightning.supported(data):
		lightning.sweep(data,true)
		return
	if _player_night(data):
		_night_sweep(data,true)
		return
	if str(data.get("side","player"))=="player":
		if _player_fire(data): _fire_sweep(data, true)
		else: _native_ability(data)
		return
	var fighter: Dictionary = _fighters.get(_source_id(data), {})
	var x: float = float(fighter.get("x", data.get("x", 0.0)))
	var radius: float = clampf(float(data.get("range", 2.4)), 1.6, 3.0)
	var color: Color = SENTI_RED if str(data.get("style",""))=="sentience" else DANGER if str(data.get("side", "player")) != "player" else palette
	_shock(x, radius, color, 0.55)
	_card(1, Vector3(x, 1.0, 0.38), Vector2(2.5, 1.5), GOLD, 0.22, {"secondary":Color(1, 0.97, 0.75)})
	_particles(Vector3(x, 0.9, 0.35), color, 28, _facing(data), true, false, true)
	_particles(Vector3(x, 0.45, 0.25), INK, 20, _facing(data), true, true, true)

func _impact(data: Dictionary) -> void:
	if lightning.supported(data):
		lightning.impact(data)
		return
	if _player_night(data):
		_night_impact(data)
		return
	if str(data.get("style",""))=="sentience" and str(data.get("type",""))=="hit":
		_sound(_hit_sound(data))
		return
	if _player_fire(data):
		if str(data.get("type","")) == "parry": _fire_guard(data, true)
		else: _fire_impact(data)
		return
	if str(data.get("type",""))=="parry":
		_parry_impact(data)
		return
	if str(data.get("side","player"))=="player" or str(data.get("type",""))=="ultHit":
		_native_impact(data)
		return
	var final: bool = bool(data.get("final", false))
	var strong: bool = bool(data.get("heavy", false)) or bool(data.get("skill", false)) or final
	var facing: float = _facing(data)
	var x: float = float(data.get("contactX",data.get("x",0.0)))
	var origin: Vector3=_contact_origin(data)
	if strong:
		_card(2, origin + Vector3(facing * 0.09, 0, -0.10), Vector2(0.92,0.56), Color(INK,0.48),0.19,{"grow":0.55})
	_particles(origin,GOLD,10 if strong else 6,facing,strong)
	_compact_last_particles(0.25 if strong else 0.17,2.6 if strong else 2.0,1.25)
	_contact_flash(data)
	_sound(_hit_sound(data))
	if final:
		_card(7, Vector3(x, 1.7, -0.12), Vector2(1.1, 4.0), GOLD, 0.48, {"secondary":Color(1.0, 0.98, 0.78)})
		_card(0, Vector3(x, 1.1, 0.35), Vector2(3.6, 2.0), palette, 0.38, {"spin_speed":3.0})
		_particles(Vector3(x, 0.3, 0.35), GOLD, 36, facing, true, false, true)

func handle_event(data: Dictionary) -> void:
	var kind: String = str(data.get("type", ""))
	var x: float = float(data.get("x", 0.0))
	var facing: float = _facing(data)
	match kind:
		"reset": clear()
		"attack":
			var windup: float = float(data.get("windup", 0.2))
			if bool(data.get("parryFollowup",false)) and float(data.get("chaseAdvance",0.0))>0.55:
				if lightning.supported(data): lightning.dash(data)
				elif _player_night(data): _night_dash(data)
				else: _speed_streaks(x,facing)
			_cancel_cues(_source_id(data))
			var heavy: bool=str(data.get("name","light")) in ["heavy","ability"]
			_schedule(data,maxf(0.0,windup-(0.11 if heavy else 0.07)),"wind")
			if str(data.get("name",""))=="ability": _schedule(data,windup,"ability")
			else: _schedule(data,maxf(0.0,windup-0.02),"sweep")
			if bool(data.get("telegraph", false)):
				var reach: float = clampf(float(data.get("range", 2.5)), 1.4, 4.6)
				var warning_color: Color = GOLD if str(data.get("telegraphColor", "red")) == "amber" else DANGER
				_card(5, Vector3(x + facing * reach * 0.43, 0.045, 0), Vector2(reach * 1.25, 1.45), warning_color, windup + 0.15, {"ground":true, "facing":facing, "follow_id":_source_id(data), "follow_offset":facing * reach * 0.43, "telegraph":true, "windup":windup})
		"ability":
			if lightning.supported(data):
				lightning.charge(data)
				_schedule(data,float(data.get("windup",0.3)),"ability")
				return
			if _player_night(data):
				_schedule(data,float(data.get("windup",0.4)),"ability")
				return
			var charge_time: float = float(data.get("windup", 0.68))
			_stamp("curl",Vector3(x,1.1,-0.14),Vector2(2.0,1.65),Color.WHITE,charge_time+0.1,{"rgb":true,"arc":true,"grow":0.4,"spin_speed":3.0,"follow_id":_source_id(data),"charge":true,"windup":charge_time})
			_stamp("taiji",Vector3(x,0.055,0),Vector2.ONE*2.3,Color.WHITE,charge_time+0.1,{"rgb":true,"ground":true,"grow":0.55,"spin_speed":-0.7,"follow_id":_source_id(data),"charge":true,"windup":charge_time})
			_schedule(data,charge_time,"ability")
		"stanceChange":
			if _player_fire(data):
				_fire_card(0,Vector3(x,0.75,-0.18),Vector2(1.6,1.0),FIRE_LIGHT,0.24,{"angle":0.4*facing,"facing":facing,"grow":0.55,"role":"stance"})
				_fire_particles(Vector3(x,0.35,0.1),8,facing,false,true)
		"hit", "ultHit", "parry": _impact(data)
		"block": _block_impact(data)
		"dodge":
			if lightning.supported(data): lightning.dash(data)
			elif _player_night(data): _night_dash(data)
			elif _player_fire(data): _fire_dodge(x,float(data.get("direction",-facing)))
			else: _speed_streaks(x, float(data.get("direction", -facing)))
		"evade":
			if lightning.supported(data): lightning.dash(data)
			elif _player_night(data): _night_dash(data)
			elif _player_fire(data): _fire_dodge(x,float(data.get("direction",-facing)))
			else:
				_speed_streaks(x, float(data.get("direction", -facing)))
				_stamp("curl",Vector3(x,1.2,0.4),Vector2(1.6,1.1),Color.WHITE,0.3,{"rgb":true,"grow":0.7})
		"guardBreak":
			if lightning.supported(data): lightning.event(data)
			elif str(data.get("style","")) == "fenghuang":
				_fire_particles(Vector3(x,1.35,0.4),20,facing,true,true)
				_fire_ring(x,2.7,0.4)
			else:
				_particles(Vector3(x, 1.35, 0.4), GOLD, 24, facing, true, false, true)
				_shock(x, 1.5, GOLD, 0.4)
		"ultimate":
			if lightning.supported(data): lightning.event(data)
			elif _player_night(data): _night_activation(data)
			elif _player_fire(data): _fire_ultimate(data)
			else: _native_ultimate(data)
		"burstBegin":
			if lightning.supported(data): lightning.event(data)
			elif _player_night(data):
				_stamp("night_ring",Vector3(x,0.06,0),Vector2.ONE*2.8,Color(1.0,0.56,0.28,0.8),0.36,{"ground":true,"grow":0.25,"instant":true,"style":"night_squire","role":"burst_release","annulus":true})
		"ultimateImpact":
			if lightning.supported(data): lightning.event(data)
			else: lightning.sword_field(data)
		"lightningDischarge", "fogCharge", "Fogcharge":
			if lightning.supported(data): lightning.event(data)
		"victory":
			if str(data.get("style","azure_empyrea"))=="azure_empyrea": _native_victory(data)
		"bossPhase":
			_shock(x, 2.8, DANGER, 0.8)
			_card(4, Vector3(x, 0.055, 0), Vector2.ONE * 3.5, Color(INK, 0.8), 1.0, {"ground":true, "secondary":DANGER, "spin_speed":-1.0})
			_particles(Vector3(x, 0.9, 0.4), DANGER, 28, facing, true, false, true)
			_sound("heavy")
		"enemyDown":
			if lightning.supported(data): lightning.event(data)
			elif str(data.get("style","")) == "fenghuang":
				_fire_ring(x,1.8,0.42)
				_fire_particles(Vector3(x,0.4,0.2),12,facing,false,true)
			else:
				_card(2, Vector3(x, 0.05, 0), Vector2(1.9, 1.0), Color(INK, 0.5), 0.85, {"ground":true, "grow":0.4})
				_particles(Vector3(x, 0.4, 0.2), palette, 18, facing, false, true, true)
		"spawnStage":
			clear()
			_shock(x, 4.5, Color(palette, 0.7), 1.1)

func _player_night(data: Dictionary) -> bool:
	return str(data.get("style",""))=="night_squire" and str(data.get("side","player"))=="player"

func _night_color(data: Dictionary) -> Color:
	return Color(1.0,0.3529412,0.0,0.80) if bool(data.get("nightBurst",false)) else Color(1.0,0.96,0.88,0.80)

func _night_sweep(data: Dictionary, skill: bool=false) -> void:
	# Original C3 ND attack/ultra textures; source-manifest records six prefabs. Positions and timing
	# are fitted to this side-view moveset, not a claim of original emitters.
	var fighter: Dictionary=_fighters.get(_source_id(data),{})
	var x:=float(fighter.get("x",data.get("x",0.0)))
	var facing:=_facing(data)
	var heavy:=skill or str(data.get("name",""))=="heavy"
	var kick:=bool(data.get("nightBurst",false)) or heavy
	var origin:=Vector3(x+facing*(0.60 if kick else 0.42),1.05 if kick else 1.65,0.50)
	_stamp("night_burst_trail" if bool(data.get("nightBurst",false)) else "night_trail",origin,Vector2(1.9,1.35) if kick else Vector2(1.15,0.75),_night_color(data),0.20 if heavy else 0.13,{"facing":facing,"angle":(-0.65 if kick else 0.15)*facing,"grow":0.85,"instant":true,"style":"night_squire","role":"physical_trail"})

func _night_impact(data: Dictionary) -> void:
	var origin:=_contact_origin(data)
	var strong:=bool(data.get("heavy",false)) or bool(data.get("skill",false))
	var parry:=str(data.get("type",""))=="parry"
	_contact_flash(data,false,parry)
	_stamp("night_rays",origin,Vector2(0.70,0.70) if strong else Vector2(0.40,0.40),_night_color(data),0.13,{"instant":true,"grow":0.7,"style":"night_squire","role":"physical_contact"})
	_particles(origin,_night_color(data),9 if strong else 5,_facing(data),strong)
	_compact_last_particles(0.18 if strong else 0.11,2.1,1.05)
	_sound("parry" if parry else _hit_sound(data))

func _night_dash(data: Dictionary) -> void:
	var x:=float(data.get("x",0.0))
	var direction:=float(data.get("direction",-_facing(data)))
	_stamp("night_smoke",Vector3(x-direction*0.35,0.65,0.22),Vector2(1.4,0.7),Color(0.77,0.87,0.95,0.38),0.20,{"facing":direction,"grow":0.65,"style":"night_squire","role":"step"})

func _night_activation(data: Dictionary) -> void:
	var x:=float(data.get("x",0.0))
	_sound("ultimate")
	_stamp("night_ring",Vector3(x,0.05,0),Vector2.ONE*2.4,Color(0.90,0.78,0.55,0.72),1.30,{"ground":true,"grow":1.25,"fade_in":0.12,"fade_start":0.80,"style":"night_squire","role":"burst_ready","annulus":true})
	# ND is a power-up, so the native trails spiral toward the fighter rather
	# than pretending to strike the untouched enemy during the activation.
	for index: int in 4:
		var phase: float=float(index)*TAU/4.0
		_stamp("night_burst_trail",Vector3(x,0.80,-0.20),Vector2(1.35,0.32),Color(1.0,0.54,0.20,0.72),1.03,{"delay":0.16+index*0.05,"arc":true,"orbit":Vector3(0.62,0.25,0.46),"orbit_phase":phase,"orbit_speed":4.0,"velocity":Vector3(0,0.62,0),"angle":phase,"spin_speed":3.2,"grow":1.20,"fade_start":0.82,"style":"night_squire","role":"burst_gather"})
	for side: float in [-1.0,1.0]:
		_stamp("night_burst_trail",Vector3(x+side*0.42,0.95,-0.25),Vector2(0.36,2.1),Color(1.0,0.56,0.20,0.70),0.43,{"delay":1.03,"velocity":Vector3(side*0.30,0.35,0),"grow":0.35,"style":"night_squire","role":"burst_flare"})
		_stamp("night_smoke",Vector3(x+side*0.30,0.16,0.1),Vector2(1.5,0.5),Color(0.80,0.85,0.91,0.45),0.55,{"delay":1.03,"velocity":Vector3(side*1.8,0.05,0),"grow":0.5,"style":"night_squire","role":"burst_pressure"})
	for index in 5:
		var side:float=-1.0 if index%2==0 else 1.0
		_stamp("night_rays",Vector3(x+side*0.25,0.55+float(index)*0.27,0.25),Vector2.ONE*0.10,Color(1.0,0.65,0.32,0.85),0.50,{"delay":0.25+float(index)*0.11,"velocity":Vector3(0,0.65,0),"grow":0.4,"style":"night_squire","role":"burst_ready"})

func _tick_cues(_delta: float) -> void:
	for index: int in range(_cues.size() - 1, -1, -1):
		var cue: Dictionary = _cues[index]
		var fighter: Dictionary = _fighters.get(str(cue.source), {})
		var attack: Dictionary=fighter.get("attack",{})
		var clock: float=float(fighter.get("stateTime",0.0))
		var invalid: bool=fighter.is_empty() or str(fighter.get("state",""))!="attack" or str(attack.get("name",""))!=str(cue.attack_name) or int(attack.get("comboIndex",0))!=int(cue.combo) or clock+0.0001<float(cue.last_clock)
		if invalid:
			_cues.remove_at(index)
			continue
		cue.last_clock=clock
		var windup: float=float(attack.get("windup",cue.at))
		if str(cue.kind)=="ability": cue.at=windup
		elif str(cue.kind)=="sweep": cue.at=maxf(0.0,windup-0.02)
		elif str(cue.kind)=="wind": cue.at=maxf(0.0,windup-(0.11 if str(cue.attack_name) in ["heavy","ability"] else 0.07))
		if clock >= float(cue.at):
			_cues.remove_at(index)
			if str(cue.kind) == "ability": _ability_release(cue.data)
			elif str(cue.kind)=="wind": _sound("swing_heavy" if str(cue.attack_name) in ["heavy","ability"] else "swing")
			else: _attack_sweep(cue.data)

func tick(delta: float) -> void:
	if delta <= 0.0: return
	_sound_clock += delta
	_tick_cues(delta)
	for i: int in range(active.size() - 1, -1, -1):
		var item: Dictionary = active[i]
		var settings: Dictionary = item.settings
		var node: MeshInstance3D = item.node
		item.time = float(item.time) + delta
		var p: float = clampf(float(item.time) / float(item.life), 0.0, 1.0)
		var follow: String = str(settings.get("follow_id", ""))
		if not follow.is_empty() and _fighters.has(follow):
			var fighter: Dictionary = _fighters[follow]
			node.position.x = float(fighter.get("x", node.position.x)) + float(settings.get("follow_offset", 0.0))
			if bool(settings.get("telegraph", false)) or bool(settings.get("charge", false)):
				p = clampf(float(fighter.get("stateTime", 0.0)) / maxf(0.01, float(settings.get("windup", 0.3))), 0.0, 1.0)
				if str(fighter.get("state", "")) != "attack": p = 1.0
		if p >= 1.0:
			node.queue_free()
			active.remove_at(i)
			continue
		node.visible = float(item.time) >= 0.0
		var mat: ShaderMaterial = item.mat
		if str(item.mode) == "particles":
			mat.set_shader_parameter("age", maxf(0.0, float(item.time)))
		elif str(item.mode)=="native_sword":
			# Source ColorModule fades stationary swords linearly over three seconds.
			mat.set_shader_parameter("opacity",1.0-p)
		elif str(item.mode)=="sphere":
			var falling: bool=bool(settings.get("falling",false))
			var growth: float=(1.0-smoothstep(0.80,1.0,p))*smoothstep(0,0.08,p) if falling else _sphere_growth(p)
			node.scale=Vector3.ONE*maxf(0.001,float(item.radius)*growth)
			node.position=Vector3(item.origin).lerp(Vector3(item.destination),pow(p,3.0) if falling else p)
			node.rotation.z=float(item.time)*1.1
			mat.set_shader_parameter("age",maxf(0.0,float(item.time)))
			mat.set_shader_parameter("opacity",1.0 if item.time>=0.0 else 0.0)
			mat.set_shader_parameter("stretch",0.0 if falling else 0.05*sin(p*13.0))
			if falling and item.time>=0.0:
				var source_time: float=p*SPHERE_MOTION.DURATION
				var distance: float=clampf(SPHERE_MOTION.sample(SPHERE_MOTION.POSITION,source_time)/9.0,-0.25,1.0)
				node.position=Vector3(item.origin).lerp(Vector3(item.destination),distance)
				var mesh_scale:=Vector3(SPHERE_MOTION.sample(SPHERE_MOTION.SCALE_X,source_time),SPHERE_MOTION.sample(SPHERE_MOTION.SCALE_Y,source_time),SPHERE_MOTION.sample(SPHERE_MOTION.SCALE_Z,source_time))
				node.rotation=Vector3(PI/2.0,deg_to_rad(SPHERE_MOTION.sample(SPHERE_MOTION.ROTATION,source_time)),0)
				node.scale=mesh_scale*float(item.radius)*0.5
				if node.mesh is ArrayMesh and node.mesh.get_blend_shape_count()>0: node.set_blend_shape_value(0,SPHERE_MOTION.sample(SPHERE_MOTION.MORPH,source_time))
				mat.set_shader_parameter("opacity",minf(1.0,SPHERE_MOTION.sample(SPHERE_MOTION.ALPHA,source_time)*2.0)*(1.0-smoothstep(0.75,1.0,source_time)))
		elif str(item.mode) == "native":
			var age: float=maxf(0.0,float(item.time))
			if settings.has("atlas_grid"):
				var grid: Vector2=settings.atlas_grid
				var frame: int=mini(int(grid.x*grid.y)-1,int(p*float(settings.get("atlas_frames",grid.x*grid.y))))
				mat.set_shader_parameter("uv_transform",Vector4(1.0/grid.x,1.0/grid.y,float(frame%int(grid.x))/grid.x,float(frame/int(grid.x))/grid.y))
			var fade_in: float=maxf(0.005,float(settings.get("fade_in",0.025)))
			var fade_start: float=float(settings.get("fade_start",0.52))
			var alpha: float=(1.0 if bool(settings.get("instant",false)) else smoothstep(0.0,fade_in,age))*(1.0-smoothstep(fade_start,1.0,p))
			mat.set_shader_parameter("age",age)
			mat.set_shader_parameter("opacity",alpha)
			mat.set_shader_parameter("dissolve",lerpf(-0.15,0.8,smoothstep(0.32,1.0,p)))
			var start: float=float(settings.get("grow",0.75))
			node.scale=item.base_scale*lerpf(start,1.0,1.0-pow(1.0-p,3.0))
			var velocity: Vector3=settings.get("velocity",Vector3.ZERO)
			node.position=Vector3(item.origin)+velocity*age
			if settings.has("orbit"):
				var radii: Vector3=settings.orbit
				var phase: float=float(settings.get("orbit_phase",0.0))+age*float(settings.get("orbit_speed",2.0))
				node.position+=Vector3(cos(phase)*radii.x,sin(phase)*radii.y,sin(phase)*radii.z)
			if not follow.is_empty() and _fighters.has(follow):
				node.position.x=float(_fighters[follow].get("x",node.position.x))+float(settings.get("follow_offset",0.0))
			var spin: float=float(settings.get("spin_speed",0.0))*age
			if bool(settings.get("ground",false)): node.rotation.y=float(settings.get("angle",0.0))+spin
			else: node.rotation.z=float(settings.get("angle",0.0))+spin
			if bool(settings.get("billboard",false)):
				var view_camera := get_viewport().get_camera_3d()
				if view_camera != null:
					node.look_at(view_camera.global_position,Vector3.UP,true)
					node.rotate_object_local(Vector3.FORWARD,float(settings.get("angle",0.0))+spin)
		else:
			mat.set_shader_parameter("progress", p * 0.45 + 0.05 if bool(settings.get("charge", false)) else p)
			mat.set_shader_parameter("opacity", 1.0)
			mat.set_shader_parameter("spin", float(settings.get("spin_speed", 0.0)) * maxf(0.0, float(item.time)))
			var start: float = float(settings.get("grow", 1.0))
			node.scale = item.base_scale * lerpf(start, 1.0, 1.0 - pow(1.0 - p, 2.0))
			if settings.has("velocity"):
				node.position = Vector3(item.origin) + Vector3(settings.velocity) * maxf(0.0,float(item.time))

# C4 texture cells and authored lightweight flame cards share this branch.
# This is not a port of the original particle systems; C5 ink is unchanged.
func _player_fire(data: Dictionary) -> bool:
	return str(data.get("style","")) == "fenghuang" and str(data.get("side","player")) == "player"

func _fire_card(shape: int, origin: Vector3, size: Vector2, color: Color, life: float, settings: Dictionary = {}) -> Dictionary:
	var options := settings.duplicate(true)
	options.style = "fenghuang"
	options.secondary = options.get("secondary",FIRE_LIGHT)
	var item := _card(shape,origin,size,color,life,options)
	item.origin = origin
	if bool(options.get("instant",false)):
		item.mat.set_shader_parameter("opacity",1.0)
		item.node.scale = item.base_scale * float(options.get("grow",1.0))
	return item

func _fire_stamp(key: String, origin: Vector3, size: Vector2, color: Color, life: float, settings: Dictionary = {}) -> Dictionary:
	var options := settings.duplicate(true)
	options.style="fenghuang"
	options.mask=0 # All selected C4 sources have meaningful original alpha.
	options.rgb=true
	return _stamp(key,origin,size,color,life,options)

func _fire_particles(origin: Vector3, count: int, facing: float, strong: bool = false, radial: bool = false, delay: float = 0.0) -> void:
	_particles(origin,FIRE_LIGHT,count,facing,strong,false,radial)
	var item: Dictionary = active.back()
	item.settings = {"style":"fenghuang","role":"embers"}
	item.time = -delay
	item.node.visible = delay <= 0.0
	item.mat.set_shader_parameter("gravity",-0.5)
	item.mat.set_shader_parameter("speed",3.2 if strong else 2.0)

func _fire_ring(x: float, diameter: float, life: float, delay: float = 0.0) -> void:
	var settings: Dictionary={"ground":true,"delay":delay,"role":"ground_flame","grow":0.52,"fade_start":0.35}
	if native_textures.has("phoenix_ring"):
		_fire_stamp("phoenix_ring",Vector3(x,0.045,0),Vector2(diameter,diameter*0.72),Color(FLAME,0.66),life,settings)
	else:
		_fire_card(3,Vector3(x,0.045,0),Vector2(diameter,diameter*0.72),Color(FLAME,0.66),life,settings)

func _fire_wings(origin: Vector3, facing: float, scale_factor: float, life: float, delay: float = 0.0) -> void:
	# Native flame atlas cells replace the old six smooth procedural wedges.
	# Distinct trailing feathers leave the middle/face open, behind the body.
	for side: float in [-1.0,1.0]:
		for index: int in 3:
			var spread: float = (0.60+float(index)*0.29)*scale_factor
			var position: Vector3 = origin+Vector3(side*spread,(0.36+float(index)*0.28)*scale_factor,0)
			var options: Dictionary={"angle":side*(0.60+float(index)*0.16),"delay":delay+index*0.035,"grow":0.42,"velocity":Vector3(side*0.18,0.32,0),"role":"phoenix_feather","facing":side,"uv":Vector4(0.5,0.5,float(index%2)*0.5,float(index/2)*0.5),"fade_start":0.72}
			options.energy_core=true
			if native_textures.has("phoenix_fist"):
				_fire_stamp("phoenix_fist",position,Vector2((1.65-float(index)*0.14)*scale_factor,0.62*scale_factor),Color(1.0,0.40 if index==2 else 0.64,0.13,0.82),life,options)
			else:
				_fire_card(6,position,Vector2((1.35-float(index)*0.12)*scale_factor,0.85*scale_factor),EMBER if index==2 else FLAME,life,options)
	_fire_card(6,origin+Vector3(0,0.16,0.02),Vector2(0.74*scale_factor,0.15*scale_factor),FIRE_LIGHT,life*0.72,{"angle":PI*0.5+0.12*facing,"delay":delay,"grow":0.65,"role":"phoenix_core"})

func _fire_sweep(data: Dictionary, switching: bool = false) -> void:
	var fighter: Dictionary = _fighters.get(_source_id(data),{})
	var x: float = float(fighter.get("x",data.get("x",0.0)))
	var facing: float = _facing(data)
	var kick: bool = str(data.get("stance",fighter.get("stance","punch"))) == "kick"
	var strong: bool = str(data.get("name","")) == "heavy" or int(data.get("combo",0)) == 2
	var origin := Vector3(x+facing*(0.82 if kick else 0.58),1.10 if kick else 1.56,-0.14)
	if kick or switching:
		var width: float = 3.1 if strong else 2.35 if kick else 1.85
		var settings: Dictionary={"angle":(-0.4 if kick else 0.5)*facing,"facing":facing,"spin_speed":-3.0*facing,"grow":0.7,"role":"kick_sweep" if kick else "switch_sweep"}
		if native_textures.has("phoenix_arc"):
			# One of four horizontal source rows, never the entire atlas.
			var row: int=mini(3,int(data.get("combo",0))+(1 if strong else 0))
			settings.uv=Vector4(1.0,0.25,0.0,float(row)*0.25)
			_fire_stamp("phoenix_arc",origin,Vector2(width,0.48 if strong else 0.38),Color(FLAME,0.82),0.22 if strong else 0.16,settings)
		else:
			_fire_card(0,origin,Vector2(width,1.35 if strong else 0.98),FLAME,0.28 if strong else 0.20,settings)
		_fire_card(0,origin+Vector3(0,0,0.035),Vector2(width*0.72,0.69),FIRE_LIGHT,0.13,{"angle":-0.26*facing,"facing":facing,"grow":0.8,"role":"kick_core"})
	else:
		var settings: Dictionary={"angle":(-0.2 if int(data.get("combo",0))==0 else 0.22)*facing,"facing":facing,"grow":0.72,"velocity":Vector3(facing*1.2,0,0),"role":"fist_trail"}
		if native_textures.has("phoenix_fist"):
			var cell: int=mini(3,int(data.get("combo",0))+(1 if strong else 0))
			settings.uv=Vector4(0.5,0.5,float(cell%2)*0.5,float(cell/2)*0.5)
			settings.facing=-facing # The source's sharp edge points toward -X.
			_fire_stamp("phoenix_fist",origin,Vector2(1.15 if strong else 0.90,0.44 if strong else 0.34),Color(1.0,0.93,0.82,0.84),0.14,settings)
		else:
			_fire_card(6,origin,Vector2(1.25 if strong else 0.88,0.30 if strong else 0.22),FLAME,0.18 if strong else 0.12,settings)
		_fire_card(6,origin+Vector3(0,0,0.025),Vector2(0.70,0.12),FIRE_LIGHT,0.10,{"facing":facing,"role":"fist_core"})
	if strong:
		_fire_wings(Vector3(x+facing*0.35,0.75,-0.34),facing,0.68,0.24)

func _fire_guard(data: Dictionary, parried: bool) -> void:
	var facing: float = _facing(data)
	var origin := _contact_origin(_guard_contact(data))
	if parried: origin.x += facing*0.28
	_fire_card(0,origin-Vector3(0,0,0.04),Vector2(0.70,0.78) if parried else Vector2(0.46,0.62),FIRE_LIGHT if parried else Color(FLAME,0.7),0.19 if parried else 0.13,{"angle":-0.45*facing,"facing":facing,"instant":true,"role":"fire_parry" if parried else "fire_block"})
	_fire_card(1,origin,Vector2(0.62,0.40) if parried else Vector2(0.42,0.26),FIRE_LIGHT,0.09,{"instant":true,"secondary":Color(1,0.98,0.82),"role":"guard_contact"})
	if parried:
		_fire_particles(origin,10,facing,false,true)
		_compact_last_particles(0.22,2.3,TAU)
	_sound("parry" if parried else _block_sound(data))

func _fire_impact(data: Dictionary) -> void:
	var origin := _contact_origin(data)
	var facing: float = _facing(data)
	var final: bool = bool(data.get("final",false))
	var cinematic: bool = str(data.get("type","")) == "ultHit"
	var strong: bool = bool(data.get("heavy",false)) or bool(data.get("skill",false)) or cinematic
	var kick: bool = str(data.get("stance","punch")) == "kick"
	_fire_card(1,origin,Vector2(1.30,0.78) if final else Vector2(0.90,0.54) if strong else Vector2(0.50 if kick else 0.44,0.27),FIRE_LIGHT,0.12 if final else 0.07 if strong else 0.05,{"instant":true,"secondary":Color(1,0.98,0.86),"angle":-0.2*facing,"role":"fire_contact"})
	_fire_card(6,origin+Vector3(facing*0.18,-0.05,-0.08),Vector2(2.4,0.58) if final else Vector2(1.35,0.30) if strong else Vector2(1.0 if kick else 0.62,0.18),FLAME,0.28 if final else 0.18 if strong else 0.14,{"instant":true,"facing":facing,"velocity":Vector3(facing*1.8,0.12,0),"role":"fire_jet"})
	_fire_particles(origin,24 if final else 16 if cinematic else 10 if strong else 5,facing,strong,final)
	if not cinematic: _compact_last_particles(0.28 if strong else 0.18,2.5 if strong else 1.8,1.2)
	if strong: _fire_ring(origin.x,4.2 if final else 2.2,0.46 if final else 0.32)
	if final: _fire_wings(Vector3(origin.x,0.85,-0.45),facing,1.55,0.58)
	if cinematic: _fire_landing(origin.x,facing,final)
	_sound("heavy" if cinematic else _hit_sound(data))

func _fire_landing(x: float,facing: float,final: bool) -> void:
	# The actual hit event owns the explosion, including the very first frame.
	# Ordinary hit sparks remain compact; Q gets a distinct original fire atlas
	# silhouette and outward jets below the standing enemy's face.
	var strength: float=1.22 if final else 1.0
	_fire_stamp("phoenix_explosion",Vector3(x,0.30,-0.34),Vector2(2.45,1.25)*strength,Color(1.0,0.72,0.33,0.76),0.24,{"instant":true,"grow":0.85,"fade_start":0.30,"role":"ultimate_flame_core"})
	for index: int in 5:
		var side: float=float(index-2)
		var height: float=0.80 if index==2 else 1.15
		_fire_stamp("phoenix_flame",Vector3(x+side*0.48,height*0.45,-0.38),Vector2(1.25,height)*strength,Color(1.0,0.92,0.80,0.94),0.52+absf(side)*0.035,{"instant":true,"grow":0.88,"uv":Vector4(0.25,0.25,0,0),"atlas_grid":Vector2(4,4),"atlas_frames":16,"angle":-side*0.18,"velocity":Vector3(side*0.60,0.52,0),"fade_start":0.80,"role":"ultimate_flame_plume"})
	for side: float in [-1.0,1.0]:
		_fire_stamp("phoenix_fist",Vector3(x+side*0.75,0.42,0.45),Vector2(3.4,0.68)*strength,Color(1.0,0.76,0.25,0.93),0.33,{"uv":Vector4(0.5,0.5,0,0),"instant":true,"grow":0.95,"facing":-side,"angle":side*0.11,"energy_core":true,"velocity":Vector3(side*2.8,0.1,0),"fade_start":0.50,"role":"ultimate_flame_outburst"})

func _fire_dodge(x: float, direction: float) -> void:
	_fire_card(6,Vector3(x-direction*0.45,0.65,-0.12),Vector2(1.45,0.20),Color(FLAME,0.62),0.22,{"facing":direction,"velocity":Vector3(-direction*0.45,0.1,0),"role":"fire_dodge"})

func _fire_ultimate(data: Dictionary) -> void:
	var x: float = float(data.get("x",0.0))
	var target_x: float = float(data.get("targetX",x+1.0))
	var facing: float = _facing(data)
	_sound("ultimate")
	_fire_ring(x,2.2,0.55)
	_fire_particles(Vector3(x,1.5,0.1),14,facing,false,true)
	_fire_wings(Vector3(x,1.80,-0.42),facing,1.18,1.12,0.35)
	_fire_wings(Vector3(x,1.70,-0.48),facing,1.72,1.05,0.95)
	_fire_ring(x,3.9,0.70,1.15)
	for side: float in [-1.0,1.0]:
		_fire_stamp("phoenix_arc",Vector3(x+side*0.50,0.85,-0.38),Vector2(2.0,0.6),Color(1.0,0.67,0.24,0.84),0.75,{"uv":Vector4(1,0.25,0,0.5),"arc":true,"delay":0.40,"orbit":Vector3(0.48,0.30,0.28),"orbit_phase":0.0 if side<0.0 else PI,"orbit_speed":3.6*facing,"velocity":Vector3(0,0.8,0),"spin_speed":-2.3*facing,"grow":0.55,"role":"fire_gather"})
		_fire_stamp("phoenix_fist",Vector3(x+side*0.4,1.8,-0.35),Vector2(3.1,0.7),Color(1,0.71,0.28,0.85),0.33,{"uv":Vector4(0.5,0.5,0,0),"delay":1.72,"angle":-side*0.25,"facing":facing,"velocity":Vector3((target_x-x)/0.38,-0.4,0),"grow":0.55,"role":"fire_native_launch"})
	_fire_card(6,Vector3(x,1.55,-0.25),Vector2(1.75,0.28),FLAME,0.46,{"delay":1.72,"velocity":Vector3((target_x-x)/0.38,0.0,0.0),"facing":facing,"role":"fire_launch"})
	_fire_wings(Vector3(target_x,0.60,-0.48),facing,1.3,0.57,2.23)
	_fire_particles(Vector3(target_x,0.75,-0.15),18,facing,true,true,2.32)
	# The two actual impact bursts are created by ultHit at 2.10 / 2.82; no
	# decorative timer may create damage-like flashes ahead of those events.

