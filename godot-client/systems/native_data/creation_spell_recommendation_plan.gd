extends RefCounted
# First-level9c9df0 active Package→SpellPref2DA lookup. Presence of a parsed
# table records successful native preparation; a published empty failure is
# distinct from an unloaded dependency and from a valid zero-row table.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Preferences=preload("res://systems/native_data/creation_spell_preferences.gd")
static func pending(message: String,dependencies: Array=[]) -> Dictionary:return {"ready":false,"reason":message,"dependencies":dependencies}
static func compose(rules,source: Dictionary) -> Dictionary:
	var tables: Dictionary=rules.tables
	if not Preferences.scalar(rules.draft.get("classId")) or not Preferences.scalar(rules.draft.get("packageId")) or not source.get("memorizes") is bool or not Preferences.scalar(source.get("school")):return pending("The first-level native preference draft is incomplete.")
	if not tables.has("packages"):return pending("Active package data has not arrived.",["packages"])
	var plan:={"ready":true,"helperInvoked":false,"name":"","dependencies":[]}
	var package_table: Dictionary=tables.packages
	if not package_table.get("orderedRows") is Array:return plan
	var package_id:=int(rules.draft.packageId);var entry:=Tables.cell(package_table,package_id,"SpellPref2DA")
	if not entry.found or entry.text in ["","****"]:return plan
	var name:=str(entry.text).to_lower().left(16);plan.name=name
	if not tables.has(name):return pending("The active spell-preference table has not arrived.",[name])
	var class_id:=int(rules.draft.classId)
	if not tables.has("classes"):return pending("Active class data has not arrived.",["classes"])
	var restricted:=Tables.integer(tables.classes,class_id,"SpellbookRestricted")
	if not restricted.ready or not restricted.ok:return pending("Native spellbook-restriction metadata is unavailable.")
	var table: Dictionary=tables[name];var preferences: Array=[];var loaded: bool=table.get("orderedRows") is Array
	if loaded:
		var lookup:=Tables.columns(table)
		for row in table.orderedRows.size():
			var read:=Tables.integer(table,row,"SpellIndex",lookup)
			if not read.ready:return pending("A native preference conversion is unresolved.")
			preferences.append(int(read.value) if read.ok else null)
	var opposition: Variant=null
	if source.memorizes and (int(source.school)&255)!=0:
		if not tables.has("spellschools"):return pending("Active preference-opposition data has not arrived.",["spellschools"])
		var read:=Tables.integer(tables.spellschools,int(source.school)&255,"Opposition")
		if not read.ready:return pending("The native preference-opposition conversion is unresolved.")
		if read.ok:opposition=int(read.value)&255
	plan.merge({"helperInvoked":true,"loaded":loaded,"restricted":int(restricted.value)!=0,"preferences":preferences,"opposition":opposition},true)
	return plan
