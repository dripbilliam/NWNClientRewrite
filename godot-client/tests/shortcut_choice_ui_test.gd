extends SceneTree

const Quickbar = preload("res://systems/server_quickbar.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func click(point: Vector2, key: int, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point
		event.button_index = key; event.pressed = pressed; event.double_click = double_click and pressed
		root.push_input(event,true); await process_frame
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1440,1000)
	var bar := Quickbar.new(); root.add_child(bar); bar.setup()
	var requests: Array = []; var assignments: Array = []
	bar.request.connect(func(row): requests.append(row))
	bar.assignment_requested.connect(func(index,point): assignments.append({"index":index,"point":point}))
	var rows: Array = []
	for index in 36: rows.append({"index":index,"label":"Empty shortcut","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows}); bar.render(2)
	await process_frame; await process_frame
	var target: Vector2 = bar.buttons[35].get_global_rect().get_center()
	await click(target,MOUSE_BUTTON_RIGHT)
	check(assignments.size() == 1 and assignments[0].index == 35, "Actual synthetic right-click opens assignment for the selected third-page slot")
	check(assignments[0].point.distance_to(target) < 1, "Assignment uses the actual native pointer position")
	check(requests.is_empty(), "Opening an empty slot's choices does not activate an action")
	check(bar.selected_index == 35 and not bar.clear.disabled, "The explicit clear control still selects the same physical shortcut")
	await click(target,MOUSE_BUTTON_LEFT,true)
	check(assignments.size() == 1, "A left double-click does not unexpectedly reopen the assignment wheel")
	var old = bar.buttons[35]
	bar.receive({"kind":"quickbar-view","quickbarId":8,"rows":rows})
	old.context_requested.emit(target)
	check(assignments.size() == 1, "A retained button cannot open choices against its replacement owner")
	bar.page = 0; bar.render(0); await process_frame
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(assignments.size() == 2 and assignments.back().index == 0, "First-page right-click keeps its own destination instead of the prior page")
	bar.reset(); bar.free(); await process_frame; await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Authored native shortcut right-click GUI input and owner selection with synthetic viewport events; actual assignment checked separately"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
