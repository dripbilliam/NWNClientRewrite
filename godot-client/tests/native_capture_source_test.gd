extends SceneTree
const Catalog=preload("res://systems/native_data/capture_catalog.gd")
const Setup=preload("res://systems/native_data/capture_setup.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func json(path: String,value: Dictionary) -> void: write(path,JSON.stringify(value).to_utf8_buffer())
func blob(directory: String,bytes: PackedByteArray) -> void:
	var encoded:="NSYC".to_ascii_buffer(); encoded.resize(16); encoded.encode_u32(4,3); encoded.encode_u32(8,0); encoded.encode_u32(12,bytes.size()); encoded.append_array(bytes)
	write(directory.path_join("objects").path_join(Store.sha1(bytes)),encoded)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var directory:=OS.get_temp_dir().path_join("nwn-native-source-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); var cache_path:=directory.path_join("cache"); var capture_path:=directory.path_join("capture")
	var model:="Authored model identity binding".to_utf8_buffer(); var events:="Authored capture events".to_utf8_buffer()
	var raster:=PackedByteArray(); raster.resize(22); raster[2]=2; raster.encode_u16(12,1); raster.encode_u16(14,1); raster[16]=32; raster[18]=50; raster[19]=100; raster[20]=200; raster[21]=255
	write(capture_path.path_join("events.bin"),events); write(capture_path.path_join("objects").path_join(Cache.digest(model)),model)
	var captured_manifest:={"version":1,"complete":true,"eventsSha256":Cache.digest(events),"contexts":{"context-1":{"resources":{"bound_model:2002":{"sha256":Cache.digest(model),"bytes":model.size()},"present:3":{"sha256":Cache.digest(raster),"bytes":raster.size()}},"textures":{"recorded_missing":null,"present":3}}}}
	write(capture_path.path_join("objects").path_join(Cache.digest(raster)),raster); json(capture_path.path_join("manifest.json"),captured_manifest)
	var rows: Array=[["bound_model",2002,model],["new_texture",3,raster],["recorded_missing",3,raster],["present",3,raster]]
	var raw:="NSYM".to_ascii_buffer(); raw.resize(16+rows.size()*42); raw.encode_u32(4,3); raw.encode_u32(8,rows.size())
	for index in rows.size():
		var row: Array=rows[index]; var at:=16+index*42; var bytes: PackedByteArray=row[2]
		var sha:=Store.sha1(bytes).hex_decode()
		for j in 20: raw[at+j]=sha[j]
		raw.encode_u32(at+20,bytes.size()); var name: PackedByteArray=str(row[0]).to_ascii_buffer()
		for j in name.size(): raw[at+24+j]=name[j]
		raw.encode_u16(at+40,int(row[1])); blob(cache_path,bytes)
	var manifest_hash:=Store.sha1(raw); write(cache_path.path_join("manifests").path_join(manifest_hash),raw)
	var source:={"version":1,"eventsSha256":Cache.digest(events),"context":"context-1","source":{"manifest":manifest_hash,"cacheDirectory":cache_path},"bindings":[{"name":"bound_model","type":2002,"sha1":Store.sha1(model),"sha256":Cache.digest(model)}],"rasters":[{"name":"new_texture","type":3,"sha1":Store.sha1(raster)},{"name":"recorded_missing","type":3,"sha1":Store.sha1(raster)},{"name":"present","type":3,"sha1":Store.sha1(raster)}]}
	var catalog:=Catalog.new(); check(catalog.mount(capture_path,"context-1"),"Authored capture mounts")
	check(not catalog.has_resource("new_texture",3),"Recording gap is initially unavailable")
	check(catalog.mount_cached_source(source),"Pinned native cached source mounts: "+catalog.failure)
	check(catalog.has_resource("NEW_TEXTURE",3) and catalog.get_resource("new_texture",3)==raster and catalog.failure.is_empty(),"Exact cached raw bytes fill recording gap")
	check(catalog.raster_location("new_texture")=={"name":"new_texture","type":3},"Pinned original raster choice is discoverable")
	check(not catalog.has_resource("recorded_missing",3) and catalog.raster_location("recorded_missing").is_empty() and catalog.get_resource("recorded_missing",3).is_empty(),"Recorded texture miss stays authoritative, including explicit raw lookup")
	check(catalog.get_resource("present",3)==raster and catalog.location("present",3).root==capture_path,"Recorded resource has priority over cached source")
	check(not catalog.resource_names(3).has("recorded_missing") and catalog.resource_names(3).has("new_texture"),"Resource enumeration preserves misses and fills only allowed keys")
	check(catalog.get_resource("unlisted",3).is_empty() and not catalog.failure.is_empty(),"Unlisted cache resources remain unavailable")
	var fork=catalog.fork(); check(fork.get_resource("new_texture",3)==raster,"Worker fork shares pinned source with private read result")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var delivered: Dictionary={}; assets.completed.connect(func(id,result):delivered[id]=result)
	for index in 8: check(assets.request("new_texture",3,"raster")>0,"Native raster worker queues "+str(index))
	var deadline:=Time.get_ticks_msec()+10000
	while delivered.size()<8 and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==8 and delivered.values().all(func(value):return str(value.error).is_empty() and value.thread!=OS.get_main_thread_id()),"Concurrent native source reads and raster decode stay on workers")
	assets.close(); assets.queue_free(); await process_frame
	for mutation in ["eventsSha256","context","bindings","binding_sha256","raster_sha1","nativeDirectory","path"]:
		var bad:=source.duplicate(true)
		match mutation:
			"eventsSha256": bad.eventsSha256="0".repeat(64)
			"context": bad.context="other"
			"bindings": bad.bindings=[]
			"binding_sha256": bad.bindings[0].sha256="0".repeat(64)
			"raster_sha1": bad.rasters[0].sha1="0".repeat(40)
			"nativeDirectory": bad.source.nativeDirectory="relative"
			"path": bad.rasters[0].name="../new_texture"
		check(not catalog.mount_cached_source(bad),"Invalid source descriptor rejects "+mutation)
		check(catalog.get_resource("new_texture",3)==raster,"Failed source replacement leaves prior scope usable "+mutation)
	var path:=directory.path_join("source.json"); json(path,source); var source_sha:=FileAccess.get_sha256(path)
	var input:={"capture":capture_path,"context":"context-1","supplements":[],"eventsSha256":Cache.digest(events)}; var setup:=Setup.new(); root.add_child(setup); var ready: Dictionary={}
	setup.completed.connect(func(value,error,stats):ready.merge({"catalog":value,"error":error,"stats":stats}))
	setup.start(input,path,source_sha); deadline=Time.get_ticks_msec()+10000
	while ready.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not ready.is_empty() and ready.error.is_empty() and ready.stats.worker_thread!=OS.get_main_thread_id(),"Capture and source verification run on a native worker")
	if ready.has("catalog"): ready.catalog.close_sources()
	ready.clear(); setup.start(input,path,"0".repeat(64)); deadline=Time.get_ticks_msec()+10000
	while ready.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not ready.is_empty() and not ready.error.is_empty(),"Changed source descriptor checksum rejects")
	ready.clear(); setup.start(input,path,source_sha); setup.close(); await process_frame
	check(ready.is_empty() and setup.task==-1,"Retired catalog setup cannot publish stale result")
	setup.queue_free(); catalog.close_sources(); fork=null; await process_frame
	var installed: Dictionary={}
	if args.has("source"):
		var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-capture-input-v1.json")); var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baseline.input)); var source_descriptor: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.source)); var reader:=Catalog.new()
		check(reader.mount(original.capture,original.context,original.supplements),"Actual sealed capture mounts")
		check(reader.mount_cached_source(source_descriptor),"Actual cached source verifies exact captured model identity: "+reader.failure)
		if reader.source_cache!=null:
			var bytes:=reader.get_resource("ait_mscmedp_008",2033)
			check(reader.failure.is_empty() and Store.sha1(bytes)==source_descriptor.rasters[0].sha1,"Actual original missing DDS verifies by pinned SHA1")
			installed={"source":reader.source_cache.evidence.duplicate(true),"bytes":bytes.size(),"sha256":Cache.digest(bytes)}
			var helper_pid:=int(reader.source_cache.store.reader.child.pid); var actual_assets:=Assets.new(); root.add_child(actual_assets); actual_assets.configure(reader); var model_result: Dictionary={}
			actual_assets.completed.connect(func(_id,value):model_result.merge(value)); check(actual_assets.request("it_mscmedp_008",2002,"actor-model",{"relevant_tracks":true})>0,"Actual original ground-item preparation queues")
			deadline=Time.get_ticks_msec()+30000
			while model_result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
			check(not model_result.is_empty() and str(model_result.get("error","unfinished")).is_empty() and model_result.get("textures",{}).has("ait_mscmedp_008"),"Actual ground item prepares natively with its original texture")
			if model_result.has("textures"): installed.texture=model_result.textures.get("ait_mscmedp_008",{}).get("sha256","")
			actual_assets.close(); actual_assets.queue_free(); reader.close_sources(); check(not OS.is_process_running(helper_pid),"Owned read-only SQLite helper retires after native asset workers")
	await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"installed":installed,"network_connections":0,"rendering_prepared_by_js":false,"scope":"Pinned cached raw source fills only unrecorded capture gaps, exact captured model binding, worker read/prep and cleanup; no original-client pixels/full-world/performance acceptance"},"\t")); file.close(); print("NATIVE_CAPTURE_SOURCE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
