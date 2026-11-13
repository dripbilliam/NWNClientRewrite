extends SceneTree

# Research oracle for the pinned Godot Node3D setter contract. This does not
# benchmark, connect to a server, or modify the production pose implementation.
# Run only in an allocated isolated headless slot.

var _failures: Array[String] = []
var _checks := 0
var _results: Dictionary = {}
var _stability: Dictionary = {"cases": 0, "tail_stable_from_second": 0, "unstable_after_32": 0, "first_stable_histogram": {}, "first_unstable": null}
var _events: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _basis_error(left: Basis, right: Basis) -> float:
	var error := 0.0
	for column in 3:
		for row in 3:
			error = maxf(error, absf(left[column][row] - right[column][row]))
	return error

func _normalized_euler(value: Basis, order: int) -> Vector3:
	# Mirrors the pinned core/math/basis.cpp get_euler_normalized contract.
	var normalized := value.orthonormalized()
	if normalized.determinant() < 0.0:
		normalized = normalized.scaled(Vector3(-1.0, -1.0, -1.0))
	return normalized.get_euler(order)

func _observe(key: String, expected: Transform3D, candidate: Transform3D, context: String) -> void:
	if not _results.has(key):
		_results[key] = {"cases": 0, "exact": 0, "approximate": 0, "max_basis_error": 0.0, "first_mismatch": null}
	var row: Dictionary = _results[key]
	row.cases += 1
	if candidate == expected:
		row.exact += 1
	else:
		if row.first_mismatch == null:
			row.first_mismatch = context
	if candidate.is_equal_approx(expected):
		row.approximate += 1
	row.max_basis_error = maxf(row.max_basis_error, _basis_error(expected.basis, candidate.basis))

func _publish(target: Node3D, position: Vector3, quaternion: Quaternion, scalar: float) -> Transform3D:
	target.position = position
	target.quaternion = quaternion
	target.scale = Vector3(scalar, scalar, scalar)
	return target.transform

func _repeat(target: Node3D, position: Vector3, quaternion: Quaternion, scalar: float, context: String) -> void:
	var outputs: Array[Transform3D] = []
	for iteration in 32:
		outputs.append(_publish(target, position, quaternion, scalar))
	var stable_from := -1
	for start in 31:
		var stable := true
		for later in range(start + 1, 32):
			if outputs[start] != outputs[later]:
				stable = false
				break
		if stable:
			stable_from = start + 1
			break
	_stability.cases += 1
	if stable_from > 0 and stable_from <= 2:
		_stability.tail_stable_from_second += 1
	if stable_from < 0:
		_stability.unstable_after_32 += 1
		if _stability.first_unstable == null:
			var repeats: Array = []
			for first in 31:
				for later in range(first + 1, 32):
					if outputs[first] == outputs[later]:
						repeats.append([first + 1, later + 1])
			_stability.first_unstable = {"context": context, "repeated_output_pairs": repeats}
	var bucket := str(stable_from)
	_stability.first_stable_histogram[bucket] = int(_stability.first_stable_histogram.get(bucket, 0)) + 1
	_checks += 1

func _event_case(order: int, previous: Basis, quaternion: Quaternion, scalar: float, event: String) -> void:
	var target := Node3D.new()
	target.rotation_order = order
	target.transform = Transform3D(previous, Vector3(-3.0, 4.0, 5.0))
	var position := Vector3(1.31, -17.24, 2.61)
	var before := Transform3D.IDENTITY
	for iteration in 32:
		before = _publish(target, position, quaternion, scalar)
	match event:
		"same_transform_assignment": target.transform = target.transform
		"same_basis_assignment": target.basis = target.basis
		"same_scale_assignment": target.scale = target.scale
		"same_rotation_assignment": target.rotation = target.rotation
		"same_quaternion_assignment": target.quaternion = target.quaternion
		"changed_rotation_order": target.rotation_order = (order + 1) % 6
		"changed_rotation_edit_mode": target.rotation_edit_mode = (target.rotation_edit_mode + 1) % 3
		"external_manual_basis": target.transform = Transform3D(previous, Vector3(-3.0, 4.0, 5.0))
		"external_manual_position": target.position += Vector3(1.0, 0.0, -2.0)
	var after_external := target.transform
	var live_scale := target.scale
	var scale_matches := live_scale == Vector3(scalar, scalar, scalar)
	var order_matches := target.rotation_order == order
	var after_publication := _publish(target, position, quaternion, scalar)
	if not _events.has(event):
		_events[event] = {"cases": 0, "external_matrix_unchanged": 0, "unchanged_matrix_but_scale_changed": 0, "unchanged_matrix_but_republication_changed": 0, "matrix_scale_order_skip_eligible": 0, "matrix_scale_order_bad_skips": 0, "max_republication_basis_error": 0.0, "first_cache_invalidation_example": null}
	var row: Dictionary = _events[event]
	row.cases += 1
	if before == after_external:
		row.external_matrix_unchanged += 1
		if not scale_matches:
			row.unchanged_matrix_but_scale_changed += 1
		if scale_matches and order_matches:
			row.matrix_scale_order_skip_eligible += 1
			if before != after_publication:
				row.matrix_scale_order_bad_skips += 1
		if before != after_publication:
			row.unchanged_matrix_but_republication_changed += 1
			if row.first_cache_invalidation_example == null:
				row.first_cache_invalidation_example = {"order": order, "scalar": scalar, "previous": str(previous), "quaternion": str(quaternion)}
	row.max_republication_basis_error = maxf(row.max_republication_basis_error, _basis_error(before.basis, after_publication.basis))
	_checks += 1
	target.free()

