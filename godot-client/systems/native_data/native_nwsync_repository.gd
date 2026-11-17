extends Node
# Godot-owned NWSync repository access. The server supplies only a base URL;
# resource paths are built from verified SHA-1 identifiers.
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Admission=preload("res://systems/native_data/native_resource_admission.gd")
const MANIFEST_LIMIT:=64*1024*1024
const BLOB_LIMIT:=256*1024*1024
signal progress(phase: String,completed: int,total: int)
signal downloads_finished
signal diagnostic(code: String,reason: String)
class PendingFetch:
	extends RefCounted
	signal settled(response: Array)
	var done:=false
	var terminal_response: Array=[]
	func finish(response: Array)->void:
		if done:return
		done=true
		terminal_response=response
		settled.emit(terminal_response)
	func completed(result: int,code: int,headers: PackedStringArray,body: PackedByteArray)->void:
		finish([result,code,headers,body])
	func cancel()->void:finish([])
	func wait_result()->Array:
		# A close may settle synchronously before the caller begins awaiting.
		if done:return terminal_response
		return await settled
var base_url: String=""
var cache_directory: String=""
var closed:=false
var download_batch_active:=false
var pending_fetches: Array=[]

func configure(url: String,cache: String)->bool:
	if closed or not cache.is_absolute_path():return false
	var scheme_length:=7 if url.begins_with("http://") else 8 if url.begins_with("https://") else 0
	if scheme_length==0 or url.length()>2048 or url.contains("?") or url.contains("#") or url.contains("\\") or url.contains("\n") or url.contains("\r") or url.contains(" "):return false
	var remainder:=url.substr(scheme_length)
	var slash:=remainder.find("/")
	var authority:=remainder if slash<0 else remainder.substr(0,slash)
	if authority.is_empty() or authority.contains("@") or authority.contains("%") or authority.contains("/"):return false
	base_url=url.trim_suffix("/")+"/"
	cache_directory=cache.simplify_path()
	return true

func fetch(relative: String,limit: int)->Dictionary:
	if closed or base_url.is_empty() or relative.is_empty() or relative.contains("..") or relative.begins_with("/") or limit<1 or limit>BLOB_LIMIT:return {"error":"Invalid NWSync repository request"}
	var request:=HTTPRequest.new()
	request.body_size_limit=limit
	request.max_redirects=3
	request.timeout=60.0
	request.use_threads=true
	add_child(request)
	var pending:=PendingFetch.new()
	pending_fetches.append(pending)
	request.request_completed.connect(Callable(pending,"completed"),CONNECT_ONE_SHOT)
	var status:=request.request(base_url+relative)
	if status!=OK:
		pending_fetches.erase(pending)
		request.queue_free()
		return {"error":"NWSync repository request could not start"}
	var response: Array=await pending.wait_result()
	pending_fetches.erase(pending)
	request.queue_free()
	if closed or response.is_empty():return {"error":"NWSync repository request was cancelled"}
	if int(response[0])!=HTTPRequest.RESULT_SUCCESS:return {"error":"NWSync repository request failed (Godot result "+str(response[0])+")"}
	if int(response[1])!=200:return {"error":"NWSync repository returned HTTP "+str(response[1])}
	var body: PackedByteArray=response[3]
	if body.is_empty() or body.size()>limit:return {"error":"NWSync repository response exceeds bound"}
	return {"bytes":body}

func save_verified(subdirectory: String,hash: String,bytes: PackedByteArray)->bool:
	if closed or not Store.valid_hash(hash) or subdirectory not in ["manifests","objects"]:return false
	var folder:=cache_directory.path_join(subdirectory)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var path:=folder.path_join(hash)
	var temporary:=path+"."+str(Time.get_ticks_usec())+"."+str(randi())+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(bytes)
	var write_error:=file.get_error()
	file.flush()
	var flush_error:=file.get_error()
	var written:=file.get_length()
	var length_error:=file.get_error()
	file.close()
	if write_error!=OK or flush_error!=OK or length_error!=OK or written!=bytes.size():
		DirAccess.remove_absolute(temporary)
		diagnostic.emit("nwsync-cache-write","Verified NWSync cache temporary write failed")
		return false
	if closed:DirAccess.remove_absolute(temporary);return false
	var helper:=ProjectSettings.globalize_path("res://.cache/nwn79/windows-profile.exe")
	if not FileAccess.file_exists(helper):DirAccess.remove_absolute(temporary);return false
	var output: Array=[]
	var result:=OS.execute(helper,PackedStringArray(["replace-cache",temporary,path]),output,false,false)
	if result!=0:
		# On a partial Windows replacement failure, retain the verified temp and
		# optional backup for recovery. The helper uses code 4 if the name could
		# not be restored; no caller should mistake this for a cached object.
		diagnostic.emit("nwsync-cache-replace","Verified NWSync cache publication failed (Windows helper code "+str(result)+")")
		return false
	return true

func ensure_manifest(store: RefCounted,hash: String)->Dictionary:
	if not Store.valid_hash(hash):return {"error":"Invalid NWSync manifest hash"}
	var local: Dictionary=store.manifest(hash)
	if not local.has("error"):return local
	var fetched: Dictionary=await fetch("manifests/"+hash,MANIFEST_LIMIT)
	if fetched.has("error"):return fetched
	var decoded: Dictionary=Store.decode_manifest(fetched.bytes,hash)
	if decoded.has("error"):return decoded
	if not save_verified("manifests",hash,fetched.bytes):return {"error":"Verified NWSync manifest could not be cached"}
	return decoded

