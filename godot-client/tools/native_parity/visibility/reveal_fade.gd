extends RefCounted
# Pure native CNWC target-alpha and fade kernels. Existing client/effect owners
# supply received flags, selector output, snapshot time and world-time results.
# No timer, scene lookup, table store, fabricated server fields or LOS policy.
const Alpha = preload("res://tools/native_parity/visibility/alpha_program.gd")
const Perception = preload("res://tools/native_parity/visibility/perception_latch.gd")
const U32 := 4294967295

static func _uint(value: Variant, maximum: int = U32) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and float(value) == floor(float(value))

static func target_alpha(input: Dictionary) -> Dictionary:
	var result := {"available": false, "alpha_word": null, "reason": "target_fields_unavailable"}
	if not input.get("is_creature") is bool or not _uint(input.get("revealed"), 255): return result
	var use_override := false
	if not input.is_creature:
		if input.revealed != 1: return {"available": true, "alpha_word": 0, "reason": "unrevealed"}
		use_override = true
	else:
		if not input.get("player_info_present") is bool: return result
		if not input.player_info_present:
			# Native bypasses the revealed-byte test when PlayerInfo is absent.
			use_override = true
		else:
			if not input.get("matching_perception_present") is bool: return result
			if input.matching_perception_present:
				var flags: Variant = Perception.flags_value(input.get("perception"))
				if flags == null: return result
				if flags[2] or not flags[1] and flags[0]:
					return {"available": true, "alpha_word": Alpha.word(0.5), "reason": "native_detected_perception"}
			for key in ["creature114", "creature110"]:
				if not _uint(input.get(key)): return result
			if input.creature114 == 0 and input.creature110 != 0:
				return {"available": true, "alpha_word": Alpha.word(0.5), "reason": "native_creature_state"}
			if input.revealed != 1: return {"available": true, "alpha_word": 0, "reason": "unrevealed"}
			use_override = true
	if use_override:
		if not _uint(input.get("effect_override_word")): return result
		var bits := int(input.effect_override_word)
		return {"available": true, "alpha_word": Alpha.ONE_WORD if Alpha.scalar(bits) == -1.0 else bits, "reason": "native_effect_override"}
	return result

static func state_value(input: Variant) -> Dictionary:
	if not input is Dictionary: return {}
	var result := {}
	for key in ["status", "desired", "opacity_word", "expiry_enabled", "expiry_ms", "start_day", "start_ms"]:
		if not _uint(input.get(key), 255 if key in ["status", "desired"] else U32): return {}
		result[key] = int(input[key])
	return result

static func update(previous: Variant, timing: Dictionary, targets: Array, render_owner_present: bool) -> Dictionary:
	var state := state_value(previous)
	var result := {"available": not state.is_empty(), "state": state, "commands": [], "completion_requested": false, "target_query_count": 0, "reason": "native_fade_update"}
	if state.is_empty(): result.reason = "fade_state_unavailable"; return result
	if state.status == state.desired:
		if state.expiry_enabled != 0:
			# Existing WorldTimer::SubtractWorldTimes owns calendar arithmetic.
			if not _uint(timing.get("elapsed_world_ms")): result.available = false; result.reason = "world_elapsed_unavailable"; return result
			result.completion_requested = int(state.expiry_ms) <= int(timing.elapsed_world_ms)
		return result
	if not _uint(timing.get("snapshot_us"), 9223372036854775807): result.available = false; result.reason = "snapshot_time_unavailable"; return result
	var opacity_word := int(state.opacity_word)
	var opacity := Alpha.scalar(opacity_word)
	if state.desired in [0, 1]:
		if targets.is_empty() or not _uint(targets[0]): result.available = false; result.reason = "first_target_unavailable"; return result
		result.target_query_count = 1
		var target := Alpha.scalar(int(targets[0]))
		var advancing := opacity < target if state.desired == 1 else target < opacity
		advancing = advancing or is_nan(opacity) or is_nan(target) # COMISS/JC.
		if advancing:
			var milliseconds := (int(timing.snapshot_us) / 1000) & U32
			var step := Alpha.f32(Alpha.f32(float(milliseconds)) / 2000.0)
			opacity_word = Alpha.word(Alpha.f32(opacity + step if state.desired == 1 else opacity - step))
			state.status = 2 if state.desired == 1 else 3
		else:
			if targets.size() < 2 or not _uint(targets[1]): result.available = false; result.reason = "second_target_unavailable"; return result
			result.target_query_count = 2
			opacity_word = int(targets[1])
			state.status = int(state.desired)
			if state.desired == 0 and state.expiry_enabled != 0:
				if not _uint(timing.get("now_day")) or not _uint(timing.get("now_ms")) or not render_owner_present:
					result.available = false; result.reason = "hide_completion_context_unavailable"; return result
				state.start_day = int(timing.now_day)
				state.start_ms = int(timing.now_ms)
				result.commands.append({"kind": "render_owner_virtual8", "argument": 0})
	var value := Alpha.scalar(opacity_word)
	if not is_nan(value) and value < 0.0: opacity_word = 0
	elif not is_nan(value) and value > 1.0: opacity_word = Alpha.ONE_WORD
	state.opacity_word = opacity_word
	if render_owner_present: result.commands.append({"kind": "set_alpha", "scope": 255, "alpha_word": opacity_word})
	return result
