extends SceneTree
func _initialize() -> void:
	var edit:=TextEdit.new(); var properties: Array=[]; var methods: Array=[]
	for row in edit.get_property_list():
		if "scroll" in str(row.name) or "wrap" in str(row.name): properties.append(row.name)
	for row in edit.get_method_list():
		if "caret" in str(row.name) or "line_height" in str(row.name) or "visible_line" in str(row.name): methods.append(row.name)
	print(JSON.stringify({"properties":properties,"methods":methods})); edit.free(); quit()
