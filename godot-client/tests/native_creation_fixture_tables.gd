extends RefCounted
# Test-only coherent resource publication. Editing just orderedRows would leave
# orderedCells/rows referring to different values than the original loader sees.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func row_update(table: Dictionary,index: int,values: Dictionary) -> Dictionary:
	var result: Dictionary=table.duplicate(true)
	for key in values:
		var header: String=str(key);var found:=false
		for column in result.get("columns",[]):
			if str(column).to_lower()==str(key).to_lower():header=str(column);found=true;break
		if result.has("columns") and not found:result.columns.append(header)
		result.orderedRows[index][header]=str(values[key])
	if result.has("orderedCells"):
		result.orderedCells=[]
		for row in result.orderedRows:
			var cells: Array=[]
			for column in result.columns:cells.append(str(Game.cell(row,str(column),result.get("defaultValue","****"))))
			result.orderedCells.append(cells)
	if result.has("rowLabels"):
		result.rows={}
		for at in mini(result.rowLabels.size(),result.orderedRows.size()):
			var label:=str(result.rowLabels[at])
			if label.is_valid_int():result.rows[int(label)]=result.orderedRows[at]
	return result
