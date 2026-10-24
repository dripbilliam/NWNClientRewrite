extends SceneTree
const Browser = preload("res://systems/server_browser.gd")
const Client = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array[String] = []
var messages: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := "res://reports/browser-ui-native-v1.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	root.size = Vector2i(1200, 850)
	var ui := Browser.new(); root.add_child(ui); ui.request.connect(func(m): messages.append(m.duplicate(true))); await process_frame
	ui.open(); await process_frame
	check(ui.panel.visible and ui.connect_button.disabled and messages.back().operation == "open", "Open waits for backend readiness before enabling Connect")
	var view := {"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"canJoin":true,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
	ui.receive(view); await process_frame
	check(ui.host_edit.text == "127.0.0.1" and ui.port_edit.value == 5121 and ui.name_edit.text == "Tester", "Safe saved endpoint and player name fill Direct Connect")
	check(ui.password_edit.secret and ui.key_edit.secret and ui.password_edit.max_length == 255 and ui.key_edit.max_length == 41, "Transient credential editors are masked and bounded")
	check(ui.policy_label.text.contains("127.0.0.1:5121") and ui.policy_label.text.contains("off"), "Local-only connection policy is visible")
	ui.password_edit.text = "Authored password"; ui.key_edit.text = "Authored key"; ui.connect_button.pressed.emit()
	check(messages.back().operation == "join" and messages.back().direct and messages.back().values.password == "Authored password" and messages.back().values.cdKey == "Authored key", "Connect sends the draft through the scoped login request")
	check(ui.password_edit.text.is_empty() and ui.key_edit.text.is_empty() and ui.connect_button.disabled, "Sending immediately clears both credentials and locks duplicate submission")
	ui.reset(1); check(not ui.panel.visible and ui.view_id == -1, "Connection replacement retires the old native browser")
	ui.receive(view); check(not ui.panel.visible, "A retired connection cannot reopen the browser")
	view.connection = 1; view.viewId = 2; view.reopen = true; view.status = "Auth rejected"; ui.receive(view)
	check(ui.panel.visible and ui.status.text == "Auth rejected" and ui.password_edit.text.is_empty(), "Failed login can explicitly reopen a safe retry draft")
	ui.host_edit.text = "draft.invalid"; view.viewId = 3; ui.receive(view)
	check(ui.host_edit.text == "draft.invalid", "Metadata updates do not overwrite an edited direct address")
	view.tab = "Favorites"; view.viewId = 4; view.rows = [{"entryId":5,"host":"127.0.0.1","port":5121,"serverName":"Owned","moduleName":"Fixture","favorite":true,"selected":true,"allowed":true,"allowLocalVaultCharacters":true},{"entryId":9,"host":"unapproved.invalid","port":5121,"serverName":"Not enabled","selected":false,"allowed":false}]; ui.receive(view); await process_frame
	check(not ui.direct_row.visible and ui.list_box.visible and ui.selected == 5 and not ui.connect_button.disabled, "Saved-server selection enables the approved row without connecting automatically")
	check(messages.back().operation == "join", "Rendering selected rows does not emit extra selection or login events")
	ui.tree.get_root().get_child(1).select(0); await process_frame
	check(messages.back().operation == "select" and messages.back().entryId == 9 and not messages.back().has("host"), "Tree selection sends only the current private entry handle")
	view.viewId = 5; view.rows[0].selected = false; view.rows[1].selected = true; ui.receive(view)
	check(ui.connect_button.disabled and ui.inspect_button.disabled and not ui.favorite_button.disabled, "Unapproved rows may be saved but cannot be queried or joined")
	view.busy = true; view.viewId = 6; ui.receive(view)
	check(ui.host_edit.editable == false and ui.tab_buttons.Direct.disabled and ui.apply_button.disabled, "Busy requests disable conflicting controls")
	view.busy = false; view.tab = "Internet"; view.canDiscover = false; view.viewId = 7; ui.receive(view)
	check(ui.refresh_button.visible and ui.refresh_button.disabled, "Internet Refresh stays disabled without discovery permission")
	ui.password_edit.text = "discard"; ui.key_edit.text = "discard"; ui.close()
	check(not ui.panel.visible and ui.password_edit.text.is_empty() and ui.key_edit.text.is_empty() and messages.back().operation == "close", "Back clears credentials and cancels the current browser owner")
	view.reopen = false; ui.receive(view); check(not ui.panel.visible, "Queued old views cannot undo Back")
	ui.open(); view.tab = "History"; view.viewId = 8; view.pages = 3; view.page = 1; ui.receive(view); await process_frame
	check(not ui.previous_button.disabled and not ui.next_button.disabled and ui.paging.text.contains("2 / 3"), "Paged catalogs expose native Previous and Next controls")
	check(ui.blocks_pointer(ui.panel.get_global_rect().get_center()) and not ui.blocks_pointer(Vector2(-10,-10)), "Browser blocks only its actual panel rectangle")
	var pointer: Vector2 = ui.tab_buttons.Direct.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = pointer; motion.global_position = pointer; root.push_input(motion, true)
	var down := InputEventMouseButton.new(); down.position = pointer; down.global_position = pointer; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true; root.push_input(down, true); await process_frame
	var up := InputEventMouseButton.new(); up.position = pointer; up.global_position = pointer; up.button_index = MOUSE_BUTTON_LEFT; up.button_mask = 0; up.pressed = false; root.push_input(up, true); await process_frame
	check(messages.back().operation == "tab" and messages.back().tab == "Direct", "Authored pointer dispatch reaches the native Direct tab")
	check(ui.tab_buttons.History.disabled, "Pointer submission immediately locks controls before the backend reply")
	ui.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
