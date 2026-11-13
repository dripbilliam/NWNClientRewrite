extends RefCounted
# Original Package8e4620 conditionally reads Associate. A failed read keeps
# CNWCLevelUpStats7ea7a0's -1/empty (or the prior preparation), yet returns8008.
# Save807950 uses class metadata, not familiar/companion feat ownership.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
static func verify(rules) -> Dictionary:
	var draft: Dictionary=rules.draft;var table: Dictionary=rules.tables.get("classes",{})
	var minimum:=Tables.integer(table,int(draft.get("classId",-1)),"MinAssociateLevel")
	if not minimum.ready or not minimum.ok:return {"ready":false,"reason":"The compiled class associate minimum is unavailable."}
	if (int(minimum.value)&255)!=1:return {"ready":true,"field":""}
	var arcane:=Tables.integer(table,int(draft.classId),"Arcane")
	if not arcane.ready or not arcane.ok:return {"ready":false,"reason":"The compiled class associate kind is unavailable."}
	var field: String="familiar" if int(arcane.value)!=0 else "companion"
	var value: Variant=draft.get(field);var name: Variant=draft.get(field+"Name")
	if not value is int or value< -2147483648 or value>2147483647 or not name is String:return {"ready":false,"reason":"The owned associate type/name cannot be serialized."}
	return {"ready":true,"field":field}
