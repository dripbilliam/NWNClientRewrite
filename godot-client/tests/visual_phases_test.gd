extends SceneTree

const Phases = preload("res://systems/visual_phases.gd")
const Clock = preload("res://systems/visual_clock.gd")
var checks := 0
var failed_checks := 0
var failures: Array = []
var output := ""

class Token:
	extends RefCounted
	var id: int
	var kind: String
	func _init(value: int, label: String) -> void:
		id = value
		kind = label

class Fixture:
	extends RefCounted
	var config: Dictionary
	var state: Dictionary
	var trace: Array = []
	var models := {}
	var sounds := {}
	var phase
	var target := true
	var render := true
	var replaced := false

	func _init(value: Dictionary) -> void:
		config = value
		state = Phases.constructor_state()
		state.merge(config.initial.duplicate(true), true)
		state.models88 = config.models.map(model)
		state.extraModelsA0 = config.extra.map(model)
		state.proceduralB8 = model(config.procedural)
		state.controllers128 = {"authored": true}
		var providers := {
			"clientObject": func(id): trace.append(["clientObject", id]); return {"actorToken": 1} if target else null,
			"renderObject": func(_object): trace.append(["renderObject"]); return {"position38": [0.123456789, 12.3456789, -4.7654321]} if render else null,
			"playAnimation": play_animation,
			"animationInfo": func(value, clip): trace.append(["animationInfo", value.id if value != null else null, clip]); return {"length": config.clips.get(str(value.id) if value != null else "", {}).get(clip, 0)},
			"visualString": func(_id, column): trace.append(["visualString", column]); return {"found": true, "value": ("duration" if config.sound else "") if column == "SoundDuration" else ("impact" if column == "SoundImpact" else "cessation")},
			"visualInt": func(_id, column): trace.append(["visualInt", column]); return {"found": true, "value": config.shake},
			"visualFloat": func(_id, column): trace.append(["visualFloat", column]); return {"found": config.shakeFound, "value": 1.234567 if column == "ShakeDuration" else 0.123456789},
			"controlledClient": func(): trace.append(["controlledClient"]); return {"client": true} if config.controlled else null,
			"shakeOnce": func(_client, delay): trace.append(["shakeOnce", delay]),
			"shakeLoop": func(_client, delay, duration): trace.append(["shakeLoop", delay, duration]),
			"positionalSound": func(name, position, height, priority, delay, volume): trace.append(["positionalSound", name, position, height, priority, delay, volume]),
			"createSound": func(name): trace.append(["createSound", name]); return sound(0) if name != "" else null,
			"soundSetting": func(value, name, arg): trace.append(["soundSetting", value.id, name, arg]),
			"playSound": func(value): trace.append(["playSound", value.id]),
			"stopSound": stop_sound,
			"destroySound": func(value, flags): trace.append(["destroySound", value.id, flags]),
			"updateSound": func(value, position, flags): trace.append(["updateSound", value.id, position, flags]),
			"programType": func(_effect, id): trace.append(["programType", id]); return config.types.get(str(id), 0),
			"clearProgram": clear_program,
			"loadProgram": func(effect, id): trace.append(["loadProgram", id]); effect.proceduralB8 = model(config.programModels.get(str(id))),
			"startProgram": func(_effect, id): trace.append(["startProgram", id]),
			"stopProgram": func(_effect, id): trace.append(["stopProgram", id]),
			"updateProgram": func(_effect, id, delta): trace.append(["updateProgram", id, delta]),
			"currentProgram": current_program,
			"setParent": func(value, a, b, c): trace.append(["setParent", value.id, a, b, c]),
			"setScene": func(value, flags): trace.append(["setScene", value.id, flags]),
			"detachProcedural": detach_procedural,
			"unsceneProcedural": func(value, flags): trace.append(["unsceneProcedural", value.id, flags]),
			"destroyProcedural": func(value, flags): trace.append(["destroyProcedural", value.id, flags]),
			"destroyModel": func(value, flags): trace.append(["destroyModel", value.id, flags]),
			"destroyControllers": func(value): trace.append(["destroyControllers", value]),
			"detach": func(effect): trace.append(["detach"]); effect.attached114 = 0,
		}
		phase = Phases.new(state, providers)

	func model(id: Variant) -> Variant:
		if id == null:
			return null
		if not models.has(int(id)):
			models[int(id)] = Token.new(int(id), "model")
		return models[int(id)]

	func sound(id: int) -> Token:
		if not sounds.has(id):
			sounds[id] = Token.new(id, "sound")
		return sounds[id]

	func play_animation(value: Variant, clip: String, speed: float, flags: int, time: float) -> int:
		trace.append(["playAnimation", value.id if value != null else null, clip, speed, flags, time])
		if config.replaceOnImpact and clip == "impact" and not replaced:
			replaced = true
			state.models88[0] = model(3)
		return 1 if value != null and config.clips.get(str(value.id), {}).has(clip) else 0

	func stop_sound(value: Token) -> void:
		trace.append(["stopSound", value.id])
		if config.replaceSound:
			state.sound118 = sound(9)

	func clear_program(effect: Dictionary) -> void:
		trace.append(["clearProgram"])
		if effect.proceduralB8 == null:
			return
		trace.append(["setParent", effect.proceduralB8.id, 0, 0, 0])
		trace.append(["setScene", effect.proceduralB8.id, 0])
		if effect.proceduralB8 != null:
			trace.append(["destroyModel", effect.proceduralB8.id, 1])
		effect.proceduralB8 = null

	func current_program(effect: Dictionary) -> int:
		trace.append(["currentProgram"])
		var active := int(effect.programPhaseFa) & 255
		return int(effect.programsD0[active - 1]) & 65535 if active >= 1 and active <= 3 else 65535

	func detach_procedural(value: Token, a: int, b: int, c: int) -> void:
		trace.append(["detachProcedural", value.id, a, b, c])
		if config.replaceProcedural:
			state.proceduralB8 = model(4)

	func step(operation: Dictionary) -> void:
		trace.clear()
		match operation.kind:
			"start": phase.start()
			"stop": phase.stop(int(operation.requested))
			"update": phase.update_milliseconds(int(operation.delta))
			"dispose": phase.dispose()
			"target": target = operation.value
			"render": render = operation.value
			"patch": state.merge(operation.values.duplicate(true), true)

	func close() -> void:
		phase.providers.clear() # Release callback captures before dropping owner.
		phase = null

