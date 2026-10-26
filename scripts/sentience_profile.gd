extends RefCounted
## Enemy-only presentation. No player roster entry or fallback Fu Hua model.
## The asset owner writes this contract after validating the native C6 export.
const PRESENTATION_PATH := "res://assets/sentience/presentation.json"
const CHARACTER_ID := "herrscher_of_sentience"
const REQUIRED_MOTIONS := ["idle","intro","move","guard","dodge","dodgeBack","stagger","dead","light1","light2","light3","heavy","ability","ultimate"]

static func actor_config() -> Dictionary:
	if not FileAccess.file_exists(PRESENTATION_PATH): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PRESENTATION_PATH))
	if not data is Dictionary or int(data.get("schemaVersion",0))!=1 or not data.get("actor") is Dictionary:
		return {}
	var config:=decode_actor(data.actor)
	config.adaptationSource=config.get("adaptationSource",data.get("source",""))
	return config

static func selection() -> Dictionary:
	var config := actor_config()
	if not validation_errors(config).is_empty(): return {}
	return {"characterId":CHARACTER_ID,"styleId":"sentience","appearanceId":"default",
		"character":{"id":CHARACTER_ID,"name":"识之律者","playable":false},
		"style":{"id":"sentience","name":"识之律者","playable":false,"combatProfile":"sentience"},
		"appearance":{"id":"default","name":"原装","playable":false},"actor":config}

static func availability() -> Dictionary:
	var config := actor_config()
	var errors := validation_errors(config)
	return {"ready":errors.is_empty(),"errors":errors,"manifest":PRESENTATION_PATH,
		"modelPath":str(config.get("modelPath","")),"combatProfile":"sentience"}

static func decode_actor(raw: Dictionary) -> Dictionary:
	var config := raw.duplicate(true)
	config.combatProfile="sentience"
	config.attackPacing=config.get("attackPacing",{})
	config.defense=config.get("defense",{"source":"none"})
	config.victory=config.get("victory",{})
	var visual: Dictionary=config.get("visual",{}).duplicate(true)
	for key in ["hairShadowTint","bodyShadowTint"]:
		if visual.get(key) is Array and visual[key].size()==3:
			visual[key]=Vector3(float(visual[key][0]),float(visual[key][1]),float(visual[key][2]))
	var atlas: Dictionary=visual.get("faceAtlas",{}).duplicate(true)
	for key in ["scale","leftEyeOffset","otherOffset"]:
		if atlas.get(key) is Array and atlas[key].size()==2:
			atlas[key]=Vector2(float(atlas[key][0]),float(atlas[key][1]))
	visual.faceAtlas=atlas
	for slot in visual.get("surfaceUv",{}):
		for key in ["scale","offset"]:
			var value=visual.surfaceUv[slot].get(key)
			if value is Array and value.size()==2:
				visual.surfaceUv[slot][key]=Vector2(float(value[0]),float(value[1]))
	config.visual=visual
	for key in config.attackPacing:
		var anchors: Array=[]
		for value in config.attackPacing[key]:
			anchors.append(Vector2(float(value[0]),float(value[1])) if value is Array else value)
		config.attackPacing[key]=anchors
	return config

static func validation_errors(config: Dictionary, check_files: bool = true) -> Array[String]:
	var errors: Array[String]=[]
	if config.is_empty():
		errors.append("识之律者原始资源尚未就绪")
		return errors
	var model_path := str(config.get("modelPath",""))
	if not model_path.begins_with("res://assets/sentience/"):
		errors.append("识律模型必须使用独立的 sentience 资源")
	elif check_files and not ResourceLoader.exists(model_path):
		errors.append("模型不存在："+model_path)
	var library_path:=str(config.get("animationLibraryPath",""))
	if check_files and not library_path.is_empty() and not ResourceLoader.exists(library_path):
		errors.append("适配动作库不存在："+library_path)
	if str(config.get("prefix","")).is_empty(): errors.append("缺少原始动画前缀")
	var motions: Dictionary=config.get("motions",{})
	for key in REQUIRED_MOTIONS:
		var motion: Dictionary=motions.get(key,{})
		var start:=float(motion.get("start",0.0))
		var end:=float(motion.get("end",0.0))
		if str(motion.get("clip","")).is_empty() or not is_finite(start) or not is_finite(end) or start<0.0 or end<=start:
			errors.append("缺少有效原始动作："+key)
		if motion.has("contact") and (not is_finite(float(motion.contact)) or float(motion.contact)<=start or float(motion.contact)>end):
			errors.append("接触采样点超出动作区间："+key)
	var visual: Dictionary=config.get("visual",{})
	for key in ["rootBone","headBone"]:
		if str(visual.get(key,"")).is_empty(): errors.append("缺少骨骼标识："+key)
	if float(visual.get("height",0.0))<=0.0: errors.append("缺少角色显示高度")
	for key in ["hiddenMeshes","textures","outlinePixels"]:
		if not visual.has(key): errors.append("缺少呈现字段："+key)
	var textures: Dictionary=visual.get("textures",{})
	for key in textures:
		var path:=str(textures[key])
		if check_files and (path.is_empty() or not ResourceLoader.exists(path)):
			errors.append("贴图不存在："+str(key)+" "+path)
	for slot in visual.get("surfaceTextures",{}):
		for key in visual.surfaceTextures[slot]:
			var path:=str(visual.surfaceTextures[slot][key])
			if check_files and not path.is_empty() and not ResourceLoader.exists(path):
				errors.append("表面贴图不存在："+str(slot)+" "+path)
	var catalog:=str(visual.get("nativeMaterialCatalog",""))
	if check_files and not catalog.is_empty() and not FileAccess.file_exists(catalog): errors.append("原材质配置不存在："+catalog)
	if str(config.get("defense",{}).get("source","none")) not in ["none","native","local"]:
		errors.append("识律必须使用本身的防御姿势，不能沿用云墨重定向防御库")
	return errors
