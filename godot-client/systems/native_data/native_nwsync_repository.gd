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
signal progress_detail(state: Dictionary)
signal diagnostic_detail(event: Dictionary)
class PendingResult:
	extends RefCounted
	signal settled(value: Dictionary)
	var done:=false
	var terminal_value: Dictionary={}
	func finish(value: Dictionary)->void:
		if done:return
		done=true
		terminal_value=value
		settled.emit(value)
	func wait_result()->Dictionary:
		if done:return terminal_value
		return await settled
class TransferFrame:
	extends RefCounted
	signal ready
	var done:=false
	func wake()->void:
		if done:return
		done=true
		ready.emit()
var base_url: String=""
var cache_directory: String=""
var closed:=false
var download_batch_active:=false
var concurrency:=4
var active_clients: Array[HTTPClient]=[]
var transfer_frames: Array[TransferFrame]=[]
var pending_manifests: Dictionary={}
var manifests: Dictionary={}
var pending_blobs: Dictionary={}
var downloaded_bytes:=0
var progress_time_msec:=0
var progress_state: Dictionary={}

func publish_progress(phase: String,completed: int,total: int,manifest: String="",force: bool=false)->void:
	progress_state={"phase":phase,"manifest":manifest,"completed":completed,"total":total}
	var now:=Time.get_ticks_msec()
	if force or now-progress_time_msec>100:
		progress_time_msec=now
		var event:=progress_state.duplicate()
		event.downloadedBytes=downloaded_bytes
		progress_detail.emit(event)
	progress.emit(phase,completed,total)

func report_diagnostic(code: String,reason: String,context: Dictionary={})->void:
	var event: Dictionary={"code":code,"reason":reason}
	event.merge(context,true)
	diagnostic_detail.emit(event)
	diagnostic.emit(code,reason)

func report_resource_result(result: Dictionary)->void:
	if result.has("error"):
		report_diagnostic("network.resource-resolution-failed","Server resource lookup failed")
		return
	for row in result.get("missing",[]):
		if not row is Dictionary:continue
		var kind:=str(row.get("kind",""));var name:=str(row.get("name",""))
		if kind=="nwsync" and name=="primary manifest":report_diagnostic("network.resource-invalid","Primary NWSync manifest hash is empty or invalid")
		elif kind=="nwsync" and name=="required additional manifest":report_diagnostic("network.resource-invalid","Additional NWSync manifest hash is empty or invalid",{"required":true})
		elif kind=="hak" and name.is_empty():report_diagnostic("network.resource-invalid","Required HAK resource reference is empty")
		else:report_diagnostic("network.resource-unavailable","Required server resource is unavailable",{"kind":kind,"name":name,"required":true})

func read_cache(subdirectory: String,hash: String,limit: int)->Dictionary:
	var path:=cache_directory.path_join(subdirectory).path_join(hash)
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:
		if FileAccess.get_open_error()==ERR_FILE_NOT_FOUND:return {"present":false}
		return {"error":"Cached NWSync entry could not be read"}
	var length:=file.get_length()
	if length>limit:
		file.close()
		return {"error":"Cached NWSync entry exceeds the supported size"}
	var bytes:=file.get_buffer(length)
	file.close()
	if bytes.size()!=length:return {"error":"Cached NWSync entry could not be read"}
	return {"present":true,"bytes":bytes}

