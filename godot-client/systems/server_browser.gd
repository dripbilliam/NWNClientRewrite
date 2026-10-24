extends CanvasLayer

signal request(message: Dictionary)
signal closed
var connection := 0
var view_id := -1
var state: Dictionary = {}
var panel: PanelContainer
var host_edit: LineEdit
var port_edit: SpinBox
var name_edit: LineEdit
var password_edit: LineEdit
var key_edit: LineEdit
var filter_edit: LineEdit
var sort_edit: OptionButton
var tab_buttons: Dictionary = {}
var filters: Dictionary = {}
var tree: Tree
var info: Label
var status: Label
var policy_label: Label
var paging: Label
var refresh_button: Button
var inspect_button: Button
var favorite_button: Button
var connect_button: Button
var previous_button: Button
var next_button: Button
var apply_button: Button
var entries: Dictionary = {}
var selected := -1
var wanted := false
var loaded_draft := false
var direct_row: HBoxContainer
var list_box: VBoxContainer

func _ready() -> void:
	layer = 25
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); root.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("0b1110fa"); style.border_color = Color("b9a16b"); style.set_border_width_all(1); style.set_content_margin_all(16); panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); scroll.add_child(box)
	var heading := Label.new(); heading.text = "Multiplayer · Servers"; heading.add_theme_font_size_override("font_size", 24); box.add_child(heading)
	policy_label = Label.new(); policy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(policy_label)
	var tabs := HBoxContainer.new(); box.add_child(tabs)
	for tab in ["Direct", "Internet", "History", "Favorites"]:
		var button := _button(tab, _tab.bind(tab)); button.toggle_mode = true; tabs.add_child(button); tab_buttons[tab] = button
	direct_row = HBoxContainer.new(); box.add_child(direct_row)
	_label(direct_row, "Address"); host_edit = _edit(direct_row, 255, "127.0.0.1"); host_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(direct_row, "UDP port"); port_edit = SpinBox.new(); port_edit.min_value = 1; port_edit.max_value = 65535; port_edit.value = 5121; port_edit.allow_greater = false; direct_row.add_child(port_edit)
	list_box = VBoxContainer.new(); box.add_child(list_box)
	var search := HBoxContainer.new(); list_box.add_child(search); _label(search, "Filter"); filter_edit = _edit(search, 128, "Server, module or address"); filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_edit = OptionButton.new(); search.add_child(sort_edit)
	for item in ["Name", "Module", "Players", "Latency"]: sort_edit.add_item(item)
	apply_button = _button("Apply", _filter); search.add_child(apply_button); filter_edit.text_submitted.connect(func(_value): _filter())
	var filter_row := HBoxContainer.new(); list_box.add_child(filter_row)
	for definition in [["local", "Local vault"], ["server", "Server vault"], ["password", "Password protected"]]:
		var toggle := CheckBox.new(); toggle.text = definition[1]; toggle.button_pressed = true; toggle.focus_mode = Control.FOCUS_NONE; filter_row.add_child(toggle); filters[definition[0]] = toggle
	tree = Tree.new(); tree.hide_root = true; tree.columns = 7; tree.column_titles_visible = true; tree.custom_minimum_size.y = 190; tree.size_flags_vertical = Control.SIZE_EXPAND_FILL; list_box.add_child(tree)
	var titles := ["Server / address", "Module", "Players", "Levels", "Vault", "PW", "Ping"]
	for index in titles.size():
		tree.set_column_title(index, titles[index]); tree.set_column_expand(index, index < 2); tree.set_column_custom_minimum_width(index, 52 if index > 1 else 170)
	tree.item_selected.connect(_select); tree.item_activated.connect(_inspect)
	var pages := HBoxContainer.new(); list_box.add_child(pages); previous_button = _button("Previous", _page.bind(-1)); pages.add_child(previous_button); paging = Label.new(); paging.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pages.add_child(paging); next_button = _button("Next", _page.bind(1)); pages.add_child(next_button)
	info = Label.new(); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size.y = 70; box.add_child(info)
	var player := HBoxContainer.new(); box.add_child(player); _label(player, "Player name"); name_edit = _edit(player, 64, "Player name"); name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _label(player, "Server password"); password_edit = _edit(player, 255, "Optional"); password_edit.secret = true; password_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key_row := HBoxContainer.new(); box.add_child(key_row); _label(key_row, "CD key"); key_edit = _edit(key_row, 41, "Leave blank to use the key saved in Options"); key_edit.secret = true; key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(status)
	var buttons := HBoxContainer.new(); box.add_child(buttons); refresh_button = _button("Refresh", func(): _send("refresh")); buttons.add_child(refresh_button); inspect_button = _button("Server info", _inspect); buttons.add_child(inspect_button); favorite_button = _button("Toggle favorite", _favorite); buttons.add_child(favorite_button); connect_button = _button("Connect", _join); buttons.add_child(connect_button); buttons.add_child(_button("Back", close))
	panel.hide(); get_viewport().size_changed.connect(place)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(callback); return button

