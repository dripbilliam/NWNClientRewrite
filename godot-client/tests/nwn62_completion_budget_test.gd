extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
class Reader extends RefCounted:
	var failure:=""
	func fork():return Reader.new()
class Payload extends RefCounted:
	var marker: Dictionary
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:
			OS.delay_usec(250);marker.released+=1;marker.threads.append(OS.get_thread_caller_id())
class Jobs extends Assets:
	var marker: Dictionary
	func _work(job: Dictionary)->void:
		var payload:=Payload.new();payload.marker=marker
		mutex.lock();results[job.id]={"id":job.id,"epoch":job.epoch,"resource_name":job.name,"error":"","bytes":PackedByteArray(),"payload":payload};mutex.unlock()
var checks:=0
var failures: Array=[]
var observations: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func service(marker: Dictionary,pool,count: int)->Jobs:
	var node:=Jobs.new();node.marker=marker;root.add_child(node);node.maximum_workers=count;node.configure(Reader.new());node.completion_pool=pool
	for index in count:node.request(str(index),7)
	node.set_process(false);return node
func ready_jobs(nodes: Array)->void:
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var ready:=true
		for node in nodes:
			for task in node.running.values():ready=ready and WorkerThreadPool.is_task_completed(task)
		if ready:return
		await process_frame
	check(false,"Real worker tasks finish before callback-drain observation")
func shared_deadline()->void:
	var pool:=Pool.new();pool.publication_budget_us=1600
	var marker:={"released":0,"threads":[]};var delivered: Array=[]
	var first:=service(marker,pool,12);var second:=service(marker,pool,12)
	for node in [first,second]:
		node.completed.connect(func(id,_result):
			var began:=Time.get_ticks_usec();OS.delay_usec(400);pool.publication_finished(began);delivered.append([node.get_instance_id(),id]))
	await ready_jobs([first,second])
	first._profile_process(0);second._profile_process(0)
	check(delivered.size()>0 and delivered.size()<24,"Simultaneous ready workers cannot drain an unbounded callback burst")
	check(pool.publication_us==pool.completion_us and pool.completion_units==delivered.size(),"Shared callback scope includes nested scene time exactly once")
	check(int(marker.released)==delivered.size(),"Result payload destruction finishes inside the measured completion scope")
	check(marker.threads.all(func(thread):return int(thread)==OS.get_main_thread_id()),"Main-thread result cleanup retains its required ownership")
	var deferred_count:=first.running.size()+second.running.size();var before:=delivered.size()
	check(not pool.can_publish() and deferred_count+before==24,"The same pool deadline gates subsequent publication and retains every deferred result")
	observations.append({"kind":"shared","first_pass":before,"deferred":deferred_count,"callback_us":pool.completion_us,"charged_us":pool.publication_us})
	var deadline:=Time.get_ticks_msec()+5000
	while delivered.size()<24 and Time.get_ticks_msec()<deadline:await process_frame
	check(delivered.size()==24 and marker.released==24 and not first.is_processing() and not second.is_processing(),"Later frames drain all original results and both services return to NWN69 idle")
	for node in [first,second]:node.close();node.free()
	pool.clear()
func retire_reentrant()->void:
	var pool:=Pool.new();var marker:={"released":0,"threads":[]};var seen: Array=[]
	var node:=service(marker,pool,8)
	node.completed.connect(func(id,_result):seen.append(id);node.retire_scope();node._profile_process(0))
	await ready_jobs([node]);node._profile_process(0)
	check(seen.size()==1 and node.completion_pool==null and int(node.completion_stats.reentrant)==1,"Reentrant retirement releases the generation pool and cannot recursively deliver old results")
	var deadline:=Time.get_ticks_msec()+5000
	while not node.running.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(seen.size()==1 and marker.released==8 and node.results.is_empty() and not node.is_processing(),"Old ready results release without callbacks after epoch retirement")
	check(pool._completion_depth==0 and pool.completion_us>0,"Captured original pool scope closes even when callback retires its service")
	node.close();node.free();pool.clear()
func bounded_count()->void:
	var marker:={"released":0,"threads":[]};var node:=service(marker,null,12);node.completion_budget_us=0;node.maximum_completions_per_pass=3
	var seen: Array=[];node.completed.connect(func(id,_result):seen.append(id));await ready_jobs([node]);node._profile_process(0)
	check(seen.size()==3 and node.running.size()==9,"Configured completion-count cap is effective even with the time guard disabled")
	node.close();check(marker.released==12 and node.results.is_empty() and not node.is_processing(),"Close releases deferred result graphs without delivering callbacks")
	node.free()
func prior_construction()->void:
	var pool:=Pool.new();pool.publication_budget_us=1
	check(pool.can_consume_completion(),"Empty shared frame retains one initial completion progress unit")
	pool.construction_finished(Time.get_ticks_usec()-10)
	check(not pool.can_consume_completion(),"Construction already spent this frame prevents an additional free first completion")
	check(pool.can_consume_completion(true),"One explicit priority completion retains the configured progress reservation")
	pool.begin_prioritized_completion_scope(true);pool.end_completion_scope()
	check(not pool.can_consume_completion(true) and not pool.can_publish(true),"Priority callback consumes its shared reservation instead of multiplying it across services")
	pool.clear()
func prior_completion()->void:
	var pool:=Pool.new();pool.publication_budget_us=1
	pool.begin_completion_scope()
	check(pool.can_publish(),"Owning first completion can perform its first necessary construction without deadlock")
	pool._completion_began-=10
	check(not pool.can_consume_completion(),"Nested peer completion cannot multiply a spent general progress reservation")
	pool.end_completion_scope()
	check(not pool.can_publish() and not pool.can_consume_completion(),"An oversized CPU-only completion consumes the shared first-progress allowance across operation types")
	pool.clear()
func run()->void:
	await shared_deadline();await retire_reentrant();await bounded_count();prior_construction();prior_completion();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual WorkerThreadPool completions across shared world-pool callback/nested publication/result cleanup budget, epoch/reentrant retirement, deferred count and idle/close ownership. Deliberate submillisecond fixture delays verify scheduling; no FPS or throughput claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
