extends SceneTree
const Catalog=preload("res://systems/native_data/capture_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason)
func write_file(path: String, bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func authored(root_path: String, events: PackedByteArray, resources: Dictionary, textures: Dictionary, source: Dictionary={}) -> void:
	DirAccess.make_dir_recursive_absolute(root_path.path_join("objects")); write_file(root_path.path_join("events.bin"),events)
	write_file(root_path.path_join("manifest.json"),JSON.stringify({"version":1,"complete":true,"eventsSha256":Cache.digest(events),"contexts":{"context-1":{"resources":resources,"textures":textures}}}).to_utf8_buffer())
	if not source.is_empty(): write_file(root_path.path_join("source.json"),JSON.stringify(source).to_utf8_buffer())
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var directory:=OS.get_temp_dir().path_join("nwn-native-capture-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var bytes: PackedByteArray="Authored raw original-resource stand-in".to_utf8_buffer(); var identity:=Cache.digest(bytes); var events: PackedByteArray="Authored timeline checksum fixture".to_utf8_buffer()
	var entry: Dictionary={"bytes":bytes.size(),"sha256":identity}
	authored(directory,events,{"auth_raster:3":entry,"expected_miss:3":{"missing":true,"code":"RESOURCE_NOT_FOUND"},"empty:4":{"bytes":0,"sha256":Cache.digest(PackedByteArray())}},{"auth_raster":3,"expected_miss":null})
	write_file(directory.path_join("objects").path_join(identity),bytes); write_file(directory.path_join("objects").path_join(Cache.digest(PackedByteArray())),PackedByteArray())
	var supplement:=directory+"-supplement"
	authored(supplement,PackedByteArray(),{"extra:4":entry,"expected_miss:3":entry},{"expected_miss":3},{"version":1,"parentEventsSha256":Cache.digest(events)})
	write_file(supplement.path_join("objects").path_join(identity),bytes)
	var catalog:=Catalog.new()
	check(catalog.mount(directory,"context-1",[supplement]),"Native capture and matching supplement mount: "+catalog.failure)
	check(catalog.get_resource("AUTH_RASTER",3)==bytes and catalog.failure.is_empty(),"Raw capture bytes resolve case-insensitively and hash-verify")
	check(catalog.get_resource("extra",4)==bytes and catalog.failure.is_empty(),"Frozen supplement supplies only unrecorded keys")
	check(catalog.get_resource("expected_miss",3).is_empty() and not catalog.failure.is_empty() and not catalog.has_resource("expected_miss",3),"Original recorded miss stays authoritative over supplement")
	check(catalog.raster_location("expected_miss").is_empty() and int(catalog.raster_location("auth_raster").get("type",-1))==3,"Recorded texture choice/miss stays authoritative")
	check(catalog.recorded_texture_miss("expected_miss") and not catalog.recorded_texture_miss("unrecorded") and not catalog.recorded_texture_miss("auth_raster"),"Explicit original missing texture is distinguished from unrecorded coverage")
	check(catalog.has_resource("empty",4) and catalog.get_resource("empty",4).is_empty() and catalog.failure.is_empty(),"Zero-length captured resource exists")
	check(catalog.get_resource("unrecorded",4).is_empty() and not catalog.failure.is_empty(),"Unrecorded resource fails without installation or network fallback")
	var fork=catalog.fork(); check(fork.get_resource("extra",4)==bytes and fork.failure.is_empty(),"Native workers get independent capture reader state")
	write_file(directory.path_join("objects").path_join(identity),"corrupt".to_utf8_buffer())
	check(catalog.get_resource("auth_raster",3).is_empty() and not catalog.failure.is_empty(),"Changed size rejects captured object")
	var wrong:=bytes.duplicate(); wrong[0]^=1; write_file(directory.path_join("objects").path_join(identity),wrong)
	check(catalog.get_resource("auth_raster",3).is_empty() and not catalog.failure.is_empty(),"Changed bytes with same size reject captured object")
	write_file(directory.path_join("objects").path_join(identity),bytes)
	write_file(directory.path_join("events.bin"),"wrong timeline".to_utf8_buffer())
	check(not Catalog.new().mount(directory,"context-1"),"Changed timeline checksum prevents mount")
	write_file(directory.path_join("events.bin"),events)
	check(not Catalog.new().mount(directory,"other"),"Unknown recorded context fails")
	write_file(supplement.path_join("source.json"),JSON.stringify({"version":1,"parentEventsSha256":"0".repeat(64)}).to_utf8_buffer())
	check(not Catalog.new().mount(directory,"context-1",[supplement]),"Supplement from another capture fails")
	var original: Dictionary={}
	if args.has("capture") and args.has("supplement"):
		var captured:=Catalog.new(); check(captured.mount(args.capture,"context-1",[args.supplement]),"Actual original capture and frozen supplement mount natively: "+captured.failure)
		original={"resource_layers":captured.layers.size(),"models":captured.resource_names(2002).size(),"tilesets":captured.resource_names(2013),"events_sha256":captured.events_sha256,"decode_samples":[]}
		for name in captured.resource_names(2002).slice(0,8):
			var raw: PackedByteArray=captured.get_resource(name,2002)
			check(captured.failure.is_empty(),"Actual captured original resource verifies: "+str(name))
			var parser:=Model.new(); var value:=parser.parse(raw)
			original.decode_samples.append({"name":name,"bytes":raw.size(),"sha256":Cache.digest(raw),"binary_decoded":parser.failure.is_empty(),"nodes":value.get("nodes",[]).size(),"limitation":parser.failure})
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"scope":"Native raw captured-resource mount only; no V8 timeline decode, scene preparation, network or GPU benchmark","actual_capture":original,"sourceSha256":{"systems/native_data/capture_catalog.gd":FileAccess.get_sha256("res://systems/native_data/capture_catalog.gd"),"tests/native_capture_catalog_test.gd":FileAccess.get_sha256("res://tests/native_capture_catalog_test.gd")}}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
