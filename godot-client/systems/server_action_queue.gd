extends HBoxContainer
# Replicated action widgets. A click dims a widget; only server replication
# removes it. Local widget serials are never sent as native action IDs.
signal cancel_requested(action_id: int,group_id: int)
var rows: Array=[]
var buttons: Dictionary={}
var pending: Dictionary={}
var owner_ui
func setup(owner) -> void:
	owner_ui=owner; position=Vector2(20,30); add_theme_constant_override("separation",3); hide()
func reset() -> void:
	rows.clear(); pending.clear(); buttons.clear()
	for child in get_children(): remove_child(child); child.queue_free()
	hide()
func present(entries: Array) -> void:
	rows=entries.duplicate(true); buttons.clear()
	for serial in pending.keys():
		if not rows.any(func(row):return int(row.widgetSerial)==int(serial)): pending.erase(serial)
	for child in get_children(): remove_child(child); child.queue_free()
	for row in rows.slice(0,10):
		var serial:=int(row.widgetSerial); var button:=Button.new(); button.custom_minimum_size=Vector2(48,48); button.focus_mode=Control.FOCUS_NONE; button.tooltip_text="Cancel "+str(row.label); button.modulate.a=0.5 if pending.has(serial) else 1.0
		var icon:=TextureRect.new(); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left=6; icon.offset_top=6; icon.offset_right=-6; icon.offset_bottom=-6; icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(icon)
		add_child(button); buttons[serial]=button; owner_ui.art.bind(icon,str(row.icon))
		var style:=StyleBoxTexture.new(); button.add_theme_stylebox_override("normal",style); owner_ui.art.bind(style,"ctl_actionqueue","texture",true)
		button.pressed.connect(func():
			if pending.has(serial) or not rows.any(func(current):return current==row): return
			pending[serial]=true; button.modulate.a=0.5; cancel_requested.emit(int(row.type),int(row.group)))
	visible=not rows.is_empty()
func rejected() -> void: pending.clear(); present(rows)
func blocks_pointer(point: Vector2) -> bool: return visible and get_global_rect().has_point(point)
