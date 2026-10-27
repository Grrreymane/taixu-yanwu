extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
func _initialize():call_deferred("_run")
func _vec(v:Vector3)->Array:return [v.x,v.y,v.z]
func _run():
 var rows=[]
 for pair in [["shadow_knight","default"],["shadow_knight","blood_moon"],["night_squire","default"]]:
  var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua",pair[0],pair[1]))
  var skel=actor.skeleton
  var row={"style":pair[0],"appearance":pair[1],"modelScale":_vec(actor.model.scale),"skeletonWorldYLength":skel.global_transform.basis.y.length(),"rootOrigin":_vec(actor._root_origin),"eyes":[],"q":[]}
  for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
   if not ("eye" in str(mesh.name).to_lower() or "mouth" in str(mesh.name).to_lower()):continue
   var uv=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
   var lo=Vector2(INF,INF);var hi=Vector2(-INF,-INF)
   for p in uv:lo=lo.min(p);hi=hi.max(p)
   var mat=mesh.get_surface_override_material(0) as ShaderMaterial
   row.eyes.append({"name":str(mesh.name),"rawUvMin":[lo.x,lo.y],"rawUvMax":[hi.x,hi.y],"scale":str(mat.get_shader_parameter("uv_scale")),"offset":str(mat.get_shader_parameter("uv_offset")),"texture":mat.get_shader_parameter("albedo_texture").resource_path})
  if pair[0]=="shadow_knight":
   actor.animation_player.play("Avatar_Fuka_Ani_NL_B_Ultra")
   for t in [0.0,.2,.5,.8,1.0,1.233333,1.5,2.0,3.0]:
    actor._restore_source_pose();actor.animation_player.seek(t,true);actor.animation_player.advance(0.0)
    var r=skel.get_bone_pose_position(actor._root_bone)
    var feet=[]
    for foot in ["Bip001 L Foot","Bip001 R Foot"]:feet.append(_vec(skel.global_transform*skel.get_bone_global_pose(skel.find_bone(foot)).origin))
    row.q.append({"t":t,"rootLocal":_vec(r),"rootRiseWorld":(r.y-actor._root_origin.y)*skel.global_transform.basis.y.length(),"feetWorld":feet})
  rows.append(row);actor.queue_free()
 FileAccess.open("res://build/reports/shadow-knight-face-jump.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(JSON.stringify(rows));await process_frame;quit()
