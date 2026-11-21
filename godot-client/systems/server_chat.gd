extends PanelContainer

signal request(message: Dictionary)
var native_skin
const Text = preload("res://systems/server_text.gd")
var messages: RichTextLabel
var system_messages: RichTextLabel
var entry: LineEdit
var recipient: LineEdit
var channel: OptionButton
var rows: Array[Dictionary] = []
var history_limit:=200
var sequence:=0

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
	if native_skin!=null: native_skin.submit(value); return
	if value.strip_edges().is_empty():
		return
	var message := {"kind": "chat", "channel": channel.get_selected_id(), "text": value}
	var tell:=RegEx.new(); tell.compile('^/t\\s+(?:"([^"]+)"|(\\S+))\\s+(.*)$'); var match_tell:=tell.search(value)
	if match_tell!=null:
		message.channel=4; message.recipient=match_tell.get_string(1) if not match_tell.get_string(1).is_empty() else match_tell.get_string(2); message.text=match_tell.get_string(3)
		if str(message.text).strip_edges().is_empty(): return
	if message.channel == 4:
		if not message.has("recipient") and recipient.text.strip_edges().is_empty():
			append_message({"system": true, "text": "Enter a Tell recipient first."})
			return
		if not message.has("recipient"): message.recipient = recipient.text
	request.emit(message)
	entry.clear()
	entry.release_focus()
func prime_tell(name: String) -> void:
	if native_skin!=null: native_skin.prime_tell(name); return
	channel.select(0); recipient.hide(); entry.text='/t "'+name+'" '; entry.grab_focus(); entry.caret_column=entry.text.length()
func prime_player(account: String) -> void:
	if native_skin!=null: native_skin.prime_player(account)

func reset() -> void:
	rows.clear()
	messages.clear()
	system_messages.clear()
	entry.clear()
	recipient.clear()
	channel.select(0)
	recipient.hide()
	if native_skin!=null: native_skin.reset()

func append_message(message: Dictionary) -> void:
	var row := message.duplicate(true)
	sequence+=1; row.chat_sequence=sequence
	if not row.has("received_at"): row.received_at=Time.get_time_string_from_system()
	row["system"] = row.get("system", false) or int(row.get("channel", 0)) in [5, 15]
	rows.append(row)
	var indices: Array[int] = []
	for index in rows.size():
		if rows[index].system == row.system:
			indices.append(index)
	if indices.size() > history_limit:
		rows.remove_at(indices[0])
	if native_skin!=null: native_skin.receive_row(row); return
	# Rebuild only on a received message; history is bounded independently.
	messages.clear()
	system_messages.clear()
	for item in rows:
		var target := system_messages if item.system else messages
		var name: Dictionary = item.get("name", {})
		if not str(name.get("text", "")).is_empty() or item.get("nativeNameResolved")==true and not item.system:
			Text.append(target, name, Color(0.65, 0.65, 1.0))
			Text.append(target, {"text": ": "})
		var color := str(item.get("color", ""))
		var fallback := Color.html(color) if color.length() == 7 and color.begins_with("#") and color.substr(1).is_valid_hex_number(false) else Color(0.9, 0.88, 0.78)
		Text.append(target, item.get("rich", {"text": item.get("text", "")}), fallback)
		Text.append(target, {"text": "\n"})

func blocks_pointer(point: Vector2) -> bool:
	return native_skin.blocks_pointer(point) if native_skin!=null else visible and get_global_rect().has_point(point)

func trim_history() -> void:
	var counts: Dictionary={false:0,true:0}
	for index in range(rows.size()-1,-1,-1):
		var system:=bool(rows[index].get("system",false)); counts[system]+=1
		if int(counts[system])>history_limit: rows.remove_at(index)
