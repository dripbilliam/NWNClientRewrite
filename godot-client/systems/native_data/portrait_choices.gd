extends RefCounted
# Original9d1c80/9d0cd0/9d04a0 chooser membership. Data only; shared by the
# current creator and the in-progress existing-character editor.
const Resources=preload("res://systems/native_data/portrait_resources.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func ordered(rows: Array,gender: int,race: int,provider: Callable=Callable(),custom_files: Array=[],allow_custom: bool=true) -> Array:
	if race==4: race=6 # Original8edb00 maps Half-Elf to the Human portrait group.
	var matching: Array=[]; var others: Array=[]; var represented: Dictionary={}; var admitted: Dictionary={}
	for row: Dictionary in rows:
		var value: Variant=Game.cell(row,"BaseResRef")
		if value==null or str(value) in ["","****"]: continue
		var base:=Resources.resref("po_"+str(value)); represented[base]=true
		if Game.number(Game.cell(row,"Plot"),0)!=0 or Game.number(Game.cell(row,"Sex"),-1)!=gender or not Resources.available(base,provider): continue
		# Each pass preserves physical table order; add9d0cd0 suppresses a base
		# already admitted even when multiple table rows reference the same image.
		if Game.number(Game.cell(row,"Race"),-1)==race: matching.append(base)
		else: others.append(base)
	var result: Array=[]
	for base in matching+others:
		if not admitted.has(base): result.append(base); admitted[base]=true
	if allow_custom:
		for value in custom_files:
			var filename:=str(value)
			if filename.get_extension().to_lower() not in ["tga","dds"]: continue
			var name:=filename.get_basename()
			if not name.to_lower().ends_with("m"): continue
			var base:=Resources.resref(name.left(-1))
			if represented.has(base) or admitted.has(base) or not Resources.available(base,provider): continue
			result.append(base); admitted[base]=true
	return result
