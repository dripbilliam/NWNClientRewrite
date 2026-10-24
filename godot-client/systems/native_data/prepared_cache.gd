extends RefCounted
# Content-addressed native Variant data, never serialized Objects/scripts.
# Runtime asset data is kept outside the source workspace.
const REVISION := "native-assets-3"
const MAX_BYTES := 256 * 1024 * 1024
static var publication_mutex:=Mutex.new()
var directory := ""
var failure := ""
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
	return value.value
func save_data(identity: String, source_sha: String, decoder: String, value: Dictionary) -> bool:
	failure = ""; var path := filename(identity)
	if path.is_empty(): failure = "Invalid native cache identity"; return false
	var payload := var_to_bytes({"revision":REVISION,"source_sha":source_sha,"decoder":decoder,"value":value})
	if payload.is_empty() or payload.size() > MAX_BYTES: failure = "Prepared native data exceeds cache bound"; return false
	var temporary := path + "." + str(OS.get_process_id()) + "-" + str(OS.get_thread_caller_id()) + "-" + str(Time.get_ticks_usec()) + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: failure = "Cannot write prepared native data"; return false
	file.store_buffer("NWNC".to_ascii_buffer()); file.store_32(1); file.store_64(payload.size()); file.store_buffer(digest(payload).hex_decode()); file.store_buffer(payload); file.flush()
	var error := file.get_error(); file.close()
	if error != OK: DirAccess.remove_absolute(temporary); failure = "Incomplete prepared native data write"; return false
	# A concurrent repair must not delete a valid entry published after its
	# earlier failed read. Serialize only the final repair/publication step;
	# serialization, checksums and temporary-file writes remain concurrent.
	publication_mutex.lock()
	var published:=publish(temporary,path,identity,source_sha,decoder)
	publication_mutex.unlock()
	return published
func publish(temporary: String, path: String, identity: String, source_sha: String, decoder: String) -> bool:
	if FileAccess.file_exists(path):
		if not load_data(identity,source_sha,decoder).is_empty(): DirAccess.remove_absolute(temporary); return true
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary)
		if not load_data(identity,source_sha,decoder).is_empty(): return true
		failure = "Cannot publish prepared native data"; return false
	return true
