extends RefCounted
# Isolated static POD adapter. Cold tree construction uses the differential
# GDS oracle; every collection requires the independent native kernel.
const Oracle=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const EXTENSION="res://native/bsp_collector.gdextension"
var _tree:=Oracle.new()
var _scope: Dictionary={}
var _guard:=Callable()
var _open:=false
var _revision:=0
var _planes:=PackedFloat32Array()
var _topology:=PackedInt32Array()
var _vertices:=PackedFloat32Array()
var _ranges:=PackedInt32Array()
var _membership:=PackedInt64Array()
var _root:=-1
var _records: Dictionary={}
var _node_owners: Dictionary={}
var _last_cost: Dictionary={}

static func kernel_available() -> bool:
	if ClassDB.class_exists(&"NwnBspCollector"):return true
	if not FileAccess.file_exists(EXTENSION):return false
	GDExtensionManager.load_extension(EXTENSION)
	return ClassDB.class_exists(&"NwnBspCollector")

func bind_scope(scope: Dictionary,guard: Callable) -> Dictionary:
	if _open or scope.is_empty() or not guard.is_valid():return _unavailable("native-bsp-scope-unavailable")
	if not kernel_available():return _unavailable("native-bsp-kernel-unavailable")
	_scope=scope.duplicate(true);_guard=guard;_open=true;_revision+=1
	return {"available":true}

func _unavailable(reason: String) -> Dictionary:return {"available":false,"reason":reason}

func _current(revision: int,scope: Dictionary) -> bool:
	if not _open or revision!=_revision or scope!=_scope or not _guard.is_valid():return false
	var accepted: Variant=_guard.call(scope.duplicate(true))
	return accepted is bool and accepted and _open and revision==_revision and scope==_scope

func build(width: Variant,height: Variant,margin: Variant,cell: Variant) -> Dictionary:
	var revision:=_revision
	if not _current(revision,_scope):return _unavailable("native-bsp-scope-stale")
	var built:=_tree.build(width,height,margin,cell)
	if not built.available or built.cached:return built
	var tree:=_tree.export_tree()
	_planes=PackedFloat32Array();_topology=PackedInt32Array();_vertices=PackedFloat32Array();_ranges=PackedInt32Array();_membership=PackedInt64Array()
	for node in tree.nodes:
		_planes.append_array(PackedFloat32Array(node.plane));_topology.append_array(PackedInt32Array([node.leaf,node.negative,node.positive]))
		_ranges.append_array(PackedInt32Array([_vertices.size()/3,node.vertices.size()]))
		for vertex in node.vertices:_vertices.append_array(PackedFloat32Array(vertex))
		_membership.append(-1)
	_root=int(tree.root);_records.clear();_node_owners.clear();_revision+=1
	return built

func bind_tile(tile: Variant,position_native: Variant,physical_lifetime: String) -> Dictionary:
	var revision:=_revision
	if not _current(revision,_scope):return _unavailable("native-bsp-scope-stale")
	if not Oracle.uint(tile) or physical_lifetime.is_empty():return _unavailable("native-tile-identity-unavailable")
	var fit:=_tree.tile_at(position_native)
	if not fit.available:return _unavailable("native-tile-placement-unavailable")
	var token:=int(tile);var node:=int(fit.node);var record: Dictionary=_records.get(token,{})
	if not record.is_empty() and record.lifetime!=physical_lifetime:
		_retire_record(record);record={}
	if record.is_empty():record={"tile":token,"lifetime":physical_lifetime,"nodes":{}};_records[token]=record
	var previous: Dictionary=_node_owners.get(node,{})
	if not previous.is_empty():previous.nodes.erase(node)
	_node_owners[node]=record;record.nodes[node]=true;_membership[node]=token;_revision+=1
	return {"available":true,"node":node,"previous":previous.get("tile")}

func _retire_record(record: Dictionary) -> void:
	for node in record.nodes.keys():
		if is_same(_node_owners.get(node),record):_node_owners.erase(node);_membership[node]=-1
	_records.erase(record.tile)

func retire_tile(tile: Variant,physical_lifetime: String) -> bool:
	var revision:=_revision
	if not _current(revision,_scope) or not Oracle.uint(tile):return false
	var record: Dictionary=_records.get(int(tile),{})
	if record.is_empty() or record.lifetime!=physical_lifetime:return false
	_retire_record(record);_revision+=1;return true

func tile_at(position_native: Variant) -> Dictionary:return _tree.tile_at(position_native)

func collect_bound(scope: Dictionary,camera_native: Variant,planes: Variant,snapshot_words: Dictionary) -> Dictionary:
	var started:=Time.get_ticks_usec();var revision:=_revision
	if not _current(revision,scope):return _unavailable("native-bsp-scope-stale")
	if _root<0 or not Oracle.point(camera_native) or not planes is Array or planes.size()>Oracle.MAX_PLANES or not planes.all(func(p):return Oracle.point(p,4)):return _unavailable("native-bsp-collection-input-unavailable")
	if not Oracle.uint(snapshot_words.get("hi")) or not Oracle.uint(snapshot_words.get("lo")):return _unavailable("native-primary-snapshot-words-unavailable")
	var frustum:=PackedFloat32Array()
	for plane in planes:frustum.append_array(PackedFloat32Array(plane))
	var camera:=Vector3(camera_native[0],camera_native[1],camera_native[2]);var gathered:=Time.get_ticks_usec()
	# All arrays are cached borrowed POD for this synchronous call. No Nodes or
	# authority crosses the extension boundary, and outputs are detached arrays.
	var result: Dictionary=ClassDB.class_call_static(&"NwnBspCollector",&"collect",_planes,_topology,_vertices,_ranges,_membership,_root,camera,frustum,int(snapshot_words.lo))
	var returned:=Time.get_ticks_usec()
	if not _current(revision,scope):return _unavailable("native-bsp-scope-retired-during-collection")
	_last_cost={"gather_us":gathered-started,"kernel_and_publication_us":returned-gathered,"total_us":Time.get_ticks_usec()-started,"nodes":_membership.size(),"callbacks":result.get("node_ids",PackedInt32Array()).size()}
	return result

func collect_camera(scope: Dictionary,camera: Dictionary,snapshot_words: Dictionary) -> Dictionary:
	var planes:=Oracle.camera_planes(camera)
	if not planes.available:return planes
	return collect_bound(scope,camera.position,planes.planes,snapshot_words)

func export_tree() -> Dictionary:
	var tree:=_tree.export_tree()
	for node in _node_owners:tree.nodes[node].tile=_membership[node]
	return tree

func packed_input() -> Array:
	# Detached diagnostics/test vectors; callers cannot mutate the cached tree.
	return [_planes.duplicate(),_topology.duplicate(),_vertices.duplicate(),_ranges.duplicate(),_membership.duplicate(),_root]

func cost() -> Dictionary:return _last_cost.duplicate(true)

func close() -> void:
	_open=false;_revision+=1;_scope.clear();_guard=Callable();_records.clear();_node_owners.clear();_root=-1
	_planes.clear();_topology.clear();_vertices.clear();_ranges.clear();_membership.clear();_last_cost.clear()
