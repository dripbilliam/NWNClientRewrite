extends Button
const SceneHost=preload("res://systems/native_item_icon_panel_host.gd")

var inventory
var row: Dictionary = {}
var slot := 0
var channel := ""
var bound_view := -1
var image: TextureRect
var count: Label
var caption: Label
var equipment_drop_feedback:=0
var _native_icon_center: Variant=null
var native_icon_center: Variant:
	get: return _native_icon_center
	set(value):
		_native_icon_center=value
		if is_instance_valid(inventory) and inventory.has_method("position_scene_icon") and inventory.scene_icon_backend_selected and row.has("entryId"):
			inventory.position_scene_icon(int(row.entryId))
static func scene_drag_preview(source,key: String,bundle: Dictionary,extent: Vector2=Vector2(50,50),grab: Vector2=Vector2.ZERO) -> Control:
	if not is_instance_valid(source) or key.is_empty() or bundle.is_empty(): return null
	var preview:=Control.new(); preview.size=extent; preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var host:=SceneHost.new(); preview.add_child(host); host.position=-grab; host.size=extent
	preview.ready.connect(func():
		if not host.configure(source.pool): return
		host.bind_slot("preview",key,bundle,extent*0.5))
	return preview

static func drag_preview_visual(texture: Texture2D,extent: Vector2,grab: Vector2) -> Control:
	var visual: Control
	if texture!=null:
		var raster:=TextureRect.new()
		raster.texture=texture
		raster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		raster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual=raster
	else:
		var outline:=Panel.new()
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.08,0.09,0.08,0.45)
		style.border_color=Color(0.78,0.68,0.38)
		style.set_border_width_all(1)
		outline.add_theme_stylebox_override("panel",style)
		visual=outline
	visual.size=extent
	visual.position=-grab
	visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return visual
func set_icon(texture: Texture2D) -> void:
	image.texture=texture; caption.hide(); refresh_icon()
func refresh_icon() -> void:
	if native_icon_center==null or image.texture==null: return
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	image.size=image.texture.get_size(); image.position=native_icon_center-image.size*0.5

func setup(owner, value: Dictionary, target_slot: int = 0) -> void:
	inventory = owner
	row = value
	channel = str(row.get("channel", ""))
	bound_view = inventory.view_id
	slot = target_slot
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.018, 0.92)
	style.border_color = Color(0.38, 0.34, 0.22)
	style.set_border_width_all(1)
	add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.border_color = Color(0.85, 0.74, 0.4)
	add_theme_stylebox_override("hover", hover)
	image = TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 11)
	add_child(caption)
	count = Label.new()
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_color_override("font_shadow_color", Color.BLACK)
	count.add_theme_constant_override("shadow_offset_x", 1)
	count.add_theme_constant_override("shadow_offset_y", 1)
	add_child(count)
	update_tooltip()
	mouse_entered.connect(func():
		if current() and is_instance_valid(inventory.item_tooltips) and row.has("entryId"): inventory.item_tooltips.enter(self))
	mouse_exited.connect(func():
		_set_equipment_drop_feedback(0)
		if is_instance_valid(inventory) and is_instance_valid(inventory.item_tooltips): inventory.item_tooltips.leave(self))
	refresh_row(row,inventory.view_id)
	pressed.connect(_item_pressed)

func _item_pressed() -> void:
	if not current() or not row.has("entryId"): return
	var entry:=int(row.entryId)
	if inventory.can_click_pickup() and not get_viewport().gui_is_dragging():
		var drag:=_make_item_drag(get_local_mouse_position())
		if not drag.is_empty():
			drag.data.clickPickup=true
			force_drag(drag.data,drag.preview)
	inventory.select_item(entry)

func current() -> bool:
	return is_instance_valid(inventory) and inventory.wanted and inventory.view_id == bound_view

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END: _set_equipment_drop_feedback(0)

func _set_equipment_drop_feedback(value: int) -> void:
	if equipment_drop_feedback==value: return
	equipment_drop_feedback=value
	queue_redraw()

func _draw() -> void:
	if equipment_drop_feedback==0: return
	var color:=Color(0.87,0.72,0.36) if equipment_drop_feedback>0 else Color(0.85,0.29,0.24)
	draw_rect(Rect2(Vector2.ZERO,size).grow(-1.0),color,false,2.0)
func refresh_row(value: Dictionary,view: int) -> void:
	row=value; channel=str(row.get("channel","")); bound_view=view
	update_tooltip(); disabled=bool(row.get("pending",false))
	count.text=str(int(row.get("stack",1))) if int(row.get("stack",1))>1 else ""
	caption.text=str(row.get("name","")).left(8)
	add_theme_font_size_override("font_size",11)
func update_tooltip() -> void:
	tooltip_text="" if is_instance_valid(inventory.item_tooltips) and row.has("entryId") else str(row.get("name",""))
	if is_instance_valid(inventory.item_tooltips): inventory.item_tooltips.register_control(self)
func _get_tooltip(_point: Vector2) -> String:
	return "" if get_meta("native_tooltip_managed",false) else tooltip_text
