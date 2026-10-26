extends Node3D
## Original C6 textures, authored WebGL-friendly geometry and contact timing.
## This is a portable presentation, not a replacement Unity particle simulator.
const SHADER := preload("res://shaders/native_ink.gdshader")
const DIRECTORY := "res://assets/vfx/sentience-native/"
const FILES := {"sword_icon":"SFX_Icon_602", "spear_icon":"SFX_Icon_603", "chain_icon":"SFX_Icon_604",
	"blade":"SFX_BladeTrail_603", "thrust":"SFX_Trail_401", "hit":"SFX_Ray_608_OP", "flash":"SFX_Flash_602",
	"lightning":"SFX_Lightning_603", "smoke":"SFX_Smoke_103", "red_ink":"SFX_Nature_601_OP", "ground":"SFX_Ground_615",
	"mask":"SFX_Mask_619", "noise":"SFX_Noise_611"}
const MAX_ACTIVE := 48
const STRIKE_DEPTH := 0.74
var _textures: Dictionary = {}
var _fighters: Dictionary = {}
var _cues: Array[Dictionary] = []
var _active: Array[Dictionary] = []
var _weapons: Dictionary = {}
var _suspended_sources: Dictionary = {}
var _quad := QuadMesh.new()
var _arc: ArrayMesh
var _emitted := 0
var _cancelled := 0

func _ready() -> void:
	_quad.size = Vector2.ONE
	_arc = _make_arc()
	for key in FILES:
		var path := DIRECTORY+str(FILES[key])+".png"
		if ResourceLoader.exists(path): _textures[key] = load(path)

func update_fighters(player: Dictionary, enemies: Array) -> void:
	_fighters.clear()
	_fighters[str(player.get("id","player"))] = player.duplicate(true)
	for fighter: Dictionary in enemies:
		_fighters[str(fighter.get("id","enemy"))] = fighter.duplicate(true)

func handle_event(data: Dictionary) -> void:
	var type := str(data.get("type", ""))
	if type in ["reset", "start", "spawnStage"]:
		clear()
		return
	if type == "ultimate" and data.has("targets"):
		_suspended_sources.clear()
		var targets: Array=data.get("targets",[])
		for id in targets: _cancel_source(str(id))
		# A cut-in suspends the arena. Only actual victims lose their attack;
		# an out-of-range enemy resumes its own weapon clock afterward.
		for id: String in _fighters:
			var fighter: Dictionary=_fighters[id]
			if fighter.get("side","")=="enemy" and float(fighter.get("hp",1.0))>0.0 and not id in targets:
				_suspended_sources[id]=true
		return
	if type == "ultimateEnd":
		_suspended_sources.clear()
		return
	if type in ["ultimate", "end"]:
		_suspended_sources.clear()
		_cancelled += _cues.size()
		_cues.clear()
		return
	if type == "bossEntrance":
		_boss_entrance(float(data.get("x",0.0)),float(data.get("facing",-1.0)))
		return
	var source_id := str(data.get("sourceId", "enemy"))
	var source: Dictionary = _fighters.get(source_id, {})
	var native_enemy := str(data.get("style",source.get("style", "")))=="sentience" or str(data.get("motion", "")).begins_with("senti_")
	if type == "parry":
		_cancel_source(str(data.get("targetId", "")))
		return
	if type == "enemyDown" or type == "guardBreak":
		_cancel_source(str(data.get("targetId",data.get("id", ""))))
	# Health damage does not necessarily interrupt a native retaliation. Its
	# weapon cue must survive ordinary punches into the announced armor.
	if type == "hit" and not bool(data.get("armored",false)):
		_cancel_source(str(data.get("targetId", "")))
	if not native_enemy: return
	var facing := -1.0 if float(data.get("facing",source.get("facing",-1.0)))<0.0 else 1.0
	var weapon := str(data.get("weapon",source.get("attack",{}).get("weapon",source.get("weapon", "sword"))))
	if type == "weaponChange":
		_switch_icon(source_id,weapon,float(data.get("x",source.get("x",0.0))),facing)
	elif type == "attack":
		_cancel_source(source_id)
		var windup := maxf(0.02,float(data.get("windup",0.45)))
		_cues.append({"id":source_id,"motion":str(data.get("motion","")),"weapon":weapon,"clock":-0.001,
			"swingAt":maxf(0.0,windup-0.055),"windup":windup,"duration":float(data.get("duration",1.0)),"range":float(data.get("range",3.6 if weapon=="burst" else 4.2 if weapon=="spear" else 3.2 if weapon=="chain" else 2.1)),"contactHeight":float(data.get("contactHeight",1.3)),"facing":facing,"x":float(data.get("x",0.0)),"fired":false})
		if _weapons.get(source_id, "") != weapon and weapon!="burst": _switch_icon(source_id,weapon,float(data.get("x",0.0)),facing)
		if weapon=="burst":
			_stamp("red_ink",Vector3(float(data.get("x",0.0)),0.12,-0.05),Vector2(2.2,1.1),Color(0.6,0.28,0.33,0.6),minf(0.7,windup),{"ground":true,"grow":0.4,"owner":source_id,"windup":true})
	elif type in ["hit", "block"]:
		var point := Vector3(float(data.get("contactX", data.get("x",0.0))),float(data.get("guardContactY",2.05)) if type=="block" else float(data.get("contactY",data.get("contactHeight",1.3))),STRIKE_DEPTH)
		if type=="block":
			_stamp("flash",point,Vector2(0.5,0.5),Color(1.0,0.79,0.58,0.95),0.10,{"rotation":0.5,"grow":0.15,"instant":true})
		else:
			var heavy := bool(data.get("heavy",false))
			var hit_size := Vector2(1.20 if heavy else 0.82,0.78 if heavy else 0.49)
			_stamp("hit",point-Vector3(0,0,0.02),hit_size*1.15,Color(0.11,0.01,0.035,0.90),0.22,{"rgb":false,"facing":facing,"rotation":0.12*facing,"move":Vector3(facing*0.55,0.12,0),"instant":true,"role":"hit_outline","priority":4})
			_stamp("hit",point,hit_size,Color(1.0,0.84,0.87,0.98),0.22,{"facing":facing,"rotation":0.12*facing,"move":Vector3(facing*0.55,0.12,0),"dissolve":true,"instant":true,"priority":5})
			_stamp("flash",point+Vector3(0,0,0.015),Vector2(0.35,0.35),Color(1,0.92,0.9,0.95),0.075,{"grow":0.3,"instant":true})
			if weapon=="chain" or weapon=="burst":
				_stamp("lightning",point,Vector2(1.55,0.72),Color(1.0,0.169,0.169,0.85),0.20,{"rotation":-0.2*facing})

