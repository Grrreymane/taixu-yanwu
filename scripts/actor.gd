extends Node3D

const FighterRoster := preload("res://scripts/fighter_roster.gd")
const MODEL_PATH := FighterRoster.MODEL_PATH
const TEX_DIR := FighterRoster.TEX_DIR
const PREFIX := FighterRoster.PREFIX
const CHARACTER_SHADER := preload("res://shaders/character.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const DefenseMotion := preload("res://scripts/defense_motion.gd")
const SecondaryMotion := preload("res://scripts/secondary_motion.gd")
const FacialMotion := preload("res://scripts/facial_motion.gd")
const NativeMaterials := preload("res://scripts/native_materials.gd")
const ModelBounds := preload("res://scripts/model_bounds.gd")
const MOTIONS: Dictionary = FighterRoster.MOTIONS
# Combat time stays continuous. These source-time anchors give the longer
# player attacks a readable preparation, a held anticipation, then a release.
# Values are (combat fraction, source fraction) before the existing contact.
const ATTACK_PACING: Dictionary = FighterRoster.ATTACK_PACING

var model: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var materials: Array[ShaderMaterial] = []
var is_ghost := false
var current_motion := ""
var source_time := 0.0
var ready_for_combat := false
var _pivot: Node3D
var _root_bone := -1
var _head_bone := -1
var _root_origin := Vector3.ZERO
var _head_initial_basis := Basis.IDENTITY
var _last_clock := 0.0
var _transition_time := 0.0
var _transition_length := 0.0
var _previous_pose: Array[Transform3D] = []
var _source_base_pose: Array[Transform3D] = []
var _imported_base_pose: Array[Transform3D] = []
var _normalization: Dictionary = {}
var _native_dialogue_clip := ""
var _native_dialogue_player: AnimationPlayer
var _transition_from := ""
var _transition_floor := 0.0
var _feet: Array[int] = []
var _flash_remaining := 0.0
var _pivot_origin := Vector3.ZERO
var _guard_weight := 0.0
var _arms: Array[Dictionary] = []
var _impact_kind := ""
var _impact_age := 0.0
var _impact_duration := 0.0
var _impact_strength := 0.0
var _impact_direction := 1.0
var _recoil := 0.0
var _impact_bones: Array[Dictionary] = []
var _impact_neck := -1
var _impact_pose_base: Dictionary = {}
var _impact_body_angle := 0.0
var _defense = DefenseMotion.new()
var _defense_clock := 0.0
var _defense_clip := ""
var _defense_time := 0.0
var _defense_phase := "none"
var _defense_weight := 0.0
var _impact_strong := false
var _profile: Dictionary = FighterRoster.actor_config()
var _motions: Dictionary = MOTIONS
var _prefix: String = PREFIX
var _pacing: Dictionary = ATTACK_PACING
var _visual: Dictionary = {}
var _victory: Dictionary = {}
var _victory_available := false
var _victory_prefix := "presentation/"
var _native_guard := false
var _defense_source := "lighter_retargeted"
var _native_defense_floor := 0.0
var _stance := "punch"
var _native_bone_tracks: Dictionary = {}
var _secondary = SecondaryMotion.new()
var _secondary_enabled := false
var _victory_last_time := -1.0
var _victory_props: Array[MeshInstance3D] = []
var _victory_idle_base_pose: Array[Transform3D] = []
var _facial = FacialMotion.new()
var _weapon_nodes: Dictionary = {}
var _weapon_kind := ""
var _form_nodes: Dictionary = {"normal": [], "burst": []}
var _eclipse_form := false
static var _alpha_shader: Shader
var _story_active := false
var _story_shapes: Array[Dictionary] = []
var _chain_bones: Array[int] = []
var _chain_anchor := -1
var _chain_extent_scale := 1.0

func setup(ghost: bool = false, selection: Dictionary = {}) -> void:
	if ready_for_combat:
		return
	if not selection.is_empty():
		if not selection.has("actor"):
			push_error("角色配置缺少可用的模型与动作")
			return
		_profile = selection.actor.duplicate(true)
	_motions = _profile.motions
	_prefix = str(_profile.prefix)
	_pacing = _profile.attackPacing
	_visual = _profile.visual
	_victory = _profile.get("victory", {})
	_defense_source = str(_profile.get("defense", {}).get("source", "lighter_retargeted"))
	_native_guard = _defense_source in ["native","local"]
	is_ghost = ghost
	_pivot = Node3D.new()
	_pivot.name = "ModelPivot"
	add_child(_pivot)
	var packed := load(str(_profile.modelPath)) as PackedScene
	if packed == null:
		push_error("角色模型未能导入：" + str(_profile.modelPath))
		return
	model = packed.instantiate() as Node3D
	_pivot.add_child(model)
	_configure_nodes(model)
	_facial.setup(str(_visual.get("facialAnimation", "")))
	if animation_player == null or skeleton == null:
		push_error("角色模型缺少 AnimationPlayer 或 Skeleton3D")
		return
	# Preserve the untouched scene pose, before combat sampling or any solver.
	# Full native presentation clips use this for channels the take omits.
	for bone in skeleton.get_bone_count():
		_imported_base_pose.append(skeleton.get_bone_pose(bone))
	var combat_library_path := str(_profile.get("animationLibraryPath", ""))
	if not combat_library_path.is_empty():
		var combat_library := load(combat_library_path) as AnimationLibrary
		if combat_library == null:
			push_error("角色动作库未能加载："+combat_library_path)
			return
		animation_player.add_animation_library(str(_profile.get("animationLibraryName","adapted")),combat_library)
	if not animation_player.has_animation(_prefix + str(_motions.idle.clip)):
		push_error("角色模型缺少配置的待机动作："+_prefix+str(_motions.idle.clip))
		return
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_player.play(_prefix + str(_motions.idle.clip))
	animation_player.seek(0.0, true)
	animation_player.advance(0.0)
	_root_bone = skeleton.find_bone(str(_visual.rootBone))
	_head_bone = skeleton.find_bone(str(_visual.headBone))
	if float(_visual.get("chainWorldReachLimit",0.0))>0.0:
		_chain_anchor=skeleton.find_bone("Fuka_C6_Weapon_C")
		for segment in range(1,9):
			var chain_bone:=skeleton.find_bone("Fuka_C6_Weapon_C_%02d"%segment)
			if chain_bone>=0: _chain_bones.append(chain_bone)
	if _root_bone >= 0:
		_root_origin = skeleton.get_bone_pose_position(_root_bone)
	if _head_bone >= 0:
		_head_initial_basis = skeleton.get_bone_global_pose(_head_bone).basis.orthonormalized()
	for entry in [["Bip001 Spine",0.34],["Bip001 Spine1",0.40],["Bip001 Spine2",0.26]]:
		var bone := skeleton.find_bone(str(entry[0]))
		if bone >= 0: _impact_bones.append({"bone":bone,"weight":float(entry[1])})
	_impact_neck = skeleton.find_bone("Bip001 Neck")
	for side in ["L", "R"]:
		var foot := skeleton.find_bone("Bip001 "+side+" Foot")
		if foot >= 0: _feet.append(foot)
	_native_defense_floor = _foot_floor()
	_normalize_model()
	_pivot_origin = _pivot.position
	if str(_visual.get("secondaryMotion", "")) == "taixu_memory":
		_secondary_enabled = _secondary.setup(skeleton,model.find_child("Body",true,false) as MeshInstance3D)
	for side in ["L", "R"]:
		_arms.append({"upper": skeleton.find_bone("Bip001 " + side + " UpperArm"),
			"fore": skeleton.find_bone("Bip001 " + side + " Forearm"),
			"hand": skeleton.find_bone("Bip001 " + side + " Hand"), "side": side})
	if _defense_source == "lighter_retargeted": _defense.setup(skeleton,str(_profile.defense.get("libraryPath","")),bool(_profile.defense.get("fullGrounding",false)))
	var victory_path := str(_victory.get("libraryPath", ""))
	var victory_clip := str(_victory.get("clip", ""))
	var victory_idle := str(_victory.get("idleClip", ""))
	if not victory_clip.is_empty() and not victory_idle.is_empty() and animation_player.has_animation("presentation/"+victory_clip) and animation_player.has_animation("presentation/"+victory_idle):
		_victory_available = true
	elif not victory_path.is_empty() and ResourceLoader.exists(victory_path):
		var library := load(victory_path) as AnimationLibrary
		if library != null and library.has_animation(str(_victory.clip)) and library.has_animation(str(_victory.idleClip)):
			animation_player.add_animation_library("presentation", library)
			_victory_available = true
	elif not victory_clip.is_empty() and not victory_idle.is_empty() and animation_player.has_animation(_prefix+victory_clip) and animation_player.has_animation(_prefix+victory_idle):
		_victory_prefix = _prefix
		_victory_available = true
	ready_for_combat = true
	for i in skeleton.get_bone_count():
		_source_base_pose.append(skeleton.get_bone_pose(i))
	current_motion = "idle"
	_update_face_vectors()

func _configure_nodes(node: Node) -> void:
	if node is AnimationPlayer:
		animation_player = node
	if node is Skeleton3D:
		skeleton = node
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var lower_name := str(node.name).to_lower()
		var hidden_meshes: Array = []
		for entry in _visual.get("hiddenMeshes", []): hidden_meshes.append(str(entry).to_lower())
		var form_mesh := false
		for form in _visual.get("nativeFormMeshes", {}):
			for entry in _visual.nativeFormMeshes[form]:
				if lower_name == str(entry).to_lower():
					_form_nodes[form].append(mesh_node)
					form_mesh = true
					mesh_node.visible = form == "normal"
		var victory_prop := lower_name == "umbrella_s" and str(_profile.get("combatProfile", "")) == "azure_empyrea"
		if victory_prop: _victory_props.append(mesh_node)
		var weapon_meshes: Dictionary = _visual.get("weaponMeshes", {})
		var dynamic_weapon := false
		for weapon in weapon_meshes:
			if lower_name in weapon_meshes[weapon]:
				dynamic_weapon = true
				if not _weapon_nodes.has(weapon): _weapon_nodes[weapon] = []
				_weapon_nodes[weapon].append(mesh_node)
		if lower_name in hidden_meshes or dynamic_weapon:
			mesh_node.visible = false
		if lower_name not in hidden_meshes or dynamic_weapon or victory_prop or form_mesh:
			mesh_node.extra_cull_margin = 4.0
			# Restore native backface UV seams lost by the FBX importer. Only the
			# mesh changes: the original Skin, skeleton path and transform stay.
			if str(node.name).to_lower()=="body" and _visual.has("nativeBodyMesh"):
				var native_body := load(str(_visual.nativeBodyMesh)) as ArrayMesh
				if native_body!=null: mesh_node.mesh=native_body
				else: push_error("角色原版 UV2 网格未能加载："+str(_visual.nativeBodyMesh))
			for surface_index in mesh_node.mesh.get_surface_count():
				mesh_node.set_surface_override_material(surface_index, _make_material(mesh_node, surface_index))
		if str(_visual.get("expressionMode", "")) == "native_blendshapes" and lower_name in ["face", "eyebrow", "eyeshape"]:
			for index in mesh_node.mesh.get_blend_shape_count():
				_story_shapes.append({"mesh":mesh_node,"index":index,"name":str(mesh_node.mesh.get_blend_shape_name(index)),"base":mesh_node.get_blend_shape_value(index)})
	for child in node.get_children():
		_configure_nodes(child)

func _make_material(mesh_node: MeshInstance3D, surface_index: int) -> Material:
	var original := mesh_node.get_active_material(surface_index) as BaseMaterial3D
	var node_name := str(mesh_node.name).to_lower()
	var slot_key := node_name+":"+str(surface_index)
	if slot_key in _visual.get("hiddenSurfaces",[]):
		var hidden := StandardMaterial3D.new()
		hidden.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		hidden.albedo_color=Color(0,0,0,0)
		return hidden
	var slot_kind := str(_visual.get("surfaceKinds",{}).get(slot_key,""))
	var alpha_slot := str(_visual.get("surfaceNativeRoles",{}).get(slot_key,"")) == "alpha"
	var mat := ShaderMaterial.new()
	mat.shader = CHARACTER_SHADER
	if alpha_slot:
		# The original C1_05_01 Alpha material uses partial transparency on
		# exactly two surfaces. Keep the other body surfaces opaque.
		if _alpha_shader == null:
			_alpha_shader = Shader.new()
			_alpha_shader.code = CHARACTER_SHADER.code.replace("uniform float flash_amount", "uniform float native_opacity = 0.473;\nuniform float flash_amount").replace("ALBEDO = mix(color, vec3(0.93, 0.98, 1.0), paper_flash);", "ALBEDO = mix(color, vec3(0.93, 0.98, 1.0), paper_flash);\n ALPHA = base.a * native_opacity;")
		mat.shader = _alpha_shader
	mat.resource_local_to_scene = true
	var texture: Texture2D = original.albedo_texture if original != null else null
	if texture==null and _visual.textures.has("bodyColor"):
		texture=load(str(_visual.textures.bodyColor))
	if texture != null:
		mat.set_shader_parameter("albedo_texture", texture)
	if original != null:
		mat.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
		mat.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
	var kind := 0
	var outline_pixels := float(_visual.outlinePixels.body)
	if slot_kind=="hair" or (slot_kind.is_empty() and "hair" in node_name):
		kind = 1
		outline_pixels = float(_visual.outlinePixels.hair)
		_apply_material_texture(mat,"lightmap_texture",str(_visual.textures.get("hairLightmap","")),"has_lightmap")
		mat.set_shader_parameter("shadow_tint", _visual.get("hairShadowTint",Vector3.ONE))
	elif slot_kind=="face" or (slot_kind.is_empty() and "face" in node_name):
		kind = 2
		outline_pixels = float(_visual.outlinePixels.face)
		_apply_material_texture(mat,"albedo_texture",str(_visual.textures.get("faceColor","")))
		_apply_material_texture(mat,"face_mask_texture",str(_visual.textures.get("faceMask","")),"has_face_mask")
	elif slot_kind=="face_part" or (slot_kind.is_empty() and ("eye" in node_name or "mouth" in node_name)):
		kind = 3
		outline_pixels = 0.0
		# Native material evidence: FBX retains tiling but loses the left-eye offset.
		# Unity's bottom-origin atlas ST becomes y = 1 - scale.y - offset.y
		# after the FBX/Godot UV flip. Its default open eyes are the PNG's bottom row.
		if str(_visual.get("faceMode","atlas")) == "atlas":
			mat.set_shader_parameter("uv_scale", _visual.faceAtlas.scale)
			mat.set_shader_parameter("uv_offset", _visual.faceAtlas.leftEyeOffset if "eye_l" in node_name else _visual.faceAtlas.otherOffset)
			_facial.register_material(node_name, mat)
	else:
		_apply_material_texture(mat,"lightmap_texture",str(_visual.textures.get("bodyLightmap","")),"has_lightmap")
		if _visual.has("bodyShadowTint"): mat.set_shader_parameter("shadow_tint",_visual.bodyShadowTint)
	mat.set_shader_parameter("material_kind", kind)
	mat.set_shader_parameter("ghost_amount", 1.0 if is_ghost else 0.0)
	if outline_pixels > 0.0 and not alpha_slot:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("outline_pixels", outline_pixels)
		outline.set_shader_parameter("outline_color", Color(0.08, 0.16, 0.23) if is_ghost else Color(0.22, 0.18, 0.30))
		mat.next_pass = outline
	if kind < 3:
		var arrays := mesh_node.mesh.surface_get_arrays(surface_index)
		var has_uv2: bool = arrays[Mesh.ARRAY_TEX_UV2] != null and arrays[Mesh.ARRAY_TEX_UV2].size() > 0
		NativeMaterials.apply(mat, mat.next_pass as ShaderMaterial, str(_visual.get("nativeMaterialProfile", "")),
			str(_visual.get("surfaceNativeRoles",{}).get(slot_key,["body", "hair", "face"][kind])), has_uv2,
			str(_visual.get("nativeMaterialCatalog", NativeMaterials.CATALOG)))
	# A character may have several body materials and a different eye atlas.
	# Slot-specific native bindings take precedence over the broad mesh roles.
	var slot_textures: Dictionary=_visual.get("surfaceTextures",{}).get(slot_key,{})
	for entry in [["albedo","albedo_texture",""],["lightmap","lightmap_texture","has_lightmap"],["faceMap","face_mask_texture","has_face_mask"]]:
		if slot_textures.has(entry[0]):
			_apply_material_texture(mat,entry[1],str(slot_textures[entry[0]]),entry[2])
	var slot_uv: Dictionary=_visual.get("surfaceUv",{}).get(slot_key,{})
	if slot_uv.has("scale"): mat.set_shader_parameter("uv_scale",slot_uv.scale)
	if slot_uv.has("offset"): mat.set_shader_parameter("uv_offset",slot_uv.offset)
	# Native equipment may have no body lightmap; apply its own audited slot
	# properties after broad body defaults rather than shading it as clothing.
	var slot_parameters: Dictionary=_visual.get("surfaceShaderParameters",{}).get(slot_key,{})
	for parameter in slot_parameters:
		mat.set_shader_parameter(str(parameter),slot_parameters[parameter])
	if mat.next_pass is ShaderMaterial and bool(mat.get_shader_parameter("use_alpha_clip")):
		for parameter in ["albedo_texture","uv_scale","uv_offset"]:
			mat.next_pass.set_shader_parameter(parameter,mat.get_shader_parameter(parameter))
	materials.append(mat)
	return mat

func _set_native_form(burst: bool) -> void:
	# Reproduce source m_IsActive tracks on whole native meshes. Both forms
	# keep their original Skin and rig; never swap or stretch individual bones.
	if _eclipse_form == burst: return
	_eclipse_form = burst
	for node: MeshInstance3D in _form_nodes.normal: node.visible = not burst
	for node: MeshInstance3D in _form_nodes.burst: node.visible = burst

func _apply_material_texture(material: ShaderMaterial, parameter: String, path: String, flag: String = "") -> void:
	if path.is_empty() or not ResourceLoader.exists(path): return
	material.set_shader_parameter(parameter,load(path))
	if not flag.is_empty(): material.set_shader_parameter(flag,true)

func _normalize_model() -> void:
	# Use the original scene pose once. StandBy/Idle may bend the knees or
	# lean forward and must never make a character scale up to compensate.
	var sampled_pose: Array[Transform3D]=[]
	for bone in skeleton.get_bone_count():
		sampled_pose.append(skeleton.get_bone_pose(bone))
		skeleton.set_bone_pose(bone,_imported_base_pose[bone])
	var measured:=ModelBounds.measure(model,skeleton,_visual.get("hiddenSurfaces",[]))
	for bone in sampled_pose.size(): skeleton.set_bone_pose(bone,sampled_pose[bone])
	if measured.is_empty(): return
	var bounds: AABB=measured.bounds
	if bounds.size.y < 0.01:
		return
	var model_scale := float(_visual.height) / bounds.size.y
	_normalization={"reference":"native_neutral_skinned","height":bounds.size.y,"scale":model_scale,"vertices":measured.vertices}
	_pivot.scale = Vector3.ONE * model_scale
	_pivot.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * model_scale
	# Hair and long coat tails make the visual AABB asymmetric. Center combat's
	# X/Z origin on the native pelvis so opposite facings cannot lean ~0.36 units
	# into the logical gap before an attack even starts. Keep the floor Y intact.
	if _root_bone >= 0:
		var pelvis_world := skeleton.global_transform * skeleton.get_bone_global_pose(_root_bone).origin
		var pelvis_local := global_transform.affine_inverse() * pelvis_world
		_pivot.position.x -= pelvis_local.x
		_pivot.position.z -= pelvis_local.z

func animate_fighter(f: Dictionary, delta: float, game_time: float, ult_time: float = -1.0) -> void:
	if not ready_for_combat:
		return
	_set_native_form(float(f.get("eclipseRemaining", 0.0)) > 0.0 or str(f.get("state", "")) == "ultimate" or (str(f.get("state", "")) == "attack" and bool(f.get("attack", {}).get("eclipse", false))))
	var in_story := bool(f.get("story", false))
	if _story_active and not in_story: _reset_story_expression()
	_story_active = in_story
	_stance = str(f.get("stance","punch"))
	var key := _motion_key(f)
	var clock := maxf(0.0, ult_time if key == "ultimate" and ult_time >= 0.0 else float(f.get("stateTime", game_time)))
	var changed := key != current_motion or clock < _last_clock - 0.000001
	var visible_body: Dictionary = {}
	if changed and key != "stagger":
		# The next action starts at the pose actually seen, including a parry's
		# chest brace. Capture it before removing additive layers. Cloth retains
		# its clean source pose; its independent solver must never feed back here.
		for i in skeleton.get_bone_count():
			if str(skeleton.get_bone_name(i)).begins_with("Bip001"):
				visible_body[i] = skeleton.get_bone_pose(i)
	_restore_impact_pose()
	if _victory_last_time >= 0.0:
		for prop in _victory_props: prop.visible = false
		if _secondary_enabled: _secondary.reset()
		_facial.reset()
		_victory_last_time = -1.0
	if _secondary_enabled: _secondary.restore_base_pose()
	if changed:
		_previous_pose.clear()
		for i in skeleton.get_bone_count():
			_previous_pose.append(visible_body.get(i, skeleton.get_bone_pose(i)))
		_transition_floor = _foot_floor()
		_transition_from = current_motion
		_transition_length = _blend_duration(key, f)
		# State time can already be partway through a new action at low FPS.
		# Do not restart its blend after the contact point has been reached.
		_transition_time = minf(clock, _transition_length)
		current_motion = key
		animation_player.play(_prefix + str(_motions[key]["clip"]))
	else:
		_transition_time = minf(_transition_length, maxf(clock, _transition_time + maxf(0.0, delta)))
	_last_clock = clock
	var sampled_time := _sample_time(key, f, clock)
	# A late parry followup can extend the same enemy stagger without resetting
	# its clock. Hold the recovery pose until the longer mapping catches up,
	# rather than rewinding the native hit motion when its duration grows.
	source_time = maxf(source_time, sampled_time) if key == "stagger" and not changed else sampled_time
	_restore_source_pose()
	animation_player.seek(source_time, true)
	animation_player.advance(0.0)
	_update_weapon_visibility(f, key)
	if not _previous_pose.is_empty() and _transition_time < _transition_length:
		_blend_source_pose()
	if _root_bone >= 0:
		var root_position := skeleton.get_bone_pose_position(_root_bone)
		root_position.x = _root_origin.x
		root_position.z = _root_origin.z
		if key=="ultimate" and (_visual.has("ultimateJumpLimit") or _visual.has("ultimateJumpWorldLimit")):
			var rise := maxf(0.0,root_position.y-_root_origin.y)
			var limit := float(_visual.get("ultimateJumpLimit",0.7))
			if _visual.has("ultimateJumpWorldLimit"):
				var parent := skeleton.get_bone_parent(_root_bone)
				var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
				var world_per_local := (skeleton.global_transform.basis * parent_basis * Vector3.UP).length()
				limit = float(_visual.ultimateJumpWorldLimit)/maxf(0.000001,world_per_local)
			root_position.y = minf(root_position.y,_root_origin.y)+rise/(1.0+rise/limit)
		skeleton.set_bone_pose_position(_root_bone, root_position)
	position.x = float(f.get("x", 0.0))
	var facing := -1.0 if float(f.get("facing", 1.0)) < 0.0 else 1.0
	rotation.y = float(f.get("presentationYaw", facing * (PI / 2.0 - 0.23)))
	var step := maxf(0.0, delta)
	_impact_age = minf(_impact_duration, _impact_age + step)
	var guarding := key == "guard" or (key == "idle" and _impact_kind in ["block", "parry"] and _impact_age < _impact_duration)
	_defense_clock += step if guarding else 0.0
	_guard_weight = move_toward(_guard_weight, 1.0 if guarding else 0.0, step / (0.10 if guarding else 0.12))
	if key not in ["idle","guard"]:
		# The player may act immediately after a parry. Never mix the defensive
		# motion over a new strike, dodge, ultimate, or a genuine stagger.
		_guard_weight = 0.0
	if key not in ["idle","guard","stagger","dead"]:
		# A newly accepted action owns the native contact pose immediately.
		# Old guard/hit recoil must not pull the hands away from its target.
		_impact_age = _impact_duration
	_recoil = _impact_strength * pow(maxf(0.0, 1.0 - _impact_age / maxf(0.001, _impact_duration)), 2.0)
	_apply_guard_pose()
	if _root_bone >= 0:
		# The retargeted defensive source includes a small root translation.
		# It cannot override the same combat-plane lock used by native attacks.
		var guarded_root := skeleton.get_bone_pose_position(_root_bone)
		guarded_root.x = _root_origin.x
		guarded_root.z = _root_origin.z
		skeleton.set_bone_pose_position(_root_bone, guarded_root)
	_apply_impact_transform()
	_apply_body_impact()
	_apply_chain_extent(facing)
	if _secondary_enabled:
		_secondary.update(step, {"state":key, "facing":facing, "x":position.x})
	_facial.update(step, {"motion":key, "clock":clock,
		"duration":float(f.get("attack", {}).get("duration", f.get("stateDuration", 1.0))),
		"combatProfile":_profile.get("combatProfile", "")})
	_flash_remaining = maxf(0.0, _flash_remaining - step)
	for mat in materials:
		mat.set_shader_parameter("flash_amount", clampf(_flash_remaining / 0.12, 0.0, 1.0))
		mat.set_shader_parameter("key_direction", Vector3(facing * 0.45, 0.72, 0.56))
	_update_face_vectors()

func _restore_source_pose() -> void:
	# AnimationPlayer.seek updates only tracked bones. In C4, for example,
	# Pelvis has no native rotation track but is written by the defense layer.
	# Always start sampling from a clean native base so an outgoing overlay or
	# a partly blended helper cannot contaminate later clips or frozen frames.
	for i in _source_base_pose.size():
		skeleton.set_bone_pose(i, _source_base_pose[i])

func _update_weapon_visibility(f: Dictionary, key: String) -> void:
	# Native mesh skinning already follows the original C6 Weapon bones. Keep
	# their source transform tracks; do not attach them a second time to a hand.
	var kind := ""
	if not bool(f.get("story", false)) and key not in ["dead", "stagger", "intro", "idle", "move", "guard"]:
		var motion: Dictionary = _motions.get(key, {})
		kind = str(motion.get("weapon", ""))
		if source_time < float(motion.get("weaponStart",0.0)) or source_time > float(motion.get("weaponEnd",motion.get("end",0.0))): kind=""
		var requested := str(f.get("attack", {}).get("weapon", kind))
		if requested != kind: kind = ""
	_weapon_kind = kind
	for weapon in _weapon_nodes:
		for mesh: MeshInstance3D in _weapon_nodes[weapon]:
			mesh.visible = weapon == kind

func _reset_story_expression() -> void:
	for item in _story_shapes:
		item.mesh.set_blend_shape_value(int(item.index), float(item.base))
	_facial.reset()

func _apply_chain_extent(facing: float) -> void:
	_chain_extent_scale=1.0
	if _weapon_kind!="chain" or _chain_anchor<0 or _chain_bones.is_empty(): return
	var limit:=float(_visual.get("chainWorldReachLimit",3.2))
	var anchor:=skeleton.get_bone_global_pose(_chain_anchor).origin
	var world_anchor:=skeleton.global_transform*anchor
	# C6's native whip extends over fourteen world metres at this character
	# scale. Fit only its eight articulated chain segments to the horizontal
	# arena. Original body, grip, segment rotations and time curves stay intact.
	# Compute in world space so boss scale cannot enlarge the gameplay reach.
	var available:=maxf(0.2,limit-(world_anchor.x-global_position.x)*facing-0.18)
	var poses: Array[Vector3]=[]
	var extent:=0.0
	for bone in _chain_bones:
		var point:=skeleton.get_bone_global_pose(bone).origin
		poses.append(point)
		extent=maxf(extent,(skeleton.global_transform.basis*(point-anchor)).length())
	var threshold:=available*0.84
	if extent<=threshold or extent<0.0001:return
	var remainder:=available-threshold
	var bounded:=threshold+remainder*(1.0-exp(-(extent-threshold)/remainder))
	_chain_extent_scale=bounded/extent
	for i in _chain_bones.size():
		var bone:=_chain_bones[i]
		var target:=anchor+(poses[i]-anchor)*_chain_extent_scale
		var parent:=skeleton.get_bone_parent(bone)
		if parent>=0:target=skeleton.get_bone_global_pose(parent).affine_inverse()*target
		skeleton.set_bone_pose_position(bone,target)

func apply_story_expression(mood: String, talking: bool, time: float) -> void:
	# Dialogue timing is an authored presentation of original expression shapes,
	# not recovered facial animation. It is absolute-time based for pause safety.
	if not ready_for_combat: return
	_story_active = true
	_weapon_kind = ""
	for weapon in _weapon_nodes:
		for mesh: MeshInstance3D in _weapon_nodes[weapon]: mesh.visible = false
	if _story_shapes.is_empty():
		_facial.animate_dialogue(mood, talking, time)
		return
	var values: Dictionary = {}
	if mood in ["smile", "playful", "confident", "teasing", "proud"]:
		values = {"Eyebrow_Smily":0.34,"Mouth_Smile01":0.25,"Eye_Contempt":0.12}
	elif mood in ["angry", "serious", "determined"]:
		values = {"Eyebrow_Serious":0.52,"Mouth_Line01":0.3,"Eye_Hostitlity":0.15}
	elif mood in ["surprised", "question", "curious"]:
		values = {"Eyebrow_Up":0.36,"Eye_Surprised":0.22,"Mouth_O01":0.14}
	var blink_phase := fposmod(maxf(time, 0.0)+0.7, 4.1)
	var blink := maxf(0.0, 1.0-absf(blink_phase-3.83)/0.085)
	values["Eye_Wink01_L"] = blink
	values["Eye_Wink01_R"] = blink
	if talking:
		values["Mouth_A01"] = 0.09+0.19*pow(0.5+0.5*sin(time*15.0),2.0)
		values["Mouth_O01"] = float(values.get("Mouth_O01", 0.0))+0.06*(0.5+0.5*sin(time*10.7+0.6))
	for item in _story_shapes:
		item.mesh.set_blend_shape_value(int(item.index), clampf(float(values.get(item.name,item.base)),0.0,0.55 if not str(item.name).begins_with("Eye_Wink") else 1.0))

func _blend_duration(key: String, f: Dictionary) -> float:
	if key == "stagger":
		# A first impact remains immediate. Consecutive hits keep the current
		# underlying pose for a short handoff, with the fresh body impulse applied
		# once afterwards, so neither the torso nor hitstop has to wait.
		return 0.04 if current_motion == "stagger" else 0.0
	if str(f.get("state", "")) == "attack":
		var attack: Dictionary = f.get("attack", {})
		var duration := 0.045
		if bool(attack.get("parryFollowup", false)) or _defense_phase == "parry":
			duration = 0.09
		elif current_motion == "guard" or _guard_weight > 0.01:
			duration = 0.075
		elif current_motion == "stagger":
			duration = 0.07
		elif current_motion.begins_with("light") or current_motion.begins_with("kick_") or current_motion in ["heavy", "ability"] or current_motion.begins_with("counter_"):
			duration = 0.06
		# Contact mapping is unchanged; there is no previous-pose influence for
		# the final third of startup, including accelerated parry followups.
		return minf(duration, maxf(0.0, float(attack.get("windup", 0.0))) * 0.65)
	if key == "guard":
		return 0.0 if current_motion in ["idle", "guard"] else 0.065
	if current_motion == "stagger":
		return 0.10
	return 0.075

func _foot_floor() -> float:
	if _feet.is_empty(): return 0.0
	var floor_y := INF
	for foot in _feet:
		floor_y = minf(floor_y, skeleton.get_bone_global_pose(foot).origin.y)
	return floor_y

func _blend_source_pose() -> void:
	var amount := smoothstep(0.0, _transition_length, _transition_time)
	var target_floor := _foot_floor()
	for i in skeleton.get_bone_count():
		var previous_rotation := _previous_pose[i].basis.orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(i, previous_rotation.slerp(skeleton.get_bone_pose_rotation(i), amount))
	# Keep every non-root translation and scale from the native target. Blending
	# full transforms changes limb lengths on skeletons with animated translations.
	if _root_bone >= 0:
		var root_position := skeleton.get_bone_pose_position(_root_bone)
		root_position.y = lerpf(_previous_pose[_root_bone].origin.y, root_position.y, amount)
		skeleton.set_bone_pose_position(_root_bone, root_position)
		if not _feet.is_empty():
			var parent := skeleton.get_bone_parent(_root_bone)
			var up_y := skeleton.get_bone_global_pose(parent).basis.y.y if parent >= 0 else 1.0
			if absf(up_y) > 0.001:
				# Rotational interpolation otherwise makes a crouched guard dip
				# under the floor. Preserve the old-to-new supporting foot height,
				# without flattening native jumps or moving the combat X/Z root.
				root_position.y += (lerpf(_transition_floor, target_floor, amount) - _foot_floor()) / up_y
				skeleton.set_bone_pose_position(_root_bone, root_position)

func _motion_key(f: Dictionary) -> String:
	var state := str(f.get("state", "idle"))
	if state == "attack":
		var attack: Dictionary = f.get("attack", {})
		var explicit_motion := str(attack.get("motion",""))
		if _motions.has(explicit_motion): return explicit_motion
		var variant := "kick_" if str(f.get("stance","punch"))=="kick" and _motions.has("kick_light1") else ""
		if str(attack.get("name", "")) == "heavy":
			return variant+"heavy"
		if str(attack.get("name", "")) == "ability":
			return "ability"
		return variant+"light" + str(clampi(int(attack.get("comboIndex", f.get("combo", 0))), 0, 2) + 1)
	if state == "dodge" and float(f.get("dodgeDirection", 1.0)) * float(f.get("facing", 1.0)) < 0.0:
		return "dodgeBack"
	return state if _motions.has(state) else "idle"

func _sample_time(key: String, f: Dictionary, clock: float) -> float:
	var motion: Dictionary = _motions[key]
	var end_time := float(motion["end"])
	var start_time := float(motion.get("start",0.0))
	if _native_guard and key=="guard": return float(_profile.defense.get("holdTime",0.18))
	if key in ["idle", "move", "guard", "intro"]:
		return start_time+fposmod(clock, end_time-start_time)
	if str(f.get("state",""))=="attack" or key.begins_with("light") or key in ["heavy","ability"]:
		var attack: Dictionary = f.get("attack", {})
		var duration := maxf(0.001, float(attack.get("duration", f.get("stateDuration", end_time))))
		var windup := float(attack.get("windup", 0.0))
		var contact := float(motion.get("contact", -1.0))
		var native_contacts: Array = motion.get("contacts", [])
		var hit_windows: Array = attack.get("hitWindows", [])
		if not native_contacts.is_empty() and native_contacts.size() == hit_windows.size():
			var previous_game := 0.0
			var previous_source := start_time
			for i in native_contacts.size():
				var next_game := float(hit_windows[i])
				var next_source := float(native_contacts[i])
				if clock <= next_game:
					return lerpf(previous_source, next_source, clampf((clock-previous_game)/maxf(0.001,next_game-previous_game),0.0,1.0))
				previous_game = next_game
				previous_source = next_source
			return lerpf(previous_source,end_time,clampf((clock-previous_game)/maxf(0.001,duration-previous_game),0.0,1.0))
		if contact > 0.0 and windup > 0.0 and duration > windup:
			var paced := _pacing.has(key) and str(f.get("side", "player")) == "player"
			if clock <= windup:
				var preparation := clampf(clock / windup, 0.0, 1.0)
				if paced: preparation = _paced_preparation(key, preparation)
				return lerpf(start_time,contact,preparation)
			var recovery := clampf((clock - windup) / (duration - windup), 0.0, 1.0)
			# Preserve follow-through, then ease into the final recovery pose.
			if paced: recovery = 1.0 - pow(1.0 - recovery, 1.6)
			return contact + recovery * (end_time - contact)
		return lerpf(start_time,end_time,clampf(clock / duration, 0.0, 1.0))
	if key == "ultimate" or key.begins_with("dodge"):
		var duration := maxf(0.001, float(f.get("stateDuration", end_time)))
		return clampf(clock / duration, 0.0, 1.0) * end_time
	if key == "stagger":
		# The native clip starts at the idle pose. Skip that lead-in, then fit its
		# contact and recovery into combat's shorter stun without cutting it off.
		var duration := maxf(0.08, float(f.get("stateDuration", 0.32)))
		var contact_window := minf(0.06, duration * 0.25)
		if clock <= contact_window:
			return lerpf(0.085, 0.18, clampf(clock / contact_window, 0.0, 1.0))
		return lerpf(0.18, end_time - 0.025, smoothstep(contact_window, duration, clock))
	return minf(clock, end_time - 0.00001)

func _paced_preparation(key: String, progress: float) -> float:
	var anchors: Array = _pacing[key]
	var first: Vector2 = anchors[0]
	var second: Vector2 = anchors[1]
	if progress <= first.x:
		return lerpf(0.0, first.y, progress / first.x)
	if progress <= second.x:
		return lerpf(first.y, second.y, (progress - first.x) / (second.x - first.x))
	return lerpf(second.y, 1.0, (progress - second.x) / (1.0 - second.x))

func react_impact(kind: String, direction: float, strong: bool = false) -> void:
	# Direction is the world-X force on this fighter, not the attacker's facing.
	_restore_impact_pose()
	_impact_kind = kind
	_impact_direction = -1.0 if direction < 0.0 else 1.0
	_impact_age = 0.0
	_impact_duration = 0.40 if kind == "parry" else 0.30 if kind == "block" else 0.34 if strong else 0.22
	_impact_strong = strong
	_impact_strength = (1.35 if strong else 1.0) * (0.65 if kind == "block" else 1.0)
	_recoil = _impact_strength
	if kind in ["block", "parry"]:
		_guard_weight = 1.0
	else:
		_guard_weight = 0.0
	if ready_for_combat:
		_apply_impact_transform()
		_apply_body_impact()

func _apply_impact_transform() -> void:
	if _pivot == null:
		return
	# Combat owns displacement; reaction lives in the upper body. Translating or
	# rotating the entire model made planted feet slide and heavy hits feel elastic.
	_pivot.rotation = Vector3.ZERO
	_pivot.position = _pivot_origin

func _restore_impact_pose() -> void:
	if is_instance_valid(skeleton):
		for bone: int in _impact_pose_base:
			skeleton.set_bone_pose_rotation(bone,_impact_pose_base[bone])
	_impact_pose_base.clear()
	_impact_body_angle = 0.0

func _apply_body_impact() -> void:
	if _recoil<=0.000001 or _impact_kind.is_empty() or not is_instance_valid(skeleton):return
	var bend := 0.22 if _impact_strong else 0.12
	var twist := 0.065 if _impact_strong else 0.035
	if _impact_kind=="block":
		bend=0.12 if _impact_strong else 0.075
		twist=0.025
	elif _impact_kind=="parry":
		# The native L motion supplies the counter-sweep. Add only a short brace.
		bend=0.024;twist=0.012
	_impact_body_angle=bend*_recoil
	var space := skeleton.global_basis.orthonormalized().inverse()
	var force_axis := (space*Vector3.UP.cross(Vector3(_impact_direction,0.0,0.0))).normalized()
	var up_axis := (space*Vector3.UP).normalized()
	var weight_sum:=0.0
	for entry:Dictionary in _impact_bones:weight_sum+=float(entry.weight)
	for entry:Dictionary in _impact_bones:
		var bone:=int(entry.bone);var weight:=float(entry.weight)/maxf(0.001,weight_sum)
		_impact_pose_base[bone]=skeleton.get_bone_pose_rotation(bone)
		var change:=Basis(force_axis,_impact_body_angle*weight)*Basis(up_axis,twist*_recoil*_impact_direction*weight)
		_apply_global_bone_turn(bone,change)
	if _impact_neck>=0:
		_impact_pose_base[_impact_neck]=skeleton.get_bone_pose_rotation(_impact_neck)
		# Keep the eyes readable while the chest and shoulders take the impulse.
		_apply_global_bone_turn(_impact_neck,Basis(force_axis,-_impact_body_angle*0.18))

func _apply_global_bone_turn(bone:int,change:Basis) -> void:
	var target:=change*skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var parent:=skeleton.get_bone_parent(bone)
	if parent>=0:target=skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse()*target
	skeleton.set_bone_pose_rotation(bone,target.orthonormalized().get_rotation_quaternion())

func _apply_guard_pose() -> void:
	_defense_clip = ""
	_defense_time = 0.0
	_defense_phase = "none"
	_defense_weight = _guard_weight
	if _defense_source == "none":
		_defense_weight = 0.0
		return
	if _guard_weight <= 0.00001:
		return
	if _native_guard:
		_apply_native_guard()
		return
	_defense_clip = "Attack_ParryAid_H"
	_defense_time = 0.018+0.016*(0.5-0.5*cos(_defense_clock*TAU/1.9))
	_defense_phase = "hold" if _guard_weight>=0.999 else "enter" if current_motion=="guard" else "release"
	_defense.apply_pose(skeleton,_defense_clip,_defense_time,_guard_weight)
	if _impact_kind in ["block","parry"] and _impact_age < _impact_duration:
		_defense_phase = _impact_kind
		if _impact_kind=="parry":
			_defense_clip = "Attack_ParryAid_L"
			_defense_time = lerpf(0.0,0.32,clampf(_impact_age/0.27,0.0,1.0))
		else:
			_defense_clip = "Attack_ParryAid_H"
			_defense_time = lerpf(0.035,0.23 if _impact_strong else 0.14,clampf(_impact_age/0.19,0.0,1.0))
		var finish_from := 0.25 if _impact_kind=="parry" else 0.17
		var reaction_weight := 1.0-smoothstep(finish_from,_impact_duration,_impact_age)
		_defense.apply_pose(skeleton,_defense_clip,_defense_time,_guard_weight*reaction_weight)

func _apply_native_guard() -> void:
	_defense_clip = str(_profile.defense.get("kickClip","KickStyle_DefendStyle") if _stance=="kick" else _profile.defense.get("guardClip","PunchStyle_DefendStyle"))
	var hold := float(_profile.defense.get("holdTime",0.18))
	_defense_time = hold+0.012*sin(_defense_clock*2.0)
	_defense_phase = "hold" if _guard_weight>=0.999 else "enter" if current_motion=="guard" else "release"
	if _impact_kind in ["block","parry"] and _impact_age<_impact_duration:
		_defense_phase = _impact_kind
		var reaction_clip := str(_profile.defense.get("parryClip" if _impact_kind=="parry" else "blockClip",""))
		if not reaction_clip.is_empty():
			_defense_clip = reaction_clip
			if _impact_kind=="parry":
				_defense_time=lerpf(float(_profile.defense.get("parryStart",0.0)),float(_profile.defense.get("parryEnd",0.32)),clampf(_impact_age/0.27,0.0,1.0))
			else:
				_defense_time=lerpf(float(_profile.defense.get("blockStart",0.035)),float(_profile.defense.get("heavyBlockEnd",0.23) if _impact_strong else _profile.defense.get("blockEnd",0.14)),clampf(_impact_age/0.19,0.0,1.0))
		else:
			_defense_time += (0.16 if _impact_kind=="parry" else 0.09)*sin(clampf(_impact_age/_impact_duration,0.0,1.0)*PI)
	var clip := animation_player.get_animation(_prefix+_defense_clip)
	if clip==null: return
	if not _native_bone_tracks.has(_defense_clip):
		var mapping: Array=[]
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			var bone := skeleton.find_bone(str(path.get_subname(0))) if path.get_subname_count()>0 else -1
			mapping.append(bone)
		_native_bone_tracks[_defense_clip]=mapping
	var indices: Array=_native_bone_tracks[_defense_clip]
	for track in clip.get_track_count():
		var bone: int=indices[track]
		if bone<0: continue
		match clip.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(clip.rotation_track_interpolate(track,_defense_time),_guard_weight))
			Animation.TYPE_POSITION_3D:
				var value:=clip.position_track_interpolate(track,_defense_time)
				if bone==_root_bone:
					value.x=_root_origin.x
					value.z=_root_origin.z
				skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(value,_guard_weight))
	if bool(_profile.defense.get("fullGrounding",false)) and _root_bone>=0 and not _feet.is_empty():
		var position_root:=skeleton.get_bone_pose_position(_root_bone)
		position_root.y+=_native_defense_floor-_foot_floor()
		skeleton.set_bone_pose_position(_root_bone,position_root)

