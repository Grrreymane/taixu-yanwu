extends "res://tests/story_flow_suite.gd"
## Real Main, real dialogue actors, real camera application; no render/GPU run.
## Preferences, campaign records and music are isolated from the user's files.

class IsolatedMain extends "res://scripts/main.gd":
 func _load_fighter_choice() -> void:
  fighter=FighterRoster.resolve("fuhua","azure_empyrea","default")
  appearance_choices={}
 func _save_fighter_choice() -> void: pass

var observations: Array=[]
var max_camera_shift:=0.0
var max_zero_step_bone_shift:=0.0
var max_zero_step_bone_turn:=0.0
var speaker_changes:=0
var reveal_clicks:=0
var advance_clicks:=0
var senti_clips_seen: Dictionary={}
var _case_label:=""

func _run() -> void:
 OS.add_logger(recorder)
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1440,900)
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var world=IsolatedMain.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 world.music._player.free()
 world.music.free()
 world.music=QuietMusic.new()
 viewport.add_child(world)
 check(world.ready_to_play,"real Main initialized without persistent settings or GPU rendering")
 for selection: Array in [["azure_empyrea","default"],["azure_empyrea","taixu_memory"],["fenghuang","default"]]:
  for size: Vector2i in [Vector2i(1440,900),Vector2i(960,540)]:
   viewport.size=size
   world._action("menu")
   world._action("select_style:"+str(selection[0]))
   world._action("select_appearance:"+str(selection[1]))
   _case_label="%s/%s %dx%d" % [selection[0],selection[1],size.x,size.y]
   check(world.get_viewport().get_visible_rect().size==Vector2(size),_case_label+" camera receives the actual requested viewport size")
   check(world.fighter.styleId==selection[0] and world.fighter.appearanceId==selection[1],_case_label+" uses the requested actual model")
   world._action("start")
   check(world.story.active and world.story.actors.size()==2,_case_label+" actual opening dialogue has both actors")
   # Only full source clips run here. A click must not add a blink, a speaking
   # gesture, or a fresh sample from the beginning of either actor's clip.
   _frames(world,188,1.0/60.0)
   _native_contract(world)
   var faces_before:=_all_faces(world)
   _click_without_time(world)
   check(_all_faces(world)==faces_before,_case_label+" advancing/revealing leaves source face values unchanged")
   # Let the full original C6 Idle finish. Its single, clock-driven handoff to
   # Standby is intentional; changing a dialogue line must not cause it early.
   var transition_camera: Transform3D=world.camera.transform
   while world.story.clock<4.40: world._process(1.0/60.0)
   _native_contract(world)
   check(world.camera.transform.is_equal_approx(transition_camera),_case_label+" original Idle-to-Standby handoff leaves the camera fixed")
   check(world.story.actors.senti._last_clock==world.story.clock,_case_label+" handoff preserves whole-scene clock instead of resetting it to the new clip")
   _all_lines(world)
   _return_to_combat(world)
   if selection[0]=="azure_empyrea" and selection[1]=="default":
    _finish(world)
    check(world.campaign.phase=="reward",_case_label+" first real encounter reaches reward selection")
    world._action("reward_0")
    check(world.story.active and world.story.scene_id=="reward",_case_label+" committed reward opens its own dialogue")
    _frames(world,25,1.0/60.0)
    _all_lines(world)
    _return_to_combat(world)
   observations.append({"selection":selection,"viewport":[size.x,size.y],"storyClock":world.story.clock,"cameraFov":world.camera.fov,"performance":world.story.snapshot().performance,"facialShapeCounts":{"fuhua":world.story.actors.fuhua._story_shapes.size(),"senti":world.story.actors.senti._story_shapes.size()}})
 check(observations.size()==6 and speaker_changes>=12 and reveal_clicks>=12 and advance_clicks>=12,"all six model/viewport cases exercised reveal, advance and speaker changes")
 check(senti_clips_seen.has("native/Idle") and senti_clips_seen.has("native/Standby"),"both complete C6 source clips were actually sampled")
 world.free()
 viewport.free()
 await process_frame
 await process_frame
 await create_timer(0.12).timeout
 check(recorder.errors.is_empty() and recorder.warnings.is_empty(),"no hidden engine errors or warnings")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 var report: Dictionary={"suite":"story_camera_continuity","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"warnings":recorder.warnings,"cases":observations,"sentiClips":senti_clips_seen.keys(),"speakerChanges":speaker_changes,"revealClicks":reveal_clicks,"advanceClicks":advance_clicks,"maxClickCameraShift":max_camera_shift,"maxClickBonePositionShift":max_zero_step_bone_shift,"maxClickBoneAngle":max_zero_step_bone_turn,"scope":"Actual Main / three player appearances and C6, two viewports, complete native Idle-to-Standby sequence, unchanged source-default facial values, zero-time reveal/advance, fixed camera, focus freeze, reward and battle return; headless only."}
 FileAccess.open("res://build/reports/story-camera-continuity-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"story_camera_continuity","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size(),"warnings":recorder.warnings.size(),"speakerChanges":speaker_changes,"maxClickCameraShift":max_camera_shift,"maxClickBoneAngle":max_zero_step_bone_turn}))
 quit(0 if failures.is_empty() else 1)

