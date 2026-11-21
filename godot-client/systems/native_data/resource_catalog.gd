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
	var paths: Dictionary = {}
	var mutex := Mutex.new()
	var builds := 0
class DiagnosticJournal:
	extends RefCounted
	signal recorded(row: Dictionary)
	var records: Array[Dictionary]=[]
	var mutex:=Mutex.new()
	var session: String="catalog-"+str(Time.get_ticks_usec())
	func record(code: String,message: String,context: Dictionary={},severity: String="warning") -> void:
		var row: Dictionary={"version":1,"session":session,"sequence":records.size()+1,"timestamp":Time.get_datetime_string_from_system(true)+"Z","code":code,"severity":severity,"message":message,"context":context.duplicate(true)}
		mutex.lock()
		row.sequence=records.size()+1
		records.append(row)
		mutex.unlock()
		call_deferred("emit_signal","recorded",row.duplicate(true))
	func snapshot() -> Array[Dictionary]:
		mutex.lock();var rows:=records.duplicate(true);mutex.unlock();return rows
var failure := ""
var diagnostic_journal:=DiagnosticJournal.new()
func diagnostic_records() -> Array[Dictionary]:return diagnostic_journal.snapshot()
func record_diagnostic(code: String,message: String,context: Dictionary={},severity: String="warning") -> void:
	diagnostic_journal.record(code,message,context,severity)
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
	prepared_store.maximum_bytes=Residency.prepared_budget()
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
	if _ui_asset_owner==null:
		_ui_asset_owner=SessionUiAssets.new()
		_ui_asset_owner.asset_unavailable.connect(func(_kind: String,key: String,reason: String)->void:
			record_diagnostic("ui.asset-unavailable",key+": "+reason))
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
	diagnostic_journal=DiagnosticJournal.new()
	nwsync_repair=Callable()
	nested_archive_repair={}
	prepared_store=PreparationStore.new(); source_store=PreparationStore.new()
	decoder_store=Residency.decoded; _init()
	layers=[]; resolved={}; resolved_ready=false; bif_store = BifStore.new(); bifs = bif_store.entries; failure = ""
	for key in stats: stats[key]=0
func mount_install(install_root: String, language: String = "en") -> bool:
	failure = ""
	if not language.is_valid_identifier():
		failure = "Invalid install language directory";record_diagnostic("load.game-data-failed",failure,{},"error");return false
	var before: Array = layers.duplicate()
	# localResourceFile/openServerResourceContext inventoried ordinary files in
	# these two directories. KEY and later BIF selection use the same inventory.
	var directories: Array[String]=[install_root.path_join("data"),install_root.path_join("lang").path_join(language).path_join("data")]
	var normalized_root:=install_root.simplify_path().replace("\\","/").trim_suffix("/")
	var game_files: Array[Dictionary]=[]
	for directory in directories:
		var folder:=DirAccess.open(directory)
		if folder==null:
			if DirAccess.dir_exists_absolute(directory):failure="Selected game-data directory cannot be read";layers=before;record_diagnostic("load.game-data-failed",failure,{},"error");return false
			continue
		for filename in folder.get_files():
			if folder.is_link(filename):continue
			var path:=directory.path_join(filename)
			var normalized_path:=path.simplify_path().replace("\\","/")
			game_files.append({"path":path,"relative":normalized_path.trim_prefix(normalized_root+"/").to_lower()})
	var sources := [["nwn_base_loc.key", 3000000, false], ["nwn_retail.key", 2000000, false], ["nwn_base.key", 1000000, true]]
	for source in sources:
		var matches:=installed_file_matches(game_files,str(source[0]))
		if matches.size()>1:failure="Could not uniquely locate "+str(source[0])+" in the selected game-data folder.";layers=before;record_diagnostic("load.game-data-failed",failure,{},"error");return false
		var path: String=str(matches[0]) if not matches.is_empty() else ""
		if path.is_empty():
			if bool(source[2]): failure="The selected game-data folder must contain data/nwn_base.key."; layers=before;record_diagnostic("load.game-data-failed",failure,{},"error"); return false
			if str(source[0])=="nwn_retail.key":record_diagnostic("resource.key-missing","Installed retail resource KEY is unavailable; updated resources cannot be loaded",{"resource":"nwn_retail.key"})
			continue
		if not mount_key(path, install_root, int(source[1]),game_files): layers = before;record_diagnostic("load.game-data-failed",failure,{},"error"); return false
	return true
static func installed_file_matches(game_files: Array[Dictionary],wanted: String)->Array[String]:
	var normalized:=wanted.replace("\\","/").to_lower()
	var matches: Array[String]=[]
	for entry in game_files:
		var relative:=str(entry.relative)
		if relative==normalized or relative.ends_with("/"+normalized):matches.append(str(entry.path))
	return matches