func _solve_guard_arm(arm: Dictionary, target: Vector3, pole: Vector3) -> void:
	var upper: int = arm["upper"]
	var fore: int = arm["fore"]
	var hand: int = arm["hand"]
	if mini(upper, mini(fore, hand)) < 0:
		return
	var original_upper := skeleton.get_bone_pose_rotation(upper)
	var original_fore := skeleton.get_bone_pose_rotation(fore)
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(fore).origin
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var upper_length := shoulder.distance_to(elbow)
	var fore_length := elbow.distance_to(wrist)
	var direction := (target - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target), absf(upper_length - fore_length) + 0.001, upper_length + fore_length - 0.001)
	var along := (upper_length * upper_length - fore_length * fore_length + distance * distance) / (2.0 * distance)
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var target_elbow := shoulder + direction * along + bend * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	_rotate_bone_toward(upper, elbow - shoulder, target_elbow - shoulder)
	elbow = skeleton.get_bone_global_pose(fore).origin
	wrist = skeleton.get_bone_global_pose(hand).origin
	_rotate_bone_toward(fore, wrist - elbow, shoulder + direction * distance - elbow)
	var solved_upper := skeleton.get_bone_pose_rotation(upper)
	var solved_fore := skeleton.get_bone_pose_rotation(fore)
	skeleton.set_bone_pose_rotation(upper, original_upper.slerp(solved_upper, _guard_weight))
	skeleton.set_bone_pose_rotation(fore, original_fore.slerp(solved_fore, _guard_weight))

