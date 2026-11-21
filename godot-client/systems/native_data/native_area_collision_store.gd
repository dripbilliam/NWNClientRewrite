extends RefCounted

# CNWArea's physical parallel collision arrays. Source slot order, highest
# hole reuse and append-only door bound order are retained for client queries.
const INVALID:=0x7f000000
static func f(value: float)->float:return Vector3(value,0.0,0.0).x
static func _empty_bounds()->Array:return [[1000000.0,1000000.0,1000000.0],[-1000000.0,-1000000.0,-1000000.0]]
static func _vector(value: Variant)->Variant:
	if not value is Array or value.size()!=3:return {"error":"Native collision vector is unavailable or invalid"}
	var result: Array=[]
	for part in value:
		if not is_finite(float(part)) or not is_finite(f(float(part))):return {"error":"Native collision vector is unavailable or invalid"}
		result.append(f(float(part)))
	return result
static func _geometry(vertices: Variant,faces: Variant)->Variant:
	if not vertices is Array or not faces is Array:return {"error":"Native collision geometry is unavailable or invalid"}
	for face in faces:
		if not face is Array or face.size()!=3:return {"error":"Native collision geometry is unavailable or invalid"}
		for index in face:
			if typeof(index)!=TYPE_INT or index<0 or index>=vertices.size():return {"error":"Native collision geometry is unavailable or invalid"}
	var result: Array=[]
	for vertex in vertices:
		var point: Variant=_vector(vertex)
		if point is Dictionary:return point
		result.append(point)
	return result
static func _transform(vertices: Array,orientation: Array,position: Array,replacing: bool=false)->Dictionary:
	var bounds:=_empty_bounds();var result: Array=[]
	for source in vertices:
		var x:=float(source[0]);var y:=float(source[1]);var z:=float(source[2])
		var first:=f(float(orientation[0])*y);var second:=f(x*float(orientation[1]))
		var point: Array=[f(f(second+first if replacing else first+second)+float(position[0])),f(f(f(y*float(orientation[1]))-f(float(orientation[0])*x))+float(position[1])),f(z+float(position[2]))]
		for axis in 3:
			if float(bounds[0][axis])>float(point[axis]):bounds[0][axis]=point[axis]
			if float(point[axis])>float(bounds[1][axis]):bounds[1][axis]=point[axis]
		result.append(point)
	return {"vertices":result,"bounds":bounds}

var object_capacity:=0;var object_count:=0;var vertex_capacity:=0;var vertex_count:=0
var index_capacity:=0;var face_count:=0;var door_capacity:=0;var door_count:=0
var object_ids:=PackedInt64Array();var face_starts:=PackedInt32Array();var face_counts:=PackedInt32Array()
var vertex_starts:=PackedInt32Array();var vertex_counts:=PackedInt32Array()
var indices:=PackedInt32Array();var vertices:=PackedFloat32Array();var bounds:=PackedFloat32Array()
var door_ids:=PackedInt64Array();var door_bounds:=PackedFloat32Array()
var _search_tombstones:=true

func _init(dense_build: bool=false)->void:
	_search_tombstones=not dense_build

func add(id: int,orientation: Array,position: Array,source_vertices: Array,source_faces: Array)->Variant:
	if id<0 or id>0xffffffff:return {"error":"Native collision object ID is invalid"}
	var direction: Variant=_vector(orientation);var location: Variant=_vector(position);var points: Variant=_geometry(source_vertices,source_faces)
	if direction is Dictionary:return direction
	if location is Dictionary:return location
	if points is Dictionary:return points
	var transformed:=_transform(points,direction,location)
	var vertex_base:=0 if object_count==0 else vertex_count
	var face_base:=0 if object_count==0 else face_count
	var slot:=-1
	if _search_tombstones:
		slot=object_count-1
		while slot>=0 and object_ids[slot]!=INVALID:slot-=1
	var count:=object_count+1 if slot<0 else object_count
	if slot<0:slot=object_count
	var capacity:=16 if object_capacity==0 else object_capacity*2 if count==object_capacity else object_capacity
	var next_vertex_capacity:=vertex_capacity
	if vertex_base+points.size()>=next_vertex_capacity:
		if next_vertex_capacity==0:next_vertex_capacity=16
		while next_vertex_capacity<=vertex_capacity+points.size():next_vertex_capacity*=2
	var next_index_capacity:=index_capacity
	if 3*(face_base+source_faces.size())>=next_index_capacity:
		if next_index_capacity==0:next_index_capacity=48
		while next_index_capacity<=3*(face_count+source_faces.size()):next_index_capacity*=2
	if capacity>16777216 or next_vertex_capacity*3>16777216 or next_index_capacity>16777216:return {"error":"Native collision storage allocation is unsupported"}
	object_ids.resize(capacity);face_starts.resize(capacity);face_counts.resize(capacity);vertex_starts.resize(capacity);vertex_counts.resize(capacity);bounds.resize(capacity*6)
	vertices.resize(next_vertex_capacity*3);indices.resize(next_index_capacity)
	object_ids[slot]=id;face_starts[slot]=face_base;face_counts[slot]=source_faces.size();vertex_starts[slot]=vertex_base;vertex_counts[slot]=points.size()
	for axis in 3:
		bounds[slot*6+axis]=transformed.bounds[0][axis];bounds[slot*6+3+axis]=transformed.bounds[1][axis]
	for index in points.size():
		for axis in 3:vertices[3*(vertex_base+index)+axis]=transformed.vertices[index][axis]
	for face in source_faces.size():
		for corner in 3:indices[3*(face_base+face)+corner]=int(source_faces[face][corner])+vertex_base
	object_capacity=capacity;object_count=count;vertex_capacity=next_vertex_capacity;index_capacity=next_index_capacity
	vertex_count+=points.size();face_count+=source_faces.size()
	# A successful sentinel write can create a native hole even without remove().
	if id==INVALID:_search_tombstones=true
	return slot

