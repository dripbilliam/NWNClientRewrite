extends RefCounted

# Native-frame counterpart of visual_phase_control.js / visual_phase_update.js.
# Field offsets retain the reviewed original owner identity. Assets, playback,
# placement/programs and audio remain explicit synchronous platform providers.
var state: Dictionary
var providers: Dictionary
var disposed := false
static var scalar_values:=preload("res://systems/native_data/scalar_representation.gd").configured()

func _init(value: Dictionary, services: Dictionary) -> void:
	state = value
	providers = services

static func constructor_state() -> Dictionary:
	return {"vector18": [0, 0, 0], "sourceAnchor28": "", "targetAnchor38": "", "point48": [0, 0, 0], "target54": 0x7f000000, "source58": 0x7f000000,
		"modelRemaining5c": [0, 0, 0], "modelStates68": [0, 0, 0], "models88": [null, null, null], "extraModelsA0": [null, null, null], "proceduralB8": null,
		"retireRemainingC0": [0, 0, 0], "programRemainingCc": 0, "programsD0": [0, 0, 0], "updateProgramD8": 0, "retiredDc": [0, 0, 0], "retiringE8": 0,
		"closedEc": 0, "startedF0": 0, "finishedF4": 0, "visualF8": 0, "programPhaseFa": 0, "alphaPhaseFb": 0, "durationFc": 0, "field100": 1, "field104": 0, "shadow108": 0,
		"scope10c": 0, "programType10d": 0, "field110": 0, "attached114": 0, "sound118": null, "orient120": 0, "controllers128": null}

static func f32(value: float) -> float:
	return Color(value,0,0,0).r if scalar_values else PackedFloat32Array([value])[0]

static func milliseconds_long(seconds: float) -> int:
	var value := f32(f32(seconds) * 1000.0)
	# CVTTSS2SI is a signed 64-bit conversion followed by a low-DWORD store.
	if not is_finite(value) or value < -9223372036854775808.0 or value >= 9223372036854775808.0:
		return -9223372036854775807 - 1
	return int(value)

static func milliseconds(seconds: float) -> int:
	return milliseconds_long(seconds) & 0xffffffff

func _call(method: String, args: Array = []) -> Variant:
	assert(providers.has(method), "Native visual provider unavailable: " + method)
	return providers[method].callv(args)

func _word(index: int) -> int:
	return int(state.programsD0[index]) & 65535

func _render() -> Variant:
	var target: Variant = _call("clientObject", [state.target54])
	return _call("renderObject", [target]) if target != null else null

func _visual_string(column: String) -> String:
	var entry: Dictionary = _call("visualString", [int(state.visualF8) & 65535, column])
	return str(entry.value) if entry.found else ""

func _positional(name: String, render: Variant) -> void:
	_call("positionalSound", [name, render.position38.map(func(value): return f32(float(value))), f32(1.5), 11, 0, 0])

