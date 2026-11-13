extends RefCounted
# Original9c69a0's four-stage coordinator. A native draft owns its cursor;
# child modals retain the same scoped callback until this sequence finishes.
var stage:=0
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
func reset() -> void:stage=0
static func pending(field: String) -> Dictionary:return {"ready":false,"field":field}
static func numeric(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)
func advance(source: Dictionary,code: int,cancelled: bool=false) -> Dictionary:
	if cancelled:stage=0;return {"ready":true,"child":"","code":null,"activated":false,"cancelled":true}
	if not source.get("present") is bool:return pending("present")
	if not source.present:return {"ready":true,"child":"","code":null,"activated":false,"cancelled":false}
	if not numeric(source.get("mode")):return pending("mode")
	var mode:=int(source.mode);var level:=1
	if mode!=0:
		if not numeric(source.get("level")):return pending("level")
		level=int(source.level)&255
	var cursor:=stage
	while cursor in [0,1,2,3]:
		var current:=cursor;cursor+=1;var field: String=["PickDomains","PickSchool","SpellbookRestricted","MinAssociateLevel"][current]
		if current<2 and level!=1:continue
		if not numeric(source.get(field)):return pending(field)
		var show:=int(source[field])!=0 if current<3 else (int(source[field])&255)<=level
		if current==2 and show:
			if not numeric(source.get("SkipSpellSelection")):return pending("SkipSpellSelection")
			show=int(source.SkipSpellSelection)==0
		if show:
			if current==3 and not numeric(source.get("Arcane")):return pending("Arcane")
			stage=cursor;return {"ready":true,"child":["domains","school","spells","associate"][current],"code":code&0xffffffff,"activated":true,"cancelled":false}
	stage=0
	return {"ready":true,"child":"","code":0x8016 if mode!=0 else code&0xffffffff,"activated":false,"cancelled":false}
static func creation_source(rules) -> Dictionary:
	var source:={"present":true,"mode":0,"level":1}
	var id:=int(rules.draft.get("classId",-1));var table: Dictionary=rules.tables.get("classes",{})
	if id<0 or id>=(table.get("orderedRows",[]).size()&255):return {}
	for field in ["PickDomains","PickSchool","SpellbookRestricted","SkipSpellSelection","MinAssociateLevel","Arcane"]:
		var read:=Tables.integer(table,id,field)
		# LoadClassInfo writes these fields conditionally. The constructor does
		# not initialize every one: missing metadata cannot mean false/zero.
		if read.ready and read.ok:source[field]=(int(read.value)&255) if field=="MinAssociateLevel" else int(read.value) if field=="Arcane" else int(int(read.value)!=0)
	return source
