extends RefCounted
## Original C2 NL / C1 FK texture cells, arranged for this horizontal arena.
## This ports source artwork and selected emitter parameters, not Unity's renderer.
const MAPS := {
	"shadow_knight":"res://assets/shadow-knight/vfx-map.json",
	"blood_moon":"res://assets/shadow-knight/blood-moon-vfx-map.json",
	"hawk_of_the_fog":"res://assets/hawk-of-the-fog/vfx-map.json"
}
const SWORD_PATH := "res://assets/phoenix-fire-sword/vfx/UltraBlade.res"
const SWORD_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D fringe_texture : source_color, filter_linear, repeat_disable;
uniform float opacity = 1.0;
void fragment() {
 float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.0);
 vec3 fringe = texture(fringe_texture, vec2(clamp(edge * 0.4 + 0.45, 0.0, 1.0), 0.5)).rgb;
 vec3 red = vec3(1.0, 0.0, 0.0);
 // The 64x4 native gradient runs horizontally. Compress the source HDR
 // energy for Web Compatibility so it has facets instead of a clipped
 // solid-red silhouette; the core stays translucent over the fighters.
 vec3 energy = red * (1.59 * (0.32 + fringe.r * edge));
 ALBEDO = energy / (vec3(1.0) + energy);
 ALPHA = opacity * mix(0.28, 0.88, edge);
}"""
var host: Node3D
var maps: Dictionary = {}
var _charges: Dictionary = {}
var _appearances: Dictionary = {}
var _sword_mesh: Mesh
var _sword_shader: Shader

func setup(owner: Node3D) -> void:
	host = owner
	for profile: String in MAPS:
		var path: String = MAPS[profile]
		if not FileAccess.file_exists(path): continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary: continue
		maps[profile] = parsed
		for role: String in parsed:
			var texture_path: String = str(parsed[role])
			if not texture_path.ends_with(".png"): continue
			if ResourceLoader.exists(texture_path): host.native_textures[profile+":"+role] = load(texture_path)
	if ResourceLoader.exists(SWORD_PATH): _sword_mesh = load(SWORD_PATH)
	# Fx_Lightning_02 is an original four-row RGB bolt atlas (opaque alpha).
	# Keep fine lightning for small attacks; Q needs these broad broken strokes.
	# Evidence: assets/shadow-knight/vfx/source-manifest.json and
	# original-material-colors.json (Fx_Lightning_02_b_01). Fog deliberately
	# shares this NL artwork for its adapted shockwave; this is not an FK prefab.
	var bolt_path := "res://assets/shadow-knight/vfx/Fx_Lightning_02.png"
	if ResourceLoader.exists(bolt_path):
		for profile_name: String in ["shadow_knight","blood_moon","hawk_of_the_fog"]:
			host.native_textures[profile_name+":ultimateBolt"]=load(bolt_path)
	_sword_shader = Shader.new()
	_sword_shader.code = SWORD_SHADER

func clear() -> void:
	_charges.clear()
	_appearances.clear()

func supported(data: Dictionary) -> bool:
	return str(data.get("style","")) in ["shadow_knight","hawk_of_the_fog"]

func profile(data: Dictionary) -> String:
	var style := str(data.get("style",""))
	if data.has("appearanceId"): _appearances[style]=str(data.appearanceId)
	if style == "shadow_knight" and str(data.get("appearanceId",_appearances.get(style,""))) == "blood_moon": return "blood_moon"
	return style

func color(data: Dictionary, alpha: float = 0.88) -> Color:
	# NL native UltraThunder startColor: (0,.671,1); Dress01 red max(1,.245,.176).
	# FK palette remains an explicit adaptation, not a recovered particle color.
	match profile(data):
		"blood_moon": return Color(1.0,0.245,0.176,alpha)
		"hawk_of_the_fog": return Color(0.66,0.80,1.0,alpha)
	return Color(0.0,0.671,1.0,alpha)

func _stamp(data: Dictionary, texture_role: String, origin: Vector3, size: Vector2, life: float, role: String, options: Dictionary = {}) -> Dictionary:
	var p := profile(data)
	var texture_key := p+":"+texture_role
	if not host.native_textures.has(texture_key): return {}
	var settings := options.duplicate(true)
	settings.style = str(data.get("style",""))
	settings.appearance = str(data.get("appearanceId",_appearances.get(str(data.get("style","")),"")))
	settings.role = role
	settings.instant = settings.get("instant",true)
	settings.grow = settings.get("grow",0.85)
	settings.facing = host._facing(data)
	settings.energy_core = (role.begins_with("ultimate_") or role.begins_with("eclipse_")) and texture_role in ["trail","lightning","ultimateBolt"]
	# Lightning coverage is explicit in each map: SFX_Lightning_501 has native
	# alpha; opaque-alpha additive artwork such as FK Particle507 needs luminance.
	settings.mask = int(maps.get(p,{}).get("lightningMask",1)) if p != "hawk_of_the_fog" and texture_role == "lightning" else 1 if texture_role == "particle" else 0
	if texture_role=="ultimateBolt": settings.mask=1
	if p == "hawk_of_the_fog" and texture_role == "lightning":
		settings.uv = Vector4(1.0,0.31,0.0,0.34) # one ray cell, not all three
	if p == "hawk_of_the_fog" and texture_role == "burstTrail":
		settings.uv = Vector4(0.2,0.5,0.4,0.0) # source atlas: five columns, two rows
	var tint: Color = options.get("color",color(data))
	return host._stamp(texture_key,origin,size,tint,life,settings)

func _x(data: Dictionary) -> float:
	return float(host._fighters.get(host._source_id(data),{}).get("x",data.get("x",0.0)))

func _ring(data: Dictionary, x: float, size: float, life: float, role: String, options: Dictionary = {}) -> void:
	var settings := options.duplicate(true)
	settings.ground = true
	settings.annulus = true
	settings.grow = settings.get("grow",0.3)
	var texture := "ring" if profile(data) != "hawk_of_the_fog" else "glow"
	_stamp(data,texture,Vector3(x,0.075,0),Vector2.ONE*size,life,role,settings)

func sweep(data: Dictionary, skill: bool = false) -> void:
	var facing: float = host._facing(data)
	var fighter: Dictionary = host._fighters.get(host._source_id(data),{})
	var heavy := skill or str(data.get("name","")) == "heavy"
	var combo := int(data.get("combo",data.get("comboIndex",0)))
	var charged := int(fighter.get("attack",{}).get("fogCharges",0))
	var burst := float(fighter.get("eclipseRemaining",0.0)) > 0.0
	var origin := Vector3(_x(data)+facing*(0.64 if heavy else 0.48),1.15 if combo==2 or heavy else 1.65,0.58)
	var size := Vector2(1.9,1.10) if heavy else Vector2(1.26,0.62)
	var angle := facing*(-0.45 if heavy or combo==2 else 0.18 if combo==1 else -0.12)
	var fist_color := Color(1.0,0.614,0.2,0.85) if profile(data)=="shadow_knight" and not burst else color(data)
	_stamp(data,"trail",origin,size,0.21 if heavy else 0.14,"fist_trail",{"angle":angle,"color":fist_color})
	if skill or burst or charged > 0:
		_stamp(data,"lightning",origin+Vector3(0,0,0.02),size*Vector2(1.15,0.7),0.18,"electrified_fist",{"angle":angle,"grow":0.95})
	if charged > 0:
		_stamp(data,"burstTrail",origin,Vector2(1.2,2.1),0.30,"charged_release",{"angle":-facing*PI/2.0})
		_ring(data,_x(data),1.8+0.3*charged,0.34,"charged_release")

func charge(data: Dictionary) -> void:
	var life := float(data.get("windup",0.3))+0.05
	_stamp(data,"glow",Vector3(_x(data)+host._facing(data)*0.38,1.45,0.3),Vector2.ONE*0.48,life,"skill_charge",{"follow_id":host._source_id(data),"follow_offset":host._facing(data)*0.38,"charge":true,"windup":life,"color":color(data,0.42)})

func impact(data: Dictionary, guard: bool = false) -> void:
	var parry := str(data.get("type","")) == "parry"
	var contact: Dictionary = host._guard_contact(data) if guard or parry else data
	var origin: Vector3 = host._contact_origin(contact)
	var strong := bool(data.get("heavy",false)) or bool(data.get("skill",false)) or bool(data.get("final",false))
	_stamp(data,"impact",origin,Vector2.ONE*(0.75 if strong else 0.48),0.16 if strong else 0.11,"parry" if parry else "guard" if guard else "contact",{"grow":0.55,"priority":3})
	if strong or parry: _stamp(data,"lightning",origin,Vector2(1.15,0.65),0.17,"contact_lightning",{"angle":host._facing(data)*0.3})
	host._contact_flash(contact,guard,parry)
	host._sound("parry" if parry else host._block_sound(data) if guard else host._hit_sound(data))

func dash(data: Dictionary) -> void:
	var direction := float(data.get("direction",-host._facing(data)))
	_stamp(data,"trail",Vector3(float(data.get("x",0.0))-direction*0.35,0.95,0.18),Vector2(1.5,0.45),0.20,"step",{"color":color(data,0.45),"angle":0.0})
	_stamp(data,"smoke",Vector3(float(data.get("x",0.0)),0.28,0.15),Vector2(1.1,0.48),0.30,"step_smoke",{"color":Color(0.48,0.55,0.68,0.25),"rgb":true})

func ultimate(data: Dictionary) -> void:
	var x := _x(data)
	var fog := profile(data) == "hawk_of_the_fog"
	# The primary strike waits for the shared combat cue (FK .47 / NL 1.233s).
	# Activation effects stay below shoulders so the original rising/kicking take reads.
	var life := 0.47 if fog else 1.233333
	_ring(data,x,2.5,life,"ultimate_charge",{"grow":1.0,"instant":false,"fade_in":0.13,"fade_start":0.92,"follow_id":host._source_id(data),"color":color(data,0.42)})
	for i in 3:
		_stamp(data,"glow",Vector3(x-0.4+0.4*i,0.25+0.22*i,-0.3),Vector2.ONE*0.32,life,"ultimate_charge",{"instant":false,"delay":0.06*i,"velocity":Vector3(0,0.7,0),"color":color(data,0.5)})
	# Paired source trails wind around the lower torso; the face and the native
	# raised leg remain readable in the closer take. No impact before combat's cue.
	for side: float in [-1.0,1.0]:
		_stamp(data,"trail",Vector3(x,0.75,-0.30),Vector2(1.75,0.44),life,"ultimate_coil",{"arc":true,"instant":false,"fade_in":0.06,"fade_start":0.88,"grow":1.15,"orbit":Vector3(0.60,0.27,0.32),"orbit_phase":0.0 if side<0.0 else PI,"orbit_speed":5.0,"velocity":Vector3(0,0.70,0),"angle":side*0.6,"spin_speed":-3.0,"color":color(data,0.8)})
		if not fog:
			_stamp(data,"lightning",Vector3(x+side*0.60,1.15,-0.4),Vector2(0.65,2.0),0.46,"eclipse_charge_arc",{"delay":0.62,"angle":side*0.24,"color":color(data,0.68)})
	host._sound("ultimate")

func ultimate_impact(data: Dictionary) -> void:
	var x := float(data.get("x",_x(data)))
	var fog := profile(data) == "hawk_of_the_fog"
	_impact_crown(data,x,fog)
	_ring(data,x,5.0 if fog else 5.6,0.56,"ultimate_release")
	_ring(data,x,6.4 if fog else 7.0,0.46,"ultimate_pressure",{"delay":0.06,"grow":0.2,"color":color(data,0.5)})
	_stamp(data,"impact",Vector3(x,0.48,0.34),Vector2(2.1,1.7),0.29,"ultimate_ground_hit",{"grow":0.3,"color":color(data,0.9)})
	for side in [-1.0,1.0]:
		_stamp(data,"lightning",Vector3(x+side*1.05,0.85,-0.12),Vector2(2.65,0.86),0.37,"ultimate_ground_lightning",{"angle":side*0.12,"grow":0.7})
		_stamp(data,"lightning",Vector3(x+side*0.75,0.50,0.25),Vector2(2.8,0.44),0.24,"ultimate_running_arc",{"angle":side*0.10,"grow":0.45,"velocity":Vector3(side*3.8,0,0),"color":Color(0.84,0.93,1.0,0.88) if profile(data)!="blood_moon" else Color(1.0,0.77,0.55,0.88)})
		_stamp(data,"trail",Vector3(x+side*0.65,0.65,-0.3),Vector2(2.5,1.1),0.40,"ultimate_shock_arc",{"arc":true,"angle":side*0.50,"spin_speed":side*2.8,"grow":0.35,"color":color(data,0.78)})
		_stamp(data,"smoke",Vector3(x+side*0.75,0.38,-0.24),Vector2(2.5,0.7),0.64,"ultimate_smoke",{"color":Color(0.51,0.57,0.68,0.28),"velocity":Vector3(side*0.6,0.2,0),"rgb":true})
	if fog: _stamp(data,"burstTrail",Vector3(x,0.95,-0.14),Vector2(2.1,2.6),0.45,"ultimate_updraft",{"color":color(data,0.58)})
	else: _stamp(data,"lightning",Vector3(x,1.45,-0.35),Vector2(2.0,2.8),0.32,"eclipse_lightning",{"angle":PI/2.0})
	if not fog:
		# Several brief native bolts at different depths read as a release, not a
		# single almost-invisible thin strip smeared across the floor.
		for index: int in 3:
			var side: float=-1.0 if index%2==0 else 1.0
			_stamp(data,"lightning",Vector3(x+side*(0.45+0.35*index),1.25,-0.32-index*0.04),Vector2(2.1,3.2),0.34,"eclipse_release_bolt",{"delay":0.045*index,"angle":side*0.22,"grow":0.72,"color":color(data,0.95)})
	host._sound("heavy")

func _impact_crown(data: Dictionary,x: float,fog: bool) -> void:
	# A local energy core and a low crown of coarse source bolts carry the hit;
	# pinprick sparks only accent it. The crown's center is transparent, leaving
	# the crouching player's head and the standing enemy's face readable.
	_stamp(data,"glow",Vector3(x,0.20,-0.32),Vector2(2.4,0.72),0.24,"ultimate_core",{"instant":true,"grow":0.95,"fade_start":0.32,"color":Color(0.86,0.96,1,0.9) if profile(data)!="blood_moon" else Color(1,0.80,0.62,0.9)})
	for side: float in [-1.0,1.0]:
		var row: float=0.0 if side<0.0 else 0.5
		_stamp(data,"ultimateBolt",Vector3(x+side*1.1,0.50,0.52),Vector2(3.4,0.66),0.34,"ultimate_bolt_front",{"uv":Vector4(1,0.25,0,row),"instant":true,"grow":0.95,"angle":side*0.10,"velocity":Vector3(side*2.8,0.0,0),"fade_start":0.55,"color":color(data,0.96)})
		_stamp(data,"ultimateBolt",Vector3(x+side*1.30,0.95,-0.3),Vector2(2.4,0.9),0.42,"ultimate_bolt_crown",{"uv":Vector4(1,0.25,0,row+0.25),"instant":true,"grow":0.92,"angle":side*1.02,"velocity":Vector3(side*0.4,0.25,0),"fade_start":0.62,"color":color(data,0.92)})
	_stamp(data,"ultimateBolt",Vector3(x,0.55,-0.40),Vector2(5.4,2.25),0.42,"ultimate_bolt_arc",{"uv":Vector4(1,0.25,0,0.25),"arc":true,"instant":true,"grow":0.9,"angle":0.4,"spin_speed":1.0,"fade_start":0.58,"color":color(data,0.95)})

func event(data: Dictionary) -> void:
	match str(data.get("type","")):
		"ultimate": ultimate(data)
		"ultimateImpact": ultimate_impact(data)
		"burstBegin":
			_ring(data,_x(data),2.4,0.5,"eclipse_begin")
			_stamp(data,"lightning",Vector3(_x(data),1.0,-0.25),Vector2(1.5,1.7),0.26,"eclipse_begin")
		"lightningDischarge":
			var origin := Vector3(float(data.get("x",0.0)),1.2,0.50)
			_stamp(data,"lightning",origin,Vector2(1.45,1.45),0.25,"lightning_discharge",{"angle":0.55,"grow":1.0})
			_stamp(data,"glow",origin,Vector2.ONE*0.72,0.15,"lightning_discharge",{"color":Color(0.92,0.94,1.0,0.7)})
		"guardBreak":
			_ring(data,float(data.get("x",0.0)),2.2,0.36,"guard_break")
		"enemyDown":
			_stamp(data,"smoke",Vector3(float(data.get("x",0.0)),0.3,0.08),Vector2(1.8,0.55),0.42,"defeat",{"color":color(data,0.23)})
		"fogCharge", "Fogcharge":
			var amount := int(data.get("charges",1))
			var id := str(data.get("sourceId","player"))
			if amount>int(_charges.get(id,0)): _charge_flash(data,amount)
			_charges[id]=amount

func observe(fighter: Dictionary) -> void:
	if str(fighter.get("style","")) != "hawk_of_the_fog": return
	var id := str(fighter.get("id","player"))
	var amount := int(fighter.get("fogCharges",0))
	if amount > int(_charges.get(id,0)): _charge_flash(fighter,amount)
	_charges[id] = amount

func _charge_flash(data: Dictionary, amount: int) -> void:
	for i in clampi(amount,1,3):
		_stamp(data,"glow",Vector3(float(data.get("x",0.0))-0.22+0.22*i,1.0,-0.24),Vector2.ONE*0.18,0.40,"fog_charge",{"follow_id":str(data.get("id","player")),"follow_offset":-0.22+0.22*i,"color":Color(0.75,0.88,1.0,0.75)})

func sword_field(data: Dictionary) -> void:
	if str(data.get("style","")) != "fenghuang" or str(data.get("appearanceId","")) != "fire_and_sword" or not bool(data.get("final",false)) or _sword_mesh == null: return
	# Native ultra_end_dress01: two rings, six each, size1.5, y1.343 + root .01,
	# life3, speed/gravity0. Deterministic angular distribution adapts Unity random
	# spawning; trigger uses this game's final cue, absent from source clip events.
	for radius: float in [1.5,3.0]:
		for i in 6:
			host._reserve()
			var phase := TAU*float(i)/6.0+(0.28 if radius>2.0 else 0.0)
			var node := MeshInstance3D.new()
			node.mesh = _sword_mesh
			node.position = Vector3(float(data.get("x",0.0))+cos(phase)*radius,1.353,sin(phase)*radius)
			node.rotation = Vector3(deg_to_rad(90.0+float(i%3)*10.0),deg_to_rad(-20.0+float(i%3)*20.0),deg_to_rad(-20.0+float((i+1)%3)*20.0))
			node.scale = Vector3.ONE*1.5
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := ShaderMaterial.new()
			material.shader = _sword_shader
			material.set_shader_parameter("fringe_texture",load("res://assets/phoenix-fire-sword/vfx/fringe.png"))
			node.material_override = material
			host.add_child(node)
			host.active.append({"node":node,"mat":material,"mode":"native_sword","texture":"Fuka_C4_04_01_UltraBlade","origin":node.position,"base_scale":node.scale,"time":0.0,"life":3.0,"settings":{"style":"fenghuang","appearance":"fire_and_sword","role":"original_sword_field"}})

func snapshot() -> Dictionary:
	var counts := {"shadow_knight":0,"blood_moon":0,"hawk_of_the_fog":0}
	var roles: Array[String] = []
	var swords := 0
	for item: Dictionary in host.active:
		if float(item.time)<0: continue
		if str(item.mode)=="native_sword": swords+=1
		var style := str(item.settings.get("style",""))
		if not counts.has(style): continue
		counts[style] += 1
		if str(item.settings.get("appearance",""))=="blood_moon": counts.blood_moon+=1
		var role := str(item.settings.get("role",""))
		if not roles.has(role): roles.append(role)
	return {"shadowKnightCount":counts.shadow_knight,"bloodMoonCount":counts.blood_moon,"hawkFogCount":counts.hawk_of_the_fog,"lightningRoles":roles,"nativeSwordCount":swords,"adaptation":"Original source artwork; horizontal emitter placement and timing. Sword mesh/bursts/lifetime from ultra_end_dress01; fringe shader approximated."}
