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
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Recorded.new(); check(catalog.mount(str(args.catalog)),"Exact sealed table corpus mounts without network/installed fallback")
	var assets:=Assets.new(); root.add_child(assets)
	var directory:=OS.get_temp_dir().path_join("nwn-native-table-cost-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var samples: Array=[]; var written: Array=[]
	var cache:=Cache.new(); check(cache.configure(directory),"Generic comparison cache is private and outside source")
	for name in ["appearance","spells","feat","gender","baseitems"]:
		var bytes:=catalog.get_resource(name,2017)
		check(catalog.failure.is_empty(),"Exact table is available: "+name)
		var began:=Time.get_ticks_usec(); var direct:=assets.decode_uncached(bytes,2017,"2da",""); var parse_ms:=(Time.get_ticks_usec()-began)/1000.0
		var source_sha:=Cache.digest(bytes); var key:=Cache.key(source_sha,"table-cost-reference")
		written.append(cache.filename(key))
		began=Time.get_ticks_usec(); var saved:=cache.save_data(key,source_sha,"table-cost-reference",direct.value); var save_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); var loaded:=cache.load_data(key,source_sha,"table-cost-reference"); var warm_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(str(direct.error).is_empty() and saved and not loaded.is_empty(),"Direct parse, generic reference publication and verified reload succeed: "+name)
		var identity:=Cache.digest(var_to_bytes(direct.value))
		check(Cache.digest(var_to_bytes(loaded))==identity,"Every reference column/default/physical cell/row is unchanged: "+name)
		var current:=assets.decode_uncached(bytes,2017,"2da",directory)
		check(not current.cache_hit and current.timings.cache_read_ms==0 and current.timings.cache_write_ms==0 and Cache.digest(var_to_bytes(current.value))==identity,"Production decodes exact source without expanded derivative disk I/O: "+name)
		samples.append({"name":name,"source_bytes":bytes.size(),"serialized_bytes":var_to_bytes(direct.value).size(),"source_sha256":source_sha,"parse_ms":parse_ms,"generic_save_ms":save_ms,"generic_warm_ms":warm_ms,"production_timings":current.timings})
	assets.close(); assets.queue_free(); await process_frame; await process_frame
	# Remove only the exact content files this fixture created, then the empty
	# owned directory. No recursive deletion or shared user-cache cleanup.
	for path in written: DirAccess.remove_absolute(path)
	var removed:=DirAccess.remove_absolute(directory)==OK
	check(removed,"Owned generic reference cache is removed after the comparison")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"cache_directory":directory,"cache_removed":removed,"publicConnections":0,"scope":"Native table parse versus generic verified Variant cache economics; descriptive timings, not an FPS or original-binary speed comparison"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
