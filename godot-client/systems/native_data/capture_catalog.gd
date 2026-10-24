extends RefCounted
# Read original raw resources directly from sealed private captures. The V8
# event timeline is separate; this mounts no rendered/prepared JS scene data.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const MAX_MANIFEST_BYTES:=64*1024*1024
const MAX_RESOURCE_BYTES:=256*1024*1024
var failure:=""
var layers: Array=[]
var stats: Dictionary={"reads":0,"payload_bytes":0}
var events_sha256:=""
func reject(reason: String) -> bool:
	failure=reason; return false
func digest_valid(value: Variant) -> bool:
	return value is String and value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)
func read_json(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_MANIFEST_BYTES: failure="Capture manifest is unavailable or exceeds bound"; return {}
	var value: Variant=JSON.parse_string(file.get_as_text())
	if not value is Dictionary: failure="Capture manifest is not an object"; return {}
	return value
func mount(directory: String, context: String, supplements: Array=[]) -> bool:
	failure=""; layers=[]; events_sha256=""
	if not directory.is_absolute_path(): return reject("Capture needs an absolute private directory")
	var root_path:=directory.simplify_path(); var manifest:=read_json(root_path.path_join("manifest.json"))
	if manifest.is_empty(): return false
	if manifest.get("version")!=1 or manifest.get("complete")!=true or not digest_valid(manifest.get("eventsSha256")): return reject("Capture is incomplete or unsupported")
	if not manifest.get("contexts") is Dictionary or not manifest.contexts.has(context): return reject("Capture context is absent")
	events_sha256=manifest.eventsSha256
	if FileAccess.get_sha256(root_path.path_join("events.bin"))!=events_sha256: return reject("Capture timeline checksum differs")
	var proposed: Array=[{"root":root_path,"manifest":manifest}]
	for supplement in supplements:
		if not supplement is String or not supplement.is_absolute_path(): return reject("Supplement needs an absolute directory")
		var path: String=supplement.simplify_path(); var source:=read_json(path.path_join("source.json"))
		if source.get("version")!=1 or source.get("parentEventsSha256")!=events_sha256: return reject("Supplement belongs to another capture")
		var extra:=read_json(path.path_join("manifest.json"))
		if extra.get("version")!=1 or extra.get("complete")!=true or not digest_valid(extra.get("eventsSha256")): return reject("Supplement is incomplete")
		if FileAccess.get_sha256(path.path_join("events.bin"))!=extra.eventsSha256: return reject("Supplement timeline checksum differs")
		if not extra.get("contexts") is Dictionary: return reject("Supplement contexts are invalid")
		proposed.append({"root":path,"manifest":extra})
	var mounted: Array=[]
	for layer in proposed:
		if not layer.manifest.contexts.has(context): continue
		var data: Variant=layer.manifest.contexts[context]
		if not data is Dictionary or not data.get("resources") is Dictionary or not data.get("textures") is Dictionary: return reject("Capture resource index is invalid")
		if data.resources.size()>1000000 or data.textures.size()>1000000: return reject("Capture index exceeds bound")
		for key in data.resources:
			var row: Variant=data.resources[key]
			if not key is String or not row is Dictionary: return reject("Invalid captured resource record")
			var split: int=key.rfind(":")
			if split<1 or split>32 or not key.substr(split+1).is_valid_int(): return reject("Invalid captured resource key")
			var type: int=key.substr(split+1).to_int()
			if type<0 or type>65535 or "/" in key or "\\" in key or key.count(":")!=1: return reject("Unsafe captured resource key")
			if row.get("missing",false): continue
			var size: Variant=row.get("bytes")
			if not digest_valid(row.get("sha256")) or not (size is int or size is float) or not is_finite(float(size)) or float(size)!=floor(float(size)) or size<0 or size>MAX_RESOURCE_BYTES: return reject("Invalid captured content identity/size")
		mounted.append({"root":layer.root,"resources":data.resources,"textures":data.textures})
	layers=mounted; return true
func fork() -> RefCounted:
	var copy=get_script().new(); copy.layers=layers.duplicate(); copy.events_sha256=events_sha256; return copy
func location(name: String, type: int) -> Dictionary:
	var key:=name.to_lower()+":"+str(type)
	for layer in layers:
		if layer.resources.has(key): return {"root":layer.root,"record":layer.resources[key]}
	return {}
func has_resource(name: String, type: int) -> bool:
	var selected:=location(name,type)
	return not selected.is_empty() and not selected.record.get("missing",false)
func resource_names(type: int) -> Array:
	var output: Array=[]; var seen: Dictionary={}; var suffix:=":"+str(type)
	for layer in layers:
		for key in layer.resources:
			if not str(key).ends_with(suffix) or seen.has(key): continue
			seen[key]=true
			if not layer.resources[key].get("missing",false): output.append(str(key).trim_suffix(suffix))
	return output
func raster_location(name: String) -> Dictionary:
	var key:=name.to_lower()
	for layer in layers:
		if not layer.textures.has(key): continue
		var type: Variant=layer.textures[key]
		if type==null or not (type is int or type is float) or not is_finite(float(type)) or float(type)!=floor(float(type)): return {}
		var selected:=int(type)
		if selected not in [2073,2033,2059,3,6]: return {}
		return {"name":key,"type":selected}
	return {}
func recorded_texture_miss(name: String) -> bool:
	var key:=name.to_lower()
	for layer in layers:
		if layer.textures.has(key): return layer.textures[key]==null
	return false
func get_resource(name: String, type: int) -> PackedByteArray:
	failure=""
	var selected:=location(name,type)
	if selected.is_empty(): failure="Resource was not recorded: "+name+":"+str(type); return PackedByteArray()
	var record: Dictionary=selected.record
	if record.get("missing",false): failure="Recorded resource lookup failed: "+name+":"+str(type); return PackedByteArray()
	var path: String=selected.root.path_join("objects").path_join(record.sha256)
	var parent:=DirAccess.open(path.get_base_dir())
	if parent==null or parent.is_link(path.get_file()): failure="Capture object is unavailable or linked"; return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=int(record.bytes): failure="Capture object size differs"; return PackedByteArray()
	var bytes:=file.get_buffer(int(record.bytes))
	if bytes.size()!=int(record.bytes) or Cache.digest(bytes)!=record.sha256: failure="Capture object checksum differs"; return PackedByteArray()
	stats.reads+=1; stats.payload_bytes+=bytes.size(); return bytes
