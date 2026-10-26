extends SceneTree

const Roster = preload("res://scripts/fighter_roster.gd")
var checks := 0
var failures: Array[String] = []
var pending_styles: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var selected: Dictionary = Roster.resolve()
	_check(not selected.is_empty(), "the default playable selection resolves")
	_check(selected == Roster.resolve("fuhua", "azure_empyrea", "default"), "implicit defaults match the saved explicit identity")
	_check(Roster.list_characters().size() == 1 and Roster.list_styles().size() >= 1 and Roster.list_appearances().size() == 2, "Fu Hua has the two integrated Azure Empyrea appearances")
	if Roster.resolve("fuhua", "fenghuang").is_empty():
		pending_styles.append("fenghuang")
		if "--require-fenghuang" in OS.get_cmdline_user_args():
			_check(false, "requested Fenghuang style is not registered as playable yet")
	_check(Roster.resolve("unknown").is_empty(), "unknown characters never silently become Fu Hua")
	_check(Roster.resolve("fuhua", "phoenix").is_empty(), "an unimplemented Fu Hua armor is not playable")
	_check(Roster.resolve("fuhua", "azure_empyrea", "red_leaf").is_empty(), "a skin cannot be selected merely because a model may exist elsewhere")
	_check(Roster.list_styles("unknown").is_empty() and Roster.list_appearances("fuhua", "unknown").is_empty(), "invalid parents have no selectable children")
	_check(Roster.actor_config("unknown").is_empty() and Roster.presentation_identity("unknown").is_empty(), "invalid selections cannot leak a fallback actor or HUD identity")
	var identity: Dictionary = Roster.presentation_identity()
	_check(identity.characterName == "符华" and identity.styleName == "云墨丹心" and identity.skinName == "原装", "presentation labels distinguish person, moveset and skin")
	_check(selected.style.characterId == selected.character.id and selected.appearance.styleId == selected.style.id, "selected records retain their parent relationship")
	_check(selected.actor.combatProfile == selected.style.id, "the style names a combat profile without duplicating balance tables")
	_check(not selected.appearance.has("motions") and not selected.appearance.has("damage"), "cosmetic appearances cannot replace the style moveset or damage")

	# These are runtime consumer copies. A HUD sort, actor tweak or test fixture
	# must not alter the next actor or the canonical catalog through an alias.
	var config: Dictionary = Roster.actor_config()
	config.motions.light1.contact = 99.0
	config.visual.hiddenMeshes.append("body")
	selected.style.motions.light2.end = 99.0
	selected.appearance.visual.textures.faceColor = "missing.png"
	var menu: Array[Dictionary] = Roster.list_styles()
	menu[0].appearances.append("not_a_skin")
	var clean: Dictionary = Roster.resolve()
	_check(float(clean.actor.motions.light1.contact) < float(clean.actor.motions.light1.end), "actor motion edits cannot mutate the catalog")
	_check(not "body" in clean.actor.visual.hiddenMeshes and clean.actor.visual.textures.faceColor.begins_with("res://"), "nested visual settings are isolated between consumers")
	_check(float(clean.style.motions.light2.end) < 1.0 and clean.style.appearances.size() == 2, "resolved records and list records are independent deep copies")
	_check(clean.actor.modelPath == Roster.MODEL_PATH and clean.actor.textureDir == Roster.TEX_DIR and clean.actor.prefix == Roster.PREFIX, "legacy asset names resolve to the same current actor")
	_check(clean.actor.motions == Roster.MOTIONS and clean.actor.attackPacing == Roster.ATTACK_PACING, "legacy sampling dictionaries retain their exact shapes and values")

	var skin := Roster.resolve("fuhua", "azure_empyrea", "taixu_memory")
	_check(not skin.is_empty(), "the real C5_04_02 skin is registered")
	if not skin.is_empty():
		_check(skin.actor.modelPath != clean.actor.modelPath and skin.actor.textureDir != clean.actor.textureDir, "the skin uses separate original geometry and textures")
		_check(skin.actor.combatProfile == clean.actor.combatProfile and skin.actor.motions == clean.actor.motions and skin.actor.attackPacing == clean.actor.attackPacing, "appearance changes preserve combat and move sampling")
		_check(skin.actor.visual.faceAtlas.leftEyeOffset == Vector2(0.25, 0.75), "the new skin retains the corrected left-eye atlas offset")
	for style: Dictionary in Roster.list_styles():
		for appearance: Dictionary in Roster.list_appearances("fuhua", str(style.id)):
			var resolved := Roster.resolve("fuhua", str(style.id), str(appearance.id))
			_check(not resolved.is_empty() and resolved.actor.combatProfile == style.combatProfile, "playable appearance resolves within its own style: %s/%s" % [style.id, appearance.id])
			if not resolved.is_empty(): _validate_assets(resolved.actor)
	print(JSON.stringify({"suite": "fighter_roster", "checks": checks, "failures": failures, "passed": failures.is_empty(), "coverage": "all currently registered appearances", "pendingStyles": pending_styles, "requestedRosterComplete": pending_styles.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _validate_assets(config: Dictionary) -> void:
	_check(ResourceLoader.exists(config.modelPath), "selected model is a project resource")
	for role: String in config.visual.textures:
		_check(ResourceLoader.exists(str(config.visual.textures[role])), "texture role resolves: " + role)
	var packed := load(str(config.modelPath)) as PackedScene
	if packed == null:
		_check(false, "selected model loads as a scene")
		return
	var model := packed.instantiate()
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	_check(not players.is_empty() and not rigs.is_empty(), "selected model contains its animation player and rig")
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		for key: String in config.motions:
			var motion: Dictionary = config.motions[key]
			var clip_name: String = str(config.prefix) + str(motion.clip)
			var exists := player.has_animation(clip_name)
			_check(exists, "motion is backed by an imported clip: " + key)
			if exists:
				var clip := player.get_animation(clip_name)
				_check(float(motion.end) > 0.0 and float(motion.end) <= clip.length + 0.001, "motion cut stays inside the native clip: " + key)
				if key in ["light1", "light2", "light3", "heavy", "ability", "ultimate"] or key.begins_with("kick_") or key.begins_with("counter_") or key.begins_with("switch_"):
					_check(_moving_body_tracks(clip) >= 3, "attack animates the main body, not only hair or props: " + str(config.combatProfile) + "/" + key)
			if motion.has("contact"):
				_check(float(motion.contact) > 0.0 and float(motion.contact) < float(motion.end), "contact has startup and recovery: " + key)
	if not rigs.is_empty():
		var rig := rigs[0] as Skeleton3D
		_check(rig.find_bone(str(config.visual.rootBone)) >= 0 and rig.find_bone(str(config.visual.headBone)) >= 0, "the configured root and face-light anchor exist on this rig")
	_check(str(config.defense.targetRig) == str(config.rig), "retargeted defense is only associated with its intended rig")
	for key: String in config.attackPacing:
		var anchors: Array = config.attackPacing[key]
		var a: Vector2 = anchors[0]
		var b: Vector2 = anchors[1]
		_check(a.x > 0.0 and b.x > a.x and b.x < 1.0 and a.y > 0.0 and b.y > a.y and b.y < 1.0, "source pacing is ordered before contact: " + key)
	if not str(config.defense.get("libraryPath", "")).is_empty():
		var defense_fields := true
		for field: String in ["guardClip", "blockClip", "parryClip", "parryEnd"]:
			_check(config.defense.has(field), "defense sampling config declares %s: %s" % [field, config.combatProfile])
			defense_fields = defense_fields and config.defense.has(field)
		if defense_fields:
			_validate_library(config.defense, {"guardClip": 0.034, "blockClip": 0.23, "parryClip": float(config.defense.parryEnd)})
	var embedded := false
	var embedded_prefix := "presentation/"
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		embedded = player.has_animation("presentation/" + str(config.victory.clip)) and player.has_animation("presentation/" + str(config.victory.idleClip))
		if not embedded and str(config.victory.get("libraryPath", "")).is_empty():
			embedded_prefix = str(config.prefix)
			embedded = player.has_animation(embedded_prefix + str(config.victory.clip)) and player.has_animation(embedded_prefix + str(config.victory.idleClip))
	if embedded:
		var player := players[0] as AnimationPlayer
		_check(player.get_animation(embedded_prefix + str(config.victory.clip)).length >= float(config.victory.clipDuration) - 0.001, "embedded victory covers its source cut")
		_check(player.get_animation(embedded_prefix + str(config.victory.idleClip)).length >= float(config.victory.idleDuration) - 0.001, "embedded victory idle covers its source cut")
	else:
		_validate_library(config.victory, {"clip": float(config.victory.clipDuration), "idleClip": float(config.victory.idleDuration)})
	_check(config.victory.source == "native" and float(config.victory.presentationDuration) >= float(config.victory.clipDuration), "victory presentation can finish its native animation before the idle hold")
	model.free()
	_validate_material_bindings(config)

func _validate_material_bindings(config: Dictionary) -> void:
	var Actor = load("res://scripts/actor.gd")
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup(false, {"actor": config})
	_check(actor.ready_for_combat, "runtime actor initializes the registered appearance: " + str(config.modelPath))
	for node: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if not node.visible: continue
		var name := str(node.name).to_lower()
		for surface in node.mesh.get_surface_count():
			var slot := name + ":" + str(surface)
			var material := node.get_active_material(surface)
			if slot in config.visual.get("hiddenSurfaces", []):
				_check(material is BaseMaterial3D and material.albedo_color.a == 0.0, "the documented empty surface remains hidden: " + slot)
				continue
			_check(material is ShaderMaterial, "a visible surface has the character material: " + slot)
			if not material is ShaderMaterial: continue
			var texture = material.get_shader_parameter("albedo_texture")
			_check(texture is Texture2D and texture.get_width() > 0, "the visible surface has loaded color pixels: " + slot)
			if name in ["eye_l", "eye_r", "mouth"]:
				_check(int(material.get_shader_parameter("material_kind")) == 3, "facial detail uses the atlas material: " + slot)
				_check(material.get_shader_parameter("uv_scale") == config.visual.faceAtlas.scale and material.get_shader_parameter("uv_offset") == (config.visual.faceAtlas.leftEyeOffset if name == "eye_l" else config.visual.faceAtlas.otherOffset), "facial detail uses its explicit left/right UV offset: " + slot)
			if config.visual.get("surfaceKinds", {}).get(slot, "") == "body":
				_check(int(material.get_shader_parameter("material_kind")) == 0 and material.get_shader_parameter("lightmap_texture").resource_path == str(config.visual.textures.bodyLightmap), "body decorations attached to the hair mesh use the body lightmap: " + slot)
	actor.free()

func _moving_body_tracks(clip: Animation) -> int:
	var moving := 0
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D or clip.track_get_key_count(track) < 2:
			continue
		var name := str(clip.track_get_path(track))
		if not "Bip001" in name or not ("Spine" in name or "UpperArm" in name or "Forearm" in name or "Thigh" in name or "Calf" in name):
			continue
		var first: Quaternion = clip.track_get_key_value(track, 0)
		for key in range(1, clip.track_get_key_count(track)):
			var pose: Quaternion = clip.track_get_key_value(track, key)
			if first.angle_to(pose) > 0.035:
				moving += 1
				break
	return moving

func _validate_library(config: Dictionary, clips: Dictionary) -> void:
	var library_exists := ResourceLoader.exists(str(config.libraryPath))
	_check(library_exists, "motion library exists: " + str(config.libraryPath))
	if not library_exists:
		return
	var library := load(str(config.libraryPath)) as AnimationLibrary
	_check(library != null, "motion library has the correct resource type")
	if library == null:
		return
	for field: String in clips:
		var name: String = str(config[field])
		_check(library.has_animation(name), "auxiliary motion exists: " + name)
		if library.has_animation(name):
			_check(library.get_animation(name).length + 0.001 >= float(clips[field]), "auxiliary motion covers the selected time window: " + name)