func ensure_blob(store: RefCounted,entry: Dictionary)->Dictionary:
	var hash:=str(entry.get("hash",""))
	var size:=int(entry.get("size",-1))
	if not Store.valid_hash(hash) or size < -1 or size>BLOB_LIMIT:return {"error":"Invalid NWSync resource identity"}
	var local: Dictionary=store.resource(entry)
	if not local.has("error"):return local
	return await repair_failed_blob(store,entry)
func repair_failed_blob(_store: RefCounted,entry: Dictionary)->Dictionary:
	# Called on the main thread only after a worker has verified a source read
	# failure. Avoid repeating the failed disk/helper read on the frame thread.
	var hash:=str(entry.get("hash",""))
	var size:=int(entry.get("size",-1))
	if not Store.valid_hash(hash) or size < -1 or size>BLOB_LIMIT:return {"error":"Invalid NWSync resource identity"}
	var fetched: Dictionary=await fetch("data/sha1/"+hash.substr(0,2)+"/"+hash.substr(2,2)+"/"+hash,BLOB_LIMIT)
	if fetched.has("error"):return fetched
	var decoded: Dictionary=Store.decode_blob(fetched.bytes,hash,size)
	if decoded.has("error"):return decoded
	if not save_verified("objects",hash,fetched.bytes):return {"error":"Verified NWSync blob could not be cached"}
	return decoded

func download_worker(store: RefCounted,entries: Array,state: Dictionary)->void:
	while not closed and str(state.error).is_empty() and int(state.next)<entries.size():
		var index:=int(state.next)
		state.next=index+1
		var blob: Dictionary=await ensure_blob(store,entries[index])
		if blob.has("error"):
			state.error=str(blob.error)
			break
		state.completed=int(state.completed)+1
		progress.emit("server-content",int(state.completed),entries.size())
	state.workers=int(state.workers)-1
	if int(state.workers)==0:downloads_finished.emit()

func download_entries(store: RefCounted,entries: Array)->Dictionary:
	if download_batch_active:return {"error":"NWSync download batch is already active"}
	if entries.is_empty():progress.emit("server-content",0,0);return {"completed":0}
	download_batch_active=true
	var workers:=mini(4,entries.size())
	var state: Dictionary={"next":0,"completed":0,"workers":workers,"error":""}
	progress.emit("server-content",0,entries.size())
	for _index in range(workers):download_worker.call_deferred(store,entries,state)
	await downloads_finished
	download_batch_active=false
	if closed:return {"error":"NWSync repository was cancelled"}
	if not str(state.error).is_empty():return {"error":state.error}
	return {"completed":state.completed}

func ensure_requirements(store: RefCounted,requirements: Dictionary,language: int,roots: Array[String]=[],mods_directory: String="",disabled_mods: Array=[])->Dictionary:
	var selected: Dictionary=Admission.manifest_hashes(requirements,language)
	if not selected.missing.is_empty():return {"ready":false,"missing":selected.missing}
	var catalogs: Array[Dictionary]=[]
	for row in selected.manifests:
		if closed:return {"error":"NWSync repository was cancelled"}
		progress.emit("server-manifest",catalogs.size(),selected.manifests.size())
		var catalog: Dictionary=await ensure_manifest(store,str(row.hash))
		if catalog.has("error"):
			if row.required:return catalog
			continue
		catalogs.append(catalog)
	progress.emit("server-manifest",catalogs.size(),selected.manifests.size())
	var inventory: Dictionary=store.available_blob_hashes()
	if inventory.has("error"):
		# The installed SQLite inventory is optional. Preserve the verified
		# local file index and fetch missing hashes from the repository instead.
		# The store suppresses further installed reads after this failure.
		var reason:="Installed NWSync resource inventory could not be read"
		diagnostic.emit("network.nwsync-native-cache-failed",reason)
		push_warning(reason)
		inventory={"hashes":store.local_blob_hashes()}
	var available: Dictionary=inventory.hashes
	var missing_entries: Dictionary={}
	for catalog in catalogs:
		for entry in catalog.entries.values():
			var hash:=str(entry.get("hash",""))
			if not available.has(hash) and not missing_entries.has(hash):missing_entries[hash]=entry
	var downloaded: Dictionary=await download_entries(store,missing_entries.values())
	if downloaded.has("error"):return downloaded
	var resolved: Dictionary=Admission.resolve_cached(requirements,store,language,roots,mods_directory,disabled_mods)
	if not resolved.has("repair"):return resolved
	# A custom TLK may be nested inside a selected NWSync NWM/HAK. Admission
	# probes only that selected archive. Repair its failed verified read on this
	# main-thread async path, then resolve the same requirements exactly once.
	var repair: Dictionary=resolved.repair
	if repair.get("store")!=store or not (repair.get("entry") is Dictionary):
		return {"error":"Invalid NWSync admission repair source"}
	var fixed: Dictionary=await repair_failed_blob(store,repair.entry)
	if fixed.has("error"):return fixed
	if closed:return {"error":"NWSync repository was cancelled"}
	return Admission.resolve_cached(requirements,store,language,roots,mods_directory,disabled_mods)

func close()->void:
	closed=true
	for child in get_children():
		if child is HTTPRequest:child.cancel_request()
	# HTTPRequest.cancel_request() does not emit request_completed. Wake every
	# suspended fetch explicitly so admission/download cancellation can settle.
	for pending in pending_fetches.duplicate():pending.cancel()