func native_tooltip_content() -> Dictionary:
	if not current(): return {}
	if row.is_empty():
		if tooltip_text.is_empty(): return {}
		var empty_rich:=preload("res://systems/native_data/rich_text.gd").parse(tooltip_text)
		return {"rich":empty_rich,"owner":get_instance_id(),"identity":[-1,hash(empty_rich)],"below":false}
	var rich: Dictionary=row.get("tooltip",{"text":str(row.get("name","")),"spans":[]})
	return {"rich":rich,"owner":get_parent().get_instance_id() if channel in ["R","C","M","A","B"] else get_instance_id(),"identity":[int(row.get("itemId",-1)),hash(rich)],"below":preload("res://systems/native_data/item_tooltip.gd").merchant_below(row)}

func _gui_input(event: InputEvent) -> void:
	if not current() or not row.has("entryId"): return
	if event is InputEventMouseButton and event.pressed:
		if is_instance_valid(inventory.item_tooltips): inventory.item_tooltips.cancel()
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			if inventory.examine_mode or inventory.can_click_pickup(): return
			inventory.operation(int(row.entryId), "activate")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			inventory.item_menu(int(row.entryId), get_global_mouse_position())
			accept_event()

func _get_drag_data(position_in_slot: Vector2) -> Variant:
	var drag:=_make_item_drag(position_in_slot)
	if drag.is_empty(): return null
	set_drag_preview(drag.preview)
	return drag.data

func _make_item_drag(position_in_slot: Vector2) -> Dictionary:
	if not current() or not inventory.item_commands_enabled or not row.has("entryId") or disabled or inventory.examine_mode or row.get("pending",false): return {}
	if is_instance_valid(inventory.item_tooltips): inventory.item_tooltips.cancel()
	var cell: float=inventory.container_repository.cell_size if channel=="C" else inventory.repository.cell_size
	var extent:=Vector2(maxi(1,int(row.get("width",1))),maxi(1,int(row.get("height",1))))*cell
	var grab:=extent*0.5
	if position_in_slot.is_finite():
		grab=position_in_slot if slot==0 else position_in_slot/size.max(Vector2.ONE)*extent
		grab=grab.clamp(Vector2.ZERO,extent)
	var preview: Control
	if inventory.scene_icon_backend_selected:
		var binding: Dictionary=inventory.scene_icon_bindings.get(int(row.entryId),{})
		preview=scene_drag_preview(inventory.scene_icon_source,str(binding.get("key","")),binding.get("bundle",{}),extent,grab)
	var fallback:=drag_preview_visual(image.texture,extent,grab)
	if preview==null:
		preview=Control.new()
		preview.size=extent
		preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		preview.add_child(fallback)
	else:
		var host:=preview.get_child(0)
		host.connect("presented",func(_revision): fallback.hide(),CONNECT_ONE_SHOT)
		preview.add_child(fallback)
		preview.move_child(fallback,0)
	var grab_cell:=Vector2i((grab/cell).floor()).clamp(Vector2i.ZERO,Vector2i(extent/cell)-Vector2i.ONE)
	var data:={"kind": "native-inventory-item", "dragOwner": inventory.get_instance_id(), "viewId": inventory.view_id, "entryId": int(row.entryId), "grabCell": grab_cell}
	return {"data":data,"preview":preview}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if current() and slot==0 and channel=="R" and data is Dictionary and data.get("kind","")=="native-barter-item": return is_instance_valid(inventory.barter_owner) and inventory.barter_owner.can_remove(data)
	if current() and row.has("itemId") and data is Dictionary and data.get("kind","")=="native-inventory-gold": return is_instance_valid(inventory.gold_owner) and inventory.gold_owner.can_target(data,int(row.itemId))
	if current() and slot==0 and channel in ["R","C"] and data is Dictionary and data.get("grabCell") is Vector2i:
		var repository: Control=inventory.container_repository if channel=="C" else inventory.repository
		return repository._can_drop_data(repository.get_global_transform().affine_inverse()*get_global_transform()*_position,data)
	var valid: bool=current() and inventory.can_drop(data,slot)
	if slot>0 and current() and data is Dictionary and data.get("kind")=="native-inventory-item" and int(data.get("dragOwner",-1))==inventory.get_instance_id():
		_set_equipment_drop_feedback(1 if valid else -1)
	return valid

func _drop_data(_position: Vector2, data: Variant) -> void:
	if current() and data is Dictionary and data.get("kind","")=="native-barter-item":
		if _can_drop_data(_position,data): inventory.repository.drop_global(data,get_global_transform()*_position)
		return
	if current() and data is Dictionary and data.get("kind","")=="native-inventory-gold":
		if _can_drop_data(_position,data): inventory.gold_owner.drop_target(data,int(row.itemId))
		return
	if not current() or not inventory.can_drop(data, slot): return
	if slot > 0: inventory.drop_slot(data, slot)
	else:
		var repository = inventory.store_panel.repository if channel == "M" and is_instance_valid(inventory.store_panel) else (inventory.container_repository if channel == "C" else inventory.repository)
		repository.drop_global(data,get_global_transform()*_position)
