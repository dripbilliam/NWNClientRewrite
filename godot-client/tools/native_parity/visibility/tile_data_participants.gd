extends RefCounted
# Isolated cold native SpawnTile/GetTileData projection. No fog state, shader
# writes, World store, movement sampling, render cull policy or timer.
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const Kernel=preload("res://tools/native_parity/visibility/bsp_collector_kernel.gd")
const MAX_PLACEMENTS:=131072
var _kernel
var _scope: Dictionary={}
var _guard:=Callable()
var _open:=false
var _revision:=0
var _width:=0
var _height:=0
var _node_count:=0
var _next_token:=0
var _next_lease:=0
var _nodes: Dictionary={}
var _tiles: Dictionary={}
var _placements: Dictionary={}
var _canonical: Dictionary={}

static func signed32(value: Variant) -> bool:
	return Math.number(value) and value>=-2147483648 and value<=2147483647 and value==floor(float(value))
static func lifetime(value: Variant,depth: int=0) -> bool:
	if not value is Array or value.is_empty() or value.size()>64 or depth>8:return false
	for item in value:
		if item is Array:
			if not lifetime(item,depth+1):return false
		elif not (item==null or item is bool or item is String or Math.number(item)):return false
	return true
static func tile_position(x: Variant,y: Variant,height: Variant,transition: Variant) -> Dictionary:
	if not signed32(x) or not signed32(y) or not signed32(height) or not Math.number(transition):return {"available":false,"reason":"native-setposition-input-unavailable"}
	var point: Array=[Math.f(Math.f(Math.f(x)*10.)+5.),Math.f(Math.f(Math.f(y)*10.)+5.),Math.f(Math.f(height)*Math.f(transition))]
	if not Math.point(point):return {"available":false,"reason":"native-setposition-nonfinite"}
	return {"available":true,"native_position":point,"source":"CNWTile::SetPosition1402c58d0"}

func _unavailable(reason: String) -> Dictionary:return {"available":false,"associated":false,"default_factor":1.0,"reason":reason}
func _current(revision: int) -> bool:
	if not _open or revision!=_revision or not _guard.is_valid():return false
	var accepted: Variant=_guard.call(_scope.duplicate(true))
	return accepted is bool and accepted and _open and revision==_revision
func _kernel_guard(scope: Dictionary) -> bool:return scope==_scope and _current(_revision)

func configure(scope: Dictionary,guard: Callable,width: Variant,height: Variant,margin: Variant,cell: Variant) -> Dictionary:
	if _kernel!=null or scope.is_empty() or not guard.is_valid():return _unavailable("native-tiledata-scope-unavailable")
	_scope=scope.duplicate(true);_guard=guard;_open=true;_revision+=1;_kernel=Kernel.new()
	var bound: Dictionary=_kernel.bind_scope(_scope,_kernel_guard)
	if not bound.available:close();return bound
	var built: Dictionary=_kernel.build(width,height,margin,cell)
	if not built.available:close();return built
	_width=int(width);_height=int(height);_node_count=int(built.nodes)
	return {"available":true,"associated":true,"nodes":built.nodes}

func _context(record: Dictionary) -> Dictionary:
	return {"key":record.key,"lifetime":record.lifetime.duplicate(true),"kind":record.kind,"native_position":record.position.duplicate(),"canonical_index":record.canonical_index}
func _source_current(record: Dictionary,revision: int,installed: bool=true) -> bool:
	if not _current(revision) or installed and not is_same(_placements.get(record.key),record):return false
	var source_guard: Callable=record.guard
	if source_guard.is_valid():
		var accepted: Variant=source_guard.call(_context(record))
		if not accepted is bool or not accepted:return false
	return _open and revision==_revision and (not installed or is_same(_placements.get(record.key),record))

func _tile_result(tile: Dictionary) -> Dictionary:
	var indices: Array=tile.canonical.keys();indices.sort()
	return {"available":true,"associated":true,"tile_token":tile.token,"tile_lifetime":tile.lifetime.duplicate(),"node":tile.node,"native_anchor":tile.position.duplicate(),"canonical_indices":indices}
func _placement_lease(record: Dictionary) -> Dictionary:
	return {"resolver":get_instance_id(),"scope":_scope.duplicate(true),"key":record.key,"lifetime":record.lifetime.duplicate(true),"serial":record.serial}
func _placement_result(record: Dictionary,allocated: bool=false) -> Dictionary:
	var result:=_tile_result(record.tile)
	result.merge({"allocated":allocated,"placement_lease":_placement_lease(record),"native_position":record.position.duplicate(),"kind":record.kind})
	return result

func register_canonical(index: Variant,height: Variant,transition: Variant,placement_lifetime: Array,source_guard: Callable=Callable()) -> Dictionary:
	if not Math.uint(index,_width*_height-1):return _unavailable("canonical-map-index-unavailable")
	var position:=tile_position(int(index)%_width,int(index)/_width,height,transition)
	if not position.available:return position
	return _register("terrain:"+str(int(index)),placement_lifetime,"canonical",position.native_position,int(index),source_guard)
