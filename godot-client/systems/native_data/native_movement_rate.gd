extends RefCounted

# C2DA::GetFLOATEntry: the unsuccessful row/column path writes the table
# default, while an empty physical cell writes zero.
static func _f(value: float) -> float:
	return Vector3(value,0.0,0.0).x

static func _float_prefix(value: Variant) -> float:
	var expression:=RegEx.create_from_string("^\\s*[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?")
	var match_result:=expression.search("" if value==null else str(value))
	return _f(float(match_result.get_string()) if match_result!=null else 0.0)

static func _rows(table: Dictionary) -> Array:
	if table.get("orderedRows") is Array:return table.orderedRows
	return table.get("rows",{}).values() if table.get("rows",{}) is Dictionary else []

static func _cell(row: Dictionary,column: String) -> Variant:
	for key in row:
		if str(key).to_lower()==column.to_lower():return row[key]
	return null

static func native_float_entry(table: Variant,index: Variant,column: String) -> Dictionary:
	if not table is Dictionary:return {"error":"Native movement-rate 2DA is unavailable"}
	var list: Array=_rows(table)
	var valid_index:=typeof(index) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(index)) and float(index)==floorf(float(index)) and int(index)>=0 and int(index)<list.size()
	var row: Variant=list[int(index)] if valid_index else null
	var has_column:=false
	for key in table.get("columns",[]):
		if str(key).to_lower()==column.to_lower():has_column=true;break
	if not row is Dictionary or not has_column:return {"found":false,"value":_float_prefix(table.get("defaultValue",""))}
	var cell: Variant=_cell(row,column)
	if cell==null or str(cell) in ["","****"]:return {"found":false,"value":0.0}
	return {"found":true,"value":_float_prefix(cell)}

static func native_float_entry_by_index(table: Variant,index: Variant,column: Variant) -> Dictionary:
	if typeof(index) not in [TYPE_INT,TYPE_FLOAT] or typeof(column) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(index)) or not is_finite(float(column)) or float(index)!=floorf(float(index)) or float(column)!=floorf(float(column)):
		return {"error":"Native physical FLOAT indices are unavailable"}
	if not table is Dictionary:return {"error":"Native movement-rate 2DA is unavailable"}
	var list: Array=_rows(table)
	var columns: Array=table.get("columns",[])
	if int(index)<0 or int(index)>=list.size() or int(column)<0 or int(column)>=columns.size():return {"found":false,"value":_float_prefix(table.get("defaultValue",""))}
	var cells: Variant=table.get("orderedCells")
	if not cells is Array:
		var seen: Dictionary={}
		for key in columns:
			if seen.has(key):return {"error":"Native duplicate FLOAT columns require physical cell storage"}
			seen[key]=true
	var cell: Variant=null
	if cells is Array and int(index)<cells.size() and cells[int(index)] is Array and int(column)<cells[int(index)].size():cell=cells[int(index)][int(column)]
	elif list[int(index)] is Dictionary:cell=list[int(index)].get(columns[int(column)])
	if cell==null or str(cell) in ["","****"]:return {"found":false,"value":0.0}
	return {"found":true,"value":_float_prefix(cell)}
