extends RefCounted
# One-time, read-only import of movable_windows.js's Local Storage value.
# This intentionally understands only the LevelDB records needed for that key.
const STORAGE_KEY := "nwn.ui.windowPositions.v1"
const LOG_BLOCK := 32768
const MAX_FILE := 256 * 1024 * 1024
const MAX_VALUE := 1024 * 1024
const TABLE_MAGIC := [0x57, 0xfb, 0x80, 0x8b, 0x24, 0x75, 0x47, 0xdb]

func read_profile(electron_user_data_dir: String) -> Dictionary:
	var found: Dictionary=_latest(electron_user_data_dir,STORAGE_KEY)
	if str(found.get("status","error"))!="found":
		return {"status":found.get("status","error"),"positions":{},"error":found.get("error","")}
	var json_text: Variant = _dom_string(found.value)
	if json_text == null:
		return _error("Electron window positions use an unsupported string encoding")
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return _error("Electron window positions are not a JSON object")
	var positions := {}
	var seen := 0
	for key in parsed.keys():
		if seen >= 100:
			break
		seen += 1
		var point: Variant = parsed[key]
		if not key is String or not _window_key(key) or not point is Dictionary:
			continue
		var x: Variant = point.get("x", null)
		var y: Variant = point.get("y", null)
		if (x is int or x is float) and (y is int or y is float) and is_finite(float(x)) and is_finite(float(y)):
			positions[key] = {"x":x, "y":y}
	return {"status":"found", "positions":positions, "error":""}

func read_browser_profile(electron_user_data_dir: String) -> Dictionary:
	var result: Dictionary={"status":"absent","history":[],"favorites":[],"error":""}
	var any_found:=false
	for name in ["history","favorites"]:
		var found: Dictionary=_latest(electron_user_data_dir,"nwn.multiplayer."+name)
		match str(found.get("status","error")):
			"absent":continue
			"error":return {"status":"error","history":[],"favorites":[],"error":str(found.get("error","Electron browser storage could not be read"))}
		any_found=true
		var json_text: Variant=_dom_string(found.value)
		# Old stored(name) catches invalid JSON/storage and substitutes [].
		if json_text==null:continue
		var parsed: Variant=JSON.parse_string(str(json_text))
		if not parsed is Array:continue
		var rows: Array=[]
		for value in parsed:
			# The old filter dereferences r.host. A null row throws into stored's
			# catch and discards the entire list, including earlier valid rows.
			if value==null:rows.clear();break
			if not value is Dictionary or not value.get("host") is String:continue
			var port: Variant=value.get("port")
			if not (port is int or port is float) or not is_finite(float(port)) or float(port)!=floor(float(port)) or int(port)<1 or int(port)>65535:continue
			rows.append(value.duplicate(true))
			if rows.size()>=100:break
		result[name]=rows
	result.status="found" if any_found else "absent"
	return result

func read_game_options(electron_user_data_dir: String) -> Dictionary:
	# These are the only normal multiplayer option keys the old Options callback
	# writes to Chromium Local Storage. This reader never requests a key secret.
	var result: Dictionary={"status":"absent","options":{},"error":""}
	for entry in [["nwn.graphics.shadowCastingLights","shadow_lights"],["nwn.inventory.showCreatureSlots","creature_slots"]]:
		var found: Dictionary=_latest(electron_user_data_dir,str(entry[0]))
		match str(found.get("status","error")):
			"absent":continue
			"error":return {"status":"error","options":{},"error":str(found.get("error","Old game options could not be read"))}
		var value: Variant=_dom_string(found.value)
		if value==null:return {"status":"error","options":{},"error":"Old game options use an unsupported string encoding"}
		result.status="found"
		if str(entry[1])=="shadow_lights":
			var count: Variant=_js_shadow_count(str(value))
			if count!=null:result.options.shadow_lights=count
		elif str(entry[1])=="creature_slots":result.options.creature_slots=str(value)=="true"
	return result

