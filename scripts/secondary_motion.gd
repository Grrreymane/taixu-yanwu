extends RefCounted
## Controlled secondary follow for the native C5_04_02 skin only.
## Bone names/lengths come from that model. Spring tuning is a project rebuild,
## not an export of the original game's cloth or collision solver.
## Call restore_base_pose() before Actor captures/transitions/seeks its animation,
## then update(simulation_delta, context) after the final body/root pose is ready.
## context: state, stateTime, facing, optional world-space velocity:Vector3 or x.
## Explicit facing is intentional: menu/cinematic camera-facing overrides must
## not be mistaken for a new physical turn every frame.
## The original prefab contains six DynamicBone components, rooted at Hair_B_02,
## Ribbon_BL/BR_01, and Skirt_B/BL/BR_02, plus a Spine2 collider. Component types
## and Transform PPtrs are verified in the adjacent extraction project at
## hi3-fuhua-extract/exports/c5-skin-04-02/secondary-motion-evidence.json.
## Their stripped field schema/solver are not reproduced here. Additional small
## fringe/front/side motions and all spring coefficients are our reconstruction.

const PREFIX := "Fuka_C5_04_02_"
const CHAINS: Array[Dictionary] = [
	{"stem":"Hair_B", "count":7, "kind":"hair"},
	{"stem":"Hair_FL", "count":3, "kind":"fringe"},
	{"stem":"Hair_L", "count":2, "kind":"fringe"},
	{"stem":"Hair_R", "count":2, "kind":"fringe"},
	{"stem":"Ribbon_BL", "count":7, "kind":"ribbon"},
	{"stem":"Ribbon_BR", "count":7, "kind":"ribbon"},
	{"stem":"Ribbon_FL", "count":2, "kind":"ribbon_short"},
	{"stem":"Ribbon_FR", "count":2, "kind":"ribbon_short"},
	{"stem":"Skirt_B", "count":6, "kind":"skirt"},
	{"stem":"Skirt_BL", "count":6, "kind":"skirt"},
	{"stem":"Skirt_BR", "count":6, "kind":"skirt"},
	{"stem":"Skirt_F", "count":4, "kind":"skirt_front"},
	{"stem":"Skirt_L", "count":6, "kind":"skirt"},
	{"stem":"Skirt_R", "count":6, "kind":"skirt"}
]

var _skeleton: Skeleton3D
var _bones: Array[Dictionary] = []
var _chain_names: Array[String] = []
var _time := 0.0
var _last_x := 0.0
var _has_x := false
var _last_facing := 0.0
var _turn_impulse := 0.0
var _reset_count := 0
var _enabled := false
var _colliders: Array[Dictionary] = []
var _contact_count := 0
var _collider_fit: Array[Dictionary] = []

