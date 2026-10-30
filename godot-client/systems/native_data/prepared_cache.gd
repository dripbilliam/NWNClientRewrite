extends RefCounted
# Content-addressed native Variant data, never serialized Objects/scripts.
# Runtime asset data is kept outside the source workspace.
const REVISION := "native-assets-3"
const MAX_BYTES := 256 * 1024 * 1024
static var publication_mutex:=Mutex.new()
static var verified_publications: Dictionary={}
static var path_publications: Dictionary={}
var directory := ""
var failure := ""
var last_save: Dictionary={}
var path_publication:=not OS.get_cmdline_user_args().has("--prepared-cache-lock=global")
static func configured_writes_enabled() -> bool: return not OS.get_cmdline_user_args().has("--prepared-cache-write=disabled")
func configure(path: String) -> bool:
	failure = ""
	var resolved := ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().trim_suffix("/")
	var source := ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/")
	if source.get_file() == "godot-client": source = source.get_base_dir()
	if not resolved.is_absolute_path() or resolved == source or resolved.begins_with(source + "/"):
		failure = "Prepared assets must remain outside the source workspace"; return false
	if DirAccess.make_dir_recursive_absolute(resolved) != OK: failure = "Native prepared cache is unavailable"; return false
	directory = resolved; return true
static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
static func key(source_sha: String, decoder: String) -> String:
	return (REVISION + ":" + str(Engine.get_version_info().hash) + ":" + decoder + ":" + source_sha).sha256_text()
func filename(identity: String) -> String:
	if directory.is_empty() or identity.length() != 64 or not identity.is_valid_hex_number(): return ""
	return directory.path_join(identity + ".bin")
static func fingerprint(path: String) -> String:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<48: return ""
	return file.get_buffer(48).hex_encode()+":"+str(file.get_length())
static func known_publication(path: String,stamp: String,source_sha: String,decoder: String) -> bool:
	publication_mutex.lock(); var proof: Dictionary=verified_publications.get(path,{}); publication_mutex.unlock()
	return not stamp.is_empty() and proof.get("stamp") == stamp and proof.get("source_sha")==source_sha and proof.get("decoder")==decoder and verified_payload(path,stamp)
static func verified_payload(path: String,stamp: String) -> bool:
	# Recheck bytes without decoding a second model graph. Header equality alone
	# would miss same-length payload corruption between reads/publications.
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<48: return false
	var header:=file.get_buffer(48); var size:=int(header.decode_u64(8))
	if header.hex_encode()+":"+str(file.get_length())!=stamp or size<=0 or size>MAX_BYTES or file.get_length()!=size+48: return false
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	while size>0:
		var chunk:=file.get_buffer(mini(size,1048576))
		if chunk.is_empty(): return false
		context.update(chunk); size-=chunk.size()
	var valid:=context.finish()==header.slice(16,48); file.close()
	return valid and fingerprint(path)==stamp
static func remember_publication(path: String,stamp: String,source_sha: String,decoder: String) -> void:
	# Caller holds publication_mutex. Proofs contain only small validated file
	# identities, never decoded model graphs or caller-owned mutable data.
	if verified_publications.size()>=4096 and not verified_publications.has(path): verified_publications.erase(verified_publications.keys()[0])
	verified_publications[path]={"stamp":stamp,"source_sha":source_sha,"decoder":decoder}
func load_data(identity: String, source_sha: String, decoder: String) -> Dictionary:
	failure = ""; var path := filename(identity)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: failure = "Cannot read prepared native data"; return {}
	if file.get_length() < 48 or file.get_buffer(4).get_string_from_ascii() != "NWNC" or file.get_32() != 1: failure = "Invalid native cache header"; return {}
	var size := int(file.get_64()); var checksum := file.get_buffer(32)
	if size < 1 or size > MAX_BYTES or file.get_length() != size + 48: failure = "Invalid native cache length"; return {}
	var payload := file.get_buffer(size)
	if payload.size() != size or digest(payload).hex_decode() != checksum: failure = "Native cache checksum mismatch"; return {}
	var value: Variant = bytes_to_var(payload)
	if not value is Dictionary or value.get("revision") != REVISION or value.get("source_sha") != source_sha or value.get("decoder") != decoder or not value.get("value") is Dictionary:
		failure = "Prepared native data identity mismatch"; return {}
	file.seek(0); var stamp:=file.get_buffer(48).hex_encode()+":"+str(file.get_length())
	publication_mutex.lock(); remember_publication(path,stamp,source_sha,decoder); publication_mutex.unlock()
	return value.value
