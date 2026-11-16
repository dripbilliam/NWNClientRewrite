extends SceneTree
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Repository=preload("res://systems/native_data/native_nwsync_repository.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
var repository: Node
var requirements: Dictionary={}

func _initialize()->void:
	var record:=FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://.cache/nwn79/arelith-resource-record.bin"))
	var decoded: Dictionary=Requirements.decode_record(record)
	if decoded.has("error"):fail("Server resource fixture is unavailable");return
	requirements=decoded
	var advertisement: Dictionary=decoded.advertisement
	var folder:=ProjectSettings.globalize_path("res://.cache/nwn79/repository-test")
	repository=Repository.new()
	root.add_child(repository)
	if not repository.configure(advertisement.url,folder):fail("Repository URL validation failed");return
	if repository.configure("file:///private",folder) or repository.configure("http://user@server/path",folder):fail("Unsafe repository URL was accepted");return
	verify.call_deferred(str(advertisement.hash))

func verify(hash: String)->void:
	var store:=Store.new()
	if not store.configure(repository.cache_directory):fail("Private cache configuration failed");return
	var decoded: Dictionary=await repository.ensure_manifest(store,hash)
	if decoded.has("error") or decoded.entries.size()<1:fail("Downloaded manifest differs from advertised digest");return
	var cached: Dictionary=store.manifest(hash)
	if cached.has("error") or cached.entries.size()!=decoded.entries.size():fail("Verified manifest was not cached");return
	var path: String=str(repository.cache_directory).path_join("manifests").path_join(hash)
	var corrupt:=FileAccess.open(path,FileAccess.WRITE)
	if corrupt==null:fail("Private repair fixture could not be opened");return
	corrupt.store_8(0);corrupt.close()
	var repaired: Dictionary=await repository.ensure_manifest(store,hash)
	if repaired.has("error") or store.manifest(hash).has("error"):fail("Corrupt private manifest was not repaired");return
	var sample: Dictionary={}
	for entry in decoded.entries.values():
		if int(entry.get("size",-1))>0 and int(entry.size)<65536:
			sample=entry;break
	if sample.is_empty():fail("No small NWSync fixture entry");return
	var blob: Dictionary=await repository.ensure_blob(store,sample)
	if blob.has("error") or blob.bytes.size()!=int(sample.size):fail("Downloaded NWSync blob did not verify: "+str(blob.get("error","size")));return
	var cached_blob: Dictionary=store.resource(sample)
	if cached_blob.has("error") or cached_blob.bytes!=blob.bytes:fail("Verified NWSync blob was not cached");return
	var object_path: String=ProjectSettings.globalize_path("res://.cache/nwn79/repository-test/objects").path_join(str(sample.hash))
	var corrupt_blob:=FileAccess.open(object_path,FileAccess.WRITE)
	if corrupt_blob==null:fail("Private blob repair fixture could not be opened");return
	corrupt_blob.store_8(0);corrupt_blob.close()
	var repaired_blob: Dictionary=await repository.ensure_blob(store,sample)
	if repaired_blob.has("error") or store.resource(sample).has("error"):fail("Corrupt private blob was not repaired");return
	var batch: Array=[]
	for entry in decoded.entries.values():
		var size:=int(entry.get("size",-1))
		if size>0 and size<65536 and str(entry.hash)!=str(sample.hash) and not FileAccess.file_exists(str(repository.cache_directory).path_join("objects").path_join(str(entry.hash))):
			batch.append(entry)
			if batch.size()==3:break
	if batch.size()!=3:fail("No parallel NWSync blob fixtures");return
	var downloaded: Dictionary=await repository.download_entries(store,batch)
	if downloaded.has("error") or int(downloaded.get("completed",0))!=3:fail("Parallel NWSync downloads failed");return
	for entry in batch:
		if store.resource(entry).has("error"):fail("Parallel NWSync blob did not cache");return
	var documents:=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var profile:=documents.path_join("Neverwinter Nights.0")
	var installed:=Store.new()
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	var installed_cache:=profile.path_join("replacement-client/server-content")
	if not installed.configure(installed_cache,profile.path_join("nwsync"),helper):fail("Installed NWSync reader unavailable");return
	if not repository.configure(str(requirements.advertisement.url),installed_cache):fail("Installed repository configuration failed");return
	var roots: Array[String]=[profile]
	var resolved: Dictionary=await repository.ensure_requirements(installed,requirements,0,roots)
	if resolved.has("error") or not resolved.get("ready",false):fail("Godot resource orchestration did not admit installed content");return
	installed.close()
	print("NWN79 Godot NWSync repository fetch/cache/admission PASS: entries=",decoded.entries.size()," blob_bytes=",blob.bytes.size())
	store.close()
	repository.close();quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot NWSync repository failed: "+reason)
	if repository!=null:repository.close()
	quit(1)
