extends RefCounted
# Owned local-server acceptance only. Never fabricates incoming NUI messages.
var running := true
var client
var connection := -1
var checks: Array = []
var observations: Dictionary = {}
var spell_ready: Dictionary = {}
var spell_observation: Dictionary = {}
var skin_ok := true
var skin_checks := 0
var popup_ok := true
var popup_checks := 0
func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.connection == connection
func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})
	print("NATIVE_NUI_CHECK ", value, " ", name)
func check_skin(value: bool, name: String) -> void:
	skin_checks += 1; skin_ok = skin_ok and value; check(value, name)
func check_popup(value: bool, name: String) -> void:
	popup_checks += 1; popup_ok = popup_ok and value; check(value, name)
func key(code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.unicode = unicode; event.pressed = pressed
		client.get_viewport().push_input(event, true); await client.get_tree().process_frame
func edits_in(node: Node) -> Array:
	var found: Array = [node] if node is LineEdit else []
	for child in node.get_children(true): found.append_array(edits_in(child))
	return found
func popups(root) -> void:
	var combo = element(root, "combo"); var popup: PopupMenu = combo.popup
	await click(combo); await client.get_tree().process_frame
	check_popup(popup.visible and popup.is_embedded(), "Actual NUI combo opens an embedded native popup through GUI hit routing")
	check_popup(combo.popup_blocks_pointer(Vector2(popup.position) + Vector2(popup.size) / 2), "Actual combo popup is included in native world-pointer blocking")
	# A mouse-opened menu has no highlighted item until keyboard navigation.
	await key(KEY_DOWN); await key(KEY_DOWN); await key(KEY_ENTER)
	check_popup(await wait_until(func(): return int(element(root, "combo").values.get("selected", -1)) == 1) and not popup.visible, "Native popup keyboard selection round trips the canonical server choice and closes")
	var color = element(root, "color"); await click(color); await client.get_tree().process_frame
	var picker: PopupPanel = color.popup
	check_popup(picker.visible and picker.is_embedded(), "Actual NUI color button opens an embedded native picker through GUI hit routing")
	check_popup(color.popup_blocks_pointer(Vector2(picker.position) + Vector2(picker.size) - Vector2(5, 5)), "Actual color popup blocks world picking throughout its rectangle")
	var entries := edits_in(color.widget.get_picker()).filter(func(edit): return edit.is_visible_in_tree() and edit.text.to_lower() == color.widget.color.to_html(false))
	check_popup(entries.size() == 1, "Native color popup exposes its original editable hex field")
	if entries.size() == 1:
		entries[0].grab_focus(); entries[0].select_all()
		for letter in "1e78e6": await key(letter.to_upper().unicode_at(0), letter.unicode_at(0))
		await key(KEY_ENTER)
	check_popup(await wait_until(func():
		var value: Dictionary = element(root, "color").values.get("value", {})
		return int(value.get("r", -1)) == 30 and int(value.get("g", -1)) == 120 and int(value.get("b", -1)) == 230 and int(value.get("a", -1)) == 255), "Typed native popup hex entry round trips exact RGBA through a real watched server binding")
	observations.popup_color = element(root, "color").values.get("value", {}).duplicate()
	if not picker.visible: await click(color); await client.get_tree().process_frame
	await key(KEY_ESCAPE)
	check_popup(not picker.visible, "Native popup Escape dismisses the picker without starting a world action")
func wait_until(predicate: Callable, seconds: float = 12) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func window_named(title: String):
	for window in client.nui.windows.values():
		if window.state.get("title") == title: return window
	return null
func element(window, tag: String, index: int = -1):
	if not is_instance_valid(window): return null
	for node in window.nodes.values():
		if node.spec.get("tag") == tag and int(node.spec.get("index", -1)) == index: return node
	return null
func label(window, tag: String) -> String:
	var node = element(window, tag)
	return str(node.widget.text) if node != null and node.widget != null else ""
func click(node) -> void:
	# Use native GUI hit routing, including clipping and child mouse filters.
	if node == null: return
	var at: Vector2 = node.widget.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = at; event.global_position = at
		client.get_viewport().push_input(event, true)
		await client.get_tree().process_frame
func run(owner, message: Dictionary) -> void:
	client = owner; connection = client.connection
	client.command({"kind": "chat", "channel": 1, "text": "-native-nui"})
	check(await wait_until(func(): return window_named("Local native NUI") != null, 20), "Actual server creates native NUI root")
	var root = window_named("Local native NUI")
	if root == null: finish(message); return
	observations.root_window_id = root.window_id
	if message.has("retiredConnection"):
		observations.retired = client.nui.retired_state()
		check(int(observations.retired.windows) == 0 and int(observations.retired.resources) == 0, "Previous connection NUI windows, original fonts and images are released")
		client.send({"kind": "nui-input", "connection": int(message.retiredConnection), "windowId": int(message.retiredWindowId), "operation": "close"})
		await client.get_tree().create_timer(0.25).timeout
		check(client.nui.windows.get(root.window_id) == root, "A stale old-connection close cannot destroy a reused new native window handle")
	check(await wait_until(func(): return label(root, "caption") == "Native open event accepted"), "Native open callback reaches the actual server")
	check(await wait_until(func(): return client.nui.resources.values().filter(func(v): return v is FontFile).size() >= 2, 20), "Original default and monospace fonts load through chunked native resources")
	check(await wait_until(func(): return client.nui.resources.values().filter(func(v): return v is Texture2D).size() >= 2, 20), "Original skin and spell icon textures load without substitute artwork")
	if message.get("skin", false):
		check(await wait_until(func(): return client.nui.skin_ready() and element(root, "progress").widget.get_theme_stylebox("fill") is StyleBoxTexture, 20), "Installed NUI skin resource set finishes before native style checks")
		var theme = client.nui.theming
		check_skin(element(root, "check").widget.get_theme_icon("unchecked").get_size() == Vector2(23, 22), "Native checkbox uses the original 23 by 22 background artwork")
		check_skin(element(root, "options").option_buttons[0] is CheckBox and element(root, "options").option_buttons[0].get_theme_icon("radio_unchecked").get_size() == Vector2(27, 27), "Native options use original radio artwork rather than rectangular toggle buttons")
		check_skin(element(root, "slider").widget.get_theme_icon("grabber") == theme.texture("slider", "cursor_normal"), "Live slider uses the installed original cursor texture")
		check_skin(element(root, "progress").widget.get_theme_stylebox("fill").texture == theme.texture("progress", "cursor_normal"), "Live progress fill uses the installed original texture")
		check_skin(element(root, "combo").widget.get_theme_icon("arrow") == theme.texture("combo.button", "normal"), "Live combo uses the installed original dropdown arrow")
		var bar = element(root, "rows").scroll.get_v_scroll_bar()
		check_skin(bar.get_theme_icon("increment") == theme.texture("scrollv.inc_button", "normal") and bar.custom_minimum_size.x == 18, "Live scrollbar uses original arrows and the skin's 18-pixel width")
		check_skin(root.close.icon == theme.texture("window.header.close_button", "normal") and root.close.text.is_empty(), "Live window close uses the installed icon instead of a text glyph")
		check_skin(element(root, "edit").widget.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) == 10, "Live editor uses original skin content padding")
	var kinds: Dictionary = {}
	for node in root.nodes.values(): kinds[node.kind] = true
	check(kinds.size() == 21, "All 21 control kinds are present in the real server menu")
	check(await wait_until(func(): return element(root, "edit").values.get("value") == "Native draft" and int(element(root, "rows").values.get("row_count", 0)) == 2000), "Initial server binding stream arrives before editing")
	observations.initial = {"edit": element(root, "edit").values, "rows": element(root, "rows").values, "caption": label(root, "caption"), "echo": label(root, "echo")}
	if int(element(root, "rows").values.get("row_count", 0)) != 2000: finish(message); return
	var edit = element(root, "edit"); var handle: int = edit.control_id
	edit.widget.grab_focus(); edit.widget.text = "Native watched edit"; edit.widget.caret_column = edit.widget.text.length(); edit.widget.text_changed.emit(edit.widget.text)
	check(await wait_until(func(): return label(root, "echo") == "Native watched edit"), "Text edit round trips through a real watched server bind")
	observations.edit_after_echo = {"handle": element(root, "edit").control_id, "same_handle": handle, "focus": edit.widget.has_focus(), "caret": edit.widget.caret_column, "text": edit.widget.text}
	check(element(root, "edit").control_id == handle and edit.widget.has_focus() and edit.widget.caret_column == edit.widget.text.length(), "Binding updates retain native focus, caret, and control identity")
	check((client.get_viewport().gui_get_focus_owner() is LineEdit or client.get_viewport().gui_get_focus_owner() is TextEdit), "Native text focus suppresses WASD input")
	edit.widget.release_focus()
	check(not (client.get_viewport().gui_get_focus_owner() is LineEdit or client.get_viewport().gui_get_focus_owner() is TextEdit), "WASD is released after native text focus ends")
	for tag in ["selected", "check"]:
		await click(element(root, tag))
	check(await wait_until(func(): return element(root, "selected").values.get("value") == true and element(root, "check").values.get("value") == true), "Real GUI clicks toggle both selectable and check controls")
	if message.get("skin", false):
		check_skin(element(root, "selected").widget.get_theme_stylebox("normal").texture == client.nui.theming.texture("selectable", "normal_active"), "Selected native button switches to the installed active artwork")
	var combo = element(root, "combo")
	if message.get("popup", false): await popups(root)
	else: combo.widget.select(1); combo.widget.item_selected.emit(1)
	element(root, "slider").widget.value = 7; element(root, "sliderf").widget.value = 0.75
	element(root, "options").option_buttons[1].pressed.emit(); element(root, "tabs").option_buttons[1].pressed.emit()
	if not message.get("popup", false): element(root, "color").widget.color_changed.emit(Color8(30, 120, 230, 255))
	var multiline = element(root, "multiline"); multiline.widget.text = "Native multiline\nSecond line"; multiline.widget.text_changed.emit()
	check(await wait_until(func(): return int(element(root, "combo").values.get("selected", -1)) == 1 and element(root, "slider").values.get("value") == 7 and absf(float(element(root, "sliderf").values.get("value", 0)) - 0.75) < 0.001), "Native numeric and canonical choice bindings update")
	check(await wait_until(func(): return int(element(root, "options").values.get("selected", -1)) == 1 and int(element(root, "tabs").values.get("selected", -1)) == 1 and element(root, "color").values.get("value", {}).get("b") == 230 and element(root, "multiline").values.get("value") == "Native multiline\nSecond line"), "Native options, tabs, RGBA color, and multiline bindings update")
	var rows = element(root, "rows"); rows.scroll.scroll_vertical = 60000; rows.request_range()
	check(await wait_until(func(): return element(root, "row_check", 1999) != null), "Virtual scrolling materializes the last original server row")
	var last = element(root, "row_check", 1999)
	if last != null: last.widget.button_pressed = true; last.widget.pressed.emit()
	check(await wait_until(func(): return element(root, "row_check", 1999) != null and element(root, "row_check", 1999).values.get("value") == true), "Indexed native checkbox preserves server array index 1999")
	client.command({"kind": "chat", "channel": 1, "text": "-native-nui-query"})
	await client.get_tree().create_timer(0.4).timeout
	var row = element(root, "row", 1999)
	if row != null: row.widget.pressed.emit()
	check(await wait_until(func(): return element(root, "replaced") != null and element(root, "original") == null), "Actual server group replacement retires old native children")
	check(root.nodes.size() < 150, "Two thousand rows retain a bounded native control count")
	await click(element(root, "next"))
	check(await wait_until(func(): return window_named("Native child menu") != null and window_named("") != null), "Actual native GUI click creates independent child and toolbar windows")
	var child = window_named("Native child menu"); var toolbar = window_named("")
	if child != null:
		await click(element(child, "third"))
	check(await wait_until(func(): return window_named("Resource-backed grandchild") != null), "Real server JUI resource creates a third native window")
	if toolbar != null:
		var slot = element(toolbar, "toolbar_0")
		check(toolbar.header_height == 0 and slot != null and slot.size.y == 48 and toolbar.body.get_global_rect().encloses(slot.get_global_rect()), "Titleless 50-pixel toolbar retains the complete 48-pixel button height")
		check(await wait_until(func(): return client.nui.resources.get(int(slot.values.get("image", -1))) is Texture2D), "Toolbar original cropped spell icon is decoded")
		var texture: Texture2D = client.nui.resources.get(int(slot.values.get("image", -1)))
		check(texture != null and texture.get_width() == 32 and texture.get_height() == 32, "Toolbar uses the exact original 32 by 32 image crop")
		var old: int = toolbar.window_id
		await click(element(root, "image_button"))
		check(await wait_until(func(): return window_named("") != null and window_named("").window_id != old), "Server token reuse retires the previous private native window")
	if child != null:
		await click(element(child, "target"))
		check(await wait_until(func(): return client.targeting.active), "NUI server callback enables native script targeting")
		if message.get("actions", false):
			client.targeting.choose({"id": client.controlled_id, "position": client.pivots[client.controlled_id].global_position})
			check(await wait_until(func(): return label(root, "target_ack") == "Native target selection accepted"), "Native target selection reaches the real server callback as the selected player")
			client.command({"kind": "interface-spell-watch"})
			check(await wait_until(func(): return not spell_ready.is_empty()) and int(spell_ready.get("before", 0)) > 0, "Server-replicated prepared Light uses exist before the NUI cast")
			await click(element(window_named(""), "toolbar_0"))
			check(await wait_until(func(): return client.targeting.active), "Native toolbar GUI click enters the server-requested cast target mode")
			client.targeting.choose({"id": client.controlled_id, "position": client.pivots[client.controlled_id].global_position})
			check(await wait_until(func(): return label(root, "target_ack") == "Native cast target accepted"), "NUI spell target reaches the actual server callback")
			check(await wait_until(func(): return not spell_observation.is_empty(), 20), "The NUI server action consumes an actual prepared Light use")
		else:
			client.targeting.cancel()
	var controller = client.owner_scene.camera_controller; var yaw: float = controller.yaw
	var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; controller._input(middle)
	var motion := InputEventMouseMotion.new(); motion.relative = Vector2(3, 0); controller._input(motion); middle.pressed = false; controller._input(middle)
	check(controller.yaw != yaw and not controller.dragging, "Middle mouse camera rotation works with simultaneous NUI menus")
	controller.orbit(Vector2(-3, 0))
	var grandchild = window_named("Resource-backed grandchild")
	if grandchild != null: grandchild.close.pressed.emit()
	check(await wait_until(func(): return window_named("Resource-backed grandchild") == null), "Native close delivers a real server close event and retires the window")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Live native NUI controls and complete toolbar captured for visual review")
	var root_id: int = root.window_id; var resources_before: int = client.nui.resources.size()
	# Move through the native title drag path to expose the world below.
	var anchor: Vector2 = root.title.get_global_rect().get_center()
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = root.title.size / 2
	root.begin_drag(down, false, root.title)
	var drag := InputEventMouseMotion.new(); drag.global_position = anchor + Vector2(960, 0); root._input(drag)
	down.pressed = false; root._input(down)
	check(await wait_until(func(): return root.position.x >= 999), "Native title drag moves and raises a server menu without blocking the world")
	var begin: Vector3 = client.pivots[client.controlled_id].global_position
	var keyboard = client.keyboard; var require_focus: bool = keyboard.require_focus; keyboard.require_focus = false
	keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.7).timeout; keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = require_focus
	check(await wait_until(func(): return client.pivots[client.controlled_id].global_position.distance_to(begin) > 0.1, 8), "Actual WASD remains live with simultaneous server NUI windows")
	var world_input = client.owner_scene.world_input; var camera: Camera3D = client.owner_scene.camera; var clicked := false
	begin = client.pivots[client.controlled_id].global_position
	for offset in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
		var screen := camera.unproject_position(begin + offset)
		if world_input.extra_pointer_block.call(screen) or client.owner_scene.native_hud.blocks_pointer(screen): continue
		var hit: Dictionary = client.owner_scene.registry.pick(camera, screen)
		if hit.is_empty() or hit.get("entity", {}).get("eligible", false): continue
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = screen
		world_input._unhandled_input(event); world_input._physics_process(0.1); clicked = true; break
	check(clicked and await wait_until(func(): return client.pivots[client.controlled_id].global_position.distance_to(begin) > 0.1, 8), "A ray click outside NUI menus still produces real server movement")
	var original_area: int = client.area_id; var generation_before: int = client.generation
	client.command({"kind": "chat", "channel": 1, "text": "-native-b"})
	check(await wait_until(func(): return client.area_id != original_area and client.generation > generation_before and client.smoke_frame_complete, 45), "Actual server transition admits and animates a second world with NUI open")
	check(client.nui.windows.get(root_id) == root and root.nodes.has(handle) and label(root, "echo") == "Native watched edit", "Connection-owned NUI identity and binding state survive the area transition")
	if not valid() or client.area_id == original_area: finish(message); return
	generation_before = client.generation
	client.command({"kind": "chat", "channel": 1, "text": "-native-a"})
	check(await wait_until(func(): return client.area_id == original_area and client.generation > generation_before and client.smoke_frame_complete, 45), "Actual return transition completes the native A–B–A lifecycle")
	check(client.nui.windows.get(root_id) == root and root.nodes.has(handle) and client.nui.resources.size() == resources_before, "NUI controls and original fonts/textures remain stable across repeated world replacement")
	# Wait for the final server echo packets before the host compares all typed values.
	await client.get_tree().create_timer(0.5).timeout
	finish(message)
func finish(message: Dictionary) -> void:
	if valid(): client.command({"kind": "interface-tested", "result": {"completed": true, "checks": checks, "skin": {"checks": skin_checks, "passed": skin_ok}, "popup": {"checks": popup_checks, "passed": popup_ok}, "statistics": client.nui.statistics, "observations": observations, "serverChat": client.chat.get_parsed_text(), "windows": client.nui.windows.size(), "screenshot": message.screenshot}})
