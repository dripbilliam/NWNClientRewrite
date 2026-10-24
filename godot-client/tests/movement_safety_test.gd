extends SceneTree
const Motion = preload("res://systems/network_motion.gd")
const Ground = preload("res://systems/ground_height.gd")
var checks := 0
var failures: Array = []
var output := ""
var ground_oracle := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value and failures.size() < 20:
		failures.append(name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
		elif arg.begins_with("--ground="):
			ground_oracle = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/native-drive-ack-completion-v1.json")))
	var case_index := 0
	for row in oracle.cases:
		var mover := Motion.new()
		var actor := {"position": row.before, "orientation": [0.9245460629463196, 0.3810702860355377, 0], "animation": 79, "walkRate": 2200, "runRate": 4400}
		var before := actor.duplicate(true)
		var state := mover.ensure(1, actor)
		state.script = 1
		state.active = true
		state.factor = 1.0
		state.path = row.priorPath.map(Motion.vector)
		state.driveSequence = int(row.lastSequence)
		mover.observe(1, {"actionFlag": row.sequence, "path": row.acknowledged, "animation": 79, "field8F4": 1, "field8EC": 1})
		for frame in row.frames:
			mover.update(0.008)
			for key in ["position", "render"]:
				check(Motion.length32(state[key] - Motion.vector(frame[key])) < 2e-5, "original acknowledgement/completion %s/%s/%s" % [case_index, frame.ms, key])
			check(int(state.script) == int(frame.script) and bool(state.active) == (int(frame.animation) == 79), "original completion ownership %s/%s" % [case_index, frame.ms])
			mover.finish_frame(1)
			check(int(state.animation) == int(frame.animation), "original completion animation %s/%s" % [case_index, frame.ms])
		check(actor == before, "native prediction preserves server input arrays")
		var lifetime := int(state.lifetime)
		mover.observe(1, {"position": [20, 20, 0], "animation": 0}, true, actor)
		check(int(mover.objects[1].lifetime) != lifetime and not mover.objects[1].has("driveSequence"), "same-ID recreation resets stale prediction ownership")
		case_index += 1
	var ground := Ground.new()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ground_oracle))
	ground.configure(fixture.triangles)
	for query in fixture.queries:
		check(absf(ground.height(Motion.vector(query.position), float(query.position[2])) - float(query.height)) < 1e-8, "authored indexed ground height")
	ground.configure([])
	check(ground.height(Vector3(1, 2, 3), 3) == 3, "area teardown removes old height cells")
	var bridge = preload("res://systems/local_connection.gd").new()
	root.add_child(bridge)
	bridge.set_process(false)
	var state: Dictionary = bridge.motion.ensure(1, {"position": [1, 2, 0], "animation": 4, "walkRate": 2200, "runRate": 4400})
	state.script = 1
	state.driveSequence = 2
	bridge.pending_paths[1] = {"waiting": true, "request": 1, "row": {"revision": 1, "changes": {"actionFlag": 1}}, "position": state.position, "render": state.render, "cursor": 0, "path": [], "lifetime": state.lifetime, "script": 1, "sequence": 1}
	bridge._path_result({"actorId": 1, "requestId": 1, "revision": 1, "result": {"path": [[9, 2, 0]]}})
	check(state.path.is_empty() and bridge.pending_paths.is_empty(), "late asynchronous acknowledgement cannot replace a newer drive sequence")
	bridge.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Native retained acknowledgement/completion oracle, immutable authority, new motion lifetimes and authored exact height index; no FPS acceptance", "checks": checks, "failures": failures}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures, "report": output}))
	quit(0 if failures.is_empty() else 1)
