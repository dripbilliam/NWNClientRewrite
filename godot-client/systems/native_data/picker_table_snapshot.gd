extends RefCounted
# Staged numeric projection input closure, not imported by the live picker.
# Keep every physical spell row and every active class-level column. Authored
# nested values retain the original detached worker ownership.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func spell_columns(classes: Dictionary) -> Dictionary:
	var wanted: Dictionary={}
	for row in classes.get("orderedRows",[]):
		var column:=str(Game.cell(row,"SpellTableColumn",""))
		if column not in ["","****"]:wanted[column.to_lower()]=true
	return wanted
static func relevant(keys: Array,wanted: Dictionary) -> Array:
	var result: Array=[]
	for key in keys:
		if wanted.has(str(key).to_lower()):result.append(key)
	return result
static func capture_spells(table: Dictionary,classes: Dictionary) -> Dictionary:
	# PregameSpells reads class-level cells only, addressed by physical spellID.
	# Capture EVERY row and EVERY currently defined class column, including
	# future selections' unknown book IDs/classes. UI names/icons stay in Talk.
	var rows: Array=table.get("orderedRows",[]);var wanted:=spell_columns(classes);var output: Array=[];output.resize(rows.size())
	var common: Array=rows[0].keys() if not rows.is_empty() and rows[0] is Dictionary else []
	var selected:=relevant(common,wanted)
	for index in rows.size():
		var row: Variant=rows[index]
		if not row is Dictionary:output[index]=row.duplicate(true) if row is Array else row;continue
		# Native parsed rows share key order. A differing authored/mutated row
		# takes its own exact order, retaining first case-insensitive precedence.
		var keys: Array=row.keys();var use: Array=selected if keys==common else relevant(keys,wanted);var detached: Dictionary={}
		for key in use:
			var value: Variant=row[key]
			detached[key]=value.duplicate(true) if value is Array or value is Dictionary else value.duplicate() if typeof(value)>=TYPE_PACKED_BYTE_ARRAY else value
		output[index]=detached
	return {"orderedRows":output}
