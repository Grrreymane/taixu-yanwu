extends SceneTree
const Config = preload("res://assets/shadow-knight/roster.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, detail: String) -> void:
 checks += 1
 if not value: failures.append(detail)
func _find(n: Node, kind: String) -> Node:
 if n.is_class(kind): return n
 for c in n.get_children():
  var f := _find(c,kind)
  if f != null: return f
 return null
func _run() -> void:
 var results: Array = []
 _check(Config.STYLE.id == "shadow_knight", "Independent armor ID")
 _check(Config.STYLE.defaultAppearance == "blood_moon", "Blood moon first appearance")
 _check(Config.APPEARANCES.size() == 2, "Both original and blood moon available")
 for key in Config.APPEARANCES:
  var app: Dictionary = Config.APPEARANCES[key]
  _check(is_equal_approx(float(app.visual.ultimateJumpWorldLimit),.70),str(key)+" Q jump limit is in world units")
  for face_slot in ["eye_l:0","eye_r:0","mouth:0"]:
   _check(is_equal_approx(float(app.visual.surfaceShaderParameters[face_slot].face_part_depth_bias),.000005),str(key)+" native scale face-part depth bias "+face_slot)
  for eye_slot in ["eye_l:0","eye_r:0"]:
   _check(is_equal_approx(float(app.visual.surfaceShaderParameters[eye_slot].native_hue_offset),.424 if key=="blood_moon" else 0.0),str(key)+" native iris hue "+eye_slot)
   _check(is_equal_approx(float(app.visual.surfaceShaderParameters[eye_slot].native_value_offset),.059 if key=="blood_moon" else 0.0),str(key)+" native iris value "+eye_slot)
  _check(FileAccess.file_exists(app.portraitPath), str(key)+" original portrait exists")
  var model: Node3D = load(str(app.modelPath)).instantiate()
  root.add_child(model)
  var skel := _find(model,"Skeleton3D") as Skeleton3D
  var player := _find(model,"AnimationPlayer") as AnimationPlayer
  _check(skel.get_bone_count() == (91 if key == "default" else 98), str(key)+" original distinct skeleton size")
  player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var names := {}
  var weighted_bind_count := 0
  var errors := 0
  for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   names[str(mesh.name)] = true
   _check(mesh.skin != null,str(key)+" native Skin "+str(mesh.name))
   if mesh.skin == null: continue
   var used := {}
   for surface in mesh.mesh.get_surface_count():
    var arrays := mesh.mesh.surface_get_arrays(surface)
    for i in arrays[Mesh.ARRAY_BONES].size():
     if arrays[Mesh.ARRAY_WEIGHTS][i] > 0.00001: used[int(arrays[Mesh.ARRAY_BONES][i])] = true
   for bind in used:
    weighted_bind_count += 1
    var bind_name := mesh.skin.get_bind_name(bind)
    var bone := skel.find_bone(bind_name) if not str(bind_name).is_empty() else mesh.skin.get_bind_bone(bind)
    if bone < 0: errors += 1
    _check(bone >= 0 and bone < skel.get_bone_count(),str(key)+" weighted bind resolves "+str(mesh.name)+":"+str(bind))
    _check(mesh.skin.get_bind_pose(bind).is_finite(),str(key)+" finite native bind")
  for set_name in ["normal","burst"]:
   for mesh_name in app.visual.nativeFormMeshes[set_name]:
    _check(names.has(mesh_name),str(key)+" form mesh exists "+str(mesh_name))
  for mesh_name in app.visual.hiddenMeshes:
   _check(names.has(mesh_name),str(key)+" initial hidden mesh exists "+str(mesh_name))
  var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(app.visual.nativeMaterialCatalog))
  var profiles: Dictionary = catalog.profiles[app.visual.nativeMaterialProfile]
  for slot in app.visual.surfaceNativeRoles:
   _check(profiles.has(app.visual.surfaceNativeRoles[slot]),str(key)+" native material role "+str(slot))
  for tex in app.visual.textures.values(): _check(FileAccess.file_exists(str(tex)),str(key)+" native texture exists "+str(tex))
  for alias in Config.STYLE.motions:
   var mapping: Dictionary = Config.STYLE.motions[alias]
   var clip := str(Config.STYLE.prefix)+str(mapping.clip)
   _check(player.has_animation(clip),str(key)+" alias "+str(alias))
   var anim := player.get_animation(clip)
   _check(anim.get_track_count()>0,str(key)+" body motion has actual tracks "+str(alias))
   _check(float(mapping.end)<=anim.length+0.0001,str(key)+" alias within native clip "+str(alias))
   if mapping.has("contact"): _check(float(mapping.contact)<float(mapping.end),str(key)+" contact before recovery "+str(alias))
  var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(app.textureDir)+"source-manifest.json"))
  var animated_count := 0
  for clip: Dictionary in manifest.nativeClips:
   var anim := player.get_animation(str(clip.name))
   _check(absf(anim.length-float(clip.stopTime)-1.0/60.0)<0.0001,str(key)+" native duration "+str(clip.name))
   if anim.get_track_count()==0: continue
   animated_count += 1
   player.play(str(clip.name))
   for t in [0.0,anim.length*0.37,anim.length-0.0001]:
    player.seek(t,true);player.advance(0.0)
    var finite := true
    for bone in skel.get_bone_count(): finite = finite and skel.get_bone_global_pose(bone).is_finite()
    _check(finite,str(key)+" finite sampled full native clip "+str(clip.name))
  _check(animated_count==46,str(key)+" full transform clip set")
  results.append({"appearance":key,"bones":skel.get_bone_count(),"meshes":names.size(),"animatedClips":animated_count,"weightedBinds":weighted_bind_count,"unresolvedWeightedBinds":errors})
  model.queue_free()
 for filename in ["vfx-map.json","blood-moon-vfx-map.json"]:
  var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/shadow-knight/"+filename))
  for role in ["trail","lightning","ring","impact","glow","smoke"]:
   _check(FileAccess.file_exists(str(map[role])),filename+" native VFX "+role)
 var report := {"checks":checks,"failures":failures,"appearances":results}
 var file := FileAccess.open("res://build/reports/shadow-knight-assets.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify(report))
 await process_frame
 quit(0 if failures.is_empty() else 1)
