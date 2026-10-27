extends SceneTree

const SOURCE := "res://assets/vfx/native/Sphere002-source.json"
const OBJ := "res://assets/vfx/native/Sphere002.obj"
const OUTPUT := "res://assets/vfx/native/Sphere002-morph.res"
var failed:=false

func _require(condition: bool, message: String) -> void:
 if not condition:
  failed=true
  push_error(message)
  quit(1)

func _initialize() -> void:
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 var data: Dictionary=source.details
 var raw_vertices: Array=data.vertices
 var raw_uv: Array=data.uv0
 var raw_indices: Array=data.indices
 var vertices:=PackedVector3Array()
 var uv:=PackedVector2Array()
 var indices:=PackedInt32Array()
 var normals:=PackedVector3Array()
 _require(int(data.vertexCount)==559 and raw_vertices.size()==559*3,"Original sphere must contain 559 vertices")
 _require(raw_uv.size()==559*2 and raw_indices.size()==960*3,"Original sphere UV/index counts differ")
 for i in 559:
  # AnimeStudio's OBJ exporter mirrors X and leaves the original UVs intact.
  vertices.append(Vector3(-float(raw_vertices[i*3]),float(raw_vertices[i*3+1]),float(raw_vertices[i*3+2])))
  uv.append(Vector2(float(raw_uv[i*2]),float(raw_uv[i*2+1])))
 for triangle in 960:
  var offset: int=triangle*3
  indices.append(int(raw_indices[offset+2]))
  indices.append(int(raw_indices[offset+1]))
  indices.append(int(raw_indices[offset]))
 for line in FileAccess.get_file_as_string(OBJ).split("\n"):
  if not line.begins_with("vn "):continue
  var values: PackedStringArray=line.strip_edges().split(" ",false)
  normals.append(Vector3(float(values[1]),float(values[2]),float(values[3])))
 _require(normals.size()==559,"OBJ must supply one original mirrored normal per vertex")

 var shapes: Dictionary=data.shapes
 _require(shapes.channels.size()==1 and shapes.channels[0].name=="Sphere001","Unexpected source morph channel")
 _require(shapes.vertices.size()==462 and shapes.fullWeights.size()==1 and is_equal_approx(float(shapes.fullWeights[0]),100.0),"Unexpected source morph offsets or full weight")
 var target_vertices: PackedVector3Array=vertices.duplicate()
 var used_indices: Dictionary={}
 for entry in shapes.vertices:
  var index: int=int(entry.index)
  _require(index>=0 and index<559 and not used_indices.has(index),"Invalid or duplicated morph vertex index")
  used_indices[index]=true
  var delta: Dictionary=entry.vertex
  target_vertices[index]+=Vector3(-float(delta.X),float(delta.Y),float(delta.Z))
 # The original channel explicitly hasNormals=false. Retain its base normals.
 _require(not bool(shapes.shapes[0].hasNormals),"Source unexpectedly contains morph normal offsets")

 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices
 var shape_arrays: Array=[]
 shape_arrays.resize(Mesh.ARRAY_MAX)
 shape_arrays[Mesh.ARRAY_VERTEX]=target_vertices
 shape_arrays[Mesh.ARRAY_NORMAL]=normals.duplicate()
 var mesh:=ArrayMesh.new()
 mesh.resource_name="Sphere002 · original Sphere001 morph"
 mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
 mesh.add_blend_shape("Sphere001")
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape_arrays])
 mesh.surface_set_name(0,"Sphere002")
 var bounds:=AABB(vertices[0],Vector3.ZERO)
 for vertex in vertices:bounds=bounds.expand(vertex)
 for vertex in target_vertices:bounds=bounds.expand(vertex)
 mesh.custom_aabb=bounds
 mesh.set_meta("source_path_id",str(source.pathId))
 mesh.set_meta("source_raw_sha256",str(source.rawSHA256))
 mesh.set_meta("source_morph_full_weight",100.0)
 mesh.set_meta("source_morph_vertex_count",462)
 mesh.set_meta("coordinate_conversion","Mirrored X; reversed triangle indices; original UV0 and OBJ normals")
 _require(ResourceSaver.save(mesh,OUTPUT)==OK,"Saving the native morph mesh failed")

 var saved: ArrayMesh=ResourceLoader.load(OUTPUT,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
 _require(saved!=null and saved.get_surface_count()==1,"Saved mesh failed to reload")
 _require(saved.get_blend_shape_count()==1 and saved.get_blend_shape_name(0)=="Sphere001","Saved morph channel differs")
 _require(saved.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"Saved morph mode must remain normalized")
 var actual: Array=saved.surface_get_arrays(0)
 _require(actual[Mesh.ARRAY_VERTEX].size()==559 and actual[Mesh.ARRAY_INDEX].size()==2880,"Saved geometry counts differ")
 _require(actual[Mesh.ARRAY_INDEX]==indices,"Saved winding differs from original OBJ")
 var saved_shapes: Array=saved.surface_get_blend_shape_arrays(0)
 _require(saved_shapes.size()==1 and saved_shapes[0][Mesh.ARRAY_VERTEX].size()==559,"Saved shape geometry differs")
 for i in 559:
  _require(actual[Mesh.ARRAY_VERTEX][i].distance_to(vertices[i])<0.00001,"Saved base vertex differs")
  _require(actual[Mesh.ARRAY_TEX_UV][i].distance_to(uv[i])<0.00001,"Saved UV differs")
  _require(saved_shapes[0][Mesh.ARRAY_VERTEX][i].distance_to(target_vertices[i])<0.00001,"Saved target vertex differs")
 if failed:
  quit(1)
 else:
  print("PASS: Sphere002-morph.res — 559 vertices, 960 triangles, 1 normalized Sphere001 blend shape, 462 original offsets; saved/reloaded geometry verified")
  quit(0)
