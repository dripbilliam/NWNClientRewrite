extends SceneTree
const Service=preload("res://systems/native_data/asset_service.gd")
const Shared=preload("res://systems/native_data/shared_animation_preparation.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Pose=preload("res://systems/model_native_pose.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ancestors=preload("res://systems/native_data/ancestor_preparation.gd")
class Counted:
	extends Service
	var count_mutex:=Mutex.new()
	var rig_builds:=0
	var projection_builds:=0
	var delay_ms:=0
	func inherited_clips(model: Dictionary,parent: Dictionary,parent_name: String) -> Dictionary:
		count_mutex.lock(); projection_builds+=1; count_mutex.unlock()
		if delay_ms>0: OS.delay_msec(delay_ms)
		return super.inherited_clips(model,parent,parent_name)
	func build_shared_rig(model: Dictionary,identity: String,cache_path: String) -> Dictionary:
		count_mutex.lock(); rig_builds+=1; count_mutex.unlock()
		if delay_ms>0: OS.delay_msec(delay_ms)
		return super.build_shared_rig(model,identity,cache_path)
class Held:
	extends RefCounted
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var result: Dictionary={"answer":1}
	func build() -> Dictionary:
		entered.post(); release.wait(); return result
class Failed:
	extends RefCounted
	var calls:=0
	func build() -> Dictionary:
		calls+=1; return {"error":"Authored calculation error"}
class SlowFailure:
	extends RefCounted
	var calls:=0
	func build() -> Dictionary:
		calls+=1; OS.delay_msec(40); return {"error":"Authored concurrent calculation error"}
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func write(path: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func authored(name: String,parent: String="",scale_value: float=1.0,with_clips: bool=false) -> String:
	var text:="newmodel %s\n"%name
	if not parent.is_empty(): text+="setsupermodel %s %s\n"%[name,parent]
	text+="setanimationscale %.6f\nbeginmodelgeom %s\nnode dummy %s\nparent NULL\nendnode\nnode dummy bone\nparent %s\nendnode\nnode dummy unused\nparent %s\nendnode\nendmodelgeom %s\n"%[scale_value,name,name,name,name,name]
	if with_clips:
		for clip in ["walk","pause"]:
			text+="newanim %s %s\nlength 1.0\ntranstime 0.1\nnode dummy %s\nparent NULL\npositionkey 2\n0 0 0 0\n1 4 0 0\nendnode\nnode dummy bone\nparent %s\npositionkey 2\n0 0 0 0\n1 0 2 0\nendnode\nnode dummy unused\nparent %s\npositionkey 2\n0 0 0 0\n1 0 0 3\nendnode\ndoneanim %s %s\n"%[clip,name,name,name,name,clip,name]
	return text
func catalog(folder: String):
	var value:=Catalog.new(); value.decoder_store=Store.new(); value.mount_directory(folder); return value
func make_service(enabled: bool) -> Counted:
	var value:=Counted.new(); value.shared_animation_preparation_enabled=enabled; value.ancestor_preparation_enabled=false
	root.add_child(value); value.set_process(false); return value
func prepare(service,reader,name: String,selected: Variant={}) -> Dictionary:
	var fork=reader.fork(); var bytes: PackedByteArray=fork.get_resource(name,2002)
	return service.actor_data(fork,name,bytes,"",[],selected)
func rig(service,reader,result: Dictionary) -> Dictionary:
	return service.shared_rig_data(result.value,result.animation_sources,"",reader.decoded_cache(),str(result.animation_view_identity))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-shared-animation-v1-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("parent.mdl"),authored("parent","",1.0,true))
	write(folder.path_join("child.mdl"),authored("child","parent",2.0))
	write(folder.path_join("sibling.mdl"),authored("sibling","parent",0.5))
	var serial:=make_service(false); var shared:=make_service(true); var reader=catalog(folder)
	var seen_views: Dictionary={}
	for selected in [null,{}, {"bone":true}, {"child":true}]:
		var reference:=prepare(serial,reader,"child",selected)
		var first:=prepare(shared,reader,"child",selected)
		var second:=prepare(shared,reader,"child",selected)
		check(reference.error.is_empty() and first.error.is_empty() and second.error.is_empty(),"Actual source composition succeeds for selection "+str(selected))
		check(Cache.digest(var_to_bytes(reference.value))==Cache.digest(var_to_bytes(first.value)) and first.value==second.value,"Shared projection exactly preserves serial clips, root alias, scaled packed keys and original geometry")
		check(first.animation_sources==reference.animation_sources and second.animation_sources==reference.animation_sources,"Exact actual parent source order/hashes remain attached")
		check(not first.has("shared_animation_preparation") and not second.has("shared_animation_preparation"),"V2 preserves original inheritance composition without populating a broad projection cache")
		check(not first.value.animations.is_read_only() and not is_same(first.value.animations,second.value.animations),"Instances retain private outer clip containers without scanning/freezing unused projection graphs")
		var decoded_before: Dictionary=reader.decoded_cache().snapshot()
		var a:=rig(shared,reader,first); var b:=rig(shared,reader,second); var c:=rig(shared,reader,first)
		check(a.hit==seen_views.has(first.animation_view_identity) and c.hit and is_same(b.value,c.value) and b.value.is_read_only() and b.value.clips.is_read_only(),"Second/repeated calculated rigs share one immutable canonical derived entry")
		check(seen_views.has(first.animation_view_identity) or a.first_use and not a.admitted and not a.resident,"A single-use rig avoids freezing/accounting/retention until actual repeated use")
		var decoded_after: Dictionary=reader.decoded_cache().snapshot()
		check(decoded_before.entries==decoded_after.entries and decoded_before.estimated_bytes==decoded_after.estimated_bytes and decoded_before.evictions==decoded_after.evictions and decoded_before.accounting==decoded_after.accounting,"Derived rig admission cannot charge or evict parsed MDL entries")
		seen_views[first.animation_view_identity]=true
		check(a.value==serial.rig_data(reference.value,reference.animation_sources,""),"Resident rig matches original calculation for this selection")
		second.value.name="private_header"; second.value.animations.clear()
		var third:=prepare(shared,reader,"child",selected)
		check(third.value.name=="child" and not third.value.animations.is_empty(),"Per-actor header and clip-container mutation cannot corrupt another actor or cached projection")
	var all:=prepare(shared,reader,"child",null); var filtered:=prepare(shared,reader,"child",{"bone":true})
	check(all.animation_view_identity!=filtered.animation_view_identity and rig(shared,reader,all).value.controlled.size()>rig(shared,reader,filtered).value.controlled.size(),"Full and filtered views cannot collide in memory or persistent rig identity")
	check(Shared.view_identity(all.animation_sources,{"bone":true,"child":true})==Shared.view_identity(all.animation_sources,{"child":true,"bone":true}),"Selection dictionary insertion order does not fragment the cache")
	# Consumers retain private native Part storage and binding state even when
	# defaults, clips and controller trees share the same immutable rig asset.
	var parent_result:=prepare(shared,reader,"parent",null)
	rig(shared,reader,parent_result)
	var asset: Dictionary=rig(shared,reader,parent_result).value; var source_before:=Cache.digest(var_to_bytes(asset))
	check(asset.get("nativeAnimation",{}).get("root",-1)>=0,"Authored model provides real native controller data for pose isolation")
	if asset.get("nativeAnimation",{}).get("root",-1)>=0:
		var poses: Array=[]; var nodes: Array=[]
		for index in 2:
			var pose:=Pose.new(); pose.compiled_controls=false; pose.native_storage=false; pose.prepared_plan=false; pose.bulk_evaluation=false
			var private_nodes: Array=[]
			for row in asset.nativeAnimation.parts: private_nodes.append(Node3D.new())
			var parts: Array=[]
			for part in private_nodes.size(): parts.append(part)
			pose.configure(asset.nativeAnimation,{"parts":parts},private_nodes,{})
			poses.append(pose); nodes.append(private_nodes)
		var before_b: Array=poses[1].read(poses[1].parts[0],16,3)
		poses[0].set_manual(0,Vector3(3,4,5),Quaternion.IDENTITY)
		check(poses[0].read(poses[0].parts[0],16,3)!=before_b and poses[1].read(poses[1].parts[0],16,3)==before_b,"Two native pose owners sharing one rig retain independent writable transform storage")
		check(Cache.digest(var_to_bytes(asset))==source_before,"Real native pose initialization/update never mutates shared controller/default/clip data")
		for index in poses.size():
			poses[index].close()
			for node in nodes[index]: node.free()
	# Distinct palette requests take this same lower immutable path, independently
	# of complete actor bundles whose keys include their private palette options.
	print("SHARED_TEST_PHASE concurrent")
	var concurrent:=make_service(true); concurrent.delay_ms=40; var fresh=catalog(folder)
	var value:=prepare(concurrent,fresh,"child",null)
	var threads: Array=[]
	for index in 6:
		var thread:=Thread.new(); thread.start(rig.bind(concurrent,fresh,value)); threads.append(thread)
	var outputs: Array=[]
	for thread in threads: outputs.append(thread.wait_to_finish())
	print("SHARED_TEST_PHASE concurrent-finished")
	check(concurrent.rig_builds==1 and outputs.filter(func(output):return output.hit).size()==5,"Six actual concurrent rig requests perform one calculation")
	check(outputs.all(func(output):return is_same(output.value,outputs[0].value)) and outputs.any(func(output):return int(output.wait_us)>0),"Concurrent followers reuse one immutable result and report their coalesced wait")
	check(fresh.decoded_cache().snapshot().inflight==0 and Shared.snapshot(fresh.decoded_cache()).inflight==0,"Concurrent native requests leave no outstanding source or derived cache flight")
	# Exercise the actual service publication path too. Complete bundle caching
	# owns private graphs; the service rebinds its canonical read-only rig after
	# that copy so later actor instances still share the calculated skeleton data.
	var worker_reader=catalog(folder)
	var worker:=make_service(true); worker.high_priority=true; worker.ancestor_preparation_enabled=true; worker.configure(worker_reader); worker.set_process(true)
	var published: Array=[]
	worker.completed.connect(func(_id,result):published.append(result))
	for palette in [[0],[1],[1],[0]]:
		worker.request("child",2002,"actor-model",{"relevant_tracks":true,"palette_colors":palette})
		var expected:=published.size()+1; var deadline:=Time.get_ticks_msec()+3000
		while published.size()<expected and Time.get_ticks_msec()<deadline: await process_frame
		check(published.size()==expected and published.back().error.is_empty(),"Actual native asset worker publishes an actor palette request")
	if published.size()==4:
		check(is_same(published[1].value.rig_asset,published[2].value.rig_asset) and is_same(published[2].value.rig_asset,published[3].value.rig_asset),"After second-use admission, distinct palette bundles and complete-bundle memory hits share the same canonical rig")
		check(published[2].get("memory_cache_hit",false) and published[2].phases.shared_rig_preparation.hit,"Complete prepared-bundle hits explicitly restore/report canonical rig sharing")
		check(published[0].phases.ancestor_preparation.jobs_started>0 and Ancestors.snapshot().active==0,"Real high-priority native source helpers execute and drain alongside shared projection/rig preparation")
		var actor_a:=Actor.new(); var actor_b:=Actor.new(); root.add_child(actor_a); root.add_child(actor_b)
		var pool:=Pool.new(); var maps:={"0":{"0":"walk","1":"pause"}}
		var shared_before:=Cache.digest(var_to_bytes(published[1].value.rig_asset))
		check(actor_a.install([{"bundle":published[1]}],pool,101,maps,0) and actor_b.install([{"bundle":published[2]}],pool,102,maps,0),"Two real native actor/rig owners install the actual worker-prepared shared calculated data")
		if actor_a.rigs!=null and actor_b.rigs!=null:
			actor_a.rigs.set_process(false); actor_b.rigs.set_process(false)
			actor_a.set_animation(1,2.0,false)
			actor_a.rigs._update(0.2); actor_b.rigs._update(0.4)
			var runtime_a: Dictionary=actor_a.rigs.entities[101].models[0]
			var runtime_b: Dictionary=actor_b.rigs.entities[102].models[0]
			check(runtime_a.clip=="pause" and runtime_b.clip=="walk" and runtime_a.speed==2.0 and runtime_b.speed==1.0,"Actual animation selection, speed, loop and playback state remain private per actor")
			check(runtime_a.player!=runtime_b.player and runtime_a.clip_builder.library!=runtime_b.clip_builder.library and runtime_a.clip_builder.library.get_animation(runtime_a.names.pause)!=runtime_b.clip_builder.library.get_animation(runtime_b.names.walk),"Actual binding paths and writable AnimationPlayer/Library/Animation resources are not shared")
			check(is_same(runtime_a.asset_source,runtime_b.asset_source) and Cache.digest(var_to_bytes(runtime_a.asset_source))==shared_before,"Actual ModelRigs readers do not mutate shared defaults, clips, tracks or controller metadata")
		actor_a.retire(); await process_frame
		actor_b.set_animation(1,1.0,true)
		check(not actor_b.retired and actor_b.rigs.entities[102].models[0].clip=="pause","Retiring one real actor leaves the other shared-resource actor playable")
		actor_b.retire(); await process_frame
		var builds_before:=worker.rig_builds
		worker_reader.decoder_store.clear()
		for palette in [[1],[1],[0]]:
			worker.request("child",2002,"actor-model",{"relevant_tracks":true,"palette_colors":palette})
			var expected:=published.size()+1; var deadline:=Time.get_ticks_msec()+3000
			while published.size()<expected and Time.get_ticks_msec()<deadline: await process_frame
			check(published.size()==expected and published.back().error.is_empty(),"Actual full-bundle hit recovers after the decoded owner generation changes")
		if published.size()==7:
			check(worker.rig_builds==builds_before and published[4].phases.shared_rig_preparation.seeded and published[5].phases.shared_rig_preparation.seeded,"Full-bundle hits seed from existing prepared rig data and never invoke a rig rebuild after eviction")
			check(is_same(published[5].value.rig_asset,published[6].value.rig_asset) and published[6].phases.shared_rig_preparation.hit,"New-generation seeded rig becomes canonical for subsequent actor bundles")
			check(worker_reader.decoder_store.snapshot().entries==0 and Shared.snapshot(worker_reader.decoder_store).entries==1,"Seed restoration repopulates only the independent derived tier, not decoded MDLs")
	worker.close(); worker.free()
	# Source selection still reads the actual parent before using a projected hit.
	var old_identity: String=value.animation_view_identity
	var override_dir:=folder.path_join("override")
	write(override_dir.path_join("parent.mdl"),authored("parent","",1.0,true).replace("1 4 0 0","1 9 0 0"))
	check(fresh.mount_directory(override_dir,10000001),"Higher-priority original resource override mounts")
	var overridden:=prepare(concurrent,fresh,"child",null)
	check(overridden.error.is_empty() and overridden.animation_view_identity!=old_identity and overridden.animation_sources[1].sha256!=value.animation_sources[1].sha256,"Actual parent override bytes invalidate inherited projection/rig identities despite unchanged child bytes")
	check(rig(concurrent,fresh,overridden).value!=outputs[0].value,"Changed parent produces changed rig instead of reviving the old shared result")
	check(prepare(concurrent,fresh,"child",null).shared_animation_preparation.back().hit,"New parent generation can reuse its own correctly derived result")
	var sibling:=prepare(shared,reader,"sibling",null)
	check(sibling.animation_view_identity!=all.animation_view_identity and sibling.value.animations!=all.value.animations,"Sibling root aliases and animation scales retain distinct projection identities")
	# Clear while an old generation is computing: existing waiters finish with
	# their own immutable result; old work cannot populate the new generation.
	var small:=Store.new(); var held:=Held.new(); var work:=Thread.new()
	print("SHARED_TEST_PHASE retirement")
	work.start(Shared.acquire.bind(small,"held",held.build)); held.entered.wait()
	var follower:=Thread.new(); follower.start(Shared.acquire.bind(small,"held",held.build))
	var waiter_deadline:=Time.get_ticks_msec()+2000
	while Shared.snapshot(small).coalesced==0 and Time.get_ticks_msec()<waiter_deadline: await process_frame
	check(Shared.snapshot(small).coalesced==1,"Retirement exercise observes a real waiter on an unfinished calculation")
	small.clear(); held.release.post()
	var old: Dictionary=work.wait_to_finish()
	var old_follower: Dictionary=follower.wait_to_finish()
	check(old.value.answer==1 and small.snapshot().entries==0 and small.snapshot().inflight==0,"Retired calculation drains without repopulating a cleared generation")
	check(is_same(old.value,old_follower.value) and old.value.is_read_only() and Shared.snapshot(small).entries==0,"Old-generation waiter receives only its own read-only result and cannot populate the replacement partition")
	var current:=Shared.acquire(small,"held",func():return {"answer":2})
	check(not current.hit and current.value.answer==2,"Reconnect/new generation cannot resolve the old same-key prepared result")
	print("SHARED_TEST_PHASE retirement-finished")
	var failed:=Failed.new()
	for index in 2:
		var error:=Shared.acquire(small,"failed",failed.build)
		check(error.value.error=="Authored calculation error" and not error.hit,"Calculation errors stay explicit and do not become successful cache hits")
	check(failed.calls==2 and small.snapshot().inflight==0,"Failure retries do not leak a flight or permanently poison a key")
	var failed_owner:=Store.new(); var slow_failed:=SlowFailure.new(); var error_threads: Array=[]; var error_outputs: Array=[]
	for index in 6:
		var thread:=Thread.new(); thread.start(Shared.acquire.bind(failed_owner,"concurrent-error",slow_failed.build)); error_threads.append(thread)
	for thread in error_threads: error_outputs.append(thread.wait_to_finish())
	check(slow_failed.calls==1 and error_outputs.all(func(output):return output.value.error=="Authored concurrent calculation error"),"Concurrent calculation errors wake every real follower without duplicate work")
	check(Shared.snapshot(failed_owner).inflight==0 and Shared.snapshot(failed_owner).entries==0,"Failed single-flight data never leaks a flight or becomes a successful retained entry")
	var tiny:=Store.new(); tiny.maximum_bytes=1
	Shared.set_limits(tiny,1)
	for index in 2: Shared.acquire(tiny,"too-large",func():return {"clips":[1,2,3]})
	check(Shared.snapshot(tiny).entries==0 and Shared.snapshot(tiny).inflight==0,"Oversized prepared data remains usable without bypassing the independent derived memory bound")
	var eviction_owner:=Store.new(); Shared.set_limits(eviction_owner,1024*1024,1)
	var retained_old: Dictionary={}
	for key in ["old","new"]:
		Shared.acquire(eviction_owner,key,func():return {"name":key})
		var retained:=Shared.acquire(eviction_owner,key,func():return {"name":key})
		if key=="old": retained_old=retained.value
	check(Shared.snapshot(eviction_owner).entries==1 and Shared.snapshot(eviction_owner).evictions==1 and retained_old.name=="old" and retained_old.is_read_only(),"Derived eviction is bounded and preserves an old immutable resource held by a live consumer")
	check(eviction_owner.snapshot().entries==0 and eviction_owner.snapshot().evictions==0,"Derived partition eviction leaves the parsed-source store untouched")
	var transient=Store.new(); var orphan:=Shared.partition(transient); transient=null
	check(orphan.source.get_ref()==null,"Derived partition uses a weak source witness and cannot retain a retired catalog/store")
	# Actual authoritative error paths still run before any projection lookup.
	write(folder.path_join("cycle.mdl"),authored("cycle","cycle"))
	write(folder.path_join("missing.mdl"),authored("missing","absent"))
	var error_reader=catalog(folder)
	for name in ["cycle","missing"]:
		var a:=prepare(serial,error_reader,name,null); var b:=prepare(shared,error_reader,name,null)
		check(not a.error.is_empty() and a.error==b.error,"Shared preparation preserves authoritative missing/cyclic parent error: "+name)
	# Optional sealed real sources are correctness/worker timings only. No GPU,
	# native gameplay connection or full-world FPS acceptance is implied.
	if args.has("catalog"):
		for name in ["pme0","pme0_chest025","c_nulltail"]:
			var recorded:=Recorded.new(); check(recorded.mount(args.catalog),"Original captured catalog mounts: "+name)
			var began:=Time.get_ticks_usec(); var reference:=prepare(serial,recorded,name,{})
			var serial_ms:=(Time.get_ticks_usec()-began)/1000.0
			began=Time.get_ticks_usec(); var first:=prepare(shared,recorded,name,{})
			var first_ms:=(Time.get_ticks_usec()-began)/1000.0
			began=Time.get_ticks_usec(); var second:=prepare(shared,recorded,name,{})
			var repeated_ms:=(Time.get_ticks_usec()-began)/1000.0
			check(reference.error.is_empty() and first.error.is_empty() and second.error.is_empty() and Cache.digest(var_to_bytes(reference.value))==Cache.digest(var_to_bytes(first.value)) and first.value==second.value,"Captured original composed source exactly matches serial preparation: "+name)
			if not first.error.is_empty(): continue
			var a:=rig(shared,recorded,first); var b:=rig(shared,recorded,second); var c:=rig(shared,recorded,first)
			check(not a.hit and b.admitted and c.hit and is_same(b.value,c.value) and a.value==serial.rig_data(reference.value,reference.animation_sources,""),"Captured original calculated rig exactly matches and is shared after actual repeated use: "+name)
			observations.append({"name":name,"serial_ms":serial_ms,"first_ms":first_ms,"repeated_ms":repeated_ms,"rig_first_ms":a.elapsed_ms,"rig_second_admission_ms":b.elapsed_ms,"rig_repeated_ms":c.elapsed_ms,"source_count":first.animation_sources.size(),"derived_cache":Shared.snapshot(recorded.decoded_cache())})
	for service in [serial,shared,concurrent]: service.close(); service.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"server_connections":0,"graphics":0,"scope":"Actual source and calculated rig cache, inherited projection equivalence, private native poses, concurrent work, override/removal of generation, selected views and errors; optional source timings are not full-world loading/FPS acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("NATIVE_SHARED_ANIMATION_PREPARATION ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