# Start/restart140970e20..14097152b. No browser or network tick owns this clock.
func start() -> void:
	if disposed or not state.closedEc or state.finishedF4:
		return
	state.startedF0 = 1
	for index in 3:
		state.modelRemaining5c[index] = 0
		var model: Variant = state.models88[index]
		if model == null:
			continue
		if _call("playAnimation", [model, "impact", 1, 1, 0]):
			state.modelStates68[index] = 1
			var info: Dictionary = _call("animationInfo", [state.models88[index], "impact"])
			state.modelRemaining5c[index] = milliseconds(float(info.length))
		elif (int(state.durationFc) & 255) == 1:
			state.modelStates68[index] = 2
			_call("playAnimation", [state.models88[index], "duration", 1, 0, 0])
		else:
			state.modelStates68[index] = 1
			state.modelRemaining5c[index] = 1000
	state.programPhaseFa = 0
	for index in 3:
		if _word(index) != 65535:
			_call("clearProgram", [state])
			_call("loadProgram", [state, _word(index)])
			_call("startProgram", [state, _word(index)])
			state.programPhaseFa = index + 1
			state.programType10d = int(_call("programType", [state, _word(index)])) & 255
			break
	if (int(state.scope10c) & 255) == 0:
		var type: Dictionary = _call("visualInt", [int(state.visualF8) & 65535, "ShakeType"])
		var duration: Dictionary = _call("visualFloat", [int(state.visualF8) & 65535, "ShakeDuration"])
		var delay: Dictionary = _call("visualFloat", [int(state.visualF8) & 65535, "ShakeDelay"])
		var kind := int(type.value) if type.found else 0
		var seconds := f32(float(duration.value)) if duration.found else 0.0
		var wait := f32(float(delay.value)) if delay.found else 0.0
		if _call("controlledClient") != null:
			if kind == 1:
				_call("shakeOnce", [_call("controlledClient"), milliseconds_long(wait)])
			elif kind == 2:
				_call("shakeLoop", [_call("controlledClient"), milliseconds_long(wait), milliseconds_long(seconds)])
	var render: Variant = _render()
	var impact := _visual_string("SoundImpact")
	var duration_sound := _visual_string("SoundDuration")
	if render != null:
		_positional(impact, render)
	state.sound118 = _call("createSound", [duration_sound])
	if state.sound118 != null:
		_call("soundSetting", [state.sound118, "setting1401d9e90", 1])
		_call("soundSetting", [state.sound118, "setting1401da060", 11])
		_call("soundSetting", [state.sound118, "setting1401d9f90", 1])
		_call("playSound", [state.sound118])
	state.closedEc = 0

# Stop/cessation140971530..140971955. Preserve writes to retirement slot ZERO
# inside every physical model iteration; do not regularize this native quirk.
func stop(requested: int = 1) -> void:
	if disposed:
		return
	state.finishedF4 = requested
	if state.closedEc:
		return
	state.closedEc = 1
	var played := false
	for index in 3:
		state.modelRemaining5c[index] = 0
		var model: Variant = state.models88[index]
		if model == null:
			continue
		var info: Dictionary = _call("animationInfo", [model, "cessation"])
		if _call("playAnimation", [state.models88[index], "cessation", 1, 1, 0]):
			state.modelStates68[index] = 3
			var length := milliseconds(float(info.length))
			state.modelRemaining5c[index] = length
			state.retireRemainingC0[0] = (length + 3000) & 0xffffffff
			played = true
		else:
			state.retiredDc[0] = 1
			state.retireRemainingC0[0] = 3000
	if requested != 0 and not played:
		state.retiringE8 = 1
	if (int(state.programPhaseFa) & 255) == 2:
		if (int(_call("programType", [state, _word(1)])) & 255) != 4 or (int(_call("programType", [state, _word(2)])) & 255) != 4:
			_call("stopProgram", [state, _word(1)])
			if state.proceduralB8 != null:
				_call("detachProcedural", [state.proceduralB8, 0, 0, 0])
				_call("unsceneProcedural", [state.proceduralB8, 0])
				if state.proceduralB8 != null:
					_call("destroyProcedural", [state.proceduralB8, 1])
				state.proceduralB8 = null
		if _word(2) == 65535:
			state.programPhaseFa = 0
		else:
			state.programPhaseFa = 3
			state.programType10d = int(_call("programType", [state, _word(2)])) & 255
			state.programRemainingCc = 1000
	if _word(2) != 65535:
		if (int(_call("programType", [state, _word(1)])) & 255) != 4 or (int(_call("programType", [state, _word(2)])) & 255) != 4:
			_call("loadProgram", [state, _word(2)])
		_call("startProgram", [state, _word(2)])
	var render: Variant = _render()
	var cessation := _visual_string("SoundCessation")
	if render != null:
		_positional(cessation, render)
	if state.sound118 != null:
		_call("stopSound", [state.sound118])
		if state.sound118 != null:
			_call("destroySound", [state.sound118, 1])
		state.sound118 = null
	if state.attached114:
		_call("detach", [state])

