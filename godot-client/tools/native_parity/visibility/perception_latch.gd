extends RefCounted
# Pure scope/latch reducer for native handler140810970. The consumer owns
# effect execution; this never mutates received state or chooses an opacity.
const SCOPE_KEYS:=["connection_epoch","area_generation","area_id","object_id","entity_lifetime"]
static func token(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length()<=256 or value is int and value>=0
static func scope_value(value: Variant) -> Dictionary:
	if not value is Dictionary:return {}
	var result:={}
	for key in SCOPE_KEYS:
		if not value.has(key):return {}
		var item: Variant=value[key]
		if key in ["connection_epoch","entity_lifetime"]:
			if not token(item):return {}
		else:
			if not (item is int or item is float) or not is_finite(float(item)) or float(item)!=floor(float(item)) or item<0 or item>4294967295:return {}
			item=int(item)
		result[key]=item
	return result
static func flags_value(value: Variant) -> Variant:
	if not value is Array or value.size()!=3:return null
	var result: Array=[]
	for flag in value:
		if flag is bool:result.append(flag)
		elif (flag is int or flag is float) and is_finite(float(flag)) and (flag==0 or flag==1):result.append(flag==1)
		else:return null
	return result
static func reduce(previous: Dictionary,scope: Variant,received_flags: Variant) -> Dictionary:
	var current:=scope_value(scope)
	var result:={"version":1,"available":false,"action":null,"reason":"scope_unavailable","state":{},"scope_reset":false}
	if current.is_empty():return result
	var old_scope:=scope_value(previous.get("scope"))
	var same:=not old_scope.is_empty() and old_scope==current
	if same and (previous.get("version")!=1 or not previous.get("latched") is bool):result.reason="previous_latch_unavailable";return result
	# The original creature constructor7fb5ed sets26c tozero. Reset only for a
	# genuinely new lifetime scope, never because the perception flags are absent.
	var latched: bool=previous.latched if same else false
	result.state={"version":1,"scope":current,"latched":latched};result.scope_reset=not same
	var flags: Variant=flags_value(received_flags)
	if flags==null:result.reason="received_visibility_triple_unavailable";return result
	result.available=true;result.reason="native_handler";result.action={"kind":"noop","visual_id":null}
	if (not flags[1] and flags[0]) or flags[2]:
		if not latched:result.action={"kind":"apply6","visual_id":6};result.state.latched=true
	elif flags[1] and not flags[2] and latched:
		result.action={"kind":"remove6","visual_id":6};result.state.latched=false
	return result
