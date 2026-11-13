extends RefCounted
# Isolated physical TileData+c4/c8 reducer. The scene resolver owns TileData
# identity and Part associations; existing visual owners own shader endpoints.
# No Nodes, clock, camera, world store or production activation lives here.
const Math=preload("res://systems/native_render/native_tile_fog.gd")
const MAX_TILES:=65536
const MAX_ENDPOINTS:=262144
var _scope: Array=[]
var _guard: Callable
var _closed:=true
var _revision:=0
var _tiles: Dictionary={}
var _endpoints: Dictionary={}
var _issues: Array=[]
var stats:={"registrations":0,"fog_setters":0,"callbacks":0,"factor_changes":0,"publications":0,"adoptions":0,"retirements":0,"unavailable":0}

func _issue(reason: String) -> Dictionary:
	stats.unavailable+=1
	if _issues.size()<32 and not _issues.has(reason):_issues.append(reason)
	return {"available":false,"reason":reason}
static func _token(value: Variant) -> bool:return Math.integer(value,1,4294967295)
static func _life(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size()>8:return false
	for member in value:
		if not (member is int or member is String):return false
	return true
func configure(scope: Array,scope_guard: Callable) -> Dictionary:
	if not _closed or scope.is_empty() or not scope_guard.is_valid():return _issue("physical-fog-configuration-unavailable")
	_scope=scope.duplicate(true);_guard=scope_guard;_closed=false;_revision+=1
	return {"available":_current()}
func _current() -> bool:
	if _closed or not _guard.is_valid():return false
	var epoch:=_revision
	var accepted: Variant=_guard.call(_scope.duplicate(true))
	return accepted==true and not _closed and _revision==epoch
func _tile(token: int,lifetime: Array) -> Dictionary:
	if not _current():return {}
	var record: Dictionary=_tiles.get(token,{})
	return record if record.get("lifetime")==lifetime else {}
func register_tile(token: int,lifetime: Array) -> Dictionary:
	if not _token(token) or not _life(lifetime) or not _current():return _issue("physical-tile-identity-unavailable")
	if _tiles.has(token):
		if _tiles[token].lifetime!=lifetime:return _issue("physical-tile-token-reused-without-scope-retirement")
		return {"available":true,"allocated":false}
	if _tiles.size()>=MAX_TILES:return _issue("physical-tile-capacity")
	# Original constructor088130: c4=0, c8=1. Canonical map loader/fog
	# operations are separate setters; outside TileData is not zeroed by fiat.
	_tiles[token]={"lifetime":lifetime.duplicate(true),"fogged":false,"factor":1.0,"publish_ready":false,"publication_pending":false,"endpoints":{}}
	_revision+=1;stats.registrations+=1
	return {"available":true,"allocated":true}
func _effective(record: Dictionary) -> float:return float(record.factor) if record.publish_ready else 1.0
func _endpoint_current(record: Dictionary) -> bool:
	if not _current():return false
	var epoch:=_revision
	var accepted: Variant=record.guard.call(record.lease.duplicate(true))
	return accepted==true and _current() and epoch==_revision and _endpoints.get(record.key)==record
func _publish_one(record: Dictionary,factor: float) -> bool:
	if not _endpoint_current(record):return false
	if record.get("published")==factor:return true
	var epoch:=_revision
	var accepted: Variant=record.publish.call(factor,record.lease.duplicate(true))
	# A reentrant adoption, retirement or material replacement cannot certify
	# this older endpoint's write as publication onto the successor.
	if accepted!=true or not _current() or epoch!=_revision or not _endpoint_current(record):return false
	record.published=factor;stats.publications+=1
	return true
func _publish(token: int) -> bool:
	if not _current() or not _tiles.has(token):return false
	var tile: Dictionary=_tiles[token];var epoch:=_revision
	var factor:=_effective(tile)
	tile.publication_pending=true
	# Membership is small and changes only at existing model publication/retire
	# boundaries. The settled per-frame path never walks these endpoints.
	for key in tile.endpoints:
		if epoch!=_revision or not _current():return false
		var endpoint: Dictionary=_endpoints.get(key,{})
		if endpoint.is_empty() or not _publish_one(endpoint,factor):return false
	tile.publication_pending=false
	return true
func adopt_endpoint(token: int,lifetime: Array,key: String,lease: Dictionary,lease_current: Callable,publish: Callable) -> Dictionary:
	var tile:=_tile(token,lifetime)
	if tile.is_empty() or key.is_empty() or lease.is_empty() or not lease_current.is_valid() or not publish.is_valid():return _issue("physical-fog-endpoint-unavailable")
	if _endpoints.has(key):return _issue("physical-fog-endpoint-key-already-owned")
	if _endpoints.size()>=MAX_ENDPOINTS:return _issue("physical-fog-endpoint-capacity")
	var epoch:=_revision
	var current: Variant=lease_current.call(lease.duplicate(true))
	if current!=true or not _current() or epoch!=_revision:return _issue("physical-fog-endpoint-lease-stale")
	var record:={"key":key,"token":token,"lease":lease.duplicate(true),"guard":lease_current,"publish":publish}
	_endpoints[key]=record;tile.endpoints[key]=true;_revision+=1;stats.adoptions+=1
	if not _publish_one(record,_effective(tile)):
		tile.publication_pending=true
		return _issue("physical-fog-endpoint-publication-unavailable")
	if tile.publication_pending and not _publish(token):return _issue("physical-fog-pending-endpoint-publication-unavailable")
	return {"available":true,"factor":_effective(tile)}
func retire_endpoint(key: String,lease: Dictionary) -> bool:
	if not _current() or not _endpoints.has(key) or _endpoints[key].lease!=lease:return false
	var record: Dictionary=_endpoints[key]
	_tiles[record.token].endpoints.erase(key);_endpoints.erase(key);_revision+=1;stats.retirements+=1
	return true
func set_publish_ready(token: int,lifetime: Array,ready_value: bool) -> Dictionary:
	var tile:=_tile(token,lifetime)
	if tile.is_empty():return _issue("physical-fog-completeness-owner-unavailable")
	if tile.publish_ready==ready_value:
		if tile.publication_pending and not _publish(token):return _issue("physical-fog-completeness-publication-unavailable")
		return {"available":true,"changed":false}
	# This explicit source-owner certificate prevents floor-only activation
	# while associated static Parts/material paths are still unsupported.
	tile.publish_ready=ready_value;_revision+=1
	if not _publish(token):return _issue("physical-fog-completeness-publication-unavailable")
	return {"available":true,"changed":true}
func receive_fog(token: int,lifetime: Array,fogged: bool) -> Dictionary:
	var tile:=_tile(token,lifetime)
	if tile.is_empty():return _issue("physical-fog-setter-identity-unavailable")
	var before: float=tile.factor
	tile.fogged=fogged
	if fogged:tile.factor=0.0
	_revision+=1;stats.fog_setters+=1
	if tile.factor!=before:
		stats.factor_changes+=1
		if not _publish(token):return _issue("physical-fog-setter-publication-unavailable")
	elif tile.publication_pending and not _publish(token):return _issue("physical-fog-pending-setter-publication-unavailable")
	return {"available":true,"changed":tile.factor!=before}
# Caller supplies original renderer DeltaT from primary snapshot words, after
# original signed-low32/CVTDQ2PS/DIVSS conversion. Never use GUI/process delta.
func advance_collected(tokens: Variant,delta: float) -> Dictionary:
	# The native collector returns PackedInt64Array. Accept it directly rather
	# than allocating a boxed whole-collection Array each render frame.
	if not (tokens is Array or tokens is PackedInt32Array or tokens is PackedInt64Array):return _issue("physical-fog-collection-format-unavailable")
	if not _current() or not is_finite(delta):return _issue("physical-fog-collection-time-unavailable")
	for token in tokens:
		if not _token(token) or not _tiles.has(int(token)):return _issue("physical-fog-collected-token-unavailable")
	var step:=Math.f(Math.f(delta)*4.0)
	var changed: Dictionary={}
	for token in tokens:
		var tile: Dictionary=_tiles[int(token)]
		stats.callbacks+=1
		if tile.factor<1.0 and not tile.fogged:
			var next:=Math.f(float(tile.factor)+step)
			tile.factor=1.0 if next>1.0 else next
			changed[int(token)]=true;stats.factor_changes+=1
	# Preserve duplicate native callbacks in the reducer, but publish each
	# resulting shader value only once. No per-frame all-world copying/scanning.
	if not changed.is_empty():_revision+=1
	for token in changed:
		if not _publish(token):return _issue("physical-fog-collection-publication-unavailable")
	return {"available":_current(),"changed":changed.size(),"callbacks":tokens.size()}
func tile_view(token: int,lifetime: Array) -> Dictionary:
	var tile:=_tile(token,lifetime)
	if tile.is_empty():return {"available":false}
	return {"available":true,"token":token,"lifetime":tile.lifetime.duplicate(true),"fogged":tile.fogged,"factor":tile.factor,"publish_ready":tile.publish_ready,"publication_pending":tile.publication_pending,"effective_factor":_effective(tile),"endpoints":tile.endpoints.size()}
func snapshot() -> Dictionary:
	return {"closed":_closed,"scope":_scope.duplicate(true),"tiles":_tiles.size(),"endpoints":_endpoints.size(),"stats":stats.duplicate(),"issues":_issues.duplicate(),"active_in_production":false}
func close() -> void:
	_closed=true;_revision+=1;_scope.clear();_guard=Callable();_tiles.clear();_endpoints.clear()
