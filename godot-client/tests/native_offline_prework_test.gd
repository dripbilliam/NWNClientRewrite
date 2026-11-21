extends SceneTree
const Controller=preload("res://systems/native_asset_prework.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func wait_done(owner) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"Offline preparation/cancel/clear drains its workers")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-offline-prework-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var recorded:=folder.path_join("recorded"); DirAccess.make_dir_recursive_absolute(recorded.path_join("objects"))
	var raw:="newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n".to_utf8_buffer()
	var sha:=Cache.digest(raw); write(recorded.path_join("objects").path_join(sha),raw)
	write(recorded.path_join("manifest.json"),JSON.stringify({"version":2,"complete":true,"availability":{"authored:2002":2},"resources":{"authored:2002":{"sha256":sha,"bytes":raw.size()}}}).to_utf8_buffer())
	var offline:={"recordedCatalog":recorded}; var cache_path:=folder.path_join("cache")
	var owner:=Controller.new(); root.add_child(owner)
	check(owner.start_sources(offline,cache_path),"Offline preparation accepts the recorded catalog")
	await wait_done(owner)
	check(int(owner.state.saved)==2 and int(owner.state.failed)==0,"Offline preparation indexes sources and persists static/animated model routes")
	check(owner.owned_catalog==null and owner.source_loader==null,"Offline source ownership is released after preparation")
	owner.start_sources(offline,cache_path); await wait_done(owner)
	check(int(owner.state.reused)==2,"A subsequent offline action reuses saved model bundles")
	owner.start_sources(offline,cache_path); owner.cancel(); await wait_done(owner)
	check(str(owner.state.message).begins_with("Preparation cancelled"),"Cancellation is valid while offline catalog indexing is in flight")
	owner.start_sources(offline,cache_path); owner.clear_saved(cache_path); await wait_done(owner)
	check(str(owner.state.message).begins_with("Cleared") and DirAccess.get_files_at(owner.store.directory).is_empty(),"Clear during offline indexing cancels admission and deletes only saved prework")
	owner.close(); owner.queue_free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Offline recorded catalog mounting, persistent model preparation, repeat reuse, and cancellation and clearing during indexing"}
	write(report,JSON.stringify(result,"\t").to_utf8_buffer()); print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
