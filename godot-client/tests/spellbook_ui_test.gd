extends SceneTree

var checks := 0
var failures: Array[String] = []
var sent: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func entry(id: int, spell: int, family: bool = false) -> Dictionary:
	return {"entryId": id, "key": "%s:%s" % [id, spell], "spellId": spell, "label": "Protection from Alignment with a very long caption" if family else "Light", "family": family, "uses": 2.0, "ready": true, "domain": false, "metamagic": 0, "slot": 0, "pending": false, "canCast": spell >= 0, "canDrag": spell >= 0 and not family}

func view(id: int) -> Dictionary:
	return {"kind": "spellbook-view", "viewId": id, "classIndex": 0, "level": 0, "metamagic": 0, "classes": [{"index": 0, "label": "Wizard"}], "metas": [{"value": 0, "label": "Normal"}], "prepared": true, "known": [entry(0, 10, true), entry(1, 100)], "memory": [entry(2, -1), entry(3, 100)], "family": [], "familyTitle": "", "usesLeft": 2}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var book := preload("res://systems/server_spellbook.gd").new()
	book.setup("")
	root.add_child(book)
	book.request.connect(func(message): sent.append(message))
	var quick := preload("res://systems/server_quickbar.gd").new()
	root.add_child(quick)
	quick.setup()
	quick.request.connect(func(message): sent.append(message))
	quick.spellbook_requested.connect(book.open)
	book.open()
	book.receive(view(10))
	check(book.visible and book.widgets.size() == 4, "Native book displays original-provider known and physical prepared rows together")
	book.widgets[0].pressed.emit()
	check(sent.back().kind == "book-family" and sent.back().entryId == 0 and book.widgets[0].payload.is_empty(), "Parent click asks for its variants and cannot begin a castable drag")
	var family := view(11)
	family.familyTitle = "Protection from Alignment"
	for id in 4:
		family.family.append(entry(4 + id, 20 + id))
	book.receive(family)
	check(book.widgets.size() == 8, "Native family panel retains all four children beside the parent book")
	var payload: Dictionary = book.widgets[4].payload
	check(payload == {"kind": "spell", "viewId": 11, "entryId": 4}, "Variant drag contains only its scoped entry identity")
	check(book.widgets[2]._can_drop_data(Vector2.ZERO, payload), "Physical prepared slot accepts a current native spell drag")
	book.widgets[2]._drop_data(Vector2.ZERO, payload)
	check(sent.back() == {"kind": "book-prepare", "viewId": 11, "entryId": 4, "destinationId": 2}, "Native drop sends the original physical destination independently of variant cast binding")
	book.widgets[4].pressed.emit()
	book.cast.pressed.emit()
	check(sent.back().kind == "book-activate" and sent.back().entryId == 4, "Selected child casts through typed native book input")
	var rows: Array = []
	for index in 36:
		rows.append({"index": index, "label": "Shortcut %s" % index, "uses": 123, "empty": index != 0, "enabled": index == 0})
	quick.receive({"kind": "quickbar-view", "quickbarId": 30, "rows": rows})
	check(quick.buttons.size() == 12 and quick.visible, "Only the current twelve slots are native controls; all three pages are retained")
	check(quick.buttons[5]._can_drop_data(Vector2.ZERO, payload), "Quickbar accepts a spell-family child drag")
	quick.buttons[5]._drop_data(Vector2.ZERO, payload)
	check(sent.back() == {"kind": "quickbar-assign", "viewId": 11, "entryId": 4, "index": 5}, "Variant quickbar assignment sends no trusted arbitrary binding")
	var old_button: Button = quick.buttons[0]
	var old_row: Button = book.widgets[4]
	quick.receive({"kind": "quickbar-view", "quickbarId": 31, "rows": rows})
	book.receive(view(12))
	var before := sent.size()
	old_button.pressed.emit()
	old_row.pressed.emit()
	check(sent.size() == before, "Retired native controls cannot invoke newly rebound entries with reused IDs")
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	quick.receive({"kind": "quickbar-icon", "quickbarId": 30, "index": 0, "image": png})
	book.receive({"kind": "book-icon", "viewId": 11, "entryId": 1, "image": png})
	check(quick.buttons[0].image.texture == null and book.widgets[1].image.texture == null, "Old async images cannot decorate replacement widgets")
	quick.receive({"kind": "quickbar-icon", "quickbarId": 31, "index": 12, "image": png})
	quick.render(1)
	check(quick.buttons[12].image.texture != null, "Off-page icons are retained when switching to that page")
	quick.render(0)
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	quick._input(f1)
	check(sent.back() == {"kind": "quickbar-activate", "quickbarId": 31, "index": 0}, "F1 delegates the visible page slot to the real shortcut owner")
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.pressed = true
	before = sent.size()
	quick._input(w)
	check(sent.size() == before and book.visible, "Simultaneous book and quickbar leave WASD available")
	var input := LineEdit.new()
	root.add_child(input)
	input.grab_focus()
	await process_frame
	before = sent.size()
	quick._input(f1)
	check(sent.size() == before, "Quickbar hotkeys do not consume text-entry input")
	input.release_focus()
	f1.ctrl_pressed = true
	f1.alt_pressed = true
	quick._input(f1)
	check(sent.size() == before, "Ctrl+Alt diagnostics remain independent of function-key shortcuts")
	book.widgets[1].pressed.emit()
	book.receive({"kind": "book-description", "viewId": 12, "entryId": 1, "rich": {"text": "Original spell description"}})
	var refreshed := view(14)
	refreshed.known[1].uses = 1.0
	book.receive(refreshed)
	check(book.selected_id == 1 and book.details.get_parsed_text() == "Original spell description", "Count refresh preserves the selected logical spell and readable description")
	check(book.widgets[1].counter.text == "1" and book.widgets[3].caption.text.contains("Ready"), "Integral JSON counts have no decimal suffix and physical readiness stays visible")
	book.close_requested.emit()
	book.hide()
	book.receive(view(15))
	check(not book.visible and book.view_id == 14, "A late book snapshot cannot reopen a user-closed window")
	for frame in 90:
		await process_frame
	var peak := Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
	check(peak < 1048576 and quick.buttons[0].size.y < 100, "Delayed tall icons remain fixed native slot geometry without a GUI message loop")
	book.reset()
	quick.reset()
	check(not book.visible and not quick.visible and quick.quickbar_id == -1 and book.view_id == -1, "World retirement clears native book and shortcut ownership")
	book.queue_free()
	quick.queue_free()
	input.queue_free()
	await process_frame
	var report := {"scope": "Authored native spellbook/family/preparation drop/quickbar/hotkey and delayed-icon ownership checks; not actual server acceptance", "checks": checks, "failures": failures, "queue_peak_bytes": peak}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
