extends RefCounted
const Values=preload("res://systems/native_data/character_record_values.gd")
static func integer(value: Variant,unknown: String="?") -> String:
	var text:=Values.integer_text(value)
	return unknown if text.is_empty() else text
static func endpoint(row: Dictionary) -> String:
	return str(row.get("host",""))+":"+integer(row.get("port"))
