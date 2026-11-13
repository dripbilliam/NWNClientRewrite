extends RefCounted
# First-level private CNWClass projection. LoadClassInfo2a4a90 calls
# InitLegacyClassDefaults2a4350 before conditional active-column writes.
# Raw catalog/text tables remain untouched; no world/level-up cache is owned.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const NUMERIC=["MemorizesSpells","SpellbookRestricted","PickDomains","PickSchool","LearnScroll","Arcane","ASF","MinCastingLevel","CanCastSpontaneously","MinAssociateLevel","SkipSpellSelection"]
const BOOLEANS=["MemorizesSpells","SpellbookRestricted","PickDomains","PickSchool","LearnScroll","Arcane","ASF","CanCastSpontaneously","SkipSpellSelection"]
const ABILITIES=["STR","DEX","CON","INT","WIS","CHA"]
static func legacy(id: int) -> Dictionary:
	var value:={"MemorizesSpells":1,"SpellbookRestricted":0,"PickDomains":0,"PickSchool":0,"LearnScroll":0,"Arcane":0,"ASF":0,"SpellcastingAbil":"****","SpellTableColumn":"Innate","MinCastingLevel":1,"CanCastSpontaneously":0,"MinAssociateLevel":255,"SkipSpellSelection":0}
	match id&255:
		1:value.merge({"MemorizesSpells":0,"SpellbookRestricted":1,"Arcane":1,"ASF":1,"SpellcastingAbil":"CHA","SpellTableColumn":"Bard"},true)
		2:value.merge({"PickDomains":1,"SpellcastingAbil":"WIS","SpellTableColumn":"Cleric","CanCastSpontaneously":1},true)
		3:value.merge({"SpellcastingAbil":"WIS","SpellTableColumn":"Druid","MinAssociateLevel":1},true)
		6:value.merge({"SpellcastingAbil":"WIS","SpellTableColumn":"Paladin","MinCastingLevel":4},true)
		7:value.merge({"SpellcastingAbil":"WIS","SpellTableColumn":"Ranger","MinCastingLevel":4,"MinAssociateLevel":6},true)
		9:value.merge({"MemorizesSpells":0,"SpellbookRestricted":1,"Arcane":1,"ASF":1,"SpellcastingAbil":"CHA","SpellTableColumn":"Wiz_Sorc","MinAssociateLevel":1},true)
		10:value.merge({"SpellbookRestricted":1,"PickSchool":1,"LearnScroll":1,"Arcane":1,"ASF":1,"SpellcastingAbil":"INT","SpellTableColumn":"Wiz_Sorc","MinAssociateLevel":1},true)
	var ability:=ABILITIES.find(str(value.SpellcastingAbil));value.CastingAbility=255 if ability<0 else ability;value.CLMultiplier=1.0
	return value
static func resolve(table: Dictionary,id: int,lookup: Dictionary={}) -> Dictionary:
	var value:=legacy(id);var unknown: Dictionary={}
	value.erase("CastingAbility")
	for field in NUMERIC:
		var read:=Tables.integer(table,id,field,lookup)
		if not read.ready:unknown[field]=str(read.get("reason","Native class conversion is unresolved."));value.erase(field)
		elif read.ok:
			var number:=int(read.value)
			value[field]=int(number!=0) if field in BOOLEANS else number&255 if field=="MinAssociateLevel" else number
	var ability:=Tables.cell(table,id,"SpellcastingAbil",lookup)
	# The loader compares against the six exact native uppercase abbreviations;
	# an unrecognized successful string does not overwrite its initialized byte.
	if ability.found and str(ability.text) in ABILITIES:value.SpellcastingAbil=str(ability.text)
	var column:=Tables.cell(table,id,"SpellTableColumn",lookup)
	if column.found and str(column.text) not in ["","****"]:value.SpellTableColumn=str(column.text)
	var multiplier:=Tables.cell(table,id,"CLMultiplier",lookup)
	if multiplier.found and str(multiplier.text) not in ["","****"]:
		var number:=str(multiplier.text).strip_edges()
		if number.is_valid_float() and is_finite(number.to_float()):value.CLMultiplier=PackedFloat32Array([number.to_float()])[0]
		else:unknown.CLMultiplier="Native class floating-point conversion is unresolved.";value.erase("CLMultiplier")
	return {"fields":value,"unknown":unknown}
static func compile(raw: Dictionary) -> Dictionary:
	if not raw.get("orderedRows") is Array:return {"ready":false,"reason":"The active physical class table is unavailable.","table":{},"raw":raw}
	var result:=raw.duplicate();var rows: Array=raw.orderedRows.duplicate();var physical: Array=raw.get("orderedCells",[]).duplicate();var headers: Array=raw.get("columns",[]).duplicate();var unknown: Dictionary={}
	if headers.is_empty():
		for row in rows:
			if row is Dictionary:
				for key in row:
					if not headers.has(str(key)):headers.append(str(key))
	var lookup:=Tables.columns(raw);var fields: Array=NUMERIC+["SpellcastingAbil","SpellTableColumn","CLMultiplier"];var columns: Dictionary={}
	for field in fields:
		var column: int=int(lookup.get(str(field).to_lower(),-1))
		if column<0:
			# Preserve first physical/case-insensitive source precedence. New
			# private metadata columns are appended only when no source header owns it.
			for at in headers.size():
				if str(headers[at]).to_lower()==str(field).to_lower():column=at;break
		if column<0:column=headers.size();headers.append(field)
		columns[field]=column
	var named: Dictionary=raw.get("rows",{}).duplicate()
	for id in rows.size()&255:
		if not rows[id] is Dictionary:return {"ready":false,"reason":"An active physical class row is unavailable.","table":{},"raw":raw}
		var row: Dictionary=rows[id].duplicate();var resolved:=resolve(raw,id,lookup);var cells: Array=physical[id].duplicate() if id<physical.size() and physical[id] is Array else []
		# Generic rule readers prefer an exact dictionary key. Mirror the first
		# native physical column into all private case aliases, so e.g. headers
		# arcane,Arcane cannot expose the later raw cell via Rules.num('Arcane').
		# The source graph and later physical cells remain unchanged.
		var aliases: Dictionary={}
		for key in row:aliases.get_or_add(str(key).to_lower(),[]).append(key)
		for key in aliases:
			if aliases[key].size()<2:continue
			var first:=Tables.cell(raw,id,str(aliases[key][0]),lookup)
			for alias in aliases[key]:row[alias]=str(first.text)
		if not resolved.unknown.is_empty():unknown[id]=resolved.unknown
		# Supply a complete private physical row; leave duplicate later columns
		# intact. Missing source cells keep the source DEFAULT until resolved.
		while cells.size()<headers.size():
			var index:=cells.size();var old:=Tables.cell(raw,id,str(headers[index]),lookup);cells.append(str(old.text))
		for field in resolved.fields:
			var at: int=columns[field];var header:=str(headers[at]);var value: Variant=resolved.fields[field]
			row[header]=str(value);cells[at]=str(value)
			for alias in aliases.get(str(field).to_lower(),[]):row[alias]=str(value)
		for key in named:
			if is_same(named[key],rows[id]):named[key]=row
		rows[id]=row
		while physical.size()<=id:physical.append([])
		physical[id]=cells
	result.orderedRows=rows;result.orderedCells=physical;result.columns=headers
	if raw.has("rows"):result.rows=named
	result.nativeClassProjection={"scope":"first_level_private","legacy":"0x1402a4350","loader":"0x1402a4a90","unknown":unknown}
	return {"ready":true,"table":result,"raw":raw,"unknown":unknown}
