extends SceneTree
const ProcessOwner=preload("res://systems/native_prework_process.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
class Artwork:
	extends Node
	var closed:=false
	var cache_directory:=""
	var prework_records:={"authored":true}
	var packet: Dictionary={}
	func prework_packet(_key: String) -> Dictionary: return packet
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func wait_done(owner) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while owner.state.active and Time.get_ticks_msec()<deadline:
		await process_frame
	check(not owner.state.active,"Isolated preparation action drains")
	check(owner.service==null and owner.source_loader==null,"Frontend owns no model preparation service or catalog worker")
func wait_child(owner) -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while owner.child_pid<0 and owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(owner.child_pid>0 and owner.child_pid!=OS.get_process_id(),"Preparation runs in a separate owned engine process")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-prework-process-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var recorded:=folder.path_join("recorded"); DirAccess.make_dir_recursive_absolute(recorded.path_join("objects"))
	var availability: Dictionary={}; var resources: Dictionary={}; var hashes: Dictionary={}
	for index in 4:
		var name:="shape"+str(index); var raw:=("newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n").to_utf8_buffer(); var sha:=Cache.digest(raw)
		write(recorded.path_join("objects").path_join(sha),raw); availability[name+":2002"]=2; resources[name+":2002"]={"sha256":sha,"bytes":raw.size()}; hashes[name]=sha
	write(recorded.path_join("manifest.json"),JSON.stringify({"version":2,"complete":true,"availability":availability,"resources":resources}).to_utf8_buffer())
	var cache_path:=folder.path_join("cache"); var sources:={"recordedCatalog":recorded}
	var owner:=ProcessOwner.new(); root.add_child(owner); owner.set_workers(1)
	var options:={"relevant_tracks":true,"palette_colors":[1,2,3,4,5,6]}
	owner.extra_variants=[{"name":"shape0","type":2002,"decoder":"actor-model","options":options}]
	var art:=Artwork.new(); root.add_child(art); art.cache_directory=cache_path; art.add_to_group("native_prework_icons")
	var icon_key:=Cache.key("authored-icon","isolation-test")
	art.packet={"key":icon_key,"inputs":[],"data":{"width":1,"height":1,"pixels":PackedByteArray([255,100,25,255]),"bounds":{"min":[0.0,0.0],"max":[1.0,1.0]}}}
	check(owner.start_sources(sources,cache_path),"Isolated preparation starts")
	await wait_child(owner); owner.set_workers(8); await wait_done(owner)
	check(int(owner.state.saved)==10 and int(owner.state.failed)==0,"Background process saves all model variants and transported UI artwork")
	check(int(owner.state.workers)==8 and int(owner.state.get("peak_running",0))>1,"Live worker selection reaches the background process")
	var store:=Store.new(); store.configure(cache_path)
	var icon:=store.cache.load_data(icon_key,icon_key,Store.REVISION)
	check(icon.get("data",{}).get("pixels")==art.packet.data.pixels,"Cross-process artwork retains exact pixels")
	var decoder:=Assets.new(); var expected:=Store.request_key("shape0",2002,"actor-model",options,str(hashes.shape0),[decoder.mesh_preparation_enabled,decoder.skin_preparation_enabled,decoder.mesh_revision()]); decoder.free()
	check(not store.cache.load_data(expected,expected,Store.REVISION).is_empty(),"Appearance options retain exact integer types and live-session cache identities")
	var completed_state:=owner.state.duplicate(true)
	var runtime: Dictionary=completed_state.get("engine_runtime",{})
	check(runtime.get("editor")==OS.has_feature("editor") and runtime.get("debug")==OS.is_debug_build(),"Background worker uses the selected editor or packaged release runtime")
	# JSON carries version-number fields as floats; compare the immutable
	# version/build identity without mistaking that transport type for a change.
	var child_version: Dictionary=runtime.get("version",{}); var parent_version:=Engine.get_version_info()
	check(child_version.get("hash")==parent_version.hash and child_version.get("string")==parent_version.string and child_version.get("build")==parent_version.build and int(child_version.get("hex",-1))==int(parent_version.hex),"Background worker retains the exact parent engine version")
	check(owner.start_sources(sources,cache_path),"A later isolated run can start")
	await wait_child(owner)
	var failed_pid: int=owner.child_pid; OS.kill(failed_pid); await wait_done(owner)
	check(str(owner.state.message).contains("worker stopped unexpectedly") and not OS.is_process_running(failed_pid),"A failed preparation process leaves the client alive and reports the failure")
	check(FileAccess.file_exists(store.cache.filename(expected)),"Worker failure preserves completed prework")
	owner.start_sources(sources,cache_path); await wait_child(owner); owner.cancel(); await wait_done(owner)
	check(str(owner.state.message).begins_with("Preparation cancelled"),"Cancel drains the separate worker")
	owner.start_sources(sources,cache_path); await wait_child(owner); owner.clear_saved(cache_path); await wait_done(owner)
	check(DirAccess.get_files_at(store.directory).is_empty(),"Clear waits for the process to exit before removing generated files")
	owner.close(); owner.queue_free(); art.queue_free(); await process_frame; await process_frame
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed_state,"public_connections":0,"scope":"Real isolated worker process, exact model/appearance/icon persistence, live worker control, failure containment, cancel and flush; no server connections"}
	write(report,JSON.stringify(output,"\t").to_utf8_buffer()); print(JSON.stringify({"success":output.success,"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
