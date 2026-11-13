extends RefCounted
# Exact input closure for Provider.appearance. No live table crosses a worker.
# Keep canonical header/default/physical-cell precedence, including partial
# orderedCells rows. Only rows the provider cannot address are omitted.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func detach(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value.duplicate() if typeof(value)>=TYPE_PACKED_BYTE_ARRAY else value
static func rows(table: Dictionary,selected: Array) -> Dictionary:
	var source: Array=table.get("orderedRows",[]);var physical: Array=table.get("orderedCells",[])
	var copied: Array=[];copied.resize(source.size())
	var cells: Array=[];cells.resize(physical.size())
	for index in source.size():copied[index]={}
	for index in physical.size():cells[index]=[]
	for index in selected:
		if index>=0 and index<source.size():copied[index]=detach(source[index])
		if index>=0 and index<physical.size():cells[index]=detach(physical[index])
	var result: Dictionary={}
	if table.has("orderedRows"):result.orderedRows=copied
	if table.has("columns"):result.columns=detach(table.columns)
	if table.has("defaultValue"):result.defaultValue=detach(table.defaultValue)
	if table.has("orderedCells"):result.orderedCells=cells
	return result
static func capture(tables: Dictionary,race_id: int) -> Dictionary:
	var result: Dictionary={}
	for name in ["racialtypes","appearance","gender","chargenclothes","ruleset"]:
		if tables.has(name) and (not tables[name] is Dictionary or tables[name].has("orderedRows") and not tables[name].orderedRows is Array):
			# Preserve explicit invalid/absent publication instead of inventing
			# a known-empty orderedRows table. Provider rejects this before use.
			for key in ["racialtypes","appearance","gender","chargenclothes","ruleset"]:
				if tables.has(key):result[key]=detach(tables[key])
			return result
	var races: Dictionary=tables.get("racialtypes",{});var appearance: Dictionary=tables.get("appearance",{})
	var selected: Array=[];var id:=Tables.integer(races,race_id,"Appearance")
	if id.get("ready",false) and id.get("ok",false):selected.append(int(id.value)&65535)
	if tables.has("racialtypes"):result.racialtypes=rows(races,[race_id])
	if tables.has("appearance"):result.appearance=rows(appearance,selected)
	if tables.has("gender"):result.gender=rows(tables.gender,[0,1])
	for name in ["chargenclothes","ruleset"]:
		if not tables.has(name):continue
		var table: Dictionary=tables[name]
		# These two native scans read every physical row. Preserve the whole
		# row and physical cell data; their graphs are small compared to appearance.
		result[name]=rows(table,range(table.get("orderedRows",[]).size()))
	# The live immutable ruleset owner can carry a resolved getter. Freeze the
	# one consumed scalar, never the live Entry/lease object, across the worker.
	result._native_resolved_ruleset={"CHARGEN_ENABLED_PHENOTYPES":Values.cfg(tables,"CHARGEN_ENABLED_PHENOTYPES",5)}
	return result
