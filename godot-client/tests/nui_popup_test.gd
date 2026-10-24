extends SceneTree
# Authored native frames only. Exercises actual embedded popup GUI dispatch.
const Manager = preload("res://systems/server_nui.gd")
var checks := 0
var failures: Array = []
var observations: Dictionary = {}
var sent: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func mouse_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = point; e.global_position = point
		root.push_input(e, true); await process_frame
func key_to(_view: Viewport, code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.unicode = unicode; e.pressed = pressed
		# Let the root viewport route into its focused embedded subwindow.
		root.push_input(e, true)
		await process_frame
func edits_in(node: Node) -> Array:
	var found: Array = [node] if node is LineEdit else []
	for child in node.get_children(true): found.append_array(edits_in(child))
	return found
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1000, 800)
	check(root.gui_embed_subwindows, "Production project embeds gameplay popups without a test-only override")
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer); manager.request.connect(func(row): sent.append(row))
	manager.receive({"kind":"nui-frame","windowId":1,"version":1,"rootId":1,"title":"Authored popup menu","closable":true,"collapsible":false,"collapsed":false,"header":true,"transparent":false,"border":true,"acceptsInput":true,"resizable":true,"geometry":{"x":30,"y":40,"w":400,"h":100}})
	var rows := [{"controlId":1,"type":"row","tag":"root","index":-1,"children":[2,3],"values":{"enabled":true,"visible":true}}, {"controlId":2,"type":"combo","tag":"combo","index":-1,"children":[],"values":{"enabled":true,"visible":true,"width":180,"height":40,"options":["First","Second","Third","Fourth","Fifth","Sixth"],"selected":0}}, {"controlId":3,"type":"color_picker","tag":"color","index":-1,"children":[],"values":{"enabled":true,"visible":true,"width":180,"height":40,"value":{"r":30,"g":120,"b":230,"a":255}}}]
	manager.receive({"kind":"nui-nodes","windowId":1,"version":1,"nodes":rows}); manager.receive({"kind":"nui-commit","windowId":1,"version":1}); await process_frame; await process_frame
	var window = manager.windows[1]; var combo = window.nodes[2]; var color = window.nodes[3]; var popup: PopupMenu = combo.widget.get_popup()
	await mouse_at(combo.widget.get_global_rect().get_center()); await process_frame
	check(popup.visible, "A real native GUI click opens the combo popup")
	var outside := Vector2(popup.position) + Vector2(popup.size.x / 2.0, popup.size.y - 4)
	observations.combo = {"popup": str(Rect2(popup.position, popup.size)), "parent": str(window.get_global_rect()), "test_point": str(outside), "focused": popup.get_focused_item()}
	check(not window.get_global_rect().has_point(outside), "Authored dropdown extends beyond its parent window")
	check(manager.blocks_pointer(outside), "An open dropdown blocks world picking beyond its parent rectangle")
	var down := InputEventKey.new(); down.keycode = KEY_DOWN; down.physical_keycode = KEY_DOWN; down.pressed = true
	observations.input = {"down_action": down.is_action_pressed("ui_down"), "has_action": InputMap.has_action("ui_down"), "events": str(InputMap.action_get_events("ui_down"))}
	await key_to(popup, KEY_DOWN); observations.first_down = popup.get_focused_item(); await key_to(popup, KEY_DOWN); observations.second_down = popup.get_focused_item(); await key_to(popup, KEY_ENTER)
	check(sent.any(func(row): return row.get("operation") == "change" and int(row.get("controlId", -1)) == 2 and int(row.get("value", -1)) == 1), "Native popup Down and Enter select exactly the second private choice")
	check(not popup.visible, "Choosing an entry dismisses the native combo popup")
	check(not manager.blocks_pointer(outside), "World picking resumes outside the menu after the popup closes")
	await mouse_at(color.widget.get_global_rect().get_center()); await process_frame
	var picker: PopupPanel = color.widget.get_popup()
	check(picker.visible, "A real native GUI click opens the color picker")
	var color_outside := Vector2(picker.position) + Vector2(picker.size) - Vector2(5, 5)
	check(not window.get_global_rect().has_point(color_outside) and manager.blocks_pointer(color_outside), "Color popup blocks world picking throughout its extended rectangle")
	observations.color_entries = edits_in(color.widget.get_picker()).map(func(edit): return {"text": edit.text, "placeholder": edit.placeholder_text, "tooltip": edit.tooltip_text, "visible": edit.is_visible_in_tree()})
	var hex = edits_in(color.widget.get_picker()).filter(func(edit): return edit.is_visible_in_tree() and edit.text == "1e78e6")[0]
	hex.grab_focus(); hex.select_all()
	for letter in "ff4020": await key_to(picker, letter.to_upper().unicode_at(0), letter.unicode_at(0))
	await key_to(picker, KEY_ENTER)
	check(color.widget.color.to_html() == "ff4020ff" and sent.any(func(row): return row.get("operation") == "change" and int(row.get("controlId", -1)) == 3 and row.get("value") == {"r":255,"g":64,"b":32,"a":255}), "Typing a native color hex code submits the exact canonical RGBA value")
	await mouse_at(color.widget.get_global_rect().get_center()); await process_frame
	check(picker.visible, "A color popup can reopen after a typed submission")
	await key_to(picker, KEY_ESCAPE)
	check(not picker.visible, "Escape dismisses the color popup")
	# A server disabling or replacing a control must revoke its open popup too.
	await mouse_at(combo.widget.get_global_rect().get_center()); await process_frame
	rows[1].values.enabled = false
	manager.receive({"kind":"nui-frame","windowId":1,"version":2,"rootId":1,"title":"Authored popup menu","closable":true,"collapsible":false,"collapsed":false,"header":true,"transparent":false,"border":true,"acceptsInput":true,"resizable":true,"geometry":{"x":30,"y":40,"w":400,"h":100}})
	manager.receive({"kind":"nui-nodes","windowId":1,"version":2,"nodes":rows}); manager.receive({"kind":"nui-commit","windowId":1,"version":2}); await process_frame
	check(not popup.visible, "A server disabling a visible combo dismisses its active popup")
	rows[1].values.enabled = true; combo.apply(rows[1]); await mouse_at(combo.widget.get_global_rect().get_center()); await process_frame
	check(popup.visible, "A reenabled server control can reopen its popup")
	window.state.acceptsInput = false; combo.apply(rows[1])
	check(not popup.visible, "A passive server window dismisses an already open child popup")
	window.state.acceptsInput = true; combo.apply(rows[1]); await mouse_at(combo.widget.get_global_rect().get_center()); await process_frame
	combo.retire()
	check(not popup.visible and not combo.popup_blocks_pointer(outside), "Retirement releases popup picking immediately before deferred deletion")
	manager.reset(); await process_frame; await process_frame
	check(manager.windows.is_empty() and int(manager.retired_state().windows) == 0, "Popup owners retire completely on connection reset")
	manager.free(); layer.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
