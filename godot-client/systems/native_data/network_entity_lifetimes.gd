extends RefCounted
# Client-known disclosure runs, separate from server IDs and native lifetimes.
# The World caller supplies a stable private Handle for each canonical object.
const MAX:=9007199254740991
class Handle extends RefCounted:
	var id: int
	func _init(object_id: int)->void:id=object_id
static func make_handle(object_id: int)->Handle:return Handle.new(object_id)
static func _safe(value: Variant)->bool:return (value is int or value is float and is_finite(value) and floor(value)==value) and value>=1 and value<=MAX
var maximum_serial:=MAX
var serial:=0
var identities: Dictionary={}
var diagnostics: Dictionary={}
var error: String=""
func _init(options: Dictionary={}) -> void:
	var bound: Variant=options.get("maximumSerial",MAX)
	if not _safe(bound):error="Invalid disclosure counter limit";return
	maximum_serial=int(bound)
func note(code: String)->void:diagnostics[code]=mini(65535,int(diagnostics.get(code,0))+1)
func _sweep_expired()->void:
	for key in identities.keys():
		var reference: WeakRef=identities[key].get("ref")
		if reference==null or reference.get_ref()==null:identities.erase(key)
func reset()->void:
	identities.clear()
	note("resets")
func _entry(handle: Variant)->Dictionary:
	if not handle is Object or not is_instance_valid(handle):return {}
	var entry: Dictionary=identities.get(handle.get_instance_id(),{})
	if entry.is_empty():return {}
	var reference: WeakRef=entry.get("ref")
	return entry if reference!=null and reference.get_ref()==handle else {}
func token(handle: Variant,row: Variant)->Variant:
	if not handle is Object or not is_instance_valid(handle) or not row is Dictionary:
		note("invalidSource");return null
	if row.get("replicationRemoved",false):return null
	var entry:=_entry(handle)
	if not entry.is_empty():return entry.token
	if serial>=maximum_serial:
		note("exhausted");return null
	serial+=1
	if (serial&255)==0:_sweep_expired()
	identities[handle.get_instance_id()]={"ref":weakref(handle),"token":serial}
	return serial
func transport_row(handle: Variant,row: Dictionary)->Dictionary:
	var result:=row.duplicate()
	result.clientKnownLifetime=token(handle,row)
	return result
func observe_accepted(records: Variant,resolve_canonical: Callable)->void:
	# Only the World caller invokes this after its canonical transaction commits.
	if not records is Array or not resolve_canonical.is_valid():
		note("invalidBoundary");return
	for record in records:
		if not record is Dictionary or record.get("action")!="delete":continue
		var handle: Variant=resolve_canonical.call(record.get("id"))
		if not handle is Object or not is_instance_valid(handle):continue
		var key: int=int(handle.get_instance_id())
		if not _entry(handle).is_empty():
			identities.erase(key);note("retired")
func snapshot()->Dictionary:
	_sweep_expired()
	return {"serial":serial,"maximumSerial":maximum_serial,"diagnostics":diagnostics.duplicate()}
