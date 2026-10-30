extends SceneTree

const Text = preload("res://systems/server_text.gd")
const Dialog = preload("res://systems/server_conversation.gd")
const Examine = preload("res://systems/server_examine.gd")
const Chat = preload("res://systems/server_chat.gd")
const Connection = preload("res://systems/local_connection.gd")
const Main = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var sent: Array = []
var output := ""

class Counter extends Node:
	var updates := 0
	func update_metrics() -> void:
		updates += 1

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)
		push_error(name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var rich := {"text": "Attuned to Fire\n[b]literal[/b] <img>", "spans": [{"text": "Attuned to ", "color": "#87ceeb"}, {"text": "Fire", "color": "#01ff01"}, {"text": "\n[b]literal[/b] <img>", "color": null}]}
	var label := Text.label(rich)
	root.add_child(label)
	check(not label.bbcode_enabled and label.get_parsed_text() == rich.text, "Server text is literal; nested color spans retain line breaks without interpreting markup")
	check(label.get_theme_constant("outline_size") >= 3 and label.get_theme_color("font_outline_color") == Color.BLACK, "Bright server text has a black letter outline")
	Text.set_text(label, {"spans": [{"text": "safe", "color": "url(server)"}]})
	check(label.get_parsed_text() == "safe", "Invalid style is ignored without losing literal text")
	var chat := Chat.new()
	chat.setup()
	root.add_child(chat)
	chat.request.connect(func(message): sent.append(message))
	chat.submit("draft")
	check(sent.back().channel == 1 and chat.rows.is_empty(), "Talk sends the original channel request and never echoes an unconfirmed draft")
	chat.channel.select(5)
	chat.submit("tell")
	check(sent.size() == 1, "Tell requires a recipient")
	chat.recipient.text = "Ada"
	chat.submit("tell")
	check(sent.back().channel == 4 and sent.back().recipient == "Ada", "Tell passes the chosen recipient without inventing an object ID")
	chat.reset()
	chat.append_message({"name": {"text": "Ada"}, "rich": rich, "channel": 1})
	check(chat.messages.get_parsed_text() == "Ada: " + rich.text + "\n", "Native history includes the resolved speaker and complete colored message")
	for i in 205:
		chat.append_message({"system": true, "text": "system%s" % i})
	check(chat.rows.size() == 201 and chat.messages.get_parsed_text().contains("Attuned to Fire"), "System history caps independently at 200 without removing ordinary chat")
	check(not chat.system_messages.get_parsed_text().contains("system0\n") and chat.system_messages.get_parsed_text().contains("system204\n"), "History retires its oldest received rows")
	var dialog := Dialog.new()
	dialog.setup("")
	root.add_child(dialog)
	dialog.request.connect(func(message): sent.append(message))
	dialog.present({"kind": "dialog-replies", "entryId": 1, "replies": []})
	check(dialog.entry_id == -1, "Replies cannot create a conversation without a server entry")
	dialog.present({"kind": "dialog-entry", "rich": rich})
	dialog.present({"kind": "dialog-replies", "entryId": 4294967294, "replies": [{"id": 4294967293, "rich": {"text": "Choose"}}, {"id": 3, "rich": {"text": "A long colored choice ".repeat(15), "spans": [{"text": "A long colored choice ".repeat(15), "color": "#ffff01"}]}}]})
	await process_frame
	await process_frame
	check(dialog.body.get_parsed_text() == rich.text and dialog.replies.get_child_count() == 2, "Native conversation renders the complete entry and all server choices")
	var long_button: Button = dialog.replies.get_child(1)
	check(long_button.custom_minimum_size.y > 40, "Wrapped choice text expands its hit target instead of clipping the bottom half")
	var count := sent.size()
	dialog.choose(77)
	check(sent.size() == count, "An unadvertised reply is rejected")
	dialog.choose(4294967293)
	check(sent.back() == {"kind": "reply", "entryId": 4294967294, "replyId": 4294967293, "abort": false}, "Full unsigned entry/reply IDs survive the native button event")
	dialog.choose(3)
	check(sent.size() == count + 1 and long_button.disabled, "A pending reply disables every choice and prevents duplicate sends")
	dialog.present({"kind": "dialog-error", "entryId": 4294967294})
	check(not long_button.disabled and not dialog.pending, "A failed send allows retry")
	dialog.choose(4294967295, true)
	check(sent.back().abort and sent.back().replyId == 4294967295, "End conversation sends the native abort sentinel")
	dialog.present({"kind": "dialog-close"})
	check(not dialog.visible and dialog.entry_id == -1 and dialog.replies.get_child_count() == 0, "Server close revokes all old reply ownership")
	var examine := Examine.new()
	examine.setup("")
	root.add_child(examine)
	examine.present({"targetId": 4294967295, "revision": 1, "name": {"text": "Ada"}, "description": rich})
	check(examine.visible and examine.body.get_child(0).get_parsed_text() == rich.text, "Examine keeps the server-authored attunement line and formatting")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var portrait := {"targetId": 4294967295, "revision": 1, "image": "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())}
	check(examine.set_portrait(portrait) and examine.portrait.visible, "Original portrait payload can be displayed independently of examination text")
	var stale := portrait.duplicate()
	stale.revision = 0
	check(not examine.set_portrait(stale), "A delayed portrait cannot replace a newer examination")
	examine.hide()
	check(not examine.set_portrait(portrait), "A portrait completion cannot reopen a user-closed menu")
	examine.present({"targetId": 2, "revision": 2, "name": {"text": "Object"}, "description": {"text": "Server description only"}})
	check(examine.body.get_child_count() == 1 and not examine.body.get_child(0).get_parsed_text().contains("Attuned"), "Examine never manufactures an undisclosed attunement or creature stat")
	dialog.present({"kind": "dialog-entry", "rich": {"text": "Entry"}})
	dialog.present({"kind": "dialog-replies", "entryId": 2, "replies": [{"id": 9, "rich": {"text": "Reply"}}]})
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	count = sent.size()
	chat.entry.grab_focus()
	dialog._unhandled_key_input(key)
	check(sent.size() == count, "Typing a number in chat cannot select a dialogue reply")
	chat.entry.release_focus()
	examine.move_to_front()
	dialog._unhandled_key_input(key)
	check(sent.size() == count, "A covered conversation does not steal another menu's shortcuts")
	examine.hide()
	dialog._unhandled_key_input(key)
	check(sent.back().kind == "reply" and sent.back().replyId == 9, "The front conversation accepts a numeric shortcut")
	dialog.present({"kind": "dialog-error", "entryId": 4294967294})
	check(dialog.pending, "A stale reply error cannot unlock a newer conversation entry")
	dialog.present({"kind": "dialog-error", "entryId": 2})
	dialog.heading.get_parent().get_child(1).pressed.emit()
	check(dialog.visible and dialog.pending and sent.back().abort, "Title-bar close requests server abort and waits for its close confirmation")
	dialog.present({"kind": "dialog-error", "entryId": 2})
	check(dialog.visible and not dialog.pending, "Failed abort remains visible and retryable")
	var host := Main.new()
	root.add_child(host)
	var bridge := Connection.new()
	host.add_child(bridge)
	bridge.set_process(false)
	bridge.owner_scene = host
	bridge._make_ui()
	bridge.connection = 1
	bridge.world_scope.reset(1)
	bridge.receive({"kind": "loading", "connection": 1, "areaId": 9, "generation": 3, "transferId": 1, "text": "Loading"})
	bridge.area_id = 9
	bridge.generation = 3
	var entry_message := {"kind": "dialog-entry", "connection": 1, "areaId": 9, "generation": 3, "rich": rich}
	bridge.receive(entry_message)
	check(bridge.dialog_panel.visible, "Matching live dialogue reaches the native panel")
	bridge.receive({"kind": "dialog-close", "connection": 1, "areaId": 8, "generation": 3})
	check(bridge.dialog_panel.visible, "Old-area close cannot hide a current conversation even with matching generation")
	var wrong_connection := entry_message.duplicate()
	wrong_connection.connection = 0
	wrong_connection.rich = {"text": "retired"}
	bridge.receive(wrong_connection)
	check(bridge.dialog_panel.body.get_parsed_text() == rich.text, "Old-connection text cannot overwrite a current panel")
	bridge.receive({"kind": "examine", "connection": 1, "areaId": 9, "generation": 3, "targetId": 2, "revision": 1, "description": rich})
	bridge.receive({"kind": "floating", "connection": 1, "areaId": 9, "generation": 3, "objectId": 2, "rich": rich})
	check(bridge.examine_panel.visible and bridge.floating.entries.size() == 1, "Examine and feedback prompts coexist with conversation")
	bridge.receive({"kind": "loading", "connection": 1, "areaId": 10, "generation": 4, "transferId": 2, "text": "Next area"})
	check(not bridge.dialog_panel.visible and not bridge.examine_panel.visible and bridge.floating.entries.is_empty(), "Area retirement clears all gameplay presentation owners")
	var counter := Counter.new()
	host.add_child(counter)
	host.native_hud = counter
	var view := Camera3D.new()
	host.add_child(view)
	host.camera = view
	host.warmup = 120
	host._process(0.016)
	check(counter.updates == 1, "FPS HUD updates immediately while benchmark samples are still warming up")
	host.native_hud = null
	host.camera = null
	for node in [label, chat, dialog, examine, host]:
		node.queue_free()
	await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"success": failures.is_empty(), "scope": "Authored native rich-text/menu routing, disclosure, replies, stale completion and cleanup; not live-server, pixel/font or FPS acceptance", "checks": checks, "failures": failures}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures.size(), "report": output}))
	quit(0 if failures.is_empty() else 1)
