extends RefCounted
# Original9d1c80/9d0cd0/9d04a0 chooser membership. Data only; shared by the
# current creator and the in-progress existing-character editor.
const Resources=preload("res://systems/native_data/portrait_resources.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const ClassRules=preload("res://systems/native_data/creation_class_rules.gd")
static func creation_number(row: Dictionary,column: String,fallback: int=0) -> float:
	var value: Variant=Game.cell(row,column)
	if value==null or value is String and value in ["","****"]:return float(fallback)
	return ClassRules.js_number(value)
static func custom_creation_portraits(names: Array) -> Array:
	var result: Array=[];var seen: Dictionary={}
	for value in names:
		var name:=str(value)
		if not name.to_lower().ends_with("m"):continue
		var base:=name.left(-1).to_lower()
		if not seen.has(base):seen[base]=true;result.append(base)
	return result
static func available_creation_portraits(refs: Array,provider: Callable) -> Dictionary:
	if refs.size()>32768:return {"error":"Invalid character creation portrait references"}
	for value in refs:
		if not value is String or value.length()>32:return {"error":"Invalid character creation portrait references"}
		for character in value:
			if character.unicode_at(0)<32 or character in ["/","\\",":"]:return {"error":"Invalid character creation portrait references"}
	if not provider.is_valid():return {"error":"Character creation portrait catalog is unavailable"}
	var result: Array=[];var seen: Dictionary={}
	for value in refs:
		if seen.has(value):continue
		seen[value]=true
		for candidate in Resources.candidates(value,3):
			if provider.call(candidate,3) or provider.call(candidate,2033):result.append(value);break
	return {"ready":true,"available":result}
static func ordered(rows: Array,gender: int,race: int,provider: Callable=Callable(),custom_files: Array=[],allow_custom: bool=true,creation_js_order: bool=false) -> Array:
	if race==4 and not creation_js_order: race=6 # Original8edb00 maps Half-Elf to the Human portrait group.
	var matching: Array=[]; var others: Array=[]; var represented: Dictionary={}; var admitted: Dictionary={}
	for row: Dictionary in rows:
		var value: Variant=Game.cell(row,"BaseResRef")
		if value==null or str(value) in ["","****"]: continue
		var base:=("po_"+str(value)).to_lower() if creation_js_order else Resources.resref("po_"+str(value)); represented[base]=true
		if creation_number(row,"Plot")!=0.0 or creation_number(row,"Sex",-1)!=float(gender) or not Resources.available(base,provider): continue
		# Each pass preserves physical table order; add9d0cd0 suppresses a base
		# already admitted even when multiple table rows reference the same image.
		if creation_number(row,"Race",-1)==float(race): matching.append(base)
		else: others.append(base)
	var result: Array=[]
	for base in matching+others:
		if not admitted.has(base): result.append(base); admitted[base]=true
	if allow_custom:
		for value in custom_files:
			var base: String
			if creation_js_order:base=str(value).to_lower()
			else:
				var filename:=str(value)
				if filename.get_extension().to_lower() not in ["tga","dds"]:continue
				var name:=filename.get_basename()
				if not name.to_lower().ends_with("m"):continue
				base=Resources.resref(name.left(-1))
			if represented.has(base) or admitted.has(base) or not Resources.available(base,provider): continue
			result.append(base); admitted[base]=true
	return result
