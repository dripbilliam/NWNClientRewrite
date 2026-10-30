extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func prepare(corpus: String,name: String,directory: String) -> Dictionary:
	# Every call mounts a new catalog and creates new decoding stores. The only
	# reused tier is verified disk data; no previous live actor/graph is reused.
	var reader:=Recorded.new()
	if not reader.mount(corpus): return {"error":reader.failure}
	var service:=Assets.new(); root.add_child(service)
	var bytes:=reader.get_resource(name,2002); var began:=Time.get_ticks_usec()
	var result:=service.actor_data(reader,name,bytes,directory,[],{})
	result.measured_ms=(Time.get_ticks_usec()-began)/1000.0
	service.close(); service.queue_free()
	return result
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var directory:=OS.get_temp_dir().path_join("nwn-native-persistent-actor-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var samples: Array=[]
	for name in ["pme0","c_nulltail","pme0_chest025"]:
		var cold:=prepare(args.catalog,name,directory); var warm:=prepare(args.catalog,name,directory)
		check(str(cold.error).is_empty() and str(warm.error).is_empty(),"Fresh owners prepare exact original model and ancestors: "+name)
		if not str(cold.error).is_empty() or not str(warm.error).is_empty(): continue
		check(Cache.digest(var_to_bytes(cold.value))==Cache.digest(var_to_bytes(warm.value)) and cold.animation_sources==warm.animation_sources,"Persistent data preserves every composed node/skin/clip/controller/source identity: "+name)
		check(warm.preparation_sources.all(func(row):return not row.memory_hit and row.timings.decode_ms==0 and row.timings.cache_read_ms>0 and row.timings.cache_write_ms==0),"Fresh owner reads every ancestor from verified disk without reparsing: "+name)
		check(not is_same(cold.value,warm.value),"Persistence does not alias live owner model wrappers: "+name)
		samples.append({"name":name,"cold_ms":cold.measured_ms,"warm_ms":warm.measured_ms,"sources":warm.preparation_sources.size(),"source_names":warm.preparation_sources.map(func(row):return row.name)})
	await process_frame; await process_frame
	var files: Array=Array(DirAccess.get_files_at(directory)); var owned: bool=files.size()>0 and files.all(func(name):return str(name).ends_with(".bin") and str(name).trim_suffix(".bin").length()==64 and str(name).trim_suffix(".bin").is_valid_hex_number()) and DirAccess.get_directories_at(directory).is_empty()
	check(owned,"Only exact generated content-addressed cache files occupy the owned directory")
	if owned:
		for name in files: DirAccess.remove_absolute(directory.path_join(name))
	check(owned and DirAccess.remove_absolute(directory)==OK,"Fixture removes its own files and empty directory without recursive user-cache deletion")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Fresh native model/catalog owners over exact frozen original bytes, persistent verified parsed data and composed graph equivalence. OS caches not flushed; not whole-world or FPS acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
