extends RefCounted
const Binary = preload("res://systems/native_data/binary_data.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
const MAX_ENTRIES := 1000000
const MAX_RESOURCE_BYTES := 256 * 1024 * 1024
var failure := ""
var index_bytes := 0
var opened_size := 0
var index_cache_hit:=false
var index_cache_wait_us:=0
var index_identity:=""
func resident_index(kind: String,path: String,parts: Array,decode: Callable) -> Dictionary:
	var result:=Residency.index(kind,[path.simplify_path(),opened_size,FileAccess.get_modified_time(path)],parts,decode)
	index_cache_hit=bool(result.cache_hit); index_cache_wait_us=int(result.wait_us); index_identity=str(result.identity); failure=str(result.error)
	return result.value
func reject(message: String) -> Dictionary:
	if failure.is_empty(): failure = message
	return {}
func read_range(file: FileAccess, at: int, length: int) -> PackedByteArray:
	if at < 0 or length < 0 or length > MAX_RESOURCE_BYTES or at > opened_size or length > opened_size - at:
		reject("Archive range exceeds file bounds"); return PackedByteArray()
	file.seek(at)
	var result := file.get_buffer(length)
	index_bytes += result.size()
	if result.size() != length: reject("Archive read was truncated")
	return result
func _open(path: String) -> FileAccess:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: reject("Cannot open resource archive: " + path.get_file())
	opened_size = 0 if file == null else file.get_length()
	return file
func erf(path: String) -> Dictionary:
	failure = ""; index_bytes = 0
	var file := _open(path)
	if file == null: return {}
	var h := Binary.new(read_range(file, 0, 160))
	if not failure.is_empty(): return {}
	var tag: String = h.text(0, 4); var version: String = h.text(4, 4)
	var count: int = h.u32(16); var keys: int = h.u32(24); var resources: int = h.u32(28)
	if tag not in ["ERF ", "MOD ", "HAK "] or version not in ["V1.0", "V1.1"] or count > MAX_ENTRIES or resources < keys: return reject("Invalid ERF header")
	var stride := 24 if version == "V1.0" or (count > 0 and float(resources - keys) / count < 40) else 40
	var name_size := 32 if stride == 40 else 16
	var names := Binary.new(read_range(file, keys, count * stride)); var locations := Binary.new(read_range(file, resources, count * 8))
	if not failure.is_empty(): return {}
	return resident_index("erf",path,[h.data,names.data,locations.data],func():
		var value:=erf_entries(path,version,count,stride,name_size,names,locations)
		return {"value":value,"error":failure})
func erf_entries(path: String,version: String,count: int,stride: int,name_size: int,names,locations) -> Dictionary:
	var entries := {}
	for index in count:
		var name: String = names.text(index * stride, name_size, true).to_lower()
		var kind: int = names.u16(index * stride + name_size + 4)
		var at: int = locations.u32(index * 8); var size: int = locations.u32(index * 8 + 4)
		if at > opened_size or size > opened_size - at: return reject("ERF payload exceeds archive bounds")
		entries[name + ":" + str(kind)] = {"offset": at, "size": size, "type": kind}
	return {"entries": entries, "path": path, "size": opened_size, "modified": FileAccess.get_modified_time(path), "index_bytes": index_bytes, "version": version}
func key(path: String) -> Dictionary:
	failure = ""; index_bytes = 0
	var file := _open(path)
	if file == null: return {}
	var h := Binary.new(read_range(file, 0, 28))
	if not failure.is_empty(): return {}
	var version: String = h.text(4, 4)
	if h.text(0, 4) != "KEY " or version not in ["V1  ", "V1.1"]: return reject("Invalid KEY header")
	var bif_count: int = h.u32(8); var count: int = h.u32(12); var header_at := 20 if version == "V1.1" else 16
	if bif_count > MAX_ENTRIES or count > MAX_ENTRIES: return reject("KEY count exceeds supported bound")
	var bifs := Binary.new(read_range(file, h.u32(header_at), bif_count * 12))
	var stride := 26 if version == "V1.1" else 22
	var resources := Binary.new(read_range(file, h.u32(header_at + 4), count * stride))
	if not failure.is_empty(): return {}
	var filenames: Array = []
	for index in bif_count:
		var length: int = bifs.u32(index * 12 + 8) if version == "V1.1" else bifs.u16(index * 12 + 8)
		var name: String = Binary.new(read_range(file, bifs.u32(index * 12 + 4), length)).text(0, length, true).replace("\\", "/").to_lower()
		if not failure.is_empty(): return {}
		if name.is_empty() or name.is_absolute_path() or ":" in name or ".." in name.split("/"): return reject("Unsafe KEY archive path")
		filenames.append(name)
	return resident_index("key",path,[h.data,bifs.data,resources.data,var_to_bytes(filenames)],func():
		var value:=key_entries(version,count,stride,filenames,resources)
		return {"value":value,"error":failure})
func key_entries(version: String,count: int,stride: int,filenames: Array,resources) -> Dictionary:
	var entries := {}
	for index in count:
		var at := index * stride; var name: String = resources.text(at, 16, true).to_lower()
		var kind: int = resources.u16(at + 16); var resource_id: int = resources.u32(at + 18)
		var bif_id: int = (resources.u32(at + 22) if version == "V1.1" else resource_id) >> 20
		if bif_id >= filenames.size(): return reject("KEY references a missing BIF")
		entries[name + ":" + str(kind)] = {"bif": filenames[bif_id], "slot": resource_id & 0xfffff, "type": kind}
	return {"entries": entries, "bifs": filenames, "version": version, "index_bytes": index_bytes}
func bif(path: String) -> Dictionary:
	failure = ""; index_bytes = 0
	var file := _open(path)
	if file == null: return {}
	var h := Binary.new(read_range(file, 0, 20))
	if not failure.is_empty(): return {}
	var version: String = h.text(4, 4); var count: int = h.u32(8)
	if h.text(0, 4) != "BIFF" or version not in ["V1  ", "V1.1"] or count > MAX_ENTRIES: return reject("Invalid BIF header")
	if h.u32(12) != 0: return reject("Fixed BIF resources require a dedicated reader")
	var stride := 20 if version == "V1.1" else 16
	var table := Binary.new(read_range(file, h.u32(16), count * stride))
	if not failure.is_empty(): return {}
	return resident_index("bif",path,[h.data,table.data],func():
		var value:=bif_entries(path,version,count,stride,table)
		return {"value":value,"error":failure})
func bif_entries(path: String,version: String,count: int,stride: int,table) -> Dictionary:
	var entries: Array = []
	for index in count:
		var cursor := index * stride + (8 if version == "V1.1" else 4)
		var at: int = table.u32(cursor); var size: int = table.u32(cursor + 4)
		if at > opened_size or size > opened_size - at: return reject("BIF payload exceeds archive bounds")
		entries.append({"offset": at, "size": size, "type": table.u32(cursor + 8)})
	return {"entries": entries, "path": path, "size": opened_size, "modified": FileAccess.get_modified_time(path), "index_bytes": index_bytes}
func payload(archive: Dictionary, entry: Dictionary) -> PackedByteArray:
	failure = ""; index_bytes = 0
	var path := str(archive.get("path", "")); var file := _open(path)
	if file == null: return PackedByteArray()
	if opened_size != int(archive.size) or FileAccess.get_modified_time(path) != int(archive.modified):
		reject("Resource archive changed; rebuild the native catalog"); return PackedByteArray()
	return read_range(file, int(entry.offset), int(entry.size))
