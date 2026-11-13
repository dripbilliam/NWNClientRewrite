extends SceneTree
const Source=preload("res://systems/native_data/native_clock_source.gd")
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
var checks:=0
var failures: Array=[]
var report:=""
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func write_bytes(file_path: String,bytes: PackedByteArray)->void:
	var file:=FileAccess.open(file_path,FileAccess.WRITE)
	if file==null:check(false,"Owned copy can be written: "+file_path);return
	file.store_buffer(bytes);file.close()
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(not ClassDB.class_exists(Source.NATIVE_CLASS),"Copied project has no automatic extension registration")
	check(not GDExtensionManager.is_extension_loaded(Source.DESCRIPTOR),"Ignored descriptor is not in an editor extension list")
	var descriptor:=FileAccess.get_file_as_bytes(Source.DESCRIPTOR)
	var library:=FileAccess.get_file_as_bytes(Source.LIBRARY)
	check(descriptor.get_string_from_utf8()==Source.DESCRIPTOR_TEXT,"Copied descriptor is exact")
	check(FileAccess.get_sha256(Source.LIBRARY)==Source.LIBRARY_SHA256,"Copied reviewed DLL is exact")
	write_bytes(Source.DESCRIPTOR,"not a reviewed descriptor".to_utf8_buffer())
	var changed_descriptor:=Source.new()
	check(not changed_descriptor.initialize().ready and changed_descriptor.read()==null,"Changed descriptor cannot load or return a fake zero")
	check(not ClassDB.class_exists(Source.NATIVE_CLASS),"Changed descriptor never registers code")
	write_bytes(Source.DESCRIPTOR,descriptor)
	write_bytes(Source.LIBRARY,PackedByteArray([0,1,2,3]))
	var changed_library:=Source.new()
	check(not changed_library.initialize().ready and changed_library.read()==null,"Changed library cannot load or return a fake zero")
	check(not ClassDB.class_exists(Source.NATIVE_CLASS),"Changed library never registers code")
	write_bytes(Source.LIBRARY,library)
	check(FileAccess.get_sha256(Source.LIBRARY)==Source.LIBRARY_SHA256,"Owned negative fixture restores only its copied DLL")
	var source:=Source.new()
	check(source.initialize().ready,"Explicit owner loads exact ignored descriptor without touching extension_list")
	check(GDExtensionManager.is_extension_loaded(Source.DESCRIPTOR) and ClassDB.class_exists(Source.NATIVE_CLASS),"Expected descriptor owns actual registered native class")
	check(source.initialize().ready and source.samples==0,"Repeated initialization does not sample or reload")
	var first: Variant=source.read()
	check(first is Dictionary and not NativeWorldTimer.words(first).is_empty(),"Actual Win32 source supplies exact unsigned words")
	if not first is Dictionary:finish(source);return
	var recorded:=source.state_view()
	check(recorded.phase=="direct-real-only" and recorded.lastSample.microseconds==first and recorded.samples==1,"Actual direct-Real sample has measured source metadata")
	first.lo=int(first.lo)^1
	check(source.state_view().lastSample.microseconds!=first,"Returned words cannot mutate retained measured state")
	recorded.lastSample.microseconds.lo=int(recorded.lastSample.microseconds.lo)^1
	check(source.state_view().lastSample.microseconds!=recorded.lastSample.microseconds,"Diagnostic nested data is detached")
	var clocks: Array=[]
	for _index in 3:
		var native_clock:=NativeWorldTimer.new();clocks.append(native_clock)
		check(native_clock.initialize(source.read).ready,"A process service timer constructs from this actual absolute provider")
		check(native_clock.counter==source.state_view().lastSample.microseconds,"Timer stores the exact actual sample without origin conversion")
		check(native_clock.microseconds.get_object()==source,"Each timer retains the same explicit source owner")
	await process_frame
	for native_clock in clocks:
		check(native_clock.snapshot().ready,"Actual provider advances an existing process timer")
		check(native_clock.counter==source.state_view().lastSample.microseconds,"Frame snapshot preserves full unsigned words")
		check(NativeWorldTimer.frame_seconds_from_difference(native_clock.snapshot_difference().microseconds).ready,"Native signed-lowDWORD GUI conversion accepts actual difference")
		native_clock.close()
		check(not native_clock.initialized and source.library_ready,"Timer closes only its own state")
	var second_owner:=Source.new()
	check(second_owner.initialize().ready and second_owner.read() is Dictionary,"A later owner reuses the same already validated process extension")
	check(second_owner.samples==1 and source.samples==7,"Measurement counters stay instance-local while the native source is process-owned")
	check(FileAccess.get_sha256(Source.LIBRARY)==Source.LIBRARY_SHA256 and FileAccess.get_file_as_string(Source.DESCRIPTOR)==Source.DESCRIPTOR_TEXT,"Owned fixture files match input bytes after negative cases")
	finish(source)
func finish(source)->void:
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"source":source.state_view(),"scope":"Copied native provider ownership and exact descriptor/DLL validation, actual direct-Real Win32 samples into three actual timers. No main installation, native build, original process, cached-thread equivalence, server/profile/key/GPU or visual acceptance."})+"\n");file.close()
	print("NATIVE_CLOCK_SOURCE_OWNER ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
