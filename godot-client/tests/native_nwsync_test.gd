extends SceneTree
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Reader=preload("res://systems/native_data/nwsync_reader.gd")
const PreworkSources=preload("res://systems/native_data/prework_sources.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var raw:=FileAccess.get_file_as_bytes(str(fixture.root).path_join("raw"))
	var manifest:=FileAccess.get_file_as_bytes(str(fixture.cache).path_join("manifests").path_join(fixture.hash))
	var decoded:=Store.decode_manifest(manifest,fixture.hash)
	check(not decoded.has("error") and decoded.entries.size()==3,"Native manifest and alias decode")
	check(decoded.entries.has("generic:0"),"Type-zero entries do not reject an entire real catalog")
	check(decoded.entries.has("native_table :2017"),"Trailing ResRef space is retained")
	check(decoded.entries["alias:2017"].hash==fixture.resource,"Alias uses base identity")
	for offset in [0,4,8,12,16,40,58]:
		var bad:=manifest.duplicate(); bad[offset]^=255
		check(Store.decode_manifest(bad,fixture.hash).has("error"),"Manifest digest rejects mutation at "+str(offset))
	var duplicate:=manifest.duplicate(); duplicate[62]=110 # alias ref, then replace full name
	for index in 16: duplicate[62+index]=manifest[40+index]
	check(Store.decode_manifest(duplicate,Store.sha1(duplicate)).has("error"),"Duplicate references rejected with correct digest")
	var invalid_alias:=manifest.duplicate(); invalid_alias.encode_u32(58,1)
	check(Store.decode_manifest(invalid_alias,Store.sha1(invalid_alias)).has("error"),"Alias must refer to original base entry")
	for algorithm in [0,1,2]:
		var encoded: PackedByteArray
		if algorithm==2:
			encoded="NSYC".to_ascii_buffer(); encoded.resize(24); encoded.encode_u32(4,3); encoded.encode_u32(8,2); encoded.encode_u32(12,raw.size()); encoded.encode_u32(16,1); encoded.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
		else: encoded=FileAccess.get_file_as_bytes(str(fixture.root).path_join("blob"+str(algorithm)))
		var result:=Store.decode_blob(encoded,fixture.resource,int(fixture.bytes))
		check(not result.has("error") and result.bytes==raw,"Native decompression algorithm "+str(algorithm))
		check(Store.decode_blob(encoded,"0".repeat(40)).has("error"),"Decompressed bytes must match SHA1")
		check(Store.decode_blob(encoded,fixture.resource,int(fixture.bytes)+1).has("error"),"Declared size must match")
	var bad_blob:=FileAccess.get_file_as_bytes(str(fixture.root).path_join("blob0")); bad_blob.encode_u32(8,999)
	check(Store.decode_blob(bad_blob,fixture.resource).has("error"),"Unknown algorithm rejected")
	check(Store.decode_blob(raw,fixture.resource).has("error"),"File cache requires NSYC wrapper")
	check(Store.decode_blob(raw,fixture.resource,-1,true).bytes==raw,"Installed raw storage is digest verified")
	var catalog:=Catalog.new()
	check(catalog.mount_nwsync(fixture.hash,fixture.cache),"Native file-cache catalog mount")
	check(catalog.get_resource("ALIAS",2017)==raw and catalog.failure.is_empty(),"Native catalog returns original decoded bytes")
	check(catalog.fork().get_resource("native_table ",2017)==raw,"Worker catalog forks retain native content")
	check(not catalog.mount_nwsync("../bad",fixture.cache) and catalog.layers.size()==1,"Failed mount is atomic and hash cannot become a path")
	var installed:=Catalog.new(); var helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	check(installed.mount_nwsync(fixture.hash,str(fixture.root).path_join("empty-cache"),fixture.installed,helper),"Native read-only SQLite manifest mount")
	if not installed.layers.is_empty():
		check(installed.get_resource("alias",2017)==raw and installed.failure.is_empty(),"Native SQLite blob decode")
		check(installed.get_resource("generic",0)==raw,"SQLite helper retains type-zero entry")
		var tasks: Array=[]; var worker_results: Dictionary={}; var mutex:=Mutex.new()
		for index in 8:
			var fork=installed.fork()
			tasks.append(WorkerThreadPool.add_task(func():
				var result: PackedByteArray=fork.get_resource("alias",2017)
				mutex.lock(); worker_results[index]=result==raw and fork.failure.is_empty(); mutex.unlock()))
		for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
		check(worker_results.size()==8 and worker_results.values().all(func(value):return value),"Eight native workers share bounded independent SQLite readers safely")
		var assets:=Assets.new(); root.add_child(assets); assets.configure(installed)
		var received: Dictionary={}; assets.completed.connect(func(id: int, result: Dictionary): received[id]=result)
		var id:=assets.request("alias",2017,"2da")
		var deadline:=Time.get_ticks_msec()+10000; var result: Dictionary={}
		while Time.get_ticks_msec()<deadline:
			await process_frame
			result=received.get(id,{})
			if not result.is_empty(): break
		check(not result.is_empty() and str(result.get("error","missing")).is_empty() and result.value.rows.size()==2,"Asset worker decodes SQLite 2DA entirely natively")
		assets.close(); assets.queue_free()
		var store=installed.layers[0].store; var pids: Array=[]
		for child in store.readers: pids.append(int(child.child.get("pid",-1)))
		check(pids.size()>=1 and pids.size()<=store.maximum_readers,"Installed reader pool respects its process bound")
		store.close()
		check(pids.all(func(pid):return pid>0 and not OS.is_process_running(pid)),"Every owned native cache helper retires")
	var detached=Reader.new()
	check(detached.open(helper,fixture.installed),"Owned helper opens for destructor cleanup check")
	var listed:=detached.request(5,PackedByteArray())
	var manifests:=PreworkSources.decode_inventory(listed.get("bytes",PackedByteArray()))
	check(manifests.size()==1 and str(manifests[0].hash)==str(fixture.hash),"Read-only manifest inventory discovers downloaded content without a server connection")
	check(PreworkSources.decode_inventory(PackedByteArray([255,255,255,255])).is_empty(),"Malformed offline manifest inventories are rejected")
	var options:=PreworkSources.discover({"install":str(fixture.root),"cacheDirectory":fixture.cache,"nativeDirectory":fixture.installed,"helper":helper})
	check(options.choices.size()==2 and options.choices[1].sources.nwsync.size()==1,"Native and file caches deduplicate the same manifest into one isolated prework source")
	var detached_pid:=int(detached.child.get("pid",-1)); detached=null
	var cleanup_deadline:=Time.get_ticks_msec()+2000
	while detached_pid>0 and OS.is_process_running(detached_pid) and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	check(detached_pid>0 and not OS.is_process_running(detached_pid),"Abandoned reader closes its own helper without script-dispatch errors")
	await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"js_rendering":false}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
