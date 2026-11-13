extends RefCounted
# Explicitly generated, data-only artifacts. Never contains game downloads or
# live nodes. Dependency bytes, lookup decisions and engine/schema identify reuse.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const REVISION:="session-prework-v2"
const MODEL_METADATA_REVISION:="native-part-bounds-1-tilefade-1"
# Preserve v1's identity across changes to cache locking/scheduling. This is
# the original v1 store fingerprint, not a model processor. Format changes
# bump REVISION; actual decoder/render source hashes remain tracked below.
const V1_STORE_FINGERPRINT:="ea47423de230209744d24cb3cb8c4283230b6e4e661d3d3ba4c09b580a35f192"
const V1_SOURCE_DISCOVERY_FINGERPRINT:="33ecd4f83867df4f8f1a7490308b5d5495018b61a9866130f71935b055a25174"
# Residency/lookup policy changes do not change calculated model output. Keep
# the prior fingerprint for these pure source providers; prework reuse still
# revalidates actual dependency bytes and lookup/absence facts. Changes to a
# decoded representation or calculated output require updating its schema.
const RESIDENCY_SOURCE_FINGERPRINTS={
	"preparation_store.gd":"d0febfea936400d90031507cc179122259c23a52035ef84b3b7efbd1d047e681",
	"recorded_catalog.gd":"fe5eee5ea072edd2ef18dbd03d7e0410b9a6ef89c54eeb6246c7bfa7bb08df50",
	"archive_index.gd":"c267f1419568682c945177ae95368083093bf4a05cbcfde2bf107a6c12319af2",
	"loose_index.gd":"bee820a82e58ccb0dd48ad68542b02f9920cb44b3e6f18f2d51311173227e698",
	"nwsync_store.gd":"6bdae43bb428cca29938c244e09b074abd391ceeca5964847b22575473a034ea",
	"resource_catalog.gd":"12ffee832552c339364eb4be6374b308ba44d10f4b88db0bee70c9c63bd73011",
	"session_catalog.gd":"e714ff29d6eaaaf7a506df7188f468f440e70fdec4a10f6bd0cf9866ed073784",
	"source_bytes_cache.gd":"909fbca9aaab684d29a93037e9a8a8a8b455f95461e7e6707ff3b12f4cae2e53",
	"prepared_write_queue.gd":"d4c04d1799890890a7e0db7b132f7f8954cfdd6eee82a703f0e217bf042347db"
}
static var gate:=Mutex.new()
static var processor_gate:=Mutex.new()
static var clear_gate:=Mutex.new()
static var entry_locks: Dictionary={}
static var directory_writes: Dictionary={}
static var clearing_directories: Dictionary={}
static var clear_waiters: Dictionary={}
static var generations: Dictionary={}
static var observed: Dictionary={}
static var processor_fingerprint:=""
static var diagnostics_enabled:=false
static var save_timings: Dictionary={}
static func take_save_timing() -> Dictionary:
	gate.lock(); var id:=OS.get_thread_caller_id(); var timing: Dictionary=save_timings.get(id,{}); save_timings.erase(id); gate.unlock(); return timing
static func processor_identity() -> String:
	processor_gate.lock()
	if processor_fingerprint.is_empty():
		var sources: Array=[REVISION]
		# Development changes invalidate generated data automatically. Exported
		# builds retain the explicit schema revision and engine-version identity.
		for directory in ["res://systems/native_data","res://systems/native_render"]:
			for filename in DirAccess.get_files_at(directory):
				if not filename.ends_with(".gd"): continue
				if directory=="res://systems/native_data" and filename in ["resource_residency.gd","resource_index_backend.gd"]: continue
				var digest:=FileAccess.get_sha256(directory.path_join(filename))
				if directory=="res://systems/native_data":
					if filename=="prework_store.gd": digest=V1_STORE_FINGERPRINT
					elif filename=="prework_sources.gd": digest=V1_SOURCE_DISCOVERY_FINGERPRINT
					elif RESIDENCY_SOURCE_FINGERPRINTS.has(filename): digest=RESIDENCY_SOURCE_FINGERPRINTS[filename]
				sources.append([filename,digest])
		for path in ["res://systems/native_item_icons.gd","res://systems/model_rigs.gd","res://systems/model_native_pose.gd","res://systems/model_native_animation.gd","res://.cache/native-kernel/nwn-particle-kernel.dll"]:
			if FileAccess.file_exists(path): sources.append([path,FileAccess.get_sha256(path)])
		processor_fingerprint=Cache.digest(var_to_bytes(sources))
	var result:=processor_fingerprint; processor_gate.unlock(); return result
static func remember_request(catalog,name: String,type: int,decoder: String,options: Dictionary) -> void:
	if decoder not in ["actor-model","static-model","gui-icon-v1"] or not catalog.has_method("preparation_cache"): return
	var owner=catalog.preparation_cache()
	if owner==null: return
	var scope:=int(owner.get_instance_id()); var settings:=options.duplicate(true); settings.erase("icon_descriptor")
	if not observed.has(scope):
		if observed.size()>=8: observed.erase(observed.keys()[0])
		observed[scope]={}
	var identity:=Cache.digest(var_to_bytes([name,type,decoder,settings]))
	if observed[scope].size()<8192: observed[scope][identity]={"name":name,"type":type,"decoder":decoder,"options":settings}
