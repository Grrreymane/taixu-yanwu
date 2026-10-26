extends SceneTree

const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Victory=preload("res://scripts/victory_presentation.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}

func _initialize() -> void: call_deferred("_run")
func _check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func _actor(skin:String):
	var actor=Actor.new();root.add_child(actor)
	actor.setup(false,Roster.resolve("fuhua","azure_empyrea",skin))
	return actor
func _find(node:Node,kind:String) -> Node:
	if node.is_class(kind): return node
	for child in node.get_children():
		var found=_find(child,kind)
		if found!=null:return found
	return null
func _penetration(actor) -> float:
	var total:=0.0
	var sk:Skeleton3D=actor.skeleton
	for bone in actor._secondary._bones:
		if not str(bone.kind).begins_with("skirt"):continue
		var tr:=sk.get_bone_global_pose(int(bone.id))
		for collider in actor._secondary._colliders:
			if collider.kind!="leg":continue
			var a:=sk.get_bone_global_pose(int(collider.from)).origin
			var b:=sk.get_bone_global_pose(int(collider.to)).origin
			var axis:=b-a
			for fraction:float in [0.55,1.0]:
				var sample:Vector3=tr.origin+tr.basis*(bone.tip as Vector3)*float(bone.length)*fraction
				var closest:=a+axis*clampf((sample-a).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
				total+=maxf(0.0,float(collider.radius)+0.012-sample.distance_to(closest))
	return total
func _run() -> void:
	var skin=_actor("taixu_memory")
	var native=load("res://assets/azure-skin/Avatar.fbx").instantiate()
	root.add_child(native)
	var original:Skeleton3D=_find(native,"Skeleton3D")
	var sk:Skeleton3D=skin.skeleton
	_check(sk.get_bone_count()==122 and sk.get_bone_count()==original.get_bone_count(),"skin keeps all 122 original bones")
	var rests:=true
	for i in sk.get_bone_count():
		var target:=original.find_bone(sk.get_bone_name(i))
		rests=rests and target>=0 and sk.get_bone_rest(i).is_equal_approx(original.get_bone_rest(target)) and sk.get_bone_parent(i)==original.get_bone_parent(target)
	_check(rests,"skin hierarchy and rest transforms exactly match its source FBX")
	var binds:=true
	for mesh:MeshInstance3D in skin.model.find_children("*","MeshInstance3D",true,false):
		var found=native.find_children(str(mesh.name),"MeshInstance3D",true,false)
		if mesh.skin==null or found.is_empty():continue
		var source:Skin=found[0].skin
		binds=binds and source!=null and mesh.skin.get_bind_count()==source.get_bind_count()
		for bind in mesh.skin.get_bind_count():
			binds=binds and mesh.skin.get_bind_pose(bind).is_equal_approx(source.get_bind_pose(bind)) and mesh.skin.get_bind_bone(bind)==source.get_bind_bone(bind)
	_check(binds,"all outfit meshes retain their original inverse bind poses and bone indices")
	native.free()
	var no_collision=_actor("taixu_memory")
	var colliders:Array=no_collision._secondary._colliders.duplicate(true)
	no_collision._secondary._colliders.clear()
	var with_depth:=0.0
	var without_depth:=0.0
	var contacts:=0
	var body_equal:=true
	for motion in ["idle","move","guard","heavy","ultimate"]:
		skin.reset_presentation();no_collision.reset_presentation()
		for frame in 90:
			var at:=float(frame+1)/60.0
			var fighter:Dictionary={"state":motion,"stateTime":at,"stateDuration":2.0,"facing":1.0,"x":0.0}
			if motion in ["heavy","ultimate"]:
				fighter.state="attack" if motion=="heavy" else "ultimate"
				fighter.attack={"name":motion,"comboIndex":0,"duration":1.5,"windup":0.7}
			skin.animate_fighter(fighter,1.0/60.0,at,at if motion=="ultimate" else -1.0)
			no_collision.animate_fighter(fighter,1.0/60.0,at,at if motion=="ultimate" else -1.0)
			with_depth+=_penetration(skin)
			no_collision._secondary._colliders.assign(colliders)
			without_depth+=_penetration(no_collision)
			no_collision._secondary._colliders.clear()
			contacts+=int(skin._secondary.snapshot().collisionContacts)
			for i in sk.get_bone_count():
				if str(sk.get_bone_name(i)).begins_with("Bip001"):
					body_equal=body_equal and sk.get_bone_pose(i).is_equal_approx(no_collision.skeleton.get_bone_pose(i))
	_check(body_equal,"cloth contacts never alter animated body or attack contact bones")
	_check(contacts>0,"native skirt chains encounter moving leg colliders")
	_check(with_depth<without_depth*0.9,"body avoidance reduces sampled skirt/leg intersections by at least ten percent")
	metrics={"penetrationWithClearance":with_depth,"penetrationWithoutClearance":without_depth,"contacts":contacts}
	no_collision.free()
	# A future source clip may animate cloth; the secondary layer must preserve
	# that input instead of snapping it back to the imported rest transform.
	skin.reset_presentation()
	var bone:Dictionary=skin._secondary._bones[2]
	var authored:Quaternion=(bone.rest as Quaternion)*Quaternion(Vector3.RIGHT,0.12)
	sk.set_bone_pose_rotation(int(bone.id),authored)
	skin._secondary.update(1.0/60.0,{"state":"idle"})
	skin._secondary.restore_base_pose()
	_check(sk.get_bone_pose_rotation(int(bone.id)).is_equal_approx(authored),"secondary restore preserves an authored auxiliary-bone input")
	skin.free()
	for appearance in ["default","taixu_memory"]:
		var actor=_actor(appearance)
		_check(actor._victory_props.size()==1 and not actor._victory_props[0].visible,appearance+" umbrella is hidden in combat")
		actor.animate_victory(3.199)
		var canopy:int=actor.skeleton.find_bone("Dummy001")
		var canopy_endpoint:Vector3=actor.skeleton.get_bone_pose_position(canopy)
		actor.animate_victory(3.2)
		_check(canopy_endpoint.distance_to(actor.skeleton.get_bone_pose_position(canopy))<0.0001,appearance+" unkeyed canopy position continues from Victory endpoint into Idle")
		actor.reset_presentation()
		var minimum_face_dot:=1.0
		for frame in 265:
			var at:=float(frame)/60.0
			actor.animate_victory(at)
			var shot:=Victory.frame(at,16.0/9.0,"azure_empyrea")
			var delta_basis:Basis=actor.skeleton.get_bone_global_pose(actor._head_bone).basis.orthonormalized()*actor._head_initial_basis.inverse()
			var front:=delta_basis*Vector3.BACK
			front.y=0;front=front.normalized()
			var toward:Vector3=shot.position
			toward.y=0;toward=toward.normalized()
			minimum_face_dot=minf(minimum_face_dot,front.dot(toward))
		_check(actor._victory_props[0].visible,appearance+" victory restores the source skinned umbrella")
		_check(minimum_face_dot>0.40,appearance+" orbit keeps the native turn and face visible throughout")
		metrics[appearance+"MinimumFaceCameraDot"]=minimum_face_dot
		actor.reset_presentation()
		_check(not actor._victory_props[0].visible,appearance+" leaving victory clears the prop")
		actor.free()
	var report={"suite":"skin_victory_repair","checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":metrics}
	var file=FileAccess.open("res://build/reports/skin-victory-repair.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