func remove(slot: int)->Variant:
	if slot==-1 or slot>=object_count:return null
	if slot<0:return {"error":"Native collision slot would access invalid memory"}
	var vertex_base:=int(vertex_starts[slot]);var removed_vertices:=int(vertex_counts[slot])
	var face_base:=int(face_starts[slot]);var removed_faces:=int(face_counts[slot])
	vertex_starts[slot]=0;vertex_counts[slot]=0;face_starts[slot]=0;face_counts[slot]=0
	object_ids[slot]=INVALID
	_search_tombstones=true
	var empty:=_empty_bounds()
	for axis in 3:bounds[slot*6+axis]=empty[0][axis];bounds[slot*6+3+axis]=empty[1][axis]
	for index in range((vertex_base+removed_vertices)*3,vertex_count*3):vertices[index-removed_vertices*3]=vertices[index]
	for index in range(3*(face_base+removed_faces),3*face_count):indices[index-3*removed_faces]=indices[index]-removed_vertices
	vertex_count-=removed_vertices;face_count-=removed_faces
	for index in object_count:
		if int(vertex_starts[index])>vertex_base:vertex_starts[index]-=removed_vertices
		if int(face_starts[index])>face_base:face_starts[index]-=removed_faces
	return null

func replace(slot: int,id: int,orientation: Array,position: Array,source_vertices: Array,source_faces: Array)->Variant:
	if slot==-1 or slot>=object_count:return null
	if slot<0:return {"error":"Native collision slot would access invalid memory"}
	if id<0 or id>0xffffffff:return {"error":"Native collision object ID is invalid"}
	if object_ids[slot]!=id or source_vertices.size()!=vertex_counts[slot] or source_faces.size()!=face_counts[slot]:return null
	var direction: Variant=_vector(orientation);var location: Variant=_vector(position);var points: Variant=_geometry(source_vertices,source_faces)
	if direction is Dictionary:return direction
	if location is Dictionary:return location
	if points is Dictionary:return points
	var transformed:=_transform(points,direction,location,true)
	var vertex_base:=int(vertex_starts[slot]);var face_base:=int(face_starts[slot])
	for index in points.size():
		for axis in 3:vertices[3*(vertex_base+index)+axis]=transformed.vertices[index][axis]
	for face in source_faces.size():
		for corner in 3:indices[3*(face_base+face)+corner]=int(source_faces[face][corner])+vertex_base
	for axis in 3:bounds[slot*6+axis]=transformed.bounds[0][axis];bounds[slot*6+3+axis]=transformed.bounds[1][axis]
	return null

func get_bounds(slot: int)->Variant:
	if slot<0 or slot>=object_count:return {"error":"Native collision slot would access invalid memory"}
	return [[bounds[slot*6],bounds[slot*6+1],bounds[slot*6+2]],[bounds[slot*6+3],bounds[slot*6+4],bounds[slot*6+5]]]
func add_door_bounds(id: int,minimum: Array,maximum: Array)->Variant:
	if id<0 or id>0xffffffff:return {"error":"Native collision object ID is invalid"}
	var low: Variant=_vector(minimum);var high: Variant=_vector(maximum)
	if low is Dictionary:return low
	if high is Dictionary:return high
	var capacity:=maxi(8,door_capacity*2) if door_count==door_capacity else door_capacity
	if capacity>16777216 or capacity*6>16777216:return {"error":"Native collision storage allocation is unsupported"}
	door_ids.resize(capacity);door_bounds.resize(capacity*6)
	door_ids[door_count]=id
	for axis in 3:door_bounds[door_count*6+axis]=low[axis];door_bounds[door_count*6+3+axis]=high[axis]
	door_capacity=capacity;door_count+=1
	return 0
func remove_door_bounds(id: int)->Variant:
	if id<0 or id>0xffffffff:return {"error":"Native collision object ID is invalid"}
	var index:=0
	while index<door_count and door_ids[index]!=id:index+=1
	if index==door_count:return 0
	door_count-=1
	for at in range(index,door_count):
		door_ids[at]=door_ids[at+1]
		for axis in 6:door_bounds[at*6+axis]=door_bounds[(at+1)*6+axis]
	return 1
