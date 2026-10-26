extends SceneTree
## Headless source-versus-actor checks; no GPU and no production mutation.
const Actor=preload("res://scripts/actor.gd")
const Profile=preload("res://scripts/sentience_profile.gd")
const NativeCombat=preload("res://scripts/sentience_combat.gd")
const CASES: Array=[ ["sword",0,"senti_sword_1"], ["sword",1,"senti_sword_2"], ["sword",2,"senti_sword_3"], ["spear",0,"senti_spear_1"], ["spear",1,"senti_spear_2"], ["chain",0,"senti_chain_1"], ["chain",1,"senti_chain_2"], ["burst",0,"senti_burst"] ]
const BODY: Array[String]=["Bip001 Pelvis","Bip001 Spine","Bip001 Spine1","Bip001 Spine2","Bip001 L UpperArm","Bip001 R UpperArm","Bip001 L Forearm","Bip001 R Forearm","Bip001 L Hand","Bip001 R Hand","Bip001 L Thigh","Bip001 R Thigh","Bip001 L Calf","Bip001 R Calf"]
const WEAPON_BONES: Dictionary={"sword":"Fuka_C6_Weapon_A","spear":"Fuka_C6_Weapon_B","chain":"Fuka_C6_Weapon_C"}
var checks:=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var samples: Array=[]
var diagnostics: Array[String]=[]
var recorder:=ErrorRecorder.new()
class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if type!=Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)
func _pose(skeleton: Skeleton3D) -> Array:
 var result: Array=[]
 for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(bone))
 return result
func _point(skeleton: Skeleton3D,name: String) -> Vector3:
 return skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin
func _world(skeleton: Skeleton3D,name: String) -> Vector3:
 return skeleton.global_transform*_point(skeleton,name)
func _nearest_hand(skeleton: Skeleton3D,name: String) -> float:
 var point:=_point(skeleton,name)
 return minf(point.distance_to(_point(skeleton,"Bip001 L Hand")),point.distance_to(_point(skeleton,"Bip001 R Hand")))
func _skin_points(actor,weapon: String) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 for mesh: MeshInstance3D in actor._weapon_nodes.get(weapon,[]):
  var skin: Skin=mesh.skin
  var transforms: Array[Transform3D]=[]
  if skin!=null:
   for bind in skin.get_bind_count():
    var bone: int=skin.get_bind_bone(bind)
    if bone<0: bone=actor.skeleton.find_bone(skin.get_bind_name(bind))
    transforms.append(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones=arrays[Mesh.ARRAY_BONES]
   var weights=arrays[Mesh.ARRAY_WEIGHTS]
   var influences: int=bones.size()/vertices.size() if bones!=null and vertices.size()>0 else 0
   for index in vertices.size():
    var point:=Vector3.ZERO
    var total:=0.0
    for influence in influences:
     var slot:=index*influences+influence
     var weight: float=weights[slot]
     if weight<=0.0: continue
     point+=(transforms[int(bones[slot])]*vertices[index])*weight
     total+=weight
    result.append(point/total if total>0.0 else mesh.global_transform*vertices[index])
 return result

func _run() -> void:
 if "--contact-sweep" in OS.get_cmdline_user_args():
  _contact_sweep()
  return
 OS.add_logger(recorder)
 var selection: Dictionary=Profile.selection()
 check(not selection.is_empty(),"final native enemy selection is available")
 if not selection.is_empty():
  var config: Dictionary=selection.actor
  check(config.prefix=="native/" and config.animationLibraryName=="native" and str(config.animationLibraryPath).ends_with("native-motions.res"),"final enemy uses native C6 library, never the old C4 adaptation")
  var library: AnimationLibrary=load(config.animationLibraryPath)
  check(library!=null and library.get_animation_list().size()==24,"complete twenty-four-clip native library is present")
  var actor=Actor.new()
  root.add_child(actor)
  actor.setup(false,selection)
  check(actor.ready_for_combat,"actual Actor accepts native presentation configuration")
  var raw: Node3D=load(config.modelPath).instantiate()
  root.add_child(raw)
  var source_skeleton: Skeleton3D=raw.find_children("*","Skeleton3D",true,false)[0]
  var source_player: AnimationPlayer=raw.find_children("*","AnimationPlayer",true,false)[0]
  source_player.add_animation_library("native",library)
  source_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var base:=_pose(source_skeleton)
  var rest_lengths: Dictionary={}
  for name: String in BODY:
   var bone:=source_skeleton.find_bone(name)
   check(bone>=0,"expected native body joint exists: "+name)
   rest_lengths[name]=source_skeleton.get_bone_rest(bone).origin.length() if bone>=0 else 0.0
  for name: String in WEAPON_BONES.values(): check(source_skeleton.find_bone(name)>=0,"original weapon anchor exists: "+name)
  completed.append("identity")
  if actor.ready_for_combat:
   for definition: Array in CASES:
    _motion(actor,config,source_skeleton,source_player,base,rest_lengths,definition)
   _locomotion(actor,config,source_skeleton,source_player,base)
  actor.free()
  raw.free()
  await process_frame
 check(samples.size()==16 and completed==["identity","senti_sword_1","senti_sword_2","senti_sword_3","senti_spear_1","senti_spear_2","senti_chain_1","senti_chain_2","senti_burst","locomotion"],"all eight motions, both facings and locomotion completed")
 check(recorder.errors.is_empty(),"no hidden engine or script errors")
 var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"completed":completed,"samples":samples,"diagnostics":diagnostics}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/sentience-native-asset-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"sentience_native_asset","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size(),"samples":samples.size(),"diagnostics":diagnostics}))
 quit(0 if failures.is_empty() else 1)

