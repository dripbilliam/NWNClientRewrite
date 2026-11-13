extends RefCounted
# Isolated final-collection composition. Existing owners retain camera, clock,
# tree/membership and TileData C4/C8. No World hook, clock or shader write here.
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const PHASE:="final-main-world-collection"
const MAX_COLLECTIONS:=1024
const MAX_CALLBACKS:=600000
const BEFORE_MATH:={"physical-fog-collection-format-unavailable":true,"physical-fog-collection-time-unavailable":true,"physical-fog-collected-token-unavailable":true}
var _camera: WeakRef
var _resolver: WeakRef
var _fog: WeakRef
var _scope: Dictionary={}
var _fog_scope: Array=[]
var _guard:=Callable()
var _open:=false
var _configured:=false
var _revision:=0
var _busy:=false
var _frame:=-1
var _tickets: Dictionary={}
var stats:={"attempts":0,"native_collections":0,"consumed":0,"publication_unavailable":0,"duplicates":0,"reentry":0,"preflight_unavailable":0}

func _unavailable(reason: String) -> Dictionary:
	return {"available":false,"native_collected":false,"native_consumed":false,"publication_available":false,"reason":reason}
func _owners(revision: int) -> Array:
	if not _open or revision!=_revision:return []
	var values: Array=[]
	for reference in [_camera,_resolver,_fog]:
		var value: Object=reference.get_ref() if reference!=null else null
		if not is_instance_valid(value):return []
		values.append(value)
	if values[0].get("_open")!=true or values[1].get("_open")!=true or values[2].get("_closed")!=false:return []
	if values[0].get("_scope")!=_scope or values[1].get("_scope")!=_scope or values[2].get("_scope")!=_fog_scope:return []
	return values
func _admitted(revision: int,frame: int,collection: int) -> Array:
	var owners:=_owners(revision)
	if owners.is_empty() or not _guard.is_valid():return []
	var accepted: Variant=_guard.call(_scope.duplicate(true),PHASE,frame,collection)
	var after:=_owners(revision)
	return after if accepted is bool and accepted and not after.is_empty() and after==owners else []
func configure(scope: Dictionary,fog_scope: Array,camera_boundary: RefCounted,resolver: RefCounted,fog: RefCounted,source_guard: Callable) -> Dictionary:
	if _configured or scope.is_empty() or fog_scope.is_empty() or not source_guard.is_valid():return _unavailable("physical-collection-configuration-unavailable")
	var owners: Array=[camera_boundary,resolver,fog]
	var paths: Array=["res://tools/native_parity/visibility/camera_boundary.gd","res://tools/native_parity/visibility/tile_data_fog_setter.gd","res://tools/native_parity/visibility/physical_tile_fog.gd"]
	for index in owners.size():
		if not is_instance_valid(owners[index]) or owners[index].get_script()==null or owners[index].get_script().resource_path!=paths[index]:return _unavailable("physical-collection-owner-type-unavailable")
	_scope=scope.duplicate(true);_fog_scope=fog_scope.duplicate(true);_guard=source_guard
	_camera=weakref(camera_boundary);_resolver=weakref(resolver);_fog=weakref(fog);_open=true;_revision+=1
	if _owners(_revision).is_empty():close();return _unavailable("physical-collection-physical-owner-unavailable")
	_configured=true
	return {"available":true,"phase":PHASE}

func _finish(ticket: Dictionary,result: Dictionary) -> Dictionary:
	_busy=false;result.frame=ticket.frame;result.collection=ticket.collection;result.phase=PHASE
	if not result.has("native_collected"):result.native_collected=ticket.native_collected
	if not result.has("native_consumed"):result.native_consumed=ticket.consumed
	if not result.has("publication_available"):result.publication_available=false
	result.duplicate=false;ticket.result=result.duplicate(true)
	return result
func _fail(ticket: Dictionary,reason: String) -> Dictionary:
	stats.preflight_unavailable+=1
	return _finish(ticket,{"available":false,"reason":reason})
func _physical_tokens(owners: Array,tokens: PackedInt64Array) -> bool:
	# Narrow read-only projections of the two existing physical registries.
	# These are references, not whole-registry snapshots/copies or a new store.
	var native_tiles: Variant=owners[1].get("_tiles");var fog_tiles: Variant=owners[2].get("_tiles")
	if not native_tiles is Dictionary or not fog_tiles is Dictionary:return false
	for token in tokens:
		if not Math.uint(token) or token==0:return false
		var native_tile: Variant=native_tiles.get(token);var fog_tile: Variant=fog_tiles.get(token)
		if not native_tile is Dictionary or not fog_tile is Dictionary or native_tile.get("lifetime")!=fog_tile.get("lifetime"):return false
	return true