func _label(parent: Node, text: String) -> void:
	var label := Label.new(); label.text = text; parent.add_child(label)

func _edit(parent: Node, limit: int, hint: String) -> LineEdit:
	var edit := LineEdit.new(); edit.max_length = limit; edit.placeholder_text = hint; edit.custom_minimum_size.x = 135; parent.add_child(edit); return edit

func place() -> void:
	var available := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(1050, maxf(300, available.x - 32)), minf(760, maxf(240, available.y - 70)))
	panel.position = ((available - panel.size) * 0.5).max(Vector2.ZERO)

func open() -> void:
	wanted = true; view_id = -1; loaded_draft = false; clear_secrets(); panel.show(); status.text = "Reading saved servers…"; _enable(false); place(); _send("open")

func clear_secrets() -> void:
	password_edit.clear(); key_edit.clear()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == password_edit or focused == key_edit: focused.release_focus()

func reset(value: int) -> void:
	connection = value; wanted = false; loaded_draft = false; view_id = -1; state = {}; entries.clear(); selected = -1; clear_secrets(); panel.hide()

func close() -> void:
	wanted = false; clear_secrets(); panel.hide(); _send("close"); closed.emit()

func _send(operation: String, fields: Dictionary = {}) -> void:
	var message := {"kind":"browser-input", "connection":connection, "viewId":view_id, "operation":operation}; message.merge(fields, true)
	if operation not in ["open", "close"]: state["busy"] = true; _enable(false)
	request.emit(message)

func _tab(tab: String) -> void:
	if view_id >= 0 and not state.get("busy", false): _send("tab", {"tab":tab})

func _filter() -> void:
	if view_id < 0 or state.get("busy", false): return
	var values := {}; for key in filters: values[key] = filters[key].button_pressed
	_send("filter", {"filter":filter_edit.text, "sort":sort_edit.get_item_text(sort_edit.selected), "filters":values})

func _page(offset: int) -> void:
	_send("page", {"page":int(state.get("page", 0)) + offset})

func _select() -> void:
	var item := tree.get_selected()
	if item and not state.get("busy", false): _send("select", {"entryId":int(item.get_metadata(0))})

func _endpoint() -> Dictionary:
	return {"host":host_edit.text, "port":int(port_edit.value)}

func _selection() -> Dictionary:
	var direct: bool = state.get("tab", "Direct") == "Direct"
	return {"direct":direct, "entryId":selected, "values":_endpoint() if direct else {}}

func _inspect() -> void:
	if not inspect_button.disabled: _send("inspect", _selection())

func _favorite() -> void:
	if not favorite_button.disabled: _send("favorite", _selection())

func _join() -> void:
	if connect_button.disabled: return
	var fields := _selection(); fields.values.merge({"name":name_edit.text, "password":password_edit.text, "cdKey":key_edit.text}, true)
	_send("join", fields); clear_secrets(); _enable(false); status.text = "Connecting…"

func _enable(enabled: bool) -> void:
	for button in tab_buttons.values(): button.disabled = not enabled
	for button in [refresh_button, inspect_button, favorite_button, connect_button, previous_button, next_button, apply_button]: button.disabled = not enabled
	for edit in [host_edit, name_edit, password_edit, key_edit, filter_edit]: edit.editable = enabled
	port_edit.editable = enabled; sort_edit.disabled = not enabled; tree.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for toggle in filters.values(): toggle.disabled = not enabled

