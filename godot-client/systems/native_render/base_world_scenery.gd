extends RefCounted
# Scheduling classification only. Never changes usability, state, rendering,
# collision or the canonical registry. Unknown provenance stays explicit.
static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=low and float(value)<=high
static func vector(value: Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for part in value:
		if not (part is int or part is float) or not is_finite(float(part)):return false
	return true
static func classify(row: Dictionary, area_id: int) -> Dictionary:
	if not integer(row.get("id"),0,4294967295) or not integer(row.get("objectType"),0,255):return {"available":false,"base":false,"reason":"identity-unavailable"}
	if not integer(row.get("areaId"),0,4294967295):return {"available":false,"base":false,"reason":"area-unavailable"}
	if int(row.areaId)!=area_id or row.get("replicationRemoved",false) or row.get("destroyed",false):return {"available":true,"base":false,"reason":"outside-current-world"}
	if int(row.objectType)!=9:return {"available":true,"base":false,"reason":"not-placeable-geometry"}
	var fixed: Variant=row.get("staticState")
	if not fixed is Dictionary:
		var live: Variant=row.get("replicated",{})
		if not row.has("staticState") and live is Dictionary:
			var usable: Variant=live.get("field264",row.get("nativeUseable264",row.get("usable")))
			if (usable is bool or integer(usable,0,4294967295)) and usable:return {"available":true,"base":false,"reason":"received-live-usability"}
		return {"available":false,"base":false,"reason":"clientarea-static-provenance-unavailable"}
	if not integer(fixed.get("id"),0,4294967295) or int(fixed.id)!=int(row.id) or not integer(fixed.get("appearance"),0,65535) or not vector(fixed.get("position")) or not vector(fixed.get("orientation")):
		return {"available":false,"base":false,"reason":"malformed-clientarea-static-record"}
	var state: Variant=row.get("replicated",{})
	var authored: Variant=row.get("authored",{})
	if not state is Dictionary or not authored is Dictionary:return {"available":false,"base":false,"reason":"malformed-live-metadata"}
	# Contradictory explicit live usability cannot be reclassified as base scenery.
	# No missing Useable field is converted into false; static provenance itself
	# comes from the dedicated received ClientArea.staticPlaceables list.
	for usable in [state.get("field264"),row.get("nativeUseable264"),row.get("usable"),authored.get("Useable")]:
		if usable==null:continue
		if not usable is bool and not integer(usable,0,4294967295):return {"available":false,"base":false,"reason":"usability-unavailable"}
		if usable:return {"available":false,"base":false,"reason":"contradictory-live-usability"}
	return {"available":true,"base":true,"reason":"received-clientarea-static-geometry"}

# Called only when the existing receive filter excludes a row. A positive
# staticState marker is source provenance even when its required pose is absent.
# Explicit removal/other-area/other-kind records retire the omission normally.
static func omitted_reason(row: Dictionary,area_id: int) -> String:
	if not row.has("staticState") or row.get("replicationRemoved",false) or row.get("destroyed",false):return ""
	if integer(row.get("objectType"),0,255) and int(row.objectType)!=9:return ""
	if integer(row.get("areaId"),0,4294967295) and int(row.areaId)!=area_id:return ""
	var classification:=classify(row,area_id)
	return "renderer-pose-unavailable" if classification.base else str(classification.reason)
