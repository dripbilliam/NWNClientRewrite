extends RefCounted
# Client selection projection of received state. Keep the authoritative world
# registry intact; never infer usability from a model name or visual effect.
static func eligible(object: Dictionary,area_id: int) -> bool:
	if object.is_empty() or object.get("replicationRemoved",false) or object.get("destroyed",false) or int(object.get("areaId",-1))!=area_id: return false
	match int(object.get("objectType",0)):
		5,10: return true
		6:
			var location: Variant=object.get("inventoryLocation")
			return not (location is Dictionary and location.get("channel")) and not object.get("equipped",false)
		7:
			var state: Dictionary=object.get("replicated",{})
			return state.get("hasTransition",false) and not state.get("isTrap",false)
		9:
			if object.has("staticState") and object.staticState!=null: return false
			var state: Dictionary=object.get("replicated",{})
			var usable: Variant=state.get("field264")
			if usable==null: usable=object.get("nativeUseable264")
			if usable==null: usable=object.get("usable")
			if usable==null: usable=object.get("authored",{}).get("Useable",false)
			return true if usable else false
	return false
