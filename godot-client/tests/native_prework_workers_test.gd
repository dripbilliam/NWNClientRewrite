extends SceneTree
const Controller=preload("res://systems/native_asset_prework.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
var folder:=""
class Monitor:
	extends RefCounted
	var mutex:=Mutex.new()
	var resume:=Semaphore.new()
	var entered:=0
	var active:=0
	var peak:=0
	func enter() -> void:
		mutex.lock(); entered+=1; active+=1; peak=maxi(peak,active); mutex.unlock(); resume.wait()
	func leave() -> void:
		mutex.lock(); active-=1; mutex.unlock()
	func count() -> int:
		mutex.lock(); var value:=entered; mutex.unlock(); return value
class HeldWriter:
	extends "res://systems/native_data/prework_store.gd"
	var monitor
	func save_entry_locked(key: String,inputs: Array,data: Dictionary) -> bool:
		monitor.enter(); var ok:=super.save_entry_locked(key,inputs,data); monitor.leave(); return ok
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func wait_count(monitor,count: int) -> void:
	var deadline:=Time.get_ticks_msec()+5000
	while monitor.count()<count and Time.get_ticks_msec()<deadline: await process_frame
func wait_tasks(tasks: Array) -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while tasks.any(func(task):return not WorkerThreadPool.is_task_completed(int(task))) and Time.get_ticks_msec()<deadline: await process_frame
	check(tasks.all(func(task):return WorkerThreadPool.is_task_completed(int(task))),"Data workers drain")
	for task in tasks: WorkerThreadPool.wait_for_task_completion(int(task))
func wait_done(owner) -> void:
	var deadline:=Time.get_ticks_msec()+60000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"Parallel preparation action finishes/drains")
func fixture() -> String:
	var path:=folder.path_join("recorded"); DirAccess.make_dir_recursive_absolute(path.path_join("objects"))
	var availability: Dictionary={}; var resources: Dictionary={}
	var geometry: Array[String]=["beginmodelgeom %s","node trimesh root","parent NULL","verts 900"]
	for index in 300: geometry.append_array(["0 0 0","1 0 0","0 1 0"])
	geometry.append("faces 300")
	for index in 300: geometry.append("%d %d %d 1 0 1 2 0"%[index*3,index*3+1,index*3+2])
	geometry.append_array(["endnode","endmodelgeom %s"])
	var body:="\n".join(geometry)+"\n"
	for index in 16:
		var name:="shape_%03d"%index; var bytes:=("newmodel "+name+"\n"+body%[name,name]).to_utf8_buffer(); var sha:=Cache.digest(bytes)
		write(path.path_join("objects").path_join(sha),bytes); availability[name+":2002"]=2; resources[name+":2002"]={"sha256":sha,"bytes":bytes.size()}
	write(path.path_join("manifest.json"),JSON.stringify({"version":2,"complete":true,"availability":availability,"resources":resources}).to_utf8_buffer()); return path
