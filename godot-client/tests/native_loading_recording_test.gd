extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recording=preload("res://systems/native_data/resource_recording.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir()); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-loading-record-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var original:=folder.path_join("original"); var recorded:=folder.path_join("catalog-1")
	var table:="2DA V2.0\n\nValue\n0 original\n".to_utf8_buffer()
	write(original.path_join("auth.2da"),table); write(original.path_join("unused.2da"),table)
	write(original.path_join("image.tga"),PackedByteArray([1,2,3])); write(original.path_join("image.dds"),PackedByteArray([4,5,6])); write(original.path_join("talk.tlk"),PackedByteArray([8,9,10]))
	var catalog:=Catalog.new(); check(catalog.mount_directory(original),"Authored original resource catalog mounts")
	var recorder:=Recording.new(); check(recorder.start(recorded,catalog.layers,{"base":original.path_join("talk.tlk")}),"Native writer starts outside workspace with complete availability index")
	catalog.recording=recorder; var copy=catalog.fork()
	check(copy.recording==recorder,"Worker catalog forks share only the native recording owner")
	var owner:=Assets.new(); root.add_child(owner); var results: Array=[]; owner.configure(catalog); owner.completed.connect(func(_id,result):results.append(result)); owner.request("auth",2017,"2da")
	var deadline:=Time.get_ticks_msec()+10000
	while results.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(results.size()==1 and results[0].error.is_empty() and results[0].thread!=OS.get_main_thread_id(),"Actual native data worker reads and decodes the source while recording")
	check(copy.get_resource("image",3)==PackedByteArray([1,2,3]),"Independent fork records original texture bytes")
	copy.get_resource("missing",2017); check(not copy.failure.is_empty(),"Absent original reads retain their failure")
	owner.close(); owner.queue_free(); var sealed:=recorder.close(); catalog.recording=null; copy.recording=null
	check(sealed.complete and sealed.resources==3,"Close drains actual writer and seals every observed resource/read failure")
	var frozen:=Recorded.new(); check(frozen.mount(recorded),"Sealed native recorded catalog mounts without an install or server")
	check(frozen.has_resource("unused",2017) and not frozen.has_resource("missing",2017),"Complete original existence is distinct from which payloads were actually requested")
	check(frozen.raster_location("image")==catalog.raster_location("image"),"Native storage-class/format preference is preserved even for unread format alternatives")
	check(frozen.get_resource("auth",2017)==table,"Replay reads exactly recorded original bytes")
	frozen.get_resource("unused",2017); check(frozen.failure.begins_with("Unrecorded native resource"),"Unrecorded dependency fails explicitly instead of installed/network fallback")
	frozen.get_resource("missing",2017); check(frozen.failure.contains("Resource not found"),"Original recorded read failure remains a failure")
	check(FileAccess.get_file_as_bytes(frozen.talk_path("base"))==PackedByteArray([8,9,10]),"Direct TLK input is frozen with resource bytes")
	write(original.path_join("auth.2da"),"changed".to_utf8_buffer()); check(frozen.fork().get_resource("auth",2017)==table,"Changing installed/loose sources after sealing cannot affect replay")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(recorded.path_join("manifest.json"))); var digest: String=manifest.resources["auth:2017"].sha256
	write(recorded.path_join("objects").path_join(digest),PackedByteArray([0])); frozen.get_resource("auth",2017)
	check(frozen.failure.contains("unavailable or changed"),"Modified recorded payload is rejected")
	var bounded:=Recording.new(); bounded.maximum_queued_bytes=1; bounded.start(folder.path_join("incomplete"),catalog.layers); bounded.record("auth",2017,table,"")
	check(not bounded.close().complete and not Recorded.new().mount(folder.path_join("incomplete")),"Capture overflow cannot masquerade as a complete replay")
	await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"fixture":folder,"network_connections":0,"scope":"Native file-backed catalog forks, real data worker, dedicated capture writer, complete existence/classes, exact frozen bytes/TLK, failures, mutation and queue overflow. Authored resources only; no public/cold-world performance acceptance."},"\t")); file.close(); print("NATIVE_LOADING_RECORDING ",checks," checks"); quit(0 if failures.is_empty() else 1)
