extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Archive=preload("res://systems/native_data/archive_index.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const NWSync=preload("res://systems/native_data/nwsync_store.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func erf(path: String,rows: Array) -> void:
	var at:=160+rows.size()*32; var bytes:="HAK V1.0".to_ascii_buffer(); bytes.resize(at)
	bytes.encode_u32(16,rows.size()); bytes.encode_u32(24,160); bytes.encode_u32(28,160+rows.size()*24)
	for index in rows.size():
		var row: Array=rows[index]; var name: PackedByteArray=str(row[0]).to_ascii_buffer()
		for offset in mini(16,name.size()): bytes[160+index*24+offset]=name[offset]
		bytes.encode_u16(180+index*24,int(row[1])); bytes.encode_u32(160+rows.size()*24+index*8,at); bytes.encode_u32(164+rows.size()*24+index*8,row[2].size())
		bytes.append_array(row[2]); at+=row[2].size()
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-residency-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	var path:=folder.path_join("all.hak"); var rows: Array=[]
	for type in [2002,3,2033,4,2017,2047,2013,2022,2060,2018,2074]: rows.append(["asset"+str(type),type,("exact source "+str(type)).to_utf8_buffer()])
	erf(path,rows)
	var first:=Archive.new(); var first_index:=first.erf(path)
	check(first.failure.is_empty() and not first.index_cache_hit and first_index.entries.size()==rows.size(),"First archive parses its exact original table")
	var second:=Archive.new(); var second_index:=second.erf(path)
	check(second.failure.is_empty() and second.index_cache_hit and second_index==first_index,"Another archive owner reuses the complete resident table")
	check(second_index.is_read_only() and second_index.entries.is_read_only() and second_index.entries["asset2002:2002"].is_read_only(),"Shared index metadata is recursively immutable rather than caller-editable")
	var original:=Catalog.new(); check(original.mount_erf(path),"Original resource owner mounts")
	var next:=Catalog.new(); check(next.mount_erf(path),"Independent resource owner mounts the same content")
	var first_bindings:=original.build_resource_index(); var reused_bindings:=next.build_resource_index()
	check(not first_bindings.residency_hit and reused_bindings.residency_hit and next.resolved.is_read_only(),"Unchanged ordered resource layers reuse a complete immutable lookup map")
	for row in rows: check(original.get_resource(row[0],row[1])==row[2] and next.get_resource(row[0],row[1])==row[2],"Shared indexing retains exact bytes across catalogs for type "+str(row[1]))
	var override_path:=folder.path_join("override.hak"); erf(override_path,[["asset2002",2002,"server model".to_utf8_buffer()]])
	check(next.mount_erf(override_path,100) and next.get_resource("asset2002",2002).get_string_from_utf8()=="server model" and original.get_resource("asset2002",2002)==rows[0][2],"Different server precedence never shares a resref binding or overwrites another catalog")
	check(not next.build_resource_index().residency_hit,"An added server layer cannot reuse the old lookup map")
	var reversed:=Catalog.new(); reversed.mount_erf(override_path,100); reversed.mount_erf(path,200)
	check(not reversed.build_resource_index().residency_hit and reversed.get_resource("asset2002",2002)==rows[0][2],"Changed layer order selects another map and the correct resource winner")
	var loose_path:=folder.path_join("latest.2da"); var loose_file:=FileAccess.open(loose_path,FileAccess.WRITE); loose_file.store_string("before demand"); loose_file.close()
	var loose:=Catalog.new(); check(loose.mount_directory(folder),"Loose resource names mount without eager file metadata")
	loose_file=FileAccess.open(loose_path,FileAccess.WRITE); loose_file.store_string("latest source bytes"); loose_file.close()
	check(loose.get_resource("latest",2017).get_string_from_utf8()=="latest source bytes","First resource demand reads current bytes rather than rejecting a pre-demand source update")
	DirAccess.remove_absolute(loose_path)
	var refreshed:=Catalog.new(); refreshed.mount_directory(folder)
	check(not refreshed.has_resource("latest",2017),"A changed directory listing invalidates retained filename bindings")
	var file:=FileAccess.open(path,FileAccess.READ_WRITE); file.seek(160); file.store_buffer("other2002".to_ascii_buffer()); file.close()
	var edited:=Archive.new(); var changed:=edited.erf(path)
	check(edited.failure.is_empty() and not edited.index_cache_hit and changed.entries.has("other2002:2002") and not changed.entries.has("asset2002:2002"),"Same-length index edits are detected by actual bytes, including within one timestamp second")
	var workers: Array=[]; var mutex:=Mutex.new(); var calls:={"count":0}; var release:=Semaphore.new(); var returned: Array=[]
	var before: int=Residency.indexes.snapshot().coalesced
	for index in 2:
		workers.append(WorkerThreadPool.add_task(func():
			var value:=Residency.index("concurrent",[folder],["shared index".to_ascii_buffer()],func():
				mutex.lock(); calls.count+=1; mutex.unlock(); release.wait()
				return {"value":{"entries":{"same:2002":{"offset":0}}},"error":""})
			mutex.lock(); returned.append(value); mutex.unlock()))
	var deadline:=Time.get_ticks_msec()+5000
	while int(Residency.indexes.snapshot().coalesced)-before<1 and Time.get_ticks_msec()<deadline: await process_frame
	var joined:=int(Residency.indexes.snapshot().coalesced)-before
	release.post()
	for task in workers: WorkerThreadPool.wait_for_task_completion(task)
	check(joined==1 and calls.count==1 and returned.size()==2 and returned.all(func(value):return value.value.entries.has("same:2002")),"Concurrent owners coalesce one immutable index parse and wake every waiter")
	var bad:=Residency.index("retry",[folder],[],func():return {"value":{},"error":"authored read failure"})
	var retry:=Residency.index("retry",[folder],[],func():return {"value":{"entries":{"repaired:4":{}}},"error":""})
	check(bad.error=="authored read failure" and not retry.cache_hit and retry.error.is_empty() and Residency.indexes.snapshot().inflight==0,"Failures wake their waiters without persisting or poisoning a later read")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(original)
	var table:="2DA V2.0\n\nName\n0 123\n".to_ascii_buffer()
	var decoded: Dictionary=assets.decode(table,2017,"2da","",original.decoded_cache(),true)
	var reused: Dictionary=assets.decode(table,2017,"2da","",next.decoded_cache(),true)
	check(not decoded.memory_decode_hit and reused.memory_decode_hit and reused.value==decoded.value,"Separate catalogs reuse content-identical decoded rules")
	var private_copy: Dictionary=assets.decode(table,2017,"2da","",next.decoded_cache()); private_copy.value.orderedRows[0].Name="changed"
	var intact: Dictionary=assets.decode(table,2017,"2da","",original.decoded_cache(),true)
	check(intact.value.orderedRows[0].Name=="123","Mutable consumers cannot overwrite the retained immutable definition")
	next.reset(); var retained: Dictionary=assets.decode(table,2017,"2da","",next.decoded_cache(),true)
	var different: Dictionary=assets.decode("2DA V2.0\n\nName\n0 456\n".to_ascii_buffer(),2017,"2da","",next.decoded_cache(),true)
	check(retained.memory_decode_hit and not different.memory_decode_hit and different.value.orderedRows[0].Name=="456","Catalog reset keeps unchanged sources while changed server bytes select another decoded entry")
	var object_dir:=folder.path_join("objects"); DirAccess.make_dir_recursive_absolute(object_dir)
	var raw:="a verified resource of any type".to_utf8_buffer(); var hash:=NWSync.sha1(raw); var blob:="NSYC".to_ascii_buffer(); blob.resize(16); blob.encode_u32(4,3); blob.encode_u32(12,raw.size()); blob.append_array(raw)
	var object_path:=object_dir.path_join(hash); file=FileAccess.open(object_path,FileAccess.WRITE); file.store_buffer(blob); file.close()
	var store:=NWSync.new(); check(store.configure(folder),"Authored offline NWSync source opens")
	var entry:={"hash":hash,"size":raw.size()}; var cold:=store.resource(entry)
	check(not cold.has("error") and cold.bytes==raw,"The initial NWSync demand returns the verified source bytes")
	var cold_buffer: PackedByteArray=cold.bytes; cold_buffer[0]=0
	store.close(); DirAccess.remove_absolute(object_path)
	var another:=NWSync.new(); another.configure(folder); var warm:=another.resource(entry)
	check(not cold.has("error") and not warm.has("error") and warm.bytes==raw and warm.timings.memory_source_hit,"Verified NWSync bytes survive source-owner disposal and bypass disk/decompression by content identity")
	var altered: PackedByteArray=warm.bytes; altered[0]=0
	check(another.resource(entry).bytes==raw and another.resource({"hash":hash,"size":raw.size()+1}).has("error"),"Resident packed bytes preserve private buffer isolation and enforce the requesting manifest's length")
	check(another.resource({"hash":"0".repeat(40),"size":raw.size()}).has("error"),"A different unavailable content identity never returns cached bytes by name or length")
	another.close(); assets.close(); assets.free()
	for owned in [path,override_path]: DirAccess.remove_absolute(owned)
	DirAccess.remove_absolute(object_dir); check(DirAccess.remove_absolute(folder)==OK,"The fixture removes only its exact authored files and empty directories")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"residency":Residency.snapshot(),"publicConnections":0,"scope":"Shared immutable archive indexes, all sampled resource types, active layer precedence, exact table-byte invalidation, coalesced owners, decoded-source isolation and verified NWSync memory residency. No game-server or FPS claim."}
	file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
