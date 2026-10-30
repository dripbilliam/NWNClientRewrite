extends Node
# Local metadata discovery only. No server queries/downloads or asset decoding.
signal completed(choices: Array,error: String)
const Reader=preload("res://systems/native_data/nwsync_reader.gd")
const Sync=preload("res://systems/native_data/nwsync_store.gd")
var task:=-1
var result: Dictionary={}
var mutex:=Mutex.new()
static func decode_inventory(bytes: PackedByteArray) -> Array:
	if bytes.size()<4: return []
	var count:=int(bytes.decode_u32(0)); var rows: Array=[]
	if count>1024 or bytes.size()!=4+count*552: return []
	for index in count:
		var offset:=4+index*552; var hash:=bytes.slice(offset,offset+40).get_string_from_ascii()
		if not Sync.valid_hash(hash): return []
		var raw:=bytes.slice(offset+40,offset+552); var end:=raw.find(0)
		var label:=raw.slice(0,end if end>=0 else raw.size()).get_string_from_utf8().replace("\n"," ").replace("\r"," ").strip_edges()
		rows.append({"hash":hash,"label":label.left(100)})
	return rows
static func discover(sources: Dictionary) -> Dictionary:
	var base:=sources.duplicate(true)
	for key in ["cacheDirectory","nativeDirectory","helper"]: base.erase(key)
	if not str(base.get("install","")).is_absolute_path(): return {"choices":[],"error":"Installed game location is unavailable."}
	base.archives=[]; base.nwsync=[]
	var choices: Array=[{"label":"Installed game + local content","sources":base}]
	var rows: Array=[]; var note:=""
	var native:=str(sources.get("nativeDirectory","")); var helper:=str(sources.get("helper","")); var cache:=str(sources.get("cacheDirectory",""))
	if FileAccess.file_exists(native.path_join("nwsyncmeta.sqlite3")):
		var reader:=Reader.new()
		if reader.open(helper,native):
			var response:=reader.request(5,PackedByteArray())
			if response.has("bytes"): rows=decode_inventory(response.bytes)
			else: note="Some downloaded content could not be listed."
		else: note="The downloaded content reader is unavailable."
		reader.close()
	var seen: Dictionary={}
	for row in rows: seen[row.hash]=true
	# A fresh/local-only profile legitimately has no downloaded manifests.
	var manifest_directory:=DirAccess.open(cache.path_join("manifests")) if cache.is_absolute_path() else null
	if manifest_directory!=null:
		for hash in manifest_directory.get_files():
			if Sync.valid_hash(hash) and not seen.has(hash): rows.append({"hash":hash,"label":""}); seen[hash]=true
	for row in rows:
		var selected:=base.duplicate(true)
		selected.nwsync=[{"hash":row.hash,"cacheDirectory":cache,"nativeDirectory":native if FileAccess.file_exists(native.path_join("nwsyncmeta.sqlite3")) else "","helper":helper}]
		choices.append({"label":str(row.label) if not str(row.label).is_empty() else "Downloaded server content "+str(choices.size()),"sources":selected,"hash":row.hash})
	return {"choices":choices,"error":note}
func start(sources: Dictionary) -> void:
	close(); var owned:=sources.duplicate(true)
	task=WorkerThreadPool.add_task(func():
		var found:=discover(owned); mutex.lock(); result=found; mutex.unlock(),false,"Find local prework content")
func _process(_delta: float) -> void:
	if task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock(); var found:=result; result={}; mutex.unlock()
	completed.emit(found.get("choices",[]),str(found.get("error","")))
func close() -> void:
	if task>=0: WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock(); result={}; mutex.unlock()
func _exit_tree() -> void: close()
