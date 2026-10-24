extends SceneTree
const Creator = preload("res://systems/server_creation.gd")
const Client = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array = []
var requests: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point; event.global_position = point; root.push_input(event, true); await process_frame
func present(ui, view: int, step: int, items: Array, extra: Dictionary = {}) -> void:
	var state := {"kind":"creation-begin","viewId":view,"step":step,"steps":["Gender","Race","Portrait","Class","Alignment","Package","Abilities","Domains","Skills","Feats","Spells","Appearance","Voice","Name","Review"],"phase":"editing","status":"","errors":[],"canEdit":true,"canFinish":false,"canRecommend":true,"canCancel":true,"count":items.size()}; state.merge(extra, true)
	ui.receive(state); ui.receive({"kind":"creation-items","viewId":view,"items":items}); ui.receive({"kind":"creation-commit","viewId":view})
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1200, 850)
	var ui := Creator.new(); root.add_child(ui); ui.request.connect(func(value): requests.append(value.duplicate(true))); ui.open(); await process_frame
	check(ui.wanted and ui.panel.visible and requests.back().operation == "open", "Native Create requests rules before an area admission")
	present(ui, 1, 13, [{"type":"input","controlId":1,"label":"First name","tag":"firstName","value":"","maxLength":32},{"type":"input","controlId":2,"label":"Biography","tag":"biography","value":"","maxLength":32768,"multiline":true}]); await process_frame; await process_frame
	check(ui.tabs.size() == 15 and ui.inputs[1] is LineEdit and ui.inputs[2] is TextEdit, "All fifteen native pages and single/multiline character fields are available")
	ui.inputs[2].text = "a".repeat(32769); ui.inputs[2].text_changed.emit(); await process_frame
	check(ui.inputs[2].text.length() == 32768, "Native biography editor applies the documented transport limit before navigation")
	ui.inputs[1].text = "Native Tester"; ui.inputs[2].text = "First line\nSecond line"; await click(ui.next.get_global_rect().get_center())
	check(requests.back().operation == "page" and int(requests.back().step) == 14 and requests.back().texts[0].value == "Native Tester" and requests.back().texts[1].value.contains("\n"), "Actual Next click atomically flushes both character text fields")
	var before := requests.size(); ui.navigate(3); check(requests.size() == before and not ui.inputs[1].editable, "Waiting guards duplicate navigation and locks existing native controls")
	present(ui, 2, 14, [], {"canFinish":true}); await process_frame; await process_frame
	check(ui.finish.visible and not ui.finish.disabled and ui.finish.get_global_rect().end.y < root.size.y, "Review exposes Play inside the native frame")
	await click(ui.finish.get_global_rect().get_center()); check(requests.back().operation == "submit", "Actual native Play submits only its scoped view and text fields")
	present(ui, 3, 14, [], {"canEdit":false,"canFinish":false,"canRecommend":false,"canCancel":false,"phase":"waiting"}); before = requests.size(); ui.close_creator(); check(ui.cancel.disabled and requests.size() == before, "A character already submitted cannot be cancelled or submitted twice")
	present(ui, 4, 2, [{"type":"portrait","controlId":10,"label":"Authored","resource":"authored_","disabled":false,"selected":true}]); await process_frame; await process_frame
	var png := Image.create(64, 100, false, Image.FORMAT_RGBA8); png.fill(Color.RED); var url := "data:image/png;base64," + Marshalls.raw_to_base64(png.save_png_to_buffer())
	ui.receive({"kind":"creation-portrait","viewId":3,"controlId":10,"image":url}); check(ui.controls[10].get_meta("portrait").texture == null, "Portraits from retired views cannot replace the current original-art thumbnail")
	ui.receive({"kind":"creation-portrait","viewId":4,"controlId":10,"image":url}); check(ui.controls[10].get_meta("portrait").texture != null and ui.controls[10].modulate == Color.WHITE, "Current scoped PNG arrives in the native portrait slot without a selection tint")
	await click(ui.controls[10].get_global_rect().get_center()); check(requests.back().operation == "control" and int(requests.back().controlId) == 10, "Actual portrait click sends its private control handle")
	present(ui, 5, 11, [{"type":"select","controlId":11,"label":"Head","value":-1,"options":["Head 1","Head 2"],"disabled":false},{"type":"colour","controlId":12,"label":"Hair colour 1","color":"#ff0000","disabled":false}]); await process_frame
	ui.controls[11].item_selected.emit(2); check(requests.back().value == 1, "Unchosen dropdown placeholder keeps native option indices aligned")
	present(ui, 6, 5, []); await process_frame; await click(ui.recommend.get_global_rect().get_center()); check(requests.back().operation == "recommend", "Recommended button uses the existing package recommendation operation")
	present(ui, 7, 14, [], {"errors":range(40).map(func(i): return "Missing choice " + str(i))}); await process_frame; await process_frame
	check(ui.errors.visible and ui.finish.get_global_rect().end.y < root.size.y, "Long validation lists scroll without pushing Play outside the window")
	ui.receive({"kind":"creation-begin","viewId":8,"count":2}); ui.receive({"kind":"creation-items","viewId":8,"items":[]}); ui.receive({"kind":"creation-commit","viewId":8}); check(ui.view_id == 7, "Incomplete framed views never replace usable controls")
	ui.receive({"kind":"creation-closed"}); check(not ui.wanted and not ui.panel.visible and ui.controls.is_empty(), "Closing creation releases controls, text fields and portrait textures")
	ui.queue_free(); await process_frame; await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"completed":failures.is_empty(),"checks":checks,"failures":failures})); file.close(); quit(0 if failures.is_empty() else 1)