func _raw_sample(skeleton: Skeleton3D,player: AnimationPlayer,base: Array,clip: String,time: float) -> void:
 for bone in base.size(): skeleton.set_bone_pose(bone,base[bone])
 player.play(clip)
 player.seek(time,true)
 player.advance(0.0)
 skeleton.force_update_all_bone_transforms()

func _motion(actor,config: Dictionary,source: Skeleton3D,player: AnimationPlayer,base: Array,lengths: Dictionary,definition: Array) -> void:
 var weapon: String=definition[0]
 var key: String=definition[2]
 check(config.motions.has(key),"native combat has explicit configured source: "+key)
 if not config.motions.has(key): return
 var motion: Dictionary=config.motions[key]
 var clip: String="native/"+str(motion.clip)
 check(player.has_animation(clip) and not str(motion.clip).begins_with("JW_"),"attack binds a real C6 clip without C4 fallback: "+key)
 if not player.has_animation(clip): return
 var attack: Dictionary=NativeCombat.attack(weapon,int(definition[1]),true,2,weapon=="burst")
 var contact: float=motion.get("contact",-1.0)
 check(contact>0.0 and contact<=float(motion.end),"source contact is inside configured native motion: "+key)
 var reference: Array=[]
 var changed: Dictionary={}
 var max_length_error:=0.0
 var start: float=motion.get("start",0.0)
 for t in [start,lerpf(start,contact,0.5),contact,lerpf(contact,float(motion.end),0.8)]:
  _raw_sample(source,player,base,clip,float(t))
  for name: String in BODY:
   var bone:=source.find_bone(name)
   var rotation:=source.get_bone_pose_rotation(bone)
   if reference.size()<BODY.size(): reference.append(rotation)
   elif reference[BODY.find(name)].angle_to(rotation)>0.03: changed[name]=true
   max_length_error=maxf(max_length_error,absf(source.get_bone_pose_position(bone).length()-float(lengths[name])))
 check(changed.size()>=6,"native clip drives torso and limbs, not only hair/weapon tracks: "+key)
 check(max_length_error<0.002,"native body bone lengths remain stable: "+key)
 for facing in [-1.0,1.0]:
  actor.reset_presentation()
  var f: Dictionary={"id":"native_foe","side":"enemy","state":"attack","stateTime":0.0,"x":1.3,"facing":facing,"attack":attack}
  var max_hand_error:=0.0
  var max_root_error:=0.0
  var contact_reach:=0.0
  var contact_band_reach:=0.0
  var min_weapon_y:=INF
  var max_weapon_y:=-INF
  var contact_near_hand:=0.0
  var vertices:=0
  for t in [0.0,float(attack.windup)*0.5,float(attack.windup),float(attack.windup)+0.04,float(attack.duration)*0.9]:
   f.stateTime=float(t)
   actor.animate_fighter(f,0.10,float(t))
   actor.skeleton.force_update_all_bone_transforms()
   _raw_sample(source,player,base,clip,actor.source_time)
   var root_position: Vector3=actor.skeleton.get_bone_pose_position(actor._root_bone)
   max_root_error=maxf(max_root_error,Vector2(root_position.x-actor._root_origin.x,root_position.z-actor._root_origin.z).length())
   for bone_name: String in WEAPON_BONES.values():
    var expected:=_nearest_hand(source,bone_name)
    var actual:=_nearest_hand(actor.skeleton,bone_name)
    # Ignore the short startup blend, where body bones intentionally blend
    # from idle while original weapon tracks are still entering the strike.
    if float(t)>=float(attack.windup)*0.5: max_hand_error=maxf(max_hand_error,absf(actual-expected))
   if is_equal_approx(float(t),float(attack.windup)):
    check(is_equal_approx(actor.source_time,contact),"actual attack windup samples its precise source contact: "+key)
    if weapon in WEAPON_BONES: check(actor._weapon_kind==weapon,"weapon is actually visible at its damage contact: "+key)
    var points:=_skin_points(actor,weapon)
    vertices=points.size()
    contact_near_hand=INF
    for point in points:
     contact_reach=maxf(contact_reach,(point.x-float(f.x))*facing)
     min_weapon_y=minf(min_weapon_y,point.y)
     max_weapon_y=maxf(max_weapon_y,point.y)
     if absf(point.y-float(attack.get("contactHeight",1.3)))<=0.40:
      contact_band_reach=maxf(contact_band_reach,(point.x-float(f.x))*facing)
     contact_near_hand=minf(contact_near_hand,minf(point.distance_to(_world(actor.skeleton,"Bip001 L Hand")),point.distance_to(_world(actor.skeleton,"Bip001 R Hand"))))
    if points.is_empty(): contact_near_hand=0.0
   for bone in actor.skeleton.get_bone_count():
    var transform: Transform3D=actor.skeleton.get_bone_global_pose(bone)
    check(transform.origin.is_finite() and transform.basis.is_finite(),"finite sampled pose: "+key+"/"+str(bone))
  check(max_root_error<0.00001,"combat-plane root lock remains stationary: "+key)
  check(max_hand_error<0.005,"root lock preserves source weapon-to-hand distances: "+key)
  var expected_weapon: String=str(motion.get("weapon","")) if actor.source_time>=float(motion.get("weaponStart",0.0)) and actor.source_time<=float(motion.get("weaponEnd",motion.end)) else ""
  check(actor._weapon_kind==expected_weapon,"visible weapon follows the source draw/recovery window: "+key)
  if weapon in WEAPON_BONES: check(vertices>0,"native weapon has real skinned geometry at contact: "+key)
  var frozen:=_pose(actor.skeleton)
  var snapshot: Dictionary=actor.presentation_snapshot()
  for index in 5: actor.animate_fighter(f,0.0,100.0+index)
  check(_pose(actor.skeleton)==frozen and actor.presentation_snapshot()==snapshot,"pause preserves native body and weapon transforms: "+key)
  samples.append({"motion":key,"clip":clip,"facing":facing,"contactSourceTime":contact,"combatWindup":attack.windup,"combatRange":attack.range,"contactHeight":attack.get("contactHeight",1.3),"weaponReachAtContact":contact_reach,"weaponReachInContactBand":contact_band_reach,"weaponYMin":min_weapon_y if is_finite(min_weapon_y) else null,"weaponYMax":max_weapon_y if is_finite(max_weapon_y) else null,"nearestWeaponVertexToHand":contact_near_hand,"weaponVertices":vertices,"sourceHandDistanceError":max_hand_error,"rootXZError":max_root_error,"bodyRotationsChanging":changed.size(),"boneLengthError":max_length_error})
  if weapon in WEAPON_BONES and contact_reach<float(attack.range)-0.8: diagnostics.append("%s facing %+.0f: weapon reach %.2fm versus range %.2fm"%[key,facing,contact_reach,float(attack.range)])
  if weapon in WEAPON_BONES and contact_band_reach<float(attack.range)-0.8: diagnostics.append("%s facing %+.0f: contact-height reach %.2fm versus range %.2fm"%[key,facing,contact_band_reach,float(attack.range)])
 completed.append(key)

