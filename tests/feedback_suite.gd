extends SceneTree

class FeedbackProbe extends "res://scripts/effects.gd":
	var heard: Array[String]=[]
	var released: Array[String]=[]
	func _ready() -> void:
		_quad.size=Vector2.ONE
		for key: String in NATIVE_FILES:
			native_textures[key]=load("res://assets/vfx/native/"+str(NATIVE_FILES[key])+".png")
		for key: String in PHOENIX_FILES:
			native_textures[key]=load("res://assets/vfx/phoenix-native/"+str(PHOENIX_FILES[key])+".png")
		native_sphere=load("res://assets/vfx/native/Sphere002-morph.res")
	func _sound(key: String) -> void:
		heard.append(key)
	func _attack_sweep(data: Dictionary) -> void:
		released.append("sweep:"+str(data.get("name","light")))
	func _ability_release(_data: Dictionary) -> void:
		released.append("ability")

var passed:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures.append(message)
	else: passed+=1

func textures(fx, key: String) -> Array:
	return fx.active.filter(func(item: Dictionary) -> bool: return str(item.get("texture",""))==key)

func fighter(name: String="light", combo: int=0) -> Dictionary:
	return {"id":"player","side":"player","x":0.0,"facing":1,"state":"attack","stateTime":0.0,"attack":{"name":name,"comboIndex":combo,"windup":0.30}}

