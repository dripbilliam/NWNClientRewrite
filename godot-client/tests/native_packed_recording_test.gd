extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var original:=Recorded.new(); var packed:=Recorded.new()
	check(original.mount(str(args.fixture).path_join("source/catalog-1")),"Original sealed fixture mounts")
	check(packed.mount(str(args.fixture).path_join("clone/catalog-1")),"Benchmark mounts a real native-readable ERF index")
	check(packed.packed_catalog!=null and packed.packed_catalog.layers[0].entries.size()==7,"Native archive parser indexes complete captured namespace")
	check(packed.manifest.availability==original.manifest.availability,"Original winning storage classes are preserved independently of synthetic storage")
	for key in ["table:2017","alias:2017","zero:4","long_reference_12345678901234567:2022","žtest:2047"]:
		var pair: PackedStringArray=key.rsplit(":",true,1); var expected: PackedByteArray=original.get_resource(pair[0],int(pair[1])); var actual: PackedByteArray=packed.get_resource(pair[0],int(pair[1]))
		check(original.failure.is_empty() and packed.failure.is_empty() and expected==actual,"Exact native demand read including aliases, CP1252, zero length and 32-byte names: "+key)
	check(packed.fork().get_resource("table",2017)==original.get_resource("table",2017),"Independent worker fork shares metadata and reads original bytes")
	packed.get_resource("unused",2002); check(packed.failure.begins_with("Unrecorded native resource"),"Unread namespace entry remains a capture gap, never a zero-byte placeholder")
	packed.get_resource("failed",3); check(packed.failure=="original read error","Original read error is retained")
	check(FileAccess.get_file_as_bytes(packed.talk_path("base"))==FileAccess.get_file_as_bytes(original.talk_path("base")),"Direct talk-file source is identical")
	var source:=str(args.fixture).path_join("clone/catalog-1/resources.erf"); var file:=FileAccess.open(source,FileAccess.READ_WRITE); file.seek(file.get_length()-1); var last:=file.get_8(); file.seek(file.get_length()-1); file.store_8(last^1); file.close()
	var corrupted:=Recorded.new(); check(corrupted.mount(str(args.fixture).path_join("clone/catalog-1")),"Payload-only edit does not require a different namespace")
	corrupted.get_resource("table",2017); check(corrupted.failure.contains("checksum differs") or corrupted.failure.contains("changed"),"Fresh demand rejects a modified archived captured payload")
	file=FileAccess.open(source,FileAccess.READ_WRITE); file.seek(file.get_length()-1); file.store_8(last); file.close()
	var report:=FileAccess.open(args.report,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Authored recording cloned into real ERF indexes/demand reads, identical payloads, preserved presence/classes/failures/forks/TLK, and corruption rejection"})); report.close(); quit(0 if failures.is_empty() else 1)
