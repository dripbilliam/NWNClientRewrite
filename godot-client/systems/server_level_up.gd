extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal presentation_reset
signal source_reopen
var wanted := false
var view_id := -1
var state: Dictionary = {}
var inputs: Dictionary = {}
var controls: Dictionary = {}
var tabs: Array = []
var scroll: ScrollContainer
var body: VBoxContainer
var status: Label
var errors: Label
var back: Button
var next: Button
var finish: Button
var cancel: Button
var positions: Dictionary = {}
var waiting := false
var source_active:=false
var request_serial:=0

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Level Up", "level-up", Vector2(100, 70), storage)
	custom_minimum_size = Vector2(820, 700)
	close_hides = false
	var navigation := HBoxContainer.new(); content.add_child(navigation)
	for index in 7:
		var button := Button.new(); button.text = ["Class", "Abilities", "Skills", "Feats", "Spells", "Choices", "Review"][index]; button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): navigate(index)); navigation.add_child(button); tabs.append(button)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x = 780; content.add_child(status)
	scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(780, 440); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	errors = Label.new(); errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; errors.custom_minimum_size.x = 780; errors.add_theme_color_override("font_color", Color.ORANGE); content.add_child(errors)
	var footer := HBoxContainer.new(); content.add_child(footer)
	for definition in [["Back", "back"], ["Next", "next"], ["Finish", "finish"], ["Cancel", "cancel"]]:
		var button := Button.new(); button.text = definition[0]; button.focus_mode = Control.FOCUS_NONE; footer.add_child(button)
		match definition[1]:
			"back": back = button; button.pressed.connect(func(): navigate(int(state.get("step", 0)) - 1))
			"next": next = button; button.pressed.connect(func(): navigate(int(state.get("step", 0)) + 1))
			"finish": finish = button; button.pressed.connect(submit)
			"cancel": cancel = button; button.pressed.connect(close_level_up)
	close_requested.connect(close_level_up)
	reset()

func reset() -> void:
	wanted = false; view_id = -1; waiting = false; source_active=false;request_serial+=1;state.clear(); positions.clear(); clear_body(); hide();presentation_reset.emit()

func clear_body() -> void:
	inputs.clear(); controls.clear()
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func open() -> void:
	if wanted and source_active:source_reopen.emit();return
	if wanted: show(); move_to_front(); return
	wanted = true;request_serial+=1; show(); move_to_front(); status.text = "Requesting server level-up choices…"
	request.emit({"kind": "level-open"})

func activate_source(value: bool) -> void:
	source_active=value
	if value:hide()
	elif wanted:show();move_to_front()

func text_values() -> Array:
	var result: Array = []
	for id in inputs: result.append({"controlId": int(id), "value": inputs[id].text})
	return result

func ready_for_input(bound: int) -> bool:
	return wanted and not waiting and bound == view_id and state.get("canEdit", false)

func set_waiting() -> void:
	waiting = true
	for button in tabs + [back, next, finish]: button.disabled = true
	for control in controls.values():
		if control is BaseButton: control.disabled = true
		if control is LineEdit: control.editable = false

func change(id: int, value: Variant, bound: int) -> void:
	if not ready_for_input(bound): return
	var text := text_values(); set_waiting()
	request.emit({"kind": "level-control", "viewId": bound, "controlId": id, "value": value, "texts": text})

func navigate(step: int) -> void:
	if not ready_for_input(view_id) or step < 0 or step > 6: return
	var text := text_values(); set_waiting()
	request.emit({"kind": "level-page", "viewId": view_id, "step": step, "texts": text})

func submit() -> void:
	if not ready_for_input(view_id) or not state.get("canFinish", false): return
	set_waiting(); request.emit({"kind": "level-submit", "viewId": view_id})

func close_level_up() -> void:
	if not wanted or not state.get("canCancel", true): return
	request.emit({"kind": "level-cancel"})

func receive(message: Dictionary) -> void:
	match message.kind:
		"level-closed", "level-complete": reset()
		"level-notice": status.text = str(message.text)
		"level-view":
			if not wanted: return
			if not state.is_empty(): positions[int(state.step)] = scroll.scroll_vertical
			state = message.duplicate(true); view_id = int(message.viewId); waiting = false
			render()

func render() -> void:
	clear_body()
	set_caption("Level Up" + (" · Level " + str(int(state.level)) if state.get("level") != null else ""))
	status.text = str(state.get("status", ""))
	errors.text = "\n".join(state.get("errors", [])) if int(state.step) == 6 else ""
	for index in tabs.size(): tabs[index].disabled = not state.canEdit or index == int(state.step)
	back.disabled = not state.canBack; next.disabled = not state.canNext; next.visible = int(state.step) != 6
	finish.visible = int(state.step) == 6; finish.disabled = not state.canFinish; cancel.disabled = not state.canCancel
	var skill_row: HBoxContainer
	for item in state.items:
		if item.type == "text":
			var label := Label.new(); label.text = str(item.label); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if item.get("tag", "") == "skill":
				skill_row = HBoxContainer.new(); body.add_child(skill_row); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; skill_row.add_child(label)
			else: body.add_child(label)
			continue
		var id := int(item.controlId)
		var bound := view_id
		var target: Node = skill_row if item.get("tag", "") in ["skill-plus", "skill-minus"] and skill_row != null else body
		if item.type == "button":
			var button := Button.new(); button.text = str(item.label); button.focus_mode = Control.FOCUS_NONE; button.disabled = item.disabled
			if item.get("selected", false): button.modulate = Color(1, 0.85, 0.45)
			button.pressed.connect(func(): change(id, null, bound)); target.add_child(button); controls[id] = button
		elif item.type == "toggle":
			var check := CheckBox.new(); check.text = str(item.label); check.focus_mode = Control.FOCUS_NONE; check.button_pressed = item.value; check.disabled = item.disabled
			check.toggled.connect(func(value): change(id, value, bound)); body.add_child(check); controls[id] = check
		elif item.type == "select":
			var row := HBoxContainer.new(); body.add_child(row)
			var label := Label.new(); label.text = str(item.label); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
			var choice := OptionButton.new(); choice.focus_mode = Control.FOCUS_NONE; choice.disabled = item.disabled
			var offset := 1 if int(item.value) < 0 else 0
			if offset: choice.add_item("Choose…"); choice.set_item_disabled(0, true)
			for option in item.options: choice.add_item(str(option))
			choice.select(int(item.value) + offset if int(item.value) >= 0 else 0)
			choice.item_selected.connect(func(index): change(id, index - offset, bound)); row.add_child(choice); controls[id] = choice
		elif item.type == "input":
			var row := HBoxContainer.new(); body.add_child(row)
			var label := Label.new(); label.text = str(item.label); row.add_child(label)
			var input := LineEdit.new(); input.text = str(item.value); input.max_length = int(item.maxLength); input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input.text_submitted.connect(func(value): change(id, value, bound)); row.add_child(input); inputs[id] = input; controls[id] = input
			var apply := Button.new(); apply.text = "Apply"; apply.focus_mode = Control.FOCUS_NONE; apply.pressed.connect(func(): change(id, input.text, bound)); row.add_child(apply)
	scroll.set_deferred("scroll_vertical", int(positions.get(int(state.step), 0)))
	_clamp()
