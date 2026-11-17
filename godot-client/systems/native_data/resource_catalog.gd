extends RefCounted
# One session's ordered resource catalog. Workers use independent file handles.
# No eager BIF/HAK payload reads, Three scene, GLB, JSON/base64 or Electron.
const Archive = preload("res://systems/native_data/archive_index.gd")
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
const PreparationStore=preload("res://systems/native_data/preparation_store.gd")
const NWSync=preload("res://systems/native_data/nwsync_store.gd")
const Loose=preload("res://systems/native_data/loose_index.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
const SessionUiAssets=preload("res://systems/native_data/session_ui_asset_owner.gd")
const ItemIconSources=preload("res://systems/native_data/item_icon_sources.gd")
const SpellbookIconSources=preload("res://systems/native_data/spellbook_icon_sources.gd")
class BifStore:
	extends RefCounted
	var entries: Dictionary = {}
	var mutex := Mutex.new()
	var builds := 0
var failure := ""
var layers: Array = []
var recording
var resolved: Dictionary={}
var resolved_ready:=false
var _ui_asset_owner
var _ui_asset_scope_permitted:=true
var prepared_store:=PreparationStore.new()
var source_store:=PreparationStore.new()
var decoder_store=Residency.decoded
func _init() -> void:
	prepared_store.maximum_bytes=Residency.prepared_budget(); prepared_store.maximum_entries=2048
var bif_store := BifStore.new()
var bifs: Dictionary = bif_store.entries # Read-only view outside get_resource.
var nwsync_repair: Callable
var nested_archive_repair: Dictionary={}
var stats := {"index_bytes":0,"payload_bytes":0,"reads":0,"lookup_us":0,"lookups":0,"loose_read_us":0,"archive_read_us":0,"bif_index_wait_us":0,"nwsync_read_us":0,"nwsync_wait_us":0,"nwsync_pipe_us":0,"nwsync_decode_us":0,"source_memory_hits":0,"source_coalesced_wait_us":0,"source_requests":0}
func count_source_cache(timing: Dictionary) -> void:
	for name in ["cache_read_us","cache_save_us","cache_prune_us","raw_cache_us"]:
		var key: String="nwsync_"+str(name); stats[key]=int(stats.get(key,0))+int(timing.get(name,0))
func residency_stats() -> Dictionary: return Residency.snapshot()
func invalidate() -> void:
	# Detach bindings instead of mutating an index retained by existing forks.
	_ui_asset_owner=null
	resolved={}; resolved_ready=false; source_store=PreparationStore.new(); prepared_store.clear()
func ui_asset_owner():
	# Generic forks are payload readers, often retired on worker threads. They
	# must never hold or create the main-thread GPU texture owner.
	if not _ui_asset_scope_permitted: return null
	if _ui_asset_owner==null: _ui_asset_owner=SessionUiAssets.new()
	if _ui_asset_owner.closed: return null
	if _ui_asset_owner.binding_identities.is_empty():
		var identities: Array=[]
		for layer in layers: identities.append(str(layer.get("binding_identity","")))
		_ui_asset_owner.configure(identities)
	return _ui_asset_owner
func release_ui_assets() -> void:
	if _ui_asset_owner!=null: _ui_asset_owner.close()
func build_resource_index() -> Dictionary:
	var began:=Time.get_ticks_usec(); var identities: Array=[]
	for layer in layers:
		if str(layer.get("binding_identity","")).is_empty(): identities.clear(); break
		identities.append(str(layer.binding_identity))
	if identities.size()==layers.size():
		var cached:=Residency.index("ordered-bindings",identities,[],func():return {"value":{"entries":compile_bindings()},"error":""},Residency.bindings)
		resolved=cached.value.entries; resolved_ready=true
		return {"resolved_entries":resolved.size(),"index_build_ms":(Time.get_ticks_usec()-began)/1000.0,"residency_hit":cached.cache_hit}
	resolved=compile_bindings(); resolved_ready=true
	return {"resolved_entries":resolved.size(),"index_build_ms":(Time.get_ticks_usec()-began)/1000.0,"residency_hit":false}
func compile_bindings() -> Dictionary:
	var entries: Dictionary={}
	for index in layers.size():
		for key in layers[index].entries:
			if not entries.has(key): entries[key]=index
	return entries
func reset() -> void:
	_ui_asset_owner=null
	nwsync_repair=Callable()
	nested_archive_repair={}
	prepared_store=PreparationStore.new(); source_store=PreparationStore.new()
	decoder_store=Residency.decoded; _init()
	layers=[]; resolved={}; resolved_ready=false; bif_store = BifStore.new(); bifs = bif_store.entries; failure = ""
	for key in stats: stats[key]=0
func mount_install(install_root: String, language: String = "en") -> bool:
	failure = ""
	if not language.is_valid_identifier(): failure = "Invalid install language directory"; return false
	var before: Array = layers.duplicate()
	# The old game-data reader inspected these two directories and required each
	# selected KEY basename to be unique across them. Probe only those six paths.
	var directories: Array[String]=[install_root.path_join("data"),install_root.path_join("lang").path_join(language).path_join("data")]
	var sources := [["nwn_base_loc.key", 3000000, false], ["nwn_retail.key", 2000000, false], ["nwn_base.key", 1000000, true]]
	for source in sources:
		var path: String=""
		for directory in directories:
			var candidate: String=directory.path_join(str(source[0]))
			if not FileAccess.file_exists(candidate): continue
			if not path.is_empty(): failure="Could not uniquely locate "+str(source[0])+" in the selected game-data folder."; layers=before; return false
			path=candidate
		if path.is_empty():
			if bool(source[2]): failure="The selected game-data folder must contain data/nwn_base.key."; layers=before; return false
			continue
		if not mount_key(path, install_root, int(source[1])): layers = before; return false
	return true
func fork() -> RefCounted:
	# Immutable indexes are shared after locked publication. Every payload read
	# still opens its own file handle; workers never share a seek position.
	var copy = get_script().new()
	copy.layers = layers.duplicate()
	copy.resolved=resolved; copy.resolved_ready=resolved_ready
	copy.prepared_store=prepared_store
	copy.source_store=source_store
	copy.decoder_store=decoder_store
	copy.recording=recording
	copy._ui_asset_scope_permitted=false
	copy.bif_store = bif_store; copy.bifs = bif_store.entries
	return copy
func bind_nwsync_repair(callback: Callable)->void:
	# Main-thread publication owner only. Worker forks carry source data, not
	# an HTTP/scene Callable.
	nwsync_repair=callback
func nwsync_repair_binding(name: String,type: int)->Dictionary:
	var found:=location(name,type)
	if found.is_empty():return {}
	var kind:=str(found.layer.get("kind",""))
	if kind=="nwsync":return {"store":found.layer.store,"entry":found.entry}
	if kind=="nwsync-erf":return {"store":found.layer.store,"entry":found.layer.source_entry}
	return {}
func preparation_cache(): return prepared_store
func decoded_cache(): return decoder_store
func bif_index_build_count() -> int:
	bif_store.mutex.lock(); var count := bif_store.builds; bif_store.mutex.unlock(); return count
func mount_nwsync(manifest_hash: String, cache_directory: String, native_directory: String="", helper: String="", priority: int=40000000, raw_cache_directory: String="") -> bool:
	failure=""
	var store:=NWSync.new()
	if not store.configure(cache_directory,native_directory,helper,raw_cache_directory): failure="Native NWSync store is unavailable"; return false
	var manifest:=store.manifest(manifest_hash)
	if manifest.has("error"): failure=manifest.error; store.close(); return false
	layers.append({"kind":"nwsync","priority":priority,"serial":layers.size(),"storage_class":5,"store":store,"entries":manifest.entries,"binding_identity":"nwsync:"+manifest_hash})
	invalidate()
	layers.sort_custom(func(a,b): return a.priority>b.priority or (a.priority==b.priority and a.serial<b.serial))
	return true
func mount_directory(directory: String, priority: int=10000000, types: Array=[],portrait_alias: String="") -> bool:
	failure=""
	var reader:=Loose.new(); var index:=reader.scan(directory,types)
	if not reader.failure.is_empty(): failure=reader.failure; return false
	if index.entries.is_empty(): return true
	layers.append({"kind":"loose","priority":priority,"serial":layers.size(),"storage_class":2,"entries":index.entries,"binding_identity":reader.index_identity,"portrait_alias":portrait_alias})
	invalidate()
	layers.sort_custom(func(a,b):return a.priority>b.priority or (a.priority==b.priority and a.serial<b.serial))
	return true
func mount_erf(path: String, priority: int = 0) -> bool:
	failure = ""
	var reader := Archive.new(); var index: Dictionary = reader.erf(path)
	if not reader.failure.is_empty(): failure = reader.failure; return false
	stats.index_bytes += reader.index_bytes
	layers.append({"kind": "erf", "priority": priority, "serial": layers.size(), "archive": index, "entries": index.entries,"binding_identity":reader.index_identity})
	invalidate()
	layers.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.serial < b.serial))
	return true
