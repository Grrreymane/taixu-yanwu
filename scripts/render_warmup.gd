extends Node
## Compatibility compiles shader variants only after a real visible draw.
## Use the gameplay viewport behind the loading cover: an offscreen viewport
## with different render settings can warm the wrong shader variants.
var geometry: Node3D
var canvas: CanvasLayer
var samples: Array[MeshInstance3D]=[]

func prepare(camera: Camera3D,effects: Node3D) -> void:
 geometry=Node3D.new()
 add_child(geometry)
 geometry.global_transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-3))
 var quad:=QuadMesh.new();quad.size=Vector2.ONE
 for shader: Shader in [effects.CARD_SHADER,effects.NATIVE_SHADER,effects.ENERGY_SHADER]:
  _sample(quad,shader)
 _sample(effects._particle_mesh(12),effects.PARTICLE_SHADER)
 var sphere:=_sample(effects.native_sphere,effects.SPHERE_SHADER)
 if sphere.mesh.get_blend_shape_count()>0:sphere.set_blend_shape_value(0,0.25)
 # Native mesh particles have vertex-color/normal layouts unlike plain quads.
 for mesh: Mesh in effects.remaining_native.meshes.values():
  _sample(mesh,effects.NATIVE_SHADER)
  _sample(mesh,effects.ENERGY_SHADER)
 # Phoenix uses a skinned StandardMaterial, a different variant from the
 # unskinned effect cards. Preserve its actual skeleton and material layout.
 var phoenix:=effects.native_phoenix.model.duplicate() as Node3D
 geometry.add_child(phoenix)
 phoenix.scale=Vector3.ONE*0.001
 for mesh: MeshInstance3D in phoenix.find_children("*","MeshInstance3D",true,false):
  mesh.visible=true
  mesh.extra_cull_margin=1000.0
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 canvas=CanvasLayer.new();canvas.layer=90;add_child(canvas)
 for shader: Shader in [preload("res://shaders/combat_focus.gdshader"),preload("res://shaders/ultimate_focus.gdshader")]:
  var panel:=ColorRect.new();panel.size=Vector2(2,2)
  panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var material:=ShaderMaterial.new();material.shader=shader;panel.material=material
  canvas.add_child(panel)

func _sample(mesh: Mesh,shader: Shader) -> MeshInstance3D:
 var instance:=MeshInstance3D.new()
 instance.mesh=mesh
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=shader
 instance.material_override=material
 geometry.add_child(instance)
 var bounds:=mesh.get_aabb()
 var scale_factor:=0.04/maxf(bounds.size.length(),0.001)
 instance.scale=Vector3.ONE*scale_factor
 instance.position=-bounds.get_center()*scale_factor
 instance.extra_cull_margin=1.0
 samples.append(instance)
 return instance

