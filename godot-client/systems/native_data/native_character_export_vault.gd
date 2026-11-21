extends RefCounted
# Godot-owned durable store for the opaque BIC returned by server 3/10.
# Names are metadata only. Paths contain a generated local UUID or SHA-256.
const Gff=preload("res://systems/native_data/gff_document.gd")
const CreationBic=preload("res://systems/native_data/creation_bic.gd")
const MAX_BYTES:=948*65535-16
static var publication_mutex:=Mutex.new()
var directory: String=""

func configure(path: String)->bool:
	var resolved:=ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().trim_suffix("/")
	if not resolved.is_absolute_path() or resolved.is_empty():return false
	directory=resolved
	return DirAccess.make_dir_recursive_absolute(_blobs())==OK and DirAccess.make_dir_recursive_absolute(_entries())==OK

func store(message: Dictionary,existing_id: String="",deduplicate_bytes: bool=false)->Dictionary:
	if directory.is_empty() or not message.get("data") is PackedByteArray:return {"error":"Character vault or export bytes are unavailable."}
	if not existing_id.is_empty() and not (_valid_id(existing_id) if deduplicate_bytes else _valid_server_id(existing_id)):return {"error":"Invalid saved character identity."}
	if message.data.size()<56 or message.data.size()>MAX_BYTES:return {"error":"Invalid exported character size."}
	var bytes: PackedByteArray=message.data.duplicate()
	var parser=Gff.new();var document: Dictionary=parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty() or document.is_empty():bytes.fill(0);return {"error":"Exported character is not a valid BIC."}
	if deduplicate_bytes:
		if DirAccess.make_dir_recursive_absolute(_created_entries())!=OK:bytes.fill(0);return {"error":"Created character storage is unavailable."}
		var invalid: String=CreationBic.validate_created_character(document)
		if not invalid.is_empty():bytes.fill(0);return {"error":invalid}
	var names: Array[String]=[]
	for value in [_local_name(document.root.get("FirstName")),_local_name(document.root.get("LastName"))]:
		if not value.is_empty():names.append(value)
	var name:=_created_filename(document.root) if deduplicate_bytes else " ".join(names)
	if name.is_empty():name="Saved character"
	publication_mutex.lock()
	var result: Dictionary=_store_locked(bytes,_digest(bytes) if deduplicate_bytes and existing_id.is_empty() else existing_id,name,deduplicate_bytes and existing_id.is_empty(),_created_description(document.root,name) if deduplicate_bytes else {})
	publication_mutex.unlock()
	bytes.fill(0)
	return result

static func _created_filename(root: Dictionary)->String:
	var original:=_local_name(root.get("FirstName"))+"_"+_local_name(root.get("LastName"))
	var clean:=""
	for character in original:
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":clean+=character
	return (clean.substr(0,24) if not clean.is_empty() else "character")+".bic"

static func _created_description(root: Dictionary,name: String)->Dictionary:
	var classes: Array=[];var level:=0
	for row in root.get("ClassList",[]):
		classes.append({"id":int(row.get("Class",0)),"level":int(row.get("ClassLevel",0))});level+=int(row.get("ClassLevel",0))
	var names: PackedStringArray=[]
	for value in [_local_name(root.get("FirstName")),_local_name(root.get("LastName"))]:
		if not value.is_empty():names.append(value)
	var display:=" ".join(names)
	return {"displayName":display if not display.is_empty() else name,"source":"Created character","raceId":root.get("Race"),"gender":root.get("Gender"),"portrait":root.get("Portrait"),"classes":classes,"level":level}

func export_character(id: String,created: bool=false)->Dictionary:
	if directory.is_empty() or not (_valid_id(id) if created else _valid_server_id(id)):return {"error":"Invalid saved character identity."}
	var record: Dictionary=_entry(id,created)
	if record.has("error"):return record
	var path:=_blobs().path_join(str(record.sha256)+".bic")
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()!=int(record.bytes) or _digest(bytes)!=str(record.sha256):return {"error":"Saved character integrity check failed."}
	var parser=Gff.new();var document: Dictionary=parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty() or created and not CreationBic.validate_created_character(document).is_empty():return {"error":"Saved character BIC is invalid."}
	var result: Dictionary={"ready":true,"entry":record,"data":bytes}
	if created:result.root=document.root
	return result

func open_created()->Dictionary:
	# CharacterVault.open() read persisted creation BICs by SHA key before the
	# createOnly wizard opened. A bad individual record was skipped, not fatal.
	if directory.is_empty():return {"error":"Character vault is unavailable."}
	if DirAccess.make_dir_recursive_absolute(_created_entries())!=OK:return {"error":"Created character storage is unavailable."}
	var folder:=DirAccess.open(_created_entries())
	if folder==null:return {"error":"Created character entries are unavailable."}
	var files: PackedStringArray=folder.get_files(); files.sort()
	var entries: Array=[];var failures: Array=[]
	for filename in files:
		if not filename.ends_with(".json"):continue
		var id:=filename.trim_suffix(".json")
		if not _valid_hex(id,64):continue
		var saved:=export_character(id,true)
		if not saved.get("ready",false):failures.append({"id":id,"name":filename,"error":str(saved.get("error","Invalid character record"))});continue
		var description: Dictionary=saved.entry.duplicate(true)
		description.merge(_created_description(saved.root,str(saved.entry.name)),true)
		description.bytes=saved.data; description.source="Local vault"
		entries.append(description)
	return {"ready":true,"entries":entries,"failures":failures}