func _rotate_bone_toward(index: int, current: Vector3, desired: Vector3) -> void:
	if current.length_squared() < 0.000001 or desired.length_squared() < 0.000001:
		return
	var rotation_delta := Basis(Quaternion(current.normalized(), desired.normalized()))
	var target_basis := rotation_delta * skeleton.get_bone_global_pose(index).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		target_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * target_basis
	skeleton.set_bone_pose_rotation(index, target_basis.orthonormalized().get_rotation_quaternion())

func motion_snapshot() -> Dictionary:
	# Per-frame contact trace: avoid inspecting every cloth bone for diagnostics.
	return {"motion":current_motion,"sourceTime":source_time,"defenseTime":_defense_time,
		"defensePhase":_defense_phase,"defenseWeight":_defense_weight}

func presentation_snapshot() -> Dictionary:
	return {"motion": current_motion, "sourceTime": source_time, "guardWeight": _guard_weight,
		"modelPath":str(_profile.get("modelPath","")),"deathDuration":death_duration(),"adaptationSource":_profile.get("adaptationSource",{}),"weapon":_weapon_kind,"chainExtentScale":_chain_extent_scale,"story":_story_active,
		"recoil": _recoil, "impactKind": _impact_kind, "impactAge": _impact_age, "flash": _flash_remaining,
		"impactBodyAngle":_impact_body_angle,"impactDuration":_impact_duration,
		"transitionFrom":_transition_from,"transitionTime":_transition_time,"transitionDuration":_transition_length,
		"defenseClip":_defense_clip,"defenseTime":_defense_time,"defensePhase":_defense_phase,"defenseWeight":_defense_weight,
		"victoryAvailable":_victory_available,"combatProfile":_profile.get("combatProfile",""),
		"normalization":_normalization.duplicate(),
		"secondaryMotion":_secondary.snapshot() if _secondary_enabled else {"enabled":false},
		"facial":_facial.snapshot()}

