extends RefCounted
# Godot-owned durable store for the opaque BIC returned by server 3/10.
# Names are metadata only. Paths contain a generated local UUID or SHA-256.
const Gff=preload("res://systems/native_data/gff_document.gd")
const MAX_BYTES:=948*65535-16
static var publication_mutex:=Mutex.new()
var directory: String=""

func configure(path: String)->bool:
	var resolved:=ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().trim_suffix("/")
	if not resolved.is_absolute_path() or resolved.is_empty():return false
	directory=resolved
	return DirAccess.make_dir_recursive_absolute(_blobs())==OK and DirAccess.make_dir_recursive_absolute(_entries())==OK

func store(message: Dictionary,existing_id: String="")->Dictionary:
	if directory.is_empty() or not message.get("data") is PackedByteArray:return {"error":"Character vault or export bytes are unavailable."}
	if not existing_id.is_empty() and not _valid_id(existing_id):return {"error":"Invalid saved character identity."}
	var bytes: PackedByteArray=message.data
	if bytes.size()<56 or bytes.size()>MAX_BYTES:return {"error":"Invalid exported character size."}
	var parser=Gff.new();var document: Dictionary=parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty() or document.is_empty():return {"error":"Exported character is not a valid BIC."}
	var name:=(_local_name(document.root.get("FirstName"))+" "+_local_name(document.root.get("LastName"))).strip_edges()
	if name.is_empty():name="Saved character"
	publication_mutex.lock()
	var result: Dictionary=_store_locked(bytes,existing_id,name)
	publication_mutex.unlock()
	return result

func export_character(id: String)->Dictionary:
	if directory.is_empty() or not _valid_id(id):return {"error":"Invalid saved character identity."}
	var record: Dictionary=_latest(id)
	if record.has("error"):return record
	var path:=_blobs().path_join(str(record.sha256)+".bic")
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()!=int(record.bytes) or _digest(bytes)!=str(record.sha256):return {"error":"Saved character integrity check failed."}
	var parser=Gff.new();parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty():return {"error":"Saved character BIC is invalid."}
	return {"ready":true,"entry":record,"data":bytes}

func list()->Dictionary:
	if directory.is_empty():return {"error":"Character vault is unavailable."}
	var folder:=DirAccess.open(_entries())
	if folder==null:return {"error":"Saved character entries are unavailable."}
	var newest: Dictionary={};var invalid:=0
	for filename in folder.get_files():
		var record: Dictionary=_read_entry(filename)
		if record.is_empty():
			if filename.ends_with(".json"):invalid+=1
			continue
		var id: String=record.id
		if not newest.has(id) or int(record.revision)>int(newest[id].revision):newest[id]=record
	var entries: Array[Dictionary]=[]
	for id in newest:entries.append(newest[id])
	entries.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if int(a.savedAtUnixMs)!=int(b.savedAtUnixMs):return int(a.savedAtUnixMs)>int(b.savedAtUnixMs)
		return str(a.id)<str(b.id))
	return {"ready":true,"entries":entries,"invalidEntries":invalid}

func _store_locked(bytes: PackedByteArray,existing_id: String,name: String)->Dictionary:
	var id:=existing_id if not existing_id.is_empty() else _uuid()
	var revision:=1
	if not existing_id.is_empty():
		var previous: Dictionary=_latest(existing_id)
		if previous.has("error"):return previous
		# A broken current blob must not be silently replaced by a new revision.
		if export_character(existing_id).has("error"):return {"error":"Existing saved character failed its integrity check."}
		revision=int(previous.revision)+1
	var sha:=_digest(bytes);var blob_path:=_blobs().path_join(sha+".bic")
	if FileAccess.file_exists(blob_path):
		var existing:=FileAccess.get_file_as_bytes(blob_path)
		if existing.size()!=bytes.size() or _digest(existing)!=sha:return {"error":"Saved character blob integrity check failed."}
	else:
		var blob_result: Dictionary=_atomic_write(blob_path,bytes,"blob")
		if blob_result.has("error"):return blob_result
	if not _allow_commit("after-blob"):return {"error":"Character save was interrupted before entry commit."}
	var entry: Dictionary={"id":id,"revision":revision,"sha256":sha,"bytes":bytes.size(),"name":name,"savedAtUnixMs":int(Time.get_unix_time_from_system()*1000.0)}
	var filename:=id+"."+str(revision)+"."+_nonce()+".json"
	var entry_bytes: PackedByteArray=(JSON.stringify(entry)+"\n").to_utf8_buffer()
	var entry_result: Dictionary=_atomic_write(_entries().path_join(filename),entry_bytes,"entry")
	if entry_result.has("error"):return entry_result
	return {"ready":true,"entry":entry}

