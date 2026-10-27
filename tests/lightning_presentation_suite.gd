extends SceneTree
const Camera = preload("res://scripts/lightning_camera.gd")
const Battle = preload("res://scripts/battle_camera.gd")
const Combat = preload("res://scripts/lightning_combat.gd")
const Guide = preload("res://scripts/fighter_guide.gd")
const HUD = preload("res://scripts/hud.gd")
const Shadow = preload("res://assets/shadow-knight/roster.gd")
const Fog = preload("res://assets/hawk-of-the-fog/roster.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value: failures.append(detail)
func _project(frame: Dictionary, point: Vector3, aspect: float) -> Vector2:
	var eye := Transform3D(Basis.IDENTITY,frame.position).looking_at(frame.target)
	var local: Vector3 = eye.affine_inverse()*point
	var half_height := -local.z*tan(deg_to_rad(float(frame.fov)*.5))
	return Vector2(local.x/(half_height*aspect),local.y/half_height)
func _run() -> void:
	for profile in Combat.PROFILES:
		var duration := Combat.ultimate_duration(profile)
		var impact := float(Combat.ultimate_cues(profile)[0])
		_check(Camera.return_at(profile)>impact and Camera.return_at(profile)<duration,profile+" camera returns after real impact")
		for aspect: float in [16.0/9.0,1.6,.75]:
			for facing: float in [-1.0,1.0]:
				for x: float in [-5.0,0.0,5.0]:
					var battle: Dictionary = Battle.frame(x,[x+facing*1.3],aspect)
					var entry: Dictionary = battle.duplicate(true)
					entry.position += Vector3(.1,.05,.1)
					var focus := {"playerX":x,"targetX":x+facing*1.3,"facing":facing,"aspect":aspect,"entry":entry,"battle":battle}
					var start := Camera.sample(0.0,focus,profile)
					var end := Camera.sample(duration,focus,profile)
					_check(start.position==entry.position and start.target==entry.target and start.fov==entry.fov,profile+" exact entry")
					_check(end.position.is_equal_approx(battle.position) and end.target.is_equal_approx(battle.target) and is_equal_approx(end.fov,battle.fov),profile+" exact end")
					for frame_index in 49:
						var t := duration*frame_index/48.0
						var shot := Camera.sample(t,focus,profile)
						_check(shot.position.is_finite() and shot.target.is_finite() and is_finite(shot.fov) and is_finite(shot.roll),profile+" finite camera")
						_check(shot.position.z>=3.5 and shot.fov>=31.0 and shot.fov<=40.0,profile+" controlled viewing side and lens")
						_check(shot==Camera.sample(t,focus,profile),profile+" pause deterministic")
						var points: Array=[Vector3(x,2.85,0),Vector3(x,.05,0),Vector3(x+facing*1.3,1.4,0)]
						if shot.get("composition","full")=="portrait": points=[Vector3(x,2.85,0),Vector3(x,1.45,0)]
						for point in points:
							var projected := _project(shot,point,aspect)
							_check(absf(projected.x)<.98 and absf(projected.y)<.98,profile+" player and contact stay framed")
					for boundary in [0.07,0.10,0.20,0.30,0.94,impact+.18,impact+.28,Camera.return_at(profile),duration]:
						var before := Camera.sample(boundary-.00001,focus,profile)
						var after := Camera.sample(boundary+.00001,focus,profile)
						_check(before.position.distance_to(after.position)<.003 and absf(before.fov-after.fov)<.003,profile+" continuous shot boundary")
					for boundary in Camera.cuts(profile):
						var before:=Camera.sample(boundary-.00001,focus,profile)
						var after:=Camera.sample(boundary+.00001,focus,profile)
						_check(before.position.distance_to(after.position)>.4 and after.composition=="full",profile+" deliberate native-action cut has a distinct readable angle")
		var guide := Guide.for_style(profile)
		var config: Dictionary = Shadow.STYLE if profile=="shadow_knight" else Fog.STYLE
		_check(guide.styleId==profile and guide.name==config.name,profile+" independent player guide")
		_check(is_equal_approx(guide.cooldown,Combat.cooldown(profile)),profile+" guide actual cooldown")
		_check(guide.moves.map(func(move): return move.key)==["J","K","L","SPACE","E","Q"],profile+" all controls explained")
		_check(guide.moves[4].title==config.abilityName and guide.moves[5].title==config.ultimateName,profile+" move titles match roster")
	var hud := HUD.new()
	hud.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(hud)
	hud.set_ready(true)
	var state := {"started":false,"paused":false,"ended":false,"ko":{"active":false},"player":{"hp":120.0,"energy":100.0},"enemy":{},"enemies":[],"campaign":{"phase":"menu","mode":"trial"},"victory":{}}
	for profile in Combat.PROFILES:
		var config: Dictionary = Shadow.STYLE if profile=="shadow_knight" else Fog.STYLE
		state.fighter={"styleId":profile,"styleName":config.name,"skinName":"原装","abilityName":config.abilityName,"ultimateName":config.ultimateName}
		for value in [0.0,1.0,3.0,10.0]:
			state.player.eclipseRemaining=value if profile=="shadow_knight" else 0.0
			state.player.fogCharges=mini(int(value),3) if profile=="hawk_of_the_fog" else 0
			hud.update_status(state)
			_check(hud._stance_label.visible,profile+" mechanic status visible")
			var font: Font = hud._stance_label.get_theme_font("font")
			var size: int = hud._stance_label.get_theme_font_size("font_size")
			var width := font.get_string_size(hud._stance_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			_check(width<=hud._stance_label.size.x,profile+" status text fits without clipping")
			_check(hud._skills.ability.title.text==config.abilityName,profile+" ability button identity")
		hud.open_fighter_guide()
		await process_frame
		_check(hud._guide_data.styleId==profile,profile+" actual HUD opens own guide")
		hud.close_fighter_guide()
	state.fighter={"styleId":"azure_empyrea","styleName":"云墨丹心"}
	hud.update_status(state)
	_check(not hud._stance_label.visible and hud._stance_label.tooltip_text.is_empty(),"return to Azure clears lightning state label")
	hud.queue_free()
	await process_frame
	var report := {"checks":checks,"failures":failures,"gpuUsed":false}
	FileAccess.open("res://build/reports/lightning-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