func parse_http_url(value: String)->Dictionary:
	var url:=value.strip_edges().replace("\r","").replace("\n","").replace("\t","").replace("\\","/")
	var marker:=url.find("://")
	if marker<0:
		var colon:=url.find(":")
		if colon<0 or url.substr(0,colon).to_lower() not in ["http","https"]:return {}
		var payload:=url.substr(colon+1)
		while payload.begins_with("/"):payload=payload.substr(1)
		url=url.substr(0,colon)+"://"+payload
		marker=url.find("://")
	var scheme:=url.substr(0,marker).to_lower()
	if scheme not in ["http","https"]:return {}
	var tail:=url.substr(marker+3)
	var boundary:=tail.length()
	for symbol in ["/","?","#"]:
		var at:=tail.find(symbol)
		if at>=0:boundary=mini(boundary,at)
	var authority:=tail.substr(0,boundary)
	if authority.is_empty() or authority.contains("@") or authority.contains(" "):return {}
	var hostname:=authority
	var port:=443 if scheme=="https" else 80
	if authority.begins_with("["):
		var bracket:=authority.find("]")
		if bracket<0:return {}
		hostname=authority.substr(1,bracket-1)
		if bracket+1<authority.length():
			if authority[bracket+1]!=":":return {}
			var port_text:=authority.substr(bracket+2)
			if not port_text.is_empty():
				if not port_text.is_valid_int():return {}
				port=int(port_text)
	elif authority.count(":")==1:
		var colon:=authority.rfind(":")
		var port_text:=authority.substr(colon+1)
		if not port_text.is_empty():
			if not port_text.is_valid_int():return {}
			port=int(port_text)
		hostname=authority.substr(0,colon)
	elif authority.count(":")>1:return {}
	if hostname.is_empty() or port<1 or port>65535:return {}
	var resource:=tail.substr(boundary)
	if resource.is_empty() or not resource.begins_with("/"):resource="/"+resource
	var fragment:=resource.find("#")
	if fragment>=0:resource=resource.substr(0,fragment)
	return {"scheme":scheme,"authority":authority,"host":hostname,"port":port,"path":resource.replace(" ","%20")}

func configure(url: String,cache: String,download_concurrency: int=4)->bool:
	if closed or not cache.is_absolute_path() or download_concurrency<1 or download_concurrency>16:return false
	concurrency=download_concurrency
	if url.is_empty():
		base_url=""
		cache_directory=cache.simplify_path()
		return true
	var parsed:=parse_http_url(url)
	if parsed.is_empty() or parsed.path.contains("?") or url.contains("#"):return false
	var pathname:=str(parsed.path)
	if not pathname.ends_with("/"):pathname+="/"
	base_url=str(parsed.scheme)+"://"+str(parsed.authority)+pathname
	cache_directory=cache.simplify_path()
	return true

func release_client(client: HTTPClient,result: Dictionary)->Dictionary:
	client.close()
	active_clients.erase(client)
	return result

func transfer_frame()->void:
	if closed:return
	var waiter:=TransferFrame.new()
	transfer_frames.append(waiter)
	get_tree().process_frame.connect(Callable(waiter,"wake"),CONNECT_ONE_SHOT)
	await waiter.ready
	transfer_frames.erase(waiter)

func response_header(headers: PackedStringArray,name: String)->String:
	for header in headers:
		var line:=str(header)
		if line.to_lower().begins_with(name.to_lower()+":"):
			return line.substr(line.find(":")+1).strip_edges()
	return ""

func redirect_url(current: Dictionary,location: String)->String:
	if location.to_lower().begins_with("http://") or location.to_lower().begins_with("https://"):return location
	if location.begins_with("//"):return str(current.scheme)+":"+location
	var origin:=str(current.scheme)+"://"+str(current.authority)
	if location.begins_with("/"):return origin+location
	if location.begins_with("?"):return origin+str(current.path).split("?")[0]+location
	if location.begins_with("#"):return origin+str(current.path)+location
	var suffix:=location
	var query:=""
	var question:=suffix.find("?")
	if question>=0:query=suffix.substr(question);suffix=suffix.substr(0,question)
	var current_path:=str(current.path).split("?")[0]
	return origin+current_path.get_base_dir().path_join(suffix).simplify_path()+query