func collect(scope: Dictionary,frame: int,collection: int,phase: String) -> Dictionary:
	if not _open or scope!=_scope or phase!=PHASE or frame<0 or collection<0:return _unavailable("physical-collection-final-boundary-unavailable")
	if _busy:stats.reentry+=1;return _unavailable("physical-collection-reentry-unavailable")
	if frame<_frame:return _unavailable("physical-collection-frame-retired")
	if frame>_frame:_frame=frame;_tickets.clear()
	var previous: Dictionary=_tickets.get(collection,{})
	if not previous.is_empty() and previous.consumed:
		stats.duplicates+=1
		var repeated: Dictionary=previous.result.duplicate(true)
		repeated.duplicate=true;repeated.replayed=false
		return repeated
	if previous.is_empty() and _tickets.size()>=MAX_COLLECTIONS:return _unavailable("physical-collection-occurrence-bound")
	var ticket:={"frame":frame,"collection":collection,"native_collected":false,"consumed":false,"result":{}}
	_tickets[collection]=ticket;_busy=true;stats.attempts+=1
	var revision:=_revision;var owners:=_admitted(revision,frame,collection)
	if owners.is_empty():return _fail(ticket,"physical-collection-source-boundary-stale")
	var receipt: Variant=owners[0].call("capture",_scope.duplicate(true),frame,collection)
	if not receipt is Dictionary or receipt.get("available")!=true:return _fail(ticket,"physical-collection-camera-source-unavailable/"+str(receipt.get("reason","unknown") if receipt is Dictionary else "unknown"))
	if not owners[0].call("current",receipt):return _fail(ticket,"physical-collection-camera-lease-stale")
	var planes:=Math.camera_planes(receipt.camera)
	if not planes.available:return _fail(ticket,"physical-collection-native-camera-planes-unavailable")
	owners=_admitted(revision,frame,collection)
	if owners.is_empty() or not owners[0].call("current",receipt):return _fail(ticket,"physical-collection-boundary-changed-before-kernel")
	var native_collection: Variant=owners[1].call("collect_bound",receipt.camera.position,planes.planes,receipt.primary_words)
	if not native_collection is Dictionary or native_collection.get("available")!=true:return _fail(ticket,"physical-collection-native-traversal-unavailable")
	ticket.native_collected=true;stats.native_collections+=1
	var captured_delta:=Math.renderer_delta_t(receipt.primary_words)
	if not captured_delta.available or native_collection.get("delta_t_word")!=receipt.delta_t_word or native_collection.delta_t_word!=Math.word(captured_delta.delta_t):return _fail(ticket,"physical-collection-renderer-delta-word-mismatch")
	var tokens: Variant=native_collection.get("tile_tokens")
	if not tokens is PackedInt64Array or tokens.size()>MAX_CALLBACKS:return _fail(ticket,"physical-collection-native-token-format-unavailable")
	var resolver_revision: Variant=owners[1].get("_revision");var fog_revision: Variant=owners[2].get("_revision")
	if not _physical_tokens(owners,tokens):return _fail(ticket,"physical-collection-fog-token-identity-unavailable")
	var current:=_admitted(revision,frame,collection)
	if current.is_empty() or current!=owners or owners[1].get("_revision")!=resolver_revision or owners[2].get("_revision")!=fog_revision or not owners[0].call("current",receipt):return _fail(ticket,"physical-collection-source-changed-before-consumption")
	# Claim this occurrence before the first possible state mutation. Reentry
	# cannot replay it. Only certified pre-math rejection below releases claim.
	ticket.consumed=true
	var before_callbacks: int=int(owners[2].get("stats").get("callbacks",0))
	var advanced: Variant=owners[2].call("advance_collected",tokens,float(captured_delta.delta_t))
	var after_callbacks: int=int(owners[2].get("stats").get("callbacks",0))
	var certified:=false;var publication:=false;var reason:="physical-collection-consumption-result-unknown-do-not-replay"
	if advanced is Dictionary:
		if BEFORE_MATH.has(advanced.get("reason")):
			ticket.consumed=false;certified=true;reason=str(advanced.reason)
		elif advanced.get("available")==true or advanced.get("reason")=="physical-fog-collection-publication-unavailable" or advanced.get("callbacks")==tokens.size():
			certified=true;publication=advanced.get("available")==true;reason="" if publication else str(advanced.get("reason","physical-collection-retired-after-consumption"))
	if ticket.consumed:stats.consumed+=1
	if ticket.consumed and not publication:stats.publication_unavailable+=1
	var final_owners:=_admitted(revision,frame,collection)
	var boundary_current: bool=not final_owners.is_empty() and final_owners==owners and bool(owners[0].call("current",receipt))
	if not boundary_current:publication=false;reason="physical-collection-source-retired-after-consumption" if ticket.consumed else "physical-collection-source-retired-before-consumption"
	return _finish(ticket,{"available":ticket.consumed and certified and publication and boundary_current,"native_consumed":ticket.consumed,"publication_available":publication,"consumption_certified":certified,"callbacks":tokens.size(),"fog_callback_counter_change":after_callbacks-before_callbacks,"delta_t_word":native_collection.delta_t_word,"reason":reason})

func snapshot() -> Dictionary:return {"open":_open,"scope":_scope.duplicate(true),"frame":_frame,"occurrences":_tickets.size(),"stats":stats.duplicate(),"production_hooks":0}
func close() -> void:
	_open=false;_revision+=1;_busy=false;_scope.clear();_fog_scope.clear();_guard=Callable();_camera=null;_resolver=null;_fog=null;_tickets.clear()