func setup(skeleton: Skeleton3D, body: MeshInstance3D = null) -> bool:
	restore_base_pose()
	_skeleton = skeleton
	_bones.clear()
	_chain_names.clear()
	_colliders.clear()
	_collider_fit.clear()
	_enabled = false
	if not is_instance_valid(_skeleton): return false
	# Require this skin's actual roots, not just a generic humanoid skeleton.
	if _skeleton.find_bone(PREFIX+"Hair_B_01") < 0 or _skeleton.find_bone(PREFIX+"Skirt_B_01") < 0:
		return false
	for chain_index in CHAINS.size():
		var chain: Dictionary = CHAINS[chain_index]
		var ids: Array[int] = []
		var complete := true
		for i in int(chain.count):
			var id := _skeleton.find_bone(PREFIX+str(chain.stem)+"_%02d" % (i+1))
			if id < 0 or (i > 0 and _skeleton.get_bone_parent(id) != ids[i-1]):
				complete = false
				break
			ids.append(id)
		if not complete: continue
		_chain_names.append(str(chain.stem))
		for depth in ids.size():
			var id: int = ids[depth]
			var rest := _skeleton.get_bone_rest(id)
			var fraction := float(depth)/maxf(1.0,float(ids.size()-1))
			var tip := _skeleton.get_bone_rest(ids[depth+1]).origin if depth+1 < ids.size() else Vector3.RIGHT*maxf(0.04,rest.origin.length())
			var kind := str(chain.kind)
			var limit := lerpf(0.065,0.135,fraction)
			var frequency := lerpf(10.5,7.5,fraction)
			var idle_amount := lerpf(0.007,0.017,fraction)
			var movement_gain := lerpf(0.014,0.022,fraction)
			if kind == "hair":
				limit=lerpf(0.09,0.17,fraction); frequency=lerpf(9.5,6.5,fraction)
				idle_amount=lerpf(0.008,0.024,fraction)
			elif kind == "fringe":
				limit=lerpf(0.045,0.085,fraction); frequency=lerpf(14.0,11.5,fraction)
				idle_amount=lerpf(0.004,0.009,fraction); movement_gain*=0.42
			elif kind == "ribbon" or kind == "ribbon_short":
				limit=lerpf(0.10,0.20,fraction); frequency=lerpf(8.5,5.5,fraction)
				idle_amount=lerpf(0.009,0.028,fraction); movement_gain*=1.2
				if kind == "ribbon_short": limit*=0.65; idle_amount*=0.65
			elif kind == "skirt_front":
				limit*=0.65; idle_amount*=0.7; movement_gain*=0.65
			# Match the native attachment boundaries: these four chains start their
			# DynamicBone component on _02, so _01 stays fixed to scalp/waist.
			if depth == 0 and str(chain.stem) in ["Hair_B","Skirt_B","Skirt_BL","Skirt_BR"]:
				limit=0.0; idle_amount=0.0; movement_gain=0.0
			var hanging_root := (depth == 1 and str(chain.stem) in ["Hair_B","Skirt_B","Skirt_BL","Skirt_BR"]) or (depth == 0 and str(chain.stem) in ["Ribbon_BL","Ribbon_BR"])
			_bones.append({"id":id, "name":_skeleton.get_bone_name(id), "parent":_skeleton.get_bone_parent(id),
				"rest":rest.basis.orthonormalized().get_rotation_quaternion(), "tip":tip.normalized(),
				"base":rest.basis.orthonormalized().get_rotation_quaternion(), "length":tip.length(),
				"collision":Quaternion.IDENTITY,
				"hanging":hanging_root, "kind":kind, "global_rest":_skeleton.get_bone_global_rest(id).basis.orthonormalized().get_rotation_quaternion(),
				"hang":Quaternion.IDENTITY,"hang_limit":0.98 if kind=="hair" else 0.80 if kind=="skirt" else 0.85,
				"depth":fraction, "phase":float(chain_index)*1.73-float(depth)*0.72,
				"limit":limit, "frequency":frequency, "idle":idle_amount, "movement":movement_gain,
				"angle":Vector3.ZERO, "velocity":Vector3.ZERO, "cached":rest.basis.orthonormalized().get_rotation_quaternion(),
				"anchor_valid":false, "anchor_q":Quaternion.IDENTITY, "anchor_position":Vector3.ZERO})
	_enabled = not _bones.is_empty()
	# Collider sizes are reconstructed for this outfit, in its native skeleton
	# units. They follow the animated body; no collision bone enters the skin.
	for pair in [["Bip001 Spine","Bip001 Neck",0.095,"body"],
		["Bip001 L Thigh","Bip001 L Calf",0.070,"leg"],
		["Bip001 R Thigh","Bip001 R Calf",0.070,"leg"],
		["Bip001 L Calf","Bip001 L Foot",0.052,"leg"],
		["Bip001 R Calf","Bip001 R Foot",0.052,"leg"]]:
		var from := _skeleton.find_bone(str(pair[0]))
		var to := _skeleton.find_bone(str(pair[1]))
		if from>=0 and to>=0: _colliders.append({"from":from,"to":to,"radius":float(pair[2]),"kind":str(pair[3])})
	_fit_leg_colliders(body)
	reset()
	return _enabled

