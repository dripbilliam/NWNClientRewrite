extends RefCounted
# Internal publication adapter. Consumers use ClientAPI.entities, never this owner.
var _entities: RefCounted
func _init(entities: RefCounted) -> void: _entities=entities
func bind_sources(received_lookup: Callable,presentation_lookup: Callable=Callable()) -> void:
	_entities._bind_sources(received_lookup,presentation_lookup)
func commit(connection: int,generation: int,area_id: int,data: Dictionary,player_identity: Dictionary={}) -> bool:
	# The source owner must finish applying these full object rows before commit.
	if str(data.get("bridgeMode","full")) not in ["full","delta"] or not data.get("objects",[]) is Array or not data.get("removedObjectIds",[]) is Array: return false
	return _entities._apply_boundary(connection,generation,area_id,data.get("controlledId"),data.get("objects",[]),data.get("removedObjectIds",[]),str(data.get("bridgeMode","full"))=="full",player_identity)
func reset(reason: String="session_reset") -> bool: return _entities._reset(reason)
func begin_entry_commit(connection: int,generation: int,area_id: int,data: Dictionary,player_identity: Dictionary={}) -> bool:
	if str(data.get("bridgeMode","full"))!="full" or not data.get("objects",[]) is Array or not data.get("removedObjectIds",[]) is Array:return false
	return _entities._begin_entry_boundary(connection,generation,area_id,data.get("controlledId"),data.get("objects",[]),player_identity)
func entry_commit_step() -> Dictionary:return _entities._entry_boundary_step()
func entry_commit_steps(deadline_usec: int,max_steps: int=64) -> Dictionary:return _entities._entry_boundary_steps(deadline_usec,max_steps)
func cancel_entry_commit() -> void:_entities._cancel_entry_boundary()
func presentation_records(connection: int,generation: int,area_id: int,records: Array) -> bool:
	return _entities._presentation_records(connection,generation,area_id,records)