func _switch_icon(id: String, weapon: String, x: float, facing: float) -> void:
	if weapon not in ["sword","spear","chain"]: return
	_weapons[id] = weapon
	_stamp(weapon+"_icon",Vector3(x-facing*0.35,2.82,0.12),Vector2(0.72,0.72),Color.WHITE,0.6,{"move":Vector3(0,0.22,0),"dissolve":true,"owner":id})

func _cancel_source(id: String) -> void:
	for i in range(_cues.size()-1,-1,-1):
		if str(_cues[i].id)==id:
			_cues.remove_at(i)
			_cancelled += 1
	for item in _active:
		if item.options.get("owner", "")==id and bool(item.options.get("windup",false)):
			item.time = item.life

func tick(delta: float) -> void:
	var step := maxf(0.0,delta)
	if step<=0.0: return
	for i in range(_cues.size()-1,-1,-1):
		var cue: Dictionary = _cues[i]
		if _suspended_sources.has(str(cue.id)): continue
		var fighter: Dictionary = _fighters.get(str(cue.id),{})
		var attack: Dictionary = fighter.get("attack",{})
		var time := float(fighter.get("stateTime",0.0))
		if fighter.is_empty() or str(fighter.get("state",""))!="attack" or str(attack.get("motion",""))!=str(cue.motion) or time+0.00001<float(cue.clock):
			_cues.remove_at(i)
			_cancelled += 1
			continue
		cue.clock = time
		cue.x = float(fighter.get("x",cue.x))
		cue.facing = float(fighter.get("facing",cue.facing))
		if not bool(cue.fired) and time>=float(cue.swingAt):
			cue.fired = true
			_swing(cue)
		if time>=float(cue.duration): _cues.remove_at(i)
	for i in range(_active.size()-1,-1,-1):
		var item: Dictionary = _active[i]
		if _suspended_sources.has(str(item.options.get("owner",""))):
			item.node.visible=false
			continue
		item.time += step
		item.node.visible = float(item.time)>=0.0
		if float(item.time)<0.0: continue
		if float(item.time)>=float(item.life):
			item.node.queue_free()
			_active.remove_at(i)
			continue
		var t := clampf(float(item.time)/float(item.life),0.0,1.0)
		var fade := (1.0 if bool(item.options.get("instant",false)) else smoothstep(0.0,float(item.options.get("fade_in",0.055)),t))*(1.0-smoothstep(float(item.options.get("fade_start",0.45)),1.0,t))
		item.material.set_shader_parameter("age",item.time)
		item.material.set_shader_parameter("opacity",fade)
		item.material.set_shader_parameter("dissolve",0.45*smoothstep(0.30,1.0,t))
		item.node.position = item.origin+Vector3(item.options.get("move",Vector3.ZERO))*float(item.time)
		item.node.scale = item.scale*(1.0+float(item.options.get("grow",0.0))*t)
		if bool(item.options.get("billboard",false)):
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				item.node.look_at(camera.global_position,Vector3.UP,true)
				item.node.rotate_object_local(Vector3.FORWARD,float(item.options.get("rotation",0.0)))

