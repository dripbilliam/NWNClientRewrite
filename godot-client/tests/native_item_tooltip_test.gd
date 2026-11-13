extends "res://tests/native_object_caption_test.gd"
const TooltipData=preload("res://systems/native_data/item_tooltip.gd")
const TooltipOwner=preload("res://systems/native_item_tooltip.gd")
const InventoryOwner=preload("res://systems/native_inventory.gd")
func data_checks(text) -> void:
	super.data_checks(text)
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tooltip-oracle="): path=arg.trim_prefix("--tooltip-oracle=")
	var observed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(observed.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.compositions.size()==60 and observed.positions.size()==36,"Tooltip observations pin the original compose/placement routines")
	check(TooltipData.merchant_below({"channel":"M","y":0}) and TooltipData.merchant_below({"channel":"M","y":11}) and not TooltipData.merchant_below({"channel":"M","y":12}) and not TooltipData.merchant_below({"channel":"R","y":1}),"Original first-two-local-row placement remains correct on later merchant pages and does not affect carried items")
	for row in observed.compositions:
		var item:={"name":{"text":row.name},"field2b8":row.mode,"field2c0":row.custom}; var before:=item.duplicate(true)
		check(TooltipData.project(item,text,42)==Rich.parse(row.output.raw) and item==before,"Original item tooltip composition "+str([row.mode,row.name,row.custom,row.below]))
	for row in observed.positions:
		var anchor:=Vector2(row.output.anchor[0],row.output.anchor[1]); var dimensions:=Vector2(row.dimensions[0],row.dimensions[1]); var point:=Vector2(row.point[0],row.point[1]); var viewport:=Vector2(row.viewport[0],row.viewport[1])
		check(TooltipData.position_at(point,viewport,dimensions,bool(row.below),float(row.scale)).is_equal_approx((anchor-Vector2(0,dimensions.y))*float(row.scale)),"Original item tooltip position "+str([row.point,row.scale,row.dimensions,row.below]))