func _run() -> void:
	var rotation := Quaternion.from_euler(Vector3(0.61, -1.08, 2.24))
	var old_bases: Array[Basis] = [
		Basis.IDENTITY,
		Basis.from_euler(Vector3(-0.13, 0.52, 0.91)),
		Basis.from_scale(Vector3(1.31, 1.31, 1.31)),
		Basis.from_scale(Vector3(-1.31, -1.31, -1.31)),
		Basis.from_euler(Vector3(0.39, -0.71, 0.42)) * Basis.from_scale(Vector3(1.31, 2.17, 0.61)),
		Basis.from_euler(Vector3(0.39, -0.71, 0.42)) * Basis.from_scale(Vector3(-1.31, 2.17, 0.61)),
		Basis(Vector3(1.0, 0.25, 0.0), Vector3(0.15, 1.0, 0.12), Vector3(0.0, 0.07, 1.2)),
	]
	var quaternions: Array[Quaternion] = [
		Quaternion.IDENTITY,
		rotation,
		Quaternion(-rotation.x, -rotation.y, -rotation.z, -rotation.w),
		Quaternion(rotation.x * 1.73, rotation.y * 1.73, rotation.z * 1.73, rotation.w * 1.73),
		Quaternion.from_euler(Vector3(PI / 2.0, 0.0, 0.0)),
		Quaternion.from_euler(Vector3(-PI / 2.0, PI / 2.0, -PI)),
		Quaternion.from_euler(Vector3(0.0000001, -0.0000002, 0.0000003)),
	]
	var scales: Array[float] = [0.001, 0.6, 1.0, 1.31, 100.0, -1.31]
	var position := Vector3(1.31, -17.24, 2.61)
	var original := Node3D.new()
	var replacement := Node3D.new()
	var getter_mismatches := {"scale": 0, "rotation": 0, "quaternion": 0}
	var cases := 0
	for order in 6:
		original.rotation_order = order
		replacement.rotation_order = order
		for previous_index in old_bases.size():
			var previous: Basis = old_bases[previous_index]
			for quaternion_index in quaternions.size():
				var quaternion: Quaternion = quaternions[quaternion_index]
				for scalar in scales:
					cases += 1
					original.transform = Transform3D(previous, Vector3(-3.0, 4.0, 5.0))
					var expected := _publish(original, position, quaternion, scalar)
					var new_scale := Basis.from_scale(Vector3(scalar, scalar, scalar))
					var constructed := Basis(quaternion)
					var context := "order=%d previous=%d quaternion=%d scale=%s" % [order, previous_index, quaternion_index, scalar]
					_observe("direct_quaternion_scale", expected, Transform3D(constructed * new_scale, position), context)
					var previous_scaled := constructed * Basis.from_scale(previous.get_scale())
					var reconstructed := Basis.from_euler(_normalized_euler(previous_scaled, order), order) * new_scale
					var desired := Transform3D(reconstructed, position)
					_observe("old_scale_normalized_euler_reconstruction", expected, desired, context)
					var stateless := Basis.from_euler(_normalized_euler(constructed, order), order) * new_scale
					_observe("stateless_normalized_euler_reconstruction", expected, Transform3D(stateless, position), context)
					replacement.transform = desired
					if replacement.scale != original.scale:
						getter_mismatches.scale += 1
					if replacement.rotation != original.rotation:
						getter_mismatches.rotation += 1
					if replacement.quaternion != original.quaternion:
						getter_mismatches.quaternion += 1
					_checks += 1
					if desired != expected and _failures.size() < 10:
						_failures.append("Explicit old-scale/euler reconstruction differed: " + context)
					_repeat(original, position, quaternion, scalar, context)
					if quaternion_index == 1:
						for event in ["same_transform_assignment", "same_basis_assignment", "same_scale_assignment", "same_rotation_assignment", "same_quaternion_assignment", "changed_rotation_order", "changed_rotation_edit_mode", "external_manual_basis", "external_manual_position"]:
							_event_case(order, previous, quaternion, scalar, event)
	# Scale zero is a valid first publication matrix but a singular next basis.
	# Repeated quaternion publication/getters would enter engine decomposition
	# diagnostics, so the clean oracle never normalizes that singular matrix.
	original.transform = Transform3D.IDENTITY
	var zero_scale_matrix := _publish(original, position, rotation, 0.0)
	_checks += 1
	if zero_scale_matrix.basis != Basis.from_scale(Vector3.ZERO):
		_failures.append("First zero-scale publication did not yield a zero basis")
	original.free()
	replacement.free()
	var report := {"success": _failures.is_empty(), "checks": _checks, "cases": cases, "results": _results, "repeated_original_setters": _stability, "external_mutation_boundaries": _events, "getter_mismatches_after_set_transform": getter_mismatches, "failures": _failures, "limitations": ["Zero-length quaternion and singular previous basis excluded because the engine cannot decompose them without diagnostics; zero new scale checked only for its first publication matrix.", "Local transform only; manually owned publication must still be skipped by the actual pose owner.", "Exact result depends on pinned engine arithmetic and must not be inferred from approximate equality.", "A 32-publication observation establishes these tested cases, not a universal fixed-point theorem.", "External boundary tests query live scale before republication; earlier retained receipt without that query is preserved for comparison."]}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)
