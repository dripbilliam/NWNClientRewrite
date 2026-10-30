extends RefCounted
# Client-formatted game values only. Keep protocol/calculation values intact;
# diagnostics, versions and server-authored prose never pass through this helper.
static func text(value: Variant,unknown: String="—") -> String:
	if value is int: return str(value)
	if value is float: return str(int(value)) if is_finite(value) else unknown
	if value is String:
		if value.is_valid_int(): return str(value.to_int())
		if value.is_valid_float(): return text(value.to_float(),unknown)
		return value # Counts may carry authored markers, e.g. infinity or 3/5.
	return unknown
static func tenths(value: Variant,unknown: String="—") -> String:
	# Network examine weights are in tenths of a pound. Convert units before
	# truncating for display, just as inventory's whole-pound display does.
	return text(float(value)/10.0,unknown) if value is int or value is float else unknown
