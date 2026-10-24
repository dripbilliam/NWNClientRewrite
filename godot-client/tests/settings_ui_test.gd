extends SceneTree
const Options = preload("res://systems/native_options.gd")
const MainMenu = preload("res://systems/native_main_menu.gd")
const Debug = preload("res://systems/native_debug_window.gd")
const Client = preload("res://systems/local_connection.gd")
class FakeClient extends Node:
	var owner_scene = null
	var connection := 1
	var area_id := 7
	var generation := 2
	var controlled_id := 9
	var targeting := {"mode":{}}
	var radial := {"active":false}
var checks := 0
var failures: Array = []
var requests: Array = []
var trace: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; root.push_input(motion,true); await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point; event.global_position = point; root.push_input(event, true); await process_frame
func present(setup, view: int, locked: bool, rows: Array = []) -> void:
	var id: int = setup.request_id
	setup.receive({"kind":"settings-begin","requestId":id,"viewId":view,"count":rows.size(),"status":{"modsDirectory":"C:/authored/mods","defaultModsDirectory":"C:/authored/default","hasSavedCdKey":true,"protectedStorageAvailable":true,"resourcesLocked":locked}})
	setup.receive({"kind":"settings-mods","requestId":id,"viewId":view,"rows":rows}); setup.receive({"kind":"settings-commit","requestId":id,"viewId":view})
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1000, 850)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var options := Options.new(); layer.add_child(options); options.setup("", output + ".cfg"); options.request.connect(func(value): requests.append(value.duplicate(true)))
	options.show(); options.move_to_front(); await process_frame
	check(options.installation.wanted and requests.back().operation == "open", "Options opens the connection-scoped native settings screen without an area")
	var setup = options.installation; options.tabs.current_tab = 1
	present(setup, 1, false, [{"entryId":0,"id":"11","label":"Authored mod","directory":"C:/authored/mods/11","enabled":true},{"entryId":1,"id":"22","label":"Portraits","directory":"C:/authored/mods/22","enabled":false}]); await process_frame; await process_frame
	check(setup.mods.get_root().get_child_count() == 2 and setup.key.secret and setup.key.max_length == 41, "Native mod rows retain Boolean states and the key editor is masked and bounded")
	check(not setup.browse.disabled and not setup.defaults.disabled and setup.folder.text == "C:/authored/mods" and setup.folder.focus_mode == Control.FOCUS_NONE, "Folder display exposes browsing/defaults without taking WASD text focus")
	setup.key.text = "private authored draft"
	trace.append({"saveRect":str(setup.save_button.get_global_rect()),"panelRect":str(options.get_global_rect()),"disabled":setup.save_button.disabled,"requests":requests.size()})
	await click(setup.save_button.get_global_rect().get_center())
	trace.append({"saveRect":str(setup.save_button.get_global_rect()),"empty":setup.key.text.is_empty(),"operation":requests.back().operation,"requests":requests.size(),"savedDisabled":requests.back().get("values",{}).get("disabled"),"draftMatches":requests.back().get("values",{}).get("cdKey") == "private authored draft"})
	check(setup.key.text.is_empty() and requests.back().operation == "save" and requests.back().values.disabled == [1] and requests.back().values.cdKey == "private authored draft", "Actual Save click sends only unchecked private handles and clears the native key draft immediately")
	present(setup, 2, true)
	check(setup.browse.disabled and setup.defaults.disabled and setup.mods.get_root().get_child_count() == 1, "An active connection locks mod resource changes and handles an empty catalog")
	setup.key.text = "replacement draft"; setup.save_settings()
	check(not requests.back().values.has("disabled") and setup.key.text.is_empty(), "A connected key-only save does not implicitly change mods")
	present(setup, 3, false)
	setup.remove_key.button_pressed = true; setup.save_settings(); check(requests.back().values.get("removeCdKey", false) and requests.back().values.disabled.is_empty(), "Empty mod catalogs still permit explicit key removal")
	present(setup, 4, false); setup.key.text = "unsaved secret"; options.hide(); await process_frame
	check(setup.key.text.is_empty() and not setup.wanted and requests.back().operation == "close", "Closing Options discards private input and retires the settings view")
	setup.receive({"kind":"settings-notice","requestId":setup.request_id - 1,"text":"late"}); check(setup.notice.text != "late", "Late metadata cannot repopulate a closed native settings view")
	var changed: Array = []; options.debug_preference.connect(func(value): changed.append(value)); options.debug_toggle.button_pressed = true; options.debug_closed()
	check(changed == [true] and not options.debug_toggle.button_pressed and not options.debug_enabled, "Closing the debug window synchronizes the persisted Options toggle")
	var loaded := ConfigFile.new(); loaded.load(output + ".cfg"); check(not loaded.get_value("presentation", "debug_window", true), "Debug-window close persists without storing any key editor contents")
	var menu := MainMenu.new(); root.add_child(menu); menu.open(false); await process_frame; await process_frame
	check(menu.panel.visible and not menu.resume.visible and menu.blocks_pointer(menu.panel.get_global_rect().get_center()), "Main Menu opens independently of multiplayer and blocks only its actual panel")
	var opened := [false]; menu.options_requested.connect(func(): opened[0] = true); menu.choose("options"); check(opened[0] and not menu.panel.visible, "Main Menu Options routes to the existing native preferences")
	var fake := FakeClient.new(); root.add_child(fake); var debug := Debug.new(); debug.visible = false; root.add_child(debug); debug.setup(fake, "")
	debug.show(); await process_frame; check(debug.tabs.get_tab_count() == 5 and debug.visible and not debug.exclusive, "Debug diagnostics use a separate nonmodal Window with five tabs")
	check(root.gui_embed_subwindows and debug.force_native and not debug.is_embedded(), "Diagnostics stays an OS window while ordinary gameplay popups remain embedded")
	debug.receive({"snapshot":{"diagnostics":[{"code":"authored","reason":"test"}],"gameplay":{"phase":"menu"},"resources":{"nativeAreaAdmissions":0}}})
	for index in 5: debug.tabs.current_tab = index; debug.refresh(); check(not debug.bodies[index].text.is_empty(), "Debug tab %s has native content" % index)
	debug.hide(); var updates: int = debug.updates; await create_timer(0.6).timeout; check(debug.updates == updates, "Hidden debug window stops sampling and formatting diagnostics")
	debug.free(); fake.free(); menu.free(); options.free(); layer.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"trace":trace},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
