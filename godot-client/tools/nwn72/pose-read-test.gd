extends SceneTree

const Motion = preload("res://systems/network_motion.gd")
var report_path := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty():
		quit(2)
		return
	var motion := Motion.new()
	var checks := 0
	var failures: Array[String] = []
	checks += 1
	if not motion.pose(1).is_empty(): failures.append("missing id")
	for i in 2048:
		var render_position := Vector3(sin(float(i) * 0.43), cos(float(i) * 0.17), sin(float(i) * -0.29))
		var orientation := Vector3(cos(float(i) * 0.071), sin(float(i) * 0.043), 0)
		if i % 31 == 0:
			render_position = Vector3(-0.0, 0.0, -0.0)
			orientation = Vector3(0.0, -0.0, 0.0)
		var state := {"render": render_position, "orientation": orientation}
		motion.objects[1] = state
		var before := var_to_bytes(state)
		var expected := {"position": Vector3(state.render.x, state.render.z, -state.render.y), "rotation": -atan2(state.orientation.x, state.orientation.y)}
		var actual: Dictionary = motion.pose(1)
		checks += 2
		if var_to_bytes(actual) != var_to_bytes(expected) and failures.size() < 10: failures.append("pose %d" % i)
		if var_to_bytes(state) != before and failures.size() < 10: failures.append("input mutation %d" % i)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"issue":"NWN-72", "checks":checks, "passed":failures.is_empty(), "failures":failures, "scope":"Exact pose bytes and unchanged state, no FPS"}, "  ") + "\n")
	file.close()
	print(JSON.stringify({"checks":checks, "failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