static func known_requests(catalog) -> Array:
	var owner=catalog.preparation_cache() if catalog.has_method("preparation_cache") else null
	return observed.get(int(owner.get_instance_id()),{}).values().duplicate(true) if owner!=null else []
static func forget(catalog) -> void:
	var owner=catalog.preparation_cache() if catalog.has_method("preparation_cache") else null
	if owner!=null: observed.erase(int(owner.get_instance_id()))
var cache:=Cache.new()
var directory:=""
var failure:=""
func configure(prepared_directory: String) -> bool:
	directory=""; cache.directory=""; failure=""
	if prepared_directory.is_empty(): failure="Prepared asset directory is unavailable"; return false
	var path:=ProjectSettings.globalize_path(prepared_directory).simplify_path().path_join("saved-prework-v1")
	if not cache.configure(path): failure=cache.failure; return false
	directory=cache.directory; return true
func generation() -> int:
	gate.lock(); var value:=int(generations.get(directory,0)); gate.unlock(); return value
static func current_generation(prepared_directory: String) -> int:
	var path:=ProjectSettings.globalize_path(prepared_directory).simplify_path().path_join("saved-prework-v1").replace("\\","/").trim_suffix("/")
	gate.lock(); var value:=int(generations.get(path,0)); gate.unlock(); return value
static func request_key(name: String,type: int,decoder: String,options: Dictionary,source_sha: String,policy: Array) -> String:
	var settings:=options.duplicate(); settings.erase("icon_descriptor")
	var identity: Array=[name.to_lower(),type,decoder,settings,source_sha,policy,processor_identity()]
	# Baked models must retain original Part selection/render metadata. Do not
	# change unrelated bitmap/2DA cache identities to invalidate a model payload.
	if decoder in ["actor-model","static-model"]:identity.append(MODEL_METADATA_REVISION)
	return Cache.key(Cache.digest(var_to_bytes(identity)),REVISION)
static func valid_icon(data: Dictionary) -> bool:
	var width:=int(data.get("width",0)); var height:=int(data.get("height",0)); var pixels: Variant=data.get("pixels")
	return width>0 and height>0 and width<=4096 and height<=4096 and pixels is PackedByteArray and pixels.size()==width*height*4 and data.get("bounds") is Dictionary
func load_entry(key: String,reader,with_inputs: bool=false) -> Dictionary:
	if directory.is_empty(): return {}
	var entry:=cache.load_data(key,key,REVISION)
	if not entry.get("inputs") is Array or not entry.get("data") is Dictionary: return {}
	for row in entry.inputs:
		if not row is Dictionary: return {}
		match str(row.get("operation","")):
			"bytes":
				var bytes: PackedByteArray=reader.get_resource(str(row.name),int(row.type))
				if not reader.failure.is_empty() or Cache.digest(bytes)!=str(row.sha256): return {}
			"exists":
				if reader.has_resource(str(row.name),int(row.type))!=bool(row.present): return {}
			"raster":
				if reader.raster_location(str(row.name))!=row.selected: return {}
			"missing":
				var missing: bool=reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(str(row.name))
				if missing!=bool(row.missing): return {}
			_: return {}
	return entry if with_inputs else entry.data
func save_entry(key: String,inputs: Array,data: Dictionary,ticket: int) -> bool:
	if directory.is_empty(): return false
	var began:=Time.get_ticks_usec()
	# Metadata is shared briefly. Independent files serialize/checksum/write in
	# parallel; only writers for the same destination share an entry gate.
	gate.lock()
	if ticket!=int(generations.get(directory,0)) or clearing_directories.has(directory): gate.unlock(); return false
	var identity:=directory+":"+key
	if not entry_locks.has(identity): entry_locks[identity]={"gate":Mutex.new(),"users":0}
	var lease: Dictionary=entry_locks[identity]; lease.users+=1
	directory_writes[directory]=int(directory_writes.get(directory,0))+1; gate.unlock()
	lease.gate.lock(); var entered:=Time.get_ticks_usec()
	gate.lock(); var valid:=ticket==int(generations.get(directory,0)) and not clearing_directories.has(directory); gate.unlock()
	var ok:=save_entry_locked(key,inputs,data) if valid else false
	lease.gate.unlock()
	gate.lock(); lease.users-=1; directory_writes[directory]-=1
	if int(lease.users)==0: entry_locks.erase(identity)
	if int(directory_writes[directory])==0:
		directory_writes.erase(directory)
		if clear_waiters.has(directory): clear_waiters[directory].post()
	if diagnostics_enabled:
		if save_timings.size()>=64 and not save_timings.has(OS.get_thread_caller_id()): save_timings.erase(save_timings.keys()[0])
		save_timings[OS.get_thread_caller_id()]={"entry_wait_ms":(entered-began)/1000.0,"total_ms":(Time.get_ticks_usec()-began)/1000.0,"cache":cache.last_save.duplicate()}
	gate.unlock(); return ok
