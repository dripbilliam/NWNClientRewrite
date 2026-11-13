extends "res://tools/native_parity/visibility/tile_data_participants.gd"
# Separate original AuroraSetTileFoggedByWar target lookup. The inherited
# resolver remains the only physical TileData/placement/Part authority.
var _search_planes:=PackedFloat32Array()
var _search_topology:=PackedInt32Array()
var _search_root:=-1

func configure(scope: Dictionary,guard: Callable,width: Variant,height: Variant,margin: Variant,cell: Variant) -> Dictionary:
	var result:=super.configure(scope,guard,width,height,margin,cell)
	if not result.available:return result
	# One cold detached immutable POD copy; no per-search scene/tree rebuild
	# or duplicate physical membership store. No production file is changed.
	var packed: Array=_kernel.packed_input()
	_search_planes=packed[0];_search_topology=packed[1];_search_root=int(packed[5])
	if _search_planes.size()!=_node_count*4 or _search_topology.size()!=_node_count*3 or _search_root<0 or _search_root>=_node_count:close();return _unavailable("native-fog-setter-cached-tree-unavailable")
	for value in _search_planes:
		if not is_finite(value):close();return _unavailable("native-fog-setter-cached-plane-nonfinite")
	return result

func _search_distance(node: int,point: Array) -> float:
	var offset:=node*4
	# Exact BSPSearch Listing order: Y product + X product, then Z, then D.
	var x:=Math.f(_search_planes[offset]*point[0]);var y:=Math.f(_search_planes[offset+1]*point[1]);var z:=Math.f(_search_planes[offset+2]*point[2])
	return Math.f(Math.f(Math.f(y+x)+z)+_search_planes[offset+3])

func resolve_fog_setter(native_position: Variant) -> Dictionary:
	var revision:=_revision
	if not _current(revision):return _unavailable("native-fog-setter-scope-stale")
	if _search_root<0 or not Math.point(native_position):return _unavailable("native-fog-setter-position-unavailable")
	var point:=Math.rounded(native_position);var stack: Array[int]=[_search_root];var visited:=0;var selected: Dictionary={}
	while not stack.is_empty():
		var node:=int(stack.pop_back());visited+=1
		if node<0 or node>=_node_count or visited>_node_count:return _unavailable("native-fog-setter-tree-bound")
		# Original predicate0a5100 checks this node's TileData before any leaf
		# or point test. This is not GetTileData/radius0 fitted-node lookup.
		if _nodes.has(node):selected=_nodes[node];break
		var offset:=node*3
		if _search_topology[offset]!=0:continue
		var positive:=_search_distance(node,point)>=0.0
		var near_node:=_search_topology[offset+2 if positive else offset+1]
		var far_node:=_search_topology[offset+1 if positive else offset+2]
		# Stack reverses push order: original point-near subtree is exhausted
		# first; the far subtree is searched only after near returns no match.
		if far_node>=0:stack.append(far_node)
		if near_node>=0:stack.append(near_node)
	if not _current(revision):return _unavailable("native-fog-setter-membership-changed-during-search")
	if selected.is_empty():return _unavailable("native-fog-setter-tiledata-unavailable")
	var result:=_tile_result(selected)
	var lease:={"resolver":get_instance_id(),"scope":_scope.duplicate(true),"revision":revision,"tile_token":selected.token,"tile_lifetime":selected.lifetime.duplicate(),"node":selected.node}
	result.merge({"search":"BSPSearch229980/predicate0a5100","visited_nodes":visited,"native_setter_position":point.duplicate(),"setter_lease":lease})
	return result

func setter_target_current(lease: Dictionary) -> bool:
	if lease.get("resolver")!=get_instance_id() or lease.get("scope")!=_scope or not lease.get("revision") is int:return false
	if not _current(int(lease.revision)):return false
	var tile: Dictionary=_tiles.get(lease.get("tile_token"),{})
	return not tile.is_empty() and tile.lifetime==lease.get("tile_lifetime") and tile.node==lease.get("node") and is_same(_nodes.get(tile.node),tile)

func close() -> void:
	_search_planes.clear();_search_topology.clear();_search_root=-1
	super.close()