func _locomotion(actor,config: Dictionary,source: Skeleton3D,player: AnimationPlayer,base: Array) -> void:
 for key: String in ["idle","move","dodge","dodgeBack","stagger","dead"]:
  actor.reset_presentation()
  var f: Dictionary={"side":"enemy","state":key if key!="dodgeBack" else "dodge","stateTime":0.0,"stateDuration":1.0,"x":-2.0,"facing":1.0,"dodgeDirection":-1.0 if key=="dodgeBack" else 1.0}
  for t in [0.1,0.3,0.6]:
   f.stateTime=t
   actor.animate_fighter(f,0.15,t)
   _raw_sample(source,player,base,"native/"+str(config.motions[key].clip),actor.source_time)
   var root_position: Vector3=actor.skeleton.get_bone_pose_position(actor._root_bone)
   check(is_equal_approx(root_position.x,actor._root_origin.x) and is_equal_approx(root_position.z,actor._root_origin.z),"locomotion/root motion is locked in combat plane: "+key)
   check(actor._weapon_kind.is_empty(),"weapons remain hidden outside weapon attacks: "+key)
   for name: String in WEAPON_BONES.values():
    check(absf(_nearest_hand(actor.skeleton,name)-_nearest_hand(source,name))<0.005,"root locking cannot leave independent weapon translation behind: "+key+"/"+name)
 completed.append("locomotion")