func attack(name: String="light", combo: int=0) -> Dictionary:
	return {"type":"attack","sourceId":"player","side":"player","name":name,"combo":combo,"windup":0.30}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fx:=FeedbackProbe.new()
	root.add_child(fx)
	var f: Dictionary=fighter()
	fx.update_fighters(f,[])
	fx.handle_event(attack())
	fx.tick(0.25)
	check(fx.heard.is_empty() and fx.released.is_empty(),"wall time cannot advance attack cues")
	f.stateTime=0.24
	fx.tick(0.0)
	check(fx.heard.is_empty(),"tick zero freezes pending wind cue")
	fx.tick(1.0/60.0)
	check(fx.heard==["swing"] and fx.released.is_empty(),"air precedes contact at fighter windup")
	fx.tick(1.0/60.0)
	check(fx.heard.size()==1,"one wind per attack")
	f.stateTime=0.28
	fx.tick(1.0/60.0)
	check(fx.released==["sweep:light"],"ink sweep follows actual state time")
	fx.handle_event(attack("heavy"))
	f.attack.name="heavy"
	f.stateTime=0.05
	fx.tick(0.01)
	f.state="stagger"
	fx.tick(0.5)
	check(fx._cues.is_empty() and fx.heard.size()==1,"interrupted windup cancels without phantom heavy impact")
	f=fighter()
	fx.update_fighters(f,[])
	fx.handle_event(attack())
	f.attack.name="heavy"
	f.stateTime=0.29
	fx.tick(0.1)
	check(fx._cues.is_empty() and fx.released.size()==1,"replacement attack cannot inherit old cue")
	fx.handle_event(attack())
	fx.update_fighters({},[])
	fx.tick(0.5)
	check(fx._cues.is_empty(),"removed source cannot create a delayed ghost attack")
	f=fighter("ability")
	fx.update_fighters(f,[])
	fx.handle_event(attack("ability"))
	fx.handle_event({"type":"ability","sourceId":"player","side":"player","windup":0.3})
	f.stateTime=0.30
	fx.tick(0.01)
	check(fx.released.count("ability")==1 and fx.released.count("sweep:ability")==0,"ability attack and charge events release once")
	check(fx.heard.count("swing_heavy")==1 and not fx.heard.has("heavy"),"empty ability has air but no impact sound")
	fx.clear()
	fx.handle_event({"type":"block","sourceId":"enemy","x":4.0,"contactX":-1.25,"contactY":1.15,"facing":-1})
	var flash: Dictionary=fx.active.back()
	check(fx.heard.back()=="block","guard has its own dull sound")
	check(is_equal_approx(flash.node.position.x,-1.25) and is_equal_approx(flash.node.position.y,2.05),"guard marks hand height at actual contact X rather than pushed waist position")
	check(float(flash.mat.get_shader_parameter("opacity"))==1.0,"new contact flash is visible on hit-stop frame")
	fx.tick(0.0)
	check(float(flash.time)==0.0,"contact flash freezes during hit stop")
	fx.clear()
	fx.handle_event({"type":"block","contactX":0.1,"guardContactY":2.18})
	check(is_equal_approx(fx.active.back().node.position.y,2.18),"explicit hand contact height is supported")
	fx.clear()
	fx.handle_event({"type":"parry","side":"player","contactX":2.2,"facing":-1})
	check(fx.heard.back()=="parry" and textures(fx,"brush").size()==2,"parry gets distinct sound and two native cold brush arcs")
	check(textures(fx,"impact").is_empty() and textures(fx,"drops").is_empty() and textures(fx,"splashes").is_empty(),"parry never creates ordinary black ink hit or splatter")
	for arc: Dictionary in textures(fx,"brush"):
		var color: Color=arc.mat.get_shader_parameter("tint")
		check(color.g>=0.8 and color.b>=0.9 and color.r>=0.2,"parry arcs use cold white and cyan")
		check(is_equal_approx(arc.node.position.y,2.05) and float(arc.mat.get_shader_parameter("opacity"))==1.0,"parry arcs show at raised hands on the contact frame")
		check(is_equal_approx(arc.node.position.x,2.2-0.28) and absf(arc.base_scale.x)<=0.75 and absf(arc.base_scale.y)<=0.85,"parry catches ahead of the hands without a face-sized circle")
	var parry_before: Dictionary=fx.snapshot()
	fx.tick(0.0)
	check(fx.snapshot()==parry_before,"hitstop freezes native parry arcs")
	fx.clear()
	fx.handle_event({"type":"hit","side":"player","contactX":0.9,"heavy":true,"facing":1})
	check(fx.heard.back()=="heavy" and is_equal_approx(fx.active.back().node.position.x,0.9),"heavy contact chooses low impact at contact coordinate")
	check(textures(fx,"impact").size()==2 and textures(fx,"fluid").size()==2,"heavy hit has native black-white center and directional burst")
	fx.clear()
	for facing in [-1.0,1.0]:
		fx.handle_event({"type":"hit","side":"player","contactX":0.0,"skill":true,"facing":facing})
		var jets: Array=textures(fx,"fluid")
		check(jets.size()==2,"ability contact shares directional black-white native burst")
		var initial_x: float=jets[0].node.position.x
		fx.tick(0.05)
		check((float(jets[0].node.position.x)-initial_x)*facing>0.05,"directional impact travels with facing "+str(facing))
		fx.clear()
	fx.update_fighters(fighter(),[])
	fx._native_sweep({"sourceId":"player","side":"player","name":"light","combo":0})
	check(textures(fx,"curl").is_empty(),"first jab does not accumulate a second curl cloud")
	for brush: Dictionary in textures(fx,"brush"):
		check(float(brush.life)<=0.22 and brush.base_scale.x<=2.17 and brush.base_scale.y<=1.52,"jab brush clears quickly and is twenty percent smaller")
	fx.tick(0.23)
	check(fx.active.is_empty(),"first jab ink has fully cleared before next contact")
	fx._native_sweep({"sourceId":"player","side":"player","name":"light","combo":1})
	check(textures(fx,"curl").size()==1 and float(textures(fx,"curl")[0].life)<=0.18,"second jab curl is brief and does not linger across combo")
	fx.clear()
	fx._native_sweep({"sourceId":"player","side":"player","name":"heavy","combo":0})
	check(textures(fx,"taiji").size()==1 and textures(fx,"taiji")[0].settings.ground,"heavy keeps native Taiji on ground instead of covering face")
	check(textures(fx,"brush")[0].base_scale.x>3.0,"heavy remains visually broader than a jab")
	fx.clear()
	fx._native_ability({"sourceId":"player","side":"player","facing":1})
	var ability_brush: Dictionary=textures(fx,"brush")[0]
	check(ability_brush.origin.y+ability_brush.base_scale.y*0.5<2.2 and ability_brush.origin.z<0.0,"ability arc stays below face and behind the fighter")
	fx.clear()
	fx._native_ultimate({"x":0.0,"targetX":1.0})
	check(textures(fx,"landscape").size()==1 and is_equal_approx(textures(fx,"landscape")[0].life,3.42),"ultimate landscape retains original duration")
	var spheres: Array=fx.active.filter(func(item: Dictionary) -> bool: return item.mode=="sphere")
	check(spheres.size()==2 and is_equal_approx(spheres[0].time,-0.10) and is_equal_approx(spheres[1].time,-1.65),"ultimate sphere cue timings are unchanged")
	fx.clear()
	fx.handle_event({"type":"ultHit","side":"player","contactX":1.0,"final":false})
	check(is_equal_approx(textures(fx,"impact")[0].life,0.36) and textures(fx,"fluid").is_empty(),"ultimate impact keeps its prior lifetime without normal-combat jets")
	fx.clear()
	for entry: Dictionary in [{"combo":0,"expected":"hit"},{"combo":1,"expected":"hit_alt"},{"stance":"kick","expected":"kick"},{"heavy":true,"stance":"kick","expected":"heavy"}]:
		var event: Dictionary={"type":"hit","side":"player","contactX":0.85,"contactY":1.58,"facing":1}
		event.merge(entry,true)
		fx.handle_event(event)
		check(fx.heard.back()==entry.expected,"contact routing distinguishes "+str(entry.expected))
		fx.clear()
	fx.handle_event({"type":"hit","side":"player","combo":1,"contactX":0.85,"contactY":1.58,"facing":-1})
	check(textures(fx,"drops").is_empty() and textures(fx,"splashes").size()==2,"light contact has no large drops overlay and only two brief flecks")
	for core: Dictionary in textures(fx,"impact"):
		check(core.base_scale.x<=0.65 and core.life<=0.15 and core.origin==Vector3(0.85,1.58,0.52) + Vector3(0,0,0.025 if core==textures(fx,"impact")[1] else 0),"light native impact stays compact at exact contact")
	var light_before: Dictionary=fx.snapshot()
	fx.tick(0.0)
	check(fx.snapshot()==light_before,"revised light contact remains frozen at zero delta")
	fx.tick(0.23)
	check(fx.active.is_empty(),"all light-contact ink clears within 230 milliseconds of simulation")
	fx.handle_event({"type":"block","contactX":1.0,"heavy":true})
	check(fx.heard.back()=="block_heavy","heavy guard has a heavier contact without a landed-hit sound")
	fx.clear()
	fx.handle_event({"type":"hit","side":"enemy","sourceId":"enemy","contactX":0.2,"contactY":1.58})
	check(fx.active.size()==2,"enemy light contact avoids a second wash and particle cloud")
	for item: Dictionary in fx.active:
		check(item.life<=0.18,"enemy light contact clears without hiding the player's next movement")
	fx.clear()
	fx.handle_event({"type":"hit","style":"fenghuang","side":"player","stance":"kick","contactX":0.5})
	check(fx.heard.back()=="kick" and fx.snapshot().fireCount==3,"phoenix light kick retains its fire contact, jet and compact embers")
	for item: Dictionary in fx.active:
		check(item.life<=0.18,"phoenix normal contact has short visual recovery")
	fx.clear()
	# Exercise real voice arbitration on the dummy audio backend, with a long
	# synthetic silent stream; no graphics device or microphone is involved.
	var silence:=AudioStreamWAV.new()
	silence.format=AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate=44100
	silence.data=PackedByteArray()
	var bytes:=PackedByteArray()
	bytes.resize(44100*2)
	silence.data=bytes
	for index: int in 8:
		var voice:=AudioStreamPlayer.new()
		voice.stream=silence
		fx.add_child(voice)
		fx.audio_players.append(voice)
		voice.set_meta("feedback_priority",4)
		voice.set_meta("feedback_serial",index)
		voice.play()
	check(fx._audio_voice(1)==null and fx._audio_voice(3)==null,"air and heavy cannot steal a full set of perfect-parry voices")
	fx.audio_players[5].set_meta("feedback_priority",1)
	check(fx._audio_voice(3)==fx.audio_players[5],"a contact replaces lower-priority air before a perfect catch")
	fx.audio_players[2].stop()
	check(fx._audio_voice(1)==fx.audio_players[2],"an idle voice is preferred to cutting an audible tail")
	fx.sounds={"hit":silence,"parry":silence}
	# Bypass the recording override to test actual playback and deterministic pitch.
	var real_fx=load("res://scripts/effects.gd").new()
	root.add_child(real_fx)
	real_fx.sounds={"hit":silence,"parry":silence}
	real_fx._sound("hit")
	check(real_fx.audio_players[0].get_meta("feedback_sound")=="hit" and is_equal_approx(real_fx.audio_players[0].pitch_scale,1.0),"real first contact starts immediately at natural pitch")
	real_fx._sound_clock+=0.05
	real_fx._sound("hit")
	check(is_equal_approx(real_fx.audio_players[1].pitch_scale,0.975),"repeat contact uses a bounded deterministic pitch variant")
	real_fx.clear()
	real_fx._sound("hit")
	check(is_equal_approx(real_fx.audio_players[0].pitch_scale,1.0),"reset clears audio variant history for deterministic replay")
	real_fx.clear()
	real_fx.free()
	fx.clear()
	fx.free()
	silence=null
	# AudioServer releases stopped playback on its mixer thread, not merely on
	# the next SceneTree frame. Give the dummy mixer one bounded cleanup interval.
	await create_timer(0.15).timeout
	await process_frame
	await process_frame
	print("FEEDBACK SUITE: ",passed," passed, ",failures.size()," failed")
	quit(0 if failures.is_empty() else 1)

