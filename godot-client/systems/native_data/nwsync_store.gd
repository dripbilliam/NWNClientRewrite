extends RefCounted
# Read synced raw assets directly in Godot. Network downloading may remain in
# the protocol service; selection, decompression, verification and preparation
# have no JavaScript or scene-export dependency.
const Reader=preload("res://systems/native_data/nwsync_reader.gd")
const SourceCache=preload("res://systems/native_data/source_bytes_cache.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const LIMIT:=256*1024*1024
const MANIFEST_LIMIT:=64*1024*1024
var directory:=""
var reader
var source_cache
var readers: Array=[]
var available: Array=[]
var reader_mutex:=Mutex.new()
var reader_slots:=Semaphore.new()
var maximum_readers:=4
var native_directory:=""
var helper_executable:=""
var closed:=false
func configure(cache_directory: String, native_directory: String="", helper: String="", raw_cache_directory: String="") -> bool:
	if not cache_directory.is_absolute_path(): return false
	directory=cache_directory.simplify_path()
	if not raw_cache_directory.is_empty():
		var candidate:=SourceCache.new()
		if candidate.configure(raw_cache_directory): source_cache=candidate
	if not native_directory.is_empty():
		self.native_directory=native_directory; helper_executable=helper
		reader=Reader.new()
		if not reader.open(helper,native_directory): reader.close(); reader=null; return false
		readers.append(reader); available.append(reader)
		for index in maximum_readers: reader_slots.post()
	return true
func read_native(operation: int,payload: PackedByteArray) -> Dictionary:
	var began:=Time.get_ticks_usec(); reader_slots.wait()
	var acquired:=Time.get_ticks_usec(); reader_mutex.lock()
	if closed: reader_mutex.unlock(); reader_slots.post(); return {"error":"Native NWSync pool is closed"}
	var owned=available.pop_back() if not available.is_empty() else null
	reader_mutex.unlock()
	if owned==null:
		owned=Reader.new()
		if not owned.open(helper_executable,native_directory):
			owned.close(); reader_slots.post(); return {"error":"Native NWSync parallel reader could not start"}
		reader_mutex.lock(); readers.append(owned); reader_mutex.unlock()
	var response: Dictionary=owned.request(operation,payload)
	response.timings.wait_us+=acquired-began
	reader_mutex.lock(); available.append(owned); reader_mutex.unlock(); reader_slots.post()
	return response
static func valid_hash(value: String) -> bool: return value.length()==40 and value==value.to_lower() and value.is_valid_hex_number(false)
static func sha1(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA1)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
static func resource_reference(bytes: PackedByteArray, at: int) -> Dictionary:
	var name:=Binary.new(bytes).text(at,16,true).to_lower(); var type:=int(bytes.decode_u16(at+16))
	if name.is_empty() or "/" in name or "\\" in name or ":" in name: return {}
	for character in name:
		if character.unicode_at(0)<32: return {}
	return {"name":name,"type":type}
static func decode_manifest(bytes: PackedByteArray, expected: String) -> Dictionary:
	if not valid_hash(expected) or bytes.size()<16 or bytes.size()>MANIFEST_LIMIT or bytes.slice(0,4).get_string_from_ascii()!="NSYM" or bytes.decode_u32(4)!=3 or sha1(bytes)!=expected: return {"error":"Invalid native NWSync manifest header or digest"}
	return Residency.index("nwsync-manifest",[expected],[bytes],func():
		var value:=decode_verified_manifest(bytes)
		return {"value":value,"error":str(value.get("error",""))}).value
static func decode_verified_manifest(bytes: PackedByteArray) -> Dictionary:
	var count:=int(bytes.decode_u32(8)); var mappings:=int(bytes.decode_u32(12))
	if count<1 or count+mappings>1000000 or 16+count*42+mappings*22!=bytes.size(): return {"error":"Invalid native NWSync manifest length"}
	var entries: Dictionary={}; var base: Array=[]; var sizes: Dictionary={}
	for index in count+mappings:
		var offset:=16+index*42 if index<count else 16+count*42+(index-count)*22
		var row: Dictionary
		if index<count:
			var hash:=bytes.slice(offset,offset+20).hex_encode(); var size:=int(bytes.decode_u32(offset+20))
			if size>LIMIT or sizes.has(hash) and sizes[hash]!=size: return {"error":"Invalid native NWSync resource size"}
			sizes[hash]=size; row=resource_reference(bytes,offset+24); row.hash=hash; row.size=size
		else:
			var source:=int(bytes.decode_u32(offset))
			if source>=count: return {"error":"Invalid native NWSync alias"}
			row=resource_reference(bytes,offset+4); row.hash=base[source].hash; row.size=base[source].size
		if not row.has("name"): return {"error":"Invalid native NWSync resource reference"}
		var key:=str(row.name)+":"+str(row.type)
		if entries.has(key): return {"error":"Duplicate native NWSync reference"}
		entries[key]=row
		if index<count: base.append(row)
	return {"entries":entries}
func manifest(hash: String) -> Dictionary:
	if not valid_hash(hash): return {"error":"Invalid native NWSync manifest identity"}
	var path:=directory.path_join("manifests").path_join(hash)
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>MANIFEST_LIMIT: return {"error":"Native NWSync manifest exceeds bound"}
		return decode_manifest(file.get_buffer(file.get_length()),hash)
	if reader==null: return {"error":"Native NWSync manifest is not cached"}
	var response: Dictionary=reader.request(1,hash.to_ascii_buffer())
	if response.has("error"): return response
	if response.get("missing",false): return {"error":"Installed NWSync manifest is absent"}
	var bytes: PackedByteArray=response.bytes
	return Residency.index("nwsync-installed-manifest",[hash],[bytes],func():
		var value:=decode_installed_manifest(bytes)
		return {"value":value,"error":str(value.get("error",""))}).value
static func decode_installed_manifest(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<4: return {"error":"Invalid installed NWSync catalog"}
	var count:=int(bytes.decode_u32(0)); var entries: Dictionary={}
	if count<1 or count>1000000 or bytes.size()!=4+count*58: return {"error":"Invalid installed NWSync catalog length"}
	for index in count:
		var offset:=4+index*58; var row:=resource_reference(bytes,offset); var identity:=bytes.slice(offset+18,offset+58).get_string_from_ascii()
		if row.is_empty() or not valid_hash(identity): return {"error":"Invalid installed NWSync reference"}
		row.hash=identity; row.size=-1
		var key:=str(row.name)+":"+str(row.type)
		if entries.has(key): return {"error":"Duplicate installed NWSync reference"}
		entries[key]=row
	return {"entries":entries}
static func decode_blob(encoded: PackedByteArray, expected: String, size: int=-1, allow_raw: bool=false) -> Dictionary:
	if not valid_hash(expected) or size < -1 or size>LIMIT or encoded.size()>LIMIT: return {"error":"Invalid native NWSync blob bound"}
	var decoded:=PackedByteArray()
	if encoded.size()>=16 and encoded.slice(0,4).get_string_from_ascii()=="NSYC":
		if encoded.decode_u32(4)!=3: return {"error":"Unsupported native NWSync blob version"}
		var algorithm:=int(encoded.decode_u32(8)); var count:=int(encoded.decode_u32(12))
		if count>LIMIT or size!=-1 and size!=count: return {"error":"Native NWSync size differs"}
		if algorithm==0: decoded=encoded.slice(16)
		elif algorithm==1:
			if encoded.size()<20 or encoded.decode_u32(16)!=1: return {"error":"Invalid native NWSync zlib header"}
			decoded=encoded.slice(20).decompress(count,FileAccess.COMPRESSION_DEFLATE)
		elif algorithm==2:
			if encoded.size()<24 or encoded.decode_u32(16)!=1 or encoded.decode_u32(20)!=0: return {"error":"Invalid native NWSync Zstandard header"}
			decoded=encoded.slice(24).decompress(count,FileAccess.COMPRESSION_ZSTD)
		else: return {"error":"Unsupported native NWSync compression"}
		if decoded.size()!=count: return {"error":"Native NWSync decoded size differs"}
	elif allow_raw: decoded=encoded
	else: return {"error":"Invalid native NWSync blob header"}
	if size!=-1 and decoded.size()!=size or sha1(decoded)!=expected: return {"error":"Native NWSync resource digest or size differs"}
	return {"bytes":decoded}
func resource(entry: Dictionary) -> Dictionary:
	var hash:=str(entry.get("hash","")); var size:=int(entry.get("size",-1))
	if not valid_hash(hash) or size < -1 or size>LIMIT: return {"error":"Invalid native NWSync resource identity or size"}
	var store=Residency.synced_bytes; var generation: int=store.generation()
	var lease: Dictionary=store.begin_data(hash,generation,false)
	if not lease.owner:
		var saved: Dictionary=lease.value.duplicate()
		if not saved.has("error"):
			if size!=-1 and saved.bytes.size()!=size: return {"error":"Native NWSync resource digest or size differs"}
			# Packed arrays are mutable references in GDScript. A caller owns its
			# returned byte buffer; it must not edit the process-resident source.
			saved.bytes=saved.bytes.duplicate()
			saved.timings={"memory_source_hit":true,"wait_us":int(lease.wait_us)}
		return saved
	var result:=read_resource(entry)
	var frozen: Dictionary=result if result.has("error") else {"bytes":result.bytes.duplicate()}
	if not result.has("error"): store.save_data(hash,hash,frozen,generation,result.bytes.size()+128,true)
	store.finish_data(hash,generation,frozen)
	return result
func read_resource(entry: Dictionary) -> Dictionary:
	var hash:=str(entry.get("hash","")); var size:=int(entry.get("size",-1))
	if not valid_hash(hash): return {"error":"Invalid native NWSync resource identity"}
	var cache_read_us:=0
	if source_cache!=null:
		var began:=Time.get_ticks_usec(); var saved: Dictionary=source_cache.read(hash,size)
		cache_read_us=Time.get_ticks_usec()-began
		if not saved.is_empty(): saved.timings={"raw_cache_hit":true,"raw_cache_us":Time.get_ticks_usec()-began}; return saved
	var path:=directory.path_join("objects").path_join(hash)
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>LIMIT: return {"error":"Native NWSync cached blob exceeds bound"}
		var encoded:=file.get_buffer(file.get_length()); file.close()
		var began:=Time.get_ticks_usec(); var decoded:=decode_blob(encoded,hash,size)
		decoded.timings={"decode_us":Time.get_ticks_usec()-began}
		if not decoded.has("error") and source_cache!=null:
			queue_cache(hash,decoded.bytes,decoded.timings,cache_read_us)
		return decoded
	if reader==null: return {"error":"Native NWSync resource is not cached"}
	var response: Dictionary=read_native(2,hash.to_ascii_buffer())
	if response.has("error"): return response
	if response.get("missing",false): return {"error":"Installed NWSync resource is absent"}
	var began:=Time.get_ticks_usec(); var decoded:=decode_blob(response.bytes,hash,size,true)
	decoded.timings=response.get("timings",{}); decoded.timings.decode_us=Time.get_ticks_usec()-began
	if not decoded.has("error") and source_cache!=null:
		queue_cache(hash,decoded.bytes,decoded.timings,cache_read_us)
	return decoded
func queue_cache(hash: String,bytes: PackedByteArray,timing: Dictionary,read_us: int) -> void:
	var began:=Time.get_ticks_usec()
	var accepted: bool=Writes.enqueue_raw(source_cache.directory,hash,bytes,int(source_cache.maximum_disk_bytes),int(source_cache.maximum_entry_bytes))
	timing.cache_read_us=read_us; timing.cache_save_us=Time.get_ticks_usec()-began; timing.cache_save_queued=accepted; timing.cache_save_skipped=not accepted; timing.cache_prune_us=0
func close() -> void:
	reader_mutex.lock(); closed=true; var owned:=readers.duplicate(); readers.clear(); available.clear(); reader_mutex.unlock()
	for child in owned: child.close()
	reader=null