func _initialize() -> void:
	call_deferred("run")

func encode(value: Variant) -> Variant:
	if value is Token:
		return {value.kind: value.id}
	if value is Array:
		return value.map(encode)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = encode(value[key])
		return result
	return value

func equal(first: Variant, second: Variant) -> bool:
	# JSON has one number type; GDScript dictionaries hash int/float Variants
	# separately. Compare numeric values recursively without a tolerance.
	if (first is int or first is float) and (second is int or second is float):
		return float(first) == float(second)
	if first is Array and second is Array:
		if first.size() != second.size():
			return false
		for index in first.size():
			if not equal(first[index], second[index]):
				return false
		return true
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size():
			return false
		for key in first:
			if not second.has(key) or not equal(first[key], second[key]):
				return false
		return true
	return typeof(first) == typeof(second) and first == second

func expect(value: bool, label: String, actual: Variant = null, expected: Variant = null) -> void:
	checks += 1
	if not value:
		failed_checks += 1
		if failures.size() < 12:
			failures.append({"label": label, "actual": actual, "expected": expected})

func recorded_case(row: Dictionary, control: bool) -> Dictionary:
	var c: Dictionary = row.case
	var calls: Array = []
	var models: Array = []
	for index in 3:
		models.append(Token.new(index, "model") if not control or c.models[index] else null)
	if not control and c.alias:
		models[2] = models[0]
	var state := Phases.constructor_state()
	if control:
		state.merge({"target54": 123, "visualF8": 456, "closedEc": c.closed, "startedF0": 0, "finishedF4": c.finished, "programPhaseFa": c.phase, "durationFc": c.duration, "scope10c": c.scope, "programType10d": 99, "attached114": c.attached, "programRemainingCc": 77, "sound118": Token.new(0, "sound") if c.sound else null, "proceduralB8": Token.new(3, "model") if c.procedural else null, "models88": models, "modelRemaining5c": [100, 200, 300], "modelStates68": [7, 8, 9], "retireRemainingC0": [11, 22, 33], "retiredDc": [0, 0, 0], "retiringE8": 0, "programsD0": c.programs.duplicate()}, true)
	else:
		state.merge({"target54": 123, "programPhaseFa": c.phase, "durationFc": c.duration, "programRemainingCc": c.programRemaining, "updateProgramD8": c.updateProgram, "attached114": c.attached, "programType10d": 99, "finishedF4": 7, "retiringE8": c.retiring, "sound118": Token.new(0, "sound") if c.sound else null, "models88": models, "modelRemaining5c": c.modelRemaining.duplicate(), "modelStates68": c.states.duplicate(), "programsD0": [10, 20, 30], "retireRemainingC0": c.retireRemaining.duplicate(), "retiredDc": c.retired.duplicate()}, true)
	var p := {
		"clientObject": func(id): calls.append(["client", id]); return {} if c.client else null,
		"renderObject": func(_actor): calls.append(["render"]); return {"position38": [1.25, -2, 3.5]} if c.render else null,
		"playAnimation": func(model, name, speed, flags, time): calls.append(["play", model.id, name, speed, flags, time]); return (0 if name == "duration" else c.plays[model.id]) if control else c.play,
		"animationInfo": func(model, name): calls.append(["info", model.id, name]); return {"length": Phases.f32(float(c.lengths[model.id]))},
		"stopProgram": func(_effect, id): calls.append(["stopProgram", id]),
		"clearProgram": func(_effect): calls.append(["clearProgram"]),
		"programType": func(_effect, id): calls.append(["programType", id]); return c.types.get(str(id), 0) if control else c.type,
		"loadProgram": func(_effect, id): calls.append(["loadProgram", id]),
		"startProgram": func(_effect, id): calls.append(["startProgram", id]),
		"detach": func(_effect): calls.append(["detach"]),
		"visualString": func(id, column): calls.append(["visualString", id, column]); return c.strings[column],
		"visualInt": func(id, column): calls.append(["visualInt", id, column]); return c.queries[column],
		"visualFloat": func(id, column): calls.append(["visualFloat", id, column]); return c.queries[column],
		"controlledClient": func(): calls.append(["controlled"]); return {} if c.controlled else null,
		"shakeOnce": func(_client, delay): calls.append(["shakeOnce", delay]),
		"shakeLoop": func(_client, delay, duration): calls.append(["shakeLoop", delay, duration]),
		"positionalSound": func(name, position, height, priority, delay, volume): calls.append(["positional", name, position, height, priority, delay, volume]),
		"createSound": func(name): calls.append(["createSound", name]); return Token.new(0, "sound") if c.soundAlloc else null,
		"soundSetting": func(_sound, name, value): calls.append(["soundSetting", name, value]),
		"playSound": func(_sound): calls.append(["playSound"]),
		"stopSound": func(_sound): calls.append(["stopSound"]),
		"destroySound": func(_sound, flags): calls.append(["destroySound", flags]),
		"detachProcedural": func(_model, a, b, d): calls.append(["detachProcedural", a, b, d]),
		"unsceneProcedural": func(_model, flags): calls.append(["unsceneProcedural", flags]),
		"destroyProcedural": func(_model, flags): calls.append(["destroyProcedural", flags]),
		"currentProgram": func(_effect): calls.append(["currentProgram"]); return c.current,
		"updateProgram": func(_effect, id, delta): calls.append(["updateProgram", id, delta]),
		"updateSound": func(_sound, position, flags): calls.append(["sound", position, flags]),
	}
	var native := Phases.new(state, p)
	if control:
		if c.mode == "start":
			native.start()
		else:
			native.stop(int(c.requested))
	else:
		native.update_milliseconds(int(c.delta))
	var actual := {"calls": calls, "phase": state.programPhaseFa, "type": state.programType10d, "programRemaining": state.programRemainingCc, "modelRemaining": state.modelRemaining5c, "states": state.modelStates68, "retireRemaining": state.retireRemainingC0, "retired": state.retiredDc, "finished": state.finishedF4, "retiring": state.retiringE8}
	if control:
		actual.merge({"closed": state.closedEc, "started": state.startedF0, "sound": 1 if state.sound118 != null else 0, "procedural": 1 if state.proceduralB8 != null else 0})
	native.providers.clear()
	return actual