func receive(message: Dictionary) -> void:
	if int(message.get("connection", -1)) != connection: return
	if message.kind == "browser-closed": wanted = false; clear_secrets(); panel.hide(); return
	if message.kind == "browser-notice": status.text = str(message.text); clear_secrets(); return
	if message.kind != "browser-view" or not wanted and not message.get("reopen", false): return
	wanted = true; state = message.duplicate(true); view_id = int(message.viewId); panel.show()
	if not loaded_draft:
		var draft: Dictionary = message.get("direct", {}); host_edit.text = str(draft.get("host", "127.0.0.1")); port_edit.value = int(draft.get("port", 5121)); name_edit.text = str(draft.get("name", "")); loaded_draft = true
	var direct := str(message.tab) == "Direct"; direct_row.visible = direct; list_box.visible = not direct
	for tab in tab_buttons: tab_buttons[tab].set_pressed_no_signal(tab == message.tab)
	filter_edit.text = str(message.get("filter", "")); sort_edit.select(["Name", "Module", "Players", "Latency"].find(str(message.get("sort", "Players"))))
	for key in filters: filters[key].set_pressed_no_signal(bool(message.get("filters", {}).get(key, true)))
	policy_label.text = "Local testing: only 127.0.0.1:5121 is enabled. Internet discovery is off." if message.get("localOnly", true) and not message.get("canDiscover", false) else "Only servers enabled for this session can be queried or joined."
	key_edit.placeholder_text = "Saved protected key will be used; enter only to replace for this login" if message.get("hasSavedCdKey", false) else "No saved key — enter a key or save one in Options"
	entries.clear(); selected = -1; tree.set_block_signals(true); tree.clear(); var tree_root := tree.create_item()
	for row in message.get("rows", []):
		var id := int(row.entryId); entries[id] = row; var item := tree.create_item(tree_root); item.set_metadata(0, id)
		item.set_text(0, ("★ " if row.get("favorite", false) else "") + str(row.get("serverName", "")) + " · " + str(row.host) + ":" + str(row.port)); item.set_text(1, str(row.get("moduleName", ""))); item.set_text(2, "%s / %s" % [row.get("playerCount", "?"), row.get("maximumPlayers", "?")]); item.set_text(3, "%s–%s" % [row.get("minimumLevel", "?"), row.get("maximumLevel", "?")]); item.set_text(4, "Local" if row.get("allowLocalVaultCharacters") == true else "Server" if row.get("allowLocalVaultCharacters") == false else "?"); item.set_text(5, "Yes" if row.get("passwordRequired", false) else ""); item.set_text(6, str(row.get("latency", "?")))
		item.set_tooltip_text(0, "Enabled" if row.get("allowed", false) else "Not enabled for this session")
		if row.get("selected", false): selected = id; item.select(0)
	tree.set_block_signals(false)
	var detail = message.get("details"); info.text = "Enter an address or select a server, then request Server info."
	if detail is Dictionary:
		info.text = "%s · %s:%s\n%s\n%s" % [detail.get("serverName", "Server"), detail.host, detail.port, detail.get("moduleName", ""), str(detail.get("description", "")).left(4096)]
	status.text = str(message.get("status", "")); paging.text = "Page %s / %s · %s servers" % [int(message.get("page", 0)) + 1, message.get("pages", 1), message.get("total", 0)]
	var enabled: bool = not message.get("busy", false); _enable(enabled)
	refresh_button.visible = message.tab == "Internet"; refresh_button.disabled = not enabled or not message.get("canDiscover", false)
	previous_button.disabled = not enabled or int(message.get("page", 0)) == 0; next_button.disabled = not enabled or int(message.get("page", 0)) + 1 >= int(message.get("pages", 1))
	inspect_button.disabled = not enabled or not direct and (selected < 0 or not entries.get(selected, {}).get("allowed", false)); connect_button.disabled = not enabled or not message.get("canJoin", false) or not direct and (selected < 0 or not entries.get(selected, {}).get("allowed", false)); favorite_button.disabled = not enabled or not direct and selected < 0
	place()

func blocks_pointer(point: Vector2) -> bool:
	return panel.visible and panel.get_global_rect().has_point(point)
