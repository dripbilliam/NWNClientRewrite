extends "res://systems/inventory_slot.gd"
func _get_drag_data(_point: Vector2) -> Variant:
	if not current() or channel!="B" or disabled or inventory.examine_mode: return null
	var data: Dictionary=inventory.owner_barter.payload(int(row.itemId))
	if data.is_empty(): return null
	var preview:=TextureRect.new(); preview.texture=image.texture; preview.custom_minimum_size=image.texture.get_size() if image.texture!=null else Vector2(32,32); preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; set_drag_preview(preview)
	return data
func _can_drop_data(point: Vector2,data: Variant) -> bool:
	return current() and channel=="B" and inventory.owner_barter.can_drop(data,get_parent().cell(position+point))
func _drop_data(point: Vector2,data: Variant) -> void:
	if _can_drop_data(point,data): inventory.owner_barter.drop(data,get_parent().cell(position+point))
