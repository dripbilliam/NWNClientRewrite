extends Resource
# Original CPU geometry, shared by template clones. Only an eligible instance
# asks for a physics shape. No renderer/GPU readback or synthetic hit volume.
@export var vertices:=PackedVector3Array()
@export var indices:=PackedInt32Array()
@export var bounds:=AABB()
var cached_shape: ConcavePolygonShape3D
var builds:=0
var failure:=""
func get_shape() -> Shape3D:
	if cached_shape!=null: return cached_shape
	if vertices.is_empty() or indices.is_empty() or indices.size()%3!=0: failure="Native hit geometry is empty or malformed"; return null
	var faces:=PackedVector3Array(); faces.resize(indices.size())
	for index in indices.size():
		var vertex:=int(indices[index])
		if vertex<0 or vertex>=vertices.size() or not vertices[vertex].is_finite(): failure="Native hit geometry has an invalid vertex"; return null
		faces[index]=vertices[vertex]
	cached_shape=ConcavePolygonShape3D.new(); cached_shape.backface_collision=true; cached_shape.set_faces(faces); builds+=1
	return cached_shape