func manifest(path: String) -> Dictionary:
	var store:=Store.new(); store.configure(path); var result: Dictionary={}
	for filename in DirAccess.get_files_at(store.directory):
		var key:=filename.get_basename(); var entry:=store.cache.load_data(key,key,Store.REVISION)
		if not entry.is_empty(): result[key]=Cache.digest(var_to_bytes(entry.data))
	return result
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; root.push_input(event,true); await process_frame
func run() -> void:
	var report:=""
	var existing_cache:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--existing-cache="): existing_cache=arg.substr(17)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	folder=OS.get_temp_dir().path_join("nwn-parallel-prework-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var compatible:=0
	if not existing_cache.is_empty():
		var existing:=Store.new(); existing.configure(existing_cache); var decoder:=Assets.new()
		var scanned:=0; var scanned_bytes:=0
		for filename in DirAccess.get_files_at(existing.directory):
			if scanned>=128 or scanned_bytes>=32*1024*1024: break
			var probe:=FileAccess.open(existing.directory.path_join(filename),FileAccess.READ)
			if probe==null: continue
			var size:=probe.get_length(); probe.close(); scanned+=1
			if size>8*1024*1024: continue
			scanned_bytes+=size
			var key:=filename.get_basename(); var entry:=existing.cache.load_data(key,key,Store.REVISION)
			if not entry.get("data",{}).get("value") is Dictionary: continue
			for row in entry.inputs:
				if row.get("operation")=="bytes" and row.get("sha256")==entry.data.sha256 and row.get("type")==2002:
					for route in ["static-model","actor-model"]:
						var expected:=Store.request_key(str(row.name),2002,route,{"relevant_tracks":true} if route=="actor-model" else {},str(entry.data.sha256),[decoder.mesh_preparation_enabled,decoder.skin_preparation_enabled,decoder.mesh_revision()])
						if expected==key: compatible+=1
			if compatible>=3: break
		decoder.free(); check(compatible>0,"Existing Arelith prework keeps its cache identity across worker/scheduling changes")
	var recorded:=fixture(); var owner:=Controller.new(); root.add_child(owner)
	var states: Array=[]; var outputs: Array=[]
	for workers in [1,4]:
		owner.set_workers(workers); var path:=folder.path_join("cache-"+str(workers))
		check(owner.start_sources({"recordedCatalog":recorded},path),"Preparation starts with "+str(workers)+" workers")
		await wait_done(owner); states.append(owner.state.duplicate(true)); outputs.append(manifest(path))
		check(owner.state.completed==32 and owner.state.failed==0 and owner.state.saved==32,"Every model variant is saved exactly once")
		check(int(owner.state.peak_running)==workers,"Outstanding work fills and respects the selected worker bound")
	check(outputs[0].size()==32 and outputs[0]==outputs[1],"One and four workers produce byte-identical persisted model bundles")
	check(states[1].threads.size()>1 and not states[1].threads.has(OS.get_main_thread_id()),"Actual preparation runs on multiple background threads")
	owner.set_workers(1); owner.start_sources({"recordedCatalog":recorded},folder.path_join("cancel"))
	while owner.service==null: await process_frame
	owner.set_workers(4); check(owner.service.maximum_workers==4 and owner.inflight()==4,"Worker count can increase during preparation")
	var accepted: int=owner.service.serial; owner.cancel(); await wait_done(owner)
	check(int(owner.state.completed)==accepted,"Cancel drains admitted jobs and admits no additional work")
	owner.start_sources({"recordedCatalog":recorded},folder.path_join("clear"))
	while owner.service==null: await process_frame
	owner.clear_saved(folder.path_join("clear")); await wait_done(owner)
	check(DirAccess.get_files_at(owner.store.directory).is_empty(),"Clear drains all parallel model workers before deleting saved output")
	# Barriers prove disk saves are concurrent, rather than merely submitting
	# several jobs that still wait behind the former global serialization lock.
	var monitor:=Monitor.new(); var writers: Array=[]; var tasks: Array=[]; var saved: Array=[]; var results_mutex:=Mutex.new()
	for index in 2:
		var writer:=HeldWriter.new(); writer.monitor=monitor; writer.configure(folder.path_join("parallel-write")); writers.append(writer)
		var key:=Cache.key(str(index),"writer-test"); var epoch:=writer.generation()
		tasks.append(WorkerThreadPool.add_task(func():
			var ok: bool=writer.save_entry(key,[],{"index":index},epoch); results_mutex.lock(); saved.append(ok); results_mutex.unlock()))
	await wait_count(monitor,2); check(monitor.count()==2,"Independent cache files enter serialization concurrently")
	monitor.resume.post(); monitor.resume.post(); await wait_tasks(tasks)
	check(saved==[true,true] and monitor.peak==2,"Independent concurrent writes both publish complete entries")
	# Hold one destination, admit a duplicate behind it, and clear concurrently.
	# Clear must invalidate the waiter, drain the first writer, then delete it.
	monitor=Monitor.new(); writers=[]; tasks=[]; saved=[]
	var same_key:=Cache.key("same","writer-test"); var location:=Store.new(); location.configure(folder.path_join("clear-race")); var old_ticket:=location.generation()
	for index in 2:
		var writer:=HeldWriter.new(); writer.monitor=monitor; writer.configure(folder.path_join("clear-race")); writers.append(writer)
		tasks.append(WorkerThreadPool.add_task(func():
			var ok: bool=writer.save_entry(same_key,[],{"index":index},old_ticket); results_mutex.lock(); saved.append(ok); results_mutex.unlock()))
	await wait_count(monitor,1)
	var deadline:=Time.get_ticks_msec()+5000
	while int(Store.publication_snapshot().active.get(location.directory,0))<2 and Time.get_ticks_msec()<deadline: await process_frame
	check(monitor.count()==1,"Writers for the same destination remain serialized")
	var cleared: Dictionary={}; var clear_task:=WorkerThreadPool.add_task(func():cleared.merge(location.clear()))
	deadline=Time.get_ticks_msec()+5000
	while not Store.publication_snapshot().clearing.has(location.directory) and Time.get_ticks_msec()<deadline: await process_frame
	check(Store.publication_snapshot().clearing.has(location.directory),"Clear waits for active publication without holding metadata locks")
	monitor.resume.post(); await wait_tasks(tasks+[clear_task])
	check(saved.count(true)==1 and saved.count(false)==1 and DirAccess.get_files_at(location.directory).is_empty(),"Clear drains the active writer and rejects its old-generation queued duplicate")
	check(not location.save_entry(same_key,[],{"late":true},old_ticket),"Cleared-generation jobs cannot repopulate the folder")
	check(location.save_entry(same_key,[],{"fresh":true},location.generation()),"New-generation publication works after Clear")
	check(Store.publication_snapshot().entries==0 and Store.publication_snapshot().active.is_empty(),"All publication gates and active-write leases are released")
	var settings:=Settings.new(); root.add_child(settings); settings.setup(folder.path_join("settings.cfg"),""); settings.set_prework_sources(["Installed game + local content"],false)
	settings.prework_workers_changed.connect(owner.set_workers)
	var index:=settings.prework_workers.get_item_index(8); settings.prework_workers.select(index); settings.prework_workers.item_selected.emit(index)
	var restored:=Settings.new(); root.add_child(restored); restored.setup(folder.path_join("settings.cfg"),"")
	check(restored.prework_worker_setting==8 and owner.worker_count==8,"Worker selection persists and updates the running controller")
	var paths: Array=[]; owner.folder_opener=func(path: String) -> int: paths.append(path); return OK
	settings.prework_folder_requested.connect(func():owner.view_saved_files(folder.path_join("cache-4")))
	root.size=Vector2i(1100,800); settings.tabs.current_tab=settings.tabs.get_tab_count()-1; settings.show(); await process_frame; await process_frame
	await click(settings.prework_folder)
	check(paths.size()==1 and str(paths[0]).ends_with("/saved-prework-v1") and DirAccess.dir_exists_absolute(str(paths[0])),"View saved files routes an actual button click to the generated folder")
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(report+".png")
	owner.close(); owner.queue_free(); settings.queue_free(); restored.queue_free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"compatible_existing_entries":compatible,"workers":states,"scope":"Authored actual model processing with 1/4 workers; exact output equality, actual worker threads, bounded concurrency, live worker selection, cancellation/clear, independent and same-key write barriers, generation-safe concurrent flush, and View saved files routing. Timing samples are functional observations, not an Arelith speedup claim."}
	write(report,JSON.stringify(result,"\t").to_utf8_buffer()); print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures,"elapsed_ms":states.map(func(state):return state.elapsed_ms)})); quit(0 if failures.is_empty() else 1)
