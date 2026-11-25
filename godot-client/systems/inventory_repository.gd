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
var drop_outline:=Rect2i()
var drop_outline_valid:=false

func _ready() -> void:
	mouse_exited.connect(_clear_drop_outline)

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END: _clear_drop_outline()

func _draw() -> void:
	if not native_art:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.9))
		for column in columns + 1: draw_line(Vector2(column * cell_size, 0), Vector2(column * cell_size, rows * cell_size), Color(0.3, 0.29, 0.22))
		for row in rows + 1: draw_line(Vector2(0, row * cell_size), Vector2(columns * cell_size, row * cell_size), Color(0.3, 0.29, 0.22))
	if drop_outline.has_area():
		var bounds:=Rect2(Vector2(drop_outline.position)*cell_size,Vector2(drop_outline.size)*cell_size).grow(-1.0)
		var color:=Color(0.87,0.72,0.36) if drop_outline_valid else Color(0.85,0.29,0.24)
		draw_rect(bounds,Color(color,0.23))
		draw_rect(bounds,color,false,2.0)
func item_position(item: Dictionary) -> Vector2:
	var y:=int(item.y)%rows
	if bottom_origin: y=rows-y-maxi(1,int(item.height))
	return Vector2(int(item.x)*cell_size,y*cell_size)
func item_size(item: Dictionary) -> Vector2: return Vector2(maxi(1,int(item.width))*cell_size-1,maxi(1,int(item.height))*cell_size-1)

func _drop_footprint(position: Vector2, data: Dictionary) -> Rect2i:
	var item: Dictionary=inventory.items[int(data.entryId)]
	var footprint:=Vector2i(maxi(1,int(item.get("width",1))),maxi(1,int(item.get("height",1))))
	var grab: Vector2i=data.grabCell
	return Rect2i(Vector2i((position/cell_size).floor())-grab.clamp(Vector2i.ZERO,footprint-Vector2i.ONE),footprint)

func _set_drop_outline(outline: Rect2i, valid: bool) -> void:
	if drop_outline==outline and drop_outline_valid==valid: return
	drop_outline=outline
	drop_outline_valid=valid
	queue_redraw()

func _clear_drop_outline() -> void:
	_set_drop_outline(Rect2i(),false)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("kind","")=="native-barter-item": return channel=="R" and is_instance_valid(inventory.barter_owner) and inventory.barter_owner.can_remove(data)
	if data is Dictionary and data.get("kind","")=="native-inventory-gold": return channel=="C" and is_instance_valid(inventory.gold_owner) and inventory.gold_owner.can_target(data,int(inventory.state.get("container",{}).get("ownerId",2130706432)))
	var valid: bool=inventory.can_drop(data,0)
	if valid and data.get("grabCell") is Vector2i and not inventory.state.get("store",{}).get("open",false):
		if not position.is_finite():
			_clear_drop_outline()
			return false
		var footprint:=_drop_footprint(position,data)
		var grid:=Rect2i(0,0,columns,rows)
		valid=grid.encloses(footprint)
		_set_drop_outline(grid.intersection(footprint),valid)
	else:
		_clear_drop_outline()
	return valid

func _drop_data(position: Vector2, data: Variant) -> void:
	last_drop={"local":str(position),"point":str(get_global_transform()*position),"entry":int(data.get("entryId",-1)) if data is Dictionary else -1}
	drop_global(data,get_global_transform()*position)

func drop_global(data: Dictionary, point: Vector2) -> void:
	if not inventory.wanted: return
	var local: Vector2=get_global_transform().affine_inverse()*point
	if not _can_drop_data(local,data): return
	if local.x<0 or local.y<0: return
	var cell:=Vector2i(floori(local.x/cell_size),floori(local.y/cell_size))
	if cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows: return
	if bottom_origin: cell.y=rows-cell.y-1
	if data.get("kind","")=="native-barter-item": inventory.barter_owner.remove_to(data,cell.x,cell.y+int(inventory.state.get("page",0))*rows); return
	if data.get("kind","")=="native-inventory-gold":
		inventory.gold_owner.drop_target(data,int(inventory.state.container.ownerId)); return
	if inventory.state.get("store", {}).get("open", false): inventory.select_item(int(data.entryId)); return
	if data.get("grabCell") is Vector2i:
		var footprint:=_drop_footprint(local,data)
		cell=footprint.position
		if bottom_origin: cell.y=rows-cell.y-footprint.size.y
	var page: int = int(inventory.state.container.get("page", 0)) if channel == "C" else int(inventory.state.get("page", 0))
	inventory.operation(int(data.entryId), "unequip" if inventory.items[int(data.entryId)].channel == "I" else "move", {"destination": "container" if channel == "C" else "backpack", "x": cell.x, "y": cell.y + page * rows})
