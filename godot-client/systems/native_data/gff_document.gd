extends RefCounted
const Binary = preload("res://systems/native_data/binary_data.gd")
const MAX_RECORDS := 1000000
var failure := ""
var reader
var structs: Array = []
var fields: Array = []
var labels: Array = []
var records: Dictionary = {}
var active_structs: Dictionary = {}
var field_types: Dictionary = {}
var data_at := 0
var data_size := 0
var fields_at := 0
var fields_size := 0
var lists_at := 0
var lists_size := 0
func reject(message: String) -> void:
	if failure.is_empty(): failure = message
func parse(bytes: PackedByteArray, expected_type: String = "") -> Dictionary:
	failure = ""; structs.clear(); fields.clear(); labels.clear(); records.clear(); field_types.clear(); active_structs.clear()
	reader = Binary.new(bytes)
	if not reader.contains(0, 56, "GFF header"): failure = reader.failure; return {}
	var kind: String = reader.text(0, 4); var version: String = reader.text(4, 4)
	if version not in ["V3.2", "V3.3"] or (not expected_type.is_empty() and kind != expected_type): reject("Unsupported GFF signature"); return {}
	var offsets: Array = []; var counts: Array = []
	for index in 6:
		offsets.append(reader.u32(8 + index * 8)); counts.append(reader.u32(12 + index * 8))
	for index in 6:
		if counts[index] > MAX_RECORDS * (1 if index < 3 else 16): reject("GFF count exceeds supported bounds"); return {}
		if not reader.contains(offsets[index], counts[index] * ([12, 12, 16, 1, 1, 1][index]), "GFF table"): failure = reader.failure; return {}
	if counts[0] == 0 or counts[4] % 4 != 0 or counts[5] % 4 != 0: reject("Invalid GFF struct/index count"); return {}
	data_at = offsets[3]; data_size = counts[3]; fields_at = offsets[4]; fields_size = counts[4]; lists_at = offsets[5]; lists_size = counts[5]
	for index in counts[0]:
		var at: int = offsets[0] + index * 12
		structs.append({"id": reader.u32(at), "first": reader.u32(at + 4), "count": reader.u32(at + 8)})
	for index in counts[1]:
		var at: int = offsets[1] + index * 12
		var type: int = reader.u32(at)
		if type > 18: reject("Unsupported GFF field type"); return {}
		fields.append({"type": type, "label": reader.u32(at + 4), "value": reader.u32(at + 8), "at": at})
	for index in counts[2]: labels.append(reader.text(offsets[2] + index * 16, 16, true))
	var root: Dictionary = read_struct(0, 0)
	if not reader.failure.is_empty(): reject(reader.failure)
	if not failure.is_empty(): return {}
	return {"type": kind, "version": version, "root": root, "records": records, "struct_types": structs.map(func(row): return row.id), "field_types": field_types}
func data_offset(at: int, length: int) -> int:
	if at < 0 or length < 0 or at > data_size or length > data_size - at:
		reject("GFF value exceeds field-data section"); return -1
	return data_at + at
func sized_text(offset: int, width: int) -> String:
	var at := data_offset(offset, width)
	if at < 0: return ""
	var length: int = reader.u8(at) if width == 1 else reader.u32(at)
	at = data_offset(offset + width, length)
	return reader.text(at, length) if at >= 0 else ""
func locstring(offset: int) -> Dictionary:
	var at := data_offset(offset, 4)
	if at < 0: return {}
	var size: int = reader.u32(at)
	if size < 8 or data_offset(offset + 4, size) < 0: reject("Invalid localized string size"); return {}
	var end := at + 4 + size; var cursor := at + 12
	var count: int = reader.u32(at + 8); var entries: Array = []
	if count > MAX_RECORDS: reject("Localized string count exceeds bounds"); return {}
	for index in count:
		if cursor > end - 8: reject("Truncated localized string entry"); return {}
		var language: int = reader.u32(cursor); var length: int = reader.u32(cursor + 4); cursor += 8
		if length > end - cursor: reject("Truncated localized string text"); return {}
		entries.append({"languageId": language, "text": reader.text(cursor, length)}); cursor += length
	return {"strRef": reader.u32(at + 4), "entries": entries}
func field_value(field: Dictionary, depth: int) -> Variant:
	var value: int = field.value
	match int(field.type):
		0: return value & 255
		1: return (value & 255) - (256 if value & 128 else 0)
		2: return value & 65535
		3: return (value & 65535) - (65536 if value & 32768 else 0)
		4: return value
		5: return value - (4294967296 if value & 2147483648 else 0)
		6, 7:
			var at := data_offset(value, 8)
			if at < 0: return null
			# Godot ints are signed 64-bit. Unsigned fields keep both exact words;
			# they must never pass through a JSON/double approximation.
			return {"unsigned64_low": reader.u32(at), "unsigned64_high": reader.u32(at + 4)} if field.type == 6 else reader.i64(at)
		8: return reader.f32(int(field.at) + 8)
		9:
			var at := data_offset(value, 8)
			return reader.f64(at) if at >= 0 else null
		10: return sized_text(value, 4)
		11: return sized_text(value, 1)
		12: return locstring(value)
		13:
			var at := data_offset(value, 4)
			if at < 0: return null
			var length: int = reader.u32(at); at = data_offset(value + 4, length)
			return reader.bytes(at, length) if at >= 0 else null
		14: return read_struct(value, depth + 1)
		15:
			if value % 4 != 0 or value > lists_size - 4: reject("GFF list offset exceeds index section"); return []
			var count: int = reader.u32(lists_at + value)
			if count > MAX_RECORDS or count * 4 > lists_size - value - 4: reject("GFF list exceeds index section"); return []
			var result: Array = []
			for index in count:
				result.append(read_struct(reader.u32(lists_at + value + 4 + index * 4), depth + 1))
				if not failure.is_empty(): return []
			return result
		16, 17:
			var count := 4 if field.type == 16 else 3
			var at := data_offset(value, count * 4)
			if at < 0: return []
			var result: Array = []
			for index in count: result.append(reader.f32(at + index * 4))
			return result
		18:
			var at := data_offset(value, 4)
			return reader.u32(at) if at >= 0 else null
	return null
func read_struct(index: int, depth: int) -> Dictionary:
	if depth > 128 or index < 0 or index >= structs.size(): reject("GFF struct depth/index exceeds bounds"); return {}
	if active_structs.has(index): reject("Cyclic GFF structures are not supported"); return {}
	if records.has(index): return records[index]
	var row: Dictionary = structs[index]; var count: int = row.count; var ids: Array = []
	if count > fields.size(): reject("GFF struct has too many fields"); return {}
	if count == 1: ids.append(row.first)
	elif count > 1:
		if int(row.first) % 4 != 0 or int(row.first) > fields_size or count * 4 > fields_size - int(row.first): reject("GFF field indices exceed section"); return {}
		for item in count: ids.append(reader.u32(fields_at + int(row.first) + item * 4))
	var result := {}; var types := {}
	records[index] = result; field_types[index] = types
	active_structs[index] = true
	for id in ids:
		if int(id) >= fields.size(): reject("GFF field index exceeds table"); return {}
		var field: Dictionary = fields[int(id)]
		if int(field.label) >= labels.size(): reject("GFF label index exceeds table"); return {}
		var name: String = labels[int(field.label)]
		if result.has(name): reject("Duplicate GFF field label"); return {}
		result[name] = field_value(field, depth); types[name] = field.type
		if not failure.is_empty(): return {}
	active_structs.erase(index)
	return result
