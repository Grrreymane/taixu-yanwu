extends SceneTree
## Headless integration: actual menus, source textures, native Q framing and
## user-approved dialogue. No screenshot or graphics-window work is required.
const Camera = preload("res://scripts/night_squire_camera.gd")
const BattleCamera = preload("res://scripts/battle_camera.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const Story = preload("res://scripts/sentience_story.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
const STYLE_IDS := ["azure_empyrea", "fenghuang", "night_squire"]
var checks := 0
var failures: Array[String] = []
var approved_line_count := 0

class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve()
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what: int) -> void: pass
class QuietMusic extends Node:
	func unlock() -> void: pass
	func toggle() -> void: pass
	func set_context(_phase: String,_paused: bool,_ultimate: bool) -> void: pass
	func tick(_delta: float) -> void: pass
	func set_focused(_focused: bool) -> void: pass
	func snapshot() -> Dictionary: return {"enabled":false}
class EffectProbe extends "res://scripts/effects.gd":
	var heard: Array[String]=[]
	func _sound(key: String) -> void: heard.append(key)
class ErrorRecorder extends Logger:
	var errors: Array=[]
	func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type!=Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("CHECK FAILED: ",label)
func run() -> void:
	OS.add_logger(recorder)
	_camera_contract()
	_effect_contract()
	_approved_dialogue_contract()
	await _main_contract()
	await process_frame
	await process_frame
	check(recorder.errors.is_empty(),"headless presentation integration has no engine/script errors")
	var report={"suite":"night_squire_presentation","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"approvedDialogueLines":approved_line_count,"gpuUsed":false,"browserUsed":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/night-squire-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	OS.remove_logger(recorder)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _project(frame: Dictionary,point: Vector3,aspect: float) -> Vector2:
	var eye:=Transform3D(Basis.IDENTITY,frame.position).looking_at(frame.target)
	var local: Vector3=eye.affine_inverse()*point
	var half_height: float=-local.z*tan(deg_to_rad(float(frame.fov)*0.5))
	return Vector2(local.x/(half_height*aspect),local.y/half_height)
func _camera_contract() -> void:
	check(is_equal_approx(Camera.DURATION,1.5833333),"white Q camera ends with the full original ND_Ultra activation")
	for aspect: float in [16.0/9.0,1.6,0.75]:
		for facing: float in [-1.0,1.0]:
			for x: float in [-5.0,0.0,5.0]:
				var battle: Dictionary=BattleCamera.frame(x,[x+facing*1.3],aspect)
				var entry: Dictionary=battle.duplicate(true)
				entry.position+=Vector3(0.1,0.05,0.1)
				var focus={"playerX":x,"facing":facing,"aspect":aspect,"entry":entry,"battle":battle}
				var initial: Dictionary=Camera.sample(0.0,focus)
				var final: Dictionary=Camera.sample(Camera.DURATION,focus)
				check(initial.position==entry.position and initial.target==entry.target and initial.fov==entry.fov,"Q begins at supplied live camera %s"%str([aspect,facing,x]))
				check(final.position.is_equal_approx(battle.position) and final.target.is_equal_approx(battle.target) and is_equal_approx(final.fov,battle.fov) and is_equal_approx(final.roll,battle.roll),"Q returns to supplied battle framing within float precision %s"%str([aspect,facing,x]))
				for at: float in [0.0,0.1,0.2,0.55,1.05,1.3,Camera.DURATION]:
					var frame: Dictionary=Camera.sample(at,focus)
					check(frame.position.is_finite() and frame.target.is_finite() and is_finite(frame.fov) and is_finite(frame.roll) and frame.position.z>=4.8 and frame.fov>=34.0 and frame.fov<=36.5,"finite front-side framing %s"%str([aspect,facing,x,at]))
					check(frame==Camera.sample(at,focus),"paused Q framing is deterministic %s"%str([aspect,facing,x,at]))
					var head:=_project(frame,Vector3(x,2.85,0.0),aspect)
					var feet:=_project(frame,Vector3(x,0.05,0.0),aspect)
					check(absf(head.x)<0.98 and absf(head.y)<0.98 and absf(feet.x)<0.98 and absf(feet.y)<0.98,"head and feet remain in framing %s"%str([aspect,facing,x,at]))
				for boundary: float in [0.20,Camera.RETURN_AT,Camera.DURATION]:
					var before: Dictionary=Camera.sample(boundary-0.00001,focus)
					var after: Dictionary=Camera.sample(boundary+0.00001,focus)
					check(before.position.distance_to(after.position)<0.002 and absf(before.fov-after.fov)<0.002,"camera joins remain continuous %s"%str([aspect,facing,x,boundary]))
	for at: float in [0.0,0.1,0.55,1.3,Camera.DURATION]:
		var right: Dictionary=Camera.sample(at,{"playerX":-0.7,"facing":1.0,"aspect":1.6,"entry":{},"battle":BattleCamera.frame(-0.7,[0.6],1.6)})
		var left: Dictionary=Camera.sample(at,{"playerX":0.7,"facing":-1.0,"aspect":1.6,"entry":{},"battle":BattleCamera.frame(0.7,[-0.6],1.6)})
		check(is_equal_approx(right.position.x,-left.position.x) and is_equal_approx(right.target.x,-left.target.x) and is_equal_approx(right.roll,-left.roll),"Q mirrors facing consistently %.2f"%at)

func _event(kind: String) -> Dictionary:
	return {"type":kind,"style":"night_squire","side":"player","sourceId":"player","x":0.0,"facing":1.0,"targetX":1.2,"contactX":0.7,"nightBurst":false}
func _no_ink(fx) -> bool:
	return fx.active.all(func(item: Dictionary):return str(item.mode)!="sphere" and (str(item.mode)!="native" or str(item.get("texture","")).begins_with("night_")))
func _effect_contract() -> void:
	var fx:=EffectProbe.new()
	root.add_child(fx)
	check(fx.NIGHT_FILES.keys().all(func(key):return fx.native_textures.has(key)),"all eight original C3 texture resources load")
	var fighter={"id":"player","side":"player","style":"night_squire","x":0.0,"facing":1.0,"state":"attack","stateTime":0.0,"attack":{"name":"ability","comboIndex":0,"windup":0.40}}
	fx.update_fighters(fighter,[])
	var attack:=_event("attack")
	attack.merge({"name":"ability","windup":0.40})
	var ability:=_event("ability")
	ability.windup=0.40
	fx.handle_event(attack)
	fx.handle_event(ability)
	check(fx._cues.size()==2 and fx.active.is_empty(),"E attack and skill events share one pending contact cue without ink charge")
	fx.tick(0.25)
	check(fx.active.is_empty(),"E trail waits for fighter animation time")
	fighter.stateTime=0.40
	fx.tick(0.01)
	check(fx.snapshot().textureKeys==["night_trail"] and _no_ink(fx),"E releases its native C3 trail at the actual first leg contact")
	fx.clear()
	fx.handle_event(_event("ultimate"))
	check(fx.active.size()==6 and _no_ink(fx),"Q activation uses only C3 floor light and five rising lights, with no C5 ink")
	check(fx.active.all(func(item):return not bool(item.settings.get("contact",false))),"Q's non-damaging activation cannot fabricate hit flashes")
	var frozen: Dictionary=fx.snapshot()
	fx.tick(0.0)
	check(fx.snapshot()==frozen,"Q effects freeze during pause and hitstop")
	fx.tick(Camera.DURATION)
	check(fx.active.is_empty(),"Q activation visuals finish before burst combat begins")
	fx.handle_event(_event("burstBegin"))
	check(fx.snapshot().textureKeys==["night_ring"] and _no_ink(fx),"burst entry adds only its original C3 release ring")
	fx.clear()
	for burst in [false,true]:
		var swing:=_event("attack")
		swing.merge({"name":"light","nightBurst":burst},true)
		fx._attack_sweep(swing)
		check(fx.snapshot().textureKeys==["night_burst_trail" if burst else "night_trail"] and _no_ink(fx),"ordinary and burst strikes use distinct C3 trails "+str(burst))
		fx.clear()
	for kind in ["hit","parry","dodge","evade"]:
		fx.handle_event(_event(kind))
		check(_no_ink(fx) and fx.snapshot().nightCount>0,"white "+kind+" uses its independent effect family")
		fx.clear()
	var block:=_event("block")
	block.targetSide="player"
	block.side="enemy"
	block.sourceId="enemy"
	fx.handle_event(block)
	check(_no_ink(fx),"incoming block never switches white to cloud-ink curl")
	fx.clear()
	fighter.state="dodge"
	fighter.stateTime=0.16
	fighter.dodgeDirection=-1.0
	fx.update_fighters(fighter,[])
	check(_no_ink(fx) and fx.snapshot().nightCount>0,"continuous dodge steps preserve the C3 dust family")
	fx.clear()
	var chase:=_event("attack")
	chase.merge({"name":"light","parryFollowup":true,"chaseAdvance":0.8})
	fx.handle_event(chase)
	check(_no_ink(fx) and fx.snapshot().nightCount>0,"parry follow-up chase uses C3 dust instead of ink streaks")
	fx.clear()
	fx.free()

func _text_rows(lines: Array) -> Array:
	return lines.map(func(line):return [str(line.speaker),str(line.text)])
func _approved_dialogue_contract() -> void:
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/dialogue-editing/user-integrated.json"))
	check(baseline.revision==Dialogue.REVISION and baseline.lineCount==188,"dialogue still uses the user's approved 188-line edition")
	for section: Dictionary in baseline.sections:
		var source: String=section.source
		var parts:=source.split(".")
		var actual: Array=[]
		var route_ids: Array={"press":["fist"],"guard":["reflection"],"flow":["flow"],"balanced":[]}.get(parts[-1],[])
		if parts[0] in ["card","combination","turn"]:
			var table: Dictionary={"card":Dialogue.CARDS,"combination":Dialogue.COMBINATIONS,"turn":Dialogue.TURNS}[parts[0]]
			actual=table[parts[1]].map(func(row):return [str(row[0]),str(row[1])])
		elif source=="intro.first.common": actual=_text_rows(Story.lines("intro").slice(0,-1))
		elif source=="intro.repeat.common": actual=_text_rows(Story.lines("intro",{"runNumber":2}).slice(0,-1))
		elif source.begins_with("intro.contract."): actual=_text_rows([Story.lines("intro",{"contractId":parts[-1]})[-1]])
		elif parts[0]=="final_exchange": actual=_text_rows(Story._final_exchange(parts[1]))
		elif parts[0]=="victory": actual=_text_rows(Story.lines("victory",{"rewardIds":route_ids}))
		elif parts[0]=="defeat":
			if parts[-1]=="prefix": actual=_text_rows([Story.lines("defeat",{"stageIndex":5 if parts[1]=="boss" else 0})[0]])
			else:
				route_ids={"press":["fist"],"guard":["reflection"],"flow":["flow"],"balanced":[]}[parts[1]]
				actual=_text_rows(Story.lines("defeat",{"rewardIds":route_ids}).slice(1))
		elif source=="compatibility.final.prefix": actual=_text_rows(Story.lines("final").slice(0,2))
		elif parts[0]=="compatibility": actual=_text_rows(Story.lines(parts[1]))
		check(actual==_text_rows(section.lines),"user-approved dialogue is unchanged: "+str(section.id))
		approved_line_count+=section.lines.size()
	check(approved_line_count==188,"all approved dialogue lines were compared, not just the opening")

func _step(world,seconds: float) -> void:
	var elapsed:=0.0
	while elapsed<seconds-0.000001:
		var dt:=minf(1.0/60.0,seconds-elapsed)
		world._process(dt)
		elapsed+=dt
func _main_contract() -> void:
	root.size=Vector2i(1440,900)
	var world:=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	world.music._player.free()
	world.music.free()
	world.music=QuietMusic.new()
	root.add_child(world)
	world.effects.sounds.clear()
	world._process(0.0)
	check(world.ready_to_play,"the actual main initializes without a renderer window")
	for style: String in STYLE_IDS:
		world._action("select_style:"+style)
		world._process(0.0)
		check(world._roster_snapshot().styles.map(func(item):return str(item.id))==STYLE_IDS,"normal menu retains exactly all three armor choices: "+style)
		check(world.fighter.styleId==style and world.game.player_profile==style and world.player._profile.combatProfile==style,"menu selection keeps model and combat identity synchronized: "+style)
		world._action("start")
		check(world.story.active and _text_rows(world.story.lines)==_text_rows(Story.lines("intro",world.campaign.snapshot(world.game.snapshot()))),"selected armor retains approved story on ordinary start: "+style)
		check(world.story.actors.fuhua._profile.modelPath==world.fighter.actor.modelPath,"dialogue uses the selected armor's own native model: "+style)
		world._action("menu")
		world._action("practice")
		check(world.campaign.mode=="practice" and world.game.player_profile==style and not world.story.active,"normal practice keeps selected armor: "+style)
		world._action("restart")
		check(world.game.player_profile==style,"practice restart keeps selected armor: "+style)
		world._action("menu")
		world._action("trial")
		check(world.story.active and world.game.player_profile==style,"trial entry keeps selected armor: "+style)
		world._action("menu")
		await process_frame
	world._action("practice")
	world.game.set_training(true)
	world.game.player.x=-0.6
	world.game.enemy.x=0.7
	_step(world,0.15)
	world._action("ability")
	check(world.hud._notice.text.contains(str(Roster.STYLES.night_squire.abilityName)),"E notification follows Night Squire's own named skill")
	_step(world,1.8)
	world.game.player.energy=100.0
	var enemy_hp: float=world.game.enemy.hp
	world._action("ultimate")
	_step(world,0.6)
	check(str(world.cinematic_frame.shot).begins_with("night_") and world.hud._ultimate_tag.text=="ULTIMATE / NIGHT SQUIRE","actual Q selects Night Squire camera and HUD title")
	check(_no_ink(world.effects),"actual main Q event dispatch cannot introduce C5 ink")
	_step(world,1.05)
	check(world.game.player.nightBurstRemaining>7.8 and world.game.enemy.hp==enemy_hp and world.hud._stance_label.text.begins_with("爆发"),"actual Q returns to combat with timed burst and no activation damage")
	world.game.player.nightBurstRemaining=0.0
	world.game.player.nightFocus=2
	world._process(0.0)
	check(world.hud._stance_label.text=="烈波 2 / 3","white HUD shows the remaining follow-up charges after burst")
	world.free()
