extends SceneTree
const Tiles = preload("res://systems/native_data/native_tile_visibility.gd")
var checks := 0
var failures: Array = []
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition and failures.size() < 24: failures.append(label)
func _initialize() -> void: call_deferred("run")
func _words(values: Array) -> Array:
	var result: Array = []
	var bytes := PackedByteArray()
	bytes.resize(4)
	for value in values:
		bytes.encode_float(0, float(value))
		result.append(bytes.decode_u32(0))
	return result
func sample(previous: Array, change: Dictionary, width: int = 3, height: int = 2) -> Dictionary:
	return {"previous": previous, "change": change, "width": width, "height": height}
func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _same(a[index], b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return a == b
	return typeof(a) == typeof(b) and a == b
func run() -> void:
	var report_path := ""
	var fixture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
		if argument.begins_with("--fixture="): fixture_path = argument.substr(10)
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(fixture is Dictionary and fixture.get("kind") == "frozen-standalone-node-reference-not-native-oracle", "differential reference scope")
	var reference_cases := 0
	var xy_cases := 0
	if fixture is Dictionary:
		check(fixture.reference.sha256 == "d9bc7d33dfabfe1b35b785fe87073429721ebe636dc299f458b64492f927c70f", "reference source pin")
		check(fixture.native_evidence.binary_sha256 == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", "static native evidence identity")
		for row in fixture.get("rows", []):
			var before: Variant = row.input.duplicate(true) if row.input is Dictionary else row.input
			var output := Tiles.project(row.input)
			check(_same(output, row.expected), "reference/%s got%s" % [row.name, str(output)])
			check(_same(before, row.input), "reference input preserved/%s" % row.name)
			reference_cases += 1
		for row in fixture.get("xy_cases", []):
			var actual := Tiles.contains_native_xy(row.center, row.position)
			# Godot JSON decimal parsing can round 0.00010013580322265625;
			# compare the frozen raw f32 words, never a widened tolerance.
			check(actual.available and actual.contains == row.expected.contains and actual.reason == row.expected.reason and _same(_words(actual.minimum_native_xy), row.minimum_f32_words) and _same(_words(actual.maximum_native_xy), row.maximum_f32_words), "native f32 XY/%s expected%s got%s" % [xy_cases, JSON.stringify(row.expected), JSON.stringify(actual)])
			xy_cases += 1
	var input := sample([0, 0, 0, 0, 0, 0], {"mode": [0.0, 0.0], "points": [{"state": 1.0, "x": 1.0, "y": 0.0}]})
	input.delivery = {"scope": "c7/a4", "serial": 92}
	var original := input.duplicate(true)
	var first := Tiles.project(input)
	var second := Tiles.project(input)
	first.states[0] = 77
	first.operations[0].new_state = 77
	first.delivery.serial = 77
	check(input == original and second.states[0] == 0 and second.operations[0].new_state == 1 and second.delivery.serial == 92, "detached projection and delivery")
	var flags := Tiles.project(sample([1, 0, 0, 0, 0, 0], {"mode": [-0.0, false], "points": [{"state": -0.0, "x": 0, "y": 0}]}))
	check(flags.available and flags.states[0] == 0, "negative zero wire flag")
	for value in [NAN, INF, -INF, "1", null, 2, {}, []]:
		var malformed := sample([0, 0, 0, 0, 0, 0], {"mode": [0, 0], "points": [{"state": value, "x": 0, "y": 0}]})
		check(not Tiles.project(malformed).available, "strict flag value%s" % str(value))
	check(not Tiles.project(sample([false], {"mode": [0, 0], "points": []}, 1, 1)).available, "bool old state is not integer")
	var packed := Tiles.project({"width": 4, "height": 3, "previous": PackedByteArray([1,1,1,1,1,1,1,1,1,1,1,1]), "change": {"mode": [1,1], "bytes": PackedByteArray([129])}})
	check(packed.available and packed.states.slice(8) == [1,1,1,1] and packed.operations.size() == 8, "packed array and untouched tail")
	var too_many_bytes := PackedByteArray()
	too_many_bytes.resize(256)
	check(not Tiles.project(sample([0], {"mode": [0,1], "bytes": too_many_bytes}, 1,1)).available, "bounded packed byte payload")
	var excessive: Array = []
	excessive.resize(Tiles.MAX_OPERATIONS + 1)
	excessive.fill({"state":1,"x":0,"y":0})
	check(Tiles.project(sample([0], {"mode": [0,0], "points": excessive},1,1)).reason == "operation-limit", "bounded operations")
	excessive.clear()
	var live: Array = [1,0,0,0,0,0]
	var plan := Tiles.project(sample(live, {"mode": [1,0], "points": [{"x":0,"y":0}]}))
	var events: Array = []
	var objects := func(event: Dictionary) -> void:
		events.append(["objects", event.tile_index, live[event.tile_index], event.revealed])
		event.new_state = 99 # Must not alter the operation/store.
	var fog := func(event: Dictionary) -> void: events.append(["fog", event.tile_index, live[event.tile_index], event.fogged])
	for operation in plan.operations:
		var applied := Tiles.apply_operation(live, operation, {"objects": objects, "fog_enabled": true, "fog": fog})
		check(applied.available, "ordered full operation")
	check(live == plan.states and live[0] == 1, "full hide/reveal final array")
	check(events == [["fog",0,1,true],["objects",0,0,true],["fog",0,0,false]], "full suppressed hide then reveal; callbacks before stores")
	var op := {"tile_index":0,"x":0,"y":0,"new_state":1,"suppress_object_updates":0,"previous":99,"changed":false}
	live = [0]
	events.clear()
	var reentrant_objects := func(event: Dictionary) -> void:
		events.append(["objects",live[0],event.previous])
		live[0] = 7
	var reentrant_fog := func(_event: Dictionary) -> void: events.append(["fog",live[0]])
	var result := Tiles.apply_operation(live, op, {"objects": reentrant_objects, "fog_enabled": true, "fog": reentrant_fog})
	check(result.available and result.stored and live == [1], "reentrant callback cannot replace outer final store")
	check(events == [["objects",0,0],["fog",7]], "live old state beats projected evidence; fog after objects")
	events.clear()
	result = Tiles.apply_operation(live, op)
	check(result.available and not result.changed and not result.stored and events.is_empty(), "same state requires no callback and does not store")
	live = [0]
	var scope := {"current":true}
	var scope_guard := func() -> bool: return scope.current
	var retire := func(_event: Dictionary) -> void: scope.current = false
	result = Tiles.apply_operation(live, op, {"objects":retire,"fog_enabled":true,"fog":fog,"is_current":scope_guard})
	check(not result.available and result.cancelled and result.objects_called and not result.fog_called and not result.stored and live == [0], "scope retirement between callbacks stops old-array publication")
	result = Tiles.apply_operation(live, op, {"objects":objects,"is_current":scope_guard})
	check(result.cancelled and not result.objects_called and live == [0], "stale scope rejected before callback")
	result = Tiles.apply_operation(live, op)
	check(not result.available and result.reason == "fog-admission-unavailable" and live == [0], "unknown area fog admission is unavailable")
	result = Tiles.apply_operation(live, op, {"fog_enabled":false})
	check(not result.available and result.reason == "object-callback-unavailable" and live == [0], "unsuppressed callback cannot silently disappear")
	var hidden := op.duplicate(true)
	hidden.suppress_object_updates = 1
	result = Tiles.apply_operation(live, hidden, {"fog_enabled":true})
	check(not result.available and result.reason == "fog-callback-unavailable" and live == [0], "fog callback cannot silently disappear")
	result = Tiles.apply_operation(live, hidden, {"fog_enabled":false})
	check(result.available and result.stored and live == [1], "suppressed no-fog valid setter")
	var missing: Array = [null]
	check(not Tiles.apply_operation(missing, op).available and missing == [null], "missing live state is unavailable")
	for bad in [null, [], {"tile_index":1,"x":0,"y":0,"new_state":1,"suppress_object_updates":0}, {"tile_index":0,"x":0,"y":0,"new_state":"1","suppress_object_updates":0}]:
		check(not Tiles.apply_operation([0], bad).available, "malformed operation")
	for pair in [[null,[0,0]],[[0],[0,0]],[[0,0],[NAN,0]],[[0,0],["0",0]]]:
		check(not Tiles.contains_native_xy(pair[0],pair[1]).available, "missing XY unavailable")
	check(Tiles.contains_native_xy([0,0],[0,0,NAN]).contains, "Z is not read")
	var report := {"checks":checks,"failures":failures,"reference_cases":reference_cases,"xy_cases":xy_cases,"scope":"Native Godot ordered tile kernel versus frozen standalone Node reference; static native facts, not fresh native oracle or runtime integration"}
	if not report_path.is_empty(): FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
