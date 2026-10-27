extends SceneTree
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
func _initialize():call_deferred("_run")
func _vec(v:Vector3)->Array:return [v.x,v.y,v.z]
func _run():
 var report=[];var failures=[];var checks=0
 var before="--before" in OS.get_cmdline_user_args()
 for appearance in ["default","blood_moon"]:
  var config=Roster.resolve("fuhua","shadow_knight",appearance)
  if before:config.actor.modelPath="../hi3-fuhua-extract/exports/c2-arm-repair/godot-stage/assets/"+("shadow-knight/Avatar_Fuka_C2_NL.scn" if appearance=="default" else "shadow-knight-blood-moon/Avatar_Fuka_C2_04_01.scn")
  var actor=Actor.new();root.add_child(actor);actor.setup(false,config)
  var skel=actor.skeleton
  for burst in [false,true]:
   actor._set_native_form(burst)
   for sample in [["StandBy",0.0],["A1",.1],["NL_C1_1_Ultra",.416667]]:
    actor._restore_source_pose();actor.animation_player.play("Avatar_Fuka_Ani_"+sample[0]);actor.animation_player.seek(sample[1],true);actor.animation_player.advance(0.0)
    var row={"appearance":appearance,"burst":burst,"clip":sample[0],"time":sample[1],"surfaces":[],"arms":{}}
    var arm_tris={"L":[],"R":[]};var all_arm_tris={"L":[],"R":[]}
    for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
     if mesh.skin==null:continue
     var transforms=[];var bone_names=[]
     for bind in mesh.skin.get_bind_count():
      var bone=mesh.skin.get_bind_bone(bind)
      if bone<0:bone=skel.find_bone(mesh.skin.get_bind_name(bind))
      bone_names.append(str(skel.get_bone_name(bone)))
      transforms.append(skel.global_transform*skel.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
     for surface in mesh.mesh.get_surface_count():
      var key=str(mesh.name).to_lower()+":"+str(surface)
      var visible=mesh.visible and not key in actor._visual.hiddenSurfaces
      var arrays=mesh.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
      var stride=arrays[Mesh.ARRAY_BONES].size()/vertices.size()
      var points=[];var sides=[];var weights_by_bone={}
      for i in vertices.size():
       var p=Vector3.ZERO;var arm_weights={"L":0.0,"R":0.0}
       for k in stride:
        var slot=i*stride+k;var weight=float(arrays[Mesh.ARRAY_WEIGHTS][slot]);var bind=int(arrays[Mesh.ARRAY_BONES][slot]);var bone_name=bone_names[bind]
        if weight<=0.0:continue
        p+=(transforms[bind]*vertices[i])*weight
        weights_by_bone[bone_name]=float(weights_by_bone.get(bone_name,0.0))+weight
        for side in ["L","R"]:
         if bone_name.begins_with("Bip001 "+side+" ") and ("Forearm" in bone_name or "ForeTwist" in bone_name or "Hand" in bone_name or "Finger" in bone_name):arm_weights[side]+=weight
       points.append(p);sides.append(arm_weights)
      var counts={"L":0,"R":0}
      for i in range(0,indices.size(),3):
       var a=int(indices[i]);var b=int(indices[i+1]);var c=int(indices[i+2])
       for side in ["L","R"]:
        if maxf(sides[a][side],maxf(sides[b][side],sides[c][side]))>=.2:
         var tri=[points[a],points[b],points[c],key];counts[side]+=1;all_arm_tris[side].append(tri)
         if visible:arm_tris[side].append(tri)
      if counts.L+counts.R>0:
       row.surfaces.append({"slot":key,"visible":visible,"forearmHandTriangles":counts,"weightedBones":weights_by_bone})
    for side in ["L","R"]:
     var elbow=skel.global_transform*skel.get_bone_global_pose(skel.find_bone("Bip001 "+side+" Forearm")).origin
     var wrist=skel.global_transform*skel.get_bone_global_pose(skel.find_bone("Bip001 "+side+" Hand")).origin
     var axis=(wrist-elbow).normalized();var u=axis.cross(Vector3.UP).normalized()
     if u.length()<.5:u=axis.cross(Vector3.RIGHT).normalized()
     var v=axis.cross(u).normalized();var cuts=[]
     for fraction in [.15,.35,.55,.75,.90]:
      var center=elbow.lerp(wrist,fraction);var filled=0;var filled_all=0;var slots={};var min_radius=INF;var max_radius=0.0
      for ray in 24:
       var angle=TAU*ray/24.0;var direction=u*cos(angle)+v*sin(angle)
       var hit=false;var hit_all=false
       for tri in all_arm_tris[side]:
        var point=Geometry3D.ray_intersects_triangle(center,direction,tri[0],tri[1],tri[2])
        if point==null:continue
        var radius=center.distance_to(point)
        if radius>.30:continue
        hit_all=true
       for tri in arm_tris[side]:
        var point=Geometry3D.ray_intersects_triangle(center,direction,tri[0],tri[1],tri[2])
        if point==null:continue
        var radius=center.distance_to(point)
        if radius>.30:continue
        hit=true;slots[tri[3]]=true;min_radius=minf(min_radius,radius);max_radius=maxf(max_radius,radius)
       if hit:filled+=1
       if hit_all:filled_all+=1
      checks+=1
      if not before and filled!=24:failures.append(appearance+" "+str(burst)+" "+sample[0]+" "+side+" "+str(fraction)+" only "+str(filled)+"/24 rays")
      cuts.append({"fraction":fraction,"actualVisibleRayHits":filled,"allGeometryRayHits":filled_all,"rays":24,"slots":slots.keys(),"minRadius":min_radius if min_radius<INF else null,"maxRadius":max_radius})
     row.arms[side]={"elbowWorld":_vec(elbow),"wristWorld":_vec(wrist),"visibleTriangles":arm_tris[side].size(),"crossSections":cuts}
    report.append(row)
  actor.queue_free()
 FileAccess.open("res://build/reports/shadow-knight-arm-geometry"+("-before" if before else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 for row in report:print(row.appearance," burst=",row.burst," ",row.clip," L=",row.arms.L.crossSections.map(func(x):return x.actualVisibleRayHits)," R=",row.arms.R.crossSections.map(func(x):return x.actualVisibleRayHits))
 print("Actual skinned arm geometry: ",checks," cross-sections; failures=",JSON.stringify(failures))
 await process_frame;quit(0 if failures.is_empty() else 1)

