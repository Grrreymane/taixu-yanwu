extends SceneTree
const Effects := preload("res://scripts/sentience_effects.gd")
var failures: Array[String] = []
var checks := 0
var textures: Array[Texture2D] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error(label)
func run() -> void:
	for filename in DirAccess.get_files_at("res://assets/vfx/sentience-native"):
		if filename.ends_with(".png"):
			var path := "res://assets/vfx/sentience-native/"+filename
			var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
			texture.take_over_path(path);textures.append(texture)
	var fx := Effects.new();root.add_child(fx)
	var player := {"id":"player","side":"player","style":"azure_empyrea","state":"idle"}
	var foe := {"id":"enemy-1","side":"enemy","style":"sentience","x":1.0,"facing":-1.0,"state":"attack","stateTime":0.0,
		"attack":{"motion":"senti_sword_1","weapon":"sword","windup":0.48,"duration":0.91}}
	var event := {"type":"attack","sourceId":"enemy-1","style":"sentience","side":"enemy","weapon":"sword","motion":"senti_sword_1","x":1.0,"facing":-1.0,"windup":0.48,"duration":0.91}
	fx.update_fighters(player,[foe]);fx.handle_event(event)
	check(fx.snapshot().nativeTextures==13,"all thirteen exact native PNGs load")
	check(fx.snapshot().pending==1,"weapon swing queues on attack")
	check("sword_icon" in fx.snapshot().textures,"original sword calligraphy appears on first switch")
	var frozen: Dictionary=fx.snapshot()
	for i in 30:fx.tick(0.0)
	check(fx.snapshot()==frozen,"pause and hitstop freeze all ages/cues")
	foe.stateTime=0.40;fx.update_fighters(player,[foe]);fx.tick(0.4)
	check(fx.snapshot().emittedSwings==0,"swing does not use unrelated wall-time")
	foe.stateTime=0.43;fx.update_fighters(player,[foe]);fx.tick(0.03)
	check(fx.snapshot().emittedSwings==1 and "blade" in fx.snapshot().textures,"sword blade appears just before actual contact")
	check("flash" not in fx.snapshot().textures and "hit" not in fx.snapshot().textures,"empty swing creates no false hitflash")
	foe.state="stagger";foe.stateTime=0.0;fx.update_fighters(player,[foe]);fx.tick(0.01)
	check(fx.snapshot().pending==0,"stagger cancels remaining attack cue")
	fx.clear();foe.state="attack";foe.stateTime=0.0;fx.update_fighters(player,[foe]);fx.handle_event(event)
	fx.handle_event({"type":"parry","style":"azure_empyrea","side":"player","sourceId":"player","targetId":"enemy-1"})
	check(fx.snapshot().pending==0,"player parry cancels enemy by targetId despite player style")
	fx.handle_event(event);fx.handle_event({"type":"ultimate","side":"player"})
	check(fx.snapshot().pending==0,"player ultimate drops pending enemy weapon cue")
	fx.clear();fx.update_fighters(player,[foe])
	fx.handle_event({"type":"block","style":"sentience","side":"player","sourceId":"enemy-1","targetId":"player","contactX":0.35,"x":0.0,"facing":-1.0})
	check(fx.snapshot().active==1 and "flash" in fx.snapshot().textures,"blocked enemy blow retains source sentience style with player side")
	check(absf(float(fx._active[0].origin.x)-0.35)<0.0001,"block center uses precise contactX")
	check(is_equal_approx(float(fx._active[0].material.get_shader_parameter("opacity")),1.0),"impact is fully visible on the hitstop's very first frame")
	fx.tick(0.0)
	check(is_equal_approx(float(fx._active[0].material.get_shader_parameter("opacity")),1.0),"frozen impact cannot fade in or fade out during hitstop")
	fx.clear();fx.update_fighters(player,[foe]);fx.handle_event(event)
	var twin:=foe.duplicate(true);twin.id="enemy-2";twin.attack.motion="senti_spear_1";twin.attack.weapon="spear"
	fx.update_fighters(player,[foe,twin]);var second:=event.duplicate(true);second.sourceId="enemy-2";second.motion="senti_spear_1";second.weapon="spear";fx.handle_event(second)
	fx.handle_event({"type":"parry","sourceId":"player","targetId":"enemy-1"})
	check(fx.snapshot().pending==1 and fx._cues[0].id=="enemy-2","cancel affects only the correct enemy in a group")
	fx.handle_event({"type":"spawnStage"})
	check(fx.snapshot().active==0 and fx.snapshot().pending==0,"new stage leaves no residual particles or pending cues")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Headless resource and simulation-event lifecycle; native shader visually reviewed by root separately."}
	FileAccess.open("res://build/reports/sentience-effects.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SENTIENCE EFFECTS ",checks-failures.size(),"/",checks)
	fx.free();quit(0 if failures.is_empty() else 1)
