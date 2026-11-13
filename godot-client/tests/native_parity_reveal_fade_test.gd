extends SceneTree
const Alpha = preload("res://tools/native_parity/visibility/alpha_program.gd")
const Fade = preload("res://tools/native_parity/visibility/reveal_fade.gd")
var checks := 0
var failures: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 24: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report_path := ""
	var oracle_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
		if argument.begins_with("--oracle="): oracle_path = argument.substr(9)
	var oracle: Variant = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle is Dictionary and oracle.get("binarySha256") == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", "oracle identity")
	var target_cases := 0
	var fade_cases := 0
	if oracle is Dictionary:
		for row in oracle.get("rows", []):
			var input: Dictionary = row.case
			if input.operation == "target":
				var result := Fade.target_alpha(input.input)
				check(result.available and result.alpha_word == int(row.alpha_word), "target/%s expected%s got%s" % [target_cases, str(row.alpha_word), str(result)])
				target_cases += 1
			else:
				var original: Dictionary = input.state.duplicate(true)
				var result := Fade.update(input.state, input.timing, input.targets, input.render_owner_present)
				check(result.available, "fade available/%s" % fade_cases)
				check(result.state == Fade.state_value(row.state), "fade state/%s expected%s got%s" % [fade_cases, str(row.state), str(result.state)])
				check(result.completion_requested == row.completion_requested and result.target_query_count == int(row.target_queries), "fade queries/completion/%s" % fade_cases)
				var commands: Array = []
				for event in row.calls:
					if event.kind in ["set_alpha", "render_owner_virtual8"]:
						var command: Dictionary = event.duplicate(true)
						for key in ["scope", "alpha_word", "argument"]:
							if command.has(key): command[key] = int(command[key])
						commands.append(command)
				check(commands == result.commands, "fade commands/%s expected%s got%s" % [fade_cases, str(commands), str(result.commands)])
				check(input.state == original, "fade input detached/%s" % fade_cases)
				fade_cases += 1
	check(not Fade.target_alpha({}).available, "missing target explicit")
	check(not Fade.update({}, {}, [], false).available, "missing fade state explicit")
	var hidden := {"is_creature": false, "revealed": 0}
	check(Fade.target_alpha(hidden).available and Fade.target_alpha(hidden).alpha_word == 0, "unused override may be unavailable")
	var present := {"is_creature": true, "revealed": 1, "player_info_present": true, "matching_perception_present": true, "perception": [1.0, 0.0, 0.0]}
	check(Fade.target_alpha(present).available and Fade.target_alpha(present).alpha_word == Alpha.word(0.5), "bridge floating wire flags")
	present.perception = null
	check(not Fade.target_alpha(present).available, "missing triple not false")
	var state := {"status": 2, "desired": 1, "opacity_word": 0, "expiry_enabled": 0, "expiry_ms": 0, "start_day": 0, "start_ms": 0}
	check(not Fade.update(state, {}, [Alpha.ONE_WORD], true).available, "missing snapshot explicit")
	var result := Fade.update(state, {"snapshot_us": 1000}, [Alpha.ONE_WORD], true)
	result.state.opacity_word = Alpha.ONE_WORD
	check(state.opacity_word == 0, "detached output")
	var report := {"checks": checks, "failures": failures, "original_target_cases": target_cases, "original_fade_cases": fade_cases, "scope": "Pure target/reveal fade versus complete original CPU bodies; WorldTimer and renderer captured"}
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