func _swing(cue: Dictionary) -> void:
	var facing := float(cue.facing)
	var height:=float(cue.get("contactHeight",1.3))
	var origin := Vector3(float(cue.x)+facing*0.9,height,STRIKE_DEPTH)
	var options := {"facing":facing,"owner":str(cue.id),"dissolve":true,"move":Vector3(facing*0.65,0,0),"instant":true,"fade_start":0.62,"role":"weapon_trail"}
	match str(cue.weapon):
		"sword":
			options.rotation = -0.42*facing if str(cue.motion).ends_with("2") else 0.25*facing
			options.arc = true
			_weapon_ribbon("blade",origin,Vector2(2.55,1.45),Color(1,0.92,0.95,0.96),0.28,options)
		"spear":
			_weapon_ribbon("thrust",Vector3(float(cue.x)+facing*2.1,height,STRIKE_DEPTH),Vector2(3.8,0.43),Color(1.0,0.83,0.73,0.96),0.25,options)
		"chain":
			options.rotation = -0.22*facing
			options.arc = true
			_weapon_ribbon("blade",origin,Vector2(4.0,1.75),Color(1,0.72,0.73,0.94),0.33,options)
			_stamp("lightning",origin+Vector3(0,0,0.06),Vector2(2.4,0.5),Color(1,0.17,0.17,0.86),0.23,{"facing":facing,"instant":true})
		"burst":
			var center := Vector3(float(cue.x),0.06,0.0)
			var diameter:=float(cue.get("range",3.6))*2.0
			_stamp("ground",center,Vector2(diameter,diameter),Color(0.85,0.14,0.17,0.7),1.1,{"ground":true,"grow":0.05})
			_stamp("red_ink",center+Vector3(0,0.7,0.08),Vector2(4.1,1.8),Color(0.8,0.65,0.68,0.9),0.70,{"grow":0.25,"dissolve":true})
			_stamp("lightning",center+Vector3(0,1.25,0.25),Vector2(4,1.6),Color(1.0,0.17,0.17,0.9),0.35,{"grow":0.25})
	_emitted += 1

func _weapon_ribbon(texture: String, at: Vector3, size: Vector2, color: Color, life: float, options: Dictionary) -> void:
	# White native strips disappeared against courtyard stone and were hidden
	# behind the coat. A native-alpha ink underlay keeps the real strip legible.
	var under := options.duplicate(true)
	under.rgb=false
	under.dissolve=false
	under.priority=2
	_stamp(texture,at-Vector3(0,0,0.04),size*Vector2(1.025,1.23),Color(0.10,0.012,0.035,0.90),life,under)
	var front := options.duplicate(true)
	front.priority=3
	_stamp(texture,at,size,color,life,front)