func _fit_leg_colliders(body: MeshInstance3D) -> void:
	if body==null or body.mesh==null or body.skin==null: return
	# The original outfit has wide trousers. The former generic naked-leg
	# radii (.070/.052) let that real blue mesh pierce the white front panel.
	# Measure the actual native bind vertices in skeleton units; this changes
	# only the collision envelope, never the source mesh, weights or body pose.
	var bind_bones: Array[int]=[]
	var transforms: Array[Transform3D]=[]
	for bind in body.skin.get_bind_count():
		var id:=body.skin.get_bind_bone(bind)
		if id<0:id=_skeleton.find_bone(body.skin.get_bind_name(bind))
		if id<0:return
		bind_bones.append(id)
		transforms.append(_skeleton.get_bone_global_rest(id)*body.skin.get_bind_pose(bind))
	var fitted: Dictionary={}
	for collider: Dictionary in _colliders:
		if collider.kind!="leg":continue
		var a:=_skeleton.get_bone_global_rest(int(collider.from)).origin
		var b:=_skeleton.get_bone_global_rest(int(collider.to)).origin
		fitted[int(collider.from)]={"a":a,"axis":b-a,"radius":0.0,"samples":0}
	for surface in body.mesh.get_surface_count():
		var arrays:=body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones=arrays[Mesh.ARRAY_BONES]
		var weights=arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones==null or weights==null:continue
		var stride:int=bones.size()/vertices.size()
		for vertex in vertices.size():
			var owner:=-1;var largest:=0.0;var point:=Vector3.ZERO
			for slot in stride:
				var index:int=vertex*stride+slot
				var weight:float=weights[index]
				if weight<=0.0:continue
				var bind:int=bones[index]
				point+=(transforms[bind]*vertices[vertex])*weight
				if weight>largest:largest=weight;owner=bind_bones[bind]
			if not fitted.has(owner):continue
			var fit:Dictionary=fitted[owner]
			var axis:Vector3=fit.axis
			var fraction:float=(point-(fit.a as Vector3)).dot(axis)/maxf(axis.length_squared(),0.000001)
			# Omit the joints where pelvis/foot blending crosses the neighboring
			# capsule. Keep every trouser surface vertex along the limb itself.
			if fraction<0.05 or fraction>0.95:continue
			fit.radius=maxf(float(fit.radius),point.distance_to((fit.a as Vector3)+axis*fraction))
			fit.samples=int(fit.samples)+1
	for collider:Dictionary in _colliders:
		if collider.kind!="leg":continue
		var fit:Dictionary=fitted[int(collider.from)]
		if int(fit.samples)==0:continue
		collider.radius=maxf(float(collider.radius),float(fit.radius))
		_collider_fit.append({"bone":_skeleton.get_bone_name(int(collider.from)),"radius":collider.radius,"samples":fit.samples})

func restore_base_pose() -> void:
	if not is_instance_valid(_skeleton): return
	for bone: Dictionary in _bones:
		_skeleton.set_bone_pose_rotation(int(bone.id),bone.base)

func reset() -> void:
	restore_base_pose()
	_time = 0.0
	_has_x = false
	_last_x = 0.0
	_last_facing = 0.0
	_turn_impulse = 0.0
	_contact_count = 0
	_reset_count += 1
	for bone: Dictionary in _bones:
		bone.angle=Vector3.ZERO
		bone.velocity=Vector3.ZERO
		bone.cached=bone.rest
		bone.base=bone.rest
		bone.collision=Quaternion.IDENTITY
		bone.hang=Quaternion.IDENTITY
		bone.anchor_valid=false
		bone.anchor_q=Quaternion.IDENTITY
		bone.anchor_position=Vector3.ZERO
	restore_base_pose()