func _click_without_time(world) -> void:
 var story=world.story
 var was_revealed: bool=story.revealed
 var old_index: int=story.index
 var old_speaker: String=str(story.snapshot().speaker)
 var before:=_capture(world)
 world._action("story_next")
 if was_revealed: advance_clicks+=1
 else: reveal_clicks+=1
 if not story.active: return
 check(story.clock==before.time,_case_label+" click cannot change the body presentation clock")
 check(story.index==old_index+(1 if was_revealed else 0),_case_label+" normal story_next reveal/advance semantics remain intact")
 world._process(0.0)
 var after:=_capture(world)
 max_camera_shift=maxf(max_camera_shift,Vector3(before.camera.origin).distance_to(after.camera.origin))
 check(before.camera.is_equal_approx(after.camera) and before.fov==after.fov,_case_label+" click leaves real camera position, rotation and FOV fixed")
 if old_speaker!=str(story.snapshot().speaker): speaker_changes+=1
 for identity: String in story.actors:
  var a: Dictionary=before.actors[identity]
  var b: Dictionary=after.actors[identity]
  check(a.root.is_equal_approx(b.root) and a.model.is_equal_approx(b.model) and a.sourceTime==b.sourceTime and a.sourceClip==b.sourceClip,_case_label+" "+identity+" click never resets model root or full native clip sample")
  check(a.face==b.face,_case_label+" "+identity+" speaker change cannot add a fabricated facial pose")
  var position_error:=0.0
  var angle_error:=0.0
  for bone in a.poses.size():
   position_error=maxf(position_error,Vector3(a.poses[bone].origin).distance_to(b.poses[bone].origin))
   var relative: Quaternion=a.poses[bone].basis.orthonormalized().get_rotation_quaternion().inverse()*b.poses[bone].basis.orthonormalized().get_rotation_quaternion()
   angle_error=maxf(angle_error,2.0*atan2(Vector3(relative.x,relative.y,relative.z).length(),absf(relative.w)))
  max_zero_step_bone_shift=maxf(max_zero_step_bone_shift,position_error)
  max_zero_step_bone_turn=maxf(max_zero_step_bone_turn,angle_error)
  check(position_error<0.000001 and angle_error<0.00001,_case_label+" "+identity+" no zero-time body/head pose jump on reveal or speaker change")
 # Repeated renders at zero delta must not integrate any skeletal edits.
 for frame_index in 3: world._process(0.0)
 check(_capture(world)==after,_case_label+" repeated frozen renders do not accumulate face/body/root drift")

func _all_lines(world) -> void:
 var camera: Transform3D=world.camera.transform
 var fov: float=world.camera.fov
 var countdown: float=world.stage_countdown
 var simulation: float=world.game.time
 var before_native:=_pose(world.story.actors.senti)
 var default_faces:=_all_faces(world)
 var iterations:=0
 while world.story.active and iterations<30:
  _frames(world,7,1.0/60.0)
  check(world.camera.transform.is_equal_approx(camera) and world.camera.fov==fov,_case_label+" source clip time does not move the dialogue camera")
  _native_contract(world)
  var performance: Dictionary=world.story.snapshot().performance
  for identity: String in world.story.actors:
   var actor=world.story.actors[identity]
   check(actor._last_clock==world.story.clock and actor.current_motion=="native_dialogue",_case_label+" full native clip clock remains continuous across line boundaries")
   if str(performance.get(identity,{}).get("facialMode",""))=="source_default":
    check(_face_values(actor)==default_faces[identity],_case_label+" "+identity+" source-default face has no synthetic speech or blink animation")
  _click_without_time(world)
  iterations+=1
 check(not world.story.active and iterations<30,_case_label+" all actual dialogue lines complete normally")
 check(world.game.time==simulation and world.stage_countdown==countdown,_case_label+" dialogue clicks do not advance battle or countdown")
 check(_pose(world.story.actors.senti)!=before_native,_case_label+" fixed framing still plays the original full-body animation")
 # Open the same real scene to test focused/frozen presentation separately.
 world._begin_story("intro")
 _frames(world,17,1.0/60.0)
 world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 var held:=_capture(world)
 _frames(world,8)
 check(_capture(world)==held,_case_label+" loss of focus freezes camera, body and expression clock")
 world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 world._process(1.0/60.0)
 check(world.story.clock>float(held.time),_case_label+" focus return resumes continuous presentation")
 world._action("story_skip")

