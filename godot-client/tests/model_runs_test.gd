extends SceneTree

const Runs = preload("res://systems/model_runs.gd")
const Rigs = preload("res://systems/model_rigs.gd")
var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("run")

func expect(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if not equal_values(actual, expected) and failures.size() < 12:
		failures.append({"case": label, "actual": actual, "expected": expected})

func equal_values(actual: Variant, expected: Variant) -> bool:
	if (actual is float or actual is int) and (expected is float or expected is int): return actual == expected
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index in actual.size():
			if not equal_values(actual[index], expected[index]): return false
		return true
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in actual:
			if not expected.has(key) or not equal_values(actual[key], expected[key]): return false
		return true
	return actual == expected

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$f64"): return str(value["$f64"]).hex_decode().decode_double(0)
		var result := {}
		for key in value: result[key] = decode(value[key])
		return result
	if value is Array: return value.map(decode)
	return value

func serialized(runs: Array) -> Array:
	var result: Array = []
	for run in runs:
		var value: Dictionary = run.duplicate(true)
		value.erase("clip0")
		value.clip = run.clip0.get("key", run.clip0.get("id"))
		result.append(value)
	return result

func playback(row: Dictionary, index: int) -> void:
	var c: Dictionary = row.case
	var calls: Array = []
	var clips := {}
	for key in ["base:impact", "base:duration", "base:cessation", "override:impact"]:
		clips[key] = {"key": key, "name": key.split(":")[1], "length90": c.length, "transition94": c.transition}
	var gob := {"model68": "base", "model80": "override" if c.override else null, "runsE0": []}
	for i in c.initial.size():
		var initial: Dictionary = c.initial[i]
		gob.runsE0.append({"id": i, "clip0": clips["base:" + str(initial.name)], "speed8": 0.75, "flagsC": int(initial.flags), "previous10": 0.125, "time14": 0.375, "weight18": 0.625, "transition1c": 0.25, "scale20": 1.5, "done24": 1})
	var allocation := [100]
	var p := {"findAnimation": func(model, name): calls.append(["findAnimation", model, name]); return clips.get(str(model) + ":" + str(name).to_lower()),
		"animationScale": func(model, clip): calls.append(["animationScale", model, clip.key if clip != null else null]); return c.animationScale,
		"playbackScale": func(_gob): calls.append(["playbackScale"]); return c.playbackScale,
		"createRun": func(_clip): var id: int = allocation[0]; allocation[0] += 1; calls.append(["createRun", id]); return {"id": id},
		"destroyRun": func(value, bytes): calls.append(["destroyRun", value.id, bytes]),
		"event": func(name, data): calls.append(["event", name, data])}
	var frames: Array = []
	for request in c.requests:
		var result := Runs.play(gob, null if request.name == "<null>" else request.name, request.speed, int(request.flags), request.start, p)
		frames.append({"result": result, "runs": serialized(gob.runsE0)})
	expect(calls, row.calls, "playback callbacks %s" % index)
	expect(frames, row.frames, "playback fields %s" % index)

func clock(row: Dictionary, index: int) -> void:
	var c: Dictionary = row.case
	var calls: Array = []
	var gob := {"root90": {} if c.root else null, "period188": int(c.period), "runsE0": []}
	for i in c.initial.size():
		var r: Dictionary = c.initial[i]
		var events: Array = []
		for j in 4: events.append({"time": [0.0, 0.25, 0.5, 1.0][j], "name": "e%s_%s" % [i, j]})
		gob.runsE0.append({"id": i, "clip0": {"id": i, "name": "clip%s" % i, "length90": Runs.f(r.length), "events": events}, "speed8": Runs.f(r.speed), "flagsC": int(r.flags), "previous10": Runs.f(r.previous), "time14": Runs.f(r.time), "weight18": Runs.f(r.weight), "transition1c": Runs.f(r.transition), "scale20": Runs.f(r.scale), "done24": int(r.done)})
	var p := {"event": func(name, data): calls.append(["event", name, data]), "destroyRun": func(value, bytes): calls.append(["destroyRun", value.id, bytes]),
		"applyClip": func(clip, previous, time, weight, scale, context, reverse): calls.append(["applyClip", clip.id, previous, time, weight, scale, context.id if context != null else null, reverse if context != null else 0]),
		"animateEvents": func(clip, previous, time, reverse):
			for name in Rigs.model_events(clip.events, previous, time, reverse): calls.append(["event", name, 0]),
		"updateRoot": func(_root, delta): calls.append(["updateRoot", delta]), "periodicUpdate": func(_gob): calls.append(["periodicUpdate"])}
	var frames: Array = []
	for delta in c.deltas:
		Runs.advance(gob, delta, p)
		frames.append({"runs": serialized(gob.runsE0), "period": gob.period188})
	expect(calls, row.calls, "clock callbacks %s" % index)
	expect(frames, row.frames, "clock fields %s" % index)

func run() -> void:
	var oracle := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		elif arg.begins_with("--oracle="): oracle = arg.substr(9)
	var cases: Dictionary = decode(JSON.parse_string(FileAccess.get_file_as_string(oracle)))
	var counts := {}
	for kind in ["playback", "run-clock"]:
		var data: Dictionary = cases[kind]
		expect(data.binarySha256, "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", kind + " original build")
		counts[kind] = data.rows.size()
		for index in data.rows.size():
			if kind == "playback": playback(data.rows[index], index)
			else: clock(data.rows[index], index)
	var report := {"success":failures.is_empty(),"passed": failures.is_empty(), "checks": checks, "cases": counts, "failures": failures, "scope": "Native run scheduling/clock against retained original executions; not pose/controllers or outer scene parity"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
