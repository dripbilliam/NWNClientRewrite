extends RefCounted
# Capture the active catalog's original 2DA byte sources on the main thread.
# A preview worker receives only owned bytes and a scope, never a catalog Node,
# resolver callback, or file path from a server character record.
const TwoDA=preload("res://systems/native_data/two_da.gd")
const Encoding=preload("res://systems/native_data/native_text_encoding.gd")
const TYPE_2DA:=2017
const REQUIRED=["racialtypes","classes","skills","feat","spells","baseitems","exptable","appearance","gender","phenotype","iprp_costtable","epicattacks","epicsaves","ruleset","armor","parts_chest","iprp_saveelement","damagetypes","damagetypegroups","iprp_monstcost","iprp_damagecost","diffsettings","creaturespeed"]
const OPTIONAL=["savingthrowtypes","excitedduration","damagehitvisual","repadjust","ranges","xptable","visualeffects","encumbrance","iprp_weightinc","itemprops","itempropdef","iprp_meleecost","iprp_spells","iprp_onhitspell","spellschools","domains","usemagicdevice","fractionalcr","encdifficulty","poison","disease","restduration"]
const CLASS_TABLE_FIELDS=["StatGainTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","SkillsTable","FeatsTable","BonusFeatsTable","PreReqTable"]

static func _rows(bytes: PackedByteArray)->Dictionary:
	var parser:=TwoDA.new()
	var parsed: Dictionary=parser.parse(bytes.get_string_from_ascii())
	return parsed if parser.failure.is_empty() and parsed.get("rows") is Dictionary else {}

static func _name(value: Variant)->String:
	var name:=str(value).strip_edges().to_lower()
	return name if not name.is_empty() and name!="****" and name.length()<=16 and name.is_valid_filename() else ""

static func capture(catalog: RefCounted,connection: int)->Dictionary:
	if catalog==null or connection<0 or not catalog.has_method("get_resource"):
		return {"ready":false,"error":"Character preview rules have no active catalog."}
	var resources: Dictionary={}
	for name in REQUIRED:
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if bytes.is_empty():return {"ready":false,"error":"Missing required character preview rule: "+name}
		resources[name]=bytes.duplicate()
	var cost: Dictionary=_rows(resources["iprp_costtable"])
	var classes: Dictionary=_rows(resources["classes"])
	if cost.is_empty() or classes.is_empty():return {"ready":false,"error":"Character preview rule table is invalid."}
	var dynamic: Dictionary={}
	for id in [1,2,20,21]:
		var row: Dictionary=cost.rows.get(id,{})
		var name:=_name(row.get("Name",""))
		if name.is_empty():return {"ready":false,"error":"Character preview item-cost table is unavailable."}
		dynamic[name]=true
	for row_value in classes.rows.values():
		if not row_value is Dictionary:continue
		for field in CLASS_TABLE_FIELDS:
			var name:=_name(row_value.get(field,""))
			if not name.is_empty():dynamic[name]=true
	for name in dynamic.keys():
		if resources.has(name):continue
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if bytes.is_empty():return {"ready":false,"error":"Missing referenced character preview rule: "+name}
		resources[name]=bytes.duplicate()
	for name in OPTIONAL:
		if resources.has(name):continue
		if catalog.has_method("has_resource") and not catalog.has_resource(name,TYPE_2DA):continue
		var bytes: PackedByteArray=catalog.get_resource(name,TYPE_2DA)
		if not bytes.is_empty():resources[name]=bytes.duplicate()
	return {"ready":true,"format":"nwn79-character-preview-rules-v1","connection":connection,"catalogId":catalog.get_instance_id(),"resources":resources}

static func decode(snapshot: Dictionary)->Dictionary:
	if not snapshot.get("ready",false) or str(snapshot.get("format",""))!="nwn79-character-preview-rules-v1" or not snapshot.get("resources") is Dictionary:
		return {"ready":false,"error":"Character preview rule snapshot is unavailable."}
	var tables: Dictionary={}
	for name in snapshot.resources:
		var bytes: Variant=snapshot.resources[name]
		if not bytes is PackedByteArray:return {"ready":false,"error":"Character preview rule bytes are invalid."}
		var plain_ascii:=true
		for byte in bytes:
			if byte>127:plain_ascii=false;break
		var text: String=bytes.get_string_from_ascii()
		if not plain_ascii:
			var decoded: Dictionary=Encoding.decode(bytes,0)
			if not decoded.get("ready",false):return {"ready":false,"error":"Character preview rule text cannot be decoded."}
			text=str(decoded.text)
		var parser:=TwoDA.new()
		var table: Dictionary=parser.parse(text)
		if not parser.failure.is_empty():return {"ready":false,"error":"Character preview rule table is invalid: "+str(name)}
		tables[name]=table
	for name in REQUIRED:
		if not tables.has(name):return {"ready":false,"error":"Required character preview rule is absent: "+name}
	var costs: Dictionary={}
	for id in [1,2,20,21]:
		var cost_row: Dictionary=tables["iprp_costtable"].rows.get(id,{})
		var name:=_name(cost_row.get("Name",""))
		if name.is_empty() or not tables.has(name):return {"ready":false,"error":"Referenced character preview item-cost table is absent."}
		costs[id]=tables[name]
	var class_tables: Dictionary={}
	for row_value in tables["classes"].rows.values():
		if not row_value is Dictionary:continue
		for field in CLASS_TABLE_FIELDS:
			var name:=_name(row_value.get(field,""))
			if not name.is_empty():
				if not tables.has(name):return {"ready":false,"error":"Referenced character preview class table is absent: "+name}
				class_tables[name]=tables[name]
	tables["itemCosts"]=costs
	tables["classTables"]=class_tables
	return {"ready":true,"tables":tables,"connection":int(snapshot.connection),"catalogId":int(snapshot.catalogId)}
