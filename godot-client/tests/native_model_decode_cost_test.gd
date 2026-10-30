extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original model corpus mounts without installed/network fallback")
	var observations: Array=[]
	for name in ["a_ba","a_ba_custom","h_ba_custom","pme0"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002)
		check(not bytes.is_empty() and catalog.failure.is_empty(),"Verified captured source opens: "+name)
		if bytes.is_empty(): continue
		var binary:=bytes.size()>=4 and bytes.decode_u32(0)==0
		var reader:=Binary.new(bytes); var began:=Time.get_ticks_usec(); var text:=""
		if binary:
			for index in 2000: text=reader.text(20,64,true)
		else: text=reader.text(0,bytes.size())
		var text_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); var latin:=""
		if not binary: latin=bytes.get_string_from_ascii()
		var latin_ms:=(Time.get_ticks_usec()-began)/1000.0
		var parser:=Actor.new(); parser.packed_keys=true
		began=Time.get_ticks_usec(); var model: Dictionary=parser.parse(bytes); var parse_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(not model.is_empty() and parser.failure.is_empty(),"Actual packed native actor parser succeeds: "+name)
		observations.append({"name":name,"bytes":bytes.size(),"binary":binary,"text_ms":text_ms,"text_iterations":2000 if binary else 1,"ascii_latin_ms":latin_ms if not binary else null,"ascii_equals_cp1252":text==latin if not binary else null,"parse_ms":parse_ms,"nodes":model.get("nodes",[]).size(),"animations":model.get("animations",[]).size()})
		model.clear(); bytes=PackedByteArray(); reader=null; parser=null
		await process_frame
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"scope":"Isolated original captured raw model parse/text phase measurements, packed key path, no inheritance/rig/GPU/full-world timing or FPS acceptance. Binary text micro repeats the actual model-header conversion to expose per-name overhead."},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
