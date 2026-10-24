extends Control

var inventory
var columns := 10
var rows := 6
var channel := "R"
const CELL := 40

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.9))
	for column in columns + 1: draw_line(Vector2(column * CELL, 0), Vector2(column * CELL, rows * CELL), Color(0.3, 0.29, 0.22))
	for row in rows + 1: draw_line(Vector2(0, row * CELL), Vector2(columns * CELL, row * CELL), Color(0.3, 0.29, 0.22))

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return inventory.can_drop(data, 0)

func _drop_data(position: Vector2, data: Variant) -> void:
	drop_global(data, global_position + position)

func drop_global(data: Dictionary, point: Vector2) -> void:
	if not inventory.wanted or not inventory.can_drop(data, 0): return
	var cell := Vector2i((point - global_position) / CELL)
	if cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows: return
	if inventory.state.get("store", {}).get("open", false): inventory.select_item(int(data.entryId)); return
	var page: int = int(inventory.state.container.get("page", 0)) if channel == "C" else int(inventory.state.get("page", 0))
	inventory.operation(int(data.entryId), "unequip" if inventory.items[int(data.entryId)].channel == "I" else "move", {"destination": "container" if channel == "C" else "backpack", "x": cell.x, "y": cell.y + page * rows})
