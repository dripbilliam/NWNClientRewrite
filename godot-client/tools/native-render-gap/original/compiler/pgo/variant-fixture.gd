extends SceneTree

var rows: Array = []
var failures: Array[String] = []
var checks: int = 0

class Box extends RefCounted:
	var events: Array = []
	var backing: Variant = null
	func _get(property: StringName) -> Variant:
		if property == &"dynamic":
			events.append("get")
			return backing
		return null
	func _set(property: StringName, value: Variant) -> bool:
		if property == &"dynamic":
			events.append("set")
			backing = value
			return true
		return false
	func echo(value: Variant) -> Variant:
		events.append("call")
		return value
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			events.append("delete")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func record(label: String, value: Variant) -> void:
	rows.append({"case": label, "encoded": Marshalls.raw_to_base64(var_to_bytes(value))})

func values() -> Array:
	var nan_a: float = PackedByteArray([1, 0, 0, 0, 0, 0, 248, 127]).decode_double(0)
	var nan_b: float = PackedByteArray([2, 0, 0, 0, 0, 0, 248, 127]).decode_double(0)
	return [null, true, false, 0, 1, -1, 9223372036854775807, -9223372036854775807 - 1,
		0.0, -0.0, 1.0, -1.5, INF, -INF, NAN, nan_a, nan_b,
		"", "alpha", &"alpha", NodePath("alpha/beta"),
		Vector2(1, -0.0), Vector2i(-2, 3), Rect2(-1, 2, 3, 4), Rect2i(-1, 2, 3, 4),
		Vector3(1, 2, -0.0), Vector3i(1, -2, 3), Transform2D.IDENTITY,
		Vector4(1, 2, 3, -0.0), Vector4i(1, 2, 3, 4), Plane(Vector3.UP, 2),
		Quaternion(0, 0, 0, 1), AABB(Vector3(-1, -2, -3), Vector3(2, 4, 6)),
		Basis.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)), Color(0.1, 0.2, 0.3, 0.4),
		[1, "two", Vector3(1, 2, 3)], {"one": 1, "nested": {&"two": [2, 3]}},
		PackedByteArray([0, 10, 13, 255]), PackedInt32Array([-2147483648, 0, 2147483647]),
		PackedInt64Array([-9223372036854775807 - 1, 0, 9223372036854775807]),
		PackedFloat32Array([0.0, -0.0, 1.25, INF, -INF, NAN]),
		PackedFloat64Array([0.0, -0.0, 1.25, INF, -INF, nan_a, nan_b]),
		PackedStringArray(["alpha", "beta"]), PackedVector2Array([Vector2(1, 2)]),
		PackedVector3Array([Vector3(1, 2, 3)]), PackedVector4Array([Vector4(1, 2, 3, 4)]),
		PackedColorArray([Color(0.1, 0.2, 0.3, 0.4)])]