func fork() -> RefCounted:
	# Immutable indexes are shared after locked publication. Every payload read
	# still opens its own file handle; workers never share a seek position.
	var copy = get_script().new()
	copy.layers = layers.duplicate()
	copy.resolved=resolved; copy.resolved_ready=resolved_ready
	copy.prepared_store=prepared_store
	copy.source_store=source_store
	copy.decoder_store=decoder_store
	copy.diagnostic_journal=diagnostic_journal
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
func mount_key(path: String, install_root: String, priority: int = 0,game_files: Array[Dictionary]=[]) -> bool:
	failure = ""
	var reader := Archive.new(); var index: Dictionary = reader.key(path)
	if not reader.failure.is_empty(): failure = reader.failure; return false
	stats.index_bytes += reader.index_bytes
	layers.append({"kind": "key", "priority": priority, "serial": layers.size(), "root": install_root.simplify_path(), "key_source":path.get_file(),"game_files":game_files,"entries": index.entries,"binding_identity":reader.index_identity})
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
func resource_location(name: String, type: int) -> int:
	# ResourceResolver.resourceLocation exposes the winning native table class.
	var selected: Dictionary=location(name,type)
	if selected.is_empty():return 0
	var layer: Dictionary=selected.layer
	return int(layer.get("storage_class",1 if layer.kind=="key" else 3))
static func native_audio_ref_valid(name: String)->bool:
	if name.is_empty() or name.contains("/") or name.contains("\\") or name.contains(":") or name.contains("\u0000"):return false
	var encoded: Dictionary=preload("res://systems/native_data/native_text_encoding.gd").encode(name,0)
	return bool(encoded.get("ready",false)) and encoded.get("bytes",PackedByteArray()).size()<=16
func audio_resource_type(name: String,requested_type: int)->int:
	if not native_audio_ref_valid(name) or requested_type not in [4,8]:return -1
	for type in [8,4] if requested_type==4 else [8]:
		if has_resource(name,type):return type
	return -1
func wave_resource(name: String)->Dictionary:
	if not native_audio_ref_valid(name):return {"error":"Invalid native WAV resource request"}
	if not has_resource(name,4):return {"error":"Native WAV resource is unavailable","resref":name}
	var bytes:=get_resource(name,4)
	return {"error":failure} if not failure.is_empty() else {"bytes":bytes}
func audio_resource(name: String,requested_type: int)->Dictionary:
	if not native_audio_ref_valid(name) or requested_type not in [4,8]:return {"error":"Invalid native audio resource request"}
	var selected:=audio_resource_type(name,requested_type)
	if selected<0:return {"error":"Native audio resource is unavailable","resref":name,"requestedType":requested_type}
	var bytes:=get_resource(name,selected)
	return {"error":failure} if not failure.is_empty() else {"type":selected,"bytes":bytes}
func portrait_files() -> Array: return preload("res://systems/native_data/portrait_resources.gd").files(layers)
func creation_portrait_names() -> Array:
	# ResourceResolver.portraitNames used priorityLayers order and the first
	# occurrence of each bare raster resref, before the medium-suffix filter.
	var result: Array=[];var seen: Dictionary={}
	for layer in layers:
		if str(layer.get("portrait_alias","")) not in ["portraits","portraitsinstall"]:continue
		for key in layer.entries:
			var suffix:=str(key).get_slice(":",1)
			if suffix not in ["3","2033"]:continue
			var name:=str(key).get_slice(":",0)
			if not seen.has(name):seen[name]=true;result.append(name)
	return result
static func resource_name_group(layer: Dictionary)->int:
	var kind:=str(layer.get("kind",""))
	if kind=="key":return 0
	if kind in ["erf","nwsync-erf"]:
		var priority:=int(layer.get("priority",0))
		if priority>=22000000 and priority<29000000:return 1 # module
		if priority>=30000000:return 2 # selected server HAKs
		return 3 # Workshop HAKs
	if kind=="nwsync":return 4
	if kind=="loose" and not str(layer.get("portrait_alias","")).is_empty():return 5
	return 6 # override and other loose fallbacks
func resource_names(type: int) -> Array:
	# The former resourceNames concatenated KEY, module, selected HAK,
	# Workshop HAK, NWSync, portrait and fallback keys before Set deduplication.
	# This enumeration order differs from lookup precedence.
	var names: Dictionary={}; var suffix:=":"+str(type)
	var ordered:=layers.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		var left:=resource_name_group(a);var right:=resource_name_group(b)
		if left!=right:return left<right
		if int(a.priority)!=int(b.priority):return int(a.priority)>int(b.priority)
		return int(a.serial)<int(b.serial))
	for layer in ordered:
		for key in layer.entries:
			if str(key).ends_with(suffix): names[str(key).trim_suffix(suffix)]=true
	return names.keys()
