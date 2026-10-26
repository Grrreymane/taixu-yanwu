extends SceneTree
## Repeatable native-material comparison, not a scene or gameplay fixture.
## GPU: -- --capture --label=before (then the identical command with after).
## Headless: validates all shots and records metadata without waiting for draw.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const OUTPUT:="res://build/screenshots/native-material-comparison"
const STEP:=1.0/60.0
const POSE_FRAMES:=30
const SIDE_YAW:=PI/2.0-0.23
const EXPECTED_SAMPLES:=30
const SHOTS: Array[Dictionary]=[
	{"id":"body-front","close":false,"yaw":0.0,"facing":1.0},
	{"id":"body-right","close":false,"yaw":SIDE_YAW,"facing":1.0},
	{"id":"body-left","close":false,"yaw":-SIDE_YAW,"facing":-1.0},
	{"id":"body-front-mirrored-light","close":false,"yaw":0.0,"facing":-1.0},
	{"id":"face-front","close":true,"yaw":0.0,"facing":1.0},
	{"id":"face-quarter-right","close":true,"yaw":0.55,"facing":1.0},
	{"id":"face-quarter-left","close":true,"yaw":-0.55,"facing":-1.0},
	{"id":"face-side-right","close":true,"yaw":SIDE_YAW,"facing":1.0},
	{"id":"face-side-left","close":true,"yaw":-SIDE_YAW,"facing":-1.0},
	{"id":"face-front-mirrored-light","close":true,"yaw":0.0,"facing":-1.0}
]
var stage: Node3D
var camera: Camera3D
var caption: Label
var capture:=false
var label:="current"
var samples: Array[Dictionary]=[]
var material_profiles: Dictionary={}
var galleries: Dictionary={}
var failures: Array[String]=[]
var completed_appearances: Array[String]=[]
var captured_samples: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	capture="--capture" in args and DisplayServer.get_name()!="headless"
	for argument: String in args:
		if argument.begins_with("--label="):
			var requested:=argument.trim_prefix("--label=")
			label=""
			for character in requested:
				if character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_": label+=character
			if label.is_empty(): label="current"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"/"+label))
	root.size=Vector2i(1280,800)
	_build_stage()
	for ids: Array in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
		await _appearance(str(ids[0]),str(ids[1]))
	# A runtime error in a nested GDScript method need not terminate its caller.
	# Missing shots or an unfinished appearance must therefore fail this probe.
	if samples.size()!=EXPECTED_SAMPLES: failures.append("incomplete samples: expected 30, received "+str(samples.size()))
	if completed_appearances.size()!=3: failures.append("incomplete appearances: expected 3, received "+str(completed_appearances.size()))
	if material_profiles.size()!=3: failures.append("incomplete material profiles: expected 3, received "+str(material_profiles.size()))
	for identity: String in ["azure_empyrea-default","azure_empyrea-taixu_memory","fenghuang-default"]:
		if completed_appearances.count(identity)!=1: failures.append(identity+" did not complete exactly once")
		for shot: Dictionary in SHOTS:
			var expected:=identity+"-"+str(shot.id)
			var count:=0
			for sample: Dictionary in samples:
				if sample.id==expected: count+=1
			if count!=1: failures.append(expected+" must be sampled exactly once")
			if capture and captured_samples.count(expected)!=1: failures.append(expected+" was not saved exactly once")
	if capture: _save_grids()
	var report: Dictionary={"probe":"native_visual","label":label,"capture":capture,"passed":failures.is_empty(),"failures":failures,
		"contract":{"viewport":[1280,800],"pose":"native idle","frames":POSE_FRAMES,"step":STEP,"background":"a9b0ba","tonemap":"linear","cameraFollowsHead":false},
		"completion":{"appearances":completed_appearances,"expectedSamples":EXPECTED_SAMPLES,"savedCaptures":captured_samples.size()},
		"materials":material_profiles,"samples":samples}
	var file:=FileAccess.open(OUTPUT+"/"+label+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify({"probe":"native_visual","label":label,"shots":samples.size(),"captures":captured_samples.size(),"appearances":completed_appearances.size(),"passed":failures.is_empty(),"failures":failures}))
	stage.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _build_stage() -> void:
	stage=Node3D.new()
	root.add_child(stage)
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("a9b0ba")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color.WHITE
	environment.ambient_light_energy=0.35
	environment.ambient_light_sky_contribution=0.0
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled=false
	var world:=WorldEnvironment.new()
	world.environment=environment
	stage.add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48.0,-32.0,0.0)
	sun.light_color=Color.WHITE
	sun.light_energy=0.70
	sun.shadow_enabled=false
	stage.add_child(sun)
	camera=Camera3D.new()
	camera.current=true
	stage.add_child(camera)
	var canvas:=CanvasLayer.new()
	stage.add_child(canvas)
	caption=Label.new()
	caption.position=Vector2(22,18)
	caption.add_theme_font_size_override("font_size",19)
	caption.add_theme_color_override("font_color",Color("172732"))
	canvas.add_child(caption)

