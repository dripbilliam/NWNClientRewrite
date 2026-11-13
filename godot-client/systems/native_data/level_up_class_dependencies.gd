extends RefCounted
# Mode1 source-class admission reads the same private compiled row names as
# its actual vitals/Skills/Feats/spell owners. No stock IDs or world preload.
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Names=preload("res://systems/native_data/pregame_skills.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
static func compose(received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	var advanced:=Vitals.next_classes(received,class_id)
	if not advanced.ready:return advanced
	var classes: Variant=tables.get("classes")
	if not classes is Dictionary or not classes.get("orderedRows") is Array:return {"ready":false,"reason":"Active class rules are unavailable."}
	var names: Array=[]
	for cls in advanced.classes:
		var id:=int(cls.id)
		if id<0 or id>=(classes.orderedRows.size()&255):return {"ready":false,"reason":"An owned class is absent from the active rules."}
		var row: Dictionary=classes.orderedRows[id];var fields: Array=["StatGainTable","SkillsTable","FeatsTable","AttackBonusTable"]
		if id==class_id:fields.append("BonusFeatsTable")
		var caster:=Tables.integer(classes,id,"SpellCaster")
		if not caster.ready or not caster.ok:return {"ready":false,"reason":"An owned class's spell metadata is unavailable."}
		if int(caster.value)!=0:fields.append_array(["SpellGainTable","SpellKnownTable"])
		for field in fields:
			var name:=Names.table_name(row,str(field))
			if not name.is_empty() and not names.has(name):names.append(name)
	var missing: Array=[]
	for name in names:
		if not tables.has(name):missing.append(name);continue
		var value: Variant=tables[name]
		if not value is Dictionary or not value.get("orderedRows") is Array:return {"ready":false,"reason":"Class choices could not be prepared from "+str(name)+".","failed":str(name),"required":names}
	if not missing.is_empty():return {"ready":false,"pending":true,"dependencies":missing,"required":names,"reason":"Preparing class choices…"}
	return {"ready":true,"required":names,"advanced":advanced}
