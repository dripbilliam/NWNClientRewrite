extends RefCounted
const Tables=preload("res://systems/native_data/animation_lookup_tables.gd")
const ScriptString=preload("res://systems/native_data/native_script_string.gd")
const ResRef=preload("res://systems/native_data/visual_type10.gd")
var failure:=""
static func _atoi(value: Variant) -> int:
	var expression:=RegEx.new()
	expression.compile("^\\s*([+-]?\\d+)")
	var found:=expression.search(str(value) if value!=null else "")
	return _int32(int(found.get_string(1))) if found!=null else 0
static func _int32(value: int) -> int:
	var narrowed:=value&0xffffffff
	return narrowed-0x100000000 if narrowed>0x7fffffff else narrowed
func field(tables: Dictionary,name: String,index: int,key: String) -> int:
	var table: Dictionary=tables.get(name,{})
	var rows: Array=table.get("orderedRows",[])
	var row: Variant=null
	if table.has("orderedRows"):
		if index>=0 and index<rows.size():row=rows[index]
	else:row=table.get("rows",{}).get(index)
	if not row is Dictionary:return _atoi(table.get("defaultValue"))
	var cell: Variant=null
	var found:=false
	for column in row:
		if str(column).to_lower()==key.to_lower():cell=row[column];found=true;break
	if not found:return _atoi(table.get("defaultValue"))
	var text:=str(cell)
	if text.is_empty() or text=="****":return 0
	var expression:=RegEx.new()
	expression.compile("(?i)^0x[0-9a-f]+")
	var hex:=expression.search(text)
	return _int32(hex.get_string().hex_to_int()) if hex!=null else _atoi(text)
func equipped(object: Dictionary,slot: int) -> Dictionary:
	for entry in object.get("appearance",{}).get("equipment",[]):
		if int(entry.slot)==slot: return entry.get("item",{})
	return {}
func context(object: Dictionary,tables: Dictionary) -> Dictionary:
	var appearance_id:=int(object.get("appearance",{}).get("appearance",-1)); var rows: Array=tables.get("appearance",{}).get("orderedRows",[])
	if appearance_id<0 or appearance_id>=rows.size(): failure="Original animation appearance is absent"; return {}
	var model_type:=str(rows[appearance_id].get("MODELTYPE",""))
	var body:=preload("res://systems/native_data/animation_body_type.gd").classify(model_type)
	var right:=equipped(object,16); var left:=equipped(object,32); var style:=1; var weapon_type:=0
	if right.is_empty():
		if not left.is_empty() and field(tables,"baseitems",int(left.baseItem),"WeaponWield")==7: style=2
		weapon_type=2
	else:
		var base:=int(right.baseItem); var wield:=field(tables,"baseitems",base,"WeaponWield")&255
		var difference:=relative_size(base,appearance_id,tables)
		if difference>=-2 and difference<=0 and not (wield<=10 and ((0x570>>wield)&1)!=0):
			if left.is_empty(): style=3; weapon_type=field(tables,"baseitems",base,"WeaponType")
			else:
				var left_base:=int(left.baseItem); var left_wield:=field(tables,"baseitems",left_base,"WeaponWield")&255; var left_size:=relative_size(left_base,appearance_id,tables)
				if left_wield==7: style=4; weapon_type=field(tables,"baseitems",base,"WeaponType")
				elif left_size>=-2 and left_size<=0: style=3 if left_wield==1 else 5; weapon_type=field(tables,"baseitems",base if left_wield==1 else left_base,"WeaponType")
				else: failure="Original left weapon animation size is invalid"; return {}
		else:
			style=6 if difference==1 and wield!=8 and wield not in [4,5,6,10] else int({4:8,8:7,5:9,6:10,10:11}.get(wield,1))
			weapon_type=field(tables,"baseitems",base,"WeaponType")
	return {"fieldDE":body,"fieldDD":style,"fieldDF":weapon_type&255,"fieldE0":0,"fieldE8":0,"fieldEC":0,"model_type":model_type}
func relative_size(base: int,appearance: int,tables: Dictionary) -> int:
	return 0 if base==111 else field(tables,"baseitems",base,"WeaponSize")-field(tables,"appearance",appearance,"SIZECATEGORY")
func name_for(code: int,state: Dictionary,overrides: Array=[]) -> String:
	failure=""; code&=65535
	var body:=1 if (int(state.get("fieldDE",0))&255)==1 else 0; var style:=int(state.get("fieldDD",0))&255; var side:=int(state.get("fieldE0",0))&255
	var key:=str(body)+":"+str(style)+":"+str(side)
	if not Tables.CONTEXTS.has(key) or int(state.get("fieldEC",0))!=0 or int(state.get("fieldE8",0))!=0: failure="Original animation context is unsupported"; return ""
	var chosen: String=("pause1" if body==1 else "cpause1") if code>425 else Tables.NAMES[Tables.ROWS[int(Tables.CONTEXTS[key])][code]]
	for replacement in overrides:
		var old_lower:Dictionary=ScriptString.change_case(resref(str(replacement.get("old",""))))
		if not failure.is_empty():return ""
		if old_lower.has("error"):failure=old_lower.error;return ""
		var chosen_lower:Dictionary=ScriptString.change_case(chosen)
		if chosen_lower.has("error"):failure=chosen_lower.error;return ""
		if old_lower.value==chosen_lower.value:
			chosen=resref(str(replacement.get("replacement","")))
			if not failure.is_empty():return ""
			break
	var result:Dictionary=ScriptString.change_case(chosen)
	if result.has("error"):failure=result.error;return ""
	return result.value
func resref(value: String) -> String:
	var reference:Dictionary=ResRef.object_template_resref(value)
	if reference.has("error"):failure=str(reference.error);return ""
	return str(reference.value)
func maps(state: Dictionary) -> Dictionary:
	var output: Dictionary={}
	for side in 3:
		var context_state:=state.duplicate(); context_state.fieldE0=side; var names: Dictionary={}
		for code in 512: names[str(code)]=name_for(code,context_state)
		output[str(side)]=names
	return output
