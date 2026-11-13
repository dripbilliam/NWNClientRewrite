extends RefCounted
signal changed
# Private logical modal order. Optional/unintegrated until native owners opt in.
# A canvas layer, visible flag or unregistered window never establishes coverage.
const LIMIT:=64
const MAX_SERIAL:=9007199254740991
var _records: Array=[]
var _serial:=0
var _epoch:=1
var _coverage:=false
var _closed:=false
var diagnostics: Dictionary={}
var _callback_owner:=0
var _callback_epoch:=0
func note(code: String) -> void: diagnostics[code]=mini(65535,int(diagnostics.get(code,0))+1)
func set_membership_coverage(known: bool) -> void:
	if not _closed: _coverage=known
func flat_scope(value: Array) -> bool:
	return value.all(func(v):return v==null or v is bool or v is int or v is String or v is float and is_finite(v))
func unavailable(reason: String) -> Dictionary:
	note(reason); return {"available":false,"reason":reason}
func activate(owner: Object,kind: String,lifetime: int,scope: Array=[],deactivate: Callable=Callable(),superseded: Callable=Callable()) -> Dictionary:
	if _closed: return unavailable("closed")
	if not is_instance_valid(owner) or kind not in ["Rmnu","other","unknown"] or lifetime<=0 or lifetime>MAX_SERIAL or not flat_scope(scope):
		_coverage=false; return unavailable("unsupported_activation")
	var owner_id:=owner.get_instance_id(); var existing: Dictionary={}
	var activation_epoch:=_epoch
	for row in _records:
		if int(row.ticket.owner)==owner_id:
			if row.ticket.lifetime==lifetime and row.ticket.scope==scope:
				if row.kind!=kind: _coverage=false; return unavailable("changed_type")
				existing=row
			break
	if not existing.is_empty() and not _records.is_empty() and is_same(_records.back(),existing): return existing.ticket.duplicate(true)
	# Original1f66f0 notifies only the former top, removes an incoming lower
	# owner, then appends it. Re-activation is promotion, not a new lifetime.
	if not _records.is_empty():
		var old: Dictionary=_records.back()
		if old.superseded.is_valid(): old.superseded.call(old.ticket.duplicate(true))
	if _closed or _epoch!=activation_epoch or not is_instance_valid(owner): return unavailable("retired_during_activation")
	# A notification may replace the incoming owner's lifetime reentrantly.
	# Never append the captured old record over that new owner.
	for current in _records:
		if int(current.ticket.owner)==owner_id and (current.ticket.lifetime!=lifetime or current.ticket.scope!=scope):
			return unavailable("replaced_during_activation")
	_records=_records.filter(func(row):return int(row.ticket.owner)!=owner_id)
	if existing.is_empty():
		if _records.size()>=LIMIT or _serial>=MAX_SERIAL:
			_coverage=false; return unavailable("capacity")
		_serial+=1
		existing={"owner":weakref(owner),"kind":kind,"deactivate":deactivate,"superseded":superseded,"ticket":{"registry":get_instance_id(),"epoch":_epoch,"serial":_serial,"owner":owner_id,"lifetime":lifetime,"scope":scope.duplicate(true)}}
	_records.append(existing)
	changed.emit()
	return existing.ticket.duplicate(true)
func retire(ticket: Variant) -> bool:
	if _closed or not ticket is Dictionary: return false
	for index in _records.size():
		if _records[index].ticket==ticket:
			_records.remove_at(index); changed.emit(); return true
	return false
func admits(ticket: Dictionary) -> bool:
	if _closed or ticket.is_empty() or _records.is_empty(): return false
	var current: Dictionary=_records.back()
	return current.owner.get_ref()!=null and current.ticket==ticket
func callback_owner(ticket: Dictionary) -> bool:
	# Original guard is the GUI object pointer, not a per-open request ID.
	return not _closed and _callback_epoch==_epoch and _callback_owner==int(ticket.get("owner",0))
func with_callback(ticket: Dictionary,callback: Callable) -> Variant:
	if not admits(ticket) or not callback.is_valid(): return null
	var previous_owner:=_callback_owner;var previous_epoch:=_callback_epoch;var epoch_before:=_epoch
	_callback_owner=int(ticket.owner);_callback_epoch=_epoch
	var result: Variant=callback.call()
	# This scope covers the synchronous invocation only, never an awaited tail.
	if _epoch==epoch_before and not _closed:
		_callback_owner=previous_owner;_callback_epoch=previous_epoch
	else:
		_callback_owner=0;_callback_epoch=0
	return result
func top() -> Dictionary:
	if _closed: return unavailable("closed")
	if not _coverage: return unavailable("membership_unavailable")
	if _records.is_empty(): return {"available":true,"empty":true}
	var row: Dictionary=_records.back()
	# A missing retirement callback must not expose a lower wheel as top.
	if row.owner.get_ref()==null: return unavailable("owner_unavailable")
	if row.kind=="unknown": return unavailable("type_unavailable")
	return {"available":true,"empty":false,"kind":row.kind,"ticket":row.ticket.duplicate(true)}
func deactivate_for_panel(panel: int) -> Dictionary:
	if panel<16 or panel>22: return {"deactivationRequested":false,"reason":"unsupported_panel"}
	var current:=top()
	if not current.available or current.get("empty",false) or current.get("kind")!="Rmnu": return {"deactivationRequested":false,"reason":current.get("reason","top_not_radial")}
	var row: Dictionary=_records.back()
	if not row.deactivate.is_valid():
		_coverage=false; return {"deactivationRequested":false,"reason":"deactivate_unavailable"}
	var ticket: Dictionary=row.ticket.duplicate(true)
	# Retire before the callback: it may replace/reopen the same owner. An old
	# completion must never remove the new modal or close a second lower owner.
	_records.pop_back(); changed.emit(); row.deactivate.call(ticket.duplicate(true))
	return {"deactivationRequested":true,"ticket":ticket}
func snapshot() -> Dictionary:
	return {"closed":_closed,"membership_available":_coverage,"epoch":_epoch,"serial":_serial,"records":_records.map(func(row):return {"kind":row.kind,"ticket":row.ticket.duplicate(true),"owner_available":row.owner.get_ref()!=null}),"diagnostics":diagnostics.duplicate()}
func reset() -> void:
	if _closed: return
	_epoch+=1; _records.clear(); _coverage=false;_callback_owner=0;_callback_epoch=0;changed.emit()
func close() -> void:
	if _closed: return
	_closed=true; _epoch+=1; _records.clear(); _coverage=false;_callback_owner=0;_callback_epoch=0;changed.emit()
