extends SceneTree
const World = preload("res://systems/particle_world.gd")
const Rigs = preload("res://systems/model_rigs.gd")
class Client extends Node:
	var pivots := {}
	var content_revisions := {1: 10, 2: 20}
	var removed_states := {}
var checks := 0
var failures: Array = []
var maximum_error := 0.0
func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture_path := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):
			fixture_path = arg.substr(9)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	for source in oracle.cases:
		var host := Node3D.new()
		root.add_child(host)
		var client := Client.new()
		host.add_child(client)
		var world := World.new()
		host.add_child(world)
		world.set_process(false)
		world.client = client
		var rigs := Rigs.new()
		host.add_child(rigs)
		rigs.set_process(false)
		world.rigs = rigs
		var pivot := Node3D.new()
		host.add_child(pivot)
		client.pivots[2] = pivot
		var anchor := Node3D.new()
		host.add_child(anchor)
		var direct := Node3D.new()
		host.add_child(direct)
		rigs.entities[2] = {"nodes": [pivot, anchor, direct]}
		var endpoint: Dictionary = source.descriptor.referenceTarget
		for frame in source.frames:
			pivot.global_transform = world._transform(frame.pivot)
			anchor.global_transform = world._transform(frame.anchor)
			direct.global_transform = world._transform(frame.expected)
			var actual: Variant = world._reference_pose(endpoint)
			check(actual is Array and actual.size() == 16, "Original reference endpoint resolves its native attachment")
			if actual is Array:
				var error := 0.0
				for i in 16:
					error = maxf(error, absf(float(actual[i]) - float(frame.expected[i])))
				maximum_error = maxf(maximum_error, error)
				check(error < 0.00002, "Original attachment matrix agrees for %s flags%s error%s" % [source.mode, source.flags, error])
				check(is_equal_approx(world._transform(actual).basis.get_scale().x, 0.65), "Referenced model scale is retained without inheriting anchor scale")
			var direct_endpoint := {"matrix": frame.expected, "nativeRoot": {"objectId": 2, "rigNode": 2, "modelIndex": 0, "revision": 20}}
			var direct_result: Array = world._reference_pose(direct_endpoint)
			check(world._transform(direct_result).is_equal_approx(direct.global_transform), "A transferred reference root uses its actual native transform")
		client.content_revisions[2] = 21
		check(world._reference_pose(endpoint) == null, "Same object ID with replaced model revision cannot claim the old endpoint")
		client.content_revisions[2] = 20
		client.removed_states[2] = true
		check(world._reference_pose(endpoint) == null, "Removed canonical target cannot produce an endpoint pose")
		client.removed_states.clear()
		rigs.entities.erase(2)
		client.pivots.erase(2)
		check(world._reference_pose(endpoint) == null, "Missing physical ownership cannot fall back to stale captured target coordinates")
		host.free()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "maximum_matrix_error": maximum_error, "scope": oracle.scope}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
