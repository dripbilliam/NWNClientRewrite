extends RefCounted
# Original door-cursor6ece80 / area restore7e7540. Root owns hit/lifetime/scope
# checks and calls clear() on blocked input, pointer exit and scope retirement.
# One weak current physical owner; no IDs resolved into replacement lifetimes.
var _door: WeakRef
var _started:=false
var _closed:=false
var stats:={"begins":0,"ends":0,"missing_presentation":0,"unchanged":0}

func _current() -> Node3D:
	var value: Variant=_door.get_ref() if _door!=null else null
	return value if is_instance_valid(value) and value is Node3D and value.get("retired")!=true else null

func clear() -> Dictionary:
	var previous:=_current()
	_door=null
	_started=false
	if previous==null:return {"available":true,"special_transition":false,"suppress_hover":false,"reason":"no-current-door"}
	var handled: bool=previous.end_transition_hover()
	stats.ends+=1
	if not handled:stats.missing_presentation+=1
	return {"available":handled,"special_transition":false,"suppress_hover":false,"reason":"current-received-rest-restored" if handled else "native-restoration-unavailable"}

func update(door: Node3D,context: Dictionary) -> Dictionary:
	if _closed:return {"available":false,"special_transition":false,"suppress_hover":false,"reason":"hover-owner-closed"}
	if not context.get("controlled_present") is bool or not context.get("has_transition") is bool:
		clear()
		return {"available":false,"special_transition":false,"suppress_hover":false,"reason":"native-hover-context-unavailable"}
	var gate: Variant=context.get("native11c",1) # Proven native object ctor default.
	if not (gate is int or gate is float) or not is_finite(float(gate)) or float(gate)!=floor(float(gate)) or gate<0 or gate>4294967295:
		clear()
		return {"available":false,"special_transition":false,"suppress_hover":false,"reason":"native11c-unavailable"}
	var valid: bool=is_instance_valid(door) and door.get("retired")!=true and door.has_method("begin_transition_hover") and door.has_method("end_transition_hover")
	var special: bool=valid and context.controlled_present and context.has_transition and int(gate)!=0 and door.received_state in [1,2,3]
	if not special:return clear()
	if _current()==door:
		stats.unchanged+=1
		return {"available":_started,"special_transition":true,"suppress_hover":true,"cursor_id":21,"reason":"same-native-transition-hover"}
	clear()
	_door=weakref(door)
	_started=door.begin_transition_hover()
	if _current()!=door:
		_door=null
		_started=false
		return {"available":false,"special_transition":false,"suppress_hover":false,"reason":"door-retired-during-hover"}
	stats.begins+=1
	if not _started:stats.missing_presentation+=1
	# Native cursor branch suppresses normal hover even if the model has no
	# requested auxiliary animation. Report that presentation gap explicitly.
	return {"available":_started,"special_transition":true,"suppress_hover":true,"cursor_id":21,"reason":"native-Trans-auxiliary-run" if _started else "native-Trans-unavailable"}

func snapshot() -> Dictionary:
	var current:=_current()
	return {"active":current!=null,"presentation_started":_started,"closed":_closed,"object_id":int(current.object_id) if current!=null else null,"stats":stats.duplicate()}

func close() -> void:
	if _closed:return
	clear()
	_closed=true