func death_duration() -> float:
	return maxf(0.01,float(_motions.get("dead",{}).get("end",1.9)))

func animate_native_dialogue(clip: String, duration: float, clock: float, x: float, yaw: float, sample_clock: float = -1.0) -> void:
	if not ready_for_combat or not animation_player.has_animation(clip): return
	_set_native_form(false)
	var entering := current_motion != "native_dialogue" or _native_dialogue_clip != clip or clock < _last_clock
	var attachment_delta:=maxf(0.0,clock-_last_clock) if not entering else 0.0
	if entering:
		reset_presentation()
		_native_dialogue_clip = clip
		animation_player.stop()
	# Sample the complete original take at its original speed. No body masks,
	# additive body turns, root locks, IK, or synthetic facial timing. The
	# outfit may resolve contact against its native trouser surface afterward.
	for bone in _imported_base_pose.size():
		skeleton.set_bone_pose(bone, _imported_base_pose[bone])
	if not is_instance_valid(_native_dialogue_player):
		# Combat's mixer caches defaults for retargeted defense position tracks.
		# An independent source-only player prevents those inactive channels
		# from restoring combat-rest hand lengths into an unkeyed native take.
		_native_dialogue_player = AnimationPlayer.new()
		_native_dialogue_player.name = "NativeDialoguePlayer"
		_native_dialogue_player.root_node = animation_player.root_node
		_native_dialogue_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation_player.get_parent().add_child(_native_dialogue_player)
		_native_dialogue_player.add_animation_library("source",AnimationLibrary.new())
	var library := _native_dialogue_player.get_animation_library("source")
	var source_name := clip.replace("/","_")
	if not library.has_animation(source_name): library.add_animation(source_name,animation_player.get_animation(clip))
	if entering: _native_dialogue_player.play("source/"+source_name,0.0)
	source_time = fposmod(maxf(0.0,clock if sample_clock<0.0 else sample_clock),maxf(0.001,duration))
	_native_dialogue_player.seek(source_time,true)
	_native_dialogue_player.advance(0.0)
	if _secondary_enabled:_secondary.apply_native_contacts(attachment_delta,entering)
	current_motion = "native_dialogue"
	_story_active = true
	_last_clock = clock
	position = Vector3(x,0,0)
	rotation = Vector3(0,yaw,0)
	_pivot.position = _pivot_origin
	_pivot.rotation = Vector3.ZERO
	_update_face_vectors()

