extends CanvasLayer

signal request(message: Dictionary)
signal closed
signal voice_observed(value: Dictionary)
var voice_audio
var appearance_preview
var voice_status: Label
var voice_sample_button: Button
var voice_sample_id := -1
var voice_caption := ""
var panel: PanelContainer
var title: Label
var status: Label
var errors: RichTextLabel
var body: VBoxContainer
var scroll: ScrollContainer
var tabs: Array = []
var controls: Dictionary = {}
var inputs: Dictionary = {}
var items: Array = []
var state: Dictionary = {}
var pending: Dictionary = {}
var positions: Dictionary = {}
var view_id := -1
var wanted := false
var waiting := false
var back: Button
var next: Button
var finish: Button
var recommend: Button
var cancel: Button

func _ready() -> void:
	layer = 40
	voice_audio = preload("res://systems/creation_audio.gd").new(); add_child(voice_audio); voice_audio.observed.connect(func(value): voice_observed.emit(value))
	panel = PanelContainer.new(); add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.035, 0.055, 0.065, 0.99); style.border_color = Color(0.6, 0.51, 0.29); style.set_border_width_all(2); style.set_content_margin_all(18); panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); panel.add_child(column)
	title = Label.new(); title.text = "Create Character"; title.add_theme_font_size_override("font_size", 28); title.add_theme_color_override("font_color", Color(0.94, 0.86, 0.63)); column.add_child(title)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)
	var middle := HBoxContainer.new(); middle.size_flags_vertical = Control.SIZE_EXPAND_FILL; middle.add_theme_constant_override("separation", 20); column.add_child(middle)
	var sidebar := VBoxContainer.new(); sidebar.custom_minimum_size.x = 200; middle.add_child(sidebar)
	for index in 15:
		var button := make_button("%d. %s" % [index + 1, ["Gender", "Race", "Portrait", "Class", "Alignment", "Package", "Abilities", "Domains & school", "Skills", "Feats", "Spells", "Appearance", "Voice", "Name", "Review"][index]], navigate.bind(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT; sidebar.add_child(button); tabs.append(button)
	scroll = ScrollContainer.new(); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; middle.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8); scroll.add_child(body)
	appearance_preview = preload("res://systems/creation_preview.gd").new(); middle.add_child(appearance_preview); appearance_preview.retry_requested.connect(func(): if ready_for_input(view_id): request.emit({"kind":"creation-input","operation":"preview","viewId":view_id}))
	errors = RichTextLabel.new(); errors.custom_minimum_size.y = 90; errors.scroll_active = true; errors.bbcode_enabled = false; errors.add_theme_color_override("default_color", Color(1, 0.65, 0.52)); column.add_child(errors)
	voice_status = Label.new(); voice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(voice_status); voice_status.hide()
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_END; column.add_child(footer)
	voice_sample_button = make_button("Play sample", func(): sample_voice(voice_sample_id, view_id)); footer.add_child(voice_sample_button); voice_sample_button.hide()
	cancel = make_button("Cancel", close_creator); footer.add_child(cancel)
	back = make_button("Back", func(): navigate(int(state.get("step", 0)) - 1)); footer.add_child(back)
	recommend = make_button("Recommended", choose_recommended); footer.add_child(recommend)
	next = make_button("Next", func(): navigate(int(state.get("step", 0)) + 1)); footer.add_child(next)
	finish = make_button("Play", submit); footer.add_child(finish)
	get_viewport().size_changed.connect(place); place(); reset()

func make_button(label: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = label; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(callback); return button

func place() -> void:
	var viewport := get_viewport().get_visible_rect().size
	panel.position = Vector2(24, 12); panel.size = (viewport - Vector2(48, 24)).max(Vector2(720, 640))
	status.custom_minimum_size.x = maxf(450, panel.size.x - 40); errors.custom_minimum_size.x = status.custom_minimum_size.x

func clear_body() -> void:
	controls.clear(); inputs.clear(); voice_sample_id = -1; voice_caption = ""
	if is_instance_valid(voice_sample_button): voice_sample_button.hide()
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func reset() -> void:
	if is_instance_valid(voice_audio): voice_audio.reset()
	if is_instance_valid(appearance_preview): appearance_preview.set_active(false)
	wanted = false; waiting = false; view_id = -1; state.clear(); pending.clear(); items.clear(); positions.clear()
	if is_instance_valid(body): clear_body(); panel.hide()

func open() -> void:
	if wanted: panel.show(); return
	wanted = true; waiting = true; panel.show(); status.text = "Reading active character creation rules…"
	request.emit({"kind":"creation-input", "operation":"open"})

func text_values() -> Array:
	var values: Array = []
	for id in inputs: values.append({"controlId":int(id), "value":inputs[id].text})
	return values

func ready_for_input(bound: int) -> bool:
	return wanted and not waiting and bound == view_id and state.get("canEdit", false)

func set_waiting() -> void:
	waiting = true
	for button in tabs + [back, next, finish, recommend]: button.disabled = true
	for control in controls.values():
		if control is BaseButton: control.disabled = true
		elif control is LineEdit or control is TextEdit: control.editable = false

func operation(name: String, values: Dictionary = {}) -> void:
	var message := {"kind":"creation-input", "operation":name, "viewId":view_id, "texts":text_values()}
	message.merge(values, true); set_waiting(); request.emit(message)

func change(id: int, value: Variant, bound: int) -> void:
	if ready_for_input(bound): operation("control", {"controlId":id,"value":value})

func navigate(step: int) -> void:
	if ready_for_input(view_id) and step >= 0 and step < 15: operation("page", {"step":step})

func choose_recommended() -> void:
	if ready_for_input(view_id) and state.get("canRecommend", false): operation("recommend")

func submit() -> void:
	if ready_for_input(view_id) and state.get("canFinish", false): operation("submit")

func close_creator() -> void:
	if wanted and state.get("canCancel", true):
		set_waiting(); request.emit({"kind":"creation-input", "operation":"cancel"})

func sample_voice(id: int, bound: int) -> void:
	if ready_for_input(bound):
		voice_audio.stop(); voice_status.text = "Loading voice sample…"
		request.emit({"kind":"creation-input","operation":"voice","viewId":view_id,"controlId":id})

func _process(_delta: float) -> void:
	if wanted and voice_status.visible: voice_status.text = "Selected voice: " + voice_caption + "\n" + (voice_audio.status if not voice_audio.status.is_empty() else "Play sample to listen. Repeat for the next line.")

func receive(message: Dictionary) -> void:
	if str(message.kind).begins_with("creation-preview-"):
		if wanted: appearance_preview.receive(message)
		return
	if str(message.kind).begins_with("creation-audio-") or str(message.kind).begins_with("creation-voice-"):
		if wanted: voice_audio.receive(message)
		return
	match str(message.kind):
		"creation-closed": reset(); closed.emit()
		"creation-begin":
			if not wanted or int(message.viewId) <= view_id: return
			pending = message.duplicate(true); pending["items"] = []
		"creation-items":
			if pending.get("viewId", -1) == message.viewId and pending["items"].size() + message.items.size() <= int(pending.count): pending["items"].append_array(message.items)
		"creation-commit":
			if pending.get("viewId", -1) != message.viewId or pending["items"].size() != int(pending.count): return
			if not state.is_empty(): positions[int(state.step)] = scroll.scroll_vertical
			state = pending; pending = {}; items = state["items"]; view_id = int(state.viewId); waiting = false; render()
		"creation-portrait":
			if int(message.viewId) != view_id or not controls.has(int(message.controlId)): return
			var button: Button = controls[int(message.controlId)]
			var image = preload("res://systems/runtime_image.gd").png(str(message.image))
			if image != null and button.has_meta("portrait"): button.get_meta("portrait").texture = image; button.text = ""
		"creation-notice": status.text = str(message.text)

func render() -> void:
	appearance_preview.set_active(int(state.step) == 11 and state.get("phase", "editing") == "editing")
	voice_status.visible = int(state.step) == 12
	if voice_status.visible: voice_audio.configure(int(state.get("voiceOwner", 0)))
	else: voice_audio.reset()
	clear_body(); title.text = "Create Character · " + str(state.steps[int(state.step)])
	status.text = str(state.get("status", "")); errors.text = "\n".join(state.get("errors", [])); errors.visible = not errors.text.is_empty()
	for index in tabs.size():
		tabs[index].disabled = not state.canEdit or index == int(state.step)
		if index == int(state.step):
			var active := StyleBoxFlat.new(); active.bg_color = Color(0.23, 0.2, 0.13); active.border_color = Color(0.85, 0.72, 0.38); active.set_border_width_all(1); tabs[index].add_theme_stylebox_override("disabled", active); tabs[index].add_theme_color_override("font_disabled_color", Color(0.94, 0.86, 0.63))
		else: tabs[index].remove_theme_stylebox_override("disabled"); tabs[index].remove_theme_color_override("font_disabled_color")
	back.disabled = not state.canEdit or int(state.step) == 0; next.disabled = not state.canEdit; next.visible = int(state.step) < 14
	finish.visible = int(state.step) == 14; finish.disabled = not state.canFinish; recommend.disabled = not state.canRecommend; cancel.disabled = not state.canCancel
	var grid: GridContainer = null
	var grid_kind := ""
	var increments: HBoxContainer = null
	for item in items:
		if item.get("tag", "") == "voice" and item.get("selected", false): voice_caption = str(item.label)
		if item.type not in ["portrait", "colour"]: grid = null; grid_kind = ""
		if item.type == "text":
			var label := Label.new(); label.text = str(item.label); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(label)
			increments = null; continue
		var id := int(item.controlId); var bound := view_id
		if item.type in ["button", "portrait", "colour"]:
			var target: Node = body
			if item.type in ["portrait", "colour"]:
				if grid == null or grid_kind != str(item.type):
					grid = GridContainer.new(); grid.columns = maxi(1, int((panel.size.x - 290 - (320 if appearance_preview.active else 0)) / (76 if item.type == "portrait" else 30))); body.add_child(grid); grid_kind = str(item.type)
				target = grid
			elif item.get("tag", "") in ["ability", "skill"]:
				if int(item.delta) == -1 or increments == null: increments = HBoxContainer.new(); body.add_child(increments)
				target = increments
			var button := make_button(str(item.label), change.bind(id, null, bound)); button.disabled = item.disabled; button.tooltip_text = str(item.get("reason", "")); target.add_child(button); controls[id] = button
			button.clip_text = true
			if item.get("selected", false):
				var selected := StyleBoxFlat.new(); selected.bg_color = Color(0.2, 0.17, 0.1); selected.border_color = Color(0.9, 0.75, 0.36); selected.set_border_width_all(2); button.add_theme_stylebox_override("normal", selected); button.add_theme_color_override("font_color", Color(1, 0.86, 0.6))
			if item.type == "portrait":
				button.custom_minimum_size = Vector2(70, 106); button.clip_text = true
				var image := TextureRect.new(); image.position = Vector2(3, 3); image.size = Vector2(64, 100); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(image); button.set_meta("portrait", image); button.tooltip_text = str(item.resource)
			elif item.type == "colour":
				button.custom_minimum_size = Vector2(26, 26); button.text = ""; button.tooltip_text = str(item.label)
				var color := ColorRect.new(); color.color = Color(str(item.color)); color.position = Vector2(3, 3); color.size = Vector2(20, 20); color.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(color)
		elif item.type == "voice-sample":
			voice_sample_id = id; voice_sample_button.text = str(item.label); voice_sample_button.disabled = item.disabled; voice_sample_button.show(); controls[id] = voice_sample_button
		elif item.type == "toggle":
			var check := CheckBox.new(); check.text = str(item.label); check.focus_mode = Control.FOCUS_NONE; check.button_pressed = item.value; check.disabled = item.disabled; body.add_child(check); controls[id] = check; check.toggled.connect(func(value): change(id, value, bound))
		elif item.type == "select":
			var row := HBoxContainer.new(); body.add_child(row)
			var label := Label.new(); label.text = str(item.label); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
			var choice := OptionButton.new(); choice.focus_mode = Control.FOCUS_NONE; choice.disabled = item.disabled; choice.custom_minimum_size.x = 240; row.add_child(choice); controls[id] = choice
			var offset := 1 if int(item.value) < 0 else 0
			if offset: choice.add_item("Choose…"); choice.set_item_disabled(0, true)
			for label_text in item.options: choice.add_item(str(label_text))
			choice.select(maxi(0, int(item.value)) + (offset if int(item.value) >= 0 else 0)); choice.item_selected.connect(func(index): change(id, index - offset, bound))
		elif item.type == "input":
			var label := Label.new(); label.text = str(item.label); body.add_child(label)
			if item.get("multiline", false):
				var field := TextEdit.new(); field.text = str(item.value); field.custom_minimum_size.y = 150; field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; field.editable = state.canEdit; body.add_child(field); inputs[id] = field; controls[id] = field; field.text_changed.connect(limit_text.bind(field, int(item.maxLength)))
			else:
				var field := LineEdit.new(); field.text = str(item.value); field.max_length = int(item.maxLength); field.editable = state.canEdit; body.add_child(field); inputs[id] = field; controls[id] = field
	call_deferred("restore_scroll", int(state.step))

func restore_scroll(step: int) -> void:
	if wanted and int(state.get("step", -1)) == step: scroll.scroll_vertical = int(positions.get(step, 0))

func limit_text(field: TextEdit, maximum: int) -> void:
	if field.text.length() > maximum: field.text = field.text.left(maximum); field.set_caret_line(field.get_line_count() - 1); field.set_caret_column(field.get_line(field.get_caret_line()).length())

func blocks_pointer(point: Vector2) -> bool: return panel.visible and panel.get_global_rect().has_point(point)
