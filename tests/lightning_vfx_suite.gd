extends SceneTree
const Effects := preload("res://scripts/effects.gd")
const FireSword := preload("res://assets/phoenix-fire-sword/roster.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _find(node: Node, type: String) -> Node:
	if node.is_class(type): return node
	for child in node.get_children():
		var result := _find(child,type)
		if result != null: return result
	return null
func _run() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	await process_frame
	for profile: String in ["shadow_knight","blood_moon","hawk_of_the_fog"]:
		var data := {"style":"shadow_knight" if profile=="blood_moon" else profile,"appearanceId":"blood_moon" if profile=="blood_moon" else "default","side":"player","sourceId":"player","x":1.0,"facing":1.0,"final":true}
		var fighter := data.duplicate()
		fighter.id="player"
		fighter.state="attack"
		fighter.stateTime=0.0
		fighter.attack={"name":"light","comboIndex":0,"windup":0.2}
		effects.update_fighters(fighter,[])
		for key: String in ["trail","lightning","impact","glow","smoke"]:
			check(effects.native_textures.has(profile+":"+key),profile+" loads native "+key)
		if profile in ["shadow_knight","blood_moon"]:
			# A mesh mask can load successfully yet draw a solid rectangle when
			# used on our lightning quad. Audit actual coverage, not just existence.
			var texture: Texture2D = effects.native_textures[profile+":lightning"]
			var image := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
			check(image != null and not image.is_empty(),profile+" source lightning image can be inspected")
			if image != null and not image.is_empty():
				var filled := 0
				var transparent := 0
				for y in image.get_height():
					for x in image.get_width():
						var alpha := image.get_pixel(x,y).a
						if alpha >= 0.94: filled += 1
						if alpha <= 0.06: transparent += 1
				var pixels := float(image.get_width()*image.get_height())
				check(float(filled)/pixels < 0.20,profile+" lightning has no broad opaque mesh-mask panel")
				check(float(transparent)/pixels > 0.50,profile+" lightning quad leaves the scene visible around its bolt")
		data.type="attack"; data.name="light"; data.windup=0.2
		effects.handle_event(data)
		check(effects._cues.size()==2,profile+" attack has one sound and one source sweep cue")
		fighter.stateTime=0.2
		effects.update_fighters(fighter,[]); effects.tick(0.001)
		check(effects.snapshot().lightningRoles.has("fist_trail"),profile+" authored strike emits native trail at contact")
		for kind in ["ability","hit","ultHit","parry","block","dodge","evade","ultimate","ultimateImpact","burstBegin","lightningDischarge","guardBreak","enemyDown"]:
			fighter.state="attack"
			effects.clear(); effects.update_fighters(fighter,[])
			data.type=kind
			effects.handle_event(data)
			check(effects.active.size()>0,profile+" "+kind+" has visible feedback")
			for item: Dictionary in effects.active:
				if str(item.mode)=="native":
					check(str(item.texture).begins_with(profile+":"),profile+" "+kind+" does not fall through to Azure ink")
			var before: Dictionary=effects.snapshot()
			effects.tick(0.0)
			check(is_equal_approx(float(effects.snapshot().nativeTime),float(before.nativeTime)),profile+" "+kind+" freezes during pause/hitstop")
			fighter.state="idle"; effects.update_fighters(fighter,[])
			effects.tick(4.0)
			check(effects.active.is_empty(),profile+" "+kind+" expires")
		effects.clear()
	var fog := {"style":"hawk_of_the_fog","id":"player","x":0.0,"fogCharges":1}
	effects.update_fighters(fog,[])
	check(effects.snapshot().lightningRoles.has("fog_charge"),"Fog charge gain lights a charge marker")
	var count := effects.active.size()
	effects.update_fighters(fog,[])
	check(effects.active.size()==count,"unchanged charge count does not spawn every frame")
	effects.handle_event({"type":"fogCharge","style":"hawk_of_the_fog","sourceId":"player","x":0.0,"charges":1})
	check(effects.active.size()==count,"Explicit Fog gain event does not duplicate the observed resource marker")
	effects.clear(); fog.fogCharges=0
	effects.update_fighters(fog,[])
	effects.handle_event({"type":"fogCharge","style":"hawk_of_the_fog","sourceId":"player","x":0.0,"charges":1})
	count=effects.active.size(); fog.fogCharges=1; effects.update_fighters(fog,[])
	check(effects.active.size()==count,"Combat gain event then update_fighters emits only one marker")
	effects.clear(); effects.update_fighters(fog,[])
	effects.handle_event({"type":"block","style":"sentience","sourceId":"enemy","targetId":"player","targetSide":"player","x":0.0})
	check(effects.snapshot().lightningRoles.has("guard"),"Real enemy-source block event uses defender's Fog guard")
	for item: Dictionary in effects.active:
		if str(item.mode)=="native": check(str(item.texture).begins_with("hawk_of_the_fog:"),"Real block never falls through to C5 curl")
	effects.clear()
	var sword_event := {"type":"ultimateImpact","style":"fenghuang","appearanceId":"fire_and_sword","x":0.0,"final":false}
	effects.handle_event(sword_event)
	check(effects.snapshot().nativeSwordCount==0,"Intermediate Phoenix hits do not spawn final sword field")
	sword_event.final=true; sword_event.appearanceId="default"
	effects.handle_event(sword_event)
	check(effects.snapshot().nativeSwordCount==0,"Default Phoenix does not borrow a skin-only effect")
	sword_event.appearanceId="fire_and_sword"
	effects.handle_event(sword_event)
	check(effects.snapshot().nativeSwordCount==12,"Original dress01 two bursts of six blades")
	check(effects.snapshot().fireRoles.has("original_sword_field"),"Sword field appears in fire role telemetry")
	var locations: Array[Vector3]=[]
	for item: Dictionary in effects.active:
		locations.append(item.node.position)
		check(item.node.mesh.get_surface_count()==1,"Blade keeps original single source surface")
		check(item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()==1494,"Blade keeps every original triangle")
	effects.tick(1.5)
	for i in effects.active.size():
		check(effects.active[i].node.position.is_equal_approx(locations[i]),"Source sword has no invented falling trajectory")
		check(is_equal_approx(float(effects.active[i].mat.get_shader_parameter("opacity")),0.5),"Source alpha fades across three-second lifetime")
	effects.tick(1.51)
	check(effects.active.is_empty(),"Source swords expire cleanly")
	var appearance: Dictionary=FireSword.APPEARANCE
	var model := (load(appearance.modelPath) as PackedScene).instantiate()
	root.add_child(model)
	var skeleton := _find(model,"Skeleton3D") as Skeleton3D
	var player := _find(model,"AnimationPlayer") as AnimationPlayer
	check(skeleton.get_bone_count()==99,"Fire and Sword preserves all 99 original skin bones")
	check(model.find_children("*","MeshInstance3D",true,false).size()==8,"Skin retains six original meshes and both original fists")
	check(player.get_animation_list().size()==25,"All 25 original Phoenix animation clips available")
	check(appearance.visual.hiddenSurfaces==["body:0"],"Only original CommonEmpty surface is hidden")
	check(appearance.visual.surfaceNativeRoles.get("body:2","")=="cloak","Separate native dual-face cloak material retained")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip_name in player.get_animation_list():
		player.play(clip_name)
		for phase in [0.0,0.25,0.5,0.75,1.0]:
			player.seek(player.get_animation(clip_name).length*phase,true); player.advance(0)
			var finite := true
			for bone in skeleton.get_bone_count():
				if not skeleton.get_bone_global_pose(bone).is_finite(): finite=false
			check(finite,clip_name+" source body pose finite at "+str(phase))
	model.queue_free(); effects.clear(); effects.queue_free()
	await process_frame
	var result := {"checks":checks,"failures":failures,"status":"passed" if failures.is_empty() else "failed"}
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	var file := FileAccess.open("res://build/reports/lightning-vfx-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("LIGHTNING_VFX "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
