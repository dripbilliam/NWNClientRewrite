extends SceneTree
const Manager = preload("res://systems/server_nui.gd")
var failures: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func image(size: Vector2i, tint: Color) -> Texture2D:
	var pixels := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8); pixels.fill(tint)
	return ImageTexture.create_from_image(pixels)
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
	var controls := Control.new(); layer.add_child(controls)
	manager.resources = {1: image(Vector2i(23, 22), Color.RED), 2: image(Vector2i(23, 22), Color.GREEN), 3: image(Vector2i(15, 14), Color.BLUE), 4: image(Vector2i(27, 27), Color.RED), 5: image(Vector2i(16, 16), Color.BLUE), 6: image(Vector2i(14, 14), Color.GREEN), 7: image(Vector2i(12, 16), Color.BLUE), 8: image(Vector2i(8, 18), Color.GREEN)}
	manager.images = {"auth_n": 1, "auth_h": 2, "auth_x": 3, "auth_radio": 4, "auth_radio_x": 5, "auth_arrow": 6, "auth_slider": 7, "auth_progress": 8}
	manager.skin = {"text": {"color": "#FFFFFFFF"}, "button": {"normal": "auth_n", "hover": "auth_h", "active": "auth_h"}, "selectable": {"normal": "auth_n", "normal_active": "auth_h", "hover_active": "auth_h", "pressed_active": "auth_n"}, "checkbox": {"normal": "auth_n", "hover": "auth_h", "cursor_normal": "auth_x", "cursor_hover": "auth_x"}, "option": {"normal": "auth_radio", "hover": "auth_radio", "cursor_normal": "auth_radio_x", "cursor_hover": "auth_radio_x"}, "combo": {"normal": "auth_n", "content_padding_x": 10}, "combo.button": {"normal": "auth_arrow"}, "edit": {"normal": "auth_n", "active": "auth_h", "padding_x": 10}, "slider": {"cursor_normal": "auth_slider", "bar_filled": "#AD8E60FF"}, "progress": {"normal": "auth_n", "cursor_normal": "auth_progress"}, "window": {"fixed_background": "#000000FF", "scrollbar_size_x": 18, "scrollbar_size_y": 18}, "window.header.close_button": {"normal": "auth_arrow", "padding_x": 5, "padding_y": 5}, "scrollv": {"normal": "auth_n", "cursor_normal": "auth_radio_x"}, "scrollv.inc_button": {"normal": "auth_arrow"}, "scrollv.dec_button": {"normal": "auth_arrow"}, "scrollh": {"normal": "auth_n", "cursor_normal": "auth_radio_x"}}
	check(manager.skin_ready(), "Skin readiness follows referenced assets rather than unrelated window image counts")
	manager.images["auth_late"] = 9
	check(not manager.skin_ready(), "A pending referenced skin image prevents readiness")
	manager.resources[9] = image(Vector2i(1, 1), Color.WHITE); manager.resources_dirty = true
	check(not manager.skin_ready(), "Decoded skin images wait for native restyling before readiness")
	await process_frame; await process_frame
	check(manager.skin_ready(), "Readiness resumes after the last referenced image is styled")
	var button := Button.new(); controls.add_child(button); manager.style(button, "button", "(default)", null)
	check(button.get_theme_stylebox("normal") is StyleBoxTexture and button.get_theme_stylebox("normal").texture == manager.resources[1], "Button uses its supplied normal artwork")
	check(button.get_theme_stylebox("hover").texture == manager.resources[2], "Button hover and active artwork are independent native states")
	button.toggle_mode = true; button.button_pressed = true; manager.style(button, "button_select", "(default)", null)
	check(button.get_theme_stylebox("normal").texture == manager.resources[2], "A selected tab/button uses normal_active rather than its unselected artwork")
	var checkbox := CheckBox.new(); controls.add_child(checkbox); checkbox.button_pressed = true; manager.style(checkbox, "check", "(default)", null)
	check(checkbox.get_theme_icon("checked").get_size() == Vector2(23, 22), "Checkbox composition preserves original background dimensions")
	var checked: Image = checkbox.get_theme_icon("checked").get_image()
	check(checked.get_pixel(0, 0) == Color.RED and checked.get_pixel(11, 11) == Color.BLUE, "Original mark is composited at the center without replacing background pixels")
	var radio := CheckBox.new(); radio.button_group = ButtonGroup.new(); controls.add_child(radio); radio.button_pressed = true; manager.style(radio, "option", "(default)", null)
	check(radio.get_theme_icon("radio_checked").get_size() == Vector2(27, 27), "Radio options use their own original art and dimensions")
	var slider := HSlider.new(); controls.add_child(slider); manager.style(slider, "slider", "(default)", null)
	check(slider.get_theme_icon("grabber") == manager.resources[7] and slider.get_theme_stylebox("grabber_area").bg_color == Color.html("#AD8E60FF"), "Slider uses supplied cursor texture and bar color")
	var progress := ProgressBar.new(); controls.add_child(progress); manager.style(progress, "progress", "(default)", null)
	check(progress.get_theme_stylebox("fill").texture == manager.resources[8], "Progress fill uses supplied image")
	var combo := OptionButton.new(); combo.add_item("Authored choice"); controls.add_child(combo); manager.style(combo, "combo", "(default)", null)
	check(combo.get_theme_icon("arrow") == manager.resources[6] and combo.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) == 10, "Combo arrow and content padding use the skin")
	check(combo.get_popup().get_theme_stylebox("panel").bg_color == Color.BLACK, "Dropdown popup uses the supplied window background")
	var edit := LineEdit.new(); controls.add_child(edit); manager.style(edit, "textedit", "(default)", null)
	check(edit.get_theme_stylebox("normal").texture == manager.resources[1] and edit.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) == 10, "Editor preserves original background and padding")
	var scrollbar := VScrollBar.new(); controls.add_child(scrollbar); manager.theming.scrollbar(scrollbar, true)
	check(scrollbar.get_theme_icon("increment") == manager.resources[6] and scrollbar.custom_minimum_size.x == 18 and scrollbar.get_theme_stylebox("grabber").get_minimum_size().y == 16, "Scrollbar original arrows and thumb keep usable native dimensions")
	var close := Button.new(); controls.add_child(close); manager.style(close, "window_close", "(default)", null)
	check(close.icon == manager.resources[6] and close.text.is_empty() and close.get_theme_stylebox("normal").get_minimum_size() == Vector2(10, 10), "Window close uses original icon with skin padding instead of a text glyph")
	var cache_size: int = manager.theming.derived.size(); var box_size: int = manager.theming.boxes.size()
	manager.style(checkbox, "check", "(default)", null); manager.style(button, "button_select", "(default)", null)
	check(manager.theming.derived.size() == cache_size and manager.theming.boxes.size() == box_size, "Unchanged binding refreshes reuse themed resources")
	checked = null; controls.free(); manager.reset(); await process_frame; await process_frame
	check(int(manager.retired_state().resources) == 0, "Decoded and composed theme images retire after their widgets close")
	manager.free(); layer.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}, "\t")); file.close(); quit(0 if failures.is_empty() else 1)
