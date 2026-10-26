extends SceneTree
const Roster = preload("res://scripts/fighter_roster.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures.append(message)
func _find(node: Node, kind: String) -> Node:
 if node.is_class(kind): return node
 for child in node.get_children():
  var found := _find(child,kind)
  if found != null: return found
 return null
func _run() -> void:
 var selection: Dictionary=Roster.resolve("fuhua","night_squire","default")
 _check(not selection.is_empty(),"Night Squire resolves as a playable style")
 var config: Dictionary=selection.actor
 _check(config.rig=="fuhua_c3","Own C3 skeleton selected")
 _check(config.visual.get("facialAnimation","").is_empty(),"No invented face timing")
 _check(config.visual.get("secondaryMotion","").is_empty(),"No invented cloth animation")
 _check("body:1" in config.visual.hiddenSurfaces,"Native Invisible material preserved")
 var scene=load(config.modelPath) as PackedScene
 _check(scene!=null,"Native scene loads")
 var model=scene.instantiate()
 root.add_child(model)
 var player=_find(model,"AnimationPlayer") as AnimationPlayer
 var skeleton=_find(model,"Skeleton3D") as Skeleton3D
 _check(skeleton.get_bone_count()==78,"Native 78 bones retained")
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var body=model.find_child("Body",true,false) as MeshInstance3D
 var original_body_binds: Dictionary={}
 for b in body.skin.get_bind_count():
  var bone_name=body.skin.get_bind_name(b)
  if str(bone_name).is_empty():bone_name=skeleton.get_bone_name(body.skin.get_bind_bone(b))
  original_body_binds[bone_name]=body.skin.get_bind_pose(b)
 var equipped: Array=model.find_children("NativeFist*","MeshInstance3D",true,false)
 _check(equipped.size()==2,"Original gauntlets complete both arms")
 for mesh:MeshInstance3D in equipped:
  var valid:=true
  var original_bind_match:=true
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   for i in arrays[Mesh.ARRAY_BONES].size():
    if arrays[Mesh.ARRAY_WEIGHTS][i]<=0.00001:continue
    var bind_index: int=arrays[Mesh.ARRAY_BONES][i]
    var name: StringName=mesh.skin.get_bind_name(bind_index)
    if skeleton.find_bone(name)<0:valid=false
    if original_body_binds.has(name):
     var expected:Transform3D=original_body_binds[name]
     var actual:Transform3D=mesh.skin.get_bind_pose(bind_index)
     if actual.origin.distance_to(expected.origin)>0.00003:original_bind_match=false
     for axis in 3:
      if actual.basis[axis].distance_to(expected.basis[axis])>0.00003:original_bind_match=false
  _check(valid,str(mesh.name)+" every weighted original finger/forearm bind resolves")
  _check(original_bind_match,str(mesh.name)+" matches the original body Skin bind matrices, including native scale")
  var slot:=str(mesh.name).to_lower()+":0"
  _check(config.visual.surfaceNativeRoles.get(slot,"")=="weapon",str(mesh.name)+" uses original weapon material")
  _check(config.visual.surfaceShaderParameters.get(slot,{}).get("has_lightmap",true)==false,str(mesh.name)+" does not borrow character lightmap")
 var motion_rows: Array=[]
 for key: String in config.motions:
  var spec: Dictionary=config.motions[key]
  var clip_name: String=config.prefix+str(spec.clip)
  _check(player.has_animation(clip_name),key+" original clip exists")
  var clip=player.get_animation(clip_name)
  _check(float(spec.end)<=clip.length+0.001,key+" playback stays inside source span")
  if spec.has("contact"):_check(float(spec.contact)<float(spec.end),key+" contact precedes recovery end")
  var paths_valid:=true
  var animation_root=player.get_node(player.root_node)
  for track in clip.get_track_count():
   var path=clip.track_get_path(track)
   var target=animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
   if target==null:paths_valid=false
   elif target is Skeleton3D and path.get_subname_count()>0 and target.find_bone(str(path.get_subname(0)))<0:paths_valid=false
  _check(paths_valid,key+" all native tracks resolve")
  var finite:=true
  var hands: Array[Vector3]=[]
  player.play(clip_name)
  for frame in 121:
   player.seek(float(spec.end)*frame/120.0,true);player.advance(0)
   for bone in skeleton.get_bone_count():
    if not skeleton.get_bone_global_pose(bone).is_finite():finite=false
   hands.append(skeleton.get_bone_global_pose(skeleton.find_bone("Bip001 L Hand")).origin)
  _check(finite,key+" original poses stay finite")
  var movement:=0.0
  for pos: Vector3 in hands:movement=maxf(movement,pos.distance_to(hands[0]))
  _check(movement>0.001,key+" has real body animation")
  motion_rows.append({"motion":key,"clip":clip_name,"end":spec.end,"sourceLength":clip.length,"leftHandMovement":movement})
 player.stop()
 var native=JSON.parse_string(FileAccess.get_file_as_string("res://assets/night-squire/material-profiles.json"))
 for role: String in ["body","hair","face","weapon"]:
  _check(native.profiles.night_squire.has(role),role+" native material profile exists")
  _check(native.profiles.night_squire[role].sourceMaterial.begins_with("Avatar_Fuka_") or native.profiles.night_squire[role].sourceMaterial.begins_with("Weapon_Fist_"),role+" source material recorded")
 var report={"suite":"night_squire_assets","checks":checks,"failures":failures,"motionMappings":motion_rows}
 var file=FileAccess.open("res://build/night-squire-asset-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify({"checks":checks,"failures":failures}))
 model.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)

