extends RefCounted
const Binary = preload("res://systems/native_data/binary_data.gd")
const MAX_RECORDS := 1000000
var failure := ""
var reader
var structs: Array = []
var fields: Array = []
var labels: Array = []
var records: Dictionary = {}
var field_types: Dictionary = {}
var data_at := 0
var data_size := 0
var fields_at := 0
var fields_size := 0
var lists_at := 0
var lists_size := 0
var duplicate_labels_allowed:=false
func reject(message: String) -> void:
	if failure.is_empty(): failure = message
func require_range(at: int,length: int,label: String)->bool:
	if reader.contains(at,length,label):return true
	failure=label+" is out of range."
	return false
func parse(bytes: PackedByteArray, expected_type: String = "", preserve_duplicate_labels: bool=false) -> Dictionary:
	# Byte-preserving root patches keep the physical tables rather than writing
	# this dictionary back. Presentation callers retain strict unique labels.
	duplicate_labels_allowed=preserve_duplicate_labels
	failure = ""; structs.clear(); fields.clear(); labels.clear(); records.clear(); field_types.clear()
	reader = Binary.new(bytes)
	if not require_range(0,56,"GFF header"):return {}
	var kind: String = reader.text(0, 4); var version: String = reader.text(4, 4)
	if version not in ["V3.2", "V3.3"]:reject("Unsupported GFF version "+version+".");return {}
	if not expected_type.is_empty() and kind!=expected_type:reject("Expected "+expected_type+" GFF, found "+kind+".");return {}
	var offsets: Array = []; var counts: Array = []
	for index in 6:
		offsets.append(reader.u32(8 + index * 8)); counts.append(reader.u32(12 + index * 8))
	for count in counts:
		if count>MAX_RECORDS*16:reject("GFF table exceeds the supported size.");return {}
	if counts[0]==0 or counts[0]>MAX_RECORDS or counts[1]>MAX_RECORDS or counts[2]>MAX_RECORDS:reject("GFF header contains invalid table counts.");return {}
	if counts[4]%4!=0 or counts[5]%4!=0:reject("GFF index tables have invalid byte lengths.");return {}
	var table_labels: Array[String]=["GFF struct table","GFF field table","GFF label table","GFF field data","GFF field indices","GFF list indices"]
	for index in 6:
		if not require_range(offsets[index],counts[index]*([12,12,16,1,1,1][index]),table_labels[index]):return {}
	data_at = offsets[3]; data_size = counts[3]; fields_at = offsets[4]; fields_size = counts[4]; lists_at = offsets[5]; lists_size = counts[5]
	for index in counts[0]:
		var at: int = offsets[0] + index * 12
		structs.append({"id": reader.u32(at), "first": reader.u32(at + 4), "count": reader.u32(at + 8)})
	for index in counts[1]:
		var at: int = offsets[1] + index * 12
		var type: int = reader.u32(at)
		if type > 18: reject("Unsupported GFF field type "+str(type)+"."); return {}
		fields.append({"type": type, "label": reader.u32(at + 4), "value": reader.u32(at + 8), "at": at})
	for index in counts[2]: labels.append(reader.text(offsets[2] + index * 16, 16, true))
	var root: Dictionary = read_struct(0, 0)
	if not reader.failure.is_empty(): reject(reader.failure)
	if not failure.is_empty(): return {}
	return {"type": kind, "fileType":kind, "version": version, "root": root, "records": records, "struct_types": structs.map(func(row): return row.id), "field_types": field_types}
func data_offset(at: int, length: int,label: String="GFF value") -> int:
	if at < 0 or length < 0 or at > data_size or length > data_size - at:
		reject(label+" points outside GFF field data."); return -1
	return data_at + at
func sized_text(offset: int, width: int,label: String) -> String:
	var at := data_offset(offset, width,label)
	if at < 0: return ""
	var length: int = reader.u8(at) if width == 1 else reader.u32(at)
	if length>MAX_RECORDS*16:reject(label+" string is too large.");return ""
	at = data_offset(offset + width, length,label)
	return reader.text(at, length) if at >= 0 else ""
