extends SceneTree
## Compare the complete presented pose against a separate untouched source
## scene evaluated by AnimationPlayer, rather than checking our own offsets.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Senti=preload("res://scripts/sentience_profile.gd")
const NativeDialogue=preload("res://scripts/dialogue_performance.gd")
var failures: Array[String]=[]
var observations: Array=[]
var checks:=0

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error(label)
func find_type(node: Node,kind: String) -> Node:
	if node.is_class(kind): return node
	for child in node.get_children():
		var found:=find_type(child,kind)
		if found!=null: return found
	return null
func pose(skeleton: Skeleton3D) -> Array:
	var result: Array=[]
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(bone))
	return result
func face(actor) -> Array:
	var result: Array=[]
	for item: Dictionary in actor._story_shapes: result.append(item.mesh.get_blend_shape_value(int(item.index)))
	result.append(actor._facial.snapshot())
	return result

func run() -> void:
	var selections: Array[Dictionary]=[]
	for character: Dictionary in Roster.list_characters():
		for style: Dictionary in Roster.list_styles(str(character.id)):
			for skin: Dictionary in Roster.list_appearances(str(character.id),str(style.id)):
				selections.append(Roster.resolve(str(character.id),str(style.id),str(skin.id)))
	selections.append(Senti.selection())
	for selection: Dictionary in selections:
		var label:=str(selection.styleId)+"/"+str(selection.appearanceId)
		var config: Dictionary=selection.actor
		var reference: Node3D=load(str(config.modelPath)).instantiate()
		root.add_child(reference)
		var skeleton: Skeleton3D=find_type(reference,"Skeleton3D")
		var player: AnimationPlayer=find_type(reference,"AnimationPlayer")
		var base:=pose(skeleton)
		var library_path:=str(config.get("animationLibraryPath",""))
		if not library_path.is_empty(): player.add_animation_library(str(config.get("animationLibraryName","adapted")),load(library_path))
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var actor=Actor.new();root.add_child(actor);actor.setup(false,selection)
		var performance=NativeDialogue.new()
		var identity: String="senti" if selection.styleId=="sentience" else "fuhua"
		var clip:=str(config.prefix)+str(config.motions.idle.clip)
		var duration:=float(config.motions.idle.end)
		player.play(clip,0.0)
		var max_position:=0.0
		var max_basis:=0.0
		var max_attachment_turn:=0.0
		var attachment_ids:Dictionary={}
		if actor._secondary_enabled:
			for entry:Dictionary in actor._secondary._bones:attachment_ids[int(entry.id)]=true
		var untouched_face: Array=[]
		# A deliberately dirty previous combat pose must not contaminate the
		# independent full clip's body, unkeyed helpers or original shape values.
		actor.animate_fighter({"state":"guard","stateTime":0.2,"x":0,"facing":1},0.05,0.2)
		for frame in 180:
			var clock:=float(frame)*0.037
			var expected_clip: String="native/Idle" if identity=="senti" and clock<4.2333336 else clip
			var expected_duration: float=4.2333336 if expected_clip=="native/Idle" else duration
			var expected_clock: float=clock-4.2333336 if identity=="senti" and expected_clip==clip else clock
			for bone in base.size(): skeleton.set_bone_pose(bone,base[bone])
			player.play(expected_clip,0.0)
			player.seek(fposmod(expected_clock,expected_duration),true);player.advance(0.0)
			performance.apply(actor,identity,{"speaker":"senti" if frame%2==0 else "fuhua","mood":"teasing"},frame,0.037,clock)
			for bone in skeleton.get_bone_count():
				var actual: Transform3D=actor.skeleton.get_bone_pose(bone)
				var expected:=skeleton.get_bone_pose(bone)
				if frame==0 and actual.origin.distance_to(expected.origin)>0.000001:
					print("SOURCE DIFF ",skeleton.get_bone_name(bone)," actual ",actual.origin," expected ",expected.origin," imported ",actor._imported_base_pose[bone].origin," reference ",base[bone].origin)
				max_position=maxf(max_position,actual.origin.distance_to(expected.origin))
				if attachment_ids.has(bone):
					var change:=expected.basis.orthonormalized().get_rotation_quaternion().inverse()*actual.basis.orthonormalized().get_rotation_quaternion()
					max_attachment_turn=maxf(max_attachment_turn,change.get_angle())
					check(actual.origin.is_equal_approx(expected.origin) and actual.basis.get_scale().is_equal_approx(expected.basis.get_scale()),label+" native attachment length and scale stay unchanged during contact")
					continue
				max_basis=maxf(max_basis,actual.basis.x.distance_to(expected.basis.x))
				max_basis=maxf(max_basis,actual.basis.y.distance_to(expected.basis.y))
				max_basis=maxf(max_basis,actual.basis.z.distance_to(expected.basis.z))
			if frame==0: untouched_face=face(actor)
			check(face(actor)==untouched_face,label+" keeps source default face without generated mouth or blink")
			var held:=pose(actor.skeleton)
			performance.apply(actor,identity,{"speaker":"fuhua","mood":"angry"},999,0.0,clock)
			check(pose(actor.skeleton)==held,label+" line change at zero time cannot edit the original pose")
		check(max_position<0.000001 and max_basis<0.000001,label+" all body/face bones strictly match independent original clip; all attachment lengths match")
		check(max_attachment_turn<=0.641,label+" contact-only attachment correction remains within existing physical swing limit")
		var state: Dictionary=performance.snapshot()[identity]
		check(state.mode=="native_full_clip" and state.skeletalEdits==0,label+" no joint overlays")
		check(actor.current_motion=="native_dialogue" and state.sourceClip==clip,label+" uses own complete source animation")
		observations.append({"actor":label,"sourceClip":clip,"duration":duration,"maxBonePositionError":max_position,"maxBodyBoneBasisError":max_basis,"maxAttachmentContactRadians":max_attachment_turn,"contactBoneCount":attachment_ids.size(),"boneCount":skeleton.get_bone_count(),"frames":180})
		actor.free();reference.free()
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	FileAccess.open("res://build/reports/dialogue-performance-suite.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations},"  "))
	print(JSON.stringify({"suite":"native_dialogue_source_equivalence","checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations}))
	quit(0 if failures.is_empty() else 1)
