extends RefCounted
# Boundary-driven presentation state/spatial membership, not an entity store.
# Root supplies canonical tiles, desired entities, actual instances and clock.
const Tiles = preload("res://systems/native_data/native_tile_visibility.gd")
const Query = preload("res://systems/native_data/native_tile_query.gd")
const Fade = preload("res://tools/native_parity/visibility/reveal_fade.gd")
const Alpha = preload("res://tools/native_parity/visibility/alpha_program.gd")
const Lifetime = preload("res://systems/native_data/entity_presentation_lifetime.gd")
const MAX_ENTITIES := 8192
var _world: WeakRef
var _scope: Dictionary = {}
var _callbacks: Dictionary = {}
var _tiles: Array = [] # Aliases Root's existing canonical tile state.
var _width := 0
var _height := 0
var _flags := 0
var _records: Dictionary = {}
var _buckets: Dictionary = {}
var _active: Dictionary = {}
var _serial := -1
var _order := 0
var _closed := true
var _issues: Array = []
var stats := {"raw_events":0,"stale_events":0,"scope_rejections":0,"tile_operations":0,"object_notifications":0,"position_updates":0,"query_transitions":0,"fade_steps":0,"publications":0,"publication_failures":0,"unavailable":0,"retired":0}

static func scope_value(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var connection: Variant = value.get("connection_epoch")
	if not (connection is String and not connection.is_empty()) and not Tiles._integer(connection,0,4294967295): return {}
	var result := {"connection_epoch":connection if connection is String else int(connection)}
	for key in ["area_generation","area_id","controlled_id"]:
		if not Tiles._integer(value.get(key),0,4294967295): return {}
		result[key] = int(value[key])
	var token: Variant = value.get("controlled_lifetime")
	if not token is Array or token.size() != 2: return {}
	var normalized: Array = []
	for index in 2:
		var row: Variant = token[index]
		var key: String = ["nativeLifetime","disclosureLifetime"][index]
		if not row is Array or row.size() != 3 or row[0] != key or not row[1] is bool: return {}
		if row[1]:
			if not Tiles._integer(row[2],0,4294967295): return {}
			normalized.append([key,true,int(row[2])])
		elif row[2] == null: normalized.append([key,false,null])
		else: return {}
	# Missing native identity is unavailable, never an invented lifetime0.
	if not normalized[0][1]: return {}
	result.controlled_lifetime = normalized
	return result

static func wire_scope(frame: Variant) -> Dictionary:
	if not frame is Dictionary or frame.get("kind") != "raw-tile-visibility" or not Tiles._integer(frame.get("connection"),0,4294967295): return {}
	return scope_value({"connection_epoch":frame.connection,"area_generation":frame.get("generation"),"area_id":frame.get("areaId"),"controlled_id":frame.get("actorId"),"controlled_lifetime":frame.get("lifetime")})

func _issue(reason: String, id: int = -1) -> Dictionary:
	stats.unavailable += 1
	if _issues.size() < 64: _issues.append({"reason":reason,"id":id})
	return {"available":false,"accepted":false,"reason":reason}

func configure(world: Node, scope: Variant, area: Dictionary, callbacks: Dictionary) -> Dictionary:
	if not _closed: return _issue("visibility-owner-already-configured")
	var normalized := scope_value(scope)
	if not is_instance_valid(world) or normalized.is_empty(): return _issue("world-scope-unavailable")
	if not Tiles._integer(area.get("width"),1,Tiles.MAX_TILES) or not Tiles._integer(area.get("height"),1,Tiles.MAX_TILES) or area.width * area.height > Tiles.MAX_TILES or not Tiles._integer(area.get("flags"),-2147483648,4294967295): return _issue("native-area-fields-unavailable")
	if not area.get("states") is Array or area.states.size() != int(area.width) * int(area.height): return _issue("canonical-tiles-unavailable")
	for value in area.states:
		if not Tiles._integer(value,-2147483648,2147483647): return _issue("canonical-tile-state-unavailable")
	for key in ["scope_current","tile_center","target_alpha","publish"]:
		if not callbacks.get(key) is Callable or not callbacks[key].is_valid(): return _issue("required-callback-unavailable/" + key)
	if (int(area.flags) & 3) != 0 and (not callbacks.get("tile_fog") is Callable or not callbacks.tile_fog.is_valid()): return _issue("native-tile-fog-callback-unavailable")
	_world = weakref(world)
	_scope = normalized
	_width = int(area.width)
	_height = int(area.height)
	_flags = int(area.flags)
	_tiles = area.states
	_callbacks = callbacks.duplicate()
	_serial = -1
	_order = 0
	_closed = false
	return {"available":true,"accepted":true,"scope":_scope.duplicate(true)}

func _current() -> bool:
	var world: Node = _world.get_ref() if _world != null else null
	if _closed or not is_instance_valid(world): return false
	var accepted: Variant = _callbacks.scope_current.call(_scope.duplicate(true))
	return accepted is bool and accepted and not _closed

func _source_current(id: int, lifetime: Array) -> bool:
	if not _current(): return false
	var world: Node = _world.get_ref()
	var desired: Variant = world.get("desired")
	if not desired is Dictionary or not desired.has(id) or not desired[id] is Dictionary or not desired[id].get("object") is Dictionary: return false
	var source: Dictionary = desired[id].object
	return not source.get("replicationRemoved",false) and Tiles._integer(source.get("id"),0,4294967295) and int(source.id) == id and Tiles._integer(source.get("areaId"),0,4294967295) and int(source.areaId) == int(_scope.area_id) and Lifetime.token(source) == lifetime

func _record_current(id: int, record: Dictionary) -> bool:
	return _records.has(id) and is_same(_records[id],record) and _source_current(id,record.lifetime)

func _instance(record: Dictionary) -> Node3D:
	var instance: Node3D = record.instance.get_ref() if record.instance is WeakRef else null
	return instance if is_instance_valid(instance) and instance.get("retired") != true else null

func _publish(id: int, record: Dictionary, command: Dictionary) -> bool:
	if not _record_current(id,record): return false
	var accepted: Variant = _callbacks.publish.call(id,record.lifetime.duplicate(true),command.duplicate(true))
	stats.publications += 1
	if not accepted is bool or not accepted:
		stats.publication_failures += 1
		_issue("native-visibility-command-unavailable/" + str(command.get("kind")),id)
		return false
	return _record_current(id,record)

func _target(id: int, record: Dictionary, revealed: int) -> Variant:
	var revision: int = record.revision
	var result: Variant = _callbacks.target_alpha.call(id,record.lifetime.duplicate(true),revealed)
	if not _record_current(id,record) or record.revision != revision: return null
	if not result is Dictionary or result.get("available") != true or not Tiles._integer(result.get("alpha_word"),0,4294967295): return null
	return int(result.alpha_word)

func _update_active(id: int, record: Dictionary) -> void:
	if record.opacity_pending != null or record.fade.status != record.fade.desired: _active[id] = true
	else: _active.erase(id)

func _immediate(id: int, record: Dictionary, revealed: bool) -> void:
	if record.field104 == 1: return
	record.revision += 1
	record.fade.status = int(revealed)
	_publish(id,record,{"kind":"native_reveal_hooks","setter":"immediate765c80","revealed":revealed,"render_owner_present":_instance(record) != null,"native_field108":record.field108})
	if not _record_current(id,record): return
	# Native stores A8 first, calls its existing scene/link hooks, then stores A9.
	record.fade.desired = int(revealed)
	var target_revision: int = record.revision
	var alpha: Variant = _target(id,record,int(revealed))
	if not _record_current(id,record) or record.revision != target_revision: return
	if alpha == null:
		record.opacity_pending = int(revealed)
		record.fade.opacity_word = null
		_issue("immediate-target-alpha-unavailable",id)
	else:
		record.opacity_pending = null
		record.fade.opacity_word = alpha
		if _instance(record) != null: _publish(id,record,{"kind":"set_alpha","scope":255,"alpha_word":alpha})
	_update_active(id,record)

func _set_target(id: int, record: Dictionary, revealed: bool) -> void:
	if not _record_current(id,record) or record.field104 == 1 or record.field108 != 0: return
	record.revision += 1
	record.fade.desired = int(revealed)
	record.fade.expiry_enabled = 0
	record.fade.expiry_ms = 0
	_publish(id,record,{"kind":"native_reveal_hooks","setter":"target765920","revealed":revealed,"render_owner_present":_instance(record) != null,"native_field108":record.field108})
	if _record_current(id,record): _update_active(id,record)

func _center(index: int, x: int, y: int) -> Variant:
	if not _current(): return null
	var center: Variant = _callbacks.tile_center.call(index,x,y)
	return center if _current() and Tiles.contains_native_xy(center,center).available else null

func _keys(position: Array) -> Variant:
	if absf(float(position[0]) / 10.0) >= 2147483647.0 or absf(float(position[1]) / 10.0) >= 2147483647.0: return null
	var x := floori(float(position[0]) / 10.0)
	var y := floori(float(position[1]) / 10.0)
	var keys: Array = []
	for tx in range(x - 1,x + 2):
		for ty in range(y - 1,y + 2):
			if tx < 0 or ty < 0 or tx >= _width or ty >= _height: continue
			var index := ty * _width + tx
			var center: Variant = _center(index,tx,ty)
			if center == null: return null
			if Tiles.contains_native_xy(center,position).contains: keys.append(index)
	return keys

func _unindex(id: int, record: Dictionary) -> void:
	for key in record.tiles:
		if _buckets.has(key):
			_buckets[key].erase(id)
			if _buckets[key].is_empty(): _buckets.erase(key)
	record.tiles.clear()

func observe_object(source: Dictionary, native_position: Variant, instance: Node3D = null, reason: String = "position") -> Dictionary:
	if not _current(): return _issue("scope-retired")
	if not Tiles._integer(source.get("id"),0,4294967295) or not Tiles._integer(source.get("nativeLifetime"),0,4294967295): return _issue("native-object-lifetime-unavailable")
	var id := int(source.id)
	if not Tiles._integer(source.get("areaId"),0,4294967295) or int(source.areaId) != int(_scope.area_id): return _issue("object-area-mismatch",id)
	if source.get("staticState") is Dictionary: return {"available":true,"accepted":false,"reason":"native-clientarea-static-geometry-not-cnwc-object"}
	if not Tiles._integer(source.get("objectType"),0,255): return _issue("native-object-type-unavailable",id)
	var kind := int(source.objectType)
	if kind not in [5,6,9,10]: return {"available":true,"accepted":false,"reason":"native-object-type-not-in-tile-notifications"}
	if reason not in ["create","area-entry","position","mode"]: return _issue("unproven-reveal-entry",id)
	var token := Lifetime.token(source)
	if not _source_current(id,token): return _issue("canonical-object-lifetime-changed",id)
	if not native_position is Array or native_position.size() < 3: return _issue("native-client-position-unavailable",id)
	var position: Array = []
	for axis in 3:
		var value: Variant = native_position[axis]
		if not (value is int or value is float) or not is_finite(float(value)): return _issue("native-client-position-unavailable",id)
		var component: float = PackedFloat32Array([float(value)])[0]
		if not is_finite(component): return _issue("native-client-position-unavailable",id)
		position.append(component)
	var keys: Variant = _keys(position)
	if keys == null: return _issue("native-tile-center-unavailable",id)
	if _records.has(id) and _records[id].lifetime != token: _retire(id)
	if not _records.has(id):
		if _records.size() >= MAX_ENTITIES: return _issue("presentation-member-bound",id)
		_order += 1
		_records[id] = {"lifetime":token,"kind":kind,"order":_order,"position":position,"tiles":[],"instance":null,"prior_query230":1,"field104":0,"field108":0,"revision":0,"opacity_pending":null,"fade":{"status":1,"desired":1,"opacity_word":Alpha.ONE_WORD,"expiry_enabled":0,"expiry_ms":0,"start_day":0,"start_ms":0}}
	var record: Dictionary = _records[id]
	if not _record_current(id,record): return _issue("canonical-object-lifetime-changed",id)
	_unindex(id,record)
	record.position = position
	record.tiles = keys
	if is_instance_valid(instance): record.instance = weakref(instance)
	for key in keys:
		if not _buckets.has(key): _buckets[key] = {}
		_buckets[key][id] = true
	stats.position_updates += 1
	var query := Query.read(_flags,_width,_height,_tiles,position)
	if not query.available: return _issue("native-area-query-unavailable",id)
	if kind == 5:
		var next := int(query.revealed)
		var prior: int = record.prior_query230
		if prior != next:
			_immediate(id,record,prior != 1)
			_set_target(id,record,prior != 1)
			if _record_current(id,record): record.prior_query230 = next
			stats.query_transitions += 1
	elif reason in ["create","area-entry","mode"]:
		var revealed: bool = query.revealed and position != [0.0,0.0,0.0]
		_immediate(id,record,revealed and kind == 6)
		_set_target(id,record,revealed)
	if not _record_current(id,record): return _issue("object-retired-during-native-entry",id)
	return {"available":true,"accepted":true,"id":id,"query":query,"reason":"native-existing-entry-boundary"}

func bind_instance(id: int, lifetime: Array, instance: Node3D) -> Dictionary:
	if not _records.has(id) or _records[id].lifetime != lifetime or not is_instance_valid(instance): return _issue("instance-lifetime-unavailable",id)
	var record: Dictionary = _records[id]
	if not _record_current(id,record): return _issue("instance-scope-retired",id)
	record.instance = weakref(instance)
	if Tiles._integer(record.fade.opacity_word,0,4294967295): _publish(id,record,{"kind":"set_alpha","scope":255,"alpha_word":record.fade.opacity_word})
	if not _record_current(id,record): return _issue("instance-retired-during-publication",id)
	return {"available":true,"accepted":true}

func set_area_flags(flags: Variant) -> Dictionary:
	if not _current() or not Tiles._integer(flags,-2147483648,4294967295): return _issue("native-area-flags-unavailable")
	if (int(flags) & 3) != 0 and (not _callbacks.get("tile_fog") is Callable or not _callbacks.tile_fog.is_valid()): return _issue("native-tile-fog-callback-unavailable")
	_flags = int(flags)
	# No speculative re-evaluation: Root dispatches actual mode766140 boundaries.
	return {"available":true,"accepted":true}

func set_native_gates(id: int, lifetime: Array, field104: Variant, field108: Variant) -> Dictionary:
	if not _records.has(id) or _records[id].lifetime != lifetime or not Tiles._integer(field104,-2147483648,4294967295) or not Tiles._integer(field108,-2147483648,4294967295): return _issue("native-fade-gate-unavailable",id)
	if not _record_current(id,_records[id]): return _issue("native-fade-gate-scope-retired",id)
	_records[id].field104 = int(field104)
	_records[id].field108 = int(field108)
	_records[id].revision += 1
	return {"available":true,"accepted":true}

func _tile_objects(event: Dictionary, center: Array) -> void:
	var candidates: Array = _buckets.get(int(event.tile_index),{}).keys()
	candidates.sort_custom(func(a,b):return int(_records[a].order) < int(_records[b].order))
	for id in candidates:
		if not _records.has(id): continue
		var record: Dictionary = _records[id]
		if not _record_current(id,record): continue
		if not Tiles.contains_native_xy(center,record.position).contains: continue
		stats.object_notifications += 1
		_set_target(id,record,bool(event.revealed))

func receive(event: Dictionary) -> Dictionary:
	if not _current(): return _issue("scope-retired")
	if scope_value(event.get("scope")) != _scope:
		stats.scope_rejections += 1
		return _issue("event-scope-mismatch")
	if not Tiles._integer(event.get("serial"),0,Tiles.MAX_SAFE_SERIAL): return _issue("event-serial-unavailable")
	var serial := int(event.serial)
	if serial <= _serial:
		stats.stale_events += 1
		return {"available":true,"accepted":false,"reason":"stale-event"}
	# Projection delivery.scope is optional display evidence, not scope authority;
	# the complete typed connection/area/actor lifetime was checked above.
	var plan := Tiles.project({"previous":_tiles,"width":_width,"height":_height,"change":event.get("change"),"delivery":{"scope":str(_scope.connection_epoch),"serial":serial}})
	if not plan.available: return _issue("malformed-tile-event/" + str(plan.reason))
	# Validate all needed native centers BEFORE any callback/store. This preserves
	# whole-event retry when not yet ready; a retired scope is discarded by Root.
	var centers: Dictionary = {}
	for operation in plan.operations:
		if operation.suppress_object_updates != 0 or centers.has(operation.tile_index): continue
		var center: Variant = _center(int(operation.tile_index),int(operation.x),int(operation.y))
		if center == null: return _issue("native-tile-center-unavailable")
		centers[operation.tile_index] = center.duplicate()
	for operation in plan.operations:
		var center: Array = centers.get(operation.tile_index,[])
		var objects := func(value: Dictionary) -> void: _tile_objects(value,center)
		var fog := func(value: Dictionary) -> void:
			var accepted: Variant = _callbacks.tile_fog.call(value)
			if accepted != true: _issue("native-tile-fog-publication-failed")
		var result := Tiles.apply_operation(_tiles,operation,{"objects":objects,"fog_enabled":(_flags & 3) != 0,"fog":fog,"is_current":_current})
		if not result.available: return _issue("tile-delivery-interrupted/" + str(result.reason))
		stats.tile_operations += 1
	_serial = serial
	stats.raw_events += 1
	return {"available":true,"accepted":true,"operations":plan.operations.size(),"warnings":plan.warnings,"serial":serial}

func receive_wire(frame: Dictionary) -> Dictionary:
	var scope := wire_scope(frame)
	if scope.is_empty(): return _issue("wire-scope-or-native-lifetime-unavailable")
	return receive({"scope":scope,"serial":frame.get("serial"),"change":frame.get("change")})

func advance(existing_timing: Dictionary) -> void:
	if not _current(): return
	var ids: Array = _active.keys()
	ids.sort_custom(func(a,b):return int(_records[a].order) < int(_records[b].order))
	for id in ids:
		if not _records.has(id): continue
		var record: Dictionary = _records[id]
		if not _record_current(id,record): _retire(id); continue
		if record.opacity_pending != null:
			var pending_revision: int = record.revision
			var pending: Variant = _target(id,record,int(record.opacity_pending))
			if pending == null or record.revision != pending_revision: continue
			record.fade.opacity_word = pending
			record.opacity_pending = null
			if _instance(record) != null: _publish(id,record,{"kind":"set_alpha","scope":255,"alpha_word":pending})
			if not _record_current(id,record): continue
		var present := _instance(record) != null
		var targets: Array = []
		var target_revision: int = record.revision
		if record.fade.status != record.fade.desired:
			var first: Variant = _target(id,record,int(record.fade.desired))
			if not _record_current(id,record) or record.revision != target_revision: continue
			if first == null: _issue("fade-target-alpha-unavailable",id); continue
			targets.append(first)
		var output := Fade.update(record.fade,existing_timing,targets,present)
		if not output.available and output.reason == "second_target_unavailable":
			var second: Variant = _target(id,record,int(record.fade.desired))
			if second == null or not _record_current(id,record) or record.revision != target_revision: continue
			targets.append(second)
			output = Fade.update(record.fade,existing_timing,targets,present)
		if not output.available: _issue(str(output.reason),id); continue
		if not _record_current(id,record): continue
		record.fade = output.state
		for command in output.commands:
			if not _publish(id,record,command): break
		if _record_current(id,record): _update_active(id,record)
		stats.fade_steps += 1

func _retire(id: int) -> void:
	if not _records.has(id): return
	_unindex(id,_records[id])
	_records.erase(id)
	_active.erase(id)
	stats.retired += 1

func remove(id: int, lifetime: Array) -> Dictionary:
	if not _records.has(id): return {"available":true,"accepted":false,"reason":"already-retired"}
	if _records[id].lifetime != lifetime: return {"available":true,"accepted":false,"reason":"stale-lifetime-removal"}
	_retire(id)
	return {"available":true,"accepted":true}

func snapshot() -> Dictionary:
	var entries: Array = []
	for id in _records:
		var record: Dictionary = _records[id]
		entries.append({"id":id,"lifetime":record.lifetime.duplicate(true),"kind":record.kind,"position_native":record.position.duplicate(),"tiles":record.tiles.duplicate(),"prior_query230":record.prior_query230,"fade":record.fade.duplicate(true),"instance_present":_instance(record) != null,"opacity_pending":record.opacity_pending})
	return {"closed":_closed,"scope":_scope.duplicate(true),"last_serial":_serial,"active_fades":_active.size(),"members":entries,"stats":stats.duplicate(),"issues":_issues.duplicate(true),"clock":"caller existing native snapshot/world timing only","source":"fresh raw mask0x200; no sticky automap replay or guessed LOS"}

func close() -> void:
	if _closed: return
	_closed = true
	_records.clear()
	_buckets.clear()
	_active.clear()
	_callbacks.clear()
	_tiles = [] # Do not clear the caller's canonical Array.
	_world = null
