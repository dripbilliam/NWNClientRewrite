extends "res://tests/native_actor_visual_failure_test.gd"
const Service=preload("res://systems/native_data/asset_service.gd")
const Ancestors=preload("res://systems/native_data/ancestor_preparation.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
class SlowSource:
	extends RefCounted
	func decode(_bytes: PackedByteArray,_type: int,_decoder: String,_cache_path: String,_store) -> Dictionary:
		OS.delay_msec(25); return {"error":"Authored returned decode failure","timings":{}}
class SlowService:
	extends Service
	func decode(bytes: PackedByteArray,type: int,decoder: String,cache_path: String,store=null,immutable_source: bool=false) -> Dictionary:
		if decoder=="mdl-actor-packed-v3" and bytes.get_string_from_ascii().begins_with("newmodel grandparent"): OS.delay_msec(80)
		return super.decode(bytes,type,decoder,cache_path,store,immutable_source)
func authored(name: String,parent: String="") -> String:
	return model().replace("authored",name).replace("beginmodelgeom",("setsupermodel "+name+" "+parent+"\n" if not parent.is_empty() else "")+"beginmodelgeom")
func prepare(catalog,name: String,enabled: bool,selected: Variant={}) -> Dictionary:
	var service:=Service.new(); root.add_child(service); service.set_process(false); service.high_priority=true; service.ancestor_preparation_enabled=enabled
	var reader=catalog.fork(); var bytes: PackedByteArray=reader.get_resource(name,2002); var began:=Time.get_ticks_usec()
	var result:=service.actor_data(reader,name,bytes,"",[],selected); result.test_elapsed_ms=(Time.get_ticks_usec()-began)/1000.0
	service.close(); service.free(); return result
func compare(folder: String,name: String,label: String) -> Dictionary:
	var catalog:=Catalog.new(); catalog.mount_directory(folder); var a:=prepare(catalog,name,false)
	catalog=Catalog.new(); catalog.mount_directory(folder); var b:=prepare(catalog,name,true)
	check(str(a.error)==str(b.error),label+": authoritative success/error agrees")
	if str(a.error).is_empty(): check(Cache.digest(var_to_bytes(a.value))==Cache.digest(var_to_bytes(b.value)) and a.animation_sources==b.animation_sources,label+": complete source hierarchy/animations agree exactly")
	check(Ancestors.snapshot().active==0 and catalog.decoder_store.snapshot().inflight==0,label+": owned helpers and decoded flights drain before return")
	return b
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-ancestor-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("root.mdl"),authored("root","parent")); write(folder.path_join("parent.mdl"),authored("parent","grandparent")); write(folder.path_join("grandparent.mdl"),authored("grandparent"))
	var result:=compare(folder,"root","Valid three-level chain")
	check(result.ancestor_preparation.jobs_started==mini(2,Ancestors.configured_share()) and result.ancestor_preparation.sources.size()==mini(2,Ancestors.configured_share()),"Actual production path starts and joins its configured bounded source share")
	write(folder.path_join("parent.mdl"),authored("parent","root")); compare(folder,"root","Supermodel cycle")
	write(folder.path_join("parent.mdl"),"bad model"); compare(folder,"root","Malformed parent")
	write(folder.path_join("root.mdl"),authored("root","absent")); compare(folder,"root","Missing parent")
	write(folder.path_join("root.mdl"),authored("root","absent")+"setsupermodel root grandparent\n"); result=compare(folder,"root","Wrong early hint with later authoritative override")
	check(result.animation_sources.size()==2 and result.animation_sources[1].name=="grandparent","An unavailable speculative hint cannot change the real source chain")
	write(folder.path_join("root.mdl"),authored("root","corrupt")+"setsupermodel root grandparent\n"); write(folder.path_join("corrupt.mdl"),"bad speculative model"); result=compare(folder,"root","Unused corrupt speculative ancestor")
	check(str(result.error).is_empty() and result.ancestor_preparation.sources.any(func(source):return not str(source.error).is_empty()),"Speculative decode errors remain diagnostics and never fail a valid real chain")
	write(folder.path_join("root.mdl"),authored("root","../escape")+"setsupermodel root grandparent\n"); result=compare(folder,"root","Unsafe hint name")
	check(result.ancestor_preparation.reads.is_empty(),"Hint scanner cannot read a path outside the catalog namespace")
	for index in 17: write(folder.path_join("chain"+str(index)+".mdl"),authored("chain"+str(index),"chain"+str(index+1) if index<16 else ""))
	compare(folder,"chain0","Authoritative inheritance depth limit")
	var header:=PackedByteArray(); header.resize(244); header.encode_u32(4,232)
	var parent:="binary_parent".to_ascii_buffer()
	for index in parent.size(): header[180+index]=parent[index]
	check(Ancestors.parent_hint(header)=="binary_parent","Original binary supermodel header offset is read directly")
	check(Ancestors.parent_hint(header.slice(0,240)).is_empty(),"Truncated binary header cannot supply a hint")
	header.encode_u32(4,9999); check(Ancestors.parent_hint(header).is_empty(),"Out-of-bounds binary model declaration cannot supply a hint")
	var catalog:=Catalog.new(); catalog.mount_directory(folder); var slow:=SlowSource.new(); var raw:=authored("root","grandparent").to_ascii_buffer()
	var first:=Ancestors.start(catalog,"root",raw,"",slow.decode)
	var second:=Ancestors.start(catalog,"root",raw,"",slow.decode)
	check(first.jobs.size()==1 and second.jobs.size()==1 and Ancestors.snapshot().active==2,"Independent roots share the fixed two-helper budget")
	var third:=Ancestors.start(catalog,"root",raw,"",slow.decode)
	check(third.metrics.deferred and third.jobs.is_empty(),"Saturated helper budget never blocks or creates another thread")
	Ancestors.finish(first); Ancestors.finish(second); Ancestors.finish(third)
	check(Ancestors.snapshot().active==0 and Ancestors.snapshot().peak<=2,"Returned decoder errors release all helper credits")
	# Saturate ordinary asset workers, then close while native helper work is
	# live. Child tasks never submit to that occupied pool, and each owner joins
	# its children before its catalog/result references may be released.
	write(folder.path_join("root.mdl"),authored("root","grandparent")); write(folder.path_join("root2.mdl"),authored("root2","grandparent"))
	catalog=Catalog.new(); catalog.mount_directory(folder)
	var owners: Array=[]; var callbacks: Array=[]
	for name in ["root","root2"]:
		var owner:=SlowService.new(); root.add_child(owner); owner.configure(catalog); owner.maximum_workers=1; owner.high_priority=true; owner.ancestor_preparation_enabled=true
		owner.completed.connect(func(id,_result):callbacks.append(id)); owner.request(name,2002,"actor-model",{"relevant_tracks":true}); owners.append(owner)
	var deadline:=Time.get_ticks_msec()+5000
	while Ancestors.snapshot().active==0 and Time.get_ticks_msec()<deadline: await process_frame
	check(Ancestors.snapshot().active>0,"Lifecycle exercise observes actual helper work before cancellation")
	for owner in owners: owner.retire_scope(); owner.close()
	check(Ancestors.snapshot().active==0 and catalog.decoder_store.snapshot().inflight==0,"Closing pool owners joins active/coalesced source helpers without deadlock")
	check(callbacks.is_empty() and owners.all(func(owner):return owner.running.is_empty() and owner.pending.is_empty() and owner.results.is_empty()),"Cancelled epochs deliver no stale result and retain no owned worker/result")
	for owner in owners: owner.queue_free()
	await process_frame; await process_frame
	var corpus: Array=[]
	if args.has("catalog"):
		for name in ["pme0","pme0_chest025","c_nulltail"]:
			var recorded:=Recorded.new(); check(recorded.mount(args.catalog),"Fresh serial strict corpus mounts: "+name); var a:=prepare(recorded,name,false)
			recorded=Recorded.new(); recorded.mount(args.catalog); var b:=prepare(recorded,name,true)
			check(str(a.error).is_empty() and str(b.error).is_empty() and Cache.digest(var_to_bytes(a.value))==Cache.digest(var_to_bytes(b.value)) and a.animation_sources==b.animation_sources,"Original full composed data agrees with production helpers: "+name)
			check(recorded.decoder_store.snapshot().inflight==0 and Ancestors.snapshot().active==0,"Original source helpers drain: "+name)
			corpus.append({"name":name,"serial_ms":a.test_elapsed_ms,"candidate_ms":b.test_elapsed_ms,"prefetch":b.ancestor_preparation})
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":corpus,"publicConnections":0,"scope":"Actual production bounded source helpers, exact authored/captured composition, errors/hints/depth and global credits; not whole-world latency acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