func retained_phase_state(value: Dictionary) -> Dictionary:
	# Schema extension only: these phase-only provider fixtures never run the
	# Alpha5 program. Its separately proved constructor byte must remain zero.
	var result:=value.duplicate(true);result.alphaPhaseFb=0;return result

func run() -> void:
	var oracle_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):
			oracle_path = arg.substr(9)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	# The older retained JS schema omitted byteFB. Original constructor968660
	# instruction96875a clears DWORDF8, independently proving alphaPhaseFb=0.
	# Keep every older oracle field exact while extending that schema explicitly.
	var constructor_reference: Dictionary=oracle.constructorState.duplicate(true)
	constructor_reference.alphaPhaseFb=0
	expect(equal(Phases.constructor_state(), constructor_reference), "Constructor logical fields including original byteFB agree with original owner")
	for sample in oracle.milliseconds:
		var seconds := NAN if sample.value == "NaN" else (INF if sample.value == "Infinity" else (-INF if sample.value == "-Infinity" else float(sample.value)))
		expect(str(Phases.milliseconds_long(seconds)) == sample.long, "Signed 64-bit millisecond conversion " + sample.value, str(Phases.milliseconds_long(seconds)), sample.long)
		expect(Phases.milliseconds(seconds) == int(sample.dword), "Low DWORD conversion " + sample.value)
	for scenario in oracle.cases:
		var fixture := Fixture.new(scenario.config)
		for index in scenario.steps.size():
			var step: Dictionary = scenario.steps[index]
			fixture.step(step.operation)
			var actual_trace: Array = encode(fixture.trace)
			var actual_state: Dictionary = encode(fixture.state)
			var label := "%s/%s/%s" % [scenario.name, index, step.operation.kind]
			expect(equal(actual_trace, step.trace), label + " callback order/arguments", actual_trace, step.trace)
			var expected_state:=retained_phase_state(step.state)
			expect(equal(actual_state, expected_state), label + " full state", actual_state, expected_state)
			expect(fixture.phase.is_retired() == step.retired, label + " retirement")
			expect(fixture.phase.has_cessation() == step.cessation, label + " cessation")
		fixture.close()
	var clock_steps := 0
	for scenario in oracle.get("clocks", []):
		var fixture := Fixture.new(scenario.config)
		var clock := Clock.new()
		root.add_child(clock)
		clock.set_process(false)
		clock.configure(fixture.phase)
		expect(not clock.advance(0.1), "Clock does not run before explicit start")
		clock.start()
		expect(equal(encode(fixture.trace), scenario.start.trace), "Clock starts the original phase owner")
		for step in scenario.steps:
			fixture.trace.clear()
			var delta: float = str(step.deltaBits).hex_decode().decode_double(0)
			var expected_elapsed: float = str(step.elapsedBits).hex_decode().decode_double(0)
			expect(clock.advance(delta), "Valid native frame is accepted")
			expect(equal(encode(fixture.trace), step.trace), "Native clock preserves original update callbacks")
			expect(equal(encode(fixture.state), retained_phase_state(step.state)), "Native clock preserves phase state")
			expect(clock.elapsed_ms == expected_elapsed and clock.previous_ms == float(step.previous) and clock.frames == int(step.frames), "Fractional frame time and DWORD wrapping agree", clock.elapsed_ms, expected_elapsed)
			clock_steps += 1
		var elapsed: float = clock.elapsed_ms
		expect(not clock.advance(NAN) and not clock.advance(-1) and not clock.advance(INF) and clock.elapsed_ms == elapsed, "Invalid deltas cannot corrupt the frame clock")
		var id := clock.get_instance_id()
		clock.close()
		clock.close()
		await process_frame
		await process_frame
		expect(not is_instance_id_valid(id) and fixture.phase.disposed, "Closing the clock releases its phase owner once")
		fixture.close()
	var live := Fixture.new(oracle.cases[0].config)
	var frame_clock := Clock.new()
	root.add_child(frame_clock)
	frame_clock.configure(live.phase)
	frame_clock.start()
	for index in 5:
		await process_frame
	expect(frame_clock.frames >= 3, "Godot's actual process loop advances the visual clock without network input")
	frame_clock.close()
	await process_frame
	await process_frame
	live.close()
	var original_cases := 0
	for group in ["control", "update"]:
		var record_path := ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-visual-phase-%s-observations.json" % group).simplify_path()
		var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(record_path))
		expect(recorded.binarySha256 == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a", "Recorded original build identity " + group)
		for row in recorded.rows:
			var expected: Dictionary = row.duplicate(true)
			expected.erase("case")
			var actual := recorded_case(row, group == "control")
			expect(equal(actual, expected), "Recorded original phase %s/%s" % [group, original_cases], actual, expected)
			original_cases += 1
	var report := {"scope": "Native phase lifecycle and frame clock; authored source differential plus retained original-function observations, not fresh live binary profiling or effect/GPU acceptance", "success":failed_checks==0,"passed": failed_checks == 0, "checks": checks, "cases": oracle.cases.size(), "steps": 2400, "clock_steps": clock_steps, "recorded_original_cases": original_cases, "failed_checks": failed_checks, "failures": failures}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit(0 if failed_checks == 0 else 1)
