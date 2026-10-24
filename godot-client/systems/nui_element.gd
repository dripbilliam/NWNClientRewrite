extends Control
const Canvas = preload("res://systems/nui_canvas.gd")
var manager
var window_id := -1
var control_id := -1
var kind := ""
var spec: Dictionary = {}
var values: Dictionary = {}
var logical_children: Array = []
var holder: Control
var scroll: ScrollContainer
var widget: Control
var popup: Popup
var image_canvas
var background
var foreground
var option_buttons: Array = []
var option_labels: Array = []
var option_group: ButtonGroup
var hovered := false
var pointer_button := -1
var applying := false
var retired := false
var request_range_key := ""
var text_revision := 0

func configure(owner, window: int, row: Dictionary) -> void:
	manager = owner; window_id = window; control_id = int(row.controlId); kind = str(row.type); spec = row
	clip_contents = false; mouse_filter = Control.MOUSE_FILTER_STOP
	background = Canvas.new(); background.element = self; background.order = -1; add_child(background)
	if kind in ["list", "group"]:
		scroll = ScrollContainer.new(); add_child(scroll); holder = Control.new(); scroll.add_child(holder)
		scroll.get_v_scroll_bar().value_changed.connect(func(_v): request_range())
		scroll.get_h_scroll_bar().value_changed.connect(func(_v): request_range())
	else: holder = Control.new(); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(holder)
	match kind:
		"button", "button_image", "button_select":
			widget = Button.new(); widget.clip_text = true; widget.toggle_mode = kind == "button_select"; widget.pressed.connect(pressed)
		"check": widget = CheckBox.new(); widget.pressed.connect(pressed)
		"label": widget = Label.new(); widget.clip_text = true; widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		"text": widget = RichTextLabel.new(); widget.bbcode_enabled = false; widget.selection_enabled = true; widget.fit_content = false; widget.focus_mode = Control.FOCUS_NONE
		"combo": widget = OptionButton.new(); widget.clip_text = true; widget.item_selected.connect(func(index): change(index)); widget.pressed.connect(pressed)
		"slider", "sliderf": widget = HSlider.new(); widget.value_changed.connect(func(value): change(int(value) if kind == "slider" else value))
		"progress": widget = ProgressBar.new(); widget.show_percentage = false
		"textedit":
			if bool(row.values.get("multiline", false)):
				widget = TextEdit.new(); widget.text_changed.connect(text_changed)
			else:
				widget = LineEdit.new(); widget.text_changed.connect(func(_value): text_changed())
		"color_picker": widget = ColorPickerButton.new(); widget.pressed.connect(pressed); widget.color_changed.connect(func(value): change({"r": roundi(value.r * 255), "g": roundi(value.g * 255), "b": roundi(value.b * 255), "a": roundi(value.a * 255)}))
	if widget != null:
		add_child(widget)
		if widget is OptionButton or widget is ColorPickerButton: popup = widget.get_popup()
		widget.gui_input.connect(func(event): pointer(event, widget))
		widget.focus_entered.connect(func(): event("focus")); widget.focus_exited.connect(func(): event("blur"))
		widget.mouse_entered.connect(func(): hover(true)); widget.mouse_exited.connect(func(): hover(false))
	if kind in ["image", "button_image", "chart"]:
		image_canvas = Canvas.new(); image_canvas.element = self
		if kind == "button_image": widget.add_child(image_canvas)
		else: add_child(image_canvas)
	foreground = Canvas.new(); foreground.element = self; foreground.order = 1; add_child(foreground)
	gui_input.connect(func(event): pointer(event, self)); mouse_entered.connect(func(): hover(true)); mouse_exited.connect(func(): hover(false))
	resized.connect(layout)
	apply(row)

func send(message: Dictionary) -> void:
	if not applying and not retired and values.get("enabled", false): manager.request.emit({"kind": "nui-input", "windowId": window_id, "controlId": control_id}.merged(message))
func dismiss_popup() -> void:
	if popup != null and popup.visible: popup.hide()
func retire() -> void:
	retired = true; dismiss_popup()
func popup_blocks_pointer(point: Vector2) -> bool:
	if popup == null or not popup.visible or retired: return false
	var at := Vector2(popup.position)
	# Embedded popups use client coordinates; native windows use desktop ones.
	if not popup.is_embedded(): at -= Vector2(get_window().position)
	return Rect2(at, Vector2(popup.size)).has_point(point)
func event(type: String, fields: Dictionary = {}) -> void: send({"operation": "event", "event": type}.merged(fields))
func change(value: Variant) -> void: send({"operation": "change", "value": value})
func pressed() -> void:
	if kind in ["button_select", "check"]: change(widget.button_pressed)
	event("click")