func fetch(relative: String,limit: int)->Dictionary:
	if closed:return {"error":"Server content loading was cancelled"}
	if base_url.is_empty() or relative.is_empty() or relative.contains("..") or relative.begins_with("/") or limit<1 or limit>BLOB_LIMIT:return {"error":"Invalid NWSync repository request"}
	var url:=base_url+relative
	var deadline:=Time.get_ticks_msec()+60000
	for redirect in range(21):
		if closed:return {"error":"Server content loading was cancelled"}
		var target:=parse_http_url(url)
		if target.is_empty():return {"error":"NWSync repository request failed"}
		var client:=HTTPClient.new()
		active_clients.append(client)
		var tls: TLSOptions=TLSOptions.client() if target.scheme=="https" else null
		if client.connect_to_host(str(target.host),int(target.port),tls)!=OK:return release_client(client,{"error":"NWSync repository request failed"})
		while client.get_status() in [HTTPClient.STATUS_RESOLVING,HTTPClient.STATUS_CONNECTING]:
			if closed:return release_client(client,{"error":"Server content loading was cancelled"})
			if Time.get_ticks_msec()>=deadline:return release_client(client,{"error":"NWSync repository request failed"})
			if client.poll()!=OK:return release_client(client,{"error":"NWSync repository request failed"})
			await transfer_frame()
		if client.get_status()!=HTTPClient.STATUS_CONNECTED:return release_client(client,{"error":"NWSync repository request failed"})
		if client.request(HTTPClient.METHOD_GET,str(target.path),PackedStringArray(["Accept-Encoding: identity"]))!=OK:return release_client(client,{"error":"NWSync repository request failed"})
		while not client.has_response():
			if closed:return release_client(client,{"error":"Server content loading was cancelled"})
			if Time.get_ticks_msec()>=deadline:return release_client(client,{"error":"NWSync repository request failed"})
			if client.poll()!=OK:return release_client(client,{"error":"NWSync repository request failed"})
			if client.get_status() in [HTTPClient.STATUS_CANT_CONNECT,HTTPClient.STATUS_CANT_RESOLVE,HTTPClient.STATUS_CONNECTION_ERROR,HTTPClient.STATUS_TLS_HANDSHAKE_ERROR,HTTPClient.STATUS_DISCONNECTED]:return release_client(client,{"error":"NWSync repository request failed"})
			await transfer_frame()
		var status:=client.get_response_code()
		var headers:=client.get_response_headers()
		if status in [301,302,303,307,308]:
			var location:=response_header(headers,"location")
			if location.is_empty():return release_client(client,{"error":"NWSync repository returned HTTP "+str(status)})
			url=redirect_url(target,location)
			client.close();active_clients.erase(client)
			continue
		if status<200 or status>=300:return release_client(client,{"error":"NWSync repository returned HTTP "+str(status)})
		var declared:=response_header(headers,"content-length")
		if declared.is_valid_int() and int(declared)>limit:return release_client(client,{"error":"NWSync download exceeds the supported size"})
		var bytes:=PackedByteArray()
		while client.get_status()==HTTPClient.STATUS_BODY:
			if closed:return release_client(client,{"error":"Server content loading was cancelled"})
			if Time.get_ticks_msec()>=deadline:return release_client(client,{"error":"NWSync repository request failed"})
			if client.poll()!=OK:return release_client(client,{"error":"NWSync repository request failed"})
			var chunk:=client.read_response_body_chunk()
			if chunk.is_empty():
				await transfer_frame()
				continue
			if bytes.size()+chunk.size()>limit:return release_client(client,{"error":"NWSync download exceeds the supported size"})
			bytes.append_array(chunk)
			downloaded_bytes+=chunk.size()
			if not progress_state.is_empty():publish_progress(str(progress_state.phase),int(progress_state.completed),int(progress_state.total),str(progress_state.manifest))
		if closed:return release_client(client,{"error":"Server content loading was cancelled"})
		if client.get_status()!=HTTPClient.STATUS_CONNECTED:return release_client(client,{"error":"NWSync repository request failed"})
		if declared.is_valid_int() and bytes.size()!=int(declared):return release_client(client,{"error":"NWSync repository request failed"})
		return release_client(client,{"bytes":bytes})
	return {"error":"NWSync repository request failed"}

