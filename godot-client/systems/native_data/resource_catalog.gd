extends RefCounted
# One session's ordered resource catalog. Workers use independent file handles.
# No eager BIF/HAK payload reads, Three scene, GLB, JSON/base64 or Electron.
const Archive = preload("res://systems/native_data/archive_index.gd")
class BifStore:
	extends RefCounted
	var entries: Dictionary = {}
	var mutex := Mutex.new()
	var builds := 0
var failure := ""
var layers: Array = []
var bif_store := BifStore.new()
var bifs: Dictionary = bif_store.entries # Read-only view outside get_resource.
var stats := {"index_bytes": 0, "payload_bytes": 0, "reads": 0}
func reset() -> void:
	layers.clear(); bif_store = BifStore.new(); bifs = bif_store.entries; failure = ""
	stats = {"index_bytes": 0, "payload_bytes": 0, "reads": 0}
func mount_install(install_root: String, language: String = "en") -> bool:
	failure = ""
	if not language.is_valid_identifier(): failure = "Invalid install language directory"; return false
	var before: Array = layers.duplicate()
	var sources := [["data/nwn_base.key", 1000000, true], ["data/nwn_retail.key", 2000000, false], ["lang/" + language + "/data/nwn_base_loc.key", 3000000, false]]
	for source in sources:
		var path: String = install_root.path_join(source[0])
		if not FileAccess.file_exists(path) and not source[2]: continue
		if not mount_key(path, install_root, source[1]): layers = before; return false
	return true
func fork() -> RefCounted:
	# Immutable indexes are shared after locked publication. Every payload read
	# still opens its own file handle; workers never share a seek position.
	var copy = get_script().new()
	copy.layers = layers.duplicate()
	copy.bif_store = bif_store; copy.bifs = bif_store.entries
	return copy
func bif_index_build_count() -> int:
	bif_store.mutex.lock(); var count := bif_store.builds; bif_store.mutex.unlock(); return count
func mount_erf(path: String, priority: int = 0) -> bool:
	failure = ""
	var reader := Archive.new(); var index: Dictionary = reader.erf(path)
	if not reader.failure.is_empty(): failure = reader.failure; return false
	stats.index_bytes += reader.index_bytes
	layers.append({"kind": "erf", "priority": priority, "serial": layers.size(), "archive": index, "entries": index.entries})
	layers.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.serial < b.serial))
	return true
func mount_key(path: String, install_root: String, priority: int = 0) -> bool:
	failure = ""
	var reader := Archive.new(); var index: Dictionary = reader.key(path)
	if not reader.failure.is_empty(): failure = reader.failure; return false
	stats.index_bytes += reader.index_bytes
	layers.append({"kind": "key", "priority": priority, "serial": layers.size(), "root": install_root.simplify_path(), "entries": index.entries})
	layers.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.serial < b.serial))
	return true
func location(name: String, type: int) -> Dictionary:
	var key := name.to_lower() + ":" + str(type)
	for layer in layers:
		if layer.entries.has(key): return {"layer": layer, "entry": layer.entries[key]}
	return {}
func has_resource(name: String, type: int) -> bool: return not location(name, type).is_empty()
func raster_location(name: String) -> Dictionary:
	# Format ties use original storage classes, not priorities across formats.
	for storage_class in [2,5,3,1]:
		for type in [2073,2033,2059,3]:
			var found := location(name,type)
			if found.is_empty(): continue
			var actual: int = found.layer.get("storage_class",1 if found.layer.kind == "key" else 3)
			if actual == storage_class: return {"name":name.to_lower(),"type":type}
	return {}
func get_resource(name: String, type: int) -> PackedByteArray:
	failure = ""
	var found := location(name, type)
	if found.is_empty(): failure = "Resource not found: " + name + ":" + str(type); return PackedByteArray()
	var layer: Dictionary = found.layer; var entry: Dictionary = found.entry
	var reader := Archive.new(); var archive: Dictionary
	if layer.kind == "key":
		var path: String = layer.root.path_join(entry.bif)
		bif_store.mutex.lock()
		if not bif_store.entries.has(path):
			var index: Dictionary = reader.bif(path)
			if not reader.failure.is_empty(): bif_store.mutex.unlock(); failure = reader.failure; return PackedByteArray()
			stats.index_bytes += reader.index_bytes; bif_store.entries[path] = index; bif_store.builds += 1
		archive = bif_store.entries[path]
		bif_store.mutex.unlock()
		if int(entry.slot) >= archive.entries.size(): failure = "KEY slot exceeds BIF table"; return PackedByteArray()
		entry = archive.entries[int(entry.slot)]
		if int(entry.type) != type: failure = "KEY/BIF resource type mismatch"; return PackedByteArray()
	else: archive = layer.archive
	var bytes: PackedByteArray = reader.payload(archive, entry)
	if not reader.failure.is_empty(): failure = reader.failure; return PackedByteArray()
	stats.payload_bytes += bytes.size(); stats.reads += 1
	return bytes