func text_changed() -> void:
	if applying: return
	var maximum := int(values.get("max", 1024))
	if kind == "textedit" and widget.text.length() > maximum:
		applying = true; widget.text = widget.text.left(maximum); applying = false
	text_revision += 1
	send({"operation": "change", "value": widget.text, "inputRevision": text_revision})
func hover(value: bool) -> void:
	if retired: return
	if widget != null: manager.style(widget, kind, str(values.get("font", "(default)")), values.get("foreground_color"))
	hovered = value; background.queue_redraw(); foreground.queue_redraw()
func pointer(input: InputEvent, source: Control) -> void:
	if input is InputEventMouseButton:
		var at: Vector2 = source.get_global_transform() * input.position
		var position := {"x": at.x, "y": at.y}
		if input.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var button: int = {MOUSE_BUTTON_LEFT: 0, MOUSE_BUTTON_RIGHT: 2, MOUSE_BUTTON_MIDDLE: 1}[input.button_index]
			event("mousedown" if input.pressed else "mouseup", {"position": position, "button": button})
			if input.pressed: pointer_button = button
			else:
				if pointer_button == button and not widget is BaseButton: event("click")
				pointer_button = -1
		elif input.pressed and input.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var direction: Vector2 = {MOUSE_BUTTON_WHEEL_UP: Vector2(0, 1), MOUSE_BUTTON_WHEEL_DOWN: Vector2(0, -1), MOUSE_BUTTON_WHEEL_LEFT: Vector2(1, 0), MOUSE_BUTTON_WHEEL_RIGHT: Vector2(-1, 0)}[input.button_index] * input.factor
			event("mousescroll", {"position": position, "scroll": {"x": direction.x, "y": direction.y}})
		background.queue_redraw(); foreground.queue_redraw()

func apply(row: Dictionary) -> void:
	applying = true; spec = row; values = row.values.duplicate(true)
	visible = bool(values.get("visible", true)); tooltip_text = str(values.get("tooltip", "")); mouse_filter = Control.MOUSE_FILTER_STOP if manager.accepts(window_id) else Control.MOUSE_FILTER_IGNORE
	if not visible or not values.get("enabled", true) or not manager.accepts(window_id): dismiss_popup()
	background.commands = values.get("draw_list", []); foreground.commands = background.commands
	background.clip_contents = values.get("draw_list_scissor", true); foreground.clip_contents = background.clip_contents
	if widget != null:
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE if widget is Label or not manager.accepts(window_id) else Control.MOUSE_FILTER_STOP
		widget.modulate.a = 1 if values.get("enabled", true) else 0.55
		if widget is BaseButton: widget.disabled = not values.get("enabled", true)
		# Font changes can synchronously reshape existing native editor text.
		# Install the complete theme while a new widget is still empty, before
		# assigning its document. Button state is styled below after selection.
		if widget is Label or widget is RichTextLabel or widget is LineEdit or widget is TextEdit:
			manager.style(widget, kind, str(values.get("font", "(default)")), values.get("foreground_color"))
		match kind:
			"button", "button_select", "check":
				widget.text = str(values.get("label", ""))
				if kind != "button": widget.set_pressed_no_signal(bool(values.get("value", false)))
			"label":
				widget.text = str(values.get("label", "")); widget.horizontal_alignment = [HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT][clampi(int(values.get("text_halign", 0)), 0, 2)]; widget.vertical_alignment = [VERTICAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, VERTICAL_ALIGNMENT_BOTTOM][clampi(int(values.get("text_valign", 0)), 0, 2)]
			"text":
				if widget.text != str(values.get("label", "")): widget.text = str(values.get("label", ""))
				widget.scroll_active = int(values.get("scrollbars", 4)) in [2, 3, 4]
			"combo":
				if option_labels != values.get("options", []):
					option_labels = values.options.duplicate(); widget.clear()
					for label in option_labels: widget.add_item(str(label))
				widget.select(int(values.get("selected", -1)))
			"slider", "sliderf", "progress":
				widget.set_block_signals(true); widget.min_value = float(values.get("min", 0)); widget.max_value = float(values.get("max", 100)); widget.step = float(values.get("step", 0)); widget.value = float(values.get("value", 0)); widget.set_block_signals(false)
				if widget is Slider: widget.editable = bool(values.get("enabled", true))
			"textedit":
				# Changing max_length reapplies LineEdit's document. Set the limit
				# before a replacement value so a large incoming edit is shaped once.
				if widget is LineEdit:
					var maximum := int(values.get("max", 1024))
					if widget.max_length != maximum:
						var caret: int = widget.caret_column; widget.max_length = maximum; widget.caret_column = mini(caret, widget.text.length())
				# Earlier queued projections must not overwrite text entered after
				# they were prepared. Once the backend applies this input, ordinary
				# authoritative server replacements are accepted again.
				if int(values.get("inputAck", 0)) >= text_revision and widget.text != str(values.get("value", "")):
					if widget is LineEdit:
						var caret: int = widget.caret_column; widget.text = str(values.get("value", "")); widget.caret_column = mini(caret, widget.text.length())
					else:
						var line: int = widget.get_caret_line(); var column: int = widget.get_caret_column(); widget.text = str(values.get("value", "")); widget.set_caret_line(mini(line, widget.get_line_count() - 1)); widget.set_caret_column(column)
				widget.placeholder_text = str(values.get("label", "")); widget.editable = bool(values.get("enabled", true))
				if widget is TextEdit: widget.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if values.get("wordwrap", true) else TextEdit.LINE_WRAPPING_NONE
			"color_picker": widget.color = foreground.rgba(values.get("value")); widget.disabled = not values.get("enabled", true)
	if widget != null: manager.style(widget, kind, str(values.get("font", "(default)")), values.get("foreground_color"))
	if image_canvas != null:
		image_canvas.image_id = int(values.get("image", -1)); image_canvas.image_aspect = int(values.get("image_aspect", 0)); image_canvas.image_halign = int(values.get("image_halign", 0)); image_canvas.image_valign = int(values.get("image_valign", 0)); image_canvas.chart = values.get("slots", []); image_canvas.queue_redraw()
	if kind in ["options", "tabbar"]: options()
	if scroll != null:
		var bars := int(values.get("scrollbars", 4))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if bars in [1, 3] else (ScrollContainer.SCROLL_MODE_AUTO if bars == 4 else ScrollContainer.SCROLL_MODE_DISABLED)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if bars in [2, 3] else (ScrollContainer.SCROLL_MODE_AUTO if bars == 4 else ScrollContainer.SCROLL_MODE_DISABLED)
	background.queue_redraw(); foreground.queue_redraw(); applying = false; layout(); queue_redraw()

