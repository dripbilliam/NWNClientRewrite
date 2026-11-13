extends RefCounted
# Thin SessionWorld boundary adapter. Canonical entities stay in UI.text.objects
# and World.desired; local constructor fields stay in their physical cache.
# No per-frame world enumeration, renderer-driven construction or room hiding.
const Bridge=preload("res://systems/native_render/native_scene_visibility_bridge.gd")
const LocalFields=preload("res://systems/native_render/native_creature_visibility_fields.gd")
const Fog=preload("res://systems/native_render/native_tile_fog.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const Scope=preload("res://systems/native_render/native_scene_visibility.gd")
const MAX_EVENTS:=512
const MAX_UNITS:=262144
var _client: WeakRef
var _world: WeakRef
var _connection:=-1
var _closed:=true
var _fields
var _bridge
var _fog
var _scope: Dictionary={}
var _area_scope: Array=[]
var _states: Array=[] # Native CNWCTile map states; no copied entity store.
var _width:=0
var _height:=0
var _flags:=0
var _pending: Array=[]
var _units:=0
var _serials: Dictionary={}
var _links: Array=[]
var _references: Dictionary={} # Only scoped lifetime tokens for retire hooks.
var _ports: Dictionary={}
var _initializer_seen:=false
var _issues: Array=[]
var stats:={"accepted_worlds":0,"queued":0,"accepted_events":0,"retired_events":0,"observations":0,"model_publications":0,"position_events":0,"world_scans":0,"unavailable":0,"area_bindings":0}
func _issue(reason: String) -> Dictionary:
	stats.unavailable+=1
	if _issues.size()<64 and not _issues.has(reason):_issues.append(reason)
	return {"available":false,"reason":reason}
func configure(client: Object,ports: Dictionary={}) -> Dictionary:
	if not _closed or not is_instance_valid(client) or not client.has_method("native_text_connection"):return _issue("native-visibility-client-unavailable")
	_client=weakref(client);_ports=ports.duplicate();_closed=false
	return {"available":true,"lazy":true}
func _live_client() -> Object:
	var client: Object=_client.get_ref() if _client!=null else null
	return client if not _closed and is_instance_valid(client) and client.get("closing")!=true else null
func _connection_current(value: Variant) -> bool:
	var client:=_live_client()
	return client!=null and value==_connection and client.call("native_text_connection")==_connection
func _ensure_connection() -> bool:
	var client:=_live_client()
	if client==null:return false
	var connection: Variant=client.call("native_text_connection")
	if not LocalFields.uint(connection):return false
	if int(connection)==_connection:return _fields!=null
	cleanup_connection();_connection=int(connection);_fields=LocalFields.new()
	return _fields.configure(_connection,_connection_current).available
func _known(id: int) -> Dictionary:
	var client:=_live_client()
	if client==null:return {}
	var ui: Variant=client.get("gameplay_ui")
	if not is_instance_valid(ui):return {}
	var text: Variant=ui.get("text")
	if not is_instance_valid(text) or not text.get("objects") is Dictionary:return {}
	var source: Variant=text.get("objects").get(id)
	return source if source is Dictionary else {}
func _world_current() -> Node:
	var client:=_live_client();var world: Node=_world.get_ref() if _world!=null else null
	if client==null or not is_instance_valid(world) or client.get("world")!=world or world.get("closed")==true or world.get("retiring")==true or not _connection_current(_connection):return null
	return world
func _scope_current(scope: Dictionary) -> bool:
	var world:=_world_current()
	if world==null or scope!=_scope or world.get("generation")!=scope.area_generation or world.get("area_id")!=scope.area_id or world.get("controlled_id")!=scope.controlled_id:return false
	return Lifetime.token(_known(int(scope.controlled_id)))==scope.controlled_lifetime
func _link(owner: Object,signal_name: String,callback: Callable) -> void:
	if is_instance_valid(owner) and owner.has_signal(signal_name) and not owner.is_connected(signal_name,callback):
		owner.connect(signal_name,callback);_links.append({"owner":weakref(owner),"signal":signal_name,"callback":callback})
func _disconnect() -> void:
	for link in _links:
		var owner: Object=link.owner.get_ref()
		if is_instance_valid(owner) and owner.is_connected(link.signal,link.callback):owner.disconnect(link.signal,link.callback)
	_links.clear()
func _retire_world() -> void:
	_disconnect()
	if _bridge!=null:_bridge.close()
	if _fog!=null:_fog.close()
	_bridge=null;_fog=null;_world=null;_scope={};_references.clear()
func lifecycle(event: Dictionary) -> Dictionary:
	if not _ensure_connection():return _issue("native-lifecycle-connection-unavailable")
	# The SessionWorld caller owns admitted raw-clock-protocol scope fences.
	# This path is independent of optional native clock sampling/availability.
	return _fields.accepted_lifecycle(event)
func accepted_lifecycle(event: Dictionary) -> Dictionary:return lifecycle(event)
func receive(frame: Dictionary) -> bool:
	if not _ensure_connection() or frame.get("connection")!=_connection:return false
	var kind: String=str(frame.get("kind"))
	if kind not in ["raw-tile-visibility","raw-creature-visibility-permission"] or not LocalFields.uint(frame.get("serial"),9007199254740991):return false
	if int(frame.serial)<=int(_serials.get(kind,-1)):return false
	var units:=1
	if kind=="raw-tile-visibility":
		if Scope.wire_scope(frame).is_empty() or not frame.get("change") is Dictionary:return false
		var payload: Variant=frame.change.get("bytes",frame.change.get("points"))
		if not payload is Array and not payload is PackedByteArray:return false
		units=payload.size()
	else:
		if not frame.get("permission") is bool or not frame.get("field114") is bool:return false
		if frame.get("actorId")!=null and (not LocalFields.uint(frame.actorId) or not LocalFields.valid_token(frame.get("lifetime"))):return false
		# Native permission is connection-global and the raw frame captures its
		# exact recipient. Area advancement cannot retire the global write or
		# silently redirect stats114 to today's controlled character.
		var applied: Dictionary=_fields.receive(frame)
		if applied.get("available")==true:
			_serials[kind]=int(frame.serial);stats.accepted_events+=1
			if applied.get("recipient_available")!=true:_issue("native-permission-recipient-physical-owner-unavailable")
			return true
		_issue("native-permission-event-unavailable/"+str(applied.get("reason")));return false
	if not LocalFields.uint(frame.get("generation")) or not LocalFields.uint(frame.get("areaId")):return false
	if _pending.size()>=MAX_EVENTS or _units+units>MAX_UNITS:_issue("native-visibility-queue-capacity");return false
	_serials[kind]=int(frame.serial);_pending.append({"frame":frame.duplicate(true),"units":units});_units+=units;stats.queued+=1;return true
func _event_scope(frame: Dictionary) -> String:
	# The wire lifetime contains JSON floats; the owned scope contains integers.
	# Compare the established typed projection, not raw heterogeneous Arrays.
	var incoming:=Scope.wire_scope(frame)
	if incoming.is_empty() or incoming.connection_epoch!=_connection:return "retired"
	if _bridge==null or _scope.is_empty():return "wait"
	if incoming.area_generation<_scope.area_generation:return "retired"
	if incoming.area_generation>_scope.area_generation:return "wait"
	if incoming.area_id!=_scope.area_id:return "retired"
	if incoming.controlled_id!=_scope.controlled_id or incoming.controlled_lifetime!=_scope.controlled_lifetime:return "retired"
	return "current"
func _drain() -> void:
	# Only accepted-world-end calls this. A fresh raw operation must never run
	# against the prior coalesced world's old positions/lifetimes.
	var batch:=_pending;_pending=[];var remaining:=_units;_units=0
	for index in batch.size():
		var item: Dictionary=batch[index];var frame: Dictionary=item.frame;var current:=_event_scope(frame)
		if current=="wait":_pending=batch.slice(index)+_pending;_units+=remaining;return
		remaining-=int(item.units)
		if current=="retired":stats.retired_events+=1;continue
		var result: Dictionary={}
		if frame.kind=="raw-tile-visibility":result=_bridge.receive_wire(frame)
		else:result=_fields.receive(frame)
		if result.get("available")==true:stats.accepted_events+=1
		else:_issue("native-event-lower-unavailable/"+str(result.get("reason","unknown")))
	if not _scope.is_empty() and _fields!=null:_fields.controlled_changed(_scope.controlled_id,_scope.controlled_lifetime)
func _player_info() -> Dictionary:
	if _scope.is_empty():return {"available":false}
	var source:=_known(int(_scope.controlled_id));var state: Variant=source.get("playerState")
	if not state is Dictionary:return {"available":false,"reason":"native-player-info-owner-unavailable"}
	var visibility: Variant=state.get("visibility")
	if not visibility is Dictionary:return {"available":false,"reason":"received-perception-list-unavailable"}
	return {"available":true,"present":true,"visibility":visibility}
func _creature_fields(id: int,lifetime: Array) -> Dictionary:
	var source:=_known(id)
	if _fields==null or Lifetime.token(source)!=lifetime:return {"available":false}
	_fields.bind(source)
	return _fields.fields(id,lifetime)
func _shadow_detail() -> Variant:
	var client:=_live_client();var settings: Variant=client.get("render_settings") if client!=null else null
	return settings.get("creature_shadow_detail") if is_instance_valid(settings) else null
func _fade_timing() -> Dictionary:
	var client:=_live_client();var clock: Variant=client.get("native_clock_runtime") if client!=null else null
	if not is_instance_valid(clock) or not clock.has_method("reveal_timing"):return {"available":false}
	var result: Variant=clock.call("reveal_timing")
	return result if result is Dictionary else {"available":false}
func _tile_fog(event: Dictionary) -> bool:
	if _fog==null:_issue("native-draw-collected-tile-owner-unavailable/fog-kept-at-default1");return false
	return _fog.receive(event)
func _tile_center(_index: int,x: int,y: int) -> Array:return [float(x*10+5),float(y*10+5)]
func _native_position(source: Dictionary) -> Array:
	var world:=_world_current();var id: int=int(source.get("id",-1))
	if world!=null:
		var motion: Variant=world.get("motion")
		if is_instance_valid(motion) and motion.get("objects") is Dictionary:
			var point: Variant=motion.get("objects").get(id,{}).get("position")
			if point is Vector3 and point.is_finite():return [point.x,point.y,point.z]
	var point: Variant=source.get("replicated",{}).get("position")
	return point if point is Array else []
func _observe(source: Dictionary,reason: String) -> Dictionary:
	if _bridge==null or not LocalFields.uint(source.get("id")):return _issue("native-observation-owner-unavailable")
	var id:=int(source.id);var world:=_world_current()
	if world==null or not world.get("desired").has(id):return {"available":true,"accepted":false}
	if source.get("objectType")==5:_fields.bind(source)
	var result: Dictionary=_bridge.observe(source,_native_position(source),reason)
	if result.get("available")==true:_references[id]=Lifetime.token(source);stats.observations+=1
	return result
func _ready_signal(id: int,source: Dictionary,instance: Variant) -> void:
	var world:=_world_current()
	if world==null or _bridge==null or world.get("instances").get(id)!=instance or Lifetime.token(_known(id))!=Lifetime.token(source):return
	if not _references.has(id):_observe(source,"area-entry")
	var result: Dictionary=_bridge.model_ready(id,Lifetime.token(source))
	if result.get("available")==true:stats.model_publications+=1
func _state_signal(_id: int,source: Dictionary) -> void:
	if _bridge!=null and _scope_current(_scope):_observe(source,"position")
func _removed_signal(id: int) -> void:
	# Render eviction/replacement is not entity destruction. Preserve native
	# fade/local fields if the canonical received entity is still present.
	var world:=_world_current()
	if world!=null and not world.get("desired").has(id) and _references.has(id):_bridge.remove(id,_references[id]);_references.erase(id)
func _tile_signal(index: int,instance: Variant) -> void:
	if _fog!=null and instance is Node3D:_fog.model_ready(index,instance)
func _motion_signal(rows: Array,emitter: WeakRef) -> void:
	# Sparse logical positions from the existing native simulation writer.
	# Bind the exact weak emitter: an earlier synchronous listener can replace
	# the World/Motion owner or reenter its update before our callback runs.
	var motion: Object=emitter.get_ref() if emitter!=null else null
	for value in rows:
		var world:=_world_current()
		if world==null or not _scope_current(_scope) or not is_instance_valid(motion) or world.get("motion")!=motion:return
		if not value is Dictionary or not LocalFields.uint(value.get("id")):continue
		var id:=int(value.id);var source:=_known(id)
		if not _references.has(id) or Lifetime.token(source)!=_references[id] or not world.get("desired").has(id):continue
		var point: Variant=value.get("native_position")
		if not point is Vector3 or not point.is_finite():continue
		# This guard belongs immediately before forwarding, inside emission.
		# Retained, physically replaced and superseded outer rows are invalid.
		if not motion.call("position_change_is_current",value):continue
		position_changed(id,[point.x,point.y,point.z])
func accepted_world(data: Dictionary) -> Dictionary:
	if not _ensure_connection():return _issue("accepted-world-connection-unavailable")
	# Connection16 is a connection initialization fact. An unavailable area,
	# clock or map must not defer it or turn it into an area-local default.
	var ui: Variant=data.get("ui")
	if not _initializer_seen and ui is Dictionary:
		var initial: Variant=ui.get("gameMasterPermission")
		if initial is Dictionary and initial.get("source")=="native_connection_start_16":
			if _fields.initialize_connection_permission(initial).available:_initializer_seen=true
	var client:=_live_client();var world: Variant=client.get("world");var area: Variant=data.get("area")
	if not world is Node or world.get("closed")==true or world.get("retiring")==true or not area is Dictionary:return _issue("accepted-native-world-unavailable")
	var controlled: Variant=data.get("controlledId");var controlled_source:=_known(int(controlled)) if LocalFields.uint(controlled) else {}
	var scope:=Scope.scope_value({"connection_epoch":_connection,"area_generation":client.get("epoch"),"area_id":area.get("id"),"controlled_id":controlled,"controlled_lifetime":Lifetime.token(controlled_source)})
	var width: Variant=area.get("width");var height: Variant=area.get("height");var fields: Variant=area.get("fields")
	if scope.is_empty():return _issue("accepted-native-controlled-lifetime-scope-unavailable")
	if not Scope.Tiles._integer(width,1,65536) or not Scope.Tiles._integer(height,1,65536) or width*height>65536:return _issue("accepted-native-area-dimensions-unavailable")
	if not fields is Dictionary:return _issue("accepted-native-area-fields-unavailable")
	var flags: Variant=fields.get("8")
	if not Scope.Tiles._integer(flags,-2147483648,4294967295):return _issue("accepted-native-area-field8-unavailable")
	if world.get("generation")!=scope.area_generation or world.get("area_id")!=scope.area_id or world.get("controlled_id")!=scope.controlled_id:return _issue("accepted-native-world-scope-mismatch")
	var area_scope: Array=[_connection,scope.area_generation,scope.area_id]
	_fields.bind(controlled_source);_fields.controlled_changed(scope.controlled_id,scope.controlled_lifetime)
	# Raw-only recordings and disabled native clocks cannot complete a fade.
	# Retain fresh setters for later, but never blank the previously working
	# world with a partial reveal path or substitute GUI/OS time.
	var timing:=_fade_timing()
	if timing.get("available")!=true:return _issue("native-primary-world-clock-unavailable/reveal-not-applied")
	var fresh_tiles: bool=(int(flags)&3)==0 or _area_scope==area_scope and not _states.is_empty()
	if not fresh_tiles:
		for item in _pending:
			var frame: Dictionary=item.frame
			if frame.kind=="raw-tile-visibility" and Scope.wire_scope(frame)==scope:fresh_tiles=true;break
	if not fresh_tiles:return _issue("fresh-native-map-history-unavailable/reveal-not-applied")
	var rebound: bool=_scope!=scope or _world==null or _world.get_ref()!=world
	if rebound:
		_retire_world();_world=weakref(world);_scope=scope
		if _area_scope!=area_scope:
			# Exact native area loader850120 first sets every map state0. This
			# is not the server UI automap's sticky snapshot or inferred LOS.
			_states=[];_states.resize(int(width)*int(height));_states.fill(0);_area_scope=area_scope
		_width=int(width);_height=int(height);_flags=int(flags)
		_bridge=Bridge.new()
		var bound: Dictionary=_bridge.configure(world,scope,{"width":_width,"height":_height,"flags":_flags,"states":_states},{"scope_current":_scope_current,"tile_center":_tile_center,"player_info":_player_info,"creature_fields":_creature_fields,"native_shadow_detail":_shadow_detail,"fade_timing":_fade_timing,"tile_fog":_tile_fog})
		if not bound.available:_bridge.close();_bridge=null;return bound
		# Fog remains default1 until the existing renderer supplies exact draw
		# collection order + DeltaT. Black tiles without a ramp are forbidden.
		_issue("native-draw-collected-tile-owner-unavailable/fog-kept-at-default1")
		_link(world,"instance_ready",_ready_signal);_link(world,"instance_state_changed",_state_signal);_link(world,"instance_removed",_removed_signal)
		var motion: Variant=world.get("motion")
		if is_instance_valid(motion) and motion.has_method("position_change_is_current"):_link(motion,"positions_changed",_motion_signal.bind(weakref(motion)))
		var terrain: Variant=world.get("terrain")
		if is_instance_valid(terrain):_link(terrain,"tile_published",_tile_signal)
		stats.area_bindings+=1
	var objects: Variant=data.get("objects")
	if not objects is Array:return _issue("accepted-native-object-boundary-unavailable")
	if rebound:
		# One cold scope bind visits the canonical World subset (including
		# unloaded actors), never a full-world scan on ordinary frames.
		stats.world_scans+=1
		for wanted in world.get("desired").values():
			if wanted is Dictionary and wanted.get("object") is Dictionary:_observe(wanted.object,"area-entry")
	else:
		if int(flags)!=_flags:_flags=int(flags);_bridge.set_area_flags(_flags)
		for source in objects:
			if source is Dictionary:_observe(source,"position" if _references.has(int(source.get("id",-1))) else "create")
	for value in data.get("removedObjectIds",[]):
		var id:=int(value)
		if _references.has(id):_bridge.remove(id,_references[id]);_references.erase(id)
	_drain()
	if rebound:
		for id in world.get("instances"):
			var source:=_known(int(id));_ready_signal(int(id),source,world.get("instances")[id])
	stats.accepted_worlds+=1;return {"available":true,"bound":true,"scope":_scope.duplicate(true),"fog_available":false}
func position_changed(id: int,native_position: Array) -> void:
	if _bridge==null or not _scope_current(_scope):return
	var source:=_known(id)
	if source.is_empty():return
	_bridge.observe(source,native_position,"position");stats.position_events+=1
func receive_movement(message: Dictionary) -> Dictionary:
	if _bridge==null or not _scope_current(_scope) or message.get("kind")!="movement" or message.get("connection")!=_connection or message.get("generation")!=_scope.area_generation or message.get("areaId")!=_scope.area_id or not message.get("records") is Array:return _issue("native-movement-visibility-scope-unavailable")
	var observed:=0
	for record in message.records:
		if not record is Dictionary or not LocalFields.uint(record.get("id")) or not record.get("changes") is Dictionary:return _issue("native-movement-record-unavailable")
		if not record.changes.has("position"):continue
		# The existing World.observe_movement already admitted this record.
		# Canonical received DTO may still lag until raw-world-end; resolve its
		# lifetime now, but read its native local position from the motion owner.
		var source:=_known(int(record.id))
		if source.is_empty() or not _references.has(int(record.id)) or Lifetime.token(source)!=_references[int(record.id)]:continue
		position_changed(int(record.id),_native_position(source));observed+=1
	return {"available":true,"observed":observed,"source":"existing-admitted-movement-native-position-boundary"}
func advance() -> Dictionary:
	if _bridge==null or not _scope_current(_scope):return {"available":false}
	return _bridge.advance()
func shadow_detail_changed(_detail: Variant=null) -> void:
	if _bridge==null or not _scope_current(_scope):return
	var world:=_world_current()
	# Explicit user option change only, never a per-frame installed-world scan.
	for id in world.get("instances"):
		if _references.has(id):_observe(_known(int(id)),"mode")
func receive_connection_permission(permission: bool) -> Dictionary:
	return _fields.receive_connection_permission(permission) if _ensure_connection() else {"available":false}
func snapshot() -> Dictionary:
	return {"closed":_closed,"connection":_connection,"scope":_scope.duplicate(true),"pending":_pending.size(),"units":_units,"tile_count":_states.size(),"tiles":_states.duplicate(),"references":_references.size(),"stats":stats.duplicate(),"issues":_issues.duplicate(),"fields":_fields.snapshot() if _fields!=null else {},"bridge":_bridge.snapshot() if _bridge!=null else {},"fog_available":_fog!=null,"limitations":["native-D0-shadowblob-owner","native-render-owner-virtual8","draw-collected-tile-owner","positive-DM-AI-getter-and-GUI-owner"]}
func cleanup_connection() -> void:
	_retire_world()
	if _fields!=null:_fields.close()
	_fields=null;_connection=-1;_states=[];_area_scope=[];_pending.clear();_units=0;_serials.clear();_initializer_seen=false
func close() -> void:
	cleanup_connection();_closed=true;_client=null;_ports.clear()
