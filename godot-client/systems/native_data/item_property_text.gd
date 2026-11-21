extends RefCounted
# Examine AddProperty1408965e0: original active 2DA/TLK lookups only.
# This formats disclosed properties; it never computes or grants item effects.
const Rich=preload("res://systems/native_data/rich_text.gd")
static func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
static func integer(data: Dictionary,column: String) -> Dictionary:
	var value: Variant=data.get(column)
	if value is int: return {"found":true,"value":value}
	if value is String and value.is_valid_int(): return {"found":true,"value":int(value)}
	return {"found":false,"value":0}
static func resource(value: Variant) -> String:
	var name:=str(value).strip_edges().to_lower() if value is String else ""
	return "" if name=="****" else name
static func specification(property: Dictionary,tables: Dictionary) -> Dictionary:
	var definition:=row(tables,"itempropdef",int(property.get("type",0))&65535)
	var cost:=int(integer(definition,"CostTableResRef").value); var param:=integer(definition,"Param1ResRef")
	var subtype:=resource(definition.get("SubTypeResRef")); var subrow:=row(tables,subtype,int(property.get("subtype",0))&65535)
	var override:=integer(subrow,"CostTableResRef")
	if override.found and int(override.value)!=0: cost=int(override.value)
	override=integer(subrow,"Param1ResRef")
	if override.found: param=override
	var cost_name:=resource(row(tables,"iprp_costtable",cost).get("Name")) if cost!=0 else ""
	var param_name:=resource(row(tables,"iprp_paramtable",int(param.value)).get("TableResRef")) if param.found else ""
	return {"definition":definition,"subtype":subtype,"subrow":subrow,"cost":cost_name,"param":param_name,"incomplete":cost!=0 and cost_name.is_empty() or param.found and param_name.is_empty()}
static func dependencies(properties: Array,tables: Dictionary) -> Array[String]:
	var missing: Array[String]=[]
	for property in properties:
		if not property is Dictionary: continue
		var info:=specification(property,tables)
		for name in [info.subtype,info.cost,info.param]:
			if not str(name).is_empty() and not tables.has(name) and not missing.has(name): missing.append(name)
	return missing
static func label(data: Dictionary,column: String,text,context: int) -> String:
	var reference:=integer(data,column)
	if not reference.found or int(reference.value)<0 or int(reference.value)==4294967295: return ""
	return text.resolve({"strRef":int(reference.value)},context)
static func project(properties: Array,text,context: int) -> Dictionary:
	var output:={"properties":[],"warnings":[],"missing":dependencies(properties,text.tables)}
	var incomplete:=false
	for property in properties:
		if not property is Dictionary: incomplete=true; continue
		var info:=specification(property,text.tables); var parts: Array[String]=[]
		incomplete=incomplete or bool(info.incomplete)
		var base:=label(info.definition,"GameStrRef",text,context)
		if base.is_empty(): incomplete=true; continue
		parts.append(base)
		for pair in [[info.subtype,info.subrow],[info.cost,row(text.tables,info.cost,int(property.get("costValue",0))&65535)],[info.param,row(text.tables,info.param,int(property.get("uses",0))&255)]]:
			if str(pair[0]).is_empty(): continue
			if not text.tables.has(pair[0]): continue
			var value:=label(pair[1],"Name",text,context)
			if value.is_empty(): incomplete=true
			else: parts.append(value)
		output.properties.append({"rich":Rich.parse(" ".join(parts)),"usable":bool(property.get("usable",false)),"type":int(property.get("type",0))&65535})
	if not output.missing.is_empty(): output.warnings.append("Loading item properties…")
	if incomplete: output.warnings.append("Some item property details could not be loaded.")
	return output