func options() -> void:
	if option_labels != values.get("options", []):
		option_labels = values.options.duplicate()
		for button in option_buttons: button.queue_free()
		option_buttons.clear(); option_group = ButtonGroup.new() if kind == "options" else null
		for index in option_labels.size():
			var button: Button = CheckBox.new() if kind == "options" else Button.new(); button.button_group = option_group; button.clip_text = true; button.text = str(option_labels[index]); button.pressed.connect(func(): change(index); event("click")); button.gui_input.connect(func(input): pointer(input, button)); button.focus_entered.connect(func(): event("focus")); button.focus_exited.connect(func(): event("blur")); add_child(button); option_buttons.append(button)
			button.mouse_entered.connect(func(): if not retired: manager.style(button, "option" if kind == "options" else "button_select", str(values.get("font", "(default)")), values.get("foreground_color")))
			button.mouse_exited.connect(func(): if not retired: manager.style(button, "option" if kind == "options" else "button_select", str(values.get("font", "(default)")), values.get("foreground_color")))
	for index in option_buttons.size():
		var button: Button = option_buttons[index]; button.toggle_mode = true; button.set_pressed_no_signal(index == int(values.get("selected", -1))); manager.style(button, "option" if kind == "options" else "button_select", str(values.get("font", "(default)")), values.get("foreground_color")); button.disabled = not values.get("enabled", true); button.mouse_filter = Control.MOUSE_FILTER_STOP if manager.accepts(window_id) else Control.MOUSE_FILTER_IGNORE
	foreground.move_to_front()

func children_changed(children: Array) -> void:
	logical_children = children
	for child in children:
		if child.get_parent() != holder:
			if child.get_parent() != null: child.get_parent().remove_child(child)
			holder.add_child(child)
	layout()
func desired(axis: int) -> float:
	var key := "width" if axis == 0 else "height"
	if values.has(key) and float(values[key]) >= 0: return float(values[key])
	var aspect := float(values.get("aspect", 0))
	var other := "height" if axis == 0 else "width"
	if aspect > 0 and values.has(other) and float(values[other]) >= 0: return float(values[other]) * aspect if axis == 0 else float(values[other]) / aspect
	if kind in ["row", "col", "group"]:
		var answer := 0.0; var sum := (kind == "row") == (axis == 0)
		for child in logical_children:
			var value: float = child.desired(axis) + 2 * float(child.values.get("margin", 0))
			answer = answer + value if sum else maxf(answer, value)
		return answer + maxf(0, logical_children.size() - 1) * 4 if sum else answer
	return 0 if axis == 0 or kind == "spacer" else (100 if kind in ["list", "chart", "text"] else 25)