func save_verified(subdirectory: String,hash: String,bytes: PackedByteArray)->bool:
	if closed or not Store.valid_hash(hash) or subdirectory not in ["manifests","objects"]:return false
	var folder:=cache_directory.path_join(subdirectory)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var path:=folder.path_join(hash)
	var temporary:=""
	var crypto:=Crypto.new()
	for _attempt in range(4):
		var nonce:=crypto.generate_random_bytes(16)
		if nonce.size()!=16:return false
		var candidate:=path+"."+nonce.hex_encode()+".tmp"
		if not FileAccess.file_exists(candidate) and not DirAccess.dir_exists_absolute(candidate):
			temporary=candidate
			break
	if temporary.is_empty():return false
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
		report_diagnostic("nwsync-cache-write","Verified NWSync cache temporary write failed")
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
		report_diagnostic("nwsync-cache-replace","Verified NWSync cache publication failed (Windows helper code "+str(result)+")")
		return false
	return true

func ensure_manifest(store: RefCounted,hash: String)->Dictionary:
	if closed:return {"error":"Server content loading was cancelled"}
	if not Store.valid_hash(hash):return {"error":"Invalid NWSync manifest hash"}
	if manifests.has(hash):return manifests[hash]
	if pending_manifests.has(hash):return await pending_manifests[hash].wait_result()
	var pending:=PendingResult.new()
	pending_manifests[hash]=pending
	var result: Dictionary=await load_manifest(store,hash)
	if closed:result={"error":"Server content loading was cancelled"}
	if result.has("error"):
		if not closed:
			var detail:=str(result.error)
			var recognized:=false
			for prefix in ["Invalid","Unsupported","NWSync","Downloaded","Cached","Required","Duplicate"]:
				if detail.begins_with(prefix):recognized=true;break
			if not recognized:detail="CONTENT_LOAD_FAILED"
			report_diagnostic("network.nwsync-manifest-failed","Server content could not be loaded",{"hash":hash,"detail":detail})
	else:manifests[hash]=result
	pending.finish(result)
	pending_manifests.erase(hash)
	return result

func load_manifest(store: RefCounted,hash: String)->Dictionary:
	publish_progress("server-manifest",0,0,hash,true)
	var cached: Dictionary=read_cache("manifests",hash,MANIFEST_LIMIT)
	if cached.has("error"):return cached
	if cached.present:
		if Store.sha1(cached.bytes)==hash:return Store.decode_manifest(cached.bytes,hash)
		report_diagnostic("network.nwsync-cache-corrupt","Cached server manifest failed verification",{"hash":hash})
	var native_available: bool=store.has_native_source()
	var local: Dictionary=store.manifest(hash)
	if native_available and not store.has_native_source():
		report_diagnostic("network.nwsync-native-cache-failed","Installed NWSync catalog could not be read")
	if not local.has("error"):return local
	if base_url.is_empty():return {"error":"Required NWSync manifest is not cached and no repository is available"}
	var fetched: Dictionary=await fetch("manifests/"+hash,MANIFEST_LIMIT)
	if fetched.has("error"):return fetched
	if Store.sha1(fetched.bytes)!=hash:return {"error":"Downloaded NWSync manifest failed hash verification"}
	var decoded: Dictionary=Store.decode_manifest(fetched.bytes,hash)
	if decoded.has("error"):return decoded
	if not save_verified("manifests",hash,fetched.bytes):return {"error":"Verified NWSync manifest could not be cached"}
	return decoded

func ensure_blob(store: RefCounted,entry: Dictionary)->Dictionary:
	if closed:return {"error":"Server content loading was cancelled"}
	var hash:=str(entry.get("hash",""))
	var size:=int(entry.get("size",-1))
	if not Store.valid_hash(hash) or size < -1 or size>BLOB_LIMIT:return {"error":"Invalid NWSync resource identity"}
	if pending_blobs.has(hash):return await pending_blobs[hash].wait_result()
	var pending:=PendingResult.new()
	pending_blobs[hash]=pending
	var result: Dictionary=await load_blob(store,entry)
	if closed:result={"error":"Server content loading was cancelled"}
	pending.finish(result)
	pending_blobs.erase(hash)
	return result

