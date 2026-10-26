extends SceneTree
const Actor := preload("res://scripts/actor.gd")
const Profile := preload("res://scripts/sentience_profile.gd")
const NativeMaterials := preload("res://scripts/native_materials.gd")
var checks:=0
var failures: Array[String]=[]
var textures: Array[Texture2D]=[]
var evidence: Array=[]

func _initialize() -> void:call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:failures.append(label);push_error(label)
func pose(a) -> Array:
	var result: Array=[]
	for i in a.skeleton.get_bone_count():result.append(a.skeleton.get_bone_pose(i))
	return result
func fighter(state: String, time: float, facing: float) -> Dictionary:
	return {"state":state,"stateTime":time,"stateDuration":0.44,"facing":facing,"x":1.2,"side":"enemy"}
func sample(a, key: String, time: float, facing: float, delta: float = 0.0) -> Dictionary:
	var f:=fighter(key,time,facing)
	if key in ["light1","light2","light3","heavy","ability"]:
		f.state="attack"
		f.attack={"name":"heavy" if key=="heavy" else "ability" if key=="ability" else "light","motion":key,"comboIndex":0,"windup":0.30,"duration":0.70}
	a.animate_fighter(f,delta,time)
	return f
func point(a,name: String) -> Vector3:
	return a.skeleton.get_bone_global_pose(a.skeleton.find_bone(name)).origin

func run() -> void:
	# Read actual newly extracted PNGs before the main thread's unified import.
	for file in DirAccess.get_files_at("res://assets/sentience"):
		if file.ends_with(".png"):
			var path:="res://assets/sentience/"+file
			var texture:=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
			texture.take_over_path(path);textures.append(texture)
	check(not Profile.validation_errors({}).is_empty(),"missing extraction cannot fall back silently to player Azure")
	var selection:=Profile.selection()
	check(not selection.is_empty(),"real C6 assets and native action library are available: "+str(Profile.availability()))
	if selection.is_empty():finish();return
	var a:=Actor.new();root.add_child(a);a.setup(false,selection)
	check(a.ready_for_combat,"actual C6 actor setup succeeds")
	if not a.ready_for_combat:finish();return
	check(a.skeleton.get_bone_count()==193,"real 193-bone C6 skeleton is used")
	check(a.presentation_snapshot().combatProfile=="sentience","enemy uses its independent profile")
	check(a.presentation_snapshot().modelPath=="res://assets/sentience/Avatar_Fuka_C6_FL.scn","enemy cannot inherit player skin")
	check(not a.presentation_snapshot().adaptationSource.is_empty(),"adapted motion provenance is explicit")
	check(not a._facial.snapshot().get("enabled",false),"C6 NewFace does not run the incompatible C5 atlas controller")
	check(is_equal_approx(a.death_duration(),float(a._motions.dead.end)) and is_equal_approx(a.death_duration(),3.0),"death timing exposes complete original C6 Die")
	check(a.animation_player.has_animation("native/Attack_A_01") and not a.animation_player.has_animation("adapted/Guard_H"),"native C6 library replaces C4 body and Lighter defensive fallback")
	var original_player:=NativeMaterials.profile("azure_default","body").duplicate(true)
	var new_material:=NativeMaterials.profile("sentience","body",str(selection.actor.visual.nativeMaterialCatalog))
	check(not new_material.is_empty(),"independent C6 material catalog loads")
	check(NativeMaterials.profile("azure_default","body")==original_player,"C6 catalog does not overwrite player material cache")
	check(NativeMaterials.profile("sentience","body").is_empty(),"enemy material cannot leak through default player catalog")
	var visible_count:=0
	for mesh in a.model.find_children("*","MeshInstance3D",true,false):
		var name:=str(mesh.name).to_lower()
		if "weapon" in name:check(not mesh.visible,"unretargeted weapon is hidden: "+name)
		if mesh.visible:visible_count+=1
	check(visible_count>=4,"recognizable body, hair and NewFace meshes remain visible")
	a.set_enemy_style(Color(0.7,0.1,0.8),true)
	for material in a.materials:
		check(is_zero_approx(float(material.get_shader_parameter("ghost_amount"))),"enemy identification preserves original texture colors")
		var color=material.get_shader_parameter("albedo_texture")
		check(color is Texture2D and str(color.resource_path).begins_with("res://assets/sentience/"),"every visible surface binds a C6 texture")
	for facing: float in [-1.0,1.0]:
		for key in ["idle","move","guard","dodge","dodgeBack","stagger","light1","light2","light3","heavy","ability","dead"]:
			a.reset_presentation()
			sample(a,key,0.0,facing)
			var initial:=point(a,"Bip001 R Hand")
			var distance:=0.0
			var length_error:=0.0
			var invalid:=0
			var previous:=0.0
			for fraction in [0.1,0.25,0.5,0.75,1.0]:
				var at:float=(a.death_duration() if key=="dead" else 0.7 if key in ["light1","light2","light3","heavy","ability"] else 0.44)*float(fraction)
				var f:=sample(a,key,at,facing,at-previous)
				previous=at
				distance=maxf(distance,point(a,"Bip001 R Hand").distance_to(initial))
				for i in a.skeleton.get_bone_count():
					if not a.skeleton.get_bone_global_pose(i).is_finite():invalid+=1
					if i!=a._root_bone and str(a.skeleton.get_bone_name(i)).begins_with("Bip001"):length_error=maxf(length_error,absf(a.skeleton.get_bone_pose_position(i).length()-a.skeleton.get_bone_rest(i).origin.length()))
				var frozen:=pose(a)
				var status:Dictionary=a.presentation_snapshot()
				for pause_frame in 15:a.animate_fighter(f,0.0,200.0+pause_frame)
				check(frozen==pose(a) and status==a.presentation_snapshot(),key+" freezes all model pose and reaction clocks")
			check(invalid==0,key+" has finite transforms on all 193 bones")
			check(length_error<0.00001,key+" preserves target C6 bone lengths")
			if key in ["move","stagger","light1","light2","light3","heavy","ability","dead"]:
				check(distance>0.02,key+" main body is animated, not merely hair/accessories")
			if key in ["light1","light2","light3","heavy","ability"]:
				sample(a,key,0.30,facing)
				check(is_equal_approx(a.source_time,float(a._motions[key].contact)),key+" contact aligns with selected original source time")
			evidence.append({"motion":key,"facing":facing,"rightHandRange":distance,"boneLengthError":length_error,"invalidTransforms":invalid})
		a.reset_presentation();sample(a,"guard",0.10,facing,0.10)
		var floor_before:=minf(point(a,"Bip001 L Foot").y,point(a,"Bip001 R Foot").y)
		for kind in ["block","parry"]:
			a.react_impact(kind,-facing,true)
			sample(a,"guard",0.10,facing)
			check(a.presentation_snapshot().defenseClip.is_empty(),"native C6 "+kind+" cannot load removed C4/Lighter defense fallback")
			check(absf(minf(point(a,"Bip001 L Foot").y,point(a,"Bip001 R Foot").y)-floor_before)<0.0001,"local "+kind+" preserves support foot height")
	a.free()
	finish()

func finish() -> void:
	var report:={"suite":"sentience_presentation","checks":checks,"failures":failures,"passed":failures.is_empty(),"evidence":evidence,"scope":"Actual C6 mesh/materials and original C6 body/weapon motion restored from native muscle/IK data. Headless geometry/clock checks; visual acceptance is separate."}
	FileAccess.open("res://build/reports/sentience-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SENTIENCE PRESENTATION ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