func _js_shadow_count(value: String)->Variant:
	# Old main.js admits [1,2,3].includes(Number(saved)), not just the
	# canonical strings that its own settings UI writes.
	var raw:=value.strip_edges()
	if raw.is_empty():return null
	if raw.is_valid_float():
		var number:=raw.to_float()
		return int(number) if is_finite(number) and number in [1.0,2.0,3.0] else null
	var radix:=0
	if raw.begins_with("0x") or raw.begins_with("0X"):radix=16
	elif raw.begins_with("0b") or raw.begins_with("0B"):radix=2
	elif raw.begins_with("0o") or raw.begins_with("0O"):radix=8
	if radix==0 or raw.length()<=2:return null
	var total:=0
	for digit_index in range(2,raw.length()):
		var digit: int="0123456789abcdef".find(raw[digit_index].to_lower())
		if digit<0 or digit>=radix:return null
		total=total*radix+digit
		if total>3:return null
	return total if total in [1,2,3] else null

func _latest(electron_user_data_dir: String,target_key: String) -> Dictionary:
	var empty := {"status":"absent", "error":""}
	if not electron_user_data_dir.is_absolute_path():
		return _error("Electron profile path is not absolute")
	var db := electron_user_data_dir.path_join("Local Storage").path_join("leveldb")
	if not DirAccess.dir_exists_absolute(db):
		return empty
	var current := _file(db.path_join("CURRENT"), 4096)
	if not current.ok:
		return _error("Chromium Local Storage CURRENT is unavailable")
	var manifest_name: String = current.bytes.get_string_from_utf8().strip_edges()
	if not manifest_name.begins_with("MANIFEST-") or manifest_name.get_file() != manifest_name:
		return _error("Chromium Local Storage CURRENT is invalid")
	var manifest := _file(db.path_join(manifest_name), MAX_FILE)
	if not manifest.ok:
		return _error("Chromium Local Storage manifest is unavailable")
	var records := _log_records(manifest.bytes)
	if not records.ok:
		return _error("Chromium Local Storage manifest is damaged")
	var active := {}
	var log_number := -1
	var previous_log := -1
	for record in records.records:
		var edit := _manifest_edit(record)
		if not edit.ok:
			return _error("Chromium Local Storage manifest entry is unsupported")
		for number in edit.deleted:
			active.erase(number)
		for number in edit.added:
			active[number] = true
		if edit.log_number >= 0:
			log_number = edit.log_number
		if edit.previous_log >= 0:
			previous_log = edit.previous_log
	if log_number < 0:
		return _error("Chromium Local Storage has no active log number")
	var latest := {"sequence":-1, "deleted":false, "value":PackedByteArray()}
	var files := DirAccess.get_files_at(db)
	for number in active.keys():
		var path := _numbered_file(files, int(number), ["ldb", "sst"])
		if path.is_empty():
			return _error("Chromium Local Storage is missing an active table")
		var source := _file(db.path_join(path), MAX_FILE)
		if not source.ok or not _scan_table(source.bytes, latest,target_key):
			return _error("Chromium Local Storage active table cannot be read")
	for number in [previous_log, log_number]:
		if number <= 0:
			continue
		var path := _numbered_file(files, number, ["log"])
		if path.is_empty():
			if number == previous_log:
				continue
			return _error("Chromium Local Storage active log is unavailable")
		var source := _file(db.path_join(path), MAX_FILE)
		if not source.ok:
			return _error("Chromium Local Storage active log cannot be read")
		var log := _log_records(source.bytes)
		if not log.ok:
			return _error("Chromium Local Storage log is damaged")
		for record in log.records:
			if not _scan_batch(record, latest,target_key):
				return _error("Chromium Local Storage write batch is damaged")
	if latest.sequence < 0 or latest.deleted:
		return empty
	return {"status":"found","value":latest.value,"error":""}

func _error(message: String) -> Dictionary:
	return {"status":"error", "positions":{}, "error":message}

func _file(path: String, maximum: int) -> Dictionary:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {"ok":false}
	var length := handle.get_length()
	if length < 0 or length > maximum:
		return {"ok":false}
	var data := handle.get_buffer(length)
	return {"ok":data.size() == length, "bytes":data}

