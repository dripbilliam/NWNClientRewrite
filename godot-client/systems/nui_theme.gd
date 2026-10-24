extends RefCounted
# Original installed NUI skin -> native widget theme items. Resource payloads
# remain owned by the connection manager; composed check/radio icons are cached.
var owner
var revision := 0
var derived: Dictionary = {}
var boxes: Dictionary = {}
func invalidate() -> void:
	revision += 1; derived.clear(); boxes.clear()
func number(table: String, key: String, fallback: float) -> float: return float(owner.skin.get(table, {}).get(key, fallback))
func texture(table: String, key: String):
	return owner.resources.get(int(owner.images.get(str(owner.skin.get(table, {}).get(key, "")), -1)))
func padded(table: String, key: String, fallback: Color, x: float = 0, y: float = 0) -> StyleBox:
	var id := table + "/" + key + "/" + str(x) + "/" + str(y) + "/" + fallback.to_html()
	if not boxes.has(id):
		var box: StyleBox = owner.box(table, key, fallback).duplicate()
		box.set_content_margin(SIDE_LEFT, x); box.set_content_margin(SIDE_RIGHT, x); box.set_content_margin(SIDE_TOP, y); box.set_content_margin(SIDE_BOTTOM, y); boxes[id] = box
	return boxes[id]
func marked_icon(table: String, hovered: bool, checked: bool):
	var state := "hover" if hovered else "normal"; var base = texture(table, state); var mark = texture(table, "cursor_hover" if hovered else "cursor_normal")
	if not base is Texture2D: return null
	if not checked or not mark is Texture2D: return base
	var key := table + "/" + state + "/checked"
	if not derived.has(key):
		var image: Image = base.get_image().duplicate(); var top: Image = mark.get_image()
		image.convert(Image.FORMAT_RGBA8); top = top.duplicate(); top.convert(Image.FORMAT_RGBA8)
		image.blend_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), (image.get_size() - top.get_size()) / 2)
		derived[key] = ImageTexture.create_from_image(image)
	return derived[key]
func color(control: Control, key: String, value: Color) -> void: control.add_theme_color_override(key, value)
func icon(control: Control, key: String, value) -> void:
	if value is Texture2D: control.add_theme_icon_override(key, value)
