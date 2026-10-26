extends SceneTree
## CPU-only cue and particle lifecycle, no shader/rendering claims.
const Effects=preload("res://scripts/sentience_effects.gd")
var checks:=0
var failures:Array[String]=[]
var evidence:Array=[]
func _initialize() -> void:call_deferred("_run")
func _check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _foe(id:String,clock:float) -> Dictionary:
	return {"id":id,"side":"enemy","style":"sentience","hp":100.0,"x":2.0,"facing":-1.0,"state":"attack","stateTime":clock,"attack":{"motion":"senti_sword_1","weapon":"sword","windup":0.64,"duration":1.07}}
func _queue(fx:Node3D,foe:Dictionary) -> void:
	fx.handle_event({"type":"attack","sourceId":foe.id,"side":"enemy","style":"sentience","motion":foe.attack.motion,"weapon":foe.attack.weapon,"windup":foe.attack.windup,"duration":foe.attack.duration})
func _run() -> void:
	var player:={"id":"player","side":"player"}
	for targets:Array in [["near"],[]]:
		var fx:=Effects.new();root.add_child(fx)
		var near:=_foe("near",0.20)
		var far:=_foe("far",0.40)
		fx.update_fighters(player,[near,far]);_queue(fx,near);_queue(fx,far)
		fx.tick(0.01)
		# Real native ribbon gives an owned active particle to suspend along
		# with the separate not-yet-fired cue. Textures use headless loading.
		fx._weapon_ribbon("blade",Vector3.ZERO,Vector2.ONE,Color.WHITE,0.28,{"owner":"far","role":"weapon_trail","instant":true})
		var ribbon:Dictionary=fx._active[-1]
		var age:float=ribbon.time
		var clock:float=fx._cues[-1].clock
		fx.handle_event({"type":"ultimate","targets":targets})
		var expected:int=2 if targets.is_empty() else 1
		_check(fx.snapshot().pending==expected,"only the actual ultimate target loses its pending attack")
		_check(fx.snapshot().suspendedSources.size()==expected,"empty-target activation suspends every enemy without interrupting")
		for i in 48:fx.tick(0.05)
		_check(is_equal_approx(ribbon.time,age) and not ribbon.node.visible,"remote owned ribbon stays hidden at its original age throughout cut-in")
		_check(fx._cues[-1].clock==clock and fx.snapshot().emittedSwings==0,"remote pre-contact cue never advances or fires during cut-in")
		fx.handle_event({"type":"ultimateEnd"})
		fx.tick(0.01)
		_check(fx.snapshot().suspendedSources.is_empty() and ribbon.node.visible,"ultimateEnd restores the existing ribbon on the next tick")
		_check(is_equal_approx(ribbon.time,age+0.01),"resumed trail advances from its prior age rather than restarting")
		far.stateTime=0.60;fx.update_fighters(player,[near,far]);fx.tick(0.01)
		_check(fx.snapshot().emittedSwings==1,"restored remote cue fires before its actual 0.64-second contact")
		fx.tick(0.01)
		_check(fx.snapshot().emittedSwings==1,"resuming cannot duplicate a source swing")
		evidence.append({"targets":targets,"restored":fx.snapshot()})
		fx.handle_event({"type":"ultimate","targets":[]})
		fx.handle_event({"type":"end"})
		_check(fx.snapshot().pending==0 and fx.snapshot().suspendedSources.is_empty(),"ending an encounter clears all suspension and pending cues")
		fx.handle_event({"type":"ultimate","targets":[]})
		fx.handle_event({"type":"reset"})
		_check(fx.snapshot().pending==0 and fx.snapshot().suspendedSources.is_empty() and fx.snapshot().active==0,"reset cannot retain a hidden effect from the prior encounter")
		fx.free()
	var legacy:=Effects.new()
	var foe:=_foe("legacy",0.0);legacy.update_fighters(player,[foe]);_queue(legacy,foe)
	legacy.handle_event({"type":"ultimate"})
	_check(legacy.snapshot().pending==0 and legacy.snapshot().suspendedSources.is_empty(),"legacy events without target IDs keep their original cancellation behavior")
	legacy.free()
	await process_frame
	var report:={"suite":"sentience_ultimate_suspend","checks":checks,"passed":failures.is_empty(),"failures":failures,"gpuUsed":false,"evidence":evidence}
	FileAccess.open("res://build/reports/sentience-ultimate-suspend.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures}));quit(0 if failures.is_empty() else 1)
