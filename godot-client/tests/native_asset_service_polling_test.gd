extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const DrawCache=preload("res://systems/native_render/native_draw_cache_runtime.gd")
class Gate extends RefCounted:
	var mutex:=Mutex.new()
	var wake:=Semaphore.new()
	var entered:=false
	func hold() -> void:
		mutex.lock();entered=true;mutex.unlock();wake.wait()
	func started() -> bool:
		mutex.lock();var answer:=entered;mutex.unlock();return answer
class Reader extends RefCounted:
	var failure:=""
	var stats: Dictionary={}
	var prefix:="original:"
	var gate: RefCounted
	func fork() -> RefCounted:
		var result:=Reader.new();result.prefix=prefix;result.gate=gate;return result
	func get_resource(name: String,_type: int) -> PackedByteArray:
		if name=="held" and gate!=null:gate.hold()
		return (prefix+name).to_utf8_buffer()
class Observed extends Assets:
	var callback_count:=0
	func _process(delta: float) -> void:
		callback_count+=1;super._process(delta)
class FrameProbe extends Node:
	var state: Dictionary
	var first:=false
	func _process(_delta: float) -> void:
		if first:state.began=Time.get_ticks_usec()
		elif state.capture:state.samples.append(Time.get_ticks_usec()-int(state.began))
var options: Dictionary={}
var checks:=0
var failures: Array=[]
var received: Dictionary={}
var spawned: Array=[]
var benchmark: Dictionary={}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func frames(count: int) -> void:
	for index in count:await process_frame
func until(predicate: Callable,label: String) -> bool:
	var deadline:=Time.get_ticks_msec()+5000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	var ok:=bool(predicate.call());check(ok,label);return ok
func result_ok(id: int,content: String) -> bool:
	return received.has(id) and str(received[id].get("error","missing")).is_empty() and received[id].get("bytes")==content.to_utf8_buffer()
