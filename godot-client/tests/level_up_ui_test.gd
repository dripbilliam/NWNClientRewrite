extends SceneTree
const Wizard = preload("res://systems/server_level_up.gd")
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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/level-up-ui-fixture-v1.json"))
	var wizard := Wizard.new(); wizard.setup(""); root.add_child(wizard)
	var sent: Array = []; wizard.request.connect(func(row): sent.append(row))
	wizard.open(); wizard.receive(data.pages[0]); await process_frame
	check(wizard.visible and sent[0].kind == "level-open" and wizard.tabs.size() == 7, "Native level-up has all seven pages and begins through its session owner")
	wizard.tabs[1].pressed.emit()
	check(sent.back().kind == "level-page" and sent.back().step == 1 and wizard.waiting, "Navigation carries the private view and blocks duplicate in-flight edits")
	var count := sent.size(); wizard.navigate(2)
	check(sent.size() == count, "An unacknowledged view cannot send another mutation")
	wizard.receive(data.pages[1])
	var ability: Dictionary = data.pages[1].items.filter(func(row): return row.get("tag", "") == "ability")[0]
	wizard.controls[int(ability.controlId)].pressed.emit()
	check(sent.back().kind == "level-control" and sent.back().controlId == ability.controlId and not sent.back().has("proposal"), "Ability controls carry no trusted draft/proposal data")
	wizard.receive(data.pages[2])
	var plus: Dictionary = data.pages[2].items.filter(func(row): return row.get("tag", "") == "skill-plus")[0]
	check(wizard.controls[int(plus.controlId)].get_parent() is HBoxContainer, "Skill rows keep name, rank and increment controls together")
	wizard.receive(data.pages[3])
	var filter: Dictionary = data.pages[3].items.filter(func(row): return row.get("tag", "") == "feat-filter")[0]
	wizard.inputs[int(filter.controlId)].text = "Master group"
	wizard.navigate(4)
	check(sent.back().texts[0].value == "Master group", "Navigation commits unsubmitted text filters through private handles")
	wizard.receive(data.pages[5])
	check(wizard.inputs.size() == 2, "Familiar and animal companion both expose independent name fields")
	var index := 0
	for id in wizard.inputs:
		wizard.inputs[id].text = "Companion " + str(index); index += 1
	wizard.navigate(6)
	check(sent.back().texts.size() == 2 and sent.back().texts[0].value != sent.back().texts[1].value, "Both companion names commit in the same navigation request")
	wizard.receive(data.pages[6])
	check(not wizard.finish.visible or wizard.finish.disabled, "Review cannot finish an invalid authored draft")
	var ready: Dictionary = data.pages[6].duplicate(true); ready.viewId = 100; ready.errors = []; ready.canFinish = true
	wizard.receive(ready); wizard.submit()
	check(sent.back().kind == "level-submit" and not sent.back().has("proposal"), "Finish submits only the scoped review identity")
	var pending := ready.duplicate(true); pending.viewId = 101; pending.phase = "submitting"; pending.items = []; pending.canEdit = false; pending.canFinish = false; pending.canCancel = false; pending.canBack = false; pending.canNext = false
	wizard.receive(pending); count = sent.size(); wizard.close_level_up(); wizard.submit()
	check(sent.size() == count and wizard.visible, "Waiting for confirmation cannot be dismissed as a cancelled or accepted level")
	wizard.receive({"kind": "level-complete", "accepted": true})
	check(not wizard.visible and wizard.view_id == -1 and wizard.inputs.is_empty(), "Confirmed completion retires native draft controls")
	wizard.open(); wizard.receive(data.pages[0]); wizard.position = Vector2(30, 35); wizard.close_level_up()
	check(sent.back().kind == "level-cancel" and wizard.visible, "Cancel waits for the owner response rather than fabricating local completion")
	wizard.receive({"kind": "level-closed"}); wizard.open(); wizard.receive(data.pages[0])
	check(wizard.position == Vector2(30, 35), "Native wizard reopens at its last position")
	wizard.reset(); check(wizard.state.is_empty() and not wizard.visible, "World retirement clears the native wizard")
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native level-up pages/input/confirmation ownership; actual server validation separate"}, "\t")); file.close()
	wizard.free(); quit(0 if failures.is_empty() else 1)