func _numbered_file(names: PackedStringArray, number: int, extensions: Array) -> String:
	for extension in extensions:
		var name := "%06d.%s" % [number, extension]
		if names.has(name):
			return name
	return ""

func _u16(data: PackedByteArray, at: int) -> int:
	return int(data[at]) | (int(data[at + 1]) << 8)

func _u32(data: PackedByteArray, at: int) -> int:
	return int(data[at]) | (int(data[at + 1]) << 8) | (int(data[at + 2]) << 16) | (int(data[at + 3]) << 24)

func _u64(data: PackedByteArray, at: int) -> int:
	return _u32(data, at) | (_u32(data, at + 4) << 32)

func _varint(data: PackedByteArray, cursor: Dictionary, end: int) -> int:
	var value := 0
	for shift in range(0, 70, 7):
		var at: int = cursor.p
		if at >= end:
			return -1
		var byte: int = data[at]
		cursor.p = at + 1
		if shift == 63 and byte > 1:
			return -1
		value |= (byte & 127) << shift
		if byte < 128:
			return value if value >= 0 else -1
	return -1

func _length_bytes(data: PackedByteArray, cursor: Dictionary, end: int) -> Variant:
	var length := _varint(data, cursor, end)
	if length < 0 or length > end - int(cursor.p):
		return null
	var at: int = cursor.p
	cursor.p = at + length
	return data.slice(at, at + length)

func _crc32c(data: PackedByteArray) -> int:
	var crc := 0xffffffff
	for byte in data:
		crc ^= int(byte)
		for bit in 8:
			crc = ((crc >> 1) ^ (0x82f63b78 if (crc & 1) != 0 else 0)) & 0xffffffff
	return (crc ^ 0xffffffff) & 0xffffffff

func _masked_crc(data: PackedByteArray) -> int:
	var crc := _crc32c(data)
	return (((crc >> 15) | (crc << 17)) + 0xa282ead8) & 0xffffffff

func _log_records(data: PackedByteArray) -> Dictionary:
	var rows := []
	var fragment := PackedByteArray()
	var in_fragment := false
	var at := 0
	while at < data.size():
		var block_end: int = mini(data.size(), at - (at % LOG_BLOCK) + LOG_BLOCK)
		if block_end - at < 7:
			at = block_end
			continue
		var size := _u16(data, at + 4)
		var kind: int = data[at + 6]
		if size == 0 and kind == 0:
			at = block_end
			continue
		if size > block_end - at - 7 or kind < 1 or kind > 4:
			return {"ok":false}
		var payload := data.slice(at + 7, at + 7 + size)
		var checksum := PackedByteArray([kind])
		checksum.append_array(payload)
		if _masked_crc(checksum) != _u32(data, at):
			return {"ok":false}
		at += 7 + size
		match kind:
			1:
				if in_fragment:
					return {"ok":false}
				rows.append(payload)
			2:
				fragment = payload
				in_fragment = true
			3:
				if not in_fragment:
					return {"ok":false}
				fragment.append_array(payload)
			4:
				if not in_fragment:
					return {"ok":false}
				fragment.append_array(payload)
				rows.append(fragment)
				fragment = PackedByteArray()
				in_fragment = false
	return {"ok":true, "records":rows}

