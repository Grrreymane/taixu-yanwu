extends SceneTree
const Roster := preload("res://scripts/fighter_roster.gd")
const Materials := preload("res://scripts/native_materials.gd")
const Character := preload("res://shaders/character.gdshader")
const Outline := preload("res://shaders/outline.gdshader")
var checks := 0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _run() -> void:
	var alpha_samples: Dictionary={}
	for id in ["spring_traveler","xuanyi_sushang","black_butler"]:
		var selection: Dictionary=Roster.resolve("fuhua","night_squire",id)
		var visual: Dictionary=selection.actor.visual
		var path: String=visual.nativeMaterialCatalog
		var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)).profiles[visual.nativeMaterialProfile]
		var raw: Array=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir()+"/original-materials.json")).materials
		for role in profiles:
			if role=="weapon": continue
			var profile: Dictionary=profiles[role]
			var source: Dictionary={}
			for row: Dictionary in raw:
				if str(row.pathId)==str(profile.source.pathId) and str(row.serializedFile)==str(profile.source.cab): source=row
			check(not source.is_empty(),id+" "+role+" exact source material identity")
			if source.is_empty():continue
			check(bool(profile.useAlphaClip)==bool(source.floats.get("_UseAlphaClip",0)),id+" "+role+" native alpha mode retained")
			check(is_equal_approx(float(profile.alphaClipThreshold),float(source.floats.get("_AlphaClipThreshold",.1))),id+" "+role+" native clip threshold retained")
			check(bool(profile.backFaceUseUv2)==bool(source.floats.get("_BackFaceUseUV2",0)),id+" "+role+" native backface UV selection")
			for texture_path: String in profile.textures.values():check(ResourceLoader.exists(texture_path),id+" "+role+" original texture loads")
			var body := ShaderMaterial.new(); body.shader=Character
			var outline := ShaderMaterial.new(); outline.shader=Outline
			Materials.apply(body,outline,visual.nativeMaterialProfile,role,false,path)
			check(body.shader==Character,id+" "+role+" has no unrelated .473 transparent shader")
			check(bool(body.get_shader_parameter("use_alpha_clip"))==bool(profile.useAlphaClip),id+" "+role+" runtime body alpha selection")
			check(bool(outline.get_shader_parameter("use_alpha_clip"))==bool(profile.useAlphaClip),id+" "+role+" runtime outline alpha selection")
			if bool(profile.useAlphaClip):
				check(is_equal_approx(float(body.get_shader_parameter("alpha_clip_threshold")),.1),"Xuanyi body source threshold .1")
				check(is_equal_approx(float(outline.get_shader_parameter("alpha_clip_threshold")),.1),"Xuanyi outline matches .1 source threshold")
		check(ResourceLoader.exists(selection.appearance.portraitPath),id+" correct original portrait loads")
		if id=="xuanyi_sushang":
			check(visual.surfaceNativeRoles.get("body:3","")=="cutout","Xuanyi cutout has separate role")
			check(visual.surfaceNativeRoles.get("body:2","")=="dualface","Xuanyi dual face remains separate")
			check(visual.hiddenSurfaces==["body:1","body:4"],"Xuanyi only native invisible slots hidden")
			var model: Node=(load(selection.actor.modelPath) as PackedScene).instantiate()
			var mesh := model.find_child("Body",true,false) as MeshInstance3D
			var image := Image.load_from_file(ProjectSettings.globalize_path(profiles.body.textures.albedo))
			for surface in [0,2,3]:
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var values: Array[float]=[]
				for i in range(0,indices.size(),3):
					var point: Vector2=(uv[indices[i]]+uv[indices[i+1]]+uv[indices[i+2]])/3.0
					values.append(image.get_pixel(clampi(roundi(point.x*(image.get_width()-1)),0,image.get_width()-1),clampi(roundi(point.y*(image.get_height()-1)),0,image.get_height()-1)).a)
				values.sort()
				alpha_samples[str(surface)]={"triangles":values.size(),"min":values.front(),"median":values[values.size()/2],"max":values.back(),"belowThreshold":values.filter(func(a:float)->bool:return a<.1).size()}
			model.free()
		elif id=="black_butler":check(visual.surfaceKinds.get("hair:1","")=="body","Black Butler extra hair mesh surface uses its original body material")
	var report := {"checks":checks,"failures":failures,"xuanyiBodyTriangleAlphaSamples":alpha_samples,"pass":failures.is_empty()}
	var file := FileAccess.open("res://build/reports/night-squire-skin-material-suite.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("NIGHT_SQUIRE_SKIN_MATERIALS "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
