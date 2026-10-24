extends PanelContainer

signal request(message: Dictionary)
const Text = preload("res://systems/server_text.gd")
var messages: RichTextLabel
var system_messages: RichTextLabel
var entry: LineEdit
var recipient: LineEdit
var channel: OptionButton
var rows: Array[Dictionary] = []

func setup() -> void:
	custom_minimum_size = Vector2(520, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.02, 0.92)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	messages = Text.label({})
	messages.fit_content = false
	messages.custom_minimum_size = Vector2(510, 110)
	messages.scroll_active = true
	messages.scroll_following = true
	messages.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(messages)
	system_messages = Text.label({})
	system_messages.fit_content = false
	system_messages.custom_minimum_size = Vector2(510, 90)
	system_messages.scroll_active = true
	system_messages.scroll_following = true
	system_messages.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(system_messages)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	channel = OptionButton.new()
	channel.focus_mode = Control.FOCUS_NONE
	for row in [[1, "Talk"], [2, "Shout"], [3, "Whisper"], [6, "Party"], [14, "DM"], [4, "Tell"]]:
		channel.add_item(row[1], row[0])
	channel.item_selected.connect(func(_index): recipient.visible = channel.get_selected_id() == 4)
	controls.add_child(channel)
	recipient = LineEdit.new()
	recipient.placeholder_text = "Recipient first name"
	recipient.custom_minimum_size.x = 150
	recipient.hide()
	controls.add_child(recipient)
	entry = LineEdit.new()
	entry.placeholder_text = "Enter to chat"
	entry.max_length = 1000
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(entry)
	entry.text_submitted.connect(submit)

func submit(value: String) -> void:
	if value.strip_edges().is_empty():
		return
	var message := {"kind": "chat", "channel": channel.get_selected_id(), "text": value}
	if message.channel == 4:
		if recipient.text.strip_edges().is_empty():
			append_message({"system": true, "text": "Enter a Tell recipient first."})
			return
		message.recipient = recipient.text
	request.emit(message)
	entry.clear()
	entry.release_focus()

func reset() -> void:
	rows.clear()
	messages.clear()
	system_messages.clear()
	entry.clear()
	recipient.clear()
	channel.select(0)
	recipient.hide()

func append_message(message: Dictionary) -> void:
	var row := message.duplicate(true)
	row["system"] = row.get("system", false) or int(row.get("channel", 0)) in [5, 15]
	rows.append(row)
	var indices: Array[int] = []
	for index in rows.size():
		if rows[index].system == row.system:
			indices.append(index)
	if indices.size() > 200:
		rows.remove_at(indices[0])
	# Rebuild only on a received message; history is bounded independently.
	messages.clear()
	system_messages.clear()
	for item in rows:
		var target := system_messages if item.system else messages
		var name: Dictionary = item.get("name", {})
		if not str(name.get("text", "")).is_empty():
			Text.append(target, name, Color(0.65, 0.65, 1.0))
			Text.append(target, {"text": ": "})
		var color := str(item.get("color", ""))
		var fallback := Color.html(color) if color.length() == 7 and color.begins_with("#") and color.substr(1).is_valid_hex_number(false) else Color(0.9, 0.88, 0.78)
		Text.append(target, item.get("rich", {"text": item.get("text", "")}), fallback)
		Text.append(target, {"text": "\n"})
