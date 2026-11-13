extends RefCounted
# Detached spell-name text for the existing BIC worker. No live TalkText or
# mutable TLK/file handles cross the worker boundary.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
var names: Dictionary={}
var revision: Variant=null
var failure:=""
func raw(value: Dictionary) -> String:
	var id:=int(value.get("strRef",4294967295))&0xffffffff
	if not names.has(id):failure="A spell-name reference changed after its save snapshot.";return ""
	return str(names[id])
func is_complete() -> bool:return failure.is_empty()
static func capture(rules,text) -> Dictionary:
	if text==null or not text.has_method("raw") or not rules.tables.get("spells") is Dictionary:return {"ready":false,"reason":"Active spell-name data is unavailable."}
	var result=load("res://systems/native_data/creation_spell_text_snapshot.gd").new();result.revision=text.get("revision")
	var table: Dictionary=rules.tables.spells;var lookup:=Tables.columns(table)
	for row in table.get("orderedRows",[]).size():
		var read:=Tables.integer(table,row,"Name",lookup)
		if not read.ready:return {"ready":false,"reason":"A native spell-name conversion is unresolved."}
		var id:=int(read.value)&0xffffffff
		if not result.names.has(id):result.names[id]=text.raw({"strRef":id})
	return {"ready":true,"text":result}
