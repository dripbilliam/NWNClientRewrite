extends SceneTree
const Store=preload("res://systems/native_data/preparation_store.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
var mutex:=Mutex.new()
var received: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func follower(store,epoch: int,index: int) -> void:
	var lease: Dictionary=store.begin_data("authored",epoch)
	mutex.lock(); received[index]=lease; mutex.unlock()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var store:=Store.new(); var epoch:=store.generation()
	check(store.begin_data("authored",epoch).owner,"First request owns immutable preparation")
	var tasks: Array=[]
	for index in 3: tasks.append(WorkerThreadPool.add_task(follower.bind(store,epoch,index)))
	var deadline:=Time.get_ticks_msec()+10000
	while store.snapshot().coalesced<3 and Time.get_ticks_msec()<deadline: await process_frame
	check(store.snapshot().coalesced==3,"Concurrent consumers wait behind the actual leader")
	var value:={"data":[{"pose":1}],"bytes":PackedByteArray([1,2,3])}
	store.save_data("authored","identity",value,epoch)
	store.finish_data("authored",epoch,value)
	while tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)): await process_frame
	for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
	check(received.size()==3 and received.values().all(func(row):return not row.owner and row.value==value),"All followers receive complete equivalent preparation")
	received[0].value.data[0].pose=99
	check(received[1].value.data[0].pose==1 and store.load_data("authored",epoch).data[0].pose==1,"Mutable caller state cannot modify another actor's immutable source")
	store.clear(); received.clear(); tasks.clear(); epoch=store.generation()
	check(store.begin_data("authored",epoch).owner,"New catalog epoch creates a new leader")
	tasks.append(WorkerThreadPool.add_task(follower.bind(store,epoch,0)))
	deadline=Time.get_ticks_msec()+10000
	while store.snapshot().coalesced<4 and Time.get_ticks_msec()<deadline: await process_frame
	store.clear(); store.finish_data("authored",epoch,{"error":"retired"})
	while not WorkerThreadPool.is_task_completed(tasks[0]): await process_frame
	WorkerThreadPool.wait_for_task_completion(tasks[0])
	check(received[0].value.error=="retired" and store.snapshot().inflight==0,"Retirement releases old waiters without publishing stale cache data")
	var assets:=Assets.new(); root.add_child(assets); var shared:=Store.new(); var results: Dictionary={}
	var bytes:="2DA V2.0\n\nValue\n0 17\n1 23\n".to_utf8_buffer(); tasks.clear()
	for index in 8:
		tasks.append(WorkerThreadPool.add_task(func():
			var result:=assets.decode(bytes,2017,"2da","",shared)
			mutex.lock(); results[index]=result; mutex.unlock()))
	while tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)): await process_frame
	for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
	check(results.size()==8 and results.values().all(func(row):return str(row.error).is_empty()),"Actual native decoder services concurrent consumers")
	check(results.values().filter(func(row):return not row.memory_decode_hit).size()==1,"Identical concurrent native inputs decode exactly once")
	results[0].value.orderedRows[0].Value="changed"
	check(results[1].value.orderedRows[0].Value=="17","Actual decoded table copies retain independent consumer state")
	var typed:=assets.decode(bytes,2016,"2da","",shared)
	check(not typed.memory_decode_hit,"Resource type remains part of preparation identity")
	var borrowed:=assets.decode(bytes,2017,"2da","",shared,true)
	var borrowed_again:=assets.decode(bytes,2017,"2da","",shared,true)
	check(is_same(borrowed.value,borrowed_again.value),"Read-only appearance-table consumers share the immutable decoded source")
	var isolated:=assets.decode(bytes,2017,"2da","",shared)
	isolated.value.orderedRows[0].Value="isolated"
	check(borrowed.value.orderedRows[0].Value=="17" and not is_same(isolated.value,borrowed.value),"Default mutable table consumers cannot alter shared read-only rendering data")
	assets.close(); assets.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"store":shared.snapshot()})); file.close()
	quit(0 if failures.is_empty() else 1)
