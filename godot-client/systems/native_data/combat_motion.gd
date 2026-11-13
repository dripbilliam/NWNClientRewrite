extends RefCounted
# This is the native motion owner's remaining-path state, not an inference from
# an attack code, target or authoritative position. Unknown is distinct from0.
static func remaining_path(state: Dictionary) -> Variant:
	var path: Variant=state.get("path")
	var cursor: Variant=state.get("cursor")
	var active: Variant=state.get("active")
	# Live NetworkMotion rows use an integer cursor. Keep the full validation
	# below for imported/malformed states, including integral float cursors.
	if path is Array and cursor is int and active is bool and cursor>=0 and cursor<=path.size():
		return active and cursor<path.size()
	if not path is Array or not active is bool or not (cursor is int or cursor is float): return null
	if not is_finite(float(cursor)) or float(cursor)!=floor(float(cursor)) or float(cursor)<0 or float(cursor)>path.size(): return null
	return active and int(cursor)<path.size()
