extends RefCounted
# Experimental data-only sidecars for prework raster values. Disabled by
# default. Existing parent packets, source facts and decoder observations stay
# intact; only the repeated image value moves to content-addressed storage.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const FORMAT:="prework-raster-values-v1"
const DIRECTORY:="raster-children-v1"
const MAX_REFERENCES:=4096
static var gate:=Mutex.new()
static var writers: Dictionary={}
static var counters:={"reads":0,"writes":0,"memory_hits":0,"missing":0,"invalid":0,"repairs":0,"directories":0}
var parent_directory:=""
var cache:=Cache.new()
var ready:=false
var failure:=""
static func enabled() -> bool: return OS.get_cmdline_user_args().has("--prework-raster-children=enabled")
static func count(field: String) -> void:
	gate.lock(); counters[field]=int(counters[field])+1; gate.unlock()
static func snapshot() -> Dictionary:
	gate.lock(); var result:=counters.duplicate(); result.active_writers=writers.size(); gate.unlock(); return result
func configure(parent: String) -> void:
	parent_directory=parent; ready=false; cache.directory=""; failure="" # No child filesystem access.
func ensure_cache() -> bool:
	if not enabled(): failure="Raster child mode disabled"; return false
	if ready: return true
	if parent_directory.is_empty(): failure="Raster child parent directory unavailable"; return false
	count("directories")
	ready=cache.configure(parent_directory.path_join(DIRECTORY)); failure=cache.failure
	return ready
static func valid_sha(value: Variant) -> bool:
	return value is String and value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)
static func data_only(value: Variant,depth: int=0) -> bool:
	if depth>64 or value is Object or value is Callable or value is Signal or value is RID: return false
	if value is Dictionary:
		for key in value:
			if not data_only(key,depth+1) or not data_only(value[key],depth+1): return false
	elif value is Array:
		for child in value:
			if not data_only(child,depth+1): return false
	return true
static func has_bytes(value: Variant) -> bool:
	if value is PackedByteArray: return not value.is_empty()
	if value is Dictionary:
		for child in value.values():
			if has_bytes(child): return true
	elif value is Array:
		for child in value:
			if has_bytes(child): return true
	return false
static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary=value.duplicate(); result.clear(); var keys: Array=value.keys()
		keys.sort_custom(func(a,b): return var_to_bytes(a).hex_encode()<var_to_bytes(b).hex_encode())
		for key in keys: result[key]=canonical(value[key])
		return result
	if value is Array:
		var result: Array=value.duplicate()
		for index in result.size(): result[index]=canonical(value[index])
		return result
	return value
static func encoded(value: Dictionary) -> PackedByteArray: return var_to_bytes(canonical(value))
static func child_key(sha: String) -> String: return Cache.key(sha,FORMAT)
func write_child(sha: String,size: int,value: Dictionary) -> bool:
	if not valid_sha(sha) or size<=0 or size>Cache.MAX_BYTES: failure="Invalid raster child publication identity"; return false
	var identity:=parent_directory+":"+sha
	gate.lock()
	if not writers.has(identity): writers[identity]={"mutex":Mutex.new(),"users":0}
	var lease: Dictionary=writers[identity]; lease.users+=1; gate.unlock()
	lease.mutex.lock(); var success:=write_child_locked(sha,size,value); lease.mutex.unlock()
	gate.lock(); lease.users-=1
	if int(lease.users)==0: writers.erase(identity)
	gate.unlock(); return success
func write_child_locked(sha: String,size: int,value: Dictionary) -> bool:
	if not ensure_cache(): return false
	var key:=child_key(sha); var previous:=read_child(sha,size)
	if not previous.is_empty(): return true
	var path:=cache.filename(key)
	if FileAccess.file_exists(path):
		# Only this exact generated digest path is eligible. Removing a corrupt
		# sidecar makes readers fall back; publication remains atomic afterward.
		if DirAccess.remove_absolute(path)!=OK: failure="Raster child repair is busy"; return false
		count("repairs")
	if not cache.save_data(key,sha,FORMAT,value): failure=cache.failure; return false
	count("writes"); return true
func read_child(sha: String,size: int) -> Dictionary:
	if not ensure_cache(): return {}
	count("reads"); var value:=cache.load_data(child_key(sha),sha,FORMAT)
	if value.is_empty(): count("missing"); return {}
	if not data_only(value): count("invalid"); return {}
	var bytes:=encoded(value)
	if bytes.size()!=size or Cache.digest(bytes)!=sha: count("invalid"); return {}
	return value