func _manifest_edit(data: PackedByteArray) -> Dictionary:
	var edit := {"ok":false, "added":[], "deleted":[], "log_number":-1, "previous_log":-1}
	var cursor := {"p":0}
	while cursor.p < data.size():
		var tag := _varint(data, cursor, data.size())
		var number := -1
		match tag:
			1:
				if _length_bytes(data, cursor, data.size()) == null:
					return edit
			2, 3, 4, 9:
				number = _varint(data, cursor, data.size())
				if number < 0:
					return edit
				if tag == 2:
					edit.log_number = number
				elif tag == 9:
					edit.previous_log = number
			5:
				if _varint(data, cursor, data.size()) < 0 or _length_bytes(data, cursor, data.size()) == null:
					return edit
			6:
				if _varint(data, cursor, data.size()) < 0:
					return edit
				number = _varint(data, cursor, data.size())
				if number < 0:
					return edit
				edit.deleted.append(number)
			7:
				if _varint(data, cursor, data.size()) < 0:
					return edit
				number = _varint(data, cursor, data.size())
				if number < 0 or _varint(data, cursor, data.size()) < 0 or _length_bytes(data, cursor, data.size()) == null or _length_bytes(data, cursor, data.size()) == null:
					return edit
				edit.added.append(number)
			_:
				return edit
	edit.ok = true
	return edit

func _matches_key(key: PackedByteArray,target_key: String) -> bool:
	if key.size() < target_key.length() + 3 or key[0] != 95:
		return false
	var separator := key.find(0)
	if separator < 2 or separator + 1 >= key.size():
		return false
	# Chromium DOM storage: 0x01 Latin-1, 0x00 UTF-16LE.
	var encoded := key.slice(separator + 1)
	return _dom_string(encoded) == target_key

func _consider(key: PackedByteArray, value: PackedByteArray, sequence: int, deleted: bool, latest: Dictionary,target_key: String) -> void:
	if sequence >= int(latest.sequence) and _matches_key(key,target_key):
		latest.sequence = sequence
		latest.deleted = deleted
		latest.value = value

func _scan_batch(data: PackedByteArray, latest: Dictionary,target_key: String) -> bool:
	if data.size() < 12:
		return false
	var sequence := _u64(data, 0)
	var count := _u32(data, 8)
	if count > data.size() - 12:
		return false
	var cursor := {"p":12}
	for index in count:
		if cursor.p >= data.size():
			return false
		var kind: int = data[cursor.p]
		cursor.p += 1
		if kind != 0 and kind != 1:
			return false
		var key: Variant = _length_bytes(data, cursor, data.size())
		if key == null:
			return false
		var value := PackedByteArray()
		if kind == 1:
			var raw: Variant = _length_bytes(data, cursor, data.size())
			if raw == null:
				return false
			value = raw
		_consider(key, value, sequence + index, kind == 0, latest,target_key)
	return cursor.p == data.size()

func _block(data: PackedByteArray, offset: int, length: int) -> Variant:
	if offset < 0 or length < 0 or offset > data.size() - length - 5:
		return null
	var packed := data.slice(offset, offset + length)
	var kind: int = data[offset + length]
	var checksum := packed.duplicate()
	checksum.append(kind)
	if _masked_crc(checksum) != _u32(data, offset + length + 1):
		return null
	if kind == 0:
		return packed
	if kind == 1:
		return _snappy(packed)
	return null

func _handle(data: PackedByteArray, cursor: Dictionary, end: int) -> Dictionary:
	var offset := _varint(data, cursor, end)
	var length := _varint(data, cursor, end)
	return {"ok":offset >= 0 and length >= 0, "offset":offset, "length":length}

func _scan_table(data: PackedByteArray, latest: Dictionary,target_key: String) -> bool:
	if data.size() < 48:
		return false
	for i in 8:
		if data[data.size() - 8 + i] != TABLE_MAGIC[i]:
			return false
	var footer := data.slice(data.size() - 48, data.size() - 8)
	var cursor := {"p":0}
	if not _handle(footer, cursor, footer.size()).ok:
		return false
	var index_handle := _handle(footer, cursor, footer.size())
	if not index_handle.ok:
		return false
	var index_block: Variant = _block(data, index_handle.offset, index_handle.length)
	if index_block == null:
		return false
	var index_rows := _entries(index_block)
	if not index_rows.ok:
		return false
	for row in index_rows.rows:
		var handle_cursor := {"p":0}
		var handle := _handle(row.value, handle_cursor, row.value.size())
		if not handle.ok:
			return false
		var block: Variant = _block(data, handle.offset, handle.length)
		if block == null:
			return false
		var entries := _entries(block)
		if not entries.ok:
			return false
		for entry in entries.rows:
			var key: PackedByteArray = entry.key
			if key.size() < 8:
				return false
			var packed_sequence := _u64(key, key.size() - 8)
			var kind := packed_sequence & 255
			if kind != 0 and kind != 1:
				continue
			_consider(key.slice(0, key.size() - 8), entry.value, packed_sequence >> 8, kind == 0, latest,target_key)
	return true