func _boss_entrance(x: float, facing: float) -> void:
	# Native C6 textures; authored 5.3-second presentation, not the Unity prefab.
	_stamp("ground",Vector3(x,0.065,0),Vector2(4.4,4.4),Color(0.65,0.035,0.09,0.68),4.8,{"ground":true,"grow":0.08,"fade_in":0.12,"fade_start":0.75,"role":"entrance_ground"})
	for index: int in 3:
		var side: float=-1.0 if index%2==0 else 1.0
		_stamp("smoke",Vector3(x+side*0.45,0.45,-0.36),Vector2(2.2,1.35),Color(0.12,0.035,0.08,0.75),1.6,{"delay":float(index)*0.18,"grow":0.5,"move":Vector3(side*0.18,0.23,0),"role":"entrance_gather"})
	_stamp("red_ink",Vector3(x,0.64,-0.20),Vector2(4.8,1.65),Color.WHITE,1.45,{"delay":0.82,"grow":0.2,"dissolve":true,"fade_start":0.65,"role":"entrance_reveal"})
	_stamp("lightning",Vector3(x,1.05,0.34),Vector2(4.5,0.8),Color(1,0.17,0.23,0.85),0.48,{"delay":1.05,"instant":true,"role":"entrance_reveal"})
	# Calligraphy sits beside the shoulders instead of over the face.
	for index: int in 3:
		var weapon: String=["sword","spear","chain"][index]
		var side: float=-1.0 if index%2==0 else 1.0
		_stamp(weapon+"_icon",Vector3(x+side*(1.12+float(index)*0.16),1.65+float(index%2)*0.25,0.38),Vector2.ONE*(0.82 if index!=2 else 0.92),Color.WHITE,0.85,{"delay":1.12+float(index)*0.43,"move":Vector3(side*0.08,0.12,0),"dissolve":true,"role":"entrance_calligraphy","billboard":true})
	_stamp("red_ink",Vector3(x,0.42,-0.1),Vector2(4.1,1.10),Color(0.75,0.50,0.59,0.78),1.6,{"delay":3.50,"grow":-0.60,"dissolve":true,"role":"entrance_settle"})
	_stamp("blade",Vector3(x+facing*0.5,0.72,STRIKE_DEPTH),Vector2(3.0,0.60),Color(1,0.68,0.72,0.8),0.5,{"delay":4.25,"facing":facing,"rotation":-0.17*facing,"dissolve":true,"role":"entrance_settle"})

func _stamp(texture: String, at: Vector3, size: Vector2, color: Color, life: float, options: Dictionary = {}) -> void:
	if not _textures.has(texture): return
	if _active.size()>=MAX_ACTIVE:
		_active[0].node.queue_free()
		_active.pop_front()
	var node := MeshInstance3D.new()
	node.mesh = _arc if bool(options.get("arc",false)) else _quad
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin=5.0
	node.position=at
	node.scale=Vector3(size.x,size.y,1)
	if bool(options.get("arc",false)): node.scale.x*=float(options.get("facing",1.0))
	node.rotation.z=float(options.get("rotation",0.0))
	if bool(options.get("ground",false)): node.rotation.x=-PI/2.0
	var mat := ShaderMaterial.new()
	mat.shader=SHADER
	mat.set_shader_parameter("source_texture",_textures[texture])
	mat.set_shader_parameter("source_rgb",bool(options.get("rgb",true)))
	mat.set_shader_parameter("mask_mode",0)
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("opacity",1.0 if bool(options.get("instant",false)) else 0.08)
	mat.set_shader_parameter("flip_x",not bool(options.get("arc",false)) and float(options.get("facing",1.0))<0.0)
	mat.set_shader_parameter("use_dissolve",bool(options.get("dissolve",false)))
	if _textures.has("mask"): mat.set_shader_parameter("dissolve_texture",_textures.mask)
	mat.set_shader_parameter("noise_uv_transform",Vector4(1,1,0,0))
	mat.set_shader_parameter("noise_velocity",Vector2.ZERO)
	mat.render_priority=int(options.get("priority",0))
	node.material_override=mat
	node.visible=float(options.get("delay",0.0))<=0.0
	add_child(node)
	_active.append({"node":node,"material":mat,"texture":texture,"time":-float(options.get("delay",0.0)),"life":maxf(0.04,life),"origin":at,"scale":node.scale,"options":options.duplicate(true)})

func _make_arc() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 20:
		for corner in [0,1,2,1,3,2]:
			var f := (float(segment)+(1.0 if corner>=2 else 0.0))/20.0
			var inner: bool = int(corner)%2==0
			var angle := lerpf(-1.10,1.10,f)
			var radius := 0.38 if inner else 0.62
			tool.set_uv(Vector2(f,1.0 if inner else 0.0))
			tool.set_normal(Vector3(0,0,1))
			tool.add_vertex(Vector3(sin(angle)*radius,cos(angle)*radius-0.38,0))
	return tool.commit()

func clear() -> void:
	for item in _active:
		if is_instance_valid(item.node): item.node.queue_free()
	_active.clear()
	_cues.clear()
	_weapons.clear()
	_suspended_sources.clear()
	_emitted=0
	_cancelled=0

func snapshot() -> Dictionary:
	var elapsed := 0.0
	var textures: Array[String] = []
	for item in _active:
		elapsed += float(item.time)
		if not textures.has(str(item.texture)): textures.append(str(item.texture))
	return {"active":_active.size(),"pending":_cues.size(),"time":elapsed,"emittedSwings":_emitted,"cancelled":_cancelled,"textures":textures,"nativeTextures":_textures.size(),"suspendedSources":_suspended_sources.keys()}
