extends RefCounted

# In-process counterpart of the saved native host's RawWorldDeltas. The
# receiver owns admission; this owner advances its base only on that receipt.
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_OBJECTS := 65536

class StaticRows extends RefCounted:
	var objects: Array
	var rows: Dictionary={}
	var borrows_static_nested: bool

	func _init(borrow_nested: bool=false)->void:
		borrows_static_nested=borrow_nested

	func capture(source: Dictionary,wire: Dictionary)->void:
		# The network world replaces this backing on every staged static
		# write. Registration and disclosure may change outside that stage.
		var backing: Variant=source.get("replicated")
		if not backing is Dictionary or wire.get("nativeClockOwner")!=null or not wire.get("id") is int:
			return
		rows[wire.id]=[wire,[backing,wire.get("nativeProjectileRegistration"),
			wire.get("clientKnownLifetime"),wire.get("nativeLifetime"),wire.get("replicationRemoved")]]

var base: Dictionary = {}
var pending: Dictionary = {}
var last_static_encodes_reused:=0

func reset() -> void:
	base.clear()
	pending.clear()
	last_static_encodes_reused=0

static func _safe_integer(value: Variant, minimum: int) -> bool:
	if value is int:
		return value >= minimum and value <= MAX_SAFE_INTEGER
	return value is float and is_finite(value) and value >= minimum and value <= MAX_SAFE_INTEGER and value == floorf(value)

static func _same_static_row(previous: Array,current: Array)->bool:
	return is_same(previous[0],current[0]) and previous[1]==current[1] and previous[2]==current[2] and previous[3]==current[3] and previous[4]==current[4]

func plan(connection: Variant, generation: Variant, serial: Variant, data: Variant,static_rows: StaticRows=null) -> Variant:
	last_static_encodes_reused=0
	if not pending.is_empty():
		return {"error": "Raw world update is awaiting acknowledgement"}
	if not _safe_integer(connection, 0) or not _safe_integer(generation, 0) or not _safe_integer(serial, 1) or not data is Dictionary or not data.get("objects") is Array or data.objects.size() > MAX_OBJECTS:
		return {"error": "Invalid raw delta scope"}
	var objects: Array = data.objects
	var records: Dictionary = {}
	var upserts: Array = []
	var full: bool = base.is_empty() or int(base.connection) != int(connection) or int(base.generation) != int(generation)
	var proven_objects:=static_rows!=null and is_same(static_rows.objects,objects)
	var proven: Dictionary=static_rows.rows if proven_objects else {}
	var borrow_nested:=static_rows!=null and static_rows.borrows_static_nested
	var accepted_static: Dictionary=base.get("static_rows",{}) if not full else {}
	var previous_records: Dictionary=base.get("records",{})
	var scan_removals:=not full and previous_records.size()!=objects.size()
	var next_static: Dictionary={}
	for object in objects:
		if not object is Dictionary or not _safe_integer(object.get("id"), 0):
			return {"error": "Invalid or duplicate raw object identity"}
		var id: int = int(object.id)
		if records.has(id):
			return {"error": "Invalid or duplicate raw object identity"}
		var proof: Variant=proven.get(id)
		if proof is Array and is_same(proof[0],object):
			var stamp: Array=proof[1]
			next_static[id]=stamp
			var accepted_stamp: Variant=accepted_static.get(id)
			if accepted_stamp is Array and _same_static_row(accepted_stamp,stamp):
				records[id]=previous_records[id]
				last_static_encodes_reused+=1
				continue
		var encoded: String = JSON.stringify(object, "", false, true)
		records[id] = encoded
		var previous_encoded: String=str(previous_records.get(id, "")) if not full else ""
		if full or previous_encoded != encoded:
			# A new ID can replace a removed ID without changing the row count.
			if not full and previous_encoded.is_empty():scan_removals=true
			# A private projection may share canonical static values only until
			# planning ends. Receivers can retain and mutate every upsert.
			var detach: bool=borrow_nested and (not proven_objects or proof!=null or object.get("objectType") in [9,10])
			upserts.append(object.duplicate(true) if detach else object)
	var removed: Array = []
	if scan_removals:
		for id in previous_records:
			if not records.has(id):
				removed.append(id)
	var header: Dictionary = data.duplicate()
	header.erase("objects")
	header = header.duplicate(true)
	var encoded_header: String = JSON.stringify(header, "", false, true)
	if not full and upserts.is_empty() and removed.is_empty() and encoded_header == str(base.header):
		return null
	pending = {"connection": int(connection), "generation": int(generation), "serial": int(serial), "records": records, "header": encoded_header}
	if not next_static.is_empty():pending.static_rows=next_static
	header.objects = upserts
	header.bridgeMode = "full" if full else "delta"
	header.bridgeBaseSerial = -1 if full else int(base.serial)
	header.removedObjectIds = removed
	return header

func acknowledge(connection: Variant, generation: Variant, serial: Variant) -> bool:
	if pending.is_empty() or not _safe_integer(connection, 0) or not _safe_integer(generation, 0) or not _safe_integer(serial, 1):
		return false
	if int(pending.connection) != int(connection) or int(pending.generation) != int(generation) or int(pending.serial) != int(serial):
		return false
	base = pending
	pending = {}
	return true