func animate_victory(time: float) -> void:
	if not ready_for_combat:
		return
	_set_native_form(false)
	if _story_active:
		_reset_story_expression()
		_story_active = false
	_update_weapon_visibility({"story":true}, "idle")
	_restore_impact_pose()
	var step := time - _victory_last_time if _victory_last_time >= 0.0 else 0.0
	if _victory_last_time < 0.0 or step < 0.0 or step > 0.25:
		if _secondary_enabled: _secondary.reset()
		step = 0.0
	_victory_last_time = time
	if _secondary_enabled: _secondary.restore_base_pose()
	var clip := str(_victory.get("clip", "Victory"))
	var duration := float(_victory.get("clipDuration", 3.8))
	# The exported C5 take opens with a 0.60 s held setup pose. Begin at the
	# gesture, then keep the original speed and native VictoryIdle continuation.
	var native_time := maxf(0.0, time) + float(_victory.get("leadInSkip", 0.0))
	var idle := native_time >= duration
	var key := "victoryIdle" if idle else "victory"
	if not _victory_available:
		animate_fighter({"x":0.0,"facing":1.0,"state":"idle","stateTime":time},0.0,time)
		rotation.y = 0.0
		_update_face_vectors()
		return
	if _victory_idle_base_pose.is_empty():
		# Unity keeps unkeyed prop channels at the preceding take's endpoint.
		# VictoryIdle omits Dummy001's canopy position: restoring combat idle
		# instead drops the open umbrella into the face when results appear.
		_restore_source_pose()
		animation_player.play(_victory_prefix + str(_victory.clip))
		animation_player.seek(duration - 0.00001, true)
		animation_player.advance(0.0)
		for bone in skeleton.get_bone_count():
			_victory_idle_base_pose.append(skeleton.get_bone_pose(bone))
	if idle:
		clip = str(_victory.idleClip)
		source_time = fposmod(maxf(0.0,native_time-duration),float(_victory.idleDuration))
	else:
		source_time = clampf(native_time,0.0,duration-0.00001)
	if current_motion != key:
		current_motion = key
		animation_player.play(_victory_prefix + clip)
	# Some victory tracks omit helpers that a preceding guard/strike changed.
	# Start from the native source pose for deterministic replay and seeking.
	_restore_source_pose()
	if idle:
		for bone in _victory_idle_base_pose.size():
			skeleton.set_bone_pose(bone, _victory_idle_base_pose[bone])
	animation_player.seek(source_time,true)
	animation_player.advance(0.0)
	if _root_bone >= 0:
		var root_position := skeleton.get_bone_pose_position(_root_bone)
		root_position.x = _root_origin.x
		root_position.z = _root_origin.z
		skeleton.set_bone_pose_position(_root_bone,root_position)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	_pivot.rotation = Vector3.ZERO
	_pivot.position = _pivot_origin
	# The original take animates the umbrella's own Sickle/Dummy bones. Showing
	# this skinned prop restores the held-object action without hand attachment.
	for prop in _victory_props: prop.visible = true
	if _secondary_enabled:
		_secondary.update(step, {"state":key, "facing":1.0, "x":0.0})
	_facial.animate_victory(native_time, str(_profile.get("combatProfile", "")))
	for mat in materials:
		mat.set_shader_parameter("flash_amount",0.0)
		mat.set_shader_parameter("key_direction",Vector3(0.32,0.72,0.61))
	_update_face_vectors()

