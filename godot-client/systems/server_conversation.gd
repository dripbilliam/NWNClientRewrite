extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal rendered(kind: String)
const Text = preload("res://systems/server_text.gd")
const GameInput=preload("res://systems/native_data/game_input.gd")
var body: RichTextLabel
var replies: VBoxContainer
var end_button: Button
var entry_id := -1
var pending := false
var opened := false
var reply_ids: Array[int] = []
var reply_available: Array[bool] = []
var rows: Array=[]
var serial:=0
var dialog_generation:=0
var speaker_id:=-1
var native_skin
var entry_rich: Dictionary={}
var failure_notice: RichTextLabel
var reply_failure:=""

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	close_hides = false
	configure("Conversation", "local-dialog", Vector2(550, 200), storage)
	body = Text.label({}, 540)
	body.custom_minimum_size.y = 75
	content.add_child(body)
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(560, 280)
	content.add_child(scroller)
	replies = VBoxContainer.new()
	replies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(replies)
	end_button = Button.new()
	end_button.text = "End conversation"
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.pressed.connect(func(): choose(4294967295, true))
	content.add_child(end_button)
	failure_notice=Text.label({},540); failure_notice.hide(); content.add_child(failure_notice)
	close_requested.connect(func(): choose(4294967295, true))
	reset()

func clear_replies() -> void:
	for child in replies.get_children():
		replies.remove_child(child)
		child.queue_free()
	reply_ids.clear()
	reply_available.clear(); rows.clear()

func reset() -> void:
	serial+=1; speaker_id=-1
	dialog_generation+=1
	reply_failure=""
	opened = false
	entry_id = -1
	pending = false
	clear_replies()
	body.clear()
	entry_rich.clear()
	if is_instance_valid(failure_notice): failure_notice.hide()
	hide()

func present_if_ready() -> void:
	if not opened: hide(); return
	if is_instance_valid(native_skin):
		var failure: String=native_skin.art_failure()
		if not failure.is_empty():
			window_column.show()
			if is_instance_valid(native_skin.stage): native_skin.stage.hide()
			failure_notice.text="Original conversation unavailable: "+failure
			failure_notice.show()
		elif not native_skin.display_ready(): hide(); return
		else:
			if reply_failure.is_empty(): failure_notice.hide(); window_column.hide()
			else: failure_notice.text=reply_failure; failure_notice.show(); window_column.show()
			if is_instance_valid(native_skin.stage): native_skin.stage.show()
	show(); move_to_front()

func present(message: Dictionary) -> void:
	match message.kind:
		"dialog-close": reset()
		"dialog-entry":
			serial+=1; speaker_id=int(message.get("speakerId",-1))
			dialog_generation+=1
			reply_failure=""
			opened = true
			entry_id = -1
			pending = false
			end_button.disabled = true
			clear_replies()
			entry_rich=message.get("rich", {"text": message.get("text", "")}).duplicate(true)
			Text.set_text(body, entry_rich)
			present_if_ready()
			rendered.emit(str(message.kind))
		"dialog-replies":
			if not opened:
				return
			clear_replies()
			serial+=1
			entry_id = int(message.entryId)
			pending = false
			end_button.disabled = false
			for row in message.replies:
				var reply_id := int(row.id)
				var available:=bool(row.get("available",true)); var bound:=serial; var index:=reply_ids.size()
				reply_ids.append(reply_id)
				reply_available.append(available); rows.append(row.duplicate(true))
				var button := Text.reply_button(row.get("rich", {"text": row.get("text", "")}), reply_ids.size())
				button.disabled=not available
				var handle: WeakRef=weakref(button)
				button.pressed.connect(func():
					if bound==serial and index<reply_ids.size() and reply_available[index] and replies.get_child(index)==handle.get_ref(): choose(reply_id))
				replies.add_child(button)
			rendered.emit(str(message.kind))
		"dialog-error":
			if int(message.get("entryId", -1)) != entry_id or message.has("dialogGeneration") and int(message.dialogGeneration)!=dialog_generation:
				return
			pending = false
			for index in replies.get_child_count(): replies.get_child(index).disabled=false
			end_button.disabled = entry_id < 0
			reply_failure=str(message.get("reason",message.get("error","Dialog reply failed")))
			failure_notice.text=reply_failure
			failure_notice.show()
			window_column.show()
			rendered.emit(str(message.kind))

func available(reply_id: int) -> bool:
	for index in reply_ids.size():
		if reply_ids[index]==reply_id and reply_available[index]: return true
	return false
func choose(reply_id: int, abort: bool = false) -> void:
	if not opened or entry_id < 0 or pending or not abort and not available(reply_id):
		return
	pending = true
	for button in replies.get_children():
		button.disabled = true
	end_button.disabled = true
	rendered.emit("dialog-pending")
	request.emit({"kind": "reply", "entryId": entry_id, "replyId": reply_id, "abort": abort, "dialogGeneration": dialog_generation})

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if GameInput.is_text_entry(focus):
		return
	for sibling in get_parent().get_children():
		if sibling is PanelContainer and sibling.visible and sibling.get_index() > get_index():
			return
	if event.keycode == KEY_ESCAPE:
		choose(4294967295, true)
		get_viewport().set_input_as_handled()
	else:
		var index: int = -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_9 and not event.shift_pressed:
			index = int(event.keycode) - KEY_1
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
			index = int(event.keycode) - KEY_KP_1
		if index >= 0 and index < reply_ids.size() and reply_available[index]:
			choose(reply_ids[index])
			get_viewport().set_input_as_handled()