func register_spawn(key: String,placement_lifetime: Array,kind: String,native_position: Variant,source_guard: Callable=Callable()) -> Dictionary:
	if kind=="dynamic":return {"available":true,"associated":false,"default_factor":1.0,"reason":"native-dynamic-part-tiledata-unassociated"}
	if kind not in ["static","border"] or not source_guard.is_valid():return _unavailable("native-spawntile-source-unavailable")
	return _register(key,placement_lifetime,kind,native_position,null,source_guard)
func _register(key: String,placement_lifetime: Array,kind: String,native_position: Variant,canonical_index: Variant,source_guard: Callable) -> Dictionary:
	var revision:=_revision
	if not _current(revision):return _unavailable("native-tiledata-scope-stale")
	if key.is_empty() or not lifetime(placement_lifetime) or not Math.point(native_position):return _unavailable("native-spawntile-input-unavailable")
	var point:=Math.rounded(native_position)
	var previous: Dictionary=_placements.get(key,{})
	if not previous.is_empty() and previous.lifetime==placement_lifetime:
		if previous.kind!=kind or previous.position!=point or previous.canonical_index!=canonical_index:return _unavailable("native-placement-change-requires-new-lifetime")
		return _placement_result(previous) if _source_current(previous,revision) else _unavailable("native-spawntile-source-stale")
	if previous.is_empty() and _placements.size()>=MAX_PLACEMENTS:return _unavailable("native-placement-capacity-bound")
	var candidate:={"key":key,"lifetime":placement_lifetime.duplicate(true),"kind":kind,"position":point,"canonical_index":canonical_index,"guard":source_guard,"parts":{},"serial":_next_lease+1}
	if not _source_current(candidate,revision,false):return _unavailable("native-spawntile-source-stale")
	var fit: Dictionary=_kernel.tile_at(point)
	if not fit.available:return _unavailable("native-spawntile-fitted-node-unavailable")
	var node:=int(fit.node);var tile: Dictionary=_nodes.get(node,{})
	var allocated:=tile.is_empty()
	if allocated:
		if _next_token>=4294967295:return _unavailable("native-tiledata-token-bound")
		_next_token+=1
		tile={"token":_next_token,"lifetime":[get_instance_id(),_next_token],"node":node,"position":point.duplicate(),"canonical":{},"placements":{}}
		var bound: Dictionary=_kernel.bind_tile(tile.token,point,"physical-tiledata:"+str(get_instance_id())+":"+str(tile.token))
		if not bound.available or not _open or revision!=_revision:
			_kernel.retire_tile(tile.token,"physical-tiledata:"+str(get_instance_id())+":"+str(tile.token))
			return _unavailable("native-tiledata-registration-interrupted")
		_nodes[node]=tile;_tiles[tile.token]=tile
	if not previous.is_empty():_retire_record(previous)
	_next_lease+=1;candidate.serial=_next_lease;candidate.tile=tile
	# A reverse membership bit avoids a TileData→placement→TileData reference
	# cycle. Physical ownership remains in the one forward placement record.
	_placements[key]=candidate;tile.placements[key]=true
	if canonical_index!=null:_canonical[canonical_index]=candidate;tile.canonical[canonical_index]=true
	_revision+=1
	return _placement_result(candidate,allocated)

func lookup_map(index: Variant) -> Dictionary:
	var revision:=_revision
	if not _current(revision) or not Math.uint(index,_width*_height-1):return _unavailable("canonical-map-scope-unavailable")
	var record: Dictionary=_canonical.get(int(index),{})
	if record.is_empty() or not _source_current(record,revision):return _unavailable("canonical-tiledata-not-registered")
	return _placement_result(record)
func lookup_spawn(key: String,placement_lifetime: Array) -> Dictionary:
	var revision:=_revision;var record: Dictionary=_placements.get(key,{})
	if record.is_empty() or record.lifetime!=placement_lifetime or not _source_current(record,revision):return _unavailable("native-placement-lifetime-stale")
	return _placement_result(record)
func tile_data(tile_token: Variant,tile_lifetime: Array) -> Dictionary:
	var revision:=_revision
	if not _current(revision) or not Math.uint(tile_token):return _unavailable("native-tiledata-scope-stale")
	var tile: Dictionary=_tiles.get(int(tile_token),{})
	if tile.is_empty() or tile.lifetime!=tile_lifetime:return _unavailable("native-tiledata-lifetime-stale")
	return _tile_result(tile)

