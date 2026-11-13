extends SceneTree

var checks := 0
var failures: Array[String] = []
var evidence: Array = []

class CallbackPart extends Node3D:
	var owner_context: RefCounted
	var close_at := 0
	var calls := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and close_at > 0:
			calls += 1
			if calls == close_at:
				owner_context.call("dispatch", 8, {})

func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 32:
		failures.append(label)

func matrix_bytes(value: Transform3D) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(48)
	var offset := 0
	for vector in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		for component in 3:
			result.encode_float(offset, vector[component])
			offset += 4
	return result

func owner(callbacks: bool = false) -> Dictionary:
	var target: Node3D = CallbackPart.new() if callbacks else Node3D.new()
	var reference := Node3D.new()
	root.add_child(target)
	root.add_child(reference)
	var storage := PackedByteArray()
	storage.resize(0x240)
	storage.fill(0)
	storage.encode_float(28, 1.0)
	storage.encode_float(44, 1.0)
	var row := {"id30": 0, "dirty60": 0, "field8c": 0, "object": target, "source": {"type": "dummy", "children": []}, "view": storage, "fields": {16: 3, 28: 4, 44: 1}, "materials": []}
	var context: RefCounted = ClassDB.instantiate("NwnModelPoseStorage")
	var result: Dictionary = context.call("dispatch", 0, {"parts": [row], "binding": [0], "root": 0, "emitter_fields": {}})
	check(not result.has("error"), "Dedicated native owner configures")
	if callbacks:
		target.owner_context = context
		target.set_notify_local_transform(true)
	return {"context": context, "target": target, "reference": reference, "storage": storage}

func write(value: Dictionary, offset: int, fields: Array) -> void:
	var result: Dictionary = value.context.call("dispatch", 3, {"index": 0, "offset": offset, "values": fields})
	check(not result.has("error"), "Source field write admitted at " + str(offset))
	for index in fields.size():
		value.storage.encode_float(offset + index * 4, fields[index])

func reference_publish(value: Dictionary) -> void:
	var data: PackedByteArray = value.storage
	value.reference.position = Vector3(data.decode_float(16), data.decode_float(24), -data.decode_float(20))
	value.reference.quaternion = Quaternion(data.decode_float(32), data.decode_float(40), -data.decode_float(36), data.decode_float(28))
	value.reference.scale = Vector3.ONE * data.decode_float(44)

func publish(value: Dictionary, label: String, manual: bool = false) -> Dictionary:
	var result: Dictionary = value.context.call("dispatch", 2, {"manual": {0: true} if manual else {}, "profile": false, "scope": null})
	check(not result.has("error"), label + " native publication completes")
	if not manual:
		reference_publish(value)
	check(matrix_bytes(value.target.transform) == matrix_bytes(value.reference.transform), label + " exact transform bytes")
	return result

func stats(value: Dictionary) -> Dictionary:
	return value.context.call("dispatch", 7, {})

func dispose(value: Dictionary) -> void:
	value.context.call("dispatch", 8, {})
	if is_instance_valid(value.target):
		value.target.free()
	if is_instance_valid(value.reference):
		value.reference.free()

func warm_and_external() -> void:
	var value := owner()
	var quaternion := Quaternion.from_euler(Vector3(0.61, -1.08, 2.24))
	write(value, 28, [quaternion.w, quaternion.x, -quaternion.z, quaternion.y])
	write(value, 44, [1.31])
	for frame in 4:
		publish(value, "Warm " + str(frame))
		var current := stats(value)
		check(int(current.publication_skips) == maxi(0, frame - 1), "Two original publications precede reuse " + str(frame))
	for event in ["same_transform", "same_basis", "same_scale", "same_rotation", "same_quaternion", "order", "edit_mode", "external_basis", "external_position"]:
		for target: Node3D in [value.target, value.reference]:
			match event:
				"same_transform": target.transform = target.transform
				"same_basis": target.basis = target.basis
				"same_scale": target.scale = target.scale
				"same_rotation": target.rotation = target.rotation
				"same_quaternion": target.quaternion = target.quaternion
				"order": target.rotation_order = (target.rotation_order + 1) % 6
				"edit_mode": target.rotation_edit_mode = (target.rotation_edit_mode + 1) % 3
				"external_basis": target.basis = Basis(Vector3(1.0, 0.2, 0.0), Vector3(0.1, 1.1, 0.15), Vector3(0.0, 0.1, 0.9))
				"external_position": target.position += Vector3(-1.1, 0.3, 2.2)
		for frame in 4:
			publish(value, event + "/" + str(frame))
	for frame in 32:
		if frame % 4 == 0:
			write(value, 16, [frame * 0.1, frame * -0.05, 0.3])
		publish(value, "Changed input " + str(frame))
	var before_manual := stats(value)
	for target: Node3D in [value.target, value.reference]:
		target.position += Vector3(0.5, 1.5, -0.7)
	for frame in 3:
		publish(value, "Manual " + str(frame), true)
	check(stats(value).publication_setter_writes == before_manual.publication_setter_writes, "Manual owner blocks all publication setters")
	for frame in 4:
		var before := stats(value)
		publish(value, "Manual return " + str(frame))
		if frame < 2:
			check(stats(value).publication_setter_writes == before.publication_setter_writes + 3, "Manual return restarts the two-publication gate")
	evidence.append({"scenario": "warm/external/changed/manual", "stats": stats(value)})
	dispose(value)