func mount_nwsync_erf(store: RefCounted,source_entry: Dictionary,priority: int,source_name: String) -> bool:
	failure="";nested_archive_repair={}
	if store==null or not store.has_method("resource_borrowed") or str(source_entry.get("hash","")).length()!=40:failure="Invalid verified NWSync archive source";return false
	var source: Dictionary=store.resource_borrowed(source_entry)
	if source.has("error"):
		failure=str(source.error)
		nested_archive_repair={"store":store,"entry":source_entry.duplicate(true)}
		return false
	var reader:=Archive.new()
	var index: Dictionary=reader.erf_bytes_index(source.bytes,str(source_entry.hash))
	if not reader.failure.is_empty():failure=reader.failure;return false
	stats.index_bytes+=reader.index_bytes
	layers.append({"kind":"nwsync-erf","priority":priority,"serial":layers.size(),"store":store,"source_entry":source_entry.duplicate(true),"archive":index,"entries":index.entries,"binding_identity":"nwsync-erf:"+str(source_entry.hash)+":"+source_name+":"+str(reader.index_identity)})
	invalidate()
	layers.sort_custom(func(a,b):return a.priority>b.priority or a.priority==b.priority and a.serial<b.serial)
	return true
func mount_key(path: String, install_root: String, priority: int = 0) -> bool:
	failure = ""
	var reader := Archive.new(); var index: Dictionary = reader.key(path)
	if not reader.failure.is_empty(): failure = reader.failure; return false
	stats.index_bytes += reader.index_bytes
	layers.append({"kind": "key", "priority": priority, "serial": layers.size(), "root": install_root.simplify_path(), "entries": index.entries,"binding_identity":reader.index_identity})
	invalidate()
	layers.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.serial < b.serial))
	return true