func locstring(offset: int) -> Dictionary:
	var at := data_offset(offset, 4,"GFF localized string")
	if at < 0: return {}
	var size: int = reader.u32(at)
	if size < 8: reject("GFF localized string has an invalid size."); return {}
	if not require_range(at+4,size,"GFF localized string body"):return {}
	var end := at + 4 + size; var cursor := at + 12
	var count: int = reader.u32(at + 8); var entries: Array = []
	if count > MAX_RECORDS: reject("GFF localized string has too many entries."); return {}
	for index in count:
		if cursor > end - 8: reject("GFF localized string entry is truncated."); return {}
		var language: int = reader.u32(cursor); var length: int = reader.u32(cursor + 4); cursor += 8
		if length > end - cursor: reject("GFF localized string data is truncated."); return {}
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
			var at := data_offset(value, 8,"GFF uint64" if field.type==6 else "GFF int64")
			if at < 0: return null
			# Godot ints are signed 64-bit. Unsigned fields keep both exact words;
			# they must never pass through a JSON/double approximation.
			return {"unsigned64_low": reader.u32(at), "unsigned64_high": reader.u32(at + 4)} if field.type == 6 else reader.i64(at)
		8: return reader.f32(int(field.at) + 8)
		9:
			var at := data_offset(value, 8,"GFF float64")
			return reader.f64(at) if at >= 0 else null
		10: return sized_text(value, 4,"GFF string")
		11: return sized_text(value, 1,"GFF resref")
		12: return locstring(value)
		13:
			var at := data_offset(value, 4,"GFF void")
			if at < 0: return null
			var length: int = reader.u32(at); at = data_offset(value + 4, length,"GFF void")
			return reader.bytes(at, length) if at >= 0 else null
		14: return read_struct(value, depth + 1)
		15:
			if value % 4 != 0:reject("GFF list offset is not DWORD-aligned.");return []
			if value > lists_size - 4:reject("GFF list offset is out of range.");return []
			var count: int = reader.u32(lists_at + value)
			if count > MAX_RECORDS or count * 4 > lists_size - value - 4: reject("GFF list exceeds the list-index table."); return []
			var result: Array = []
			for index in count:
				result.append(read_struct(reader.u32(lists_at + value + 4 + index * 4), depth + 1))
				if not failure.is_empty(): return []
			return result
		16, 17:
			var count := 4 if field.type == 16 else 3
			var at := data_offset(value, count * 4,"GFF orientation" if field.type==16 else "GFF vector")
			if at < 0: return []
			var result: Array = []
			for index in count: result.append(reader.f32(at + index * 4))
			return result
		18:
			var at := data_offset(value, 4,"GFF string reference")
			return reader.u32(at) if at >= 0 else null
	return null
func read_struct(index: int, depth: int) -> Dictionary:
	if depth>128:reject("GFF structure nesting exceeds the supported depth.");return {}
	if index<0 or index>=structs.size():reject("GFF struct index is out of range.");return {}
	if records.has(index): return records[index]
	var row: Dictionary = structs[index]; var count: int = row.count; var ids: Array = []
	if count == 1: ids.append(row.first)
	elif count > 1:
		if int(row.first)%4!=0:reject("GFF field-index offset is not DWORD-aligned.");return {}
		if int(row.first)>fields_size or count*4>fields_size-int(row.first):reject("GFF struct fields exceed the index table.");return {}
		for item in count: ids.append(reader.u32(fields_at + int(row.first) + item * 4))
	var result := {}; var types := {}
	records[index] = result; field_types[index] = types
	for id in ids:
		if int(id) >= fields.size(): reject("GFF field index is out of range."); return {}
		var field: Dictionary = fields[int(id)]
		if int(field.label) >= labels.size(): reject("GFF label index is out of range."); return {}
		var name: String = labels[int(field.label)]
		if result.has(name) and not duplicate_labels_allowed: reject("Duplicate GFF field label "+name+"."); return {}
		result[name] = field_value(field, depth); types[name] = field.type
		if not failure.is_empty(): return {}
	return result
