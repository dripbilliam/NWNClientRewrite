extends RefCounted
# Capture the active catalog's original 2DA byte sources on the main thread.
# A preview worker receives only owned bytes and a scope, never a catalog Node,
# resolver callback, or file path from a server character record.
const TwoDA=preload("res://systems/native_data/two_da.gd")
const Encoding=preload("res://systems/native_data/native_text_encoding.gd")
const RulesetCache=preload("res://systems/native_data/ruleset_cache.gd")
const TYPE_2DA:=2017
const REQUIRED=["racialtypes","classes","skills","feat","spells","baseitems","exptable","appearance","gender","phenotype","iprp_costtable","epicattacks","epicsaves","ruleset","armor","parts_chest","iprp_saveelement","damagetypes","damagetypegroups","iprp_monstcost","iprp_damagecost","diffsettings","creaturespeed"]
const OPTIONAL=["savingthrowtypes","excitedduration","damagehitvisual","repadjust","ranges","xptable","visualeffects","encumbrance","iprp_weightinc","itemprops","itempropdef","iprp_meleecost","iprp_spells","iprp_onhitspell","spellschools","domains","usemagicdevice","fractionalcr","encdifficulty","poison","disease","restduration"]
const CLASS_TABLE_FIELDS=["StatGainTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","SkillsTable","FeatsTable","BonusFeatsTable","PreReqTable"]

static func _rows(bytes: PackedByteArray)->Dictionary:
	# ResourceArchive.decodeResourceText uses Windows-1252 without stopping at NUL.
	var decoded: Dictionary=Encoding.decode(bytes,0,false,false,true)
	if not decoded.get("ready",false):return {}
	var parser:=TwoDA.new()
	var parsed: Dictionary=parser.parse(str(decoded.text))
	return parsed if parser.failure.is_empty() and parsed.get("rows") is Dictionary else {}

static func _name(value: Variant)->String:
	# The old resolver lowercases its key; it does not trim or prevalidate it.
	return str(value).to_lower() if value!=null else "****"

static func _failed(catalog: RefCounted,connection: int,reason: String,diagnostics: Array)->Dictionary:
	return {"ready":false,"error":reason,"connection":connection,"catalogId":catalog.get_instance_id(),"diagnostics":diagnostics.duplicate(true)}

static func _optional_outcome(name: String)->String:
	match name:
		"savingthrowtypes":return "Native legacy save-immunity fallback selected"
		"excitedduration":return "SetExcitedState is unavailable"
		"damagehitvisual":return "Native on-hit visual lookup is unavailable"
		"repadjust":return "Native combat reputation adjustments are unavailable"
		"ranges":return "Native perception range initialization is unavailable"
		"xptable":return "Native death experience lookup is unavailable"
		"visualeffects":return "Native death visual preservation lookup is unavailable"
	return "Native dependent rule table is unavailable"

static func _optional_warning(name: String,reason: String)->Dictionary:
	var display_name: String="XPTable" if name=="xptable" else name
	return {"code":"rules.optional-table-unavailable","reason":display_name+".2da: "+reason,"resource":name,"outcome":_optional_outcome(name)}

static func _catalog_error(catalog: RefCounted,name: String)->String:
	for property in catalog.get_property_list():
		if str(property.get("name",""))=="failure":
			var reason:=str(catalog.get("failure"))
			if not reason.is_empty():return reason
	return "Resource "+name+" (type 2017) is unavailable"

static func capture(catalog: RefCounted,connection: int)->Dictionary:
	if catalog==null or connection<0 or not catalog.has_method("get_resource"):
		return {"ready":false,"error":"Character preview rules have no active catalog."}
	var diagnostics: Array=[]
	var resources: Dictionary={}
	for name in REQUIRED:
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if bytes.is_empty():return _failed(catalog,connection,"Missing required character preview rule: "+name,diagnostics)
		resources[name]=bytes.duplicate()
	# Promise.all parses every required table before the old loader records a
	# duplicate-ruleset warning or requests any optional/reference table.
	var required_tables: Dictionary={}
	for name in REQUIRED:
		var parsed: Dictionary=_rows(resources[name])
		if parsed.is_empty():return _failed(catalog,connection,"Character preview rule table is invalid: "+name,diagnostics)
		required_tables[name]=parsed
	var cost: Dictionary=required_tables["iprp_costtable"]
	var classes: Dictionary=required_tables["classes"]
	var ruleset: Dictionary=required_tables["ruleset"]
	var compiled_ruleset: Dictionary=RulesetCache.compile_checked(ruleset)
	if not str(compiled_ruleset.get("error","")).is_empty():return _failed(catalog,connection,str(compiled_ruleset.error),diagnostics)
	for label in compiled_ruleset.duplicates:
		diagnostics.append({"code":"rules.duplicate-ruleset-entry","reason":"Duplicate ruleset.2da entry: "+str(label),"resource":"ruleset","label":str(label)})
	# loadCharacterRules tries optional tables after the required set and before
	# looking up class and item-cost table references.
	var failed_optional: Dictionary={}
	for name in OPTIONAL:
		if resources.has(name):continue
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if bytes.is_empty():
			failed_optional[name]=true
			diagnostics.append(_optional_warning(name,_catalog_error(catalog,name)))
		else:
			resources[name]=bytes.duplicate()
			if _rows(bytes).is_empty():diagnostics.append(_optional_warning(name,"Invalid 2DA table"))
	# Item-cost reads are independent by ID, including repeated names. A failed
	# optional read is retried here if a later reference requires that resource.
	var item_cost_resources: Dictionary={}
	for id in [1,2,20,21]:
		var row: Dictionary=cost.rows.get(id,{})
		var name:=_name(row.get("Name",""))
		if name.is_empty() or name=="****":return _failed(catalog,connection,"Missing ability item property cost table "+str(id),diagnostics)
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if bytes.is_empty():return _failed(catalog,connection,"Missing referenced character preview rule: "+name,diagnostics)
		if _rows(bytes).is_empty():return _failed(catalog,connection,"Referenced character preview item-cost table is invalid: "+name,diagnostics)
		item_cost_resources[id]=bytes.duplicate()
		if not resources.has(name) and not failed_optional.has(name):resources[name]=bytes.duplicate()
	# Class references are loaded once per lowercased name, in row/field order.
	# They do not share the item-cost Map's read or its parsed table object.
	var class_resources: Dictionary={}
	for row_value in classes.rows.values():
		if not row_value is Dictionary:continue
		for field in CLASS_TABLE_FIELDS:
			var name:=_name(row_value.get(field,"****"))
			if name=="****" or class_resources.has(name):continue
			var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
			if bytes.is_empty():return _failed(catalog,connection,"Missing referenced character preview rule: "+name,diagnostics)
			if _rows(bytes).is_empty():return _failed(catalog,connection,"Referenced character preview class table is invalid: "+name,diagnostics)
			class_resources[name]=bytes.duplicate()
			if not resources.has(name) and not failed_optional.has(name):resources[name]=bytes.duplicate()
	return {"ready":true,"format":"nwn79-character-preview-rules-v1","connection":connection,"catalogId":catalog.get_instance_id(),"resources":resources,"requiredTables":required_tables,"itemCostResources":item_cost_resources,"classTableResources":class_resources,"diagnostics":diagnostics.duplicate(true)}