func bind_part(key: String,placement_lifetime: Array,part_key: String,part_lifetime: Array,mesh_node: Variant=null,part_guard: Callable=Callable()) -> Dictionary:
	var revision:=_revision;var placement: Dictionary=_placements.get(key,{})
	if placement.is_empty() or placement.lifetime!=placement_lifetime or not _source_current(placement,revision):return _unavailable("native-part-placement-stale")
	if part_key.is_empty() or not lifetime(part_lifetime) or not part_guard.is_valid():return _unavailable("native-physical-part-unavailable")
	if mesh_node!=null and not Math.uint(mesh_node,_node_count-1):return _unavailable("native-mesh-node-unavailable")
	var existing: Dictionary=placement.parts.get(part_key,{})
	if not existing.is_empty() and existing.lifetime==part_lifetime:
		if existing.mesh_node!=mesh_node:return _unavailable("native-mesh-node-change-requires-new-part-lifetime")
		return _part_result(placement,existing) if _part_current(placement,existing,revision) else _unavailable("native-physical-part-stale")
	var part:={"key":part_key,"lifetime":part_lifetime.duplicate(true),"mesh_node":mesh_node,"guard":part_guard,"serial":_next_lease+1}
	if not _part_current(placement,part,revision,false):return _unavailable("native-physical-part-stale")
	_next_lease+=1;part.serial=_next_lease;placement.parts[part_key]=part;_revision+=1
	return _part_result(placement,part)
func _part_context(placement: Dictionary,part: Dictionary) -> Dictionary:
	var result:=_context(placement);result.merge({"part_key":part.key,"part_lifetime":part.lifetime.duplicate(true),"mesh_node":part.mesh_node,"tile_token":placement.tile.token,"tile_lifetime":placement.tile.lifetime.duplicate()});return result
func _part_current(placement: Dictionary,part: Dictionary,revision: int,installed: bool=true) -> bool:
	if not _source_current(placement,revision) or installed and not is_same(placement.parts.get(part.key),part):return false
	var accepted: Variant=part.guard.call(_part_context(placement,part))
	return accepted is bool and accepted and _open and revision==_revision and is_same(_placements.get(placement.key),placement) and (not installed or is_same(placement.parts.get(part.key),part))
func _part_result(placement: Dictionary,part: Dictionary) -> Dictionary:
	var result:=_tile_result(placement.tile);var lease:=_placement_lease(placement)
	lease.merge({"part_key":part.key,"part_lifetime":part.lifetime.duplicate(true),"part_serial":part.serial})
	result.merge({"mesh_node":part.mesh_node,"association_lease":lease});return result
func association_current(lease: Dictionary) -> bool:
	if lease.get("resolver")!=get_instance_id() or lease.get("scope")!=_scope:return false
	var revision:=_revision;var placement: Dictionary=_placements.get(lease.get("key"),{})
	if placement.is_empty() or placement.lifetime!=lease.get("lifetime") or placement.serial!=lease.get("serial"):return false
	var part: Dictionary=placement.parts.get(lease.get("part_key"),{})
	return not part.is_empty() and part.lifetime==lease.get("part_lifetime") and part.serial==lease.get("part_serial") and _part_current(placement,part,revision)
func retire_part(key: String,placement_lifetime: Array,part_key: String,part_lifetime: Array) -> bool:
	var revision:=_revision
	if not _current(revision):return false
	var placement: Dictionary=_placements.get(key,{})
	if placement.is_empty() or placement.lifetime!=placement_lifetime:return false
	var part: Dictionary=placement.parts.get(part_key,{})
	if part.is_empty() or part.lifetime!=part_lifetime:return false
	placement.parts.erase(part_key);_revision+=1;return true
func _retire_record(record: Dictionary) -> void:
	var index: Variant=record.canonical_index
	if index!=null and is_same(_canonical.get(index),record):_canonical.erase(index);record.tile.canonical.erase(index)
	if is_same(_placements.get(record.key),record):record.tile.placements.erase(record.key)
	record.parts.clear();_placements.erase(record.key)
func retire_placement(key: String,placement_lifetime: Array) -> bool:
	var revision:=_revision
	if not _current(revision):return false
	var record: Dictionary=_placements.get(key,{})
	if record.is_empty() or record.lifetime!=placement_lifetime:return false
	_retire_record(record);_revision+=1;return true

func collect_bound(camera_native: Variant,planes: Variant,primary_words: Dictionary) -> Dictionary:
	var revision:=_revision
	if not _current(revision):return _unavailable("native-tiledata-scope-stale")
	var result: Dictionary=_kernel.collect_bound(_scope,camera_native,planes,primary_words)
	if not result.available or not _open or revision!=_revision:return _unavailable("native-tiledata-collection-interrupted")
	for token in result.tile_tokens:
		if not _tiles.has(int(token)):return _unavailable("native-collected-tiledata-identity-unavailable")
	return result
func snapshot() -> Dictionary:
	var tiles: Array=[]
	for tile in _tiles.values():tiles.append(_tile_result(tile))
	return {"open":_open,"scope":_scope.duplicate(true),"tiles":tiles,"placements":_placements.size(),"canonical":_canonical.size(),"parts":_placements.values().reduce(func(total,record):return total+record.parts.size(),0),"kernel_cost":_kernel.cost() if _kernel!=null else {}}
func close() -> void:
	_open=false;_revision+=1;_scope.clear();_guard=Callable();_placements.clear();_canonical.clear();_tiles.clear();_nodes.clear()
	if _kernel!=null:_kernel.close()
