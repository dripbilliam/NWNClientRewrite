extends SceneTree
class Reader extends RefCounted:
	var failure:=""
	func fork():return Reader.new()
class Budget extends RefCounted:
	var allowed:=false
	func can_consume_completion(_priority: bool=false)->bool:return allowed
	func begin_completion_scope()->void:pass
	func end_completion_scope()->void:pass
class Tracker extends RefCounted:
	var mutex:=Mutex.new()
	var wake:=Semaphore.new()
	var started: Array=[]
	var active:=0
	var peak:=0
	func enter(id: int)->void:
		mutex.lock();started.append(id);active+=1;peak=maxi(peak,active);mutex.unlock();wake.wait()
	func leave()->void:mutex.lock();active-=1;mutex.unlock()
	func count()->int:mutex.lock();var result:=started.size();mutex.unlock();return result
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func until(predicate: Callable,label: String)->void:
	var deadline:=Time.get_ticks_msec()+5000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	check(bool(predicate.call()),label)
func context(path: String,count: int=6)->Dictionary:
	var script:=GDScript.new()
	script.source_code="extends "+JSON.stringify(path)+"\nvar tracker\nfunc _work(job: Dictionary)->void:\n\ttracker.enter(int(job.id))\n\tmutex.lock();results[job.id]={\"id\":job.id,\"epoch\":job.epoch,\"resource_name\":job.name,\"error\":\"\",\"bytes\":(\"original:\"+str(job.name)).to_utf8_buffer(),\"thread\":OS.get_thread_caller_id()};mutex.unlock()\n\ttracker.leave()\n"
	check(script.reload()==OK,"Actual source worker observer compiles: "+path)
	var service=script.new();var tracker:=Tracker.new();service.tracker=tracker;root.add_child(service);service.maximum_workers=2;service.maximum_pending=8;service.configure(Reader.new())
	var budget:=Budget.new();service.completion_pool=budget;var delivered: Array=[];var ids: Array=[]
	service.completed.connect(func(id,result):delivered.append(id);check(result.bytes==("original:"+str(result.resource_name)).to_utf8_buffer() and int(result.thread)!=OS.get_main_thread_id(),"Original private result bytes/thread survive completion buffering"))
	for index in count:ids.append(service.request(str(index),7))
	service.set_process(false)
	return {"service":service,"tracker":tracker,"budget":budget,"delivered":delivered,"ids":ids}
func all_finished(service)->bool:
	for task in service.running.values():
		if not WorkerThreadPool.is_task_completed(int(task)):return false
	return true
func drain(value: Dictionary)->void:value.service._profile_process(0);value.service.set_process(false)
func release(value: Dictionary,count: int)->void:
	for index in count:value.tracker.wake.post()
func dispose(value: Dictionary)->void:
	release(value,16);value.service.close();value.service.free()
