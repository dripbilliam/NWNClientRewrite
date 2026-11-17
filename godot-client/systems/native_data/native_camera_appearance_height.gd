extends RefCounted
# C2DA::GetFLOATEntry semantics used by the original network camera.
static func native_float(value: Variant)->float:
	var pattern:=RegEx.create_from_string("^\\s*[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?")
	var match_value:=pattern.search(str(value))
	var number:=float(match_value.get_string()) if match_value!=null else 0.0
	return float(PackedFloat32Array([number])[0])

static func from_table(object: Dictionary,table: Dictionary)->float:
	var appearance: Variant=object.get("appearance")
	var index: Variant=appearance.get("appearance") if appearance is Dictionary else null
	if table.is_empty() or not index is int:return 1.0
	var rows: Array=table.get("orderedRows",[])
	var column: String=""
	for candidate in table.get("columns",[]):
		if str(candidate).to_lower()=="height":column=str(candidate);break
	if index<0 or index>=rows.size() or column.is_empty():return native_float(table.get("defaultValue",""))
	var row: Variant=rows[index]
	if not row is Dictionary:return native_float(table.get("defaultValue",""))
	var cell: Variant=row.get(column)
	if cell==null or str(cell).is_empty() or str(cell)=="****":return 0.0
	return native_float(cell)