# Update140971a80..140971e10. Unsigned milliseconds and physical pointer alias
# comparisons are retained, including callback-driven field replacement.
func update_milliseconds(delta: int) -> void:
	assert(delta >= 0 and delta <= 0xffffffff, "Visual phase delta must be a DWORD")
	if disposed:
		return
	var object: Variant = _call("clientObject", [state.target54])
	if object == null:
		return
	var render: Variant = _call("renderObject", [object])
	if render == null:
		return
	var phase := int(state.programPhaseFa) & 255
	if phase == 1 or phase == 3:
		var remaining := int(state.programRemainingCc) & 0xffffffff
		if remaining <= delta:
			state.programRemainingCc = 0
			if phase == 1:
				_call("stopProgram", [state, _word(0)])
				_call("clearProgram", [state])
				if (int(state.durationFc) & 255) == 0:
					state.programPhaseFa = 0
					state.finishedF4 = 1
				else:
					state.programPhaseFa = 2
					state.programType10d = int(_call("programType", [state, _word(1)])) & 255
					_call("loadProgram", [state, _word(1)])
					_call("startProgram", [state, _word(1)])
					if not state.attached114:
						_call("detach", [state])
			else:
				if state.attached114:
					_call("stopProgram", [state, _word(2)])
				_call("clearProgram", [state])
				state.programPhaseFa = 0
		else:
			state.programRemainingCc = (remaining - delta) & 0xffffffff
			if state.updateProgramD8 and state.attached114:
				_call("updateProgram", [state, _call("currentProgram", [state]), delta])
	elif phase == 2 and state.updateProgramD8 and state.attached114:
		_call("updateProgram", [state, _word(1), delta])
	for index in 3:
		var remaining := int(state.modelRemaining5c[index]) & 0xffffffff
		if remaining == 0:
			continue
		state.finishedF4 = 0
		if remaining > delta:
			state.modelRemaining5c[index] = (remaining - delta) & 0xffffffff
			continue
		state.modelRemaining5c[index] = 0
		var model_state := int(state.modelStates68[index]) & 65535
		if model_state == 1 and (int(state.durationFc) & 255) != 0:
			state.modelStates68[index] = 2
			_call("playAnimation", [state.models88[index], "duration", 1, 0, 0])
		elif model_state == 1 or model_state == 3:
			for alias in 3:
				if is_same(state.models88[alias], state.models88[index]):
					state.retireRemainingC0[alias] = 3000
					break
			state.finishedF4 = 1
			state.retiringE8 = 1
	if state.sound118 != null:
		_call("updateSound", [state.sound118, render.position38.map(func(value): return f32(float(value))), 0])
	if state.retiringE8:
		for index in 3:
			if not state.retiredDc[index]:
				var remaining := int(state.retireRemainingC0[index]) & 0xffffffff
				if remaining <= delta:
					state.retiredDc[index] = 1
				else:
					state.retireRemainingC0[index] = (remaining - delta) & 0xffffffff

func is_retired() -> bool:
	return disposed or (state.retiredDc.all(func(value): return value != 0) and state.finishedF4 != 0 and (int(state.programPhaseFa) & 255) == 0)

func has_cessation() -> bool:
	for index in 3:
		if state.models88[index] != null and (int(state.modelStates68[index]) & 65535) == 3:
			return true
	return false

func dispose() -> void:
	if disposed:
		return
	disposed = true
	if state.sound118 != null:
		_call("destroySound", [state.sound118, 1])
	# Cleanup calls the lower clear owner directly, not the phase-level
	# clearProgram callback. Re-read B8 after each platform callback.
	if state.proceduralB8 != null:
		_call("setParent", [state.proceduralB8, 0, 0, 0])
		_call("setScene", [state.proceduralB8, 0])
		if state.proceduralB8 != null:
			_call("destroyModel", [state.proceduralB8, 1])
		state.proceduralB8 = null
	for index in 3:
		if state.models88[index] != null:
			_call("destroyModel", [state.models88[index], 1])
			state.models88[index] = null
		if state.extraModelsA0[index] != null:
			_call("destroyModel", [state.extraModelsA0[index], 1])
			state.extraModelsA0[index] = null
	_call("destroyControllers", [state.controllers128])
	state.sourceAnchor28 = ""
	state.targetAnchor38 = ""