func _return_to_combat(world) -> void:
 check(not world.story.active and not world.story.visible,_case_label+" finishing/skipping hides both dialogue actors and its panel")
 world._process(1.0/60.0)
 check(world.cinematic_frame.get("shot","")=="battle" and world.camera.fov==34.0,_case_label+" normal battle camera takes over after the dialogue")
 check(world.player.visible and world.hud.visible and world.stage_countdown>0.0,_case_label+" battle actors, HUD and encounter countdown resume")

func _capture(world) -> Dictionary:
 var actor_data: Dictionary={}
 var performance: Dictionary=world.story.snapshot().performance
 for identity: String in world.story.actors:
  var actor=world.story.actors[identity]
  actor_data[identity]={"root":actor.transform,"model":actor.model.transform,"sourceTime":actor.source_time,"sourceClip":performance.get(identity,{}).get("sourceClip",""),"poses":_pose(actor),"face":_face_values(actor)}
 return {"camera":world.camera.transform,"fov":world.camera.fov,"time":world.story.clock,"actors":actor_data}

func _face_values(actor) -> Dictionary:
 var values: Dictionary={}
 for item in actor._story_shapes:
  values[str(item.mesh.name)+":"+str(item.name)]=item.mesh.get_blend_shape_value(int(item.index))
 return values

func _all_faces(world) -> Dictionary:
 var faces: Dictionary={}
 for identity: String in world.story.actors: faces[identity]=_face_values(world.story.actors[identity])
 return faces

func _native_contract(world) -> void:
 var state: Dictionary=world.story.snapshot()
 check(state.revision=="user-dialogue-1",_case_label+" approved dialogue text revision remains unchanged")
 for identity: String in ["fuhua","senti"]:
  var performance: Dictionary=state.performance.get(identity,{})
  check(performance.get("mode","")=="native_full_clip",_case_label+" "+identity+" uses a full native clip")
  check(not str(performance.get("sourceClip","")).is_empty() and float(performance.get("duration",0.0))>0.0,_case_label+" "+identity+" reports a real source clip and duration")
  check(int(performance.get("skeletalEdits",-1))==0,_case_label+" "+identity+" has no additive manual bone gestures")
  check(int(performance.get("updates",0))>0 and float(performance.get("sourceTime",-1.0))>=0.0 and float(performance.get("sourceTime",0.0))<=float(performance.get("duration",0.0))+0.0001,_case_label+" "+identity+" full clip sample is in range and is being updated")
  check(not str(performance.get("facialMode","")).is_empty(),_case_label+" "+identity+" explicitly identifies native facial provenance")
  if identity=="senti":
   var opening: bool=float(state.time)<4.2333336
   var expected_clip: String="native/Idle" if opening else "native/Standby"
   var expected_time: float=float(state.time) if opening else fposmod(float(state.time)-4.2333336,2.0)
   var expected_duration: float=4.2333336 if opening else 2.0
   check(str(performance.get("sourceClip",""))==expected_clip and is_equal_approx(float(performance.get("duration",0.0)),expected_duration),_case_label+" C6 full Idle transitions to Standby only on its original end time")
   check(absf(float(performance.get("sourceTime",-1.0))-expected_time)<0.000001,_case_label+" C6 source sample follows continuous sequence time across the full-clip handoff")
   senti_clips_seen[str(performance.get("sourceClip",""))]=true
  if str(performance.get("facialMode",""))=="source_default":
   var original_face: Dictionary={}
   var actor=world.story.actors[identity]
   for item in actor._story_shapes: original_face[str(item.mesh.name)+":"+str(item.name)]=float(item.base)
   check(_face_values(actor)==original_face,_case_label+" "+identity+" keeps imported source facial defaults exactly")