func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	var service:=Observed.new();check(not service.is_processing(),"Fresh off-tree service is idle")
	root.add_child(service);await frames(4)
	check(service.callback_count==0 and not service.is_processing(),"Entering SceneTree does not enable idle callbacks")
	var reader:=Reader.new();reader.gate=Gate.new();service.configure(reader)
	service.completed.connect(func(id,result):
		received[id]=result
		if result.resource_name=="chain":spawned.append(service.request("followup",7))
		elif result.resource_name=="close":service.close())
	await frames(4)
	check(service.callback_count==0 and not service.is_processing(),"Configured service stays idle with its cache leases retained")
	check(service.prepared_write_lease and int(Writes.snapshot().owners)==1,"Idle service retains its prepared-write owner")
	if DrawCache.enabled():
		check(service.native_draw_cache_lease and int(DrawCache.snapshot().users)==1,"Idle service retains its native draw-cache lease")
		var polled:=DrawCache._polled_frame;await frames(4)
		check(is_instance_valid(root.get_node_or_null("NativeDrawCacheRetirement")) and DrawCache._polled_frame>polled,"Shared cache driver continues maintenance with no asset callbacks")
	var id:=service.request("first",7);check(id>0 and service.is_processing(),"Request wakes actual completion polling")
	await until(func():return received.has(id),"Real worker completion arrives")
	await frames(2);check(result_ok(id,"original:first") and service.running.is_empty() and service.results.is_empty() and not service.is_processing(),"Exact worker bytes arrive and fully drained service sleeps")
	var callbacks:=service.callback_count;await frames(8);check(service.callback_count==callbacks,"Drained service has zero subsequent idle callbacks")
	id=service.request("chain",7)
	await until(func():return spawned.size()==1 and received.has(spawned[0]),"Reentrant completion handler can request follow-up work")
	await frames(2);check(result_ok(id,"original:chain") and result_ok(int(spawned[0]),"original:followup") and not service.is_processing(),"Reentrant request is not lost and sleeps after completion")
	service.maximum_workers=1
	var stale:=service.request("held",7);await until(reader.gate.started,"Old-scope worker is genuinely held")
	var canceled:=service.request("canceled",7);check(not service.pending.is_empty(),"Queued request waits behind held worker")
	var replacement:=Reader.new();replacement.prefix="replacement:"
	service.configure(replacement)
	check(service.pending.is_empty() and service.is_processing(),"Reconfigure cancels queued work but keeps old-worker drainage scheduled")
	var fresh:=service.request("fresh",7);reader.gate.wake.post()
	await until(func():return received.has(fresh),"New-scope work starts after stale worker finishes")
	await frames(2);check(not received.has(stale) and not received.has(canceled) and result_ok(fresh,"replacement:fresh") and service.results.is_empty() and not service.is_processing(),"Stale results are suppressed and released without losing new work")
	service.maximum_workers=0;id=service.request("pending-only",7)
	check(id>0 and service.is_processing() and service.running.is_empty(),"Pending-only work retains a scheduler wake")
	service.retire_scope();check(not service.is_processing() and service.pending.is_empty(),"Retiring the last pending request sleeps immediately")
	service.maximum_workers=1
	id=service.request("close",7);await until(func():return service.closed,"Completion handler can close its service")
	callbacks=service.callback_count;await frames(8)
	check(service.callback_count==callbacks and not service.is_processing() and service.running.is_empty() and service.results.is_empty(),"Reentrant close stops callbacks and drains workers/results")
	check(service.request("rejected",7)==-1 and not service.is_processing(),"Rejected request cannot wake a closed service")
	check(int(Writes.snapshot().owners)==0 and (not DrawCache.enabled() or int(DrawCache.snapshot().users)==0),"Closing releases cache leases exactly once")
	root.remove_child(service);service.configure(replacement);id=service.request("off-tree",7)
	check(service.is_processing(),"Request made before tree re-entry records its wake")
	root.add_child(service);await until(func():return received.has(id),"Re-entered service delivers its actual worker completion")
	await frames(2);check(result_ok(id,"replacement:off-tree") and not service.is_processing(),"Closed service can be reconfigured, re-entered and returned to idle")
	var closed_request:=service.request("close-before-delivery",7);service.close();callbacks=service.callback_count;await frames(3)
	check(not received.has(closed_request) and service.callback_count==callbacks and service.running.is_empty() and service.results.is_empty(),"Close drains an in-flight request without a late completion or callback")
	service.queue_free();await frames(2)
	if options.has("reference"):await compare_idle()
	check(int(Writes.snapshot().owners)==0,"All fixture service leases retire")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"native_draw_cache":DrawCache.enabled(),"benchmark":benchmark,"scope":"Actual SceneTree scheduling and WorkerThreadPool requests, reentrant requests/close, epoch replacement, canceled queues, lease retention/release and optional matched idle scheduling measurement. No whole-game FPS claim."}
	var output:=FileAccess.open(options.report,FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close();print("NATIVE_ASSET_POLLING ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func summarize(values: Array) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in sorted:total+=float(value)
	return {"samples":sorted.size(),"mean_us":total/maxi(1,sorted.size()),"median_us":sorted[sorted.size()/2],"p95_us":sorted[int(sorted.size()*0.95)],"p99_us":sorted[int(sorted.size()*0.99)]}
func compare_idle() -> void:
	check(FileAccess.get_sha256(options.reference)==str(options.get("reference-sha","")),"Reference is the exact pre-change asset-service source")
	if not failures.is_empty():return
	var reference:=GDScript.new();reference.source_code="extends "+JSON.stringify(options.reference)+"\nvar callback_count:=0\nfunc _process(delta: float) -> void:\n\tcallback_count+=1;super._process(delta)\n"
	check(reference.reload()==OK,"Reference observer uses the original callback implementation")
	var old: Array=[];var changed: Array=[];var source:=Reader.new()
	for index in 80:
		var a=reference.new();root.add_child(a);a.configure(source);old.append(a)
		var b:=Observed.new();root.add_child(b);b.configure(source);changed.append(b)
	var state:={"began":0,"capture":false,"samples":[]};var early:=FrameProbe.new();early.state=state;early.first=true;early.process_priority=-100000;root.add_child(early)
	var late:=FrameProbe.new();late.state=state;late.process_priority=100000;root.add_child(late)
	var samples:={"before":[],"after":[]};var callback_counts:={"before":0,"after":0}
	# A-B-B-A retains the same catalog, service count, probes and engine process.
	for mode in ["before","after","after","before"]:
		for item in old:item.set_process(mode=="before");item.callback_count=0
		for item in changed:item.callback_count=0
		await frames(8);state.samples=[];state.capture=true;await frames(160);state.capture=false
		samples[mode].append_array(state.samples)
		var callbacks:=0
		for item in old if mode=="before" else changed:callbacks+=int(item.callback_count)
		callback_counts[mode]+=callbacks
	check(callback_counts.before>0 and callback_counts.after==0,"Matched 80-service idle workload removes all service callbacks")
	benchmark={"services":80,"before":summarize(samples.before),"after":summarize(samples.after),"callback_counts":callback_counts,"order":"A-B-B-A","measure":"Microseconds between early/late actual SceneTree process callbacks; normal engine build, same process and resident services; probe overhead retained."}
	check(float(benchmark.after.median_us)<float(benchmark.before.median_us),"Normal-engine idle callback median CPU span decreases")
	for item in old+changed:item.close();item.queue_free()
	early.queue_free();late.queue_free();await frames(2)
