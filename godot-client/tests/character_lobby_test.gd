extends SceneTree

const Lobby = preload("res://systems/character_lobby.gd")
var checks := 0
var failures: Array[String] = []
var messages: Array = []
var creation_requests := 0

func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ui := Lobby.new()
	root.add_child(ui)
	ui.request.connect(func(message): messages.append(message))
	ui.creation_requested.connect(func(): creation_requests += 1)
	expect(ui.join_button.disabled, "No login before authenticated backend readiness")
	ui.apply_state({"connection": 0, "state": {"phase": "menu", "canJoin": true}})
	ui.join_button.pressed.emit()
	expect(messages.back() == {"kind": "lobby-join", "connection": 0}, "Native Connect sends a connection-scoped request")
	var selected := {"phase": "character-selection", "canJoin": false, "canSelect": true, "connected": true, "selected": "vault:one", "choices": [{"key": "vault:one", "label": "Saved character"}, {"key": "server:17:pc", "label": "Server character"}], "preview": {"firstName": {"text": "Nibs"}, "lastName": {"text": "Test"}, "abilities": {"Str": 12}, "currentHitPoints": 10, "hitPoints": 15, "classes": [{"id": 3, "level": 2}], "feats": [1, 2], "spells": [1]}}
	ui.apply_state({"connection": 1, "state": selected})
	expect(ui.choices.item_count == 2 and ui.choices.get_item_text(1) == "Server character", "Native selector renders both advertised character sources")
	expect(ui.preview.text.contains("Nibs Test") and ui.preview.text.contains("Str: 12") and ui.preview.text.contains("10 / 15"), "Preview renders received identity and stats")
	expect(ui.create_button.disabled, "Create remains locked until admitted resources are ready")
	selected["canCreate"] = true; ui.apply_state({"connection":1,"state":selected}); ui.create_button.pressed.emit()
	expect(creation_requests == 1 and not ui.panel.visible, "Ready Create button opens the native creator and hides the vault chooser")
	ui.apply_state({"connection":1,"state":selected})
	ui.choices.item_selected.emit(1)
	expect(messages.back() == {"kind": "lobby-choose", "connection": 1, "key": "server:17:pc"}, "Selection sends catalog identity, never a path")
	ui.play_button.pressed.emit()
	expect(messages.back() == {"kind": "lobby-play", "connection": 1, "key": "vault:one"}, "Play uses the authoritative selected key")
	expect(ui.save_on_disconnect.button_pressed, "Save on explicit disconnect defaults on")
	ui.disconnect_button.pressed.emit()
	expect(not messages.back().saveCharacter and messages.back().kind == "lobby-disconnect", "Disconnect before entering the world does not export an unavailable character")
	ui.apply_state({"connection": 1, "state": {"phase": "playing", "connected": true, "selected": "vault:one"}})
	expect(not ui.panel.visible and not ui.export_button.disabled, "Playing closes the chooser and enables character export")
	expect(not ui.blocks_pointer(root.get_visible_rect().size-Vector2(48,32)), "The removed bottom-right shortcut leaves no invisible input blocker")
	ui.panel.show() # Explicit Multiplayer selection in Main Menu reopens the chooser.
	ui.apply_state({"connection": 1, "state": {"phase": "playing", "connected": true, "selected": "vault:one"}})
	expect(ui.panel.visible, "Repeated playing states preserve an intentionally open multiplayer menu")
	expect(ui.blocks_pointer(ui.panel.global_position + Vector2(10, 10)) and not ui.blocks_pointer(Vector2(2, 900)), "Only native menu rectangles block world input")
	ui.apply_state({"connection": 2, "state": {"phase": "menu", "canJoin": true, "error": "Export failed"}})
	expect(ui.panel.visible and ui.play_button.disabled and ui.message.text.contains("Export failed"), "Disconnected/error state clears old selection and keeps error readable")
	ui.preferred_auto_key = "vault:one"
	ui.last_auto_choose = -1
	ui.last_auto_play = -1
	ui.apply_state({"connection": 3, "auto": true, "state": selected})
	expect(messages.back() == {"kind": "lobby-choose", "connection": 3, "key": "vault:one"}, "Lifecycle regression chooses the saved catalog entry instead of a hardwired wizard")
	ui.apply_state({"connection": 3, "auto": true, "state": selected})
	expect(messages.back() == {"kind": "lobby-play", "connection": 3, "key": "vault:one"}, "Saved-character Play also uses the native UI route")
	ui.apply_state({"connection":4,"state":{"phase":"connecting","busy":true,"canCancelJoin":true,"endpoint":{"host":"127.0.0.1","port":5121}}})
	expect(ui.cancel_button.visible and not ui.cancel_button.disabled and ui.join_button.disabled, "Pending login exposes Cancel while another Connect remains locked")
	ui.cancel_button.pressed.emit()
	expect(messages.back() == {"kind":"lobby-cancel-join","connection":4}, "Cancel uses the pending connection owner before an area exists")
	ui.apply_state({"connection":5,"state":{"phase":"menu","canJoin":true}})
	expect(not ui.cancel_button.visible and not ui.join_button.disabled, "Retired login removes Cancel and permits a fresh connection")
	ui.free()
	var result := {"success":failures.is_empty(),"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Native Godot character-lobby UI and scoped requests; no live server or performance claim"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if file == null:
				quit(1)
				return
			file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
