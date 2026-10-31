extends Node3D
## Original JW phoenix mesh, skeleton and animation, including its vertical flight.
const SCENE = preload("res://assets/vfx/phoenix-native/model/phoenix.scn")
const Flight = preload("res://scripts/phoenix_flight.gd")
var model: Node3D
var player: AnimationPlayer
var clock := -1.0
var start_x := 0.0
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
	player.play("Avatar_Fuka_Ani_JW_Ultra_Phoenix")
	player.seek(0.0,true)
	scale=Vector3.ONE*Flight.SCALE
	rotation=Vector3.ZERO
	visible=false
func tick(delta: float, source_clock: float = -1.0) -> void:
	if clock<0.0 or delta<=0.0:return
	clock=source_clock if source_clock>=0.0 else clock+delta
	visible=Flight.active(clock)
	if not visible:
		if clock>=Flight.CONTACT:clear()
		return
	var frame:=Flight.sample(clock,start_x)
	position=frame.origin
	player.seek(frame.sourceTime,true)
	for skeleton: Skeleton3D in model.find_children("*","Skeleton3D",true,false):
		skeleton.force_update_all_bone_transforms()