func style(control: Control, kind: String, font_name: String, foreground: Variant) -> void:
	var hovered: bool = control.is_hovered() and not control.disabled if control is BaseButton else false
	var selected: bool = control.button_pressed if control is BaseButton else false
	var draw_mode: int = control.get_draw_mode() if control is BaseButton else 0
	var key := JSON.stringify([revision, kind, font_name, foreground, hovered, selected, draw_mode])
	if control.get_meta("nui_style", "") == key: return
	control.set_meta("nui_style", key)
	# Each individual override otherwise notifies the widget and may reshape
	# its entire text. Publish one complete, widget-specific theme update.
	control.begin_bulk_theme_override()
	var font: Font = owner.font_for(font_name); var size: int = owner.font_size(font_name)
	for name in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"] if control is RichTextLabel else ["font"]: control.add_theme_font_override(name, font)
	for name in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"] if control is RichTextLabel else ["font_size"]: control.add_theme_font_size_override(name, size)
	var tint: Color = owner.skin_color("window.header", "label_normal", Color.WHITE) if kind == "window_title" else owner.skin_color("text", "color", Color.WHITE)
	if foreground is Dictionary: tint = Color(float(foreground.get("r", 255)) / 255, float(foreground.get("g", 255)) / 255, float(foreground.get("b", 255)) / 255, float(foreground.get("a", 255)) / 255)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "default_color"]: color(control, name, tint)
	for name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]: color(control, name, Color.WHITE)
	if control is CheckBox:
		var table := "option" if kind == "option" else "checkbox"
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]: control.add_theme_stylebox_override(state, padded("", "", Color.TRANSPARENT))
		for prefix in ["", "radio_"]:
			for disabled in ["", "_disabled"]:
				icon(control, prefix + "unchecked" + disabled, marked_icon(table, hovered, false)); icon(control, prefix + "checked" + disabled, marked_icon(table, hovered, true))
		control.add_theme_constant_override("h_separation", 6)
	elif kind in ["window_close", "window_minimize"]:
		var table := "window.header.close_button" if kind == "window_close" else "window.header.minimize_button"
		var image = texture(table, "active" if draw_mode in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else ("hover" if hovered else "normal"))
		control.icon = image if image is Texture2D else null; control.text = "" if image is Texture2D else ("×" if kind == "window_close" else "−")
		for state in ["normal", "hover", "pressed", "disabled", "focus"]: control.add_theme_stylebox_override(state, padded("", "", Color.TRANSPARENT, number(table, "padding_x", 5), number(table, "padding_y", 5)))
	elif control is Button:
		var table := "selectable" if kind == "button_select" else ("combo" if kind == "combo" else "button")
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var source: String = "normal" if state in ["disabled", "focus"] else state
			if table == "selectable": source += "_active" if selected else ""
			elif state == "pressed": source = "active"
			control.add_theme_stylebox_override(state, padded(table, source, Color.BLACK, number(table, "content_padding_x", number(table, "padding_x", 0)), number(table, "content_padding_y", number(table, "padding_y", 0))))
		if control is OptionButton:
			icon(control, "arrow", texture("combo.button", "normal")); control.add_theme_constant_override("arrow_margin", 5)
			popup(control.get_popup(), font, size)
	elif control is LineEdit or control is TextEdit:
		for state in ["normal", "focus", "read_only"]: control.add_theme_stylebox_override(state, padded("edit", "active" if state == "focus" else "normal", Color.BLACK, number("edit", "padding_x", 0), number("edit", "padding_y", 0)))
		color(control, "caret_color", tint); color(control, "selection_color", owner.skin_color("contextual_button", "active", Color(0.68, 0.56, 0.38)))
	elif control is ProgressBar:
		control.add_theme_stylebox_override("background", padded("progress", "normal", Color.BLACK)); control.add_theme_stylebox_override("fill", padded("progress", "cursor_normal", Color(0.68, 0.56, 0.38)))
	elif control is Slider:
		for state in ["grabber", "grabber_highlight", "grabber_disabled"]: icon(control, state, texture("slider", "cursor_hover" if state == "grabber_highlight" else "cursor_normal"))
		var filled: Color = owner.skin_color("slider", "bar_filled", Color(0.68, 0.56, 0.38))
		control.add_theme_stylebox_override("slider", padded("property", "normal", Color.BLACK, 0, 2)); control.add_theme_stylebox_override("grabber_area", padded("slider", "bar_filled", filled, 0, 2)); control.add_theme_stylebox_override("grabber_area_highlight", padded("slider", "bar_filled", filled, 0, 2))
		control.add_theme_constant_override("center_grabber", 1)
	control.end_bulk_theme_override()
func scrollbar(control: ScrollBar, vertical: bool) -> void:
	var key := str(revision) + "/" + str(vertical)
	if control.get_meta("nui_scroll_style", "") == key: return
	control.set_meta("nui_scroll_style", key)
	control.begin_bulk_theme_override()
	var table := "scrollv" if vertical else "scrollh"
	control.add_theme_stylebox_override("scroll", padded(table, "normal", Color.BLACK)); control.add_theme_stylebox_override("scroll_focus", padded(table, "hover", Color.BLACK))
	for pair in [["grabber", "cursor_normal"], ["grabber_highlight", "cursor_hover"], ["grabber_pressed", "cursor_active"]]: control.add_theme_stylebox_override(pair[0], padded(table, pair[1], Color(0.68, 0.56, 0.38), 0 if vertical else 8, 8 if vertical else 0))
	for pair in [["increment", "inc_button"], ["decrement", "dec_button"]]:
		for state in [["", "normal"], ["_highlight", "hover"], ["_pressed", "active"]]: icon(control, pair[0] + state[0], texture(table + "." + pair[1], state[1]))
	if vertical: control.custom_minimum_size.x = number("window", "scrollbar_size_x", 18)
	else: control.custom_minimum_size.y = number("window", "scrollbar_size_y", 18)
	control.end_bulk_theme_override()
func popup(menu: PopupMenu, font: Font, size: int) -> void:
	menu.begin_bulk_theme_override()
	menu.add_theme_font_override("font", font); menu.add_theme_font_size_override("font_size", size)
	menu.add_theme_color_override("font_color", owner.skin_color("text", "color", Color.WHITE)); menu.add_theme_color_override("font_hover_color", Color.WHITE)
	menu.add_theme_stylebox_override("panel", padded("window", "fixed_background", Color.BLACK, 4, 4)); menu.add_theme_stylebox_override("hover", padded("contextual_button", "active", Color(0.68, 0.56, 0.38), 4, 2))
	menu.end_bulk_theme_override()
