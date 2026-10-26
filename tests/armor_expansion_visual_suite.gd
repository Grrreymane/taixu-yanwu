extends SceneTree
## Headless native-resource and presentation integration. This does not certify
## final rasterized lighting: screenshots remain the separate GPU acceptance.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Combat=preload("res://scripts/combat.gd")
const Bounds=preload("res://scripts/model_bounds.gd")
const STYLE_IDS=["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
var phase:=""
class ErrorRecorder extends Logger:
	var errors:Array=[]
	var owner
	func _log_error(function:String,file:String,line:int,code:String,rationale:String,_notify:bool,error_type:int,_backtraces:Array[ScriptBacktrace])->void:
		if error_type!=Logger.ERROR_TYPE_WARNING:errors.append({"phase":owner.phase,"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var recorder:=ErrorRecorder.new()
func _initialize()->void:call_deferred("_run")
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _find(node:Node,type:String)->Node:
	if node.is_class(type):return node
	for child in node.get_children():
		var found=_find(child,type)
		if found:return found
	return null
func _source_player(raw:Node,clip:Animation)->AnimationPlayer:
	var existing:AnimationPlayer=_find(raw,"AnimationPlayer")
	if existing:existing.stop()
	var player=AnimationPlayer.new();raw.add_child(player)
	player.root_node=existing.root_node if existing else NodePath("..")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library=AnimationLibrary.new();library.add_animation("take",clip)
	player.add_animation_library("original",library);player.play("original/take",0.0)
	return player
func _body_difference(actual:Skeleton3D,expected:Skeleton3D,skip_root_position:bool=false)->Dictionary:
	var angle:=0.0;var distance:=0.0;var worst:=""
	for bone in actual.get_bone_count():
		var name:String=actual.get_bone_name(bone)
		if not name.begins_with("Bip001"):continue
		var other=expected.find_bone(name)
		if other<0:continue
		var a=actual.get_bone_pose(bone);var b=expected.get_bone_pose(other)
		var delta=a.basis.orthonormalized().get_rotation_quaternion().angle_to(b.basis.orthonormalized().get_rotation_quaternion())
		if delta>angle:angle=delta;worst=name
		if not(skip_root_position and name=="Bip001"):distance=maxf(distance,a.origin.distance_to(b.origin))
	return {"angle":angle,"distance":distance,"worst":worst}
func _native_dialogue(actor,choice:Dictionary,at:float)->Dictionary:
	var name:String=choice.actor.prefix+choice.actor.motions.idle.clip
	var raw=load(choice.actor.modelPath).instantiate();root.add_child(raw)
	var expected:Skeleton3D=_find(raw,"Skeleton3D")
	var player=_source_player(raw,actor.animation_player.get_animation(name))
	player.seek(at,true);player.advance(0.0)
	actor.animate_native_dialogue(name,float(choice.actor.motions.idle.end),at,0.0,0.0)
	var delta=_body_difference(actor.skeleton,expected)
	_check(delta.angle<.002 and delta.distance<.00005,choice.styleId+"/"+choice.appearanceId+" dialogue matches an independently sampled complete original body take: "+str(delta))
	raw.free();return delta
func _victory(actor,choice:Dictionary,at:float)->Dictionary:
	actor.reset_presentation();actor.animate_victory(at)
	var source_name:String=actor._victory_prefix+choice.actor.victory.clip
	_check(actor.animation_player.has_animation(source_name),choice.styleId+" native victory exists")
	var source:Animation=actor.animation_player.get_animation(source_name)
	var max_rotation:=0.0;var max_position:=0.0;var sampled:=0
	# Compare keyed local body channels directly to source curves; horizontal
	# root centering is the intended arena presentation adaptation.
	for track in source.get_track_count():
		var path=source.track_get_path(track)
		if path.get_subname_count()!=1:continue
		var name:String=path.get_subname(0)
		if not name.begins_with("Bip001"):continue
		var bone=actor.skeleton.find_bone(name)
		if bone<0:continue
		if source.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			var expected:Quaternion=source.rotation_track_interpolate(track,actor.source_time)
			# Imported keys carry small quaternion norm error. Compare orientation,
			# not the length drift discarded by Skeleton3D's rotation assignment.
			max_rotation=maxf(max_rotation,expected.normalized().angle_to(actor.skeleton.get_bone_pose_rotation(bone).normalized()));sampled+=1
		elif source.track_get_type(track)==Animation.TYPE_POSITION_3D and name!="Bip001":
			max_position=maxf(max_position,source.position_track_interpolate(track,actor.source_time).distance_to(actor.skeleton.get_bone_pose_position(bone)));sampled+=1
	_check(sampled>30 and max_rotation<.002 and max_position<.00005,choice.styleId+"/"+choice.appearanceId+" victory follows original keyed body curves")
	return {"rotation":max_rotation,"position":max_position,"channels":sampled}
func _materials_and_forms(actor,choice:Dictionary)->Dictionary:
	var alpha_slots:Array=[];var mesh_count:=0
	for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		mesh_count+=1
		for surface in mesh.mesh.get_surface_count():
			var slot=str(mesh.name).to_lower()+":"+str(surface)
			if slot in choice.actor.visual.get("hiddenSurfaces",[]):continue
			var mat=mesh.get_active_material(surface)
			_check(mat!=null,choice.styleId+"/"+choice.appearanceId+" has material "+slot)
			if mat is ShaderMaterial:
				_check(mat.get_shader_parameter("albedo_texture") is Texture2D,choice.styleId+" has real albedo for "+slot)
				if mat.shader.code.contains("ALPHA = base.a * native_opacity"):
					alpha_slots.append(slot)
					_check(mat.next_pass==null,"Fog alpha surfaces do not get opaque outline fills")
	if choice.styleId=="hawk_of_the_fog":
		alpha_slots.sort();_check(alpha_slots==["body:2","glass:1"],"Only the two original Fog alpha slots are translucent")
	if choice.styleId=="shadow_knight":
		for burst in [true,false]:
			actor.animate_fighter({"x":0.0,"facing":1.0,"state":"idle","stateTime":0.2,"eclipseRemaining":1.0 if burst else 0.0},0.0,0.2)
			for mode in choice.actor.visual.nativeFormMeshes:
				for name in choice.actor.visual.nativeFormMeshes[mode]:
					var node:MeshInstance3D=actor.model.find_child(name,true,false)
					_check(node!=null and node.visible==(burst if mode=="burst" else not burst),choice.appearanceId+" native "+mode+" renderer toggles: "+str(name))
	return {"meshes":mesh_count,"alphaSlots":alpha_slots}
func _contacts(actor,choice:Dictionary)->Array:
	var result:Array=[]
	for burst in ([false,true] if choice.styleId=="shadow_knight" else [false]):
		var game=Combat.new();game.set_player_profile(choice.styleId);game.start()
		game.player.eclipseRemaining=1.0 if burst else 0.0
		_check(game.action("ability"),choice.styleId+" E begins through Combat.action")
		var attack:Dictionary=game.player.attack
		var motion:String=attack.get("motion","ability")
		var contacts:Array=choice.actor.motions[motion].contacts
		_check(attack.hitWindows.size()==3 and contacts.size()==3,choice.styleId+" E has three source peaks for three hit windows")
		for index in contacts.size():
			actor.reset_presentation();game.player.stateTime=attack.hitWindows[index]
			actor.animate_fighter(game.player,0.0,float(game.player.stateTime))
			_check(absf(actor.source_time-float(contacts[index]))<.00001,choice.styleId+" "+motion+" hit "+str(index+1)+" samples its exact source contact")
			var source:Animation=actor.animation_player.get_animation(choice.actor.prefix+choice.actor.motions[motion].clip)
			var max_angle:=0.0
			for track in source.get_track_count():
				if source.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
				var path=source.track_get_path(track)
				if path.get_subname_count()!=1:continue
				var name:String=path.get_subname(0)
				if not name.begins_with("Bip001"):continue
				var bone=actor.skeleton.find_bone(name)
				if bone<0:continue
				max_angle=maxf(max_angle,source.rotation_track_interpolate(track,contacts[index]).normalized().angle_to(actor.skeleton.get_bone_pose_rotation(bone).normalized()))
			_check(max_angle<.002,choice.styleId+" "+motion+" contact retains source body rotations")
			result.append({"motion":motion,"gameTime":attack.hitWindows[index],"sourceTime":actor.source_time,"bodyAngleError":max_angle})
	return result
func _run()->void:
	recorder.owner=self;OS.add_logger(recorder)
	_check(Roster.list_styles().map(func(style):return style.id)==STYLE_IDS,"All five implemented armor identities remain selectable")
	for style in Roster.list_styles():
		for skin in Roster.list_appearances("fuhua",style.id):
			phase=style.id+"/"+skin.id+": initialize"
			var choice=Roster.resolve("fuhua",style.id,skin.id)
			var actor=Actor.new();root.add_child(actor);actor.setup(false,choice)
			_check(actor.ready_for_combat,style.id+"/"+skin.id+" initializes")
			if not actor.ready_for_combat:
				actor.free()
				continue
			var row={"style":style.id,"appearance":skin.id,"bones":actor.skeleton.get_bone_count()}
			var source=load(choice.actor.modelPath).instantiate();root.add_child(source)
			var source_skeleton:Skeleton3D=_find(source,"Skeleton3D")
			_check(source_skeleton.get_bone_count()==actor.skeleton.get_bone_count(),style.id+" retains own original rig bone count")
			for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
				if mesh.skin==null:continue
				var original:MeshInstance3D=source.find_child(mesh.name,true,false)
				_check(original!=null and original.skin!=null and original.skin.get_bind_count()==mesh.skin.get_bind_count(),style.id+" retains original skin "+str(mesh.name))
				var difference:=false
				for bind in mesh.skin.get_bind_count():
					difference=difference or not original.skin.get_bind_pose(bind).is_equal_approx(mesh.skin.get_bind_pose(bind))
				_check(not difference,style.id+"/"+skin.id+" bind matrices remain exact: "+str(mesh.name))
			for bone in actor.skeleton.get_bone_count():actor.skeleton.set_bone_pose(bone,source_skeleton.get_bone_pose(bone))
			var measured:Dictionary=Bounds.measure(actor.model,actor.skeleton,choice.actor.visual.get("hiddenSurfaces",[]))
			var bounds:AABB=measured.bounds
			row.neutralHeight=bounds.size.y*actor._pivot.scale.y
			row.neutralFloor=(actor._pivot.transform*Vector3(0.0,bounds.position.y,0.0)).y
			_check(absf(row.neutralHeight-2.85)<.01,style.id+"/"+skin.id+" actual skinned neutral height is2.85")
			_check(absf(row.neutralFloor)<.005,style.id+"/"+skin.id+" actual lowest neutral vertex meets the floor")
			phase=style.id+"/"+skin.id+": free source scene"
			source.free()
			phase=style.id+"/"+skin.id+": material and source-pose checks"
			row.materials=_materials_and_forms(actor,choice)
			row.dialogue=_native_dialogue(actor,choice,.65)
			row.victory=_victory(actor,choice,1.25)
			if style.id in ["shadow_knight","hawk_of_the_fog"]:row.contacts=_contacts(actor,choice)
			rows.append(row)
			phase=style.id+"/"+skin.id+": free actor"
			actor.free()
	_check(rows.size()==12,"All twelve actual armor appearances passed through presentation checks")
	await _legacy_selection_roundtrip()
	_check(recorder.errors.is_empty(),"No errors during actor initialization, native sampling, legacy selection or resource release")
	OS.remove_logger(recorder);recorder.owner=null
	var report={"suite":"armor_expansion_visual","checks":checks,"passed":failures.is_empty(),"failures":failures,"appearances":rows,"engineErrors":recorder.errors,"gpuUsed":false}
	FileAccess.open("res://build/reports/armor-expansion-visual.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"appearances":rows.size()}));quit(0 if failures.is_empty() else 1)

func _legacy_selection_roundtrip()->void:
	phase="isolated legacy preference roundtrip"
	var old_user_dir:=OS.get_user_data_dir()
	var original_file:=old_user_dir.path_join("fighter-preferences.cfg")
	var original_hash:=FileAccess.get_sha256(original_file) if FileAccess.file_exists(original_file) else "absent"
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","TaixuArmorExpansionSuite/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	var isolated:=OS.get_user_data_dir()
	_check(isolated!=old_user_dir and "TaixuArmorExpansionSuite" in isolated,"Preference test is isolated before instantiating Main")
	if isolated==old_user_dir:return
	_check(DirAccess.make_dir_recursive_absolute(isolated)==OK,"Isolated preference directory exists")
	var legacy:=ConfigFile.new()
	legacy.set_value("fighter","style","night_squire")
	legacy.set_value("fighter","appearance","autumn_leaves")
	legacy.set_value("fighter","appearances",{"night_squire":"autumn_leaves","azure_empyrea":"taixu_memory","fenghuang":"default"})
	_check(legacy.save("user://fighter-preferences.cfg")==OK,"Old-format skin preference is prepared")
	var Main=load("res://scripts/main.gd")
	var world=Main.new();root.add_child(world);world.set_process(false)
	_check(world.fighter.styleId=="night_squire" and world.fighter.appearanceId=="autumn_leaves" and world.player.ready_for_combat,"Existing red-leaf preference loads after full outfit expansion")
	world._action("select_appearance:xuanyi_sushang")
	_check(world.fighter.appearanceId=="xuanyi_sushang" and world.game.player_profile=="night_squire","New skin selects through the real menu action without changing moveset")
	world._action("select_style:azure_empyrea")
	_check(world.fighter.appearanceId=="taixu_memory","Switching to old remembered armor retains its saved skin")
	world._action("select_style:night_squire")
	_check(world.fighter.appearanceId=="xuanyi_sushang","Returning to white-night restores the new remembered skin")
	world._action("select_appearance:autumn_leaves")
	_check(world.fighter.appearanceId=="autumn_leaves" and world.player._profile.modelPath==Roster.resolve("fuhua","night_squire","autumn_leaves").actor.modelPath,"Switching back to the old saved appearance preserves its original model")
	await process_frame;await process_frame
	world.queue_free();await process_frame;await process_frame
	var reloaded=Main.new();root.add_child(reloaded);reloaded.set_process(false)
	_check(reloaded.fighter.styleId=="night_squire" and reloaded.fighter.appearanceId=="autumn_leaves","Real saved preference reloads the restored old appearance")
	reloaded.queue_free();await process_frame;await process_frame
	var after:=FileAccess.get_sha256(original_file) if FileAccess.file_exists(original_file) else "absent"
	_check(original_hash==after,"Actual user preference file is unchanged")
