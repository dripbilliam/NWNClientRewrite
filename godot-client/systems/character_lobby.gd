extends CanvasLayer

signal request(message: Dictionary)
signal main_menu_requested
signal creation_requested
signal resource_progress(value: Dictionary)
var connection := 0
var state: Dictionary = {}
var panel: PanelContainer
var choices: ItemList
var preview: Label
var message: Label
var download_label: Label
var download_bar: ProgressBar
var join_button: Button
var play_button: Button
var create_button: Button
var cancel_button: Button
var disconnect_button: Button
var export_button: Button
var save_on_disconnect: CheckBox
var menu_button: Button
var keys: Array[String] = []
var last_auto_join := -1
var last_auto_choose := -1
var last_auto_play := -1
var preferred_auto_key := "installed:wizard.bic"

func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	menu_button = _button("Main Menu", func(): main_menu_requested.emit())
	menu_button.position = Vector2(1100, 16)
	root.add_child(menu_button)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 550)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.04, 0.98)
	style.border_color = Color(0.65, 0.56, 0.32)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Multiplayer · Characters"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	message = Label.new()
	message.text = "127.0.0.1:5121 · Existing protected login\nConnect, choose a local or server character, then Play."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(700, 65)
	column.add_child(message)
	download_label = Label.new(); download_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(download_label)
	download_bar = ProgressBar.new(); download_bar.custom_minimum_size = Vector2(700,20); download_bar.show_percentage = false
	column.add_child(download_bar)
	var row := HBoxContainer.new()
	column.add_child(row)
	choices = ItemList.new()
	choices.custom_minimum_size = Vector2(310, 310)
	choices.item_selected.connect(_choose)
	row.add_child(choices)
	preview = Label.new()
	preview.custom_minimum_size = Vector2(375, 310)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(preview)
	save_on_disconnect = CheckBox.new()
	save_on_disconnect.text = "Save character when disconnecting"
	save_on_disconnect.button_pressed = true
	save_on_disconnect.focus_mode = Control.FOCUS_NONE
	column.add_child(save_on_disconnect)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	join_button = _button("Connect to local server", func(): _send({"kind": "lobby-join"}))
	buttons.add_child(join_button)
	play_button = _button("Play selected", _play)
	buttons.add_child(play_button)
	create_button = _button("Create character", func(): if state.get("canCreate", false): panel.hide(); creation_requested.emit())
	buttons.add_child(create_button)
	export_button = _button("Export character", func(): _send({"kind": "lobby-export"}))
	buttons.add_child(export_button)
	disconnect_button = _button("Disconnect", func(): _send({"kind": "lobby-disconnect", "saveCharacter": save_on_disconnect.button_pressed}))
	buttons.add_child(disconnect_button)
	cancel_button = _button("Cancel connection", func(): _send({"kind":"lobby-cancel-join"}))
	column.add_child(cancel_button)
	column.add_child(_button("Return to game", func(): panel.hide()))
	get_viewport().size_changed.connect(_place)
	_place()
	apply_state({"connection": 0, "state": {"phase": "menu", "canJoin": false}})

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _place() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	panel.position = ((dimensions - panel.get_combined_minimum_size()) * 0.5).max(Vector2(0, 70))
	menu_button.position = Vector2(maxf(16, dimensions.x - 150), maxf(16, dimensions.y - 48))

func _send(value: Dictionary) -> void:
	value["connection"] = connection
	request.emit(value)

func _choose(index: int) -> void:
	if index >= 0 and index < keys.size() and state.get("canSelect", false):
		_send({"kind": "lobby-choose", "key": keys[index]})

func _play() -> void:
	var selected: Variant = state.get("selected")
	if selected != null and state.get("canSelect", false):
		_send({"kind": "lobby-play", "key": str(selected)})

