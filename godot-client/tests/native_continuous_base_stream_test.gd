extends SceneTree
# Actual production World/ObjectStream/resource workers and tiny authored meshes.
# Only an authored MDL read is gated; no readiness, worker or render-pool stubs.
const World=preload("res://systems/native_render/live_world.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Retirement=preload("res://systems/native_render/world_retirement.gd")
const Schedule=preload("res://systems/native_render/base_stream_schedule.gd")
class Gate:
	extends RefCounted
	var mutex:=Mutex.new()
	var release:=Semaphore.new()
	var enabled:=true
	var blocked:=0
	func enter() -> bool:
		mutex.lock();var hold:=enabled
		if hold:blocked+=1
		mutex.unlock();return hold
	func count() -> int:
		mutex.lock();var value:=blocked;mutex.unlock();return value
	func unblock() -> void:
		mutex.lock();enabled=false;mutex.unlock()
		for index in 8:release.post()
class HeldCatalog:
	extends Catalog
	var gate
	func fork() -> RefCounted:
		var copy=super.fork();copy.gate=gate;return copy
	func get_resource(name: String,kind: int) -> PackedByteArray:
		if kind==2002 and name=="authored_b" and gate!=null and gate.enter():gate.release.wait()
		return super.get_resource(name,kind)
var checks:=0
var failures: Array=[]
var cases: Array=[]
var worlds: Array=[]
var gates: Array=[]
var retirement
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
	return value
func row(id: int,appearance: int=0,lifetime: int=1) -> Dictionary:
	return {"id":id,"objectType":9,"areaId":1,"nativeLifetime":lifetime,"replicated":{},"staticState":{"id":id,"appearance":appearance,"position":[float(id)/10.0,0.0,0.0],"orientation":[0.0,1.0,0.0]}}
func make_world(source,epoch: int):
	var value=World.new();root.add_child(value);value.set_process(false)
	value.catalog=source;value.area_id=1;value.generation=epoch;value.opened_at=Time.get_ticks_usec();value.set_priority_origin(Vector3.ZERO)
	worlds.append(value);return value
func source(held: bool=false):
	var value=HeldCatalog.new() if held else Catalog.new()
	if held:
		value.gate=Gate.new();gates.append(value.gate)
	check(value.mount_directory(ProjectSettings.globalize_path("res://authored/base")),"Authored catalog mounted")
	return value
func spin(value,test: Callable,label: String,deadline_ms: int=5000) -> bool:
	var deadline:=Time.get_ticks_msec()+deadline_ms
	var bounded:=true
	while not test.call() and Time.get_ticks_msec()<deadline:
		value._process(0.0)
		for batch in value.batches:
			if batch.get("base_scenery",false):bounded=bounded and batch.keys.size()<=64 and batch.owner.continuous_rows.size()<=64
		await process_frame
	check(bounded,"Every observed base refill retains <=64 active reservations")
	return check(bool(test.call()),label)
func dispose(value) -> void:
	value.close();value.queue_free();worlds.erase(value)
	await process_frame;await process_frame
func schedule_case() -> void:
	var queue=Schedule.new()
	var desired:={1:{"key":"one","object":row(1)},2:{"key":"two","object":row(2)},3:{"key":"three","object":row(3)}}
	queue.update(1,"one",Vector3(3,0,0));queue.update(2,"two",Vector3(1,0,0));queue.update(3,"three",Vector3(1,0,0))
	check(queue.peek(2,desired,{},{},{}).map(func(value):return value.id)==[2,3],"Nearest priority uses stable ID tie ordering")
	check(queue.peek(2,desired,{2:true},{},{}).map(func(value):return value.id)==[3,1],"In-flight work cannot be reserved twice")
	check(queue.stats.sorts==1,"Unchanged priority does not re-sort on repeated planning")
	queue.reserved([row(2),row(3)],desired)
	check(queue.entries.size()==1 and queue.peek(8,desired,{},{},{}).size()==1,"Reservation retires metadata without removing canonical entities")
	queue.update(2,"old",Vector3.ZERO)
	check(queue.peek(8,desired,{},{},{}).size()==1 and not queue.entries.has(2),"Changed signature cannot resolve an old queued reference")
	queue.update(3,"three",Vector3.ZERO)
	check(queue.peek(8,desired,{}, {3:"three"},{}).size()==1,"Installed current keys are discarded")
	queue.update(3,"three",Vector3.ZERO)
	check(queue.peek(8,desired,{},{},{3:{"key":"three"}}).size()==1,"Current failed keys are discarded until canonical change")
	queue.set_origin(Vector3(5,0,0));queue.peek(1,desired,{},{},{})
	check(queue.stats.sorts==5,"Only changed queue/priority requires sorting")
	queue.clear();check(queue.entries.is_empty() and queue.order.is_empty() and queue.cursor==0,"Scope clear drops all stale queue metadata")
	cases.append({"name":"sparse-boundary-scheduler","success":true,"snapshot":queue.snapshot()})
func continuous_case() -> void:
	var catalog=source(true);var value=make_world(catalog,11)
	var rows: Array=[]
	for id in range(1,121):rows.append(row(id,1 if id==64 else 0))
	value.receive(rows,-1);value._process(0.0)
	check(value.continuous_base_stream and value.reuse_base_scenery_owner and value.batches.size()==1,"Explicit continuous mode owns one actual persistent base lane")
	var owner=value.batches[0].owner
	if not await spin(value,func():return catalog.gate.count()==1 and value.instances.size()>64,"More than one initial reservation loads while a cold original-wave model remains held"):catalog.gate.unblock();return
	check(value.retained_base_owner==owner and value.batches[0].owner==owner and int(value.stats.get("base_owner_creations",0))==1,"Refill preserves the actual owner rather than adding overlapping owners")
	check(not value.instances.has(64) and owner.assets.running.size()==1 and not owner.done,"Cold work remains genuinely outstanding while warm rows refill")
	check(int(owner.stats.model_jobs)==2 and owner.group_bundles.size()<=2,"Repeated prepared model groups share one result without new model jobs")
	check(not value.ready_for_control() and not value.ready_for_admission(),"Pre-control load does not weaken terrain/player readiness")
	check(int(value.stats.get("base_stream_refills",0))>0 and value.base_stream_schedule.stats.sorts==1,"Persistent refill occurs without per-refill whole-registry sorting")
	var held_evidence:={"entities_while_held":value.instances.size(),"active_rows":owner.continuous_rows.size(),"model_jobs":owner.stats.model_jobs,"real_running_workers":owner.assets.running.size(),"refills":value.stats.get("base_stream_refills",0),"schedule":value.base_stream_schedule.snapshot()}
	# Remove/reuse the held ID while its old result is outstanding.
	value.receive_delta([], [64],-1);value.receive_delta([row(64,0,2)],[],-1)
	var wanted_key: String=value.desired[64].key
	catalog.gate.unblock()
	await spin(value,func():return value.batches.is_empty() and value.instances.size()==120,"All rows complete after the real held resource is released")
	check(value.installed[64]==wanted_key and int(value.stats.stale_results)>0,"Old lifetime completion is discarded before the same-ID replacement is installed")
	check(value.failed_objects.is_empty() and value.stats.errors.is_empty() and value.retained_base_owner.wave_parked,"Complete persistent stream parks cleanly with no failed or missing entities")
	check(value.base_stream_schedule.entries.is_empty() and owner.continuous_rows.is_empty() and owner.groups.is_empty() and owner.group_bundles.is_empty(),"Completion releases active scheduling/group packets")
	check(value.worker_tasks().is_empty(),"All actual preparation workers are joined")
	cases.append({"name":"actual-continuous-refill-and-lifetime","success":true,"entities":value.instances.size(),"refills":value.stats.get("base_stream_refills",0),"held_evidence":held_evidence,"schedule":value.base_stream_schedule.snapshot(),"stats":value.stats.duplicate(true)})
	await dispose(value)
func moving_priority_case() -> void:
	# A point-only controlled presentation stand-in exercises the actual World
	# priority methods; this case does not simulate actor readiness or gameplay.
	var value=make_world(source(),15);var rows: Array=[]
	for id in range(401,501):rows.append(row(id))
	value.receive(rows,-1)
	var point:=Node3D.new();value.add_child(point);value.controlled_id=9000;value.instances[9000]=point
	value.pending_continuous_plan({},false,2)
	var initial: int=value.base_stream_schedule.stats.sorts
	for frame in range(1,200):
		point.position=Vector3(float(frame)/100.0,0,0)
		value.update_stream_priority();value.pending_continuous_plan({},false,2)
	check(value.base_stream_schedule.stats.sorts==initial,"Moving presentation below two metres cannot sort the pending queue every callback")
	point.position=Vector3(2.01,0,0);value.update_stream_priority();value.pending_continuous_plan({},false,2)
	check(value.base_stream_schedule.stats.sorts==initial+1 and value.priority_origin==point.position,"Crossing the existing two-metre threshold refreshes pending priority once")
	check(value.base_stream_schedule.entries.size()==100,"Movement-only priority checks preserve all pending canonical reservations")
	cases.append({"name":"moving-with-pending-priority-contract","success":true,"sub_threshold_calls":199,"sorts":value.base_stream_schedule.stats.sorts,"point_only_controlled_standin":true})
	value.instances.erase(9000);point.free();await dispose(value)
func failure_case() -> void:
	var value=make_world(source(),21);var rows: Array=[]
	for id in range(201,281):rows.append(row(id,999 if id==205 else 0))
	value.receive(rows,-1)
	await spin(value,func():return value.batches.is_empty() and value.instances.size()==79,"Independent failed row does not prevent later refill/completion")
	check(value.failed_objects.size()==1 and value.failed_objects.has(205) and value.stats.failed_admissions==1,"Failed signature is recorded once at its original ID")
	check(value.stats.errors.is_empty() and value.base_stream_schedule.entries.is_empty(),"Independent visual failure leaves no queued duplicate work or scope error")
	value.receive_delta([row(205,0,2)],[],-1)
	await spin(value,func():return value.batches.is_empty() and value.instances.size()==80,"Changed canonical key retries a previously failed ID")
	check(value.failed_objects.is_empty() and value.installed[205]==value.desired[205].key,"Successful retry clears the old failure")
	cases.append({"name":"failure-and-canonical-retry","success":true,"entities":value.instances.size()})
	await dispose(value)
func retirement_case() -> void:
	var catalog=source(true);var old=make_world(catalog,31)
	old.receive([row(301,1),row(302)],-1);old._process(0.0)
	if not await spin(old,func():return catalog.gate.count()==1,"Retirement fixture owns a real unfinished model job"):catalog.gate.unblock();return
	var reference:=weakref(old);retirement.retire(old)
	check(old.retiring and retirement.pending_workers()==1,"Retirement fences the continuous owner while its actual worker remains held")
	var current=make_world(source(),32);current.receive([row(301,0,2),row(302,0,2)],-1)
	await spin(current,func():return current.batches.is_empty() and current.instances.size()==2,"Next generation completes the same IDs independently")
	var key: String=current.installed[301]
	catalog.gate.unblock();var deadline:=Time.get_ticks_msec()+5000
	while reference.get_ref()!=null and Time.get_ticks_msec()<deadline:await process_frame
	check(reference.get_ref()==null and retirement.worlds.is_empty() and retirement.pending_workers()==0,"Retired continuous World and worker are fully released")
	worlds.erase(old)
	check(current.installed[301]==key and current.instances.size()==2,"Old completion cannot replace or remove the current generation's entity")
	cases.append({"name":"unfinished-retirement-and-next-generation","success":true,"retirement":retirement.snapshot()})
	await dispose(current)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	retirement=Retirement.new();root.add_child(retirement)
	schedule_case();await continuous_case();await moving_priority_case();await failure_case();await retirement_case()
	for gate in gates:gate.unblock()
	for value in worlds:
		if is_instance_valid(value):value.close();value.queue_free()
	retirement.close();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"production_world":true,"fake_render_pool":false,"readiness_overrides":false,"original_asset_reads":0,"network_connections":0,"gpu":false,"scope":"Isolated sparse queue plus full production World/ObjectStream/refill/source/worker/lifetime/retirement checks on tiny authored meshes; no network/gameplay/GPU/FPS acceptance"}
	var output:="res://result.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CONTINUOUS_BASE_STREAM ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
