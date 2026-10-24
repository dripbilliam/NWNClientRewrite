extends RefCounted
# Bounds-checked little-endian data. No scene, renderer or JS owner.
var data: PackedByteArray
var failure := ""
const CP1252_HIGH = [0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178]
func _init(bytes: PackedByteArray = PackedByteArray()) -> void: data = bytes
func reject(message: String) -> void:
	if failure.is_empty(): failure = message
func contains(at: int, length: int, label: String = "Binary range") -> bool:
	if at < 0 or length < 0 or at > data.size() or length > data.size() - at:
		reject(label + " exceeds resource bounds")
		return false
	return true
func u8(at: int) -> int: return data[at] if contains(at, 1) else 0
func u16(at: int) -> int: return data.decode_u16(at) if contains(at, 2) else 0
func u32(at: int) -> int: return data.decode_u32(at) if contains(at, 4) else 0
func i32(at: int) -> int: return data.decode_s32(at) if contains(at, 4) else 0
func i64(at: int) -> int: return data.decode_s64(at) if contains(at, 8) else 0
func f32(at: int) -> float: return data.decode_float(at) if contains(at, 4) else 0.0
func f64(at: int) -> float: return data.decode_double(at) if contains(at, 8) else 0.0
func bytes(at: int, length: int) -> PackedByteArray:
	return data.slice(at, at + length) if contains(at, length) else PackedByteArray()
func text(at: int, length: int, terminated: bool = false) -> String:
	if not contains(at, length): return ""
	if terminated:
		var zero := data.find(0, at)
		if zero >= at and zero < at + length: length = zero - at
	# The engine's byte-string conversion supplies Latin-1 code points. Replace
	# only CP1252's 32 exceptional slots using native string loops; never append
	# millions of individual characters in GDScript for a large 2DA/NSS file.
	var result := data.slice(at, at + length).get_string_from_ascii()
	for index in CP1252_HIGH.size():
		if CP1252_HIGH[index] != index + 128:
			result = result.replace(String.chr(index + 128), String.chr(CP1252_HIGH[index]))
	return result