func reset_presentation() -> void:
	_native_dialogue_clip = ""
	if is_instance_valid(_native_dialogue_player): _native_dialogue_player.stop()
	for prop in _victory_props: prop.visible = false
	_restore_impact_pose()
	_reset_story_expression()
	_story_active = false
	_chain_extent_scale=1.0
	_update_weapon_visibility({"story":true}, "idle")
	_guard_weight = 0.0
	_impact_kind = ""
	_impact_age = 0.0
	_impact_duration = 0.0
	_impact_strength = 0.0
	_recoil = 0.0
	_flash_remaining = 0.0
	_defense_clock = 0.0
	_defense_clip = ""
	_defense_time = 0.0
	_defense_phase = "none"
	_defense_weight = 0.0
	_transition_time = 0.0
	_transition_length = 0.0
	_transition_from = ""
	_transition_floor = 0.0
	_previous_pose.clear()
	_last_clock = 0.0
	_victory_last_time = -1.0
	if _secondary_enabled: _secondary.reset()
	_facial.reset()
	source_time = 0.0
	current_motion = "idle"
	if not ready_for_combat:
		return
	_pivot.position = _pivot_origin
	_pivot.rotation = Vector3.ZERO
	# Some armor clips omit helper bones. Clear the previous clip's pose before
	# starting a fresh round/menu so untracked cloth or pelvis keys cannot linger.
	skeleton.reset_bone_poses()
	animation_player.play(_prefix + str(_motions.idle.clip))
	animation_player.seek(0.0, true)
	animation_player.advance(0.0)
	for mat in materials:
		mat.set_shader_parameter("flash_amount", 0.0)
	_update_face_vectors()

func _update_face_vectors() -> void:
	if skeleton == null or _head_bone < 0:
		return
	var head_delta := skeleton.get_bone_global_pose(_head_bone).basis.orthonormalized() * _head_initial_basis.inverse()
	var world_basis := global_basis.orthonormalized()
	var forward := (world_basis * head_delta * Vector3.FORWARD * -1.0).normalized()
	var right := (world_basis * head_delta * Vector3.RIGHT).normalized()
	var up := (world_basis * head_delta * Vector3.UP).normalized()
	for mat in materials:
		mat.set_shader_parameter("face_forward", forward)
		mat.set_shader_parameter("face_right", right)
		mat.set_shader_parameter("face_up", up)

func flash() -> void:
	_flash_remaining = 0.12

func set_enemy_style(tint: Color, _boss: bool=false) -> void:
	# Boss status changes combat behaviour, not the character's body proportions.
	# The native skinned neutral pose already supplies the common display height.
	scale=Vector3.ONE
	for material in materials:
		material.set_shader_parameter("ghost_tint",tint)
