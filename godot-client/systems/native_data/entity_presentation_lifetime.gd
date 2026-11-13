extends RefCounted
# A render job's identity includes the received lifetime, not just appearance.
# No generated token or second entity store: absence stays explicitly absent.
static func token(source: Dictionary) -> Array:
	var result: Array=[]
	for key in ["nativeLifetime","disclosureLifetime"]:
		var value: Variant=source.get(key)
		# NetworkWorld's existing transport owner calls this clientKnownLifetime.
		# Keep the public token spelling stable for older captures/consumers.
		# A present but unavailable canonical value must not revive a stale alias.
		if key=="disclosureLifetime" and source.has("clientKnownLifetime"):value=source.clientKnownLifetime
		var valid: bool=(value is int or value is float) and is_finite(float(value)) and value>=0 and float(value)==floor(float(value))
		result.append([key,true,int(value)] if valid else [key,false,null])
	return result
static func changed(previous: Dictionary,current: Dictionary) -> bool:
	# Acquiring an explicit scope after a legacy/unscoped row also retires the
	# presentation. A missing delta must not fabricate another lifetime.
	var before:=token(previous);var after:=token(current)
	for index in after.size():
		if after[index][1] and (not before[index][1] or before[index][2]!=after[index][2]):return true
	return false
