extends Control
signal effect_selected(effect_id: int)
var native_skin
# Passive status presentation. Buttons only pin a tooltip; no gameplay packet.
const Images = preload("res://systems/runtime_image.gd")
var view_id := -1
var actor_id := -1
var staged: Dictionary = {}
var rows: Dictionary = {}
var buttons: Dictionary = {}
var images: Dictionary = {}
var scroll: ScrollContainer
var grid: GridContainer
var tip_layer: CanvasLayer
var tip: PanelContainer
var tip_text: Label
var hovered := -1
var pinned := false
var pinned_id := -1
var retired: Array = []
var art_error := ""
func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.mouse_filter = Control.MOUSE_FILTER_PASS; add_child(scroll)
	grid = GridContainer.new(); grid.add_theme_constant_override("h_separation", 3); grid.add_theme_constant_override("v_separation", 3); grid.mouse_filter = Control.MOUSE_FILTER_IGNORE; scroll.add_child(grid)
	tip_layer = CanvasLayer.new(); tip_layer.layer = 90; add_child(tip_layer)
	tip = PanelContainer.new(); tip.mouse_filter = Control.MOUSE_FILTER_IGNORE; tip_layer.add_child(tip)
	var style := StyleBoxFlat.new(); style.bg_color = Color("080e0bf5"); style.border_color = Color("ad9559"); style.set_border_width_all(1); style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 9; style.content_margin_bottom = 9; tip.add_theme_stylebox_override("panel", style)
	tip_text = Label.new(); tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE; tip_text.add_theme_color_override("font_color", Color("f0e5c5")); tip_text.add_theme_color_override("font_shadow_color", Color.BLACK); tip_text.add_theme_constant_override("shadow_offset_x", 1); tip_text.add_theme_constant_override("shadow_offset_y", 1); tip.add_child(tip_text)
	get_viewport().size_changed.connect(place); reset()
func reset() -> void:
	if native_skin!=null: native_skin.reset(); return
	if not buttons.is_empty() or not images.is_empty(): retired = (buttons.values() + images.values()).map(func(value): return weakref(value))
	view_id = -1; actor_id = -1; staged.clear(); rows.clear(); images.clear(); hide_tip()
	for button in buttons.values(): grid.remove_child(button); button.queue_free()
	buttons.clear(); hide()
func retired_alive() -> int: return retired.filter(func(value): return value.get_ref() != null).size()
func receive(message: Dictionary) -> void:
	if native_skin!=null: native_skin.receive(message); return
	match message.kind:
		"buff-begin": staged = {"id":int(message.viewId),"actor":int(message.actorId),"count":int(message.count),"rows":[]}
		"buff-rows":
			if int(message.viewId) == int(staged.get("id", -1)): staged.rows.append_array(message.rows)
		"buff-commit":
			if int(message.viewId) == int(staged.get("id", -1)) and staged.rows.size() == int(staged.count): commit()
		"buff-description", "buff-icon":
			var id := int(message.effectId)
			if int(message.viewId) != view_id or not buttons.has(id): return
			if message.kind == "buff-description":
				rows[id].label = str(message.label)
				if hovered == id: show_tip(id)
			else:
				var texture := Images.png(str(message.image), 512)
				if texture != null: images[id] = texture; rows[id].resource = str(message.get("resource", "")); buttons[id].get_node("Icon").texture = texture; buttons[id].text = ""
func commit() -> void:
	view_id = int(staged.id); actor_id = int(staged.actor)
	var next: Dictionary = {}
	for row in staged.rows: next[int(row.id)] = {"state":row.state,"label":rows.get(int(row.id), {}).get("label", "Effect %s" % int(row.id))}
	for id in buttons.keys():
		if not next.has(id):
			if hovered == id: hide_tip()
			grid.remove_child(buttons[id]); buttons[id].queue_free(); buttons.erase(id); images.erase(id)
	rows = next
	for id in rows:
		if not buttons.has(id):
			var button := Button.new(); button.name = "Effect%s" % id; button.custom_minimum_size = Vector2(36, 36); button.text = "?"; button.mouse_default_cursor_shape = Control.CURSOR_HELP; grid.add_child(button); buttons[id] = button
			var normal := StyleBoxFlat.new(); normal.bg_color = Color("090f0de8"); normal.border_color = Color("948355"); normal.set_border_width_all(1)
			var active: StyleBoxFlat = normal.duplicate(); active.bg_color = Color("263329"); active.border_color = Color("ead49b")
			for state in ["normal", "pressed", "disabled"]: button.add_theme_stylebox_override(state, normal)
			for state in ["hover", "hover_pressed", "focus"]: button.add_theme_stylebox_override(state, active)
			var image := TextureRect.new(); image.name = "Icon"; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.position = Vector2(2, 2); image.size = Vector2(32, 32); button.add_child(image)
			button.mouse_entered.connect(func(): pinned = false; pinned_id = -1; show_tip(id))
			button.mouse_exited.connect(func(): if not pinned and not button.has_focus(): hide_tip())
			button.focus_entered.connect(func(): show_tip(id)); button.focus_exited.connect(func(): if not pinned: hide_tip())
			button.pressed.connect(func():
				if pinned and pinned_id == id: hide_tip()
				else: pinned = true; pinned_id = id; show_tip(id))
		grid.move_child(buttons[id], grid.get_child_count() - 1)
	staged.clear(); visible = not rows.is_empty(); place()
func place() -> void:
	if scroll == null: return
	var viewport := get_viewport_rect().size; var columns := maxi(1, mini(rows.size(), floori(minf(680, maxf(36, viewport.x - 112)) / 39)))
	grid.columns = columns
	var width := columns * 39 - 3; var height := mini(ceili(float(rows.size()) / columns) * 39 - 3, int(minf(180, viewport.y * 0.3)))
	size = Vector2(width + (18 if grid.get_child_count() > columns * 4 else 0), maxi(0, height)); scroll.size = size; position = Vector2(maxf(4, viewport.x - 96 - size.x), 8)
	if hovered >= 0: call_deferred("place_tip")
func show_tip(id: int) -> void:
	if not rows.has(id): return
	hovered = id; tip_text.text = str(rows[id].label); tip_text.custom_minimum_size.x = minf(336, get_viewport_rect().size.x - 36); tip.size = Vector2.ZERO; tip.show(); call_deferred("place_tip")
func place_tip() -> void:
	if not buttons.has(hovered): return
	var extent := get_viewport_rect().size; var anchor: Rect2 = buttons[hovered].get_global_rect()
	tip.position = Vector2(maxf(4, minf(anchor.end.x - tip.size.x, extent.x - tip.size.x - 4)), maxf(4, minf(anchor.end.y + 6, extent.y - tip.size.y - 4)))
func hide_tip() -> void:
	hovered = -1; pinned = false; pinned_id = -1
	if is_instance_valid(tip): tip.hide()
func blocks_pointer(point: Vector2) -> bool:
	if native_skin!=null: return native_skin.blocks_pointer(point)
	if not visible: return false
	if scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().get_global_rect().has_point(point): return true
	return buttons.values().any(func(button): return scroll.get_global_rect().has_point(point) and button.get_global_rect().has_point(point))
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: hide_tip()
	elif event is InputEventMouseButton and event.pressed and not blocks_pointer(event.position): hide_tip()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: hide_tip()
