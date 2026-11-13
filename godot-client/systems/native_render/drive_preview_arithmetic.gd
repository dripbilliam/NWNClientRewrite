extends RefCounted
# One synchronous input only. No Nodes/world/received state are owned here.
const Profile=preload("res://systems/native_render/frame_profile.gd")
const PureSurface=preload("res://systems/native_render/terrain_surface.gd")
const MAX_BYTES:=256*1024
const MAX_TILES:=64
const MIN_FACES:=64
static func worthwhile(surface,minimum: Vector3,maximum: Vector3)->bool:
	# Inspect already-decoded source metadata only; never build collision tiles
	# merely to choose this optional optimization.
	if not is_instance_valid(surface) or surface.get_script()!=PureSurface or not surface.ready():return false
	var definition: Dictionary=surface.definition
	var width:=int(definition.get("width",0));var height:=int(definition.get("height",0))
	if width<=0 or height<=0:return false
	var left:=maxi(0,floori(minimum.x/10));var right:=mini(width-1,floori(maximum.x/10))
	var bottom:=maxi(0,floori(minimum.y/10));var top:=mini(height-1,floori(maximum.y/10))
	if right<left or top<bottom or (right-left+1)*(top-bottom+1)>MAX_TILES:return false
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			var tile: Dictionary=definition.tiles[y*width+x]
			var mesh: Dictionary=surface.meshes.get(tile.model,{})
			var faces: Variant=mesh.get("faces")
			if faces is Array and faces.size()>=MIN_FACES:return true
	return false
class Counts extends RefCounted:
	var term_prepares:=0
	var term_reuses:=0
	var height_hits:=0
	var budget_fallbacks:=0
class TileTerms extends RefCounted:
	var source: Array
	var values:=PackedFloat64Array()
	var prepared:=PackedByteArray()
	var counts: Counts
	func configure(triangles: Array,shared: Counts)->void:
		source=triangles;counts=shared;values.resize(triangles.size()*3);prepared.resize(triangles.size())
	static func cross(a: Vector2,b: Vector2)->float:return a.x*b.y-a.y*b.x
	func interval(from: Vector2,to: Vector2,index: int,tri: Dictionary)->Vector2:
		var points: Array=tri.xy_points;var area: float=tri.xy_area
		if absf(area)<0.0000001:return Vector2(1,-1)
		var sign_value:=1.0 if area>0 else -1.0
		var base:=index*3
		if prepared[index]==0:
			# Internal typed storage stays unique while being written; returning a
			# PackedArray through a Dictionary here would cause copy-on-write work.
			for edge_index in 3:
				var edge: Vector2=tri.xy_edges[edge_index]
				values[base+edge_index]=sign_value*cross(edge,from-points[edge_index])
			prepared[index]=1;counts.term_prepares+=1
		else:counts.term_reuses+=1
		var low:=0.0;var high:=1.0
		for edge_index in 3:
			var edge: Vector2=tri.xy_edges[edge_index]
			var a: float=values[base+edge_index];var b:=sign_value*cross(edge,to-points[edge_index]);var d:=b-a
			if absf(d)<0.0000001:
				if a< -0.00001:return Vector2(1,-1)
			elif d>0:low=maxf(low,-a/d)
			else:high=minf(high,-a/d)
		return Vector2(low,high)
var origin_bits:=PackedByteArray()
var _surface: WeakRef
var _definition: Dictionary={}
var _meshes: Dictionary={}
var _table: Dictionary={}
var _table_rows: Array=[]
var _default_walk: Variant=null
var _pure_height:=false
var _height_ready:=false
var _height:=0.0
var tiles: Dictionary={}
var bytes:=0
var counts:=Counts.new()
var _published:=[0,0,0,0]
var _ledger: Dictionary={}
static func point_bits(point: Vector3)->PackedByteArray:return PackedFloat32Array([point.x,point.y,point.z]).to_byte_array()
static func plain(value: Variant)->bool:return value==null or value is String or value is StringName or value is int or value is float or value is bool
func configure(point: Vector3,surface,ledger: Dictionary)->void:
	origin_bits=point_bits(point);_ledger=ledger
	if not is_instance_valid(surface) or surface.get_script()!=PureSurface:return
	var rows: Variant=surface.table.get("orderedRows",[])
	if not rows is Array or not plain(surface.table.get("defaultValue","0")):return
	# str(Object) can invoke user code. Only the normal immutable numeric/text
	# decoded table is eligible; unknown/overridden sources keep direct sampling.
	for row in rows:
		if not row is Dictionary or not plain(row.get("Walk",surface.table.get("defaultValue","0"))):return
	_surface=weakref(surface);_definition=surface.definition;_meshes=surface.meshes;_table=surface.table;_table_rows=rows;_default_walk=surface.table.get("defaultValue","0");_pure_height=true
func matches(point: Vector3)->bool:return point_bits(point)==origin_bits
func accepts(surface,point: Vector3)->bool:return matches(point) and _height_current(surface)
func _height_current(surface)->bool:
	return _pure_height and is_instance_valid(surface) and _surface.get_ref()==surface and surface.get_script()==PureSurface and not surface.closed and surface.ready() and is_same(surface.definition,_definition) and is_same(surface.meshes,_meshes) and is_same(surface.table,_table) and is_same(surface.table.get("orderedRows",[]),_table_rows) and surface.table.get("defaultValue","0")==_default_walk
func start_height(surface,point: Vector3,previous: float)->float:
	# Owner already verifies the exact input bits and scope/frame/publication.
	if _height_ready and _height_current(surface):counts.height_hits+=1;return _height
	Profile.count("count_drive_height_samples",1)
	var result: float=surface.height(point,previous)
	if _height_current(surface):_height=result;_height_ready=true
	return result
func tile_terms(index: int,triangles: Array)->TileTerms:
	if tiles.has(index):
		var cached: TileTerms=tiles[index]
		return cached if is_same(cached.source,triangles) else null
	var charge:=triangles.size()*25
	if tiles.size()>=MAX_TILES or charge>MAX_BYTES-bytes:counts.budget_fallbacks+=1;return null
	var entry:=TileTerms.new();entry.configure(triangles,counts);tiles[index]=entry;bytes+=charge
	return entry
func publish()->void:
	var values: Array=[counts.term_prepares,counts.term_reuses,counts.height_hits,counts.budget_fallbacks]
	var names: Array=["from_terms_prepared","from_terms_reused","height_memo_hits","arithmetic_budget_fallbacks"]
	for index in names.size():
		var delta:=int(values[index])-int(_published[index])
		if delta!=0:
			_ledger[names[index]]=int(_ledger.get(names[index],0))+delta
			Profile.count("count_drive_"+str(names[index]),delta)
		_published[index]=values[index]
	_ledger.arithmetic_peak_bytes=maxi(int(_ledger.get("arithmetic_peak_bytes",0)),bytes)
