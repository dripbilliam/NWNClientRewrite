extends Resource
# A parsed rigid Part owns this identity across PackedScene/recipe clones. The
# template stores source bytes and this token, but never keeps the draw mesh.
@export var source_sha: String=""
@export var node_index: int=-1
@export var mesh_data: Dictionary={}
var current: ArrayMesh