func update(delta: float, context: Dictionary = {}) -> void:
	if not _enabled or not is_instance_valid(_skeleton): return
	if delta <= 0.0 or not is_finite(delta):
		_apply_cached()
		return
	# Preserve the incoming native animation, rather than overriding every
	# auxiliary bone with rest. Recognize our own cached result if the caller
	# omitted restore_base_pose(), so offsets never feed back into themselves.
	for bone: Dictionary in _bones:
		var incoming := _skeleton.get_bone_pose_rotation(int(bone.id))
		if not incoming.is_equal_approx(bone.cached): bone.base=incoming
		_skeleton.set_bone_pose_rotation(int(bone.id),bone.base)
	var step := minf(delta,1.0/15.0)
	var facing := -1.0 if float(context.get("facing",1.0)) < 0.0 else 1.0
	var turned := _last_facing != 0.0 and facing != _last_facing
	var teleported := bool(context.get("teleport",false)) or delta > 0.25
	if context.has("x") and _has_x and absf(float(context.x)-_last_x)>1.25:
		teleported=true
	if turned:
		_turn_impulse=facing*0.9
		for bone: Dictionary in _bones: bone.anchor_valid=false
	if teleported:
		# A reset/reposition is not a fast physical movement.
		for bone: Dictionary in _bones:
			bone.angle=Vector3.ZERO; bone.velocity=Vector3.ZERO; bone.anchor_valid=false
			bone.hang=Quaternion.IDENTITY
			bone.collision=Quaternion.IDENTITY
		_turn_impulse=0.0
	_last_facing=facing
	var world_velocity := Vector3.ZERO
	if context.get("velocity") is Vector3:
		world_velocity=context.velocity
	elif context.has("x") and _has_x and not teleported:
		world_velocity.x=(float(context.x)-_last_x)/delta
	if context.has("x"):
		_last_x=float(context.x); _has_x=true
	if not world_velocity.is_finite(): world_velocity=Vector3.ZERO
	world_velocity=world_velocity.limit_length(8.0)
	var model_velocity := _skeleton.global_basis.orthonormalized().inverse()*world_velocity
	var speed := clampf(world_velocity.length()/3.0,0.0,1.0)
	var state := str(context.get("state","idle"))
	if state in ["move","run"]: speed=maxf(speed,0.45)
	_time += step
	_turn_impulse*=exp(-step*6.0)
	# Read every animated anchor before changing any secondary bone. This avoids
	# feeding our previous spring result back into native body acceleration.
	var anchors: Array[Transform3D] = []
	for bone: Dictionary in _bones:
		anchors.append(_skeleton.get_bone_global_pose(int(bone.id)))
	for index in _bones.size():
		var bone: Dictionary = _bones[index]
		var anchor: Transform3D = anchors[index]
		var basis := anchor.basis.orthonormalized()
		var q := basis.get_rotation_quaternion()
		var angular := Vector3.ZERO
		var anchor_velocity := Vector3.ZERO
		if bool(bone.anchor_valid):
			var change: Quaternion = (q*(bone.anchor_q as Quaternion).inverse()).normalized()
			if change.w < 0.0: change=-change
			var angle := change.get_angle()
			if angle > 0.00001: angular=change.get_axis()*minf(angle/step,6.0)
			anchor_velocity=((anchor.origin-(bone.anchor_position as Vector3))/step).limit_length(2.0)
		bone.anchor_q=q; bone.anchor_position=anchor.origin; bone.anchor_valid=true
		var local_flow := basis.inverse()*(-model_velocity*float(bone.movement)-anchor_velocity*0.03)
		local_flow += basis.inverse()*Vector3(_turn_impulse*0.045,0.0,_turn_impulse*0.035)
		var goal: Vector3 = (bone.tip as Vector3).cross(local_flow)
		goal -= basis.inverse()*angular*lerpf(0.014,0.024,float(bone.depth))
		var phase := float(bone.phase)
		# Low-amplitude asymmetrical breathing/wind and a quicker running ripple.
		goal += Vector3(0.0,sin(_time*1.8+phase),cos(_time*1.37+phase*0.8)*0.55)*float(bone.idle)
		goal += Vector3(0.0,sin(_time*8.8+phase)*0.8,cos(_time*8.8+phase))*speed*lerpf(0.008,0.026,float(bone.depth))
		goal=goal.limit_length(float(bone.limit)*0.85)
		var angle_vector: Vector3 = bone.angle
		var velocity: Vector3 = bone.velocity
		var frequency := float(bone.frequency)
		var slices := maxi(1,int(ceil(step*120.0)))
		var h := step/float(slices)
		for ignored in slices:
			velocity+=(goal-angle_vector)*(frequency*frequency)*h-velocity*(1.7*frequency)*h
			velocity=velocity.limit_length(2.0)
			angle_vector+=velocity*h
			if angle_vector.length()>float(bone.limit):
				angle_vector=angle_vector.limit_length(float(bone.limit))
				velocity*=0.5
		if not angle_vector.is_finite() or not velocity.is_finite():
			angle_vector=Vector3.ZERO; velocity=Vector3.ZERO
		bone.angle=angle_vector; bone.velocity=velocity
		var amount := angle_vector.length()
		var offset := Quaternion(angle_vector/amount,amount) if amount>0.000001 else Quaternion.IDENTITY
		if bool(bone.hanging):
			# Persistent leaning must not leave a long ponytail as a rigid lever.
			# At the verified DynamicBone root only, preserve animated yaw while
			# easing pitch/roll toward its original hanging orientation. Applying
			# this at every segment would multiply the correction and curl the chain.
			var rest_global: Quaternion = bone.global_rest
			var change: Quaternion = (q*rest_global.inverse()).normalized()
			var yaw := Quaternion(0.0,change.y,0.0,change.w)
			if yaw.length_squared() > 0.000001: yaw=yaw.normalized()
			else: yaw=Quaternion.IDENTITY
			var hanging_global := (yaw*rest_global).normalized()
			var target := (q.inverse()*hanging_global).normalized()
			if target.w < 0.0: target=-target
			var strength := 0.80
			if state in ["guard","stagger"]: strength=0.94 if str(bone.kind)=="hair" else 0.86
			elif state in ["move","run"]: strength=0.28
			elif state.begins_with("light") or state.begins_with("kick_") or state in ["attack","heavy","ability","ultimate","dodge","dodgeBack"]: strength=0.40
			target=Quaternion.IDENTITY.slerp(target,strength).normalized()
			var target_angle := target.get_angle()
			if target_angle > float(bone.hang_limit): target=Quaternion(target.get_axis(),float(bone.hang_limit))
			bone.hang=(bone.hang as Quaternion).slerp(target,1.0-exp(-step*8.5)).normalized()
		bone.cached=((bone.base as Quaternion)*(bone.hang as Quaternion)*offset).normalized()
	_apply_cached()
	_apply_body_clearance(step)

