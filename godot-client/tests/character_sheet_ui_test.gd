extends SceneTree
const Sheet = preload("res://systems/server_character_sheet.gd")
const Quickbar = preload("res://systems/server_quickbar.gd")
const Connection = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	root.size = Vector2i(1440, 960)
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/character-sheet-ui-fixture-v1.json"))
	data.pages[0].model.details[0].label = "Main Weapon: "
	var sheet := Sheet.new(); sheet.setup(""); root.add_child(sheet)
	var sent: Array = []; sheet.request.connect(func(row): sent.append(row))
	sheet.open(); sheet.receive(data.pages[0]); await process_frame
	check(sheet.visible and sent[0].kind == "sheet-open" and sent[0].page == 0, "Opening subscribes to the actual Character page and shows a native movable panel")
	check(sheet.find_child("Str_score", true, false).text == "20" and sheet.find_child("Str_modifier", true, false).text == "+5", "Native ability cells show received effective score and original display modifier")
	check(sheet.find_child("Str_score", true, false).get_theme_color("font_color") == Color.LIME_GREEN, "Positive received ability adjustment has native positive coloring")
	var text := ""
	for label in sheet.body.find_children("*", "RichTextLabel", true, false): text += label.get_parsed_text() + "\n"
	check(text.contains("HP: 9 / 12") and text.contains("AC: 17") and text.contains("Fortitude: 9") and text.contains("Reflex: 11") and text.contains("Will: 24"), "Native HP including temporary HP, AC and all three saves preserve received semantics/order")
	check(text.contains("Main Weapon: TLK 58291") and not text.contains("Main Weapon: :"), "Installed-style labels with trailing colon/whitespace render a single separator")
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8); image.fill(Color.GOLD)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	sheet.receive({"kind": "sheet-image", "viewId": -1, "key": "portrait", "image": png})
	check(sheet.image_nodes.portrait.texture == null, "A retired portrait cannot decorate this record")
	sheet.receive({"kind": "sheet-image", "viewId": sheet.view_id, "key": "portrait", "image": png})
	check(sheet.image_nodes.portrait.texture != null and sheet.image_nodes.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Native original portrait transport preserves aspect ratio")
	sheet.tabs[1].pressed.emit()
	check(sent.back().kind == "sheet-page" and sent.back().page == 1, "Skills tab uses an actual scoped page request")
	sheet.receive(data.pages[1]); await process_frame
	check(sheet.entry_nodes.size() == 2, "Only server-visible skill rows are displayed")
	sheet.select_entry(0)
	check(sheet.description.get_parsed_text().contains("[b]literal[/b]") and not sheet.description.bbcode_enabled, "Server descriptions retain literal markup with BBCode disabled")
	var row = sheet.entry_nodes[0]
	var drag: Dictionary = row.drag_data()
	check(drag.kind == "record-entry" and not drag.has("binding") and sheet.can_drag(drag), "A native entry drag carries only scoped private handles")
	check(sheet.entry_nodes[1].drag_data() == null, "Zero-rank skill cannot create an actionable drag")
	var bar := Quickbar.new(); root.add_child(bar); bar.setup(); bar.record_valid = sheet.can_drag; bar.request.connect(func(value): sent.append(value))
	var rows: Array = []
	for index in 36: rows.append({"label": "Empty", "uses": null, "empty": true, "enabled": false})
	bar.receive({"kind": "quickbar-view", "quickbarId": 1, "rows": rows}); bar.render(2)
	check(bar.buttons[34].accepts.call(drag), "Native quickbar accepts a live record entry")
	bar.buttons[34].dropped.emit(drag)
	check(sent.back().kind == "sheet-assign" and sent.back().index == 34 and sent.back().entryId == 0, "Record drop uses its own bounded assignment path")
	sheet.receive(data.pages[2])
	check(row.drag_data() == null and not bar.buttons[34].accepts.call(drag), "Old controls and drags retire when the record page changes")
	sheet.select_entry(0)
	check(sheet.description.get_parsed_text() == "Authored feat description", "Feat selection displays the active rule-table description")
	sheet.position = Vector2(35, 45); sheet.close_sheet(); sheet.receive({"kind": "sheet-closed"}); sheet.open(); sheet.receive(data.pages[2])
	check(sheet.position == Vector2(35, 45) and sheet.page == 2, "Reopening preserves native window position and selected tab")
	var current: Dictionary = sheet.entry_nodes[0].drag_data()
	sheet.reset()
	check(not sheet.visible and not sheet.can_drag(current) and sheet.image_nodes.is_empty() and sheet.state.is_empty(), "World reset retires entry ownership and native image controls")
	await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native sheet values, rich text, input, stale images/drags, quickbar routing and window lifecycle; live server acceptance separate"}, "\t")); file.close()
	sheet.free(); bar.free(); quit(0 if failures.is_empty() else 1)