func variant_and_dictionary_cases() -> void:
	var source: Array = values()
	var keyed: Dictionary = {}
	var observations: Array = []
	for index in source.size():
		var value: Variant = source[index]
		keyed[value] = index
		observations.append([typeof(value), hash(value), keyed.has(value), keyed.get(value, -999), var_to_bytes(value)])
	record("variant-types-hashes-float-bits", observations)
	record("dictionary-insertion-order", [keyed.keys(), keyed.values(), keyed.size()])
	var shallow: Dictionary = keyed.duplicate(false)
	var deep: Dictionary = keyed.duplicate(true)
	record("duplicates", [shallow == keyed, deep == keyed, shallow.hash(), deep.hash(), shallow.keys(), deep.values()])
	for index in range(0, source.size(), 2):
		var key: Variant = source[index]
		keyed.erase(key)
		keyed[key] = index + 1000
	record("erase-reinsert-order", [keyed.keys(), keyed.values(), keyed.size()])
	keyed.merge({&"alpha": 991, "new": [1, 2, 3]}, false)
	keyed.merge({&"alpha": 992, "new": [4, 5, 6]}, true)
	record("merge-alias-and-order", [keyed.keys(), keyed.values(), shallow.keys(), shallow.values()])
	var read_only: Dictionary = {"a": [1, 2], &"b": 3}
	read_only.make_read_only()
	check(read_only.is_read_only(), "read-only state")
	record("read-only-read-copy", [read_only.keys(), read_only.values(), read_only.get("a"), read_only.duplicate(true).is_read_only()])
	var typed: Dictionary[StringName, int] = {}
	for index in 512:
		typed[StringName("key_" + str(index))] = index * 17 - 7
	var sum: int = 0
	for index in 512:
		sum += typed.get(StringName("key_" + str(index)), -999)
		if index % 3 == 0:
			check(typed.erase(StringName("key_" + str(index))), "typed erase")
	record("typed-key-table", [typed.keys(), typed.values(), sum, typed.is_typed(), typed.get_typed_key_builtin(), typed.get_typed_value_builtin()])
	var a: Array = [{"child": [1, 2]}, 3]
	var b: Array = a.duplicate(true)
	b[0].child.append(7)
	check(a[0].child.size() == 2 and b[0].child.size() == 3, "deep duplicate detached nested arrays")
	var packed_a := PackedFloat64Array([0.0, -0.0, INF, -INF, 1.25])
	var packed_b: PackedFloat64Array = packed_a
	packed_b[4] = -9.5
	var packed_c: PackedFloat64Array = packed_a.duplicate()
	packed_c[4] = 4.25
	check(packed_a[4] == -9.5 and packed_b[4] == -9.5 and packed_c[4] == 4.25, "packed reference alias and explicit duplicate")
	record("alias-and-explicit-copy", [a, b, packed_a.to_byte_array(), packed_b.to_byte_array(), packed_c.to_byte_array()])
	var stress: Dictionary = {}
	for index in 4096:
		stress[index * 65537] = {"n": index, "payload": PackedInt32Array([index, -index])}
	var stress_sum: int = 0
	for index in 4096:
		var item: Dictionary = stress.get(index * 65537, {})
		check(item.get("n", -1) == index, "large table lookup")
		stress_sum += int(item.n)
		if index % 2 == 0:
			stress.erase(index * 65537)
	record("large-table-resize-erase", [stress_sum, stress.size(), stress.keys(), stress.hash()])

func object_case() -> Dictionary:
	var events: Array = []
	var box := Box.new()
	box.events = events
	box.set(&"dynamic", {"a": [1, 2, 3]})
	var got: Variant = box.get(&"dynamic")
	check(got == {"a": [1, 2, 3]}, "Variant dynamic getter/setter")
	var method := Callable(box, "echo")
	var callable_dictionary: Dictionary = {method: "bound"}
	check(callable_dictionary.get(method) == "bound", "callable dictionary key")
	var echo: Variant = method.call(PackedFloat64Array([-0.0, 1.25]))
	var weak: WeakRef = weakref(box)
	var holders: Dictionary = {"object": box}
	var second: Dictionary = holders.duplicate(false)
	box = null
	holders.clear()
	var retained: bool = weak.get_ref() != null
	check(retained, "copied Variant retains RefCounted")
	second.clear()
	callable_dictionary.clear()
	method = Callable()
	return {"events": events, "weak": weak, "retained": retained, "got": got, "echo": echo}

func _initialize() -> void:
	variant_and_dictionary_cases()
	var object_result: Dictionary = object_case()
	record("object-callable-refcount-callbacks", [object_result.events, object_result.retained, object_result.weak.get_ref() == null, object_result.got, object_result.echo])
	check(object_result.weak.get_ref() == null, "RefCounted released after all temporary scopes")
	var report_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	var report := {"version": 1, "success": failures.is_empty(), "checks": checks, "rows": rows, "failures": failures, "scope": "Public Godot Variant/Dictionary type, bit, hash, order, alias, callback and lifetime differential. No game or FPS claim."}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report) + "\n")
	file.close()
	quit(0 if failures.is_empty() else 1)