func load_blob(store: RefCounted,entry: Dictionary)->Dictionary:
	var hash:=str(entry.get("hash",""))
	var size:=int(entry.get("size",-1))
	var cached: Dictionary=read_cache("objects",hash,BLOB_LIMIT)
	if cached.has("error"):return cached
	if cached.present:
		var decoded: Dictionary=Store.decode_blob(cached.bytes,hash,size)
		if not decoded.has("error"):return decoded
		report_diagnostic("network.nwsync-cache-corrupt","Cached server content failed verification",{"hash":hash})
	var native_available: bool=store.has_native_source()
	var local: Dictionary=store.resource(entry)
	if native_available and not store.has_native_source():
		report_diagnostic("network.nwsync-native-cache-failed","Installed NWSync content could not be read or verified")
	if not local.has("error"):return local
	return await repair_failed_blob(store,entry)
func repair_failed_blob(_store: RefCounted,entry: Dictionary)->Dictionary:
	# Called on the main thread only after a worker has verified a source read
	# failure. Avoid repeating the failed disk/helper read on the frame thread.
	var hash:=str(entry.get("hash",""))
	var size:=int(entry.get("size",-1))
	if not Store.valid_hash(hash) or size < -1 or size>BLOB_LIMIT:return {"error":"Invalid NWSync resource identity"}
	if base_url.is_empty():return {"error":"Required NWSync content is not cached and no repository is available"}
	var fetched: Dictionary=await fetch("data/sha1/"+hash.substr(0,2)+"/"+hash.substr(2,2)+"/"+hash,BLOB_LIMIT)
	if fetched.has("error"):return fetched
	var decoded: Dictionary=Store.decode_blob(fetched.bytes,hash,size)
	if decoded.has("error"):return decoded
	if not save_verified("objects",hash,fetched.bytes):return {"error":"Verified NWSync blob could not be cached"}
	return decoded

func download_worker(store: RefCounted,entries: Array,state: Dictionary,manifest: String,available: Dictionary)->void:
	while not closed and str(state.error).is_empty() and int(state.next)<entries.size():
		var index:=int(state.next)
		state.next=index+1
		var entry: Dictionary=entries[index]
		var hash:=str(entry.get("hash",""))
		if not available.has(hash):
			var blob: Dictionary=await ensure_blob(store,entry)
			if blob.has("error"):
				state.error=str(blob.error)
				break
			available[hash]=true
		state.completed=int(state.completed)+1
		publish_progress("server-content",int(state.completed),entries.size(),manifest)
	state.workers=int(state.workers)-1
	if int(state.workers)==0:downloads_finished.emit()

func download_entries(store: RefCounted,entries: Array,manifest: String="",available: Dictionary={})->Dictionary:
	if download_batch_active:return {"error":"NWSync download batch is already active"}
	if entries.is_empty():publish_progress("server-content",0,0,manifest,true);return {"completed":0}
	download_batch_active=true
	var workers:=mini(concurrency,entries.size())
	var state: Dictionary={"next":0,"completed":0,"workers":workers,"error":""}
	publish_progress("server-content",0,entries.size(),manifest,true)
	for _index in range(workers):download_worker.call_deferred(store,entries,state,manifest,available)
	await downloads_finished
	download_batch_active=false
	if closed:return {"error":"NWSync repository was cancelled"}
	if not str(state.error).is_empty():return {"error":state.error}
	publish_progress("server-content",int(state.completed),entries.size(),manifest,true)
	return {"completed":state.completed}

