extends SceneTree

const Controls = preload("res://systems/model_controllers.gd")
const Values = preload("res://tests/oracle_values.gd")
var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void: call_deferred("run")

func expect(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if not Values.equal_values(actual, expected) and failures.size() < 12: failures.append({"case": label, "actual": actual, "expected": expected})

func samples(kind: String, rows: Array) -> void:
	var pool: Array = []
	for index in 65600: pool.append(Controls.f(((index * 13) % 37 - 18) * 0.125))
	for index in rows.size():
		var row: Dictionary = rows[index]
		var c: Dictionary = row.case
		for i in c.times.size(): pool[i] = Controls.f(c.times[i])
		var controller := {"rows4": int(c.rows), "columnsA": int(c.flags), "timeIndex6": 0, "valueIndex8": int(c.valueBase), "displacement0": int(c.get("displacement", 0))}
		var target: Array
		var result: int
		if kind == "float-sample":
			target = [77.5]
			result = Controls.scalar(controller, c.time, {"values88": pool}, target)
		elif kind == "vector-sample":
			target = [77.5, 88.5, 99.5]
			result = Controls.vector(controller, c.time, {"values88": pool}, target, c.scale)
		else:
			for i in c.quaternions.size():
				for axis in 4: pool[int(c.valueBase) + i * 4 + axis] = Controls.f(c.quaternions[i][axis])
			target = [77.5, 88.5, 99.5, 111.5]
			result = Controls.quaternion(controller, c.time, {"values88": pool}, target)
		expect({"result": result, "value": target[0] if kind == "float-sample" else target}, {"result": row.result, "value": row.value}, "%s %s" % [kind, index])

func apply_case(row: Dictionary, index: int) -> void:
	var c: Dictionary = row.case
	var calls: Array = []
	var values: Array = []
	values.resize(64)
	values.fill(0.0)
	for span in [[0, [0, 1]], [16, [2, 4]], [32, [1, 2, 3, 4, 5, 6]], [48, [0, 0, 0, 1, 0.5, 0.5, 0.5, 0.5]]]:
		for i in span[1].size(): values[span[0] + i] = span[1][i]
	var controllers: Array = []
	for spec in [[44, 1, 16], [16, 3, 32], [28, 4, 48], [44, 1, 16], [60, 2, 16]]:
		controllers.append({"displacement0": spec[0], "columnsA": spec[1], "valueIndex8": spec[2], "rows4": 2, "timeIndex6": 0})
	var node := {"controllers78": controllers, "controllerCount80": c.count, "values88": values}
	var part := {16: [2, -1, 3], 28: c.quaternion.duplicate(), 44: [7]}
	Controls.control(node, part, c.previous, c.time, c.weight, {"read": func(p, offset, _count): return p[offset].duplicate(), "write": func(p, offset, value): p[offset] = value,
		"positionScale": func(): return c.scale, "activeMotionRun": func(): return c.motion,
		"motion": func(controller, _part, _node, previous, time):
			var physical_index := -1
			for i in controllers.size():
				if is_same(controllers[i], controller): physical_index = i; break
			calls.append(["motion", physical_index, previous, time])
			if c.truncate: node.controllerCount80 = 1})
	expect({"calls": calls, "count": node.controllerCount80, "position": part[16], "quaternion": part[28], "scalar": part[44][0]}, {"calls": row.calls, "count": row.count, "position": row.position, "quaternion": row.quaternion, "scalar": row.scalar}, "controller apply %s" % index)

func hierarchy_case(row: Dictionary, index: int) -> void:
	var c: Dictionary = row.case
	var calls: Array = []
	var parts: Array = []
	var nodes: Array = []
	var ids: Array = [0] + c.physicalIds + [3]
	var animation_ids: Array = [0] + c.animationIds + [3]
	for i in ids.size():
		parts.append({"name": "part%s" % i, "id30": ids[i], "dirty60": c.childDirty if i else c.dirty, "owner50": {}, "childCount40": 0, "children38": []})
		nodes.append({"name": "node%s" % i, "id34": animation_ids[i], "childCount70": 0, "children68": []})
	parts[0].children38 = parts.slice(1, 4); parts[0].childCount40 = 3
	parts[1].children38 = [parts[4]]; parts[1].childCount40 = 1
	nodes[0].children68 = nodes.slice(1, 4); nodes[0].childCount70 = 3
	nodes[int(c.grandchildAt)].children68 = [nodes[4]]; nodes[int(c.grandchildAt)].childCount70 = 1
	var context := {"depth": c.depth}
	Controls.hierarchy(parts[0], nodes[0], -0.25, 0.75, 0.3, context, {"control": func(node, part, previous, time, weight): calls.append(["control", node.name, part.name, previous, time, weight]),
		"light": func(part): calls.append(["light", part.name]); return {"field8c": c.lightFlag} if c.light else null,
		"animateStaticLight": func(_owner, _light): calls.append(["AnimateStaticLight", "light"])})
	expect({"calls": calls, "depth": context.depth}, {"calls": row.calls, "depth": row.depth}, "hierarchy %s" % index)

func run() -> void:
	var oracle := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="): oracle = arg.substr(9)
		elif arg.begins_with("--report="): output = arg.substr(9)
	var cases: Dictionary = Values.decode(JSON.parse_string(FileAccess.get_file_as_string(oracle)))
	var counts := {}
	for kind in cases:
		expect(cases[kind].binarySha256, "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", kind + " original build")
		counts[kind] = cases[kind].rows.size()
		if kind.ends_with("sample"): samples(kind, cases[kind].rows)
		else:
			for index in cases[kind].rows.size():
				if kind == "controller-apply": apply_case(cases[kind].rows[index], index)
				else: hierarchy_case(cases[kind].rows[index], index)
	var report := {"passed": failures.is_empty(), "checks": checks, "cases": counts, "failures": failures, "scope": "Controller sampling/blending and physical hierarchy against retained original executions; not full pose/provider parity"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