func _appearance(style: String, skin: String) -> void:
	var actor=Actor.new()
	stage.add_child(actor)
	actor.setup(false,Roster.resolve("fuhua",style,skin))
	var identity:=style+"-"+skin
	if not actor.ready_for_combat:
		failures.append(identity+" failed to load")
		actor.free()
		return
	for shot: Dictionary in SHOTS:
		actor.reset_presentation()
		for frame in POSE_FRAMES:
			var clock:=float(frame+1)*STEP
			actor.animate_fighter({"x":0.0,"state":"idle","stateTime":clock,"facing":shot.facing,"presentationYaw":shot.yaw},STEP,clock)
		if bool(shot.close):
			camera.position=Vector3(0.0,2.42,1.75)
			camera.fov=30.0
			camera.look_at(Vector3(0.0,2.42,0.0))
		else:
			camera.position=Vector3(0.0,1.48,7.4)
			camera.fov=34.0
			camera.look_at(Vector3(0.0,1.45,0.0))
		var name:=identity+"-"+str(shot.id)
		caption.text=name # Same caption across labels keeps image comparisons clean.
		var poses: Array[Transform3D]=[]
		var finite:=true
		for index in actor.skeleton.get_bone_count():
			var pose: Transform3D=actor.skeleton.get_bone_pose(index)
			poses.append(pose)
			finite=finite and pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite()
		if not finite: failures.append(name+" has non-finite bones")
		var head: Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Bip001 Head")).origin
		var head_pixel:=camera.unproject_position(head)
		samples.append({"id":name,"cameraPosition":_value(camera.position),"cameraRotation":_value(camera.rotation),"fov":camera.fov,
			"actorYaw":actor.rotation.y,"facing":shot.facing,"head":_value(head),"headPixel":_value(head_pixel),"poseHash":hash(poses),"finite":finite,
			"motion":actor.current_motion,"sourceTime":actor.source_time,"presentation":actor.presentation_snapshot()})
		if not material_profiles.has(identity): material_profiles[identity]=_materials(actor)
		if capture:
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image:=root.get_texture().get_image()
			var save_error:=image.save_png(OUTPUT+"/"+label+"/"+name+".png")
			if save_error==OK: captured_samples.append(name)
			else: failures.append(name+" PNG save failed: "+str(save_error))
			image.resize(480,300,Image.INTERPOLATE_LANCZOS)
			var group:=identity+("-face" if bool(shot.close) else "-body")
			if not galleries.has(group): galleries[group]=[]
			galleries[group].append(image)
	actor.free()
	await process_frame
	completed_appearances.append(identity)

func _value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector4 or value is Quaternion: return [value.x,value.y,value.z,value.w]
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Resource: return value.resource_path
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(_value(item))
		return result
	return value

func _materials(actor) -> Dictionary:
	var result: Dictionary={}
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible: continue
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			if not material is ShaderMaterial: continue
			var values: Dictionary={}
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				values[str(uniform.name)]=_value(material.get_shader_parameter(str(uniform.name)))
			if material.next_pass is ShaderMaterial:
				values.outline={"pixels":_value(material.next_pass.get_shader_parameter("outline_pixels")),"color":_value(material.next_pass.get_shader_parameter("outline_color"))}
			result[str(mesh.name)+":"+str(surface)]=values
	return result

func _save_grids() -> void:
	for group: String in galleries:
		var images: Array=galleries[group]
		var sheet:=Image.create(1440,ceili(float(images.size())/3.0)*300,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("a9b0ba"))
		for index in images.size(): sheet.blit_rect(images[index],Rect2i(0,0,480,300),Vector2i((index%3)*480,(index/3)*300))
		sheet.save_png(OUTPUT+"/"+label+"/grid-"+group+".png")