func save_entry_locked(key: String,inputs: Array,data: Dictionary) -> bool:
	var old:=cache.load_data(key,key,REVISION)
	if not old.is_empty() and old.get("inputs")==inputs: return true
	var path:=cache.filename(key)
	if path.is_empty(): failure="Invalid saved prework identity"; return false
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:
		failure="Saved prework entry is busy; try preparation again"; return false
	var ok:=cache.save_data(key,key,REVISION,{"inputs":inputs,"data":data})
	failure=cache.failure; return ok
static func publication_snapshot() -> Dictionary:
	gate.lock(); var result:={"entries":entry_locks.size(),"active":directory_writes.duplicate(),"clearing":clearing_directories.keys()}; gate.unlock(); return result
func clear() -> Dictionary:
	if directory.is_empty(): return {"error":"Saved prework directory is unavailable"}
	clear_gate.lock()
	gate.lock(); generations[directory]=int(generations.get(directory,0))+1; clearing_directories[directory]=true
	var wake:=Semaphore.new(); var waiting:=int(directory_writes.get(directory,0))>0
	if waiting: clear_waiters[directory]=wake
	gate.unlock()
	if waiting: wake.wait()
	var removed:=0; var bytes:=0; var errors: Array=[]
	# Only this dedicated generated directory and exact content filenames are
	# eligible. No recursive deletion and no traversal of original/download caches.
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".bin") or filename.get_basename().length()!=64 or not filename.get_basename().is_valid_hex_number(false): continue
		var path:=directory.path_join(filename); var file:=FileAccess.open(path,FileAccess.READ)
		var size:=file.get_length() if file!=null else 0
		if file!=null: file.close()
		if DirAccess.remove_absolute(path)==OK: removed+=1; bytes+=size
		else: errors.append(filename)
	gate.lock(); clear_waiters.erase(directory); clearing_directories.erase(directory); gate.unlock()
	clear_gate.unlock(); return {"removed":removed,"bytes":bytes,"errors":errors}
class Inputs:
	extends RefCounted
	const Digest=preload("res://systems/native_data/prepared_cache.gd")
	var source
	var rows: Dictionary={}
	var failure:=""
	var stats: Dictionary:
		get: return source.get("stats") if source.get("stats") is Dictionary else {}
	func _init(reader) -> void: source=reader
	func fork(): return source.fork()
	func preparation_cache(): return source.preparation_cache() if source.has_method("preparation_cache") else null
	func decoded_cache(): return source.decoded_cache() if source.has_method("decoded_cache") else preparation_cache()
	func remember(name: String,type: int,bytes: PackedByteArray,known_sha: String="") -> void:
		# Optional only for the trusted digest of these same job-owned immutable
		# bytes. Other callers still hash normally; disk/load validation is separate.
		var sha:=known_sha if known_sha.length()==64 and known_sha==known_sha.to_lower() and known_sha.is_valid_hex_number(false) else Digest.digest(bytes)
		rows["bytes:"+name.to_lower()+":"+str(type)]={"operation":"bytes","name":name.to_lower(),"type":type,"sha256":sha}
	func get_resource(name: String,type: int) -> PackedByteArray:
		var bytes: PackedByteArray=source.get_resource(name,type); failure=source.failure
		if failure.is_empty(): remember(name,type,bytes)
		return bytes
	func get_resource_with_digest(name: String,type: int) -> Dictionary:
		var bytes: PackedByteArray=source.get_resource(name,type);failure=source.failure
		if not failure.is_empty():return {"bytes":bytes,"sha256":""}
		# The immediate decoder owns this pair. A later source read/mutation must
		# not change the bytes behind its already calculated identity. No raw
		# buffer is retained in the dependency registry or a persistent cache.
		bytes=bytes.duplicate()
		var sha:=Digest.digest(bytes);remember(name,type,bytes,sha)
		return {"bytes":bytes,"sha256":sha}
	func has_resource(name: String,type: int) -> bool:
		var present: bool=source.has_resource(name,type)
		rows["exists:"+name.to_lower()+":"+str(type)]={"operation":"exists","name":name.to_lower(),"type":type,"present":present}; return present
	func raster_location(name: String) -> Dictionary:
		var selected: Dictionary=source.raster_location(name)
		rows["raster:"+name.to_lower()]={"operation":"raster","name":name.to_lower(),"selected":selected}; return selected
	func recorded_texture_miss(name: String) -> bool:
		var missing: bool=source.has_method("recorded_texture_miss") and source.recorded_texture_miss(name)
		rows["missing:"+name.to_lower()]={"operation":"missing","name":name.to_lower(),"missing":missing}; return missing
	func snapshot() -> Array:
		var keys: Array=rows.keys(); keys.sort(); var output: Array=[]
		for key in keys: output.append(rows[key])
		return output