func _contact_sweep() -> void:
 OS.add_logger(recorder)
 var selection: Dictionary=Profile.selection()
 var actor=Actor.new()
 root.add_child(actor)
 actor.setup(false,selection)
 var boss_mode: bool="--boss" in OS.get_cmdline_user_args()
 var chain_only: bool="--chain-only" in OS.get_cmdline_user_args()
 if boss_mode: actor.set_enemy_style(Color.WHITE,true)
 var report: Dictionary={"cases":[],"errors":[],"band":[1.0,1.9]}
 var hz:=120.0 if "--dense" in OS.get_cmdline_user_args() else 30.0
 for definition: Array in CASES:
  var weapon: String=definition[0]
  if not weapon in WEAPON_BONES: continue
  if chain_only and weapon!="chain": continue
  var key: String=definition[2]
  var motion: Dictionary=selection.actor.motions[key]
  var attack: Dictionary=NativeCombat.attack(weapon,int(definition[1]),true,2)
  var rows: Array=[]
  for facing in [-1.0,1.0]:
   actor.reset_presentation()
   var f: Dictionary={"side":"enemy","state":"attack","stateTime":0.0,"x":0.0,"facing":facing,"attack":attack}
   for index in ceili(minf(float(motion.end),float(motion.get("weaponEnd",motion.end)))*hz)+1:
    var source: float=index/hz
    var start: float=motion.get("start",0.0)
    if source<maxf(start,float(motion.get("weaponStart",0.0))): continue
    var contact: float=motion.contact
    var clock: float=float(attack.windup)*(source-start)/(contact-start) if source<=contact else float(attack.windup)+(float(attack.duration)-float(attack.windup))*(source-contact)/(float(motion.end)-contact)
    f.stateTime=clock
    actor.animate_fighter(f,0.2,clock)
    actor.skeleton.force_update_all_bone_transforms()
    var points:=_skin_points(actor,weapon)
    var reach:=-INF
    var height:=0.0
    var chest_reach:=-INF
    var plane_reach:=-INF
    var chest_count:=0
    var near_hand:=INF
    for point in points:
     var forward: float=point.x*facing
     if forward>reach:
      reach=forward
      height=point.y
     if point.y>=1.0 and point.y<=1.9:
      chest_reach=maxf(chest_reach,forward)
      chest_count+=1
      if absf(point.z)<0.8: plane_reach=maxf(plane_reach,forward)
     near_hand=minf(near_hand,minf(point.distance_to(_world(actor.skeleton,"Bip001 L Hand")),point.distance_to(_world(actor.skeleton,"Bip001 R Hand"))))
    rows.append({"time":source,"facing":facing,"reach":reach,"farthestY":height,"chestReach":chest_reach if chest_count>0 else null,"planeChestReach":plane_reach if is_finite(plane_reach) else null,"chestVertices":chest_count,"nearestHand":near_hand})
  report.cases.append({"motion":key,"clip":motion.clip,"oldContact":motion.contact,"range":attack.range,"rows":rows})
 actor.free()
 report.errors=recorder.errors
 var output: String="res://build/reports/sentience-contact-sweep-dense.json" if hz>30.0 else "res://build/reports/sentience-contact-sweep.json"
 if chain_only: output="res://build/reports/sentience-contact-chain%s.json"%("-boss" if boss_mode else "")
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"sentience_contact_sweep","cases":report.cases.size(),"errors":report.errors.size(),"report":output}))
 quit(0 if recorder.errors.is_empty() else 1)
