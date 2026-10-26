extends SceneTree
## Independent C6 enemy model identity, adapted poses and event ownership.
## No player preferences, campaign records, GPU or browser state are touched.
const Actor = preload("res://scripts/actor.gd")
const Combat = preload("res://scripts/combat.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const PROFILE_PATH := "res://scripts/sentience_profile.gd"
const STEP := 1.0/120.0

class ErrorRecorder extends Logger:
	var errors: Array[Dictionary]=[]
	var warnings: Array[Dictionary]=[]
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		var entry: Dictionary={"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type}
		if error_type==Logger.ERROR_TYPE_WARNING:
			warnings.append(entry)
		else:
			errors.append(entry)
	func _log_message(_message: String,_error: bool) -> void: pass

var checks:=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var evidence: Dictionary={"poses":[],"playerIsolation":[],"events":[],"encounters":[],"main":[]}
var recorder:=ErrorRecorder.new()
var selection: Dictionary={}
var pose_keys: Array[String]=[]
var original_storage:=""
var storage_hashes: Dictionary={}

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		print("CHECK FAILED: ",label)

func _run() -> void:
	OS.add_logger(recorder)
	_check(ResourceLoader.exists(PROFILE_PATH),"the dedicated Sentience enemy profile is actually delivered")
	if ResourceLoader.exists(PROFILE_PATH):
		var profile=load(PROFILE_PATH)
		selection=profile.selection()
		_check(selection.has("actor"),"enemy selection supplies the existing actor configuration contract")
		if selection.has("actor"):
			for key: String in ["idle","move","guard","dodge","dodgeBack","stagger","dead","light1","light2","light3","heavy"]:
				if selection.actor.motions.has(key): pose_keys.append(key)
			_profile_contract()
			await _native_actors()
			_event_ownership()
			_campaign_identity()
			await _main_contract()
	_check(completed==["profile","actors","events","campaign","main"],"all planned independent sections reached completion")
	_check(pose_keys.size()>=6 and evidence.poses.size()==2*pose_keys.size() and evidence.playerIsolation.size()==3 and evidence.events.size()==12 and evidence.encounters.size()==6 and evidence.main.size()==3,"every expected model, event and encounter case completed")
	_check(recorder.errors.is_empty(),"no engine or script errors were hidden by a nested early exit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var report: Dictionary={"suite":"sentience_enemy","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors,"engineWarnings":recorder.warnings,"completed":completed,"evidence":evidence}
	FileAccess.open("res://build/reports/sentience-enemy-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	OS.remove_logger(recorder)
	print(JSON.stringify({"suite":"sentience_enemy","checks":checks,"passed":failures.is_empty(),"failures":failures,"engineErrors":recorder.errors.size(),"engineWarnings":recorder.warnings.size(),"completed":completed}))
	quit(0 if failures.is_empty() else 1)

func _profile_contract() -> void:
	var actor: Dictionary=selection.actor
	_check(actor.get("combatProfile","")=="sentience","enemy actor has its own combat identity")
	_check(ResourceLoader.exists(str(actor.get("modelPath",""))),"real enemy model resource exists")
	for current in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		_check(actor.modelPath!=Roster.resolve("fuhua",current[0],current[1]).actor.modelPath,"Sentience does not reuse a player model: "+str(current))
	for key: String in ["idle","move","stagger","dead","light1","heavy"]:
		_check(actor.motions.has(key) and not str(actor.motions.get(key,{}).get("clip","")).is_empty(),"enemy supplies a real motion mapping for "+key)
	for character: Dictionary in Roster.list_styles():
		_check(character.combatProfile!="sentience","enemy-only profile does not silently add an unimplemented playable selection")
	var clone: Dictionary=actor.duplicate(true)
	clone.motions.idle.clip="test_mutation"
	_check(selection.actor.motions.idle.clip!="test_mutation","enemy configuration supports isolated per-instance copies")
	completed.append("profile")

func _pose(actor) -> Array:
	var result: Array=[]
	for bone in actor.skeleton.get_bone_count(): result.append(actor.skeleton.get_bone_pose(bone))
	return result

func _finite_pose(actor) -> bool:
	for bone in actor.skeleton.get_bone_count():
		var transform: Transform3D=actor.skeleton.get_bone_global_pose(bone)
		if not transform.origin.is_finite() or not transform.basis.is_finite(): return false
	return true

func _changed_rotations(before: Array,after: Array) -> int:
	var changes:=0
	for bone in mini(before.size(),after.size()):
		if not before[bone].basis.is_equal_approx(after[bone].basis): changes+=1
	return changes

func _native_actors() -> void:
	var first=Actor.new()
	var second=Actor.new()
	root.add_child(first)
	root.add_child(second)
	first.setup(false,selection)
	second.setup(false,selection)
	_check(first.ready_for_combat and second.ready_for_combat,"two independently instantiated C6 enemies are ready")
	if not first.ready_for_combat or not second.ready_for_combat:
		first.free()
		second.free()
		return
	_check(first.model!=second.model and first.skeleton!=second.skeleton and first.animation_player!=second.animation_player,"enemy clones share neither nodes nor animation playback state")
	_check(first.skeleton.get_bone_count()>30,"enemy has a genuine articulated skeleton")
	_check(first.materials.size()>0 and first.materials.size()==second.materials.size(),"both enemies expose complete independent shader materials")
	for index in first.materials.size():
		_check(first.materials[index]!=second.materials[index],"material instance is independent at slot "+str(index))
		_check(float(first.materials[index].get_shader_parameter("ghost_amount"))==0.0,"native enemy colors survive normal actor creation at slot "+str(index))
		_check(first.materials[index].next_pass==null or first.materials[index].next_pass!=second.materials[index].next_pass,"outline instance is independent at slot "+str(index))
	var model_path: String=first.presentation_snapshot().get("modelPath","")
	_check(model_path==str(selection.actor.modelPath) and first.presentation_snapshot().get("combatProfile","")=="sentience","read-only enemy telemetry exposes the actual native source identity")
	var stationary: Dictionary={"side":"enemy","state":"idle","stateTime":0.1,"x":1.0,"facing":-1.0}
	first.animate_fighter(stationary,0.1,0.1)
	var untouched:=_pose(first)
	second.flash()
	second.set_enemy_style(Color(1.0,0.2,0.6),true)
	for facing in [-1.0,1.0]:
		for key: String in pose_keys:
			second.reset_presentation()
			var definition: Dictionary=selection.actor.motions[key]
			var clip_name: String=str(selection.actor.prefix)+str(definition.clip)
			_check(second.animation_player.has_animation(clip_name),key+": configured native animation is really loaded")
			var state: String="attack" if key in ["light1","light2","light3","heavy"] else "dodge" if key=="dodgeBack" else key
			var fighter: Dictionary={"side":"enemy","state":state,"stateTime":0.0,"stateDuration":1.0,"x":1.0,"facing":facing,"dodgeDirection":-facing if key=="dodgeBack" else facing}
			if state=="attack": fighter.attack={"name":"heavy" if key=="heavy" else "light","motion":key,"comboIndex":0,"duration":0.9,"windup":0.36,"active":0.12}
			second.animate_fighter(fighter,0.0,0.0)
			var initial:=_pose(second)
			fighter.stateTime=0.36 if state=="attack" else 0.24
			second.animate_fighter(fighter,fighter.stateTime,fighter.stateTime)
			var changed:=_changed_rotations(initial,_pose(second))
			_check(_finite_pose(second),key+": sampled native bone transforms stay finite facing "+str(facing))
			if key in ["move","dodge","dodgeBack","stagger","dead","light1","light2","light3","heavy"]:
				_check(changed>=3,key+": delivered bone animation actually moves several joints")
			if state=="attack": _check(is_equal_approx(second.source_time,float(definition.contact)),key+": native contact pose stays aligned to combat windup")
			var frozen:=_pose(second)
			var snapshot: Dictionary=second.presentation_snapshot()
			for tick in 8: second.animate_fighter(fighter,0.0,30.0+tick)
			_check(_pose(second)==frozen and second.presentation_snapshot()==snapshot,key+": zero-delta pause freezes source pose and overlays")
			_check(_pose(first)==untouched and first._flash_remaining==0.0,key+": animating/flashing another enemy cannot affect the first clone")
			evidence.poses.append({"key":key,"facing":facing,"clip":clip_name,"sourceTime":second.source_time,"changedRotations":changed})
	_check(float(second.presentation_snapshot().get("deathDuration",0.0))>=float(selection.actor.motions.dead.end)-0.05,"enemy death duration follows its native configured clip, not the old C5 cutoff")
	for chosen in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		var player=Actor.new()
		root.add_child(player)
		player.setup(false,Roster.resolve("fuhua",chosen[0],chosen[1]))
		_check(player.ready_for_combat and player._profile.modelPath!=first._profile.modelPath,"player choice and enemy model stay distinct: "+str(chosen))
		player.animate_fighter({"side":"player","state":"idle","stateTime":0.4,"x":-1.0,"facing":1.0},0.4,0.4)
		_check(_pose(first)==untouched and first._profile.combatProfile=="sentience","player animation/profile cannot mutate enemy: "+str(chosen))
		evidence.playerIsolation.append({"selection":chosen,"playerModel":player._profile.modelPath,"enemyModel":first._profile.modelPath})
		player.free()
	first.free()
	second.free()
	await process_frame
	completed.append("actors")

func _advance(game,seconds: float,guard: bool=false) -> void:
	var remaining:=seconds
	while remaining>0.000001:
		var delta:=minf(STEP,remaining)
		game.update(delta,0.0,guard)
		remaining-=delta

func _until(game,predicate: Callable,seconds: float=2.0,guard: bool=false) -> bool:
	for tick in ceili(seconds/STEP):
		if predicate.call(): return true
		game.update(STEP,0.0,guard)
	return bool(predicate.call())

func _combat(profile: String) -> Dictionary:
	var game=Combat.new()
	game.set_player_profile(profile)
	game.set_training(true)
	game.start()
	game.player.x=-0.6
	game.enemy.x=0.6
	var events: Array=[]
	game.event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	_check(game.enemy.get("style","")=="sentience" and game.enemy.get("characterId","")=="herrscher_of_sentience","combat enemy identity is independent of selected player "+profile)
	return {"game":game,"events":events}

func _kind(events: Array,kind: String) -> Array:
	return events.filter(func(event: Dictionary): return event.type==kind)

func _event_ownership() -> void:
	for profile: String in ["azure_empyrea","fenghuang"]:
		for scenario: String in ["enemy-hit","player-hit","block","parry","enemy-evade","player-evade"]:
			var fixture:=_combat(profile)
			var game=fixture.game
			var events: Array=fixture.events
			var expected_style:=profile
			var observed_kind:="hit"
			if scenario=="block":
				game.action("guard")
				_advance(game,0.2,true)
				game._attack(game.enemy,"light")
				expected_style="sentience"
				observed_kind="block"
			elif scenario in ["enemy-hit","parry","player-evade"]:
				game._attack(game.enemy,"light")
				expected_style="sentience" if scenario=="enemy-hit" else profile
				if scenario=="parry":
					_until(game,func(): return game.enemy.stateTime>=game.enemy.attack.windup-0.05)
					game.action("guard")
					observed_kind="parry"
				elif scenario=="player-evade":
					_until(game,func(): return game.enemy.stateTime>=game.enemy.attack.windup-0.025)
					game.action("dodge")
					observed_kind="evade"
			else:
				if scenario=="enemy-evade":
					game._state(game.enemy,"dodge",0.34)
					expected_style="sentience"
					observed_kind="evade"
				game.action("light")
			_check(_until(game,func(): return not _kind(events,observed_kind).is_empty(),2.0,scenario in ["block","parry"]),scenario+": real combat contact emits the expected event")
			var selected:=_kind(events,observed_kind)
			_check(not selected.is_empty() and selected[0].style==expected_style,scenario+": visual/audio style belongs to the acting source, including evade target ownership")
			if observed_kind=="hit":
				var expected_damage:=7.0 if scenario=="enemy-hit" else 6.0
				_check(not selected.is_empty() and selected[0].damage==expected_damage,scenario+": enemy art does not silently change existing damage balance")
				var frozen_time: float=game.time
				var frozen_hp: Array=[game.player.hp,game.enemy.hp]
				_advance(game,0.025)
				_check(game.time==frozen_time and [game.player.hp,game.enemy.hp]==frozen_hp,scenario+": contact hitstop freezes both timing and damage consumption")
			evidence.events.append({"playerProfile":profile,"scenario":scenario,"expectedStyle":expected_style,"events":selected})
	completed.append("events")

func _campaign_identity() -> void:
	var campaign=Campaign.new()
	for index in campaign.stages.size():
		var game=Combat.new()
		game.set_player_profile("fenghuang")
		game.start_encounter(campaign.stages[index])
		_check(game.enemies.size()==[1,2,2,3,2,1][index],"stage enemy counts remain unchanged at "+str(index))
		var ids: Dictionary={}
		for foe: Dictionary in game.enemies:
			_check(not ids.has(foe.id),"every projected enemy keeps a unique instance identity")
			ids[foe.id]=true
			_check(foe.get("style","")=="sentience" and foe.get("characterId","")=="herrscher_of_sentience","trial foe uses dedicated Sentience identity rather than player style")
			_check("识" in str(foe.name),"trial enemy label names the new opponent")
		_check(game.player_profile=="fenghuang" and game.player.style=="fenghuang","enemy encounter cannot overwrite the player's combat profile")
		if index==5: _check(game.enemy.boss and game.enemy.maxHp==260.0,"final Sentience retains boss mechanics and health balance")
		evidence.encounters.append({"stage":index,"enemies":game.enemies.duplicate(true),"playerStyle":game.player.style})
	completed.append("campaign")

func _isolate_storage() -> bool:
	original_storage=OS.get_user_data_dir()
	for filename: String in ["fighter-preferences.cfg","music-preferences.cfg","taixu_record.cfg"]:
		var path:=original_storage.path_join(filename)
		storage_hashes[filename]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","TaixuSentienceSuite/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	var isolated:=OS.get_user_data_dir()
	var safe:=isolated!=original_storage and "TaixuSentienceSuite" in isolated
	_check(safe,"real main test redirects every user setting and campaign record to a unique test directory")
	if safe: _check(DirAccess.make_dir_recursive_absolute(isolated)==OK,"isolated main-test storage is available")
	return safe

func _world_frames(world,seconds: float) -> void:
	var remaining:=seconds
	while remaining>0.000001:
		var delta:=minf(STEP,remaining)
		world._process(delta)
		remaining-=delta

func _main_contract() -> void:
	if not _isolate_storage(): return
	var Main=load("res://scripts/main.gd")
	_check(Main!=null and Main.can_instantiate(),"production Main can instantiate with the integrated enemy profile")
	if Main==null or not Main.can_instantiate(): return
	var world=Main.new()
	root.add_child(world)
	world.set_process(false)
	world.music.set_enabled(false,false)
	world._action("practice")
	world.game.set_training(true)
	_check(world.enemy_nodes.size()==1 and world.game.enemy.name=="识之律者","real practice flow creates and names the requested enemy")
	var enemy=world.enemy_nodes.get(str(world.game.enemy.id))
	_check(enemy!=null and enemy.ready_for_combat and enemy._profile.modelPath==selection.actor.modelPath,"real _sync_actors uses C6 enemy selection rather than default player roster")
	if enemy==null or not enemy.ready_for_combat:
		world.free()
		return
	_check(enemy._profile.modelPath!=world.player._profile.modelPath and enemy.skeleton!=world.player.skeleton,"production enemy and player share neither model identity nor mutable skeleton")
	evidence.main.append({"case":"practice","model":enemy._profile.modelPath,"name":world.game.enemy.name})

	world._action("menu")
	world.campaign.begin_trial()
	world.campaign.stage_index=3
	world._begin_encounter()
	world.stage_countdown=0.0
	world.game.set_training(true)
	_check(world.enemy_nodes.size()==3,"real three-enemy trial builds three C6 actors")
	var skeletons: Dictionary={}
	var materials: Dictionary={}
	for node in world.enemy_nodes.values():
		_check(node._profile.modelPath==selection.actor.modelPath and not skeletons.has(node.skeleton.get_instance_id()),"each real trial projection owns its C6 skeleton")
		skeletons[node.skeleton.get_instance_id()]=true
		for material in node.materials:
			_check(not materials.has(material.get_instance_id()),"real trial projections do not share writable shader material instances")
			materials[material.get_instance_id()]=true
	var foe: Dictionary=world.game.enemies[0]
	var fallen=world.enemy_nodes[str(foe.id)]
	_check(fallen.has_method("death_duration"),"enemy exposes the death-duration contract used by Main")
	if not fallen.has_method("death_duration"):
		world.free()
		return
	foe.hp=1.0 # Controlled lethal fixture; collision/damage balance is tested above.
	world.game._receive(world.game.player,foe,Combat.HEAVY.duplicate(true))
	world._process(0.0)
	var death_length: float=fallen.death_duration()
	var held_pose:=_pose(fallen)
	var held_clock: float=world.game.time
	_world_frames(world,0.025)
	_check(_pose(fallen)==held_pose and world.game.time==held_clock,"real death presentation stays frozen through lethal contact stop")
	_check(not world.game.ended and world.game.enemies.filter(func(other: Dictionary): return other.hp>0).size()==2,"one projection death cannot end a battle with living opponents")
	_world_frames(world,maxf(0.0,death_length-0.15))
	_check(fallen.visible and world.campaign.phase=="fight","partial defeat remains visible until its configured death animation finishes")
	_world_frames(world,0.35)
	_check(not fallen.visible and world.game.stats.kills==1,"completed projection death hides once without double-counting its kill")
	evidence.main.append({"case":"three-projections","instances":skeletons.size(),"deathDuration":death_length,"kills":world.game.stats.kills})

	world._action("menu")
	world._action("practice")
	world.game.set_training(true)
	enemy=world.enemy_nodes[str(world.game.enemy.id)]
	world.game.enemy.hp=1.0
	world.game._receive(world.game.player,world.game.enemy,Combat.HEAVY.duplicate(true))
	var final_length: float=enemy.death_duration()
	_check(world.game.ended and world.game.winner=="player","actual final damage establishes a single victory")
	_world_frames(world,maxf(0.0,final_length-0.20))
	_check(world.campaign.phase=="fight" and not world.victory.visible and enemy.visible,"final enemy death is not cut off by the old 1.15-second result delay")
	_world_frames(world,0.50)
	_check(world.campaign.phase=="cleared" and world.victory.visible,"completed final death advances into the player's existing victory presentation")
	var final_stats: Dictionary=world.game.stats.duplicate(true)
	_world_frames(world,0.30)
	_check(world.game.stats==final_stats and world.game.stats.kills==1,"presentation transition cannot commit final damage or kills again")
	evidence.main.append({"case":"final-victory","deathDuration":final_length,"endDelay":world.end_delay,"phase":world.campaign.phase,"stats":final_stats})
	world.queue_free()
	await process_frame
	await process_frame
	for filename: String in storage_hashes:
		var path:=original_storage.path_join(filename)
		var actual:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
		_check(actual==storage_hashes[filename],"user's original saved file is unchanged: "+filename)
	completed.append("main")