func save_data(identity: String, source_sha: String, decoder: String, value: Dictionary) -> bool:
	last_save={"serialization_ms":0.0,"checksum_ms":0.0,"write_ms":0.0,"flush_ms":0.0,"publication_ms":0.0,"bytes":0}
	if not configured_writes_enabled(): failure="Optional prepared cache writes disabled for measurement"; last_save.skipped=true; return false
	failure = ""; var path := filename(identity)
	if path.is_empty(): failure = "Invalid native cache identity"; return false
	# A worker may have published this exact immutable resource since our miss.
	# Avoid serializing it again when the current file has a validated identity.
	if known_publication(path,fingerprint(path),source_sha,decoder): return true
	var began:=Time.get_ticks_usec()
	var payload := var_to_bytes({"revision":REVISION,"source_sha":source_sha,"decoder":decoder,"value":value})
	last_save.serialization_ms=(Time.get_ticks_usec()-began)/1000.0; last_save.bytes=payload.size()
	if payload.is_empty() or payload.size() > MAX_BYTES: failure = "Prepared native data exceeds cache bound"; return false
	began=Time.get_ticks_usec(); var checksum:=digest(payload).hex_decode(); last_save.checksum_ms=(Time.get_ticks_usec()-began)/1000.0
	var temporary := path + "." + str(OS.get_process_id()) + "-" + str(OS.get_thread_caller_id()) + "-" + str(Time.get_ticks_usec()) + ".tmp"
	began=Time.get_ticks_usec()
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: failure = "Cannot write prepared native data"; return false
	file.store_buffer("NWNC".to_ascii_buffer()); file.store_32(1); file.store_64(payload.size()); file.store_buffer(checksum); file.store_buffer(payload)
	last_save.write_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec(); file.flush(); last_save.flush_ms=(Time.get_ticks_usec()-began)/1000.0
	var error := file.get_error(); file.close()
	if error != OK: DirAccess.remove_absolute(temporary); failure = "Incomplete prepared native data write"; return false
	# A concurrent repair must not delete a valid entry published after its
	# earlier failed read. Serialize only the final repair/publication step;
	# serialization, checksums and temporary-file writes remain concurrent.
	began=Time.get_ticks_usec(); var result:=publish(temporary,path,identity,source_sha,decoder); last_save.publication_ms=(Time.get_ticks_usec()-began)/1000.0; return result
func publish(temporary: String, path: String, identity: String, source_sha: String, decoder: String) -> bool:
	if not path_publication: return publish_locked(temporary,path,identity,source_sha,decoder,true)
	# Only a single destination needs serial repair/rename. Protect the small
	# lease/proof tables globally; filesystem work and waits use that path's gate.
	publication_mutex.lock()
	if not path_publications.has(path): path_publications[path]={"gate":Mutex.new(),"users":0}
	var lease: Dictionary=path_publications[path]; lease.users+=1; publication_mutex.unlock()
	lease.gate.lock()
	var result:=publish_locked(temporary,path,identity,source_sha,decoder,false)
	lease.gate.unlock()
	publication_mutex.lock(); lease.users-=1
	if int(lease.users)==0: path_publications.erase(path)
	publication_mutex.unlock(); return result
func publish_locked(temporary: String, path: String, identity: String, source_sha: String, decoder: String,global_gate: bool) -> bool:
	for _attempt in 8:
		var stamp:=fingerprint(path)
		var valid:=known_publication(path,stamp,source_sha,decoder)
		if FileAccess.file_exists(path) and not valid:
			# Full checksum/identity validation and decoded-graph destruction are
			# outside the shared lock. A changed file retries before publication.
			valid=not load_data(identity,source_sha,decoder).is_empty()
		if global_gate: publication_mutex.lock()
		if fingerprint(path)!=stamp:
			if global_gate: publication_mutex.unlock()
			continue
		if valid:
			DirAccess.remove_absolute(temporary)
			if global_gate: publication_mutex.unlock()
			failure=""; return true
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		var error:=DirAccess.rename_absolute(temporary,path)
		if error==OK:
			var published_stamp:=fingerprint(path)
			if not global_gate: publication_mutex.lock()
			remember_publication(path,published_stamp,source_sha,decoder)
			if not global_gate: publication_mutex.unlock()
		if global_gate: publication_mutex.unlock()
		if error==OK: failure=""; return true
		# Preserve a valid competing publication even if Windows refused rename.
		if not load_data(identity,source_sha,decoder).is_empty(): DirAccess.remove_absolute(temporary); failure=""; return true
		DirAccess.remove_absolute(temporary); failure="Cannot publish prepared native data"; return false
	DirAccess.remove_absolute(temporary); failure="Prepared native publication changed repeatedly"; return false
