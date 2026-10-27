extends SceneTree
## Read-only mesh/resource audit. No renderer, scene edits, or source writes.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const OUTPUT="res://build/reports/taixu-mesh-geometry-input.json"

func _initialize() -> void: call_deferred("_run")
func _find_body(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name).to_lower()=="body": return node
	for child in node.get_children():
		var body:=_find_body(child)
		if body!=null: return body
	return null
func _flatten(values) -> Array:
	var result: Array=[]
	if values==null: return result
	for value in values:
		if value is Vector3: result.append_array([value.x,value.y,value.z])
		elif value is Vector2: result.append_array([value.x,value.y])
		else: result.append(value)
	return result
func _mesh(mesh: Mesh) -> Array:
	var result: Array=[]
	for surface in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(surface)
		result.append({"surface":surface,"positions":_flatten(a[Mesh.ARRAY_VERTEX]),"normals":_flatten(a[Mesh.ARRAY_NORMAL]),"uv0":_flatten(a[Mesh.ARRAY_TEX_UV]),"uv2":_flatten(a[Mesh.ARRAY_TEX_UV2]),"indices":_flatten(a[Mesh.ARRAY_INDEX]),"bones":_flatten(a[Mesh.ARRAY_BONES]),"weights":_flatten(a[Mesh.ARRAY_WEIGHTS])})
	return result
func _posed(actor,body: MeshInstance3D) -> Array:
	var matrices: Array[Transform3D]=[]
	for bind in body.skin.get_bind_count():
		var bone: int=body.skin.get_bind_bone(bind)
		if bone<0: bone=actor.skeleton.find_bone(body.skin.get_bind_name(bind))
		matrices.append(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
	var result: Array=[]
	for surface in body.mesh.get_surface_count():
		var a:=body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var positions: Array=[]
		var normals: Array=[]
		var normal_data: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var width: int=bones.size()/vertices.size()
		for vertex in vertices.size():
			var position:=Vector3.ZERO
			var normal:=Vector3.ZERO
			for slot in width:
				var at: int=vertex*width+slot
				var weight: float=weights[at]
				if weight<=0.0: continue
				var matrix: Transform3D=matrices[bones[at]]
				position+=(matrix*vertices[vertex])*weight
				normal+=(matrix.basis*normal_data[vertex])*weight
			positions.append_array([position.x,position.y,position.z])
			normal=normal.normalized()
			normals.append_array([normal.x,normal.y,normal.z])
		result.append({"surface":surface,"positions":positions,"normals":normals})
	return result
func _run() -> void:
	var scene=load("res://assets/azure-skin/Avatar_Fuka_C5_04_02.scn").instantiate()
	root.add_child(scene)
	var original:=_find_body(scene)
	var native: Mesh=load("res://assets/azure-skin/native-body-uv2.res")
	var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua","azure_empyrea","taixu_memory"))
	var body:=_find_body(actor.model)
	var materials: Array=[]
	for surface in body.mesh.get_surface_count():
		var material: ShaderMaterial=body.get_active_material(surface)
		var outline: ShaderMaterial=material.next_pass
		materials.append({"surface":surface,"use_backface_uv2":material.get_shader_parameter("use_backface_uv2"),"outline_pixels":outline.get_shader_parameter("outline_pixels") if outline!=null else 0.0,"outlineShader":outline.shader.resource_path if outline!=null else ""})
	var poses: Array=[]
	for time: float in [0.0,0.6,1.2,1.8]:
		actor.reset_presentation()
		for frame in 61:
			actor.animate_fighter({"id":"player","state":"idle","stateTime":time,"x":0.0,"facing":1,"presentationYaw":-0.20,"hp":100.0},0.0 if frame==0 else 1.0/60.0,time)
		poses.append({"time":time,"surfaces":_posed(actor,body)})
	var report: Dictionary={"scope":"Headless arrays from actual on-disk mesh resources; CPU skinning for four fixed menu clip times. Not a pixel renderer.","original":_mesh(original.mesh),"restored":_mesh(native),"poses":poses,"materialBindings":materials,"skinBinds":body.skin.get_bind_count(),"modelScale":actor._pivot.scale.x}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report))
	print("TAIXU MESH AUDIT input exported: ",original.mesh.get_surface_count()," surfaces / ",body.skin.get_bind_count()," original skin binds")
	actor.free();scene.free();quit()
