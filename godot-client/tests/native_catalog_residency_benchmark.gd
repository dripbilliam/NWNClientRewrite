extends SceneTree
const Sources=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Discovery=preload("res://systems/native_data/prework_sources.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var sources: Dictionary={"install":args.install}
	if args.has("sources"):
		var supplied: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.sources)))
		if not supplied is Dictionary: quit(2); return
		sources=supplied
	var downloaded: Dictionary={}
	if args.has("downloaded"):
		var profile:=str(sources.get("profileDirectory","")); var discovery:=sources.duplicate(true)
		discovery.cacheDirectory=profile.path_join("replacement-client/server-content"); discovery.nativeDirectory=profile.path_join("nwsync"); discovery.helper=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
		var found:=Discovery.discover(discovery)
		for choice in found.choices:
			if str(choice.label).to_lower().contains(str(args.downloaded).to_lower()) and choice.has("hash"):
				sources=choice.sources; downloaded={"label":choice.label,"hash":choice.hash}; break
		if downloaded.is_empty(): push_error("Requested previously downloaded local content is unavailable"); quit(2); return
	var private_raw:=""
	if args.get("private-raw","")=="true":
		private_raw=OS.get_temp_dir().path_join("nwn-resource-benchmark-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); sources.rawCacheDirectory=private_raw
	Writes.acquire()
	var samples: Array=[]; var previous: Dictionary={}; var bindings: Array=[]
	for iteration in 3:
		var began:=Time.get_ticks_usec()
		var result:=Sources.prepare(sources)
		check(str(result.error).is_empty(),"Original installed catalog prepares: "+str(iteration))
		if not str(result.error).is_empty(): break
		var catalog=result.catalog; var sample:={"iteration":iteration,"mount_ms":(Time.get_ticks_usec()-began)/1000.0,"catalog":result.stats}
		if iteration==0:
			# Read several real resource types through the same resolver. No scene,
			# renderer, network traffic or guessed dependencies are involved.
			for type in [2002,3,2033,4,2017,2047,2013,2022,2060]:
				var names: Array=catalog.resource_names(type); names.sort()
				for index in mini(3,names.size()): bindings.append([str(names[index]),type])
		began=Time.get_ticks_usec(); var values: Dictionary={}
		for binding in bindings:
			var bytes: PackedByteArray=catalog.get_resource(binding[0],binding[1])
			check(catalog.failure.is_empty(),"Original resource reads: "+str(binding))
			values[str(binding)]=Cache.digest(bytes)
		sample.source_ms=(Time.get_ticks_usec()-began)/1000.0; sample.types=bindings.map(func(binding):return binding[1]); sample.reads=catalog.stats.duplicate()
		var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
		var raw: PackedByteArray=catalog.get_resource("classes",2017)
		began=Time.get_ticks_usec(); var decoded: Dictionary=assets.decode(raw,2017,"2da","",catalog.decoded_cache(),true)
		sample.class_decode_ms=(Time.get_ticks_usec()-began)/1000.0; sample.decode_hit=decoded.get("memory_decode_hit",false)
		check(str(decoded.error).is_empty(),"Original class table decodes: "+str(iteration))
		if iteration>0: check(values==previous,"Repeated catalogs resolve exactly the same bytes for every sampled resource type")
		previous=values; samples.append(sample); assets.close(); assets.free(); catalog=null; result={}; await process_frame
	Writes.release()
	var writer:=Writes.snapshot()
	if not private_raw.is_empty():
		var folder:=DirAccess.open(private_raw); var cleaned:=folder!=null
		if folder!=null:
			for name in folder.get_files():
				if name.length()!=44 or not name.ends_with(".raw") or folder.is_link(name): cleaned=false; continue
				cleaned=DirAccess.remove_absolute(private_raw.path_join(name))==OK and cleaned
		check(cleaned and DirAccess.remove_absolute(private_raw)==OK,"Exact owned private raw-cache files and their empty directory are removed after the writer joins")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"bindings":bindings,"downloaded":downloaded,"writer":writer,"raw_cache_directory":private_raw if not private_raw.is_empty() else ProjectSettings.globalize_path("user://native-original-bytes-v1"),"private_raw_initially_empty":not private_raw.is_empty(),"publicConnections":0,"scope":"Same-process locally mounted resource catalog, exact byte identities across resource types and table decoder residency. Optional downloaded content is read from existing local storage without downloads or server connections. Descriptive CPU timings; no FPS or original-executable speed acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
