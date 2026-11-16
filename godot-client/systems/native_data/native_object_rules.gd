extends RefCounted
# Server object-update schemas from the same original 2DA tables used by the
# Godot renderer/UI. The parser never guesses a table-dependent field width.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
var tables: Dictionary={}
var object_state: Callable

func configure(source: Dictionary,existing_object_state: Callable=Callable())->bool:
	for name in ["baseitems","classes","visualeffects","skills"]:
		if not source.has(name) or not source[name] is Dictionary or not source[name].get("orderedRows") is Array or source[name].orderedRows.is_empty():return false
	tables=source
	object_state=existing_object_state
	return true

func row(name: String,id: int)->Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[id] if id>=0 and id<rows.size() and rows[id] is Dictionary else {}

func base_item_model_type(id: int)->Variant:
	var value: Variant=Rules.cell(row("baseitems",id),"ModelType")
	var source:=str(value)
	return int(source)&255 if source.is_valid_int() else null

func quickbar_item_info(id: int)->Dictionary:
	var entry:=row("baseitems",id)
	if entry.is_empty():return {}
	var container_text:=str(Rules.cell(entry,"Container","0"))
	var slots_text:=str(Rules.cell(entry,"EquipableSlots","0"))
	var container:=container_text.hex_to_int() if container_text.to_lower().begins_with("0x") else int(container_text) if container_text.is_valid_int() else 0
	var slots:=slots_text.hex_to_int() if slots_text.to_lower().begins_with("0x") else int(slots_text) if slots_text.is_valid_int() else 0
	return {"container":container,"equipableSlots":slots&0xffffffff}

func class_info(id: int)->Variant:
	var entry:=row("classes",id)
	if entry.is_empty():return null
	var school: Variant=Rules.cell(entry,"PickSchool")
	var domains: Variant=Rules.cell(entry,"PickDomains")
	return {"pickSchool":int(str(school))!=0 if str(school).is_valid_int() else id==10,"pickDomains":int(str(domains))!=0 if str(domains).is_valid_int() else id==2}

func is_beam(id: int)->bool:
	return str(Rules.cell(row("visualeffects",id),"Type_FD","")) in ["B","P"]

func existing_state(id: int)->Variant:
	return object_state.call(id) if object_state.is_valid() else null

func providers()->Dictionary:
	return {"baseItemModelType":base_item_model_type,"classInfo":class_info,"isBeam":is_beam,"objectState":existing_state,"skillCount":tables.get("skills",{}).get("orderedRows",[]).size() & 255}
