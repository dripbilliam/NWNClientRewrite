extends SceneTree

const Selection = preload("res://systems/visual_selection.gd")
const Connection = preload("res://systems/local_connection.gd") # Compile integrated path too.
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not equal(a[index], b[index]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key], b[key]): return false
		return true
	return typeof(a) == typeof(b) and a == b

func expect(value: bool, label: String, actual: Variant = null, expected: Variant = null) -> void:
	checks += 1
	if not value and failures.size() < 10: failures.append({"label": label, "actual": actual, "expected": expected})

func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	var base := ProjectSettings.globalize_path("res://").path_join("../backups/animations").simplify_path()
	var total := 0
	for name in ["selection", "competing-removal"]:
		var observations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("native-visual-%s-observations.json" % name)))
		expect(observations.binarySha256 == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", "Original build identity")
		for row in observations.rows:
			var c: Dictionary = row.case
			var calls: Array = []
			var entries: Array = []
			for index in c.entries.size():
				var e: Dictionary = c.entries[index]
				entries.append({"id": index, "finishedF4": e.finished, "field110": e.get("field110", 0), "attached114": e.attached, "closedEc": e.get("closed", 0), "scope10c": e.scope, "programType10d": e.type, "visualF8": e.get("visual", 0)})
			var p := {"programType": func(e): return int(e.programType10d),
				"selectedObjectId1406ac1c0": func(): calls.append(["selectedObjectId1406ac1c0"]); return c.controlledId,
				"viewGate1407dadb0": func(): calls.append(["controlled"]); calls.append(["viewGate1407dadb0"]); return c.viewGate1407dadb0,
				"attach": func(e): calls.append(["attach", e.id]); e.attached114 = 1,
				"detach": func(e): calls.append(["detach", e.id]); e.attached114 = 0,
				"start": func(e): calls.append(["start", e.id]); e.closedEc = 0,
				"stop": func(e, requested): calls.append(["stop", e.id, requested]); e.closedEc = 1}
			if name == "selection":
				Selection.select({"id": 123, "suppressed108": c.suppressed, "visuals80": entries}, int(c.type), p)
			else:
				Selection.detach_competing({"visuals80": entries}, entries[int(c.remove)], p)
			expect(equal(calls, row.calls), "%s/%s callback order" % [name, total], calls, row.calls)
			expect(equal(entries.map(func(e): return e.attached114), row.attached), "%s/%s attachment state" % [name, total])
			if name == "selection": expect(equal(entries.map(func(e): return e.closedEc), row.closed), "Selected effects retain original restart/stop behavior")
			p.clear()
			total += 1
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "recorded_original_cases": total, "failures": failures, "scope": "Native physical selection/competing removal against retained original-function observations; not complete live effect rendering"}, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
