extends SceneTree
## Actual native C6 actor only. Headless checks by default; root may use -- --capture.
const Actor := preload("res://scripts/actor.gd")
const Profile := preload("res://scripts/sentience_profile.gd")
const Combat := preload("res://scripts/sentience_combat.gd")
const OUTPUT := "res://build/screenshots/sentience-native-pose"
var failures: Array[String]=[]
var records: Array=[]
var textures: Array[Texture2D]=[]
var actor
var label: Label
var capture := false

func _initialize() -> void:call_deferred("run")
func fail(message: String) -> void:
	failures.append(message);push_error(message)

func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for name in DirAccess.get_files_at("res://assets/sentience"):
		if name.ends_with(".png"):
			var path:="res://assets/sentience/"+name
			if not ResourceLoader.exists(path):
				var texture:=ImageTexture.create_from_image(Image.load_from_file(path))
				texture.take_over_path(path);textures.append(texture)
	var selection:=Profile.selection()
	if selection.is_empty() or str(selection.actor.get("animationLibraryName",""))!="native":
		fail("Native C6 profile is required; adapted C4 library cannot pass this probe")
		finish();return
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();stage.add_child(environment)
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.19,0.22,0.27)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(0.85,0.89,1)
	environment.environment.ambient_light_energy=0.65
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(18,12)
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color(0.3,0.34,0.38);floor_mat.roughness=1.0
	floor_mesh.material_override=floor_mat;stage.add_child(floor_mesh)
	var sun:=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-48,-24,0);sun.light_energy=0.8
	var camera:=Camera3D.new();stage.add_child(camera);camera.current=true;camera.position=Vector3(0,2.5,9.8);camera.fov=39;camera.look_at(Vector3(0,1.45,0))
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	label=Label.new();canvas.add_child(label);label.position=Vector2(20,18);label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color.WHITE);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
	actor=Actor.new();stage.add_child(actor);actor.setup(false,selection)
	if not actor.ready_for_combat:
		fail("Native C6 actor failed setup");finish();return
	for weapon: String in ["sword","spear","chain","burst"]:
		var count:=3 if weapon=="sword" else 1 if weapon=="burst" else 2
		for index in count:
			var attack:=Combat.attack(weapon,index,true,2)
			if not actor._motions.has(attack.motion):fail("Missing actual native motion "+str(attack.motion));continue
			for facing: float in [1.0,-1.0]:
				await sample_pose(weapon,index,facing,"contact",float(attack.windup),attack)
			# Contact both facings for all eight clips (16 frames), plus readable
			# startup and recovery for the first of each weapon (8 frames).
			if index==0:
				await sample_pose(weapon,index,1.0,"startup",float(attack.windup)*0.35,attack)
				await sample_pose(weapon,index,-1.0,"recovery",float(attack.duration)*0.90,attack)
	actor.reset_presentation()
	actor.animate_fighter({"story":true,"state":"idle","stateTime":0.5,"x":0,"facing":1},0,0.5)
	actor.apply_story_expression("playful",true,1.0)
	for group in actor._weapon_nodes:
		for node in actor._weapon_nodes[group]:
			if node.visible:fail("Story actor exposes weapon: "+str(node.name))
	stage.queue_free();canvas.queue_free()
	await process_frame
	finish()

func sample_pose(weapon: String,index: int,facing: float,phase: String,time: float,attack: Dictionary) -> void:
	actor.reset_presentation()
	var fighter:={"id":"probe","side":"enemy","style":"sentience","state":"attack","stateTime":0.0,"stateDuration":attack.duration,"x":0.0,"facing":facing,"attack":attack}
	var step:=1.0/60.0
	var elapsed:=0.0
	actor.animate_fighter(fighter,0,0)
	while elapsed<time-0.000001:
		var dt:=minf(step,time-elapsed);elapsed+=dt;fighter.stateTime=elapsed;actor.animate_fighter(fighter,dt,elapsed)
	var motion: Dictionary=actor._motions[attack.motion]
	var skin_positions: Dictionary={}
	for bone_name: String in ["Bip001","Bip001 Head","Bip001 R Hand","Bip001 L Hand","Bip001 R Foot","Bip001 L Foot","Fuka_C6_Weapon_A","Fuka_C6_Weapon_B","Fuka_C6_Weapon_C","Fuka_C6_Weapon_C_08"]:
		var index_bone:int=actor.skeleton.find_bone(bone_name)
		if index_bone<0:fail("Missing original bone "+bone_name);continue
		var point: Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(index_bone).origin
		if not point.is_finite():fail("Nonfinite bone "+bone_name)
		skin_positions[bone_name]=[point.x,point.y,point.z]
	var visible: Array=[]
	for group in actor._weapon_nodes:
		for node in actor._weapon_nodes[group]:
			if node.visible:visible.append(str(node.name))
	var should_draw: bool = weapon!="burst" and actor.source_time>=float(motion.get("weaponStart",0.0)) and actor.source_time<=float(motion.get("weaponEnd",motion.end))
	if should_draw and visible.is_empty():fail("Native weapon hidden inside action interval at "+str(attack.motion)+" "+phase)
	if not should_draw and not visible.is_empty():fail("Stowed or absent native weapon remains visible at "+str(attack.motion)+" "+phase)
	var file:="%s-%d-%s-%s"%[weapon,index+1,"right" if facing>0 else "left",phase]
	label.text="NATIVE C6  /  %s  /  %s\n%s  source %.3fs / %.3fs\ncombat %.3fs  facing %.0f  visible %s"%[weapon.to_upper(),phase,motion.clip,actor.source_time,float(motion.end),time,facing,str(visible)]
	if capture:
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/"+file+".png")
	records.append({"pose":file,"clip":motion.clip,"sourceTime":actor.source_time,"stateTime":time,"weapon":weapon,"visible":visible,"bones":skin_positions,"presentation":actor.presentation_snapshot()})

func finish() -> void:
	var report:={"passed":failures.is_empty(),"failures":failures,"capture":capture,"poses":records,"scope":"Actual native C6 actor, fixed camera and source-time/contact labels; GPU visual acceptance is manual."}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SENTIENCE NATIVE VISUAL ",records.size()," poses; failures ",failures.size(),"; capture ",capture)
	quit(0 if failures.is_empty() else 1)
