extends RefCounted
# A read model over canonical owners. Only identity/filter metadata lives here.
const Detached=preload("res://systems/client_api/detached.gd")
const INVALID_OBJECT:=0x7f000000
const TYPE_NAMES:={3:"module",4:"area",5:"creature",6:"item",7:"trigger",8:"projectile",9:"placeable",10:"door",11:"area_of_effect",12:"waypoint",13:"encounter",14:"store",15:"portal",16:"sound"}
signal entity_added(event: Dictionary)
signal entity_updated(event: Dictionary)
signal entity_removed(event: Dictionary)
signal controlled_entity_changed(event: Dictionary)
signal scope_changed(event: Dictionary)
var _received_lookup: Callable
var _presentation_lookup: Callable
var _known: Dictionary={}
var _scope_id:=0
var _next_lifetime:=1
var _revision:=0
var _scope: Dictionary={"active":false,"connection":null,"area_generation":null,"area_id":null,"scope_id":0}
var _controlled_id: Variant=null
var _player_identity: Dictionary={"available":false,"reason":"identity_not_received"}
var _publishing:=false
var _metrics:={"boundaries":0,"source_rows":0,"full_removal_visits":0,"lookups":0,"snapshots":0,"presentation_records":0}

static func valid_id(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff and int(value)!=INVALID_OBJECT

static func _integer(value: Variant) -> Variant:
	return int(value) if (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) else null

static func _source_token(source: Dictionary) -> Variant:
	if source.has("clientKnownLifetime"):
		var disclosure: Variant=_integer(source.clientKnownLifetime)
		# An explicit but unusable tagged token must never silently use renderer
		# identity. The binding rejects it; its session observer invalidates only
		# this API scope, preserving canonical application/ACK behavior.
		return "client_disclosure:"+str(disclosure) if disclosure!=null and disclosure>0 and disclosure<=9007199254740991 else null
	var token: Variant=_integer(source.get("nativeLifetime"))
	return "renderer:"+str(token) if token!=null and token>0 else null

func _bind_sources(received_lookup: Callable,presentation_lookup: Callable) -> void:
	_received_lookup=received_lookup; _presentation_lookup=presentation_lookup

func get_scope() -> Dictionary: return Detached.copy(_scope)
func diagnostics() -> Dictionary:
	var result: Dictionary=Detached.copy(_metrics)
	result.known=_known.size(); result.next_lifetime=_next_lifetime; result.revision=_revision
	return result

func _reference(id: int) -> Variant:
	if not _known.has(id): return null
	return {"api_instance":get_instance_id(),"scope_id":_scope_id,"connection":_scope.connection,"area_generation":_scope.area_generation,"area_id":_scope.area_id,"object_id":id,"lifetime":_known[id].lifetime}

func get_reference(object_id: Variant) -> Variant: return _reference(int(object_id)) if valid_id(object_id) else null

func _matches(reference: Dictionary) -> bool:
	var id: Variant=reference.get("object_id")
	return valid_id(id) and _known.has(int(id)) and reference==_reference(int(id))

func resolve(reference: Variant,include_presentation: bool=true,copy_budget: Dictionary={}) -> Variant:
	return get_by_id(int(reference.object_id),include_presentation,copy_budget) if reference is Dictionary and _matches(reference) else null

func _raw(id: int) -> Variant:
	if not _received_lookup.is_valid(): return null
	_metrics.lookups+=1
	var value: Variant=_received_lookup.call(id)
	if not value is Dictionary or not valid_id(value.get("id")) or int(value.id)!=id or value.get("replicationRemoved",false): return null
	if _known[id].source_lifetime!=null and _source_token(value)!=_known[id].source_lifetime: return null
	return value

static func _field(source: Dictionary,key: String) -> Dictionary:
	return {"available":source.has(key),"value":source.get(key)}

func get_by_id(object_id: Variant,include_presentation: bool=true,copy_budget: Dictionary={}) -> Variant:
	if not valid_id(object_id): return null
	object_id=int(object_id)
	if not _known.has(object_id): return null
	var source: Variant=_raw(object_id)
	if source==null: return null
	_metrics.snapshots+=1
	var unavailable: Array=[]
	var received_value: Variant=Detached.copy(source,unavailable,"received",[],copy_budget)
	if copy_budget.get("exceeded",false): return null
	var received: Dictionary=received_value
	# This cache initializes bonuses/dex to zero locally; it is not direct wire
	# evidence for those stats. Preserve it separately with explicit provenance.
	var ability_cache:=_field(received,"clientAbilityCache")
	ability_cache.source="client_initialized_ability_cache"
	var disclosure_lifetime:=_field(received,"clientKnownLifetime")
	disclosure_lifetime.source="client_disclosure_run"
	var skill_admission:=_field(received,"clientSkillAdmission")
	skill_admission.source="client_received_skill_cache"
	received.erase("clientAbilityCache")
	received.erase("clientKnownLifetime")
	received.erase("clientSkillAdmission")
	for index in unavailable.size():
		for pair in [["clientAbilityCache","ability_cache"],["clientKnownLifetime","disclosure_lifetime"],["clientSkillAdmission","skill_admission"]]:
			if str(unavailable[index]).begins_with("received."+pair[0]):unavailable[index]=str(unavailable[index]).replace("received."+pair[0],"client_data."+pair[1]+".value")
	var replicated: Dictionary=received.get("replicated",{}) if received.get("replicated") is Dictionary else {}
	var character: Dictionary={}
	for pair in [["stats",replicated,"stats"],["inventory_stats",received,"inventoryStats"],["player_state",received,"playerState"]]:
		character[pair[0]]=_field(pair[1],pair[2])
	var has_character: bool=character.values().any(func(field):return field.available)
	var result:={"api_version":1,"reference":_reference(object_id),"revision":_known[object_id].revision,"identity":{"object_id":object_id,"object_type":_field(received,"objectType"),"type_name":TYPE_NAMES.get(_integer(received.get("objectType")),"unknown") if received.has("objectType") else null,"area_id":_field(received,"areaId"),"name":_field(replicated,"name"),"source_lifetime":_field(received,"nativeLifetime")},"appearance":_field(received,"appearance"),"replicated":_field(received,"replicated"),"character":{"available":has_character,"value":character if has_character else null},"received":{"source":"client_received_read_model","provenance":"decoded_and_merged_server_data_with_client_metadata","boundary_revision":_known[object_id].revision,"value":received},"client_data":{"ability_cache":ability_cache,"disclosure_lifetime":disclosure_lifetime,"skill_admission":skill_admission},"presentation":{"available":false,"reason":"not_requested" if not include_presentation else "presentation_not_known","value":null},"unavailable_paths":unavailable}
	if include_presentation and _presentation_lookup.is_valid():
		var motion: Variant=_presentation_lookup.call(object_id)
		if motion is Dictionary and not motion.is_empty():
			var fields: Dictionary={}
			for key in ["lifetime","position","render","orientation","targetOrientation","animation","active","driveHeld","previewBase","path","cursor"]:
				if motion.has(key): fields[key]=Detached.copy(motion[key],unavailable,"presentation."+key,[],copy_budget)
			result.presentation={"available":true,"source":"client_simulated","coordinates":"NWN","sample_ticks_usec":Time.get_ticks_usec(),"input_revision":_known[object_id].presentation_revision,"value":fields}
	return null if copy_budget.get("exceeded",false) else result

func list_references(filters: Dictionary={}) -> Array:
	var result: Array=[]
	if filters.has("object_types") and not filters.object_types is Array: return result
	for id in _known:
		var entry: Dictionary=_known[id]
		if filters.has("object_type") and entry.object_type!=filters.object_type: continue
		if filters.has("object_types") and not filters.object_types.has(entry.object_type): continue
		if filters.get("current_area",false) and entry.area_id!=_scope.area_id: continue
		if filters.has("area_id") and entry.area_id!=filters.area_id: continue
		result.append(_reference(int(id)))
	result.sort_custom(func(a,b):return int(a.object_id)<int(b.object_id))
	return result

func list_entities(filters: Dictionary={},include_presentation: bool=true) -> Array:
	var result: Array=[]
	for reference in list_references(filters):
		var entity: Variant=resolve(reference,include_presentation)
		if entity!=null: result.append(entity)
	return result

func page_references(filters: Dictionary={},after_id: int=-1,limit: int=50) -> Dictionary:
	# Scan compact metadata on request, retaining at most limit+1 IDs. No full
	# reference array or entity payloads are copied to serve a bounded REST page.
	var ids: Array[int]=[]
	if limit<1 or limit>100 or filters.has("object_types") and not filters.object_types is Array: return {"items":[],"has_more":false}
	for id in _known:
		if int(id)<=after_id: continue
		var entry: Dictionary=_known[id]
		if filters.has("object_type") and entry.object_type!=filters.object_type: continue
		if filters.has("object_types") and not filters.object_types.has(entry.object_type): continue
		if filters.get("current_area",false) and entry.area_id!=_scope.area_id: continue
		if filters.has("area_id") and entry.area_id!=filters.area_id: continue
		if ids.size()==limit+1 and int(id)>=ids[-1]: continue
		ids.insert(ids.bsearch(int(id)),int(id))
		if ids.size()>limit+1: ids.pop_back()
	var has_more:=ids.size()>limit
	if has_more: ids.pop_back()
	var references: Array=[]
	for id in ids: references.append(_reference(id))
	return {"items":references,"has_more":has_more}

func get_controlled(include_presentation: bool=true,copy_budget: Dictionary={}) -> Dictionary:
	return _identity_result(_controlled_id,"control_not_received",include_presentation,copy_budget)

func get_player_character(include_presentation: bool=true,copy_budget: Dictionary={}) -> Dictionary:
	if not _player_identity.get("available",false):
		return {"available":false,"object_id":null,"reference":null,"entity":null,"reason":_player_identity.get("reason","identity_not_received")}
	var result:=_identity_result(_player_identity.get("object_id"),"identity_not_received",include_presentation,copy_budget)
	result.provenance=_player_identity.get("provenance")
	return result

func _identity_result(id: Variant,missing_reason: String,include_presentation: bool=true,copy_budget: Dictionary={}) -> Dictionary:
	if not valid_id(id): return {"available":false,"object_id":null,"reference":null,"entity":null,"reason":missing_reason}
	var entity: Variant=get_by_id(int(id),include_presentation,copy_budget)
	return {"available":entity!=null,"object_id":int(id),"reference":_reference(int(id)) if entity!=null else null,"entity":entity,"reason":null if entity!=null else "entity_not_known"}

func _control_marker() -> Dictionary:
	return {"object_id":_controlled_id,"reference":_reference(int(_controlled_id)) if valid_id(_controlled_id) else null}

func _remove(id: int,reason: String,events: Array) -> void:
	if not _known.has(id): return
	events.append({"reference":_reference(id),"object_id":id,"reason":reason,"revision":_revision})
	_known.erase(id)

func _publish(previous_scope: Dictionary,removed: Array,added: Array,updated: Array,previous_control: Dictionary) -> void:
	_publishing=true
	# Check each emission: an earlier callback can connect/disconnect listeners.
	# Unobserved events need no detached/frozen payload, but registry publication
	# and its reentrancy guard retain the same synchronous boundary.
	if previous_scope!=_scope and scope_changed.has_connections(): scope_changed.emit(Detached.event({"previous":previous_scope,"current":_scope,"revision":_revision}))
	for event in removed:
		if entity_removed.has_connections(): entity_removed.emit(Detached.event(event))
	for id in added:
		if entity_added.has_connections(): entity_added.emit(Detached.event({"reference":_reference(id),"object_id":id,"revision":_revision,"source":"received"}))
	for id in updated:
		if entity_updated.has_connections(): entity_updated.emit(Detached.event({"reference":_reference(id),"object_id":id,"revision":_revision,"source":"received"}))
	var control:=_control_marker()
	if previous_control!=control and controlled_entity_changed.has_connections(): controlled_entity_changed.emit(Detached.event({"previous":previous_control,"current":control,"revision":_revision}))
	_publishing=false

func _apply_boundary(connection: int,generation: int,area_id: int,controlled: Variant,objects: Array,removed_ids: Array,full: bool,player_identity: Dictionary={}) -> bool:
	if _publishing or connection<0 or generation<0 or not valid_id(area_id) or not _received_lookup.is_valid(): return false
	for object in objects:
		if object is Dictionary and not object.get("replicationRemoved",false) and object.has("clientKnownLifetime") and _source_token(object)==null: return false
	if _scope.active and (connection<int(_scope.connection) or connection==int(_scope.connection) and generation<int(_scope.area_generation)): return false
	var changing_scope: bool=not _scope.active or connection!=_scope.connection or generation!=_scope.area_generation or area_id!=_scope.area_id
	if changing_scope and not full: return false
	var previous_scope: Dictionary=Detached.copy(_scope); var previous_control:=_control_marker()
	var removed: Array=[]; var added: Array=[]; var updated: Array=[]
	_revision+=1; _metrics.boundaries+=1
	if changing_scope:
		for id in list_references(): _remove(int(id.object_id),"scope_changed",removed)
		_scope_id+=1; _scope={"active":true,"connection":connection,"area_generation":generation,"area_id":area_id,"scope_id":_scope_id}
		_player_identity={"available":false,"reason":"identity_not_received"}
	for id in removed_ids:
		if valid_id(id): _remove(int(id),"removed",removed)
	var rows: Dictionary={}
	for object in objects:
		_metrics.source_rows+=1
		if object is Dictionary and valid_id(object.get("id")): rows[int(object.id)]=object
	if full:
		for id in _known.keys():
			_metrics.full_removal_visits+=1
			if not rows.has(id): _remove(int(id),"full_absent",removed)
	var ids:=rows.keys(); ids.sort()
	for id in ids:
		var object: Dictionary=rows[id]
		if object.get("replicationRemoved",false): _remove(id,"replication_removed",removed); continue
		var token: Variant=_source_token(object)
		if _known.has(id) and (token==null or token!=_known[id].source_lifetime): _remove(id,"identity_replaced",removed)
		if not _known.has(id):
			_known[id]={"lifetime":_next_lifetime,"source_lifetime":token,"object_type":_integer(object.get("objectType")),"area_id":_integer(object.get("areaId")),"revision":_revision,"presentation_revision":-1}
			_next_lifetime+=1; added.append(id)
		else:
			_known[id].object_type=_integer(object.get("objectType")); _known[id].area_id=_integer(object.get("areaId")); _known[id].revision=_revision; updated.append(id)
	_controlled_id=int(controlled) if valid_id(controlled) else null
	if not player_identity.is_empty():
		_player_identity=Detached.copy(player_identity) if player_identity.get("available",false) and valid_id(player_identity.get("object_id")) and player_identity.get("provenance") is String and not str(player_identity.provenance).is_empty() else {"available":false,"reason":"identity_not_received"}
	removed.sort_custom(func(a,b):return int(a.object_id)<int(b.object_id))
	_publish(previous_scope,removed,added,updated,previous_control)
	return true

func _reset(reason: String="session_reset") -> bool:
	if _publishing: return false
	var previous_scope: Dictionary=Detached.copy(_scope); var previous_control:=_control_marker(); var removed: Array=[]
	_revision+=1
	for reference in list_references(): _remove(int(reference.object_id),reason,removed)
	_scope_id+=1; _scope={"active":false,"connection":null,"area_generation":null,"area_id":null,"scope_id":_scope_id}
	_controlled_id=null; _player_identity={"available":false,"reason":"identity_not_received"}
	_publish(previous_scope,removed,[],[],previous_control)
	return true

func _presentation_records(connection: int,generation: int,area_id: int,records: Array) -> bool:
	if _publishing or not _scope.active or connection!=_scope.connection or generation!=_scope.area_generation or area_id!=_scope.area_id: return false
	var ids: Dictionary={}
	for record in records:
		_metrics.presentation_records+=1
		if not record is Dictionary or not valid_id(record.get("id")) or not _known.has(int(record.id)): continue
		var input_revision: Variant=_integer(record.get("revision")); var id:=int(record.id)
		if input_revision==null or input_revision<=_known[id].presentation_revision: continue
		_known[id].presentation_revision=input_revision; ids[id]=true
	_publishing=true
	var ordered:=ids.keys(); ordered.sort()
	for id in ordered:
		if entity_updated.has_connections(): entity_updated.emit(Detached.event({"reference":_reference(id),"object_id":id,"revision":_revision,"input_revision":_known[id].presentation_revision,"source":"presentation_input"}))
	_publishing=false
	return true
