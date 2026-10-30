extends Control
var owner_view
var side:="B"
func _can_drop_data(point: Vector2,data: Variant) -> bool:
	return side=="B" and owner_view.owner_barter.can_drop(data,cell(point))
func _drop_data(point: Vector2,data: Variant) -> void:
	if _can_drop_data(point,data): owner_view.owner_barter.drop(data,cell(point))
func cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/33.0),9-floori(point.y/33.0))
