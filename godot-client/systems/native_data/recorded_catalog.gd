extends RefCounted
# Closed-world native loading replay. Resource presence/class comes from the
# original mounted catalog; missing recorded payloads are explicit capture gaps.
const Store=preload("res://systems/native_data/preparation_store.gd")
var directory:=""
var manifest: Dictionary={}
var failure:=""
var layers: Array=[]
var prepared_store:=Store.new()
var decoder_store:=Store.new()
func _init() -> void:
	prepared_store.maximum_bytes=512*1024*1024; prepared_store.maximum_entries=2048
	decoder_store.maximum_bytes=1024*1024*1024; decoder_store.maximum_entries=4096
var stats:={"reads":0,"payload_bytes":0}
func mount(path: String) -> bool:
	if not path.is_absolute_path(): failure="Recorded catalog needs an absolute directory"; return false
	var file:=FileAccess.open(path.path_join("manifest.json"),FileAccess.READ)
	if file==null or file.get_length()>64*1024*1024: failure="Recorded catalog manifest is unavailable or exceeds bound"; return false
	var value: Variant=JSON.parse_string(file.get_as_text()); file.close()
	if not value is Dictionary or value.get("version")!=2 or value.get("complete")!=true or not value.get("availability") is Dictionary or not value.get("resources") is Dictionary:
		failure="Recorded catalog is incomplete or unsupported"; return false
	if value.availability.size()>1000000 or value.resources.size()>1000000: failure="Recorded catalog exceeds resource bound"; return false
	for key in value.availability:
		var split:=str(key).rsplit(":",true,1)
		if split.size()!=2 or not str(split[1]).is_valid_int() or int(split[1])<0 or int(split[1])>65535 or str(split[0]).is_empty() or str(split[0]).length()>32 or "/" in key or "\\" in key or str(key).count(":")!=1 or int(value.availability[key]) not in [1,2,3,5]: failure="Invalid recorded resource identity"; return false
	directory=path.simplify_path(); manifest=value; layers=[{"kind":"recorded","entries":manifest.availability}]; return true
func fork() -> RefCounted:
	var copy=get_script().new(); copy.directory=directory; copy.manifest=manifest; copy.layers=layers; copy.prepared_store=prepared_store; copy.decoder_store=decoder_store; return copy
func preparation_cache(): return prepared_store
func decoded_cache(): return decoder_store
func has_resource(name: String,type: int) -> bool: return manifest.get("availability",{}).has(name.to_lower()+":"+str(type))
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
	return path if FileAccess.get_sha256(path)==digest else ""
func get_resource(name: String,type: int) -> PackedByteArray:
	failure=""; var key:=name.to_lower()+":"+str(type); var row: Dictionary=manifest.get("resources",{}).get(key,{})
	if row.is_empty(): failure="Unrecorded native resource: "+key; return PackedByteArray()
	if row.has("error"): failure=str(row.error); return PackedByteArray()
	var digest:=str(row.get("sha256","")); var count:=int(row.get("bytes",-1))
	if digest.length()!=64 or digest!=digest.to_lower() or not digest.is_valid_hex_number(false) or count<0 or count>256*1024*1024: failure="Invalid recorded payload identity"; return PackedByteArray()
	var file:=FileAccess.open(directory.path_join("objects").path_join(digest),FileAccess.READ)
	if file==null or file.get_length()!=count: failure="Recorded payload is unavailable or changed: "+key; return PackedByteArray()
	var bytes:=file.get_buffer(count); file.close()
	if preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=digest: failure="Recorded payload checksum differs: "+key; return PackedByteArray()
	stats.reads+=1; stats.payload_bytes+=bytes.size(); return bytes
func close_sources() -> void: pass