func _apply_body_clearance(step: float) -> void:
	_contact_count = 0
	var capsules: Array[Dictionary] = []
	for item in _colliders:
		capsules.append({"a":_skeleton.get_bone_global_pose(int(item.from)).origin,
			"b":_skeleton.get_bone_global_pose(int(item.to)).origin,"radius":item.radius,"kind":item.kind})
	# Solve in hierarchy order: a lower segment sees the corrected parent.
	# Rotate only, preserving the original weighted skin, lengths and anchors.
	for bone in _bones:
		var kind := str(bone.kind)
		if float(bone.limit)<=0.0 or kind in ["fringe","ribbon_short"]: continue
		var global := _skeleton.get_bone_global_pose(int(bone.id))
		var origin := global.origin
		var direction := global.basis.orthonormalized()*(bone.tip as Vector3)
		var length := float(bone.length)
		var endpoint := origin+direction*length
		var target := endpoint
		for capsule in capsules:
			if kind.begins_with("skirt") and capsule.kind=="body": continue
			if not kind.begins_with("skirt") and capsule.kind=="leg": continue
			for fraction: float in [0.55,1.0]:
				var sample := origin.lerp(target,fraction)
				var axis: Vector3 = capsule.b-capsule.a
				var closest: Vector3 = capsule.a+axis*clampf((sample-(capsule.a as Vector3)).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
				var outward := sample-closest
				var clearance := float(capsule.radius)+0.012
				if outward.length() >= clearance: continue
				if outward.length()<0.0001: outward=direction.cross(Vector3.UP)
				if outward.length()<0.0001: outward=Vector3.BACK
				target+=(outward.normalized()*clearance-outward)/fraction
				_contact_count+=1
		var wanted := Quaternion.IDENTITY
		if endpoint.distance_to(target)>0.00001 and target.distance_to(origin)>0.0001:
			var swing := Quaternion(direction.normalized(),(target-origin).normalized())
			var parent := int(bone.parent)
			var parent_rotation := _skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent>=0 else Quaternion.IDENTITY
			var local_target := parent_rotation.inverse()*swing*global.basis.orthonormalized().get_rotation_quaternion()
			wanted=((bone.cached as Quaternion).inverse()*local_target).normalized()
			if wanted.w<0.0: wanted=-wanted
			var limit := 0.64 if kind.begins_with("skirt") else 0.38
			if wanted.get_angle()>limit: wanted=Quaternion(wanted.get_axis(),limit)
		bone.collision=(bone.collision as Quaternion).slerp(wanted,1.0-exp(-step*28.0)).normalized()
		bone.cached=((bone.cached as Quaternion)*(bone.collision as Quaternion)).normalized()
		_skeleton.set_bone_pose_rotation(int(bone.id),bone.cached)

func apply_native_contacts(delta: float, entering: bool = false) -> void:
	# Dialogue retains the complete source performance. Only the outfit's
	# original attachment bones resolve body contact, with no wind, breathing,
	# hanging-pose preference, body turn or gesture overlay.
	if not _enabled or not is_instance_valid(_skeleton):return
	if delta<=0.0 and not entering:
		_apply_cached()
		return
	for bone:Dictionary in _bones:
		bone.base=_skeleton.get_bone_pose_rotation(int(bone.id))
		bone.cached=bone.base
	_apply_body_clearance(1.0 if entering else minf(delta,1.0/15.0))

func _apply_cached() -> void:
	for bone: Dictionary in _bones:
		_skeleton.set_bone_pose_rotation(int(bone.id),bone.cached)

func snapshot() -> Dictionary:
	var maximum := 0.0
	var maximum_velocity := 0.0
	var maximum_hang := 0.0
	var hanging_roots: Array[String] = []
	var names: Array[String] = []
	for bone: Dictionary in _bones:
		maximum=maxf(maximum,(bone.angle as Vector3).length())
		maximum_velocity=maxf(maximum_velocity,(bone.velocity as Vector3).length())
		maximum_hang=maxf(maximum_hang,(bone.hang as Quaternion).get_angle())
		if bool(bone.hanging): hanging_roots.append(str(bone.name))
		names.append(str(bone.name))
	return {"enabled":_enabled,"boneCount":_bones.size(),"chainCount":_chain_names.size(),
		"time":_time,"resetCount":_reset_count,"maxAngle":maximum,"maxSpeed":maximum_velocity,
		"colliderCount":_colliders.size(),"collisionContacts":_contact_count,
		"colliderSource":"native_trouser_bind_vertices" if not _collider_fit.is_empty() else "fallback","fittedLegColliders":_collider_fit.duplicate(true),
		"maxHangAngle":maximum_hang,"hangingRoots":hanging_roots,
		"chainNames":_chain_names.duplicate(),"boneNames":names,"facing":_last_facing}