func pack(data: Dictionary) -> Dictionary:
	if not enabled(): return {"success":true,"data":data}
	var result:=data.duplicate(); var references: Array=[]
	for field in ["textures","emitter_textures"]:
		if not data.get(field) is Dictionary: continue
		var textures: Dictionary=data[field].duplicate()
		for name in textures:
			var original: Variant=textures[name]
			if not original is Dictionary or not original.get("value") is Dictionary or original.value.is_empty() or not data_only(original.value) or not has_bytes(original.value): continue
			var value: Dictionary=canonical(original.value); var bytes:=var_to_bytes(value)
			if bytes.is_empty() or bytes.size()>Cache.MAX_BYTES or references.size()>=MAX_REFERENCES: return {"success":true,"data":data}
			var sha:=Cache.digest(bytes)
			if not write_child(sha,bytes.size(),value): return {"success":false,"error":failure}
			var packet: Dictionary=original.duplicate(); packet.erase("value"); textures[name]=packet
			references.append({"field":field,"name":name,"sha256":sha,"bytes":bytes.size()})
		result[field]=textures
	if references.is_empty(): return {"success":true,"data":data}
	return {"success":true,"data":{"format":FORMAT,"parent":result,"references":references}}
static func reference_valid(row: Variant,parent: Dictionary,seen: Dictionary) -> bool:
	if not row is Dictionary or row.get("field") not in ["textures","emitter_textures"] or not (row.get("name") is String or row.get("name") is StringName) or not valid_sha(row.get("sha256")) or not row.get("bytes") is int or int(row.bytes)<=0 or int(row.bytes)>Cache.MAX_BYTES: return false
	if not parent.get(row.field) is Dictionary or not parent[row.field].get(row.name) is Dictionary or parent[row.field][row.name].has("value"): return false
	var key:=str(row.field)+":"+var_to_bytes(row.name).hex_encode()
	if seen.has(key): return false
	seen[key]=true; return true
func load_value(row: Dictionary,store) -> Dictionary:
	if store==null: return read_child(str(row.sha256),int(row.bytes))
	var request:=FORMAT+":"+str(row.sha256)+":"+str(row.bytes); var epoch:=int(store.generation())
	var lease: Dictionary=store.begin_data(request,epoch,true)
	if not bool(lease.owner):
		var packet: Dictionary=lease.value
		if packet.get("sha256")==row.sha256 and packet.get("bytes")==row.bytes and packet.get("data") is Dictionary:
			count("memory_hits"); return packet.data
		return {}
	var value:=read_child(str(row.sha256),int(row.bytes)); var packet: Dictionary={}
	if not value.is_empty():
		packet={"sha256":row.sha256,"bytes":row.bytes,"data":value}
		store.save_data(request,request,packet,epoch)
	store.finish_data(request,epoch,packet); return value
func unpack(data: Dictionary,reader) -> Dictionary:
	if data.get("format")!=FORMAT: return {"success":true,"data":data}
	if not enabled(): return {"success":false,"error":"Raster child mode unavailable"}
	if not data.get("parent") is Dictionary or not data.get("references") is Array or data.references.is_empty() or data.references.size()>MAX_REFERENCES: return {"success":false,"error":"Invalid raster child parent"}
	var seen: Dictionary={}
	for row in data.references:
		if not reference_valid(row,data.parent,seen): return {"success":false,"error":"Invalid raster child reference"}
	var result: Dictionary=data.parent.duplicate(); var maps: Dictionary={}
	for field in ["textures","emitter_textures"]:
		if result.get(field) is Dictionary: maps[field]=result[field].duplicate(); result[field]=maps[field]
	var store=reader.decoded_cache() if reader!=null and reader.has_method("decoded_cache") else null
	if store!=null and not (store.has_method("begin_data") and store.has_method("save_data") and store.has_method("finish_data") and store.has_method("generation")): store=null
	for row in data.references:
		var value:=load_value(row,store)
		if value.is_empty(): return {"success":false,"error":"Raster child unavailable"}
		var packet: Dictionary=maps[row.field][row.name].duplicate(); packet.value=value; maps[row.field][row.name]=packet
	return {"success":true,"data":result}
func validate(data: Dictionary) -> bool:
	if data.get("format")!=FORMAT: return true
	return bool(unpack(data,null).success)
func clear_explicit() -> Dictionary:
	# Explicit user maintenance may clean orphan sidecars even when normal
	# child-store loading/saving is disabled. No recursive deletion.
	if parent_directory.is_empty() or not parent_directory.is_absolute_path(): return {"removed":0,"bytes":0,"errors":["Raster child parent directory unavailable"]}
	var path:=parent_directory.path_join(DIRECTORY); var removed:=0; var bytes:=0; var errors: Array=[]
	if not DirAccess.dir_exists_absolute(path): return {"removed":0,"bytes":0,"errors":[]}
	for name in DirAccess.get_files_at(path):
		if not name.ends_with(".bin") or not valid_sha(name.get_basename()): continue
		var file_path:=path.path_join(name); var file:=FileAccess.open(file_path,FileAccess.READ); var size:=file.get_length() if file!=null else 0
		if file!=null: file.close()
		if DirAccess.remove_absolute(file_path)==OK: removed+=1; bytes+=size
		else: errors.append(name)
	return {"removed":removed,"bytes":bytes,"errors":errors}