static func decode(snapshot: Dictionary)->Dictionary:
	if not snapshot.get("ready",false) or str(snapshot.get("format",""))!="nwn79-character-preview-rules-v1" or not snapshot.get("resources") is Dictionary:
		return {"ready":false,"error":"Character preview rule snapshot is unavailable."}
	var cached: Variant=snapshot.get("requiredTables")
	if not cached is Dictionary:return {"ready":false,"error":"Required character preview rules are unavailable."}
	# Callers duplicate the snapshot before handing it to a worker. Keep the
	# projection's derived entries private without decoding the required set
	# again for every character preview.
	var tables: Dictionary=cached.duplicate(true)
	for name in REQUIRED:
		if not tables.get(name) is Dictionary or not tables[name].get("rows") is Dictionary:
			return {"ready":false,"error":"Required character preview rule is absent: "+name}
	for name in snapshot.resources:
		if name in REQUIRED:continue
		var bytes: Variant=snapshot.resources[name]
		if not bytes is PackedByteArray:
			if name in OPTIONAL:continue
			return {"ready":false,"error":"Character preview rule bytes are invalid."}
		var table: Dictionary=_rows(bytes)
		if table.is_empty():
			if name in OPTIONAL:continue
			return {"ready":false,"error":"Character preview rule table is invalid: "+str(name)}
		tables[name]=table
	for name in OPTIONAL:
		if not tables.has(name):tables[name]=null
	var costs: Dictionary={}
	var cost_resources: Dictionary=snapshot.get("itemCostResources",{})
	for id in [1,2,20,21]:
		var cost_row: Dictionary=tables["iprp_costtable"].rows.get(id,{})
		var name:=_name(cost_row.get("Name",""))
		if name.is_empty() or name=="****":return {"ready":false,"error":"Missing ability item property cost table "+str(id)}
		var bytes: Variant=cost_resources.get(id,snapshot.resources.get(name,PackedByteArray()))
		if not bytes is PackedByteArray or bytes.is_empty():return {"ready":false,"error":"Referenced character preview item-cost table is absent."}
		var table: Dictionary=_rows(bytes)
		if table.is_empty():return {"ready":false,"error":"Referenced character preview item-cost table is invalid."}
		costs[id]=table
	var class_tables: Dictionary={}
	var class_resources: Dictionary=snapshot.get("classTableResources",{})
	for row_value in tables["classes"].rows.values():
		if not row_value is Dictionary:continue
		for field in CLASS_TABLE_FIELDS:
			var name:=_name(row_value.get(field,"****"))
			if name=="****" or class_tables.has(name):continue
			var bytes: Variant=class_resources.get(name,snapshot.resources.get(name,PackedByteArray()))
			if not bytes is PackedByteArray or bytes.is_empty():return {"ready":false,"error":"Referenced character preview class table is absent: "+name}
			var table: Dictionary=_rows(bytes)
			if table.is_empty():return {"ready":false,"error":"Referenced character preview class table is invalid: "+name}
			class_tables[name]=table
	var gains: Dictionary={}
	for row_value in tables["classes"].rows.values():
		if not row_value is Dictionary:continue
		var name:=_name(row_value.get("StatGainTable","****"))
		if name!="****":gains[name]=class_tables[name]
	tables["itemCosts"]=costs
	tables["abilityCosts"]={1:costs[1],21:costs[21]}
	tables["classTables"]=class_tables
	tables["gains"]=gains
	return {"ready":true,"tables":tables,"connection":int(snapshot.connection),"catalogId":int(snapshot.catalogId)}