func _atomic_write(destination: String,bytes: PackedByteArray,kind: String)->Dictionary:
	var temporary:=destination+"."+_nonce()+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return {"error":"Could not create temporary character "+kind+" file."}
	file.store_buffer(bytes);file.flush()
	var write_error:=file.get_error();file.close()
	if write_error!=OK:
		DirAccess.remove_absolute(temporary)
		return {"error":"Could not flush temporary character "+kind+" file."}
	var verification:=FileAccess.get_file_as_bytes(temporary)
	if verification.size()!=bytes.size() or _digest(verification)!=_digest(bytes):
		DirAccess.remove_absolute(temporary)
		return {"error":"Temporary character "+kind+" verification failed."}
	if not _allow_commit("before-"+kind+"-commit"):
		DirAccess.remove_absolute(temporary)
		return {"error":"Character "+kind+" commit was interrupted."}
	if FileAccess.file_exists(destination) or DirAccess.rename_absolute(temporary,destination)!=OK:
		DirAccess.remove_absolute(temporary)
		return {"error":"Could not commit character "+kind+" file."}
	return {"ready":true}

func _latest(id: String)->Dictionary:
	var listing: Dictionary=list()
	if listing.has("error"):return listing
	for record in listing.entries:
		if str(record.id)==id:return record
	return {"error":"Saved character identity is unavailable."}

func _read_entry(filename: String)->Dictionary:
	if not filename.ends_with(".json"):return {}
	var parts:=filename.trim_suffix(".json").split(".")
	if parts.size()!=3 or not _valid_id(parts[0]) or not parts[1].is_valid_int() or int(parts[1])<1 or not _valid_hex(parts[2],32):return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(_entries().path_join(filename)))
	if not parsed is Dictionary:return {}
	if str(parsed.get("id",""))!=parts[0] or int(parsed.get("revision",0))!=int(parts[1]) or not _valid_hex(str(parsed.get("sha256","")),64):return {}
	if not parsed.get("bytes") is float and not parsed.get("bytes") is int:return {}
	if int(parsed.bytes)<56 or int(parsed.bytes)>MAX_BYTES or not parsed.get("name") is String:return {}
	if not parsed.get("savedAtUnixMs") is float and not parsed.get("savedAtUnixMs") is int:return {}
	return {"id":parts[0],"revision":int(parsed.revision),"sha256":str(parsed.sha256),"bytes":int(parsed.bytes),"name":str(parsed.name),"savedAtUnixMs":int(parsed.savedAtUnixMs)}

func _blobs()->String:return directory.path_join("blobs")
func _entries()->String:return directory.path_join("entries")
func _allow_commit(_stage: String)->bool:return true

static func _local_name(value: Variant)->String:
	if not value is Dictionary:return ""
	for row in value.get("entries",[]):
		if row is Dictionary and row.get("text") is String:return str(row.text)
	return ""

static func _digest(bytes: PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()

static func _valid_id(id: String)->bool:
	if id.length()!=36 or id!=id.to_lower():return false
	for at in id.length():
		if at in [8,13,18,23]:
			if id[at]!="-":return false
		elif not id[at] in "0123456789abcdef":return false
	return true

static func _valid_hex(value: String,length: int)->bool:
	if value.length()!=length or value!=value.to_lower():return false
	for c in value:
		if not c in "0123456789abcdef":return false
	return true

static func _nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
static func _uuid()->String:
	var bytes:=Crypto.new().generate_random_bytes(16)
	bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128
	var text:=bytes.hex_encode()
	return text.substr(0,8)+"-"+text.substr(8,4)+"-"+text.substr(12,4)+"-"+text.substr(16,4)+"-"+text.substr(20,12)