func _entries(data: PackedByteArray) -> Dictionary:
	if data.size() < 4:
		return {"ok":false}
	var count := _u32(data, data.size() - 4)
	if count < 1 or count > (data.size() - 4) / 4:
		return {"ok":false}
	var end: int = data.size() - 4 - count * 4
	var cursor := {"p":0}
	var previous := PackedByteArray()
	var rows := []
	while cursor.p < end:
		var shared := _varint(data, cursor, end)
		var non_shared := _varint(data, cursor, end)
		var value_length := _varint(data, cursor, end)
		if shared < 0 or shared > previous.size() or non_shared < 0 or value_length < 0 or non_shared + value_length > end - int(cursor.p):
			return {"ok":false}
		var key := previous.slice(0, shared)
		key.append_array(data.slice(cursor.p, cursor.p + non_shared))
		cursor.p += non_shared
		var value := data.slice(cursor.p, cursor.p + value_length)
		cursor.p += value_length
		rows.append({"key":key, "value":value})
		previous = key
	return {"ok":cursor.p == end, "rows":rows}

func _snappy(data: PackedByteArray) -> Variant:
	var cursor := {"p":0}
	var length := _varint(data, cursor, data.size())
	if length < 0 or length > MAX_FILE:
		return null
	var out := PackedByteArray()
	while cursor.p < data.size() and out.size() < length:
		var tag: int = data[cursor.p]
		cursor.p += 1
		var kind := tag & 3
		if kind == 0:
			var size := tag >> 2
			if size < 60:
				size += 1
			else:
				var width := size - 59
				if width > 4 or cursor.p + width > data.size():
					return null
				size = 1
				for i in width:
					size += int(data[cursor.p + i]) << (i * 8)
				cursor.p += width
			if size > length - out.size() or cursor.p + size > data.size():
				return null
			out.append_array(data.slice(cursor.p, cursor.p + size))
			cursor.p += size
		else:
			var width := 1 if kind == 1 else (2 if kind == 2 else 4)
			if cursor.p + width > data.size():
				return null
			var offset := (tag & 0xe0) << 3 if kind == 1 else 0
			for i in width:
				offset |= int(data[cursor.p + i]) << (i * 8)
			cursor.p += width
			var size := 4 + ((tag >> 2) & 7) if kind == 1 else 1 + (tag >> 2)
			if offset < 1 or offset > out.size() or size > length - out.size():
				return null
			for i in size:
				out.append(out[out.size() - offset])
	return out if out.size() == length and cursor.p == data.size() else null

func _dom_string(data: PackedByteArray) -> Variant:
	if data.is_empty() or data.size() > MAX_VALUE:
		return null
	var text := ""
	if data[0] == 1:
		for i in range(1, data.size()):
			text += String.chr(data[i])
		return text
	if data[0] != 0 or data.size() % 2 != 1:
		return null
	var i := 1
	while i < data.size():
		var unit := _u16(data, i)
		i += 2
		if unit >= 0xd800 and unit <= 0xdbff:
			if i >= data.size():
				return null
			var lower := _u16(data, i)
			if lower < 0xdc00 or lower > 0xdfff:
				return null
			unit = 0x10000 + ((unit - 0xd800) << 10) + lower - 0xdc00
			i += 2
		elif unit >= 0xdc00 and unit <= 0xdfff:
			return null
		text += String.chr(unit)
	return text

func _window_key(key: String) -> bool:
	if key.length() < 1 or key.length() > 40:
		return false
	for byte in key.to_utf8_buffer():
		if byte != 45 and (byte < 97 or byte > 122):
			return false
	return true