func location(name: String, type: int) -> Dictionary:
	var began:=Time.get_ticks_usec(); stats.lookups+=1
	var key := name.to_lower() + ":" + str(type)
	if resolved_ready:
		var index:=int(resolved.get(key,-1)); stats.lookup_us+=Time.get_ticks_usec()-began
		if index<0: return {}
		var layer: Dictionary=layers[index]
		return {"layer":layer,"entry":layer.entries[key]}
	for layer in layers:
		if layer.entries.has(key):
			stats.lookup_us+=Time.get_ticks_usec()-began
			return {"layer": layer, "entry": layer.entries[key]}
	stats.lookup_us+=Time.get_ticks_usec()-began
	return {}
func has_resource(name: String, type: int) -> bool: return not location(name, type).is_empty()
func portrait_files() -> Array: return preload("res://systems/native_data/portrait_resources.gd").files(layers)
func resource_names(type: int) -> Array:
	var names: Dictionary={}; var suffix:=":"+str(type)
	if resolved_ready:
		for key in resolved:
			if str(key).ends_with(suffix): names[str(key).trim_suffix(suffix)]=true
		return names.keys()
	for layer in layers:
		for key in layer.entries:
			if str(key).ends_with(suffix): names[str(key).trim_suffix(suffix)]=true
	return names.keys()
func raster_location(name: String) -> Dictionary:
	# Format ties use original storage classes, not priorities across formats.
	for storage_class in [2,5,3,1]:
		for type in [2073,2033,2059,3]:
			var found := location(name,type)
			if found.is_empty(): continue
			var actual: int = found.layer.get("storage_class",1 if found.layer.kind == "key" else 3)
			if actual == storage_class: return {"name":name.to_lower(),"type":type}
	return {}
func recorded_texture_miss(name: String) -> bool:
	# This catalog is complete for the selected live session. An absent bitmap
	# is an authoritative lookup miss, unlike an unrecorded capture dependency.
	# Keep geometry/material colors; present/corrupt rasters and unresolved PLTs
	# remain preparation errors and do not become guessed replacement textures.
	return raster_location(name).is_empty() and not has_resource(name,6)
