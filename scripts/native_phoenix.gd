extends Node3D
## Original JW phoenix mesh, skeleton and 1.9167s animation. Only arena placement
## and the cue offset are adapted to our existing 3.8s combat timeline.
const SCENE = preload("res://assets/vfx/phoenix-native/model/phoenix.scn")
var model: Node3D
var player: AnimationPlayer
var clock := -1.0
var start_x := 0.0
var target_x := 0.0
var facing := 1.0
func _ready() -> void:
	model=SCENE.instantiate()
	add_child(model)
	player=model.find_children("*","AnimationPlayer",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var texture: Texture2D=load("res://assets/vfx/phoenix-native/model/phoenix.png")
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture=texture
		mesh.material_override=material
	clear()
func clear() -> void:
	clock=-1.0
	visible=false
func begin(data: Dictionary) -> void:
	clock=0.0
	start_x=float(data.get("x",0.0))
	target_x=float(data.get("targetX",start_x+1.0))
	facing=1.0 if target_x>=start_x else -1.0
	player.play("Avatar_Fuka_Ani_JW_Ultra_Phoenix")
	player.seek(0.0,true)
func tick(delta: float) -> void:
	if clock<0.0 or delta<=0.0:return
	clock+=delta
	var t:=clock-0.90
	visible=t>=0.0 and t<1.916667
	if not visible:
		if t>=1.916667:clear()
		return
	# Native model root is scaled by two; fit its 9m wingspan to the duel lane.
	scale=Vector3.ONE*0.55
	rotation.y=-facing*PI/2.0
	position=Vector3(lerpf(start_x,target_x,clampf(t/1.916667,0,1)),2.2,-0.6)
	player.seek(t,true)
	for skeleton: Skeleton3D in model.find_children("*","Skeleton3D",true,false):
		skeleton.force_update_all_bone_transforms()
		# Unity's effect flies far above the original arena. Translate the whole
		# instance into our duel framing; never edit its bone animation.
		var bone:=skeleton.find_bone("Dummy_zx")
		if bone>=0:
			var anchor: Vector3=(model.global_transform.affine_inverse()*skeleton.global_transform)*skeleton.get_bone_global_pose(bone).origin
			model.position=-anchor
