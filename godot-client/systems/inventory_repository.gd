extends Control

var inventory
var columns := 10
var rows := 6
var channel := "R"
const CELL := 40
var cell_size:=40
var bottom_origin:=false
var native_art:=false
var last_drop: Dictionary={}

func _draw() -> void:
	if native_art: return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.9))
	for column in columns + 1: draw_line(Vector2(column * cell_size, 0), Vector2(column * cell_size, rows * cell_size), Color(0.3, 0.29, 0.22))
	for row in rows + 1: draw_line(Vector2(0, row * cell_size), Vector2(columns * cell_size, row * cell_size), Color(0.3, 0.29, 0.22))
func item_position(item: Dictionary) -> Vector2:
	var y:=int(item.y)%rows
	if bottom_origin: y=rows-y-maxi(1,int(item.height))
	return Vector2(int(item.x)*cell_size,y*cell_size)
func item_size(item: Dictionary) -> Vector2: return Vector2(maxi(1,int(item.width))*cell_size-1,maxi(1,int(item.height))*cell_size-1)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("kind","")=="native-barter-item": return channel=="R" and is_instance_valid(inventory.barter_owner) and inventory.barter_owner.can_remove(data)
	if data is Dictionary and data.get("kind","")=="native-inventory-gold": return channel=="C" and is_instance_valid(inventory.gold_owner) and inventory.gold_owner.can_target(data,int(inventory.state.get("container",{}).get("ownerId",2130706432)))
	return inventory.can_drop(data, 0)

func _drop_data(position: Vector2, data: Variant) -> void:
	last_drop={"local":str(position),"point":str(get_global_transform()*position),"entry":int(data.get("entryId",-1)) if data is Dictionary else -1}
	drop_global(data,get_global_transform()*position)

func drop_global(data: Dictionary, point: Vector2) -> void:
	if not inventory.wanted or not _can_drop_data(Vector2.ZERO,data): return
	var local: Vector2=get_global_transform().affine_inverse()*point
	if local.x<0 or local.y<0: return
	var cell:=Vector2i(floori(local.x/cell_size),floori(local.y/cell_size))
	if cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows: return
	if bottom_origin: cell.y=rows-cell.y-1
	if data.get("kind","")=="native-barter-item": inventory.barter_owner.remove_to(data,cell.x,cell.y+int(inventory.state.get("page",0))*rows); return
	if data.get("kind","")=="native-inventory-gold":
		inventory.gold_owner.drop_target(data,int(inventory.state.container.ownerId)); return
	if inventory.state.get("store", {}).get("open", false): inventory.select_item(int(data.entryId)); return
	var page: int = int(inventory.state.container.get("page", 0)) if channel == "C" else int(inventory.state.get("page", 0))
	inventory.operation(int(data.entryId), "unequip" if inventory.items[int(data.entryId)].channel == "I" else "move", {"destination": "container" if channel == "C" else "backpack", "x": cell.x, "y": cell.y + page * rows})