func apply_state(value: Dictionary) -> void:
	var previous_phase := str(state.get("phase", ""))
	connection = int(value.connection)
	state = value.state
	var phase := str(state.get("phase", "menu"))
	var endpoint = state.get("endpoint")
	var address := "%s:%s" % [endpoint.host, endpoint.port] if endpoint is Dictionary else "127.0.0.1:5121"
	message.text = "%s · %s%s\n%s" % [address, phase, " · Working…" if state.get("busy", false) else "", state.get("error", "")]
	var progress: Variant = state.get("resourceProgress")
	var loading: bool = phase == "resources" and progress is Dictionary
	download_label.visible = loading; download_bar.visible = loading
	if loading:
		var total := int(progress.get("total",0)); var completed := int(progress.get("completed",0)); var bytes := int(progress.get("downloadedBytes",0))
		download_bar.indeterminate = progress.get("phase") == "server-manifest" or total == 0
		download_bar.max_value = maxi(1,total); download_bar.value = completed
		download_label.text = "Reading server content manifest…" if progress.get("phase") == "server-manifest" else "%s · %s / %s resources · %.1f MiB received" % ["Downloading server content" if bytes > 0 else "Checking cached server content",completed,total,bytes/1048576.0]
		resource_progress.emit({"connection":connection,"phase":progress.get("phase"),"completed":completed,"total":total,"downloadedBytes":bytes,"canCancel":state.get("canCancelJoin",false),"canPlay":state.get("canSelect",false)})
	choices.clear()
	keys.clear()
	for row in state.get("choices", []):
		keys.append(str(row.key))
		choices.add_item(str(row.label))
		if row.key == state.get("selected"):
			choices.select(keys.size() - 1)
	choices.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.visible = state.get("canCancelJoin", false)
	cancel_button.disabled = not state.get("canCancelJoin", false)
	join_button.disabled = not state.get("canJoin", false)
	play_button.disabled = not state.get("canSelect", false) or state.get("selected") == null
	create_button.disabled = not state.get("canCreate", false)
	disconnect_button.disabled = not state.get("connected", false) or state.get("busy", false)
	export_button.disabled = phase not in ["playing", "area-loading"] or state.get("busy", false)
	preview.text = _preview(state.get("preview"))
	call_deferred("_place")
	if state.get("creating", false): panel.hide()
	elif phase not in ["playing", "area-loading", "character"]:
		panel.show()
	elif phase != previous_phase:
		panel.hide()
	if value.get("auto", false):
		_auto()

func _auto() -> void:
	# Bounded integration tests use the same native UI requests as a player.
	if state.get("canJoin", false) and last_auto_join == -1:
		last_auto_join = connection
		_send({"kind": "lobby-join"})
	elif state.get("canSelect", false) and last_auto_choose != connection:
		var index := keys.find(preferred_auto_key)
		if index >= 0:
			last_auto_choose = connection
			_choose(index)
	elif state.get("canSelect", false) and state.get("selected") == preferred_auto_key and state.get("preview") != null and last_auto_play != connection:
		last_auto_play = connection
		_play()

func _preview(value: Variant) -> String:
	if not value is Dictionary:
		return "Select a character to inspect its server or local record.\n\nLocal-vault characters appear only when the server permits them."
	var first: Dictionary = value.get("firstName", {})
	var last: Dictionary = value.get("lastName", {})
	var lines: Array[String] = ["%s %s" % [first.get("text", ""), last.get("text", "")], "HP: %s / %s · XP: %s" % [value.get("currentHitPoints", "?"), value.get("hitPoints", "?"), value.get("experience", "?")]]
	for entry in value.get("classes", []):
		lines.append("Class %s · level %s" % [entry.get("id", "?"), entry.get("level", "?")])
	var abilities: Dictionary = value.get("abilities", {})
	for key in ["Str", "Dex", "Con", "Int", "Wis", "Cha"]:
		if abilities.has(key):
			lines.append("%s: %s" % [key, abilities[key]])
	lines.append("Feats: %s · Known spells: %s" % [value.get("feats", []).size(), value.get("spells", []).size()])
	return "\n".join(lines)

func blocks_pointer(point: Vector2) -> bool:
	return (panel.visible and panel.get_global_rect().has_point(point)) or menu_button.get_global_rect().has_point(point)
