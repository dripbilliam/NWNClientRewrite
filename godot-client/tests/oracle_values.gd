extends RefCounted

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$f64"): return str(value["$f64"]).hex_decode().decode_double(0)
		var result := {}
		for key in value: result[key] = decode(value[key])
		return result
	if value is Array: return value.map(decode)
	return value

static func equal_values(actual: Variant, expected: Variant) -> bool:
	if (actual is float or actual is int) and (expected is float or expected is int): return float(actual) == float(expected)
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index in actual.size():
			if not equal_values(actual[index], expected[index]): return false
		return true
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in actual:
			if not expected.has(key) or not equal_values(actual[key], expected[key]): return false
		return true
	return typeof(actual) == typeof(expected) and actual == expected