func ensure_requirements(store: RefCounted,requirements: Dictionary,language: int,roots: Array[String]=[],mods_directory: String="",disabled_mods: Array=[])->Dictionary:
	var selected: Dictionary=Admission.manifest_hashes(requirements,language)
	var advertisement: Variant=requirements.get("advertisement")
	if advertisement is Dictionary:
		for entry in advertisement.get("manifests",[]):
			if not entry is Dictionary or int(entry.get("language",-1)) not in [255,language]:continue
			if entry.get("hash") is String and not str(entry.hash).is_empty():continue
			if (int(entry.get("flags",0))&1)==0:report_diagnostic("network.resource-invalid","Additional NWSync manifest hash is empty or invalid",{"required":false})
	var catalogs: Array[Dictionary]=[]
	var failed_required_manifests: Array[Dictionary]=[]
	var unavailable_manifests: Array[String]=[]
	var available: Dictionary={}
	var inventory_loaded:=false
	for row in selected.manifests:
		if closed:return {"error":"NWSync repository was cancelled"}
		var catalog: Dictionary=await ensure_manifest(store,str(row.hash))
		if catalog.has("error"):
			if str(row.hash) not in unavailable_manifests:unavailable_manifests.append(str(row.hash))
			report_diagnostic("network.resource-resolution-failed","Server resource lookup failed",{"kind":"nwsync","name":str(row.hash),"required":bool(row.required)})
			if not row.required:report_diagnostic("network.resource-unavailable","Optional server resource is unavailable",{"kind":"nwsync","name":str(row.hash),"required":false})
			else:failed_required_manifests.append({"kind":"nwsync","name":str(row.hash)})
			continue
		unavailable_manifests.erase(str(row.hash))
		catalogs.append(catalog)
		if not inventory_loaded:
			var inventory: Dictionary=store.available_blob_hashes()
			if inventory.has("error"):
				# Installed storage is optional. Suppress further native reads and
				# keep the local content-addressed inventory.
				store.mark_native_failed()
				report_diagnostic("network.nwsync-native-cache-failed","Installed NWSync resource inventory could not be read")
				inventory={"hashes":store.local_blob_hashes()}
			available=inventory.hashes
			inventory_loaded=true
		var unique_entries: Dictionary={}
		for entry in catalog.entries.values():
			var hash:=str(entry.get("hash",""))
			unique_entries[hash]=entry
		var downloaded: Dictionary=await download_entries(store,unique_entries.values(),str(row.hash),available)
		if downloaded.has("error"):
			if closed:return downloaded
			if str(row.hash) not in unavailable_manifests:unavailable_manifests.append(str(row.hash))
			report_diagnostic("network.resource-resolution-failed","Server resource lookup failed",{"kind":"nwsync","name":str(row.hash),"required":bool(row.required)})
			if not row.required:report_diagnostic("network.resource-unavailable","Optional server resource is unavailable",{"kind":"nwsync","name":str(row.hash),"required":false})
			else:failed_required_manifests.append({"kind":"nwsync","name":str(row.hash)})
	var resolved: Dictionary=Admission.resolve_cached(requirements,store,language,roots,mods_directory,disabled_mods,Callable(self,"report_diagnostic"),unavailable_manifests)
	if not resolved.has("repair"):
		if not resolved.has("error"):
			for failed in failed_required_manifests:
				if not resolved.missing.has(failed):resolved.missing.append(failed)
			if not failed_required_manifests.is_empty():resolved.ready=false
		report_resource_result(resolved)
		return resolved
	# A custom TLK may be nested inside a selected NWSync NWM/HAK. Admission
	# probes only that selected archive. Repair its failed verified read on this
	# main-thread async path, then resolve the same requirements exactly once.
	var repair: Dictionary=resolved.repair
	if repair.get("store")!=store or not (repair.get("entry") is Dictionary):
		return {"error":"Invalid NWSync admission repair source"}
	var fixed: Dictionary=await repair_failed_blob(store,repair.entry)
	if fixed.has("error"):return fixed
	if closed:return {"error":"NWSync repository was cancelled"}
	var repaired: Dictionary=Admission.resolve_cached(requirements,store,language,roots,mods_directory,disabled_mods,Callable(self,"report_diagnostic"),unavailable_manifests)
	if not repaired.has("error"):
		for failed in failed_required_manifests:
			if not repaired.missing.has(failed):repaired.missing.append(failed)
		if not failed_required_manifests.is_empty():repaired.ready=false
	report_resource_result(repaired)
	return repaired

func close()->void:
	if closed:return
	closed=true
	for client in active_clients.duplicate():client.close()
	active_clients.clear()
	for waiter in transfer_frames.duplicate():waiter.wake()