func get_resource(name: String, type: int) -> PackedByteArray:
	stats.source_requests+=1
	var selected:=location(name,type)
	if not selected.is_empty() and str(selected.layer.get("kind",""))=="erf":
		var archive: Dictionary=selected.layer.archive
		if bool(archive.get("stamp_precise",false)):
			var current: Dictionary=Backend.file_stamp(str(archive.path))
			if current.has("error") or int(current.get("size",-1))!=int(archive.size) or int(current.get("modified",-1))!=int(archive.modified):
				failure="Resource archive changed; rebuild the native catalog"
				return PackedByteArray()
		else:
			# A whole-second stamp cannot distinguish an index-table rewrite either.
			# Re-read only the ERF header/tables and compare their residency identity
			# before using the mounted offset. The payload itself still bypasses the
			# resident caches so an equal-size payload rewrite reads current bytes.
			var verifier:=Archive.new()
			verifier.erf(str(archive.path))
			if not verifier.failure.is_empty() or verifier.index_identity!=str(selected.layer.binding_identity):
				failure="Resource archive changed; rebuild the native catalog"
				return PackedByteArray()
			var fresh: PackedByteArray=read_resource(name,type)
			if recording!=null:recording.record(name,type,fresh,failure)
			return fresh
	var resident: PackedByteArray=ItemIconSources.lookup(self,name,type) if type in [3,6,2073,2033,2059] else PackedByteArray()
	if resident.is_empty() and type in [3,2073,2033,2059]: resident=SpellbookIconSources.lookup(self,name,type)
	if not resident.is_empty():
		failure=""; stats.source_memory_hits+=1
		if recording!=null: recording.record(name,type,resident,"")
		return resident
	var key:=name.to_lower()+":"+str(type); var generation:=source_store.generation()
	var lease:=source_store.begin_data(key,generation); var bytes: PackedByteArray
	if lease.owner:
		bytes=read_resource(name,type)
		var value:={"bytes":bytes,"error":failure}
		if failure.is_empty(): source_store.save_data(key,key,value,generation,bytes.size()+128)
		source_store.finish_data(key,generation,value)
	else:
		bytes=lease.value.bytes; failure=str(lease.value.error); stats.source_memory_hits+=1; stats.source_coalesced_wait_us+=int(lease.wait_us)
	if recording!=null: recording.record(name,type,bytes,failure)
	return bytes.duplicate() if not selected.is_empty() and str(selected.layer.get("kind",""))=="nwsync-erf" else bytes
func read_resource(name: String, type: int) -> PackedByteArray:
	failure = ""
	var found := location(name, type)
	if found.is_empty(): failure = "Resource not found: " + name + ":" + str(type); return PackedByteArray()
	var layer: Dictionary = found.layer; var entry: Dictionary = found.entry
	if layer.kind=="loose":
		var began:=Time.get_ticks_usec()
		var loose:=Loose.new(); var payload:=loose.payload(entry)
		stats.loose_read_us+=Time.get_ticks_usec()-began
		if not loose.failure.is_empty(): failure=loose.failure; return PackedByteArray()
		stats.payload_bytes+=payload.size(); stats.reads+=1; return payload
	if layer.kind=="nwsync":
		var began:=Time.get_ticks_usec()
		var result: Dictionary=layer.store.resource(entry)
		stats.nwsync_read_us+=Time.get_ticks_usec()-began
		count_source_cache(result.get("timings",{}))
		for stage in ["wait","pipe","decode"]: stats["nwsync_"+stage+"_us"]+=int(result.get("timings",{}).get(stage+"_us",0))
		if result.has("error"): failure=result.error; return PackedByteArray()
		var original: PackedByteArray=result.bytes
		stats.payload_bytes+=original.size(); stats.reads+=1; return original
	if layer.kind=="nwsync-erf":
		var began:=Time.get_ticks_usec()
		var source: Dictionary=layer.store.resource_borrowed(layer.source_entry)
		stats.nwsync_read_us+=Time.get_ticks_usec()-began
		count_source_cache(source.get("timings",{}))
		if source.has("error"):failure=str(source.error);return PackedByteArray()
		var archive_bytes: PackedByteArray=source.bytes
		var offset:=int(entry.get("offset",-1));var size:=int(entry.get("size",-1))
		if archive_bytes.size()!=int(layer.archive.size) or offset<0 or size<0 or offset>archive_bytes.size() or size>archive_bytes.size()-offset:
			failure="Nested NWSync archive changed or resource bounds differ";return PackedByteArray()
		var nested:=archive_bytes.slice(offset,offset+size)
		stats.payload_bytes+=nested.size();stats.reads+=1;return nested
	var reader := Archive.new(); var archive: Dictionary
	if layer.kind == "key":
		var path: String = layer.root.path_join(entry.bif)
		var began:=Time.get_ticks_usec()
		bif_store.mutex.lock()
		stats.bif_index_wait_us+=Time.get_ticks_usec()-began
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
	var began:=Time.get_ticks_usec()
	var bytes: PackedByteArray = reader.payload(archive, entry)
	stats.archive_read_us+=Time.get_ticks_usec()-began
	if not reader.failure.is_empty(): failure = reader.failure; return PackedByteArray()
	stats.payload_bytes += bytes.size(); stats.reads += 1
	return bytes
