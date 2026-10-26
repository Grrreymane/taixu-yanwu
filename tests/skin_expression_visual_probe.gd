extends SceneTree
## No GPU work in headless mode. Add -- --capture for full-body/face PNGs.
## --atlas-only captures original eye pairs and mouth candidate cells with a
## fixed idle face camera; it never changes the production expression catalog.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Arena=preload("res://scripts/arena.gd")
const OUTPUT:="res://build/screenshots/skin-expression"
const STEP:=1.0/60.0
var stage: Node3D
var camera: Camera3D
var label: Label
var capture:=false
var captures:=0
var samples: Array[Dictionary]=[]
var gallery: Dictionary={}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	capture=DisplayServer.get_name()!="headless" and ("--capture" in args or "--atlas-only" in args)
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	stage=Node3D.new()
	root.add_child(stage)
	stage.add_child(Arena.new())
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	var canvas:=CanvasLayer.new()
	root.add_child(canvas)
	label=Label.new()
	label.position=Vector2(24,20)
	label.add_theme_font_override("font",load("res://assets/fonts/hi3-sdk-zh-cn.ttf"))
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color("10354c"))
	canvas.add_child(label)
	if "--atlas-only" in args:
		await _atlas_cases()
	else:
		var selections: Array=[["azure_empyrea","taixu_memory"]]
		if "--all" in args: selections=[["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]
		for ids: Array in selections: await _motion_cases(str(ids[0]),str(ids[1]))
	if capture: _save_grids()
	var output:=FileAccess.open(OUTPUT+("/atlas-report.json" if "--atlas-only" in args else "/motion-report.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"capture":capture,"captures":captures,"samples":samples},"  "))
	output.close()
	print(JSON.stringify({"probe":"skin_expression_visual","captures":captures,"samples":samples.size(),"headless":DisplayServer.get_name()=="headless"}))
	stage.free()
	canvas.free()
	await process_frame
	quit()

func _new_actor(style: String, skin: String):
	var actor=Actor.new()
	stage.add_child(actor)
	actor.setup(false,Roster.resolve("fuhua",style,skin))
	return actor

func _fighter(state: String, at: float, facing: float=1.0) -> Dictionary:
	return {"x":0.0,"facing":facing,"state":state,"stateTime":at,"stateDuration":0.4,"stance":"punch"}

func _point(actor, bone: String) -> Vector3:
	var index: int=actor.skeleton.find_bone(bone)
	return actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(index).origin

func _face_materials(actor) -> Dictionary:
	var result: Dictionary={}
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			if material is ShaderMaterial and int(material.get_shader_parameter("material_kind"))==3:
				var lower:=str(mesh.name).to_lower()
				result["eyeL" if "eye_l" in lower else "mouth" if "mouth" in lower else "eyeR"]=material
	return result

func _place_camera(actor, close: bool) -> void:
	if close:
		var head:=_point(actor,"Bip001 Head")
		var front: Vector3=actor.global_basis.orthonormalized()*Vector3(0.0,0.04,1.18)
		camera.position=head+front
		camera.fov=30.0
		camera.look_at(head+Vector3(0,-0.015,0))
	else:
		camera.position=Vector3(0.0,2.0,7.2)
		camera.fov=34.0
		camera.look_at(Vector3(0.0,1.45,0.0))

func _take(actor, name: String, group: String, close: bool, extra: Dictionary={}) -> void:
	_place_camera(actor,close)
	label.text=name
	var data: Dictionary={"name":name,"close":close,"presentation":actor.presentation_snapshot(),"head":_point(actor,"Bip001 Head"),"leftFoot":_point(actor,"Bip001 L Foot"),"rightFoot":_point(actor,"Bip001 R Foot")}
	data.merge(extra)
	samples.append(data)
	if not capture: return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png(OUTPUT+"/"+name+".png")
	image.resize(480,300,Image.INTERPOLATE_LANCZOS)
	if not gallery.has(group): gallery[group]=[]
	gallery[group].append(image)
	captures+=1

func _atlas_cases() -> void:
	var actor=_new_actor("azure_empyrea","taixu_memory")
	for frame in 36:
		var fighter:=_fighter("idle",float(frame+1)*STEP)
		fighter.presentationYaw=-0.20
		actor.animate_fighter(fighter,STEP,float(frame+1)*STEP)
	var materials:=_face_materials(actor)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/fuhua-face-atlas.json"))
	for frame_name: String in ["neutral","halfBlink","closed","focused"]:
		var frame: Dictionary=catalog.frames[frame_name]
		for part: String in ["eyeR","eyeL","mouth"]:
			materials[part].set_shader_parameter("uv_scale",Vector2(0.25,0.25))
			materials[part].set_shader_parameter("uv_offset",Vector2(frame[part][0],frame[part][1]))
		await _take(actor,"atlas-eyes-"+frame_name,"atlas",true,{"testFrame":frame})
	var candidates: Array[Vector2]=[Vector2(0.25,0.5),Vector2(0.5,0.5),Vector2(0.25,0.25),Vector2(0.75,0.0),Vector2(0.5,0.0)]
	for index in candidates.size():
		var frame: Dictionary=catalog.frames.neutral
		for part: String in ["eyeR","eyeL"]:
			materials[part].set_shader_parameter("uv_offset",Vector2(frame[part][0],frame[part][1]))
		materials.mouth.set_shader_parameter("uv_offset",candidates[index])
		await _take(actor,"atlas-mouth-%d-x%.2f-y%.2f" % [index,candidates[index].x,candidates[index].y],"atlas",true,{"mouthCandidate":candidates[index]})
	actor.free()

func _motion_cases(style: String, skin: String) -> void:
	var actor=_new_actor(style,skin)
	var cases: Array[Dictionary]=[
		{"name":"idle-050","state":"idle","end":0.5},
		{"name":"idle-220","state":"idle","end":2.2},
		{"name":"idle-226-closed","state":"idle","end":2.26},
		{"name":"idle-234-opening","state":"idle","end":2.34},
		{"name":"idle-320","state":"idle","end":3.2},
		{"name":"run-020","state":"move","end":0.2},
		{"name":"run-055","state":"move","end":0.55},
		{"name":"turn-012","state":"move","end":0.12,"turn":true},
		{"name":"turn-035","state":"move","end":0.35,"turn":true},
		{"name":"light-contact","state":"attack","end":0.18,"attack":"light"},
		{"name":"heavy-contact","state":"attack","end":0.5,"attack":"heavy"},
		{"name":"guard-hold","state":"guard","end":0.25},
		{"name":"victory-020","state":"victory","end":0.2},
		{"name":"victory-080","state":"victory","end":0.8},
		{"name":"victory-180","state":"victory","end":1.8},
		{"name":"victory-221-closed","state":"victory","end":2.21},
		{"name":"victory-420","state":"victory","end":4.2}]
	for item: Dictionary in cases:
		actor.reset_presentation()
		if bool(item.get("turn",false)):
			for frame in 24: actor.animate_fighter(_fighter("move",float(frame)*STEP),STEP,float(frame)*STEP)
		var count:=ceili(float(item.end)/STEP)
		for frame in count:
			var at:=minf(float(item.end),float(frame+1)*STEP)
			if item.state=="victory": actor.animate_victory(at)
			else:
				var fighter:=_fighter(str(item.state),at,-1.0 if bool(item.get("turn",false)) else 1.0)
				if item.has("attack"):
					fighter.attack={"name":item.attack,"comboIndex":0,"duration":0.88 if item.attack=="heavy" else 0.46,"windup":0.5 if item.attack=="heavy" else 0.16}
				actor.animate_fighter(fighter,STEP,at)
		var prefix:=style+"-"+skin+"-"+str(item.name)
		await _take(actor,prefix+"-body",style+"-"+skin+"-body",false)
		await _take(actor,prefix+"-face",style+"-"+skin+"-face",true)
	actor.free()

func _save_grids() -> void:
	for group: String in gallery:
		var images: Array=gallery[group]
		var sheet:=Image.create(1440,ceili(float(images.size())/3.0)*300,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("d9e5eb"))
		for index in images.size(): sheet.blit_rect(images[index],Rect2i(0,0,480,300),Vector2i((index%3)*480,(index/3)*300))
		sheet.save_png(OUTPUT+"/grid-"+group+".png")