func basic(path: String,changed: bool)->void:
	var value:=context(path);var service=value.service
	await until(func():return value.tracker.count()==2,"Exactly W real worker tasks enter first wave")
	check(service.running.size()==2 and service.pending.size()==4 and value.delivered.is_empty(),"Initial active/retained/pending state respects original limits")
	release(value,2);await until(func():return all_finished(service),"First wave genuinely completes without callbacks")
	drain(value)
	if not changed:
		await process_frame;check(value.tracker.count()==2 and service.running.size()==2 and service.pending.size()==4,"Frozen original leaves CPU slots idle behind denied completion")
		observations.append({"mode":"before","started":value.tracker.count(),"retained":service.running.size(),"delivered":value.delivered.size()});dispose(value);return
	await until(func():return value.tracker.count()==4,"New second wave actually runs before ANY callback is allowed")
	check(service.running.size()==4 and service.pending.size()==2 and value.delivered.is_empty(),"At most one completed wave plus W active tasks is retained")
	release(value,2);await until(func():return all_finished(service),"Second wave finishes into existing result ownership")
	drain(value);await process_frame
	check(value.tracker.count()==4 and service.running.size()==4 and service.pending.size()==2,"Third wave stays queued at2W despite all CPU slots being free")
	check(value.tracker.peak<=2 and int(service.worker_capacity_stats.maximum_reserved_active)<=2 and int(service.worker_capacity_stats.maximum_inflight)==4,"Actual and conservatively reserved active tasks never exceed W; retained tasks never exceed2W")
	check(int(service.worker_capacity_stats.completed_slot_reuses)==2 and int(service.worker_capacity_stats.backlog_bound_blocks)>0,"Positive actual old-capacity reuse and backlog-bound engagement")
	value.budget.allowed=true;drain(value)
	check(value.delivered==value.ids.slice(0,4),"Existing authoritative ready-callback order remains FIFO")
	await until(func():return value.tracker.count()==6,"Callback drainage releases capacity for final wave")
	release(value,2);await until(func():return all_finished(service),"Final workers finish")
	drain(value)
	check(value.delivered==value.ids and service.pending.is_empty() and service.running.is_empty() and service.results.is_empty(),"All exact original results delivered once, with no owner/result loss")
	check(not service.is_processing(),"Fully drained bounded-wave service retains NWN69 idle suspension")
	observations.append({"mode":"after","started":value.tracker.count(),"peak_actual_active":value.tracker.peak,"stats":service.worker_capacity_stats.duplicate(),"order":value.delivered.duplicate()});dispose(value)
func lowered_limit()->void:
	var value:=context("res://systems/native_data/asset_service.gd");var service=value.service
	await until(func():return value.tracker.count()==2,"Limit-reduction first wave starts")
	release(value,2);await until(func():return all_finished(service),"Limit-reduction first wave finishes");drain(value)
	await until(func():return value.tracker.count()==4,"Grandfathered second wave starts at original W")
	service.maximum_workers=1;service.pump();service.set_process(false)
	check(value.tracker.count()==4 and service.pending.size()==2,"Reduced active limit dispatches no new work beside grandfathered tasks")
	release(value,2);await until(func():return all_finished(service),"Grandfathered tasks finish");service.pump();service.set_process(false)
	check(value.tracker.count()==4 and service.running.size()==4,"Reduced retained limit blocks admission until old backlog drains")
	value.budget.allowed=true;service.maximum_completions_per_pass=1
	for turn in 2:drain(value)
	check(service.running.size()==2 and value.tracker.count()==4,"Exactly2W retained at reduced limit still prevents dispatch")
	drain(value);await until(func():return value.tracker.count()==5,"One new task may dispatch only below BOTH reduced bounds")
	check(service.running.size()==2 and service.pending.size()==1,"One old completion plus one new active task fits reduced bound")
	service.retire_scope();service.set_process(false);release(value,1);await until(func():return all_finished(service),"Reduced-limit worker finishes after retirement")
	while not service.running.is_empty():drain(value)
	check(value.delivered.size()==3 and service.pending.is_empty() and service.results.is_empty() and not service.is_processing(),"Retirement suppresses old/new epoch backlog callbacks and releases all owned data")
	dispose(value)
func pending_bound()->void:
	var value:=context("res://systems/native_data/asset_service.gd",0);var service=value.service;service.maximum_pending=3
	for index in 3:check(service.request(str(index),7)>0,"Logical max_pending accepts its original bound")
	check(service.request("overflow",7)==-1 and service.pending.size()+service.running.size()==3,"Existing max_pending bound includes active AND all retained tasks")
	service.set_process(false);dispose(value)
func run()->void:
	await basic("res://.cache/nwn62/completion-wave-before/asset_service.gd",false)
	await basic("res://systems/native_data/asset_service.gd",true)
	await lowered_limit();await pending_bound()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Real WorkerThreadPool semaphore engagement against frozen original; W active/2W retained bounds, exact ready callback ordering/bytes, reduced limits, max_pending, cancellation/retirement/close and idle. No timing/FPS claim."}
	var path:="res://.cache/nwn62/checks/worker-wave-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
