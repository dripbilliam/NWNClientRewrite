extends SceneTree

var report_path := ""
var checks := 0
var failures: Array = []
var witness: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func run() -> void:
	var expect_missing := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument == "--expect-missing-registry": expect_missing = true
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	var focus_script = load("res://systems/native_render/focus_lighting_builtin_input_candidate.gd")
	var owner = focus_script.new()
	var registry: Object = owner.input_registry
	witness.registry_present = is_instance_valid(registry)
	witness.registry_class = registry.get_class() if is_instance_valid(registry) else null
	if expect_missing:
		check(not is_instance_valid(registry), "Frozen default adapter reproduces missing inherited registry")
		owner.close()
		owner.free()
	else:
		var expected := "NwnBuiltinLightInputRegistry" if OS.get_cmdline_user_args().has("--light-input-registry=builtin") else "NwnLightInputRegistry"
		check(is_instance_valid(registry), "Constructor creates registry before world configure")
		if is_instance_valid(registry):
			check(registry.get_class() == expected, "Actual selected registry class")
			var room := Node3D.new()
			root.add_child(room)
			room.set_meta("native_enhanced_lighting", true)
			room.add_child(owner)
			owner.configure(room)
			owner.set_process(false)
			owner.enable_history(2)
			check(owner.history != null, "World configure and enable_history create actual history without registry injection")
			var source := Node3D.new()
			source.set_meta("native_light_source", true)
			room.add_child(source)
			var point = load("res://systems/native_render/model_point_light.gd").new()
			point.set_meta("native_enhanced_light", true)
			point.configure({"color": [0.8, 0.4, 0.2], "radius": 8.0, "multiplier": 1.0, "isdynamic": 1, "affectdynamic": 1})
			source.add_child(point)
			owner.register(point)
			check(owner.members.has(point.get_instance_id()), "Actual point registration")
			owner.history_frame(0.1)
			check(owner.history_error.is_empty(), "Actual registration/history poll has no registry error")
			check(owner.snapshot().input_registry_class == expected, "Root diagnostic snapshot observes same actual registry")
			owner.unregister(point)
			check(not owner.members.has(point.get_instance_id()), "Actual point removal")
			owner.close()
			check(owner.input_registry == null, "Close retires actual registry")
			room.free()
		else:
			owner.free()
	var output := {"success": failures.is_empty(), "checks": checks, "failures": failures, "witness": witness, "gpu": false, "server_connections": 0}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
