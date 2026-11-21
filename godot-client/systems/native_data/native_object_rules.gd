extends RefCounted
# Server object-update schemas from the same original 2DA tables used by the
# Godot renderer/UI. The parser never guesses a table-dependent field width.
var tables: Dictionary={}
var object_state: Callable

func configure(source: Dictionary,existing_object_state: Callable=Callable())->bool:
	for name in ["baseitems","classes","visualeffects","skills","spells","feat"]:
		if not source.has(name) or not source[name] is Dictionary or not source[name].get("orderedRows") is Array:return false
	tables=source
	object_state=existing_object_state
	return true

func row(name: String,id: int)->Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[id] if id>=0 and id<rows.size() and rows[id] is Dictionary else {}
func has_row(name: String,id: int)->bool:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return id>=0 and id<rows.size() and rows[id] is Dictionary
static func signed32(value: int)->int:
	var bits:=value&0xffffffff
	return bits-0x100000000 if bits>=0x80000000 else bits
static func atoi(value: Variant)->int:
	var found:=RegEx.create_from_string("^\\s*([+-]?\\d+)").search(str(value) if value!=null else "")
	if found==null:return 0
	# combat_stats.js converts the decimal prefix through Number before | 0.
	# Keep the Number rounding and ToInt32 wrap for long 2DA cells too.
	var number:=float(found.get_string(1))
	return signed32(int(fposmod(number,4294967296.0))) if is_finite(number) else 0
func int_entry(name: String,id: int,column: String)->Dictionary:
	var table: Dictionary=tables.get(name,{})
	var source_row:=row(name,id)
	var value: Variant=null;var found:=false
	for key in source_row:
		if str(key).to_lower()==column.to_lower():value=source_row[key];found=true;break
	if not found:return {"found":false,"value":atoi(table.get("defaultValue"))}
	if value=="" or value=="****":return {"found":false,"value":0}
	var source:=str(value)
	var hex:=RegEx.create_from_string("^0[xX][0-9a-fA-F]+").search(source)
	return {"found":true,"value":signed32(hex.get_string().hex_to_int() if hex!=null else atoi(source))}
func string_entry(name: String,id: int,column: String)->String:
	var table: Dictionary=tables.get(name,{})
	var columns: Array=table.get("columns",[]);var column_index:=-1
	for index in columns.size():
		if str(columns[index]).to_lower()==column.to_lower():column_index=index;break
	var rows: Array=table.get("orderedRows",[])
	var value: Variant=table.get("defaultValue")
	if column_index>=0 and id>=0 and id<rows.size() and rows[id] is Dictionary:
		var cells: Array=table.get("orderedCells",[])
		value=cells[id][column_index] if id<cells.size() and column_index<cells[id].size() else rows[id].get(columns[column_index])
	return "" if value==null or value=="" or value=="****" else str(value)

func base_item_model_type(id: int)->Variant:
	var value: Dictionary=int_entry("baseitems",id,"ModelType")
	return int(value.value)&255 if value.found else null

func quickbar_item_info(id: int)->Dictionary:
	if not has_row("baseitems",id):return {}
	return {"container":int_entry("baseitems",id,"Container").value,"equipableSlots":int(int_entry("baseitems",id,"EquipableSlots").value)&0xffffffff}

func spell_input_info(id: int)->Dictionary:
	if not has_row("spells",id):return {}
	return {"targetType":int(int_entry("spells",id,"TargetType").value)&65535}

func feat_input_info(id: int)->Dictionary:
	if id<0 or id>=65536:return {}
	return {"available":true} if int_entry("feat",id,"Feat").found else {}

func class_info(id: int)->Variant:
	if not has_row("classes",id):return null
	var school: Dictionary=int_entry("classes",id,"PickSchool")
	var domains: Dictionary=int_entry("classes",id,"PickDomains")
	return {"pickSchool":int(school.value)!=0 if school.found else id==10,"pickDomains":int(domains.value)!=0 if domains.found else id==2}

func is_beam(id: int)->bool:
	return string_entry("visualeffects",id,"Type_FD") in ["B","P"]

func existing_state(id: int)->Variant:
	return object_state.call(id) if object_state.is_valid() else null

func providers()->Dictionary:
	return {"baseItemModelType":base_item_model_type,"classInfo":class_info,"isBeam":is_beam,"objectState":existing_state,"skillCount":tables.get("skills",{}).get("orderedRows",[]).size() & 255,"spellInputInfo":spell_input_info,"featInputInfo":feat_input_info}