func list()->Dictionary:
	if directory.is_empty():return {"error":"Character vault is unavailable."}
	var folder:=DirAccess.open(_entries())
	if folder==null:return {"error":"Saved character entries are unavailable."}
	var entries: Array[Dictionary]=[]
	for filename in folder.get_files():
		if not filename.ends_with(".json"):continue
		var id:=filename.trim_suffix(".json")
		if not _valid_server_id(id):continue
		var record: Dictionary=_entry(id)
		if record.has("error"):return record
		entries.append(record)
	entries.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if str(a.savedAt)!=str(b.savedAt):return str(a.savedAt)>str(b.savedAt)
		return str(a.id)<str(b.id))
	return {"ready":true,"entries":entries}

func _store_locked(bytes: PackedByteArray,existing_id: String,name: String,created: bool=false,description: Dictionary={})->Dictionary:
	var id:=existing_id if not existing_id.is_empty() else _uuid()
	if not existing_id.is_empty() and not created:
		var previous: Dictionary=_entry(existing_id)
		if previous.has("error"):return previous
	var sha:=_digest(bytes);var blob_path:=_blobs().path_join(sha+".bic")
	if FileAccess.file_exists(blob_path):
		var existing:=FileAccess.get_file_as_bytes(blob_path)
		if existing.size()!=bytes.size() or _digest(existing)!=sha:return {"error":"Saved character blob integrity check failed."}
	else:
		var blob_result: Dictionary=_atomic_write(blob_path,bytes,"blob")
		if blob_result.has("error"):return blob_result
	var now:=int(Time.get_unix_time_from_system()*1000.0)
	var stamp:=Time.get_datetime_string_from_unix_time(int(now/1000))+".%03dZ"%[now%1000]
	var entry: Dictionary={"id":id,"sha256":sha,"bytes":bytes.size(),"name":name,"savedAt":stamp}
	entry.merge(description,true)
	var entry_bytes: PackedByteArray=(JSON.stringify(entry)+"\n").to_utf8_buffer()
	var entry_result: Dictionary=_atomic_write((_created_entries() if created else _entries()).path_join(id+".json"),entry_bytes,"entry")
	if entry_result.has("error"):return entry_result
	return {"ready":true,"entry":entry}

func _atomic_write(destination: String,bytes: PackedByteArray,kind: String)->Dictionary:
	var temporary:=destination+"."+_nonce()+".tmp"
	if FileAccess.file_exists(temporary):return {"error":"Temporary character "+kind+" file already exists."}
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
	if kind=="blob" and FileAccess.file_exists(destination) or DirAccess.rename_absolute(temporary,destination)!=OK:
		DirAccess.remove_absolute(temporary)
		return {"error":"Could not commit character "+kind+" file."}
	return {"ready":true}

func _entry(id: String,created: bool=false)->Dictionary:
	if not (_valid_id(id) if created else _valid_server_id(id)):return {"error":"Invalid saved character selection"}
	var file:=FileAccess.open((_created_entries() if created else _entries()).path_join(id+".json"),FileAccess.READ)
	if file==null:return {"error":"Saved character identity is unavailable."}
	var parsed: Variant=JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:return {"error":"Saved character metadata is invalid"}
	if parsed.get("id")!=id or not parsed.get("sha256") is String or not _valid_hex(parsed.sha256,64) or not parsed.get("bytes") is float and not parsed.get("bytes") is int or int(parsed.bytes)<56 or int(parsed.bytes)>MAX_BYTES or float(parsed.bytes)!=float(int(parsed.bytes)) or not parsed.get("name") is String or not parsed.get("savedAt") is String:return {"error":"Saved character metadata is invalid"}
	var stamp:=str(parsed.savedAt)
	if stamp.length()<20 or not stamp.ends_with("Z") or Time.get_unix_time_from_datetime_string(stamp.substr(0,19))==0:return {"error":"Saved character metadata is invalid"}
	var entry: Dictionary={"id":id,"sha256":str(parsed.sha256),"bytes":int(parsed.bytes),"name":str(parsed.name),"savedAt":stamp}
	for key in ["displayName","source","raceId","gender","portrait","classes","level"]:
		if parsed.has(key):entry[key]=parsed[key]
	return entry

func _blobs()->String:return directory.path_join("blobs")
func _entries()->String:return directory.path_join("entries")
func _created_entries()->String:return directory.path_join("created")
static func _local_name(value: Variant)->String:
	if value is String:return value
	if not value is Dictionary:return ""
	var entries: Variant=value.get("entries",[])
	if entries is Array:
		for entry in entries:
			if entry is Dictionary and entry.get("text") is String:return str(entry.text)
	return ""

static func _digest(bytes: PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()

static func _valid_id(id: String)->bool:
	if _valid_hex(id,64):return true
	return _valid_server_id(id)
static func _valid_server_id(id: String)->bool:
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
