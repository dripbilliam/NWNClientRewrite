extends RefCounted
# Pure Type5 temporal kernel. No timer, table cache, object registry or renderer.
# Native DWORD/f32 words avoid inventing missing fields and preserve signed zero.
# The caller supplies the existing effect owner's delta in milliseconds.
const UINT32_MAX := 4294967295
const ONE_WORD := 1065353216

static func _uint(value: Variant, maximum: int = UINT32_MAX) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and float(value) == floor(float(value))

static func word(value: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes.decode_u32(0)

static func scalar(bits: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, bits & UINT32_MAX)
	return bytes.decode_float(0)

static func f32(value: float) -> float:
	return scalar(word(value))

static func state_value(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result := {}
	for key in ["alpha_word", "minimum_word", "counter_ms", "phase"]:
		if not _uint(value.get(key), 255 if key == "phase" else UINT32_MAX): return {}
		result[key] = int(value[key])
	return result

static func _parameter(program: Dictionary, kind: String, column: String, fallback: Variant) -> Dictionary:
	# An absent cell is a native failed query: its initialized destination remains.
	# An absent prepared table is unavailable, distinct from a missing cell.
	if not program.get(kind) is Dictionary: return {"available": false}
	var cells: Dictionary = program[kind]
	if not cells.has(column): return {"available": true, "found": false, "value": fallback}
	var cell: Variant = cells[column]
	if not cell is Dictionary or not cell.get("found") is bool: return {"available": false}
	if not cell.found: return {"available": true, "found": false, "value": fallback}
	if kind == "float" and cell.has("word"):
		if not _uint(cell.word): return {"available": false}
		return {"available": true, "found": true, "value": scalar(int(cell.word)), "word": int(cell.word)}
	var value: Variant = cell.get("value")
	if not (value is int or value is float): return {"available": false}
	if kind == "integer":
		if not is_finite(float(value)) or float(value) != floor(float(value)) or value < -2147483648 or value > 2147483647: return {"available": false}
		return {"available": true, "found": true, "value": int(value)}
	return {"available": true, "found": true, "value": f32(float(value)), "word": word(float(value))}

static func _result(previous: Variant) -> Dictionary:
	var state := state_value(previous)
	return {"available": not state.is_empty(), "reason": "native_type5" if not state.is_empty() else "state_unavailable", "state": state, "commands": [], "counter_delta_after_publish": null}

static func _unavailable(result: Dictionary, reason: String) -> Dictionary:
	result.available = false
	result.reason = reason
	result.commands = []
	return result

static func _publish(bits: int) -> Dictionary:
	return {"kind": "set_alpha", "scope": 255, "alpha_word": bits}

static func load_program(previous: Variant, program: Dictionary) -> Dictionary:
	var result := _result(previous)
	if not result.available: return result
	var entry := _parameter(program, "float", "param1", scalar(int(result.state.minimum_word)))
	if not entry.available: return _unavailable(result, "param1_unavailable")
	if entry.found: result.state.minimum_word = int(entry.word)
	return result

static func attach(previous: Variant, program: Dictionary, target_available: bool) -> Dictionary:
	var result := _result(previous)
	if not result.available or not target_available: return result
	var vector: Array = []
	for column in ["param2", "param3", "param4"]:
		var entry := _parameter(program, "float", column, 0.0)
		if not entry.available: return _unavailable(result, column + "_unavailable")
		vector.append(int(entry.word) if entry.found else 0)
	var period := _parameter(program, "integer", "param5", 0)
	if not period.available: return _unavailable(result, "param5_unavailable")
	if period.value == 0:
		result.state.alpha_word = result.state.minimum_word
		if scalar(int(result.state.alpha_word)) > 0.0:
			result.commands.append(_publish(int(result.state.alpha_word)))
		else:
			# COMISS/JBE includes unordered alpha, not only ordered <= zero.
			result.commands.append({"kind": "set_blocked", "value": true})
			result.commands.append({"kind": "set_visible", "value": false})
	if scalar(int(vector[0])) >= 0.0:
		result.commands.append({"kind": "set_vector_channel", "channel": 3, "vector_words": vector, "flags": [0, 1]})
	return result

static func update(previous: Variant, program: Dictionary, elapsed_ms: Variant, target_available: bool) -> Dictionary:
	var result := _result(previous)
	if not result.available: return result
	if not _uint(elapsed_ms): return _unavailable(result, "elapsed_milliseconds_unavailable")
	if not target_available: return result
	var period := _parameter(program, "integer", "param5", 0)
	if not period.available: return _unavailable(result, "param5_unavailable")
	if period.value == 0:
		result.commands.append(_publish(int(result.state.alpha_word)))
		return result # Native constant-alpha branch does not advance counter.
	var maximum := _parameter(program, "float", "param6", 1.0)
	if not maximum.available: return _unavailable(result, "param6_unavailable")
	var divisor := int(period.value) & UINT32_MAX
	var old_counter := int(result.state.counter_ms)
	# Unsigned integer DIV, then a signed int32 CVTDQ2PS denominator.
	var quotient := old_counter / divisor
	var remainder := old_counter % divisor
	var phase := (int(result.state.phase) + (quotient & 255)) & 3
	result.state.phase = phase
	result.state.counter_ms = remainder
	var alpha_word := int(result.state.alpha_word)
	var maximum_word := int(maximum.word) if maximum.found else ONE_WORD
	if phase == 0 or phase == 2:
		var fraction := f32(f32(float(remainder)) / f32(float(period.value)))
		alpha_word = word(f32(1.0 - fraction)) if phase == 0 else word(fraction)
	elif phase == 1: alpha_word = int(result.state.minimum_word)
	else: alpha_word = maximum_word
	var alpha := scalar(alpha_word)
	var upper := scalar(maximum_word)
	var lower := scalar(int(result.state.minimum_word))
	# COMISS/JBE then COMISS/CMOVA: unordered first comparison follows the
	# lower test; equal/unordered lower test retains the computed word.
	if not is_nan(alpha) and not is_nan(upper) and alpha > upper:
		alpha_word = maximum_word
	elif not is_nan(lower) and not is_nan(alpha) and lower > alpha:
		alpha_word = int(result.state.minimum_word)
	result.state.alpha_word = alpha_word
	result.commands.append(_publish(alpha_word))
	# Integration must add this to the LIVE counter after executing set_alpha.
	# A callback may mutate the counter. Never overwrite it with a precomputed
	# final counter after publication. state here is the pre-publication state.
	result.counter_delta_after_publish = int(elapsed_ms)
	return result

static func complete_update(pre_publish_state: Variant, elapsed_ms: Variant) -> Dictionary:
	var state := state_value(pre_publish_state)
	if state.is_empty() or not _uint(elapsed_ms): return {}
	state.counter_ms = (int(state.counter_ms) + int(elapsed_ms)) & UINT32_MAX
	return state

static func stop(program: Dictionary, update_enabled: bool, target_available: bool) -> Dictionary:
	var result := {"available": true, "reason": "native_type5", "commands": []}
	if not update_enabled or not target_available: return result
	# Native publication precedes the two table reads. These are detached
	# prepared query values; an adapter must retain that execution boundary.
	result.commands.append(_publish(ONE_WORD))
	var minimum := _parameter(program, "float", "param1", 1.0)
	var vector := _parameter(program, "float", "param2", 1.0)
	if not minimum.available or not vector.available: return _unavailable(result, "stop_parameters_unavailable")
	if float(vector.value) >= 0.0: result.commands.append({"kind": "clear_vector_channel", "channel": 3})
	if float(minimum.value) == 0.0:
		result.commands.append({"kind": "set_blocked", "value": false})
		result.commands.append({"kind": "set_visible", "value": true})
		result.commands.append({"kind": "refresh_visibility"})
	return result

static func select_alpha(physical_list: Array) -> Dictionary:
	# Input is the physical effect-list order, not sorted effect IDs. Only
	# canonical scalar fields are consumed; the returned view is detached.
	var selected: Variant = null
	var lowest := 255
	for index in range(physical_list.size() - 1, -1, -1):
		var effect: Variant = physical_list[index]
		if not effect is Dictionary: return {"available": false, "reason": "effect_unavailable"}
		for key in ["type", "finished", "attached", "scope", "alpha_word"]:
			if not _uint(effect.get(key), 255 if key in ["type", "scope"] else UINT32_MAX): return {"available": false, "reason": "effect_field_unavailable"}
		if effect.type == 5 and effect.finished == 0 and effect.attached != 0 and effect.scope < lowest:
			lowest = int(effect.scope)
			selected = {"index": index, "scope": lowest, "alpha_word": int(effect.alpha_word)}
	return {"available": true, "selected": selected, "alpha_word": 3212836864 if selected == null else selected.alpha_word}
