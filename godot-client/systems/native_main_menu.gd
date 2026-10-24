extends CanvasLayer
signal multiplayer_requested
signal options_requested
signal exit_requested
var panel: PanelContainer
var resume: Button
func _ready() -> void:
	layer = 30
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(320, 280); root.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("0b1110f5"); style.border_color = Color("b9a16b"); style.set_border_width_all(1); style.set_content_margin_all(22); panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); panel.add_child(box)
	var title := Label.new(); title.text = "Neverwinter Nights"; title.add_theme_font_size_override("font_size", 25); box.add_child(title)
	for definition in [["Multiplayer", "multiplayer"], ["Options", "options"], ["Return to game", "resume"], ["Exit", "exit"]]:
		var button := Button.new(); button.text = definition[0]; button.focus_mode = Control.FOCUS_NONE; box.add_child(button)
		if definition[1] == "resume": resume = button
		button.pressed.connect(choose.bind(str(definition[1])))
	get_viewport().size_changed.connect(place); panel.hide(); call_deferred("place")
func choose(id: String) -> void:
	panel.hide()
	if id == "multiplayer": multiplayer_requested.emit()
	elif id == "options": options_requested.emit()
	elif id == "exit": exit_requested.emit()
func open(playing: bool) -> void: resume.visible = playing; panel.show(); place()
func place() -> void: panel.position = ((get_viewport().get_visible_rect().size - panel.size) * 0.5).max(Vector2.ZERO)
func blocks_pointer(point: Vector2) -> bool: return panel.visible and panel.get_global_rect().has_point(point)
