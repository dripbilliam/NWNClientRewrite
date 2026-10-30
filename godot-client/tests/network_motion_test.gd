extends SceneTree

const Motion = preload("res://systems/network_motion.gd")
var output := ""
var failed: Array = []
var checks := 0
var maximum_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/" + name)))

func compare(value: float, expected: float, tolerance: float, context: String) -> void:
	checks += 1
	maximum_error = maxf(maximum_error, absf(value - expected))
	if absf(value - expected) > tolerance and failed.size() < 20:
		failed.append({"case": context, "actual": value, "expected": expected})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var mover := Motion.new()
	mover.height_query = func(point, _previous): return point.z
	var movement := fixture("native-network-motion-observations.json")
	var index := 0
	for row in movement.cases:
		var c: Dictionary = row.case
		var state := {"position": Motion.vector(c.position), "render": Motion.vector(c.render), "path": c.path.map(Motion.vector), "cursor": 0, "orientation": Vector3(1, 0, 0), "animation": int(c.animation), "walkRate": float(c.rate), "runRate": float(c.rate), "script": int(c.script), "factor": float(c.factor), "acceleration": float(c.acceleration), "newPath": int(c.newPath), "correction": int(c.correction)}
		var distance := Motion.distance(state, int(c.dt))
		var step := mover.step_path(state, float(distance.distance))
		state.position = step.position
		state.render = Motion.correct(state, step.position, int(c.dt))
		for key in ["position", "render"]:
			for axis in 3:
				compare(float(state[key][axis]), float(row[key][axis]), 2e-5, "motion/%s/%s/%s" % [index, key, axis])
		compare(float(state.cursor), float(row.cursor), 0, "cursor/%s" % index)
		compare(0 if step.done else float(state.acceleration), float(row.acceleration), 2e-6, "acceleration/%s" % index)
		compare(float(state.correction), float(row.correction), 0, "correction/%s" % index)
		index += 1
	for filename in ["native-network-facing-observations.json", "native-network-facing-stalls-observations.json"]:
		index = 0
		for row in fixture(filename).cases:
			var c: Dictionary = row.case
			var result := Motion.facing_step(Motion.vector(c.orientation), Motion.vector(c.target), int(c.animation), int(c.dt), c)
			for key in ["orientation", "target"]:
				for axis in 3:
					compare(float(result[key][axis]), float(row[key][axis]), 2e-6, "%s/%s/%s/%s" % [filename, index, key, axis])
			compare(float(result.requests.size()), float(row.requests.size()), 0, "requests-size/%s/%s" % [filename, index])
			if result.requests.size() == row.requests.size():
				for i in result.requests.size():
					compare(float(result.requests[i]), float(row.requests[i]), 0, "requests/%s/%s" % [filename, index])
			index += 1
	index = 0
	for row in fixture("native-network-gait-observations.json").cases:
		var c: Dictionary = row.case
		mover.objects[1] = {"active": true, "animation": int(c.animation), "walkDistance": c.distance, "runDistance": c.distance, "scale": c.scale, "scale2": c.scale, "gait": {"rate": c.rate, "script": c.script, "factor": c.factor, "acceleration": row.acceleration}}
		compare(mover.gait_speed(1, float(c.clipMs) / 1000.0), float(row.draws[0].speed), 1e-5, "gait/%s" % index)
		index += 1
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failed.is_empty(),"scope": "Native Godot movement/facing/gait against retained original-binary observations; no live server or FPS acceptance", "target": movement.target, "checks": checks, "failures": failed, "maximum_error": maximum_error, "motion_cases": movement.cases.size(), "facing_cases": 1272, "gait_cases": 2916}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failed.size(), "maximum_error": maximum_error, "report": output}))
	quit(0 if failed.is_empty() else 1)
