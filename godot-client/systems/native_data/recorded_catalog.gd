extends RefCounted
# Closed-world native loading replay. Resource presence/class comes from the
# original mounted catalog; missing recorded payloads are explicit capture gaps.
const Store=preload("res://systems/native_data/preparation_store.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
var directory:=""
var manifest: Dictionary={}
var failure:=""
var layers: Array=[]
var prepared_store:=Store.new()
var decoder_store:=Store.new()
var packed_catalog
# Explicit opaque source scope; no raw-source cache is invented for a recording.
class SealedSourceScope:
	extends RefCounted
	var mutex:=Mutex.new()
	var healthy:=true
	func current() -> bool:
		mutex.lock();var result:=healthy;mutex.unlock();return result
	func revoke() -> void:
		mutex.lock();healthy=false;mutex.unlock()
var _source_scope
var _sealed_manifest: Dictionary={}
var _sealed_layers: Array=[]
var _sealed_directory:=""
var _sealed_packed
var _sealed_packed_store
var _sealed_packed_generation:=-1
func invalidate_cache_source_scope() -> void:
	if _source_scope!=null:_source_scope.revoke()
func cache_source_scope_v1() -> RefCounted:
	# O(1) witnesses only. Every nested JSON container was sealed once at mount.
	if _source_scope==null or not _source_scope.current():return null
	var valid: bool=directory==_sealed_directory and is_same(manifest,_sealed_manifest) and is_same(layers,_sealed_layers) and packed_catalog==_sealed_packed
	if valid and packed_catalog!=null:
		valid=packed_catalog.source_store==_sealed_packed_store and _sealed_packed_store.generation()==_sealed_packed_generation
	if not valid:invalidate_cache_source_scope();return null
	return _source_scope
func _capture_scope_witness() -> void:
	_sealed_manifest=manifest;_sealed_layers=layers;_sealed_directory=directory;_sealed_packed=packed_catalog
	_sealed_packed_store=packed_catalog.source_store if packed_catalog!=null else null
	_sealed_packed_generation=_sealed_packed_store.generation() if _sealed_packed_store!=null else -1
func _seal_graph(value: Variant) -> int:
	# JSON cannot contain cycles. Do one iterative pass, without copying payloads.
	var todo: Array=[value];var containers:=0
	while not todo.is_empty():
		var item: Variant=todo.pop_back()
		if item is Dictionary:
			if item.is_read_only():continue
			for key in item:
				if item[key] is Dictionary or item[key] is Array:todo.append(item[key])
			item.make_read_only();containers+=1
		elif item is Array:
			if item.is_read_only():continue
			for child in item:
				if child is Dictionary or child is Array:todo.append(child)
			item.make_read_only();containers+=1
	return containers
func _detach_mount() -> void:
	# Old worker forks keep their immutable namespace and old stores/handles.
	invalidate_cache_source_scope();_source_scope=null
	directory="";manifest={"availability":{},"resources":{}};layers=[];packed_catalog=null
	prepared_store=Store.new();decoder_store=Store.new();_init();_capture_scope_witness();failure=""
func _payload_integrity_failure(reason: String) -> void:
	failure=reason;invalidate_cache_source_scope()
func _init() -> void:
	prepared_store.maximum_bytes=Residency.prepared_budget(); prepared_store.maximum_entries=2048
	decoder_store.maximum_bytes=1024*1024*1024; decoder_store.maximum_entries=4096
var stats:={"reads":0,"payload_bytes":0}
func mount(path: String) -> bool:
	_detach_mount()
	if not path.is_absolute_path(): failure="Recorded catalog needs an absolute directory"; return false
	var file:=FileAccess.open(path.path_join("manifest.json"),FileAccess.READ)
	if file==null or file.get_length()>64*1024*1024: failure="Recorded catalog manifest is unavailable or exceeds bound"; return false
	var value: Variant=JSON.parse_string(file.get_as_text()); file.close()
	if not value is Dictionary or value.get("version")!=2 or value.get("complete")!=true or not value.get("availability") is Dictionary or not value.get("resources") is Dictionary:
		failure="Recorded catalog is incomplete or unsupported"; return false
	if value.availability.size()>1000000 or value.resources.size()>1000000: failure="Recorded catalog exceeds resource bound"; return false
	var portraits: Variant=value.get("portraitFiles",[])
	if not portraits is Array or portraits.size()>1000000: failure="Recorded portrait file list is invalid"; return false
	for name in portraits:
		if not name is String or name.length()>260 or "/" in name or "\\" in name or ":" in name or name.get_extension().to_lower() not in ["tga","dds"]: failure="Invalid recorded portrait filename"; return false
	for key in value.availability:
		var split:=str(key).rsplit(":",true,1)
		if split.size()!=2 or not str(split[1]).is_valid_int() or int(split[1])<0 or int(split[1])>65535 or str(split[0]).is_empty() or str(split[0]).length()>32 or "/" in key or "\\" in key or str(key).count(":")!=1 or int(value.availability[key]) not in [1,2,3,5]: failure="Invalid recorded resource identity"; return false
	var next_directory:=path.simplify_path();var next_packed
	if value.has("packedSource"):
		var packed: Variant=value.packedSource
		if not packed is Dictionary or packed.get("version")!=1 or packed.get("file")!="resources.erf" or int(packed.get("namespaceEntries",-1))!=value.availability.size(): failure="Invalid benchmark clone source"; return false
		var source_path:=next_directory.path_join("resources.erf"); var source:=FileAccess.open(source_path,FileAccess.READ)
		if source==null or source.get_length()!=int(packed.get("bytes",-1)): failure="Benchmark clone archive length differs"; return false
		source.close(); next_packed=Catalog.new()
		if not next_packed.mount_erf(source_path): failure=next_packed.failure; return false
		next_packed.build_resource_index()
	# Publish the complete validated snapshot once; failed mounts publish nothing.
	directory=next_directory;manifest=value;layers=[{"kind":"recorded","entries":value.availability}];packed_catalog=next_packed
	if packed_catalog!=null:decoder_store=Residency.decoded
	var seal_began:=Time.get_ticks_usec();var sealed:=_seal_graph([manifest,layers])
	stats["scope_seal_us"]=int(stats.get("scope_seal_us",0))+Time.get_ticks_usec()-seal_began
	stats["scope_sealed_containers"]=int(stats.get("scope_sealed_containers",0))+sealed
	_capture_scope_witness();_source_scope=SealedSourceScope.new()
	return true
func fork() -> RefCounted:
	var copy=get_script().new(); copy.directory=directory; copy.manifest=manifest; copy.layers=layers; copy.prepared_store=prepared_store; copy.decoder_store=decoder_store; copy.packed_catalog=packed_catalog.fork() if packed_catalog!=null else null; copy._source_scope=_source_scope; copy._capture_scope_witness(); return copy
func preparation_cache(): return prepared_store
func decoded_cache(): return decoder_store
func has_resource(name: String,type: int) -> bool: return manifest.get("availability",{}).has(name.to_lower()+":"+str(type))
func portrait_files() -> Array: return manifest.get("portraitFiles",[]).duplicate()
func resource_names(type: int) -> Array:
	var suffix:=":"+str(type); var output: Array=[]
	for key in manifest.get("availability",{}):
		if str(key).ends_with(suffix): output.append(str(key).trim_suffix(suffix))
	return output
func raster_location(name: String) -> Dictionary:
	for storage in [2,5,3,1]:
		for type in [2073,2033,2059,3]:
			if int(manifest.availability.get(name.to_lower()+":"+str(type),-1))==storage: return {"name":name.to_lower(),"type":type}
	return {}
func recorded_texture_miss(name: String) -> bool: return raster_location(name).is_empty() and not has_resource(name,6)
func talk_path(key: String) -> String:
	var row: Dictionary=manifest.get("talk",{}).get(key,{})
	if row.is_empty(): return ""
	var digest:=str(row.get("sha256",""))
	if digest.length()!=64 or not digest.is_valid_hex_number(false): return ""
	var path:=directory.path_join("objects").path_join(digest)
	if FileAccess.get_sha256(path)==digest:return path
	invalidate_cache_source_scope();return ""
func get_resource(name: String,type: int) -> PackedByteArray:
	failure=""; var key:=name.to_lower()+":"+str(type); var row: Dictionary=manifest.get("resources",{}).get(key,{})
	if row.is_empty(): failure="Unrecorded native resource: "+key; return PackedByteArray()
	if row.has("error"): failure=str(row.error); return PackedByteArray()
	var digest:=str(row.get("sha256","")); var count:=int(row.get("bytes",-1))
	if digest.length()!=64 or digest!=digest.to_lower() or not digest.is_valid_hex_number(false) or count<0 or count>256*1024*1024: _payload_integrity_failure("Invalid recorded payload identity"); return PackedByteArray()
	var bytes: PackedByteArray
	if packed_catalog!=null:
		bytes=packed_catalog.get_resource(name,type)
		if not packed_catalog.failure.is_empty() or bytes.size()!=count: _payload_integrity_failure("Benchmark clone payload is unavailable or changed: "+key); return PackedByteArray()
	else:
		var file:=FileAccess.open(directory.path_join("objects").path_join(digest),FileAccess.READ)
		if file==null or file.get_length()!=count: _payload_integrity_failure("Recorded payload is unavailable or changed: "+key); return PackedByteArray()
		bytes=file.get_buffer(count); file.close()
	if preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=digest: _payload_integrity_failure("Recorded payload checksum differs: "+key); return PackedByteArray()
	stats.reads+=1; stats.payload_bytes+=bytes.size(); return bytes
func close_sources() -> void: pass
