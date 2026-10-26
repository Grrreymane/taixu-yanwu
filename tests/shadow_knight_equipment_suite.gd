extends SceneTree
const BASE="../hi3-fuhua-extract/exports/c2-arm-repair/"
var checks=0
var failures=[]
func _initialize():call_deferred("_run")
func _check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _find(n:Node,k:String)->Node:
 if n.is_class(k):return n
 for c in n.get_children():
  var f=_find(c,k)
  if f:return f
 return null
func _run():
 var evidence=JSON.parse_string(FileAccess.get_file_as_string(BASE+"runtime-bind-report.json"))
 var output=[]
 for entry in evidence.appearances:
  var asset=str(entry.appearance);var scene="Avatar_Fuka_C2_NL.scn" if asset=="shadow-knight" else "Avatar_Fuka_C2_04_01.scn"
  var baseline=load(BASE+"godot-stage/assets/"+asset+"/"+scene).instantiate();root.add_child(baseline)
  var repaired=load("res://assets/"+asset+"/"+scene).instantiate();root.add_child(repaired)
  var old_skel=_find(baseline,"Skeleton3D") as Skeleton3D;var skel=_find(repaired,"Skeleton3D") as Skeleton3D
  var old_player=_find(baseline,"AnimationPlayer") as AnimationPlayer;var player=_find(repaired,"AnimationPlayer") as AnimationPlayer
  old_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var redirects={};var original_nodes=[]
  for b in entry.originalNodesPromotedToBones:
   redirects[b.sourceNode]=str(repaired.get_path_to(skel))+":"+str(b.name)
   original_nodes.append([baseline.get_node(b.sourceNode),skel.find_bone(b.name)])
  _check(skel.get_bone_count()==old_skel.get_bone_count()+original_nodes.size(),asset+" only original equipment nodes added")
  for b in old_skel.get_bone_count():
   _check(skel.get_bone_name(b)==old_skel.get_bone_name(b),asset+" existing bone order")
   _check(skel.get_bone_rest(b).is_equal_approx(old_skel.get_bone_rest(b)),asset+" original body rest unchanged")
  var moved=0;var frames=0;var max_origin_error=0.0;var max_local_error=0.0
  for key in old_player.get_animation_list():
   _check(player.has_animation(key),asset+" original clip retained")
   var old=old_player.get_animation(key);var now=player.get_animation(key)
   _check(old.length==now.length and old.loop_mode==now.loop_mode,asset+" clip timing/loop unchanged")
   _check(old.get_track_count()==now.get_track_count(),asset+" track count unchanged")
   for track in old.get_track_count():
    var path=str(old.track_get_path(track));var expected=redirects.get(path,path)
    _check(str(now.track_get_path(track))==expected,asset+" original track target "+path)
    if redirects.has(path):moved+=1
    _check(old.track_get_type(track)==now.track_get_type(track),asset+" track type")
    _check(old.track_get_key_count(track)==now.track_get_key_count(track),asset+" key count")
    _check(old.track_get_interpolation_type(track)==now.track_get_interpolation_type(track),asset+" interpolation")
    var exact=true
    for k in old.track_get_key_count(track):
     if old.track_get_key_time(track,k)!=now.track_get_key_time(track,k) or old.track_get_key_value(track,k)!=now.track_get_key_value(track,k) or old.track_get_key_transition(track,k)!=now.track_get_key_transition(track,k):exact=false
    _check(exact,asset+" all original key times/values/easing unchanged "+str(key)+" "+path)
   if old.get_track_count()==0:continue
   for fraction in [0.0,.25,.5,.75,.999]:
    old_player.stop();player.stop();old_skel.reset_bone_poses();skel.reset_bone_poses()
    # Baseline stored these bones as Node3D; restore the same original local
    # rest as the promoted Skeleton bones before sampling the full native clip.
    for pair in original_nodes:pair[0].transform=skel.get_bone_rest(pair[1])
    old_player.clear_caches();player.clear_caches()
    old_player.play(key);player.play(key)
    old_player.seek(old.length*fraction,true);old_player.advance(0.0)
    player.seek(now.length*fraction,true);player.advance(0.0)
    for b in old_skel.get_bone_count():
     var a=old_skel.get_bone_global_pose(b);var z=skel.get_bone_global_pose(b)
     max_origin_error=maxf(max_origin_error,a.origin.distance_to(z.origin))
     _check(a.is_equal_approx(z),asset+" original body pose equivalence "+str(key)+" "+str(b))
    for pair in original_nodes:
     # Node3D animation mixing defaults unauthored components to identity,
     # unlike Skeleton3D's native rest pose. Compare original curve channels
     # over the original imported rest, not that old importer side effect.
     var rest=skel.get_bone_rest(pair[1]);var position=rest.origin;var rotation=rest.basis.get_rotation_quaternion();var scale=rest.basis.get_scale()
     var path=str(baseline.get_path_to(pair[0]))
     for track in old.get_track_count():
      if str(old.track_get_path(track))!=path:continue
      match old.track_get_type(track):
       Animation.TYPE_POSITION_3D:position=old.position_track_interpolate(track,old.length*fraction)
       Animation.TYPE_ROTATION_3D:rotation=old.rotation_track_interpolate(track,old.length*fraction)
       Animation.TYPE_SCALE_3D:scale=old.scale_track_interpolate(track,old.length*fraction)
     var a=Transform3D(Basis(rotation).scaled(scale),position);var z=skel.get_bone_pose(pair[1])
     max_local_error=maxf(max_local_error,a.origin.distance_to(z.origin))
     _check(a.is_equal_approx(z),asset+" original equipment curve/rest equivalence "+str(key)+" "+str(pair[0].name))
    frames+=1
  _check(moved==int(entry.unchangedTracksRebound),asset+" audited track redirect count")
  var doc=FBXDocument.new();var state=FBXState.new();state.use_named_skin_binds=true
  _check(doc.append_from_file(FileAccess.get_file_as_string(BASE+"source-fbx-path.txt").strip_edges(),state,0,"res://assets/"+asset)==OK,asset+" native weapon source import")
  var source=doc.generate_scene(state);root.add_child(source)
  var src_skel=_find(source,"Skeleton3D") as Skeleton3D
  for original:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
   var mesh=repaired.find_child("NativeFist"+str(original.name),true,false) as MeshInstance3D
   _check(mesh!=null,asset+" original equipment exists")
   if mesh==null:continue
   _check(mesh.visible,asset+" equipped hands visible independently of form")
   _check(mesh.mesh.get_surface_count()==original.mesh.get_surface_count(),asset+" native weapon surfaces")
   for surface in original.mesh.get_surface_count():
    var a=original.mesh.surface_get_arrays(surface);var b=mesh.mesh.surface_get_arrays(surface)
    for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:
     _check(a[channel]==b[channel],asset+" original geometry/weights/UV/index channel "+str(channel))
   var used={}
   for surface in original.mesh.get_surface_count():
    var arrays=original.mesh.surface_get_arrays(surface)
    for influence in arrays[Mesh.ARRAY_WEIGHTS].size():
     if arrays[Mesh.ARRAY_WEIGHTS][influence]>.00001:used[int(arrays[Mesh.ARRAY_BONES][influence])]=true
   for bind in used:
    var source_name=original.skin.get_bind_name(bind)
    if str(source_name).is_empty():source_name=src_skel.get_bone_name(original.skin.get_bind_bone(bind))
    _check(mesh.skin.get_bind_name(bind)==source_name,asset+" original bind ordering/name")
    _check(mesh.skin.get_bind_pose(bind).is_equal_approx(original.skin.get_bind_pose(bind)),asset+" original inverse bind unchanged")
  output.append({"appearance":asset,"bodyBonesUnchanged":old_skel.get_bone_count(),"originalNodesPromoted":original_nodes.size(),"fullClipFramesCompared":frames,"maxOriginalBodyGlobalPositionError":max_origin_error,"maxOriginalEquipmentLocalPositionError":max_local_error,"originalTracksRedirected":moved})
  baseline.queue_free();repaired.queue_free();source.queue_free();await process_frame
 var result={"checks":checks,"failures":failures,"appearances":output}
 FileAccess.open("res://build/reports/shadow-knight-equipment-suite.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