func raster_location(name: String) -> Dictionary:
	# Format ties use original storage classes, not priorities across formats.
	for storage_class in [2,5,3,1]:
		for type in [2073,2033,2059,3]:
			if resource_location(name,type)==storage_class:return {"name":name.to_lower(),"type":type}
	return {}
func get_texture_resource(name: String) -> Dictionary:
	# ResourceResolver.getTextureResource: choose the winning native storage
	# class before reading. A selected source's read failure cannot fall through.
	failure=""
	var selected: Dictionary=raster_location(name)
	var type:=int(selected.get("type",-1))
	if type==2059:
		var message:="Native16-bit texture2059 "+name+" requires an unsupported decoder"
		record_diagnostic("texture.native-16bit-unhandled",message,{"resRef":name,"resourceType":2059})
		return {"error":message,"code":"UNSUPPORTED_TEXTURE_TYPE","resourceType":2059}
	if type<0 and has_resource(name,6):type=6
	if type<0:return {"error":"Texture "+name+" is unavailable","code":"RESOURCE_NOT_FOUND"}
	var bytes: PackedByteArray=get_resource(name,type)
	if not failure.is_empty():return {"error":failure,"code":"RESOURCE_READ_FAILED","resourceType":type}
	var extension:=str({2073:"ktx",2033:"dds",3:"tga",6:"plt"}.get(type,""))
	return {"type":type,"extension":extension,"bytes":bytes}
func record_resource_failure(name: String,type: int) -> void:
	if failure.is_empty():return
	var found: Dictionary=location(name,type)
	var lookup:=found.is_empty()
	var bif_name: String=str(found.entry.get("bif","")) if not lookup and str(found.layer.get("kind",""))=="key" else ""
	var key_sources: Array=[];var haks: Array=[]
	for layer in layers:
		if str(layer.get("kind",""))=="key":key_sources.append(str(layer.get("key_source","")))
		elif str(layer.get("kind",""))=="erf" and int(layer.get("priority",0))>=30000000:haks.append(str(layer.archive.get("path","")).get_file())
	var extension: Variant=preload("res://systems/native_data/resource_extensions.gd").TYPES.find_key(type)
	record_diagnostic("resource.lookup-failed" if lookup else "resource.read-failed",failure,{"resRef":name.to_lower(),"resourceType":type,"bifName":bif_name,"keySources":key_sources,"resourceExtension":str(extension),"haks":haks,"outcome":"lookup failed; consumer may recover with a fallback" if lookup else "archive read failed; consumer may recover with a fallback"},"info" if lookup else "error")
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
				failure="Mod archive changed; reconnect to reload its index";record_resource_failure(name,type)
				return PackedByteArray()
		else:
			# A whole-second stamp cannot distinguish an index-table rewrite either.
			# Re-read only the ERF header/tables and compare their residency identity
			# before using the mounted offset. The payload itself still bypasses the
			# resident caches so an equal-size payload rewrite reads current bytes.
			var verifier:=Archive.new()
			verifier.erf(str(archive.path))
			if not verifier.failure.is_empty() or verifier.index_identity!=str(selected.layer.binding_identity):
				failure="Mod archive changed; reconnect to reload its index";record_resource_failure(name,type)
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
	if not lease.owner and not failure.is_empty():record_resource_failure(name,type)
	if recording!=null: recording.record(name,type,bytes,failure)
	return bytes.duplicate() if not selected.is_empty() and str(selected.layer.get("kind",""))=="nwsync-erf" else bytes
func read_resource(name: String, type: int) -> PackedByteArray:
	var bytes:=_read_resource(name,type)
	if not failure.is_empty():record_resource_failure(name,type)
	return bytes
func _read_resource(name: String, type: int) -> PackedByteArray:
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
		var wanted:=str(entry.bif)
		var identity:=str(layer.root)+":"+wanted
		var began:=Time.get_ticks_usec()
		bif_store.mutex.lock()
		stats.bif_index_wait_us+=Time.get_ticks_usec()-began
		if not bif_store.paths.has(identity):
			var matches:=installed_file_matches(layer.get("game_files",[]),wanted)
			if matches.is_empty() and layer.get("game_files",[]).is_empty():matches.append(str(layer.root).path_join(wanted))
			if matches.size()!=1:bif_store.mutex.unlock();failure="Could not uniquely locate "+wanted+" in the selected game-data folder.";return PackedByteArray()
			bif_store.paths[identity]=matches[0]
		var path: String=str(bif_store.paths[identity])
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