func fallback_boundaries() -> void:
	var value := owner()
	for scalar in [-1.31, -0.001]:
		write(value, 44, [scalar])
		for frame in 4:
			var before := stats(value)
			publish(value, "Negative fallback %s/%d" % [scalar, frame])
			check(stats(value).publication_setter_writes == before.publication_setter_writes + 3, "Nonpositive scale never reused")
	write(value, 44, [0.0])
	publish(value, "Zero-scale first publication")
	for target: Node3D in [value.target, value.reference]:
		target.transform = Transform3D.IDENTITY
	write(value, 44, [1.0])
	for frame in 4:
		publish(value, "Restored positive scale " + str(frame))
	# Nonfinite position is accepted by the original setter without requiring
	# an Euler decomposition. Restore before exact finite comparisons/JSON.
	for component in [NAN, INF, -INF]:
		write(value, 16, [component, 0.0, 0.0])
		var before := stats(value)
		var result: Dictionary = value.context.call("dispatch", 2, {"manual": {}, "profile": false, "scope": null})
		check(not result.has("error"), "Nonfinite source preserves original native setter admission")
		check(stats(value).publication_setter_writes == before.publication_setter_writes + 3, "Nonfinite source never reused")
		check(stats(value).publication_getters == before.publication_getters, "Nonfinite source adds no cache getter/decomposition")
	write(value, 16, [0.0, 0.0, 0.0])
	for frame in 4:
		publish(value, "Restore finite position " + str(frame))
	evidence.append({"scenario": "fallback", "stats": stats(value)})
	dispose(value)

func callback_lifetime() -> void:
	for close_at in [1, 2, 3]:
		var value := owner(true)
		for frame in 4:
			publish(value, "Pre-close warm %d/%d" % [close_at, frame])
		write(value, 16, [0.5, -0.3, 0.1])
		value.target.calls = 0
		value.target.close_at = close_at
		var result: Dictionary = value.context.call("dispatch", 2, {"manual": {}, "profile": false, "scope": null})
		check(bool(result.get("closed", false)) and not result.has("error"), "Close callback remains deferred and stops publication at setter " + str(close_at))
		check(int(stats(value).parts) == 0, "Closed callback releases retained Parts after publication")
		check(value.target.calls == close_at, "No extra setter after close request " + str(close_at))
		value.target.close_at = 0
		dispose(value)
	var retired := owner()
	for frame in 4:
		publish(retired, "Pre-retire warm " + str(frame))
	retired.target.free()
	var failed: Dictionary = retired.context.call("dispatch", 2, {"manual": {}, "profile": false, "scope": null})
	check(bool(failed.get("partial", false)) and str(failed.get("error", "")).contains("no longer alive"), "Retired warm Node binding still rejects with original lifetime validation")
	dispose(retired)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ClassDB.class_exists("NwnModelPoseStorage"), "Private native pose owner available")
	if failures.is_empty():
		warm_and_external()
		fallback_boundaries()
		callback_lifetime()
	await process_frame
	var report := {"success": failures.is_empty(), "checks": checks, "failures": failures, "evidence": evidence, "gpu": false, "server_connections": 0, "scope": "Exact local transform bytes, original-setter warm stability, mutation/manual/fallback/lifetime boundaries. Materials and controller arithmetic are unchanged by the candidate."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
