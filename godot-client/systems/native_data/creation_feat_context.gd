extends RefCounted
# One synchronous feat-choice operation owns this index. It is built from the
# already detached active class snapshot, never from a global/renderer cache.
# Native class lookup takes the first matching WORD feat ID; duplicates must
# neither replace its List classification nor grant a later record's level.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const KEY="_creationClassFeatIndex"
const REQUIREMENT_KEYS=["MINSPELLLVL","MINATTACKBONUS","MINSTR","MINDEX","MINCON","MININT","MINWIS","MINCHA","PREREQFEAT1","PREREQFEAT2"]
static func requirement_row(row: Dictionary) -> Dictionary:
	# Decode owns these rows; the active raw 2DA and its column order stay intact.
	# Resolve the very same exact-key/first-case-insensitive lookup once, before
	# thousands of prerequisite reads. Keep the original keys for other owners.
	var result:=row.duplicate()
	for key in REQUIREMENT_KEYS:
		if result.has(key):continue
		var value: Variant=Game.cell(row,key)
		if value!=null:result[key]=value
	return result
static func prepare(source: Dictionary) -> Dictionary:
	var result:=source.duplicate();var records: Dictionary={}
	var classes: Array=source.get("classes",[]);var current:=int(source.get("current",0))
	if current>=0 and current<mini(8,classes.size()):
		for entry in classes[current].get("feats",[]):
			var id:=Game.number(Game.cell(entry,"id"),0)&65535
			if not records.has(id):records[id]={"List":Game.number(Game.cell(entry,"List"),0)&255,"level":Game.number(Game.cell(entry,"level"),0)&255}
	result[KEY]=records
	return result
