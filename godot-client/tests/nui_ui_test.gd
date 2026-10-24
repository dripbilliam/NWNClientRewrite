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
	manager.reset(); await process_frame; await process_frame
	check(int(manager.retired_state().windows) == 0 and int(manager.retired_state().resources) == 0, "Reset releases old native windows and decoded image resources")
	manager.free(); overlay.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "observations": observations}, "\t")); file.close(); quit(0 if failures.is_empty() else 1)
