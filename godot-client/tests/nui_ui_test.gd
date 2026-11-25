extends SceneTree
const Connection = preload("res://systems/local_connection.gd")
const Manager = preload("res://systems/server_nui.gd")
var failures: Array = []
var checks := 0
var observations: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
func click_choice(button: Button, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if mouse_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
func selected_choices(element) -> Array:
	var selected: Array = []
	for index in element.option_buttons.size():
		if element.option_buttons[index].button_pressed: selected.append(index)
	return selected
func choice_changes(sent: Array, control_id: int) -> Array:
	return sent.filter(func(row): return row.get("operation") == "change" and row.get("controlId") == control_id).map(func(row): return row.value)
func choice_pointer_events(sent: Array, first: int, control_id: int) -> Array:
	return sent.slice(first).filter(func(row):
		return row.get("controlId") == control_id and row.get("event") in ["mousedown", "mouseup", "click"]
	).map(func(row): return row.event)
func publish_choices(manager, version: int, tab: int) -> void:
	manager.receive({"kind": "nui-frame", "windowId": 1001, "version": version, "rootId": 9101, "title": "Authored choices", "closable": true, "collapsible": false, "collapsed": false, "header": true, "transparent": false, "border": true, "acceptsInput": true, "resizable": false, "geometry": {"x": 30, "y": 40, "w": 450, "h": 180}})
	var nodes: Array = [
		{"controlId": 9101, "type": "col", "tag": "root", "index": -1, "children": [9102, 9103], "values": {"enabled": true, "visible": true}},
		{"controlId": 9102, "type": "tabbar", "tag": "tabs", "index": -1, "children": [], "values": {"enabled": true, "visible": true, "width": 340, "height": 50, "direction": 0, "options": ["First", "Second", "Third"], "selected": tab}},
		{"controlId": 9103, "type": "options", "tag": "options", "index": -1, "children": [], "values": {"enabled": true, "visible": true, "width": 340, "height": 50, "direction": 0, "options": ["One", "Two"], "selected": 1}}
	]
	manager.receive({"kind": "nui-nodes", "windowId": 1001, "version": version, "nodes": nodes})
	manager.receive({"kind": "nui-commit", "windowId": 1001, "version": version})
func exercise_choices(manager, sent: Array) -> void:
	root.notify_mouse_entered()
	publish_choices(manager, 1, 0)
	await process_frame
	await process_frame
	var tabbar = manager.windows[1001].nodes[9102]
	var options = manager.windows[1001].nodes[9103]
	check(selected_choices(tabbar) == [0] and selected_choices(options) == [1], "Server tabbar and ordinary options start with independent selections")
	var pointer_events := ["mousedown", "mouseup", "click"]
	var first := sent.size()
	await click_choice(tabbar.option_buttons[0])
	var reselect := selected_choices(tabbar)
	check(reselect == [0], "Reselecting an active NUI tab keeps it highlighted")
	check(choice_pointer_events(sent, first, 9102) == pointer_events, "Tab reselect emits one down, up and click")
	publish_choices(manager, 2, 0)
	await process_frame
	first = sent.size()
	await click_choice(tabbar.option_buttons[1])
	var switched := selected_choices(tabbar)
	check(switched == [1] and selected_choices(options) == [1], "Switching NUI tabs highlights only the new tab without affecting ordinary options")
	check(choice_pointer_events(sent, first, 9102) == pointer_events, "Tab switch emits one down, up and click")
	check(choice_changes(sent, 9102) == [0, 1], "Tab pointer callbacks retain their choice indices and private control ID")
	publish_choices(manager, 3, 2)
	await process_frame
	check(selected_choices(tabbar) == [2], "Server selection overrides the pointer-selected tab")
	publish_choices(manager, 4, -1)
	await process_frame
	check(selected_choices(tabbar).is_empty() and choice_changes(sent, 9102) == [0, 1], "Empty server selection clears the tabbar without emitting an input change")
	await click_choice(tabbar.option_buttons[2])
	check(selected_choices(tabbar) == [2] and choice_changes(sent, 9102) == [0, 1, 2], "A tab can be selected normally after the server clears the selection")
	await click_choice(options.option_buttons[1])
	check(selected_choices(options) == [1], "Reselecting ordinary options preserves their active choice")
	first = sent.size()
	await click_choice(options.option_buttons[0])
	check(selected_choices(options) == [0] and selected_choices(tabbar) == [2] and choice_changes(sent, 9103) == [1, 0], "Ordinary options keep independent single-selection and input routing")
	check(choice_pointer_events(sent, first, 9103) == pointer_events, "Option switch emits one down, up and click")
	first = sent.size()
	await click_choice(tabbar.option_buttons[2], MOUSE_BUTTON_RIGHT)
	var right_click := choice_pointer_events(sent, first, 9102)
	check(right_click == pointer_events and selected_choices(tabbar) == [2] and choice_changes(sent, 9102) == [0, 1, 2], "Right click preserves pointer events and does not change the selected tab")
	observations.tabbar = {"reselect": reselect, "switch": switched, "changes": choice_changes(sent, 9102), "right_click": right_click}
	manager.receive({"kind": "nui-remove", "windowId": 1001})
func run() -> void:
	var output := ""
	var fixture := "res://reports/nui-ui-fixture-v2.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		elif arg.begins_with("--fixture="): fixture = arg.substr(10)
	root.size = Vector2i(1440, 1000)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var overlay := CanvasLayer.new(); root.add_child(overlay)
	var manager := Manager.new(); root.add_child(manager); manager.setup(overlay)
	var sent: Array = []; manager.request.connect(func(row): sent.append(row))
	for row in data.messages: manager.receive(row)
	await process_frame
	check(manager.windows.size() == 1 and sent.any(func(row): return row.get("operation") == "open"), "Native commit opens exactly one window through a private handle")
	var window = manager.windows.values()[0]
	check(window.nodes.size() < 150 and window.nodes.values().any(func(node): return node.kind == "list" and int(node.values.row_count) == 1000000), "Native virtual list represents a million server rows with a bounded live control set")
	check(window.nodes.values().any(func(node): return node.kind == "label" and node.widget.text == "FF"), "Original number and case formatting reach native labels")
	check(window.nodes.values().any(func(node): return node.kind == "text" and node.widget.text == "Authored TLK text"), "Localized NUI text remains literal native text")
	var edit = window.nodes.values().filter(func(node): return node.spec.tag == "edit")[0]
	edit.widget.text = "Changed"; edit.widget.text_changed.emit("Changed")
	check(sent.back().operation == "change" and sent.back().controlId == edit.control_id and not sent.back().has("bind"), "Native text edit submits only its private handle and value")
	var button = window.nodes.values().filter(func(node): return node.spec.tag == "next")[0]
	button.widget.pressed.emit()
	check(sent.back().operation == "event" and sent.back().event == "click" and not sent.back().has("element"), "Native button callback cannot supply trusted server element or token IDs")
	var list = window.nodes.values().filter(func(node): return node.kind == "list")[0]
	list.scroll.scroll_vertical = 3000; list.request_range()
	check(sent.back().operation == "range" and int(sent.back().start) > 0, "Scrolling requests only the newly visible original row indices")
	check(manager.resources.values().any(func(value): return value is Texture2D), "Chunked authored image resource passes digest verification and native decoding")
	check(window.nodes.values().any(func(node): return node.foreground.commands.size() == 8), "All eight draw primitives reach the native canvas")
	edit.widget.grab_focus(); edit.widget.caret_column = 3
	observations.before = {"focus": edit.widget.has_focus(), "caret": edit.widget.caret_column, "text": edit.widget.text, "handle": edit.control_id}
	# Reapply a newer server revision through the same public frame protocol.
	var newer: Array = data.messages.filter(func(row): return row.kind in ["nui-frame", "nui-nodes", "nui-commit"]).duplicate(true)
	for row in newer:
		row.version += 1
		if row.kind == "nui-nodes":
			for node in row.nodes:
				if node.tag == "edit": node.values.value = "Earlier queued value"; node.values.inputAck = 0
		manager.receive(row)
	await process_frame
	observations.after = {"focus": edit.widget.has_focus(), "caret": edit.widget.caret_column, "text": edit.widget.text, "same": window.nodes[edit.control_id] == edit}
	check(window.nodes[edit.control_id] == edit and edit.widget.has_focus() and edit.widget.caret_column == 3 and edit.widget.text == "Changed", "An older queued projection cannot erase an unacknowledged draft or its caret")
	for row in newer:
		row.version += 1
		if row.kind == "nui-nodes":
			for node in row.nodes:
				if node.tag == "edit": node.values.value = "Server override"; node.values.inputAck = 1
		manager.receive(row)
	await process_frame
	check(edit.widget.text == "Server override" and edit.widget.caret_column == 3, "After input acknowledgement a real server text replacement is applied")
	edit.widget.release_focus()
	manager.receive({"kind": "nui-frame", "windowId": 1000, "version": 1, "rootId": 9001, "title": "", "closable": false, "collapsible": false, "collapsed": false, "header": false, "transparent": true, "border": false, "acceptsInput": true, "resizable": false, "geometry": {"x": 20, "y": 920, "w": 600, "h": 50}})
	manager.receive({"kind": "nui-nodes", "windowId": 1000, "version": 1, "nodes": [{"controlId": 9001, "type": "row", "tag": "", "index": -1, "children": [9002], "values": {"enabled": true, "visible": true}}, {"controlId": 9002, "type": "button_image", "tag": "toolbar", "index": -1, "children": [], "values": {"enabled": true, "visible": true, "width": 46, "height": 48, "image": -1}}]})
	manager.receive({"kind": "nui-commit", "windowId": 1000, "version": 1})
	await process_frame
	var toolbar = manager.windows[1000]; var slot = toolbar.nodes[9002]
	check(toolbar.header_height == 0 and toolbar.body.size.y == 50 and slot.widget.size.y == 48 and toolbar.get_global_rect().encloses(slot.widget.get_global_rect()), "A titleless 50-pixel toolbar displays the entire 48-pixel button without header clipping")
	toolbar.state.acceptsInput = false; manager.input_policy(toolbar, false)
	check(not manager.blocks_pointer(slot.get_global_rect().get_center()) and slot.widget.mouse_filter == Control.MOUSE_FILTER_IGNORE, "A passive server window and its descendants pass world clicks through")
	manager.receive({"kind": "nui-remove", "windowId": 1000})
	manager.receive({"kind": "nui-remove", "windowId": window.window_id}); await process_frame
	check(manager.windows.is_empty(), "Server window removal retires native controls")
	await exercise_choices(manager, sent)
	manager.reset(); await process_frame; await process_frame
	check(int(manager.retired_state().windows) == 0 and int(manager.retired_state().resources) == 0, "Reset releases old native windows and decoded image resources")
	manager.free(); overlay.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "observations": observations}, "\t")); file.close(); quit(0 if failures.is_empty() else 1)
