extends SceneTree
const Alpha = preload("res://tools/native_parity/visibility/alpha_program.gd")
var checks := 0
var failures: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 32: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report_path := ""
	var oracle_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
		if argument.begins_with("--oracle="): oracle_path = argument.substr(9)
	var oracle: Variant = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle is Dictionary and oracle.get("binarySha256") == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", "oracle binary")
	var compared := 0
	if oracle is Dictionary:
		for row in oracle.get("rows", []):
			var input: Dictionary = row.case
			var initial: Dictionary = Alpha.state_value(input.state)
			var before := initial.duplicate(true)
			var available: bool = input.object_present and input.view_present
			var result: Dictionary
			if input.operation == "load": result = Alpha.load_program(initial, input.program)
			elif input.operation == "attach": result = Alpha.attach(initial, input.program, available)
			elif input.operation == "update": result = Alpha.update(initial, input.program, input.elapsed_ms, available)
			else: result = Alpha.stop(input.program, input.update_enabled != 0, available)
			check(result.available, "available/%s" % compared)
			var actual: Array = []
			var pre_publish: Variant = null
			for event in row.calls:
				if event.kind in ["lookup", "view", "query"]: continue
				var plain: Dictionary = event.duplicate(true)
				if plain.has("state_before"):
					pre_publish = Alpha.state_value(plain.state_before)
					plain.erase("state_before")
				if plain.has("alpha_word"): plain.alpha_word = int(plain.alpha_word)
				if plain.has("scope"): plain.scope = int(plain.scope)
				if plain.has("channel"): plain.channel = int(plain.channel)
				if plain.has("vector_words"): plain.vector_words = plain.vector_words.map(func(value): return int(value))
				if plain.has("flags"): plain.flags = plain.flags.map(func(value): return int(value))
				actual.append(plain)
			check(result.commands == actual, "commands/%s/%s expected%s got%s" % [compared, input.operation, str(actual), str(result.commands)])
			var final_state: Dictionary = result.get("state", initial).duplicate(true)
			if input.operation == "update" and pre_publish != null:
				check(final_state == pre_publish, "pre-publication state/%s" % compared)
			if input.operation == "update" and result.counter_delta_after_publish != null:
				if input.get("callback_counter") != null: final_state.counter_ms = int(input.callback_counter)
				final_state = Alpha.complete_update(final_state, result.counter_delta_after_publish)
			check(final_state == Alpha.state_value(row.state), "state/%s/%s expected%s got%s" % [compared, input.operation, str(row.state), str(final_state)])
			check(initial == before, "input mutation/%s" % compared)
			compared += 1
	var empty_program := {"integer": {}, "float": {}}
	var valid := {"alpha_word": Alpha.ONE_WORD, "minimum_word": Alpha.word(0.5), "counter_ms": 123, "phase": 0}
	check(not Alpha.update({}, empty_program, 0, true).available, "missing state explicit")
	check(not Alpha.update(valid, {}, 0, true).available, "missing table explicit")
	for elapsed in [null, -1, 1.5, INF, NAN, 4294967296, "1"]:
		check(not Alpha.update(valid, empty_program, elapsed, true).available, "elapsed validation")
	var detached := Alpha.update(valid, empty_program, 0, true)
	detached.state.alpha_word = 0
	detached.commands[0].alpha_word = 0
	check(valid.alpha_word == Alpha.ONE_WORD, "detached data")
	var effect := {"type": 5, "finished": 0, "attached": 1, "scope": 1, "alpha_word": Alpha.word(0.25)}
	var second := effect.duplicate(true)
	second.alpha_word = Alpha.word(0.75)
	var selected := Alpha.select_alpha([effect, second])
	check(selected.available and selected.selected.index == 1 and selected.alpha_word == second.alpha_word, "backward tie order")
	second.scope = 0
	check(Alpha.select_alpha([second, effect]).selected.index == 0, "lower scope wins")
	second.scope = 255
	check(Alpha.select_alpha([second]).selected == null, "scope255 excluded")
	second.scope = 0
	second.finished = 1
	check(Alpha.select_alpha([second]).selected == null, "finished excluded")
	second.finished = 0
	second.attached = 0
	check(Alpha.select_alpha([second]).selected == null, "detached excluded")
	check(Alpha.select_alpha([]).alpha_word == Alpha.word(-1.0), "no selected native sentinel")
	check(not Alpha.select_alpha([{}]).available, "missing selection fields explicit")
	var report := {"checks": checks, "failures": failures, "original_cases_compared": compared, "scope": "Pure load/attach/update/stop commands and original CPU body state; no renderer/network/clock/lifetime integration"}
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
