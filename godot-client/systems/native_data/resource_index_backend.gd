extends RefCounted
# Small selection boundary around the compiled metadata parser and file stat. The script
# parser remains a reference/fallback for platforms without the extension.
static var _file_stamp_available: Variant=null
static func available() -> bool:
	return OS.get_environment("NWN_RESOURCE_INDEX")!="gd" and ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"entries")
static func parse(kind: String,table: PackedByteArray,other: PackedByteArray=PackedByteArray(),options: Dictionary={}) -> Dictionary:
	return ClassDB.class_call_static(&"NwnResourceIndex",&"entries",kind,table,other,options)
static func retained_cost(value: Variant,maximum_bytes: int) -> Dictionary:
	if not accounting_available(): return {}
	return ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost",value,maximum_bytes)
static func accounting_available() -> bool:
	return OS.get_environment("NWN_RESOURCE_ACCOUNTING")!="serialized" and ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"retained_cost")
static func two_da_available() -> bool:
	return OS.get_environment("NWN_RESOURCE_2DA")!="gd" and ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"two_da")
static func two_da(text: String) -> Dictionary:
	return ClassDB.class_call_static(&"NwnResourceIndex",&"two_da",text)
static func file_stamp_available() -> bool:
	if _file_stamp_available==null:_file_stamp_available=ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"file_stamp")
	return bool(_file_stamp_available)
static func file_stamp(path: String) -> Dictionary:
	if not file_stamp_available(): return {"error":"Native high-resolution file stamp is unavailable"}
	var result: Dictionary=ClassDB.class_call_static(&"NwnResourceIndex",&"file_stamp",path)
	if result.has("error"): return result
	return {"size":int(result.size),"modified":int(result.modified_ticks)}
