extends RefCounted
# Mode1-only additions to the shared native field projection. CNWClass2992e0
# initializes WORD+525=0; LoadClassInfo2a4a90 conditionally writes low INT BYTEs
# to ArcSpellLvlMod+525 and DivSpellLvlMod+526. Canonical tables stay raw.
const Base=preload("res://systems/native_data/creation_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const EXTRA_FIELDS=["ArcSpellLvlMod","DivSpellLvlMod"]
const NUMERIC=Base.NUMERIC+EXTRA_FIELDS
static func compile(raw: Dictionary) -> Dictionary:
	var base:=Base.compile(raw)
	if not base.ready:return base
	var result: Dictionary=base.table;var rows: Array=result.orderedRows.duplicate();var physical: Array=result.orderedCells.duplicate();var headers: Array=result.columns.duplicate();var named: Dictionary=result.get("rows",{}).duplicate();var unknown: Dictionary=base.unknown.duplicate(true)
	var columns: Dictionary={};var lookup:=Tables.columns(raw)
	for field in EXTRA_FIELDS:
		var column: int=-1
		for at in headers.size():
			if str(headers[at]).to_lower()==str(field).to_lower():column=at;break
		if column<0:column=headers.size();headers.append(field)
		columns[field]=column
	for id in rows.size()&255:
		var row: Dictionary=rows[id].duplicate();var cells: Array=physical[id].duplicate()
		for field in EXTRA_FIELDS:
			var read:=Tables.integer(raw,id,field,lookup)
			if not read.ready:
				if not unknown.has(id):unknown[id]={}
				unknown[id][field]=str(read.get("reason","Native class BYTE conversion is unresolved."));continue
			var value: int=(int(read.value)&255) if read.ok else 0;var column: int=columns[field]
			while cells.size()<=column:cells.append("")
			cells[column]=str(value);row[str(headers[column])]=str(value)
			for alias in row:
				if str(alias).to_lower()==str(field).to_lower():row[alias]=str(value)
		for key in named:
			if is_same(named[key],rows[id]):named[key]=row
		rows[id]=row;physical[id]=cells
	result.orderedRows=rows;result.orderedCells=physical;result.columns=headers
	if result.has("rows"):result.rows=named
	result.nativeClassProjection=result.nativeClassProjection.duplicate(true);result.nativeClassProjection.scope="mode1_private";result.nativeClassProjection.adapter="level_up_class_metadata";result.nativeClassProjection.mode1ExtraFields={"constructor":"0x1402992e0","loader":"0x1402a4a90","ArcSpellLvlMod":0x525,"DivSpellLvlMod":0x526};result.nativeClassProjection.unknown=unknown
	return {"ready":true,"table":result,"raw":raw,"unknown":unknown}