func layout() -> void:
	if background == null: return
	background.position = Vector2.ZERO; background.size = size; foreground.position = Vector2.ZERO; foreground.size = size
	if widget != null: widget.position = Vector2.ZERO; widget.size = size
	if image_canvas != null: image_canvas.position = Vector2.ZERO; image_canvas.size = size
	if kind in ["options", "tabbar"]:
		var vertical := int(values.get("direction", 0)) == 1; var span := size.y if vertical else size.x; var extent := maxf(0, span - maxf(0, option_buttons.size() - 1) * 4) / maxi(1, option_buttons.size())
		for index in option_buttons.size(): option_buttons[index].position = Vector2(0, index * (extent + 4)) if vertical else Vector2(index * (extent + 4), 0); option_buttons[index].size = Vector2(size.x, extent) if vertical else Vector2(extent, size.y)
	var pad := float(values.get("padding", 0)); var available := (size - Vector2.ONE * pad * 2).max(Vector2.ZERO)
	if scroll != null: scroll.position = Vector2.ONE * pad; scroll.size = available
	else: holder.position = Vector2.ONE * pad; holder.size = available
	if kind == "list":
		var row_height := maxf(1, float(values.get("row_height", 25))); holder.custom_minimum_size = Vector2(maxf(0, available.x - (scroll.get_v_scroll_bar().size.x if scroll.get_v_scroll_bar().visible else 0)), int(values.get("row_count", 0)) * row_height)
		var rows := {}
		for child in logical_children:
			var row := int(child.spec.get("cell", {}).get("row", 0)); if not rows.has(row): rows[row] = []
			rows[row].append(child)
		for row in rows:
			var children: Array = rows[row]; var fixed := maxf(0, children.size() - 1) * 4; var variable := 0
			for child in children:
				fixed += float(child.spec.cell.width)
				if child.spec.cell.variable or float(child.spec.cell.width) <= 0: variable += 1
			var extra := maxf(0, holder.custom_minimum_size.x - fixed) / maxi(1, variable); var cursor := 0.0
			for child in children:
				var width: float = float(child.spec.cell.width) + (extra if child.spec.cell.variable or float(child.spec.cell.width) <= 0 else 0)
				child.position = Vector2(cursor, int(row) * row_height); child.size = Vector2(width, row_height); cursor += width + 4
		request_range()
	elif kind in ["row", "col", "group"]:
		var horizontal := kind == "row"; var key := "width" if horizontal else "height"; var fixed := maxf(0, logical_children.size() - 1) * 4; var growing := 0
		for child in logical_children:
			fixed += child.desired(0 if horizontal else 1) + 2 * float(child.values.get("margin", 0))
			if not child.values.has(key): growing += 1
		var span := available.x if horizontal else available.y
		if scroll != null:
			span = maxf(span, fixed); holder.custom_minimum_size = Vector2(available.x, span); holder.size = holder.custom_minimum_size
		var extra := maxf(0, span - fixed) / maxi(1, growing); var cursor := 0.0
		for child in logical_children:
			var margin := float(child.values.get("margin", 0)); var extent: float = child.desired(0 if horizontal else 1) + (extra if not child.values.has(key) else 0)
			child.position = Vector2(cursor + margin, margin) if horizontal else Vector2(margin, cursor + margin)
			var cross: float = child.desired(1 if horizontal else 0) if child.values.has("height" if horizontal else "width") else maxf(0, (available.y if horizontal else available.x) - 2 * margin)
			child.size = Vector2(extent, cross) if horizontal else Vector2(cross, extent)
			cursor += extent + 2 * margin + 4
	foreground.queue_redraw(); background.queue_redraw()

func request_range() -> void:
	if kind != "list" or scroll == null or retired: return
	var height := maxf(1, float(values.get("row_height", 25))); var count := int(values.get("row_count", 0)); var start := maxi(0, floori(scroll.scroll_vertical / height) - 3); var wanted := mini(count, start + clampi(ceili(scroll.size.y / height) + 7, 1, 4096))
	if start >= int(values.get("first", 0)) and wanted <= int(values.get("last", 0)): return
	var key := str(start) + "/" + str(wanted - start)
	if key == request_range_key or wanted <= start: return
	request_range_key = key; manager.request.emit({"kind": "nui-input", "windowId": window_id, "controlId": control_id, "operation": "range", "start": start, "count": wanted - start})
func _draw() -> void:
	if values.get("border", false): draw_style_box(manager.box("border", "border_image", Color.TRANSPARENT), Rect2(Vector2.ZERO, size))
	if values.get("encouraged", false): draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color(1, 0.9, 0.3, 0.5 + 0.4 * sin(Time.get_ticks_msec() / 300.0)), false, 2)
func _process(_delta: float) -> void:
	if values.get("encouraged", false): queue_redraw()
