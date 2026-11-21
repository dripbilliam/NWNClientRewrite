extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Session resource discovery runs off the presentation thread. The descriptor
# contains local paths and server-selected manifest identities, not meshes,
# textures, scene data or a JavaScript resource resolver.
signal completed(serial: int, catalog: RefCounted, error: String, stats: Dictionary)
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Workshop=preload("res://systems/native_data/workshop_index.gd")
const Extensions=preload("res://systems/native_data/resource_extensions.gd")
const TalkTable=preload("res://systems/native_data/talk_table.gd")
const ResourceAdmission=preload("res://systems/native_data/native_resource_admission.gd")
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
const ItemIconSources=preload("res://systems/native_data/item_icon_sources.gd")
const SpellbookIconSources=preload("res://systems/native_data/spellbook_icon_sources.gd")
var task:=-1
var serial:=0
var result: Dictionary={}
var progress_state: Dictionary={"phase":"catalog","completed":0,"total":0}
var mutex:=Mutex.new()
var stop_requested:=true
func start(sources: Dictionary) -> int:
	close(); serial+=1
	var owned:=sources.duplicate(true); var scope:=serial
	mutex.lock(); stop_requested=false; progress_state={"phase":"catalog","completed":0,"total":0}; mutex.unlock()
	task=WorkerThreadPool.add_task(func():
		var prepared:=prepare(owned,cancellation_requested,report_progress)
		mutex.lock(); result={"serial":scope,"prepared":prepared}; mutex.unlock(),false,"Native session resource catalog")
	return serial
func cancel() -> void:
	mutex.lock(); stop_requested=true; mutex.unlock()
func cancellation_requested() -> bool:
	mutex.lock(); var value:=stop_requested; mutex.unlock(); return value
func report_progress(phase: String,completed: int,total: int) -> void:
	mutex.lock(); progress_state={"phase":phase,"completed":completed,"total":total}; mutex.unlock()
func progress() -> Dictionary:
	mutex.lock(); var value:=progress_state.duplicate(); mutex.unlock(); return value
static func stopped(guard: Callable,catalog: RefCounted,began: int,phase: String) -> Dictionary:
	if not guard.is_valid() or not guard.call(): return {}
	return {"catalog":catalog,"error":"Native catalog preparation cancelled","stats":{"cancelled":true,"phase":phase,"mount_ms":(Time.get_ticks_usec()-began)/1000.0,"layers":catalog.layers.size(),"rendering_prepared":false}}
static func validate_custom_tlk(source: Variant,catalog: RefCounted,profile: String="") -> Dictionary:
	if not source is Dictionary or source.is_empty(): return {}
	var name:=str(source.get("name","")).get_file().to_lower().trim_suffix(".tlk")
	if name.is_empty(): return {"error":"Selected custom TLK name is invalid"}
	var path:=str(source.path) if source.get("path") is String else ""
	var table:=TalkTable.new()
	var male_opened:=false
	if path.is_empty():
		var bytes: PackedByteArray=catalog.get_resource(name,2018)
		if not catalog.failure.is_empty():
			var repair: Dictionary=catalog.nwsync_repair_binding(name,2018)
			return {"error":"Selected custom TLK read failed: "+catalog.failure,"repair":repair}
		male_opened=table.open_bytes(bytes)
	else:male_opened=table.open_file(path)
	var reason:=table.failure;table.close()
	if not male_opened:return {"error":"Selected custom TLK is invalid: "+reason}
	var female_name:=name+"f"
	var female_path: String=""
	var indexes: Dictionary={}
	if not path.is_empty():
		var sibling:=ResourceAdmission.indexed_file(path.get_base_dir(),path.get_file().get_basename()+"f.tlk",indexes)
		if sibling.has("error"):return sibling
		female_path=str(sibling.get("path",""))
	elif not catalog.has_resource(female_name,2018) and not profile.is_empty():
		var profile_female:=ResourceAdmission.indexed_file(profile.path_join("tlk"),female_name+".tlk",indexes)
		if profile_female.has("error"):return profile_female
		female_path=str(profile_female.get("path",""))
	if not female_path.is_empty() and FileAccess.file_exists(female_path):
		var female_opened_file:=table.open_file(female_path);reason=table.failure;table.close()
		if not female_opened_file:return {"error":"Selected custom female TLK is invalid: "+reason}
	elif path.is_empty() and catalog.has_resource(female_name,2018):
		var female_bytes: PackedByteArray=catalog.get_resource(female_name,2018)
		if not catalog.failure.is_empty():
			var female_repair: Dictionary=catalog.nwsync_repair_binding(female_name,2018)
			return {"error":"Selected custom female TLK read failed: "+catalog.failure,"repair":female_repair}
		var female_opened_bytes:=table.open_bytes(female_bytes);reason=table.failure;table.close()
		if not female_opened_bytes:return {"error":"Selected custom female TLK is invalid: "+reason}
	return {}
static func prepare(sources: Dictionary,guard: Callable=Callable(),progress_callback: Callable=Callable()) -> Dictionary:
	var began:=Time.get_ticks_usec(); var catalog:=Catalog.new(); var stop:=stopped(guard,catalog,began,"begin")
	var phase_began:=began; var phases: Dictionary={}
	if not stop.is_empty(): return stop
	if sources.has("recordedCatalog"):
		var recorded:=preload("res://systems/native_data/recorded_catalog.gd").new()
		var accepted:=recorded.mount(str(sources.recordedCatalog))
		stop=stopped(guard,recorded,began,"recorded catalog"); if not stop.is_empty(): return stop
		var recorded_stats:={"recorded":true,"benchmark_clone":recorded.packed_catalog!=null,"metadata_backend":"compiled" if Backend.available() else "gd","mount_ms":(Time.get_ticks_usec()-began)/1000.0,"rendering_prepared":false,"layers":recorded.layers.size()}
		if recorded.stats.has("overlap_thread_started"):
			# Runtime proof of the optional worker and its wait, without exposing
			# archive paths or copying the large manifest into the receipt.
			recorded_stats.overlap={"thread_started":bool(recorded.stats.overlap_thread_started),"validation_us":int(recorded.stats.get("overlap_validation_us",0)),"seal_us":int(recorded.stats.get("overlap_seal_us",0)),"join_us":int(recorded.stats.get("overlap_join_us",0)),"packed_mount_us":int(recorded.stats.get("overlap_packed_mount_us",0)),"bindings_us":int(recorded.stats.get("overlap_packed_bindings_us",0)),"start_error":int(recorded.stats.get("overlap_start_error",0))}
		return {"catalog":recorded,"error":"" if accepted else recorded.failure,"stats":recorded_stats}
	var install:=str(sources.get("install",""))
	if not install.is_absolute_path() or not catalog.mount_install(install,str(sources.get("language","en"))): return {"catalog":catalog,"error":catalog.failure if not catalog.failure.is_empty() else "Native install path is unavailable"}
	phases.installed_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	stop=stopped(guard,catalog,began,"installed"); if not stop.is_empty(): return stop
	var archives: Variant=sources.get("archives",[]); var manifests: Variant=sources.get("nwsync",[])
	if not archives is Array or not manifests is Array or archives.size()>4096 or manifests.size()>1024: return {"catalog":catalog,"error":"Native session resource descriptor exceeds bound"}
	var disabled: Variant=sources.get("disabledMods",[])
	if not disabled is Array: return {"catalog":catalog,"error":"Invalid native Workshop selection"}
	var workshop:=Workshop.new(); var roots:=workshop.scan(str(sources.get("modsDirectory","")),disabled)
	if not workshop.failure.is_empty(): return {"catalog":catalog,"error":workshop.failure}
	phases.workshop_discovery_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	var registered: Dictionary={}; var local_haks:=0
	for archive in archives:
		if archive is Dictionary and archive.has("path"): registered[str(archive.path).simplify_path().to_lower()]=true
	for selected in roots:
		stop=stopped(guard,catalog,began,"workshop"); if not stop.is_empty(): return stop
		var directory:=str(selected.directory).path_join("hak"); var folder:=DirAccess.open(directory)
		if folder==null: continue
		var names:=Array(folder.get_files()); names.sort_custom(func(a,b):return str(a).nocasecmp_to(str(b))<0)
		for filename in names:
			stop=stopped(guard,catalog,began,"workshop archive"); if not stop.is_empty(): return stop
			if str(filename).get_extension().to_lower()!="hak" or folder.is_link(str(filename)): continue
			var path:=directory.path_join(str(filename)); var identity:=path.simplify_path().to_lower()
			if registered.has(identity): continue
			if local_haks>=10000: return {"catalog":catalog,"error":"Global Workshop archive count exceeds bound"}
			registered[identity]=true
			if not catalog.mount_erf(path,29000000-local_haks): return {"catalog":catalog,"error":catalog.failure}
			local_haks+=1
	phases.workshop_archives_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	var seen: Dictionary={}; var manifest_layers: Dictionary={}; var index:=0
	for manifest in manifests:
		stop=stopped(guard,catalog,began,"manifest"); if not stop.is_empty(): return stop
		if not manifest is Dictionary: return {"catalog":catalog,"error":"Invalid native NWSync descriptor"}
		var hash:=str(manifest.get("hash",""))
		if seen.has(hash): continue
		seen[hash]=true
		if not catalog.mount_nwsync(hash,str(manifest.get("cacheDirectory","")),str(manifest.get("nativeDirectory","")),str(manifest.get("helper","")),40000000+index,str(sources.get("rawCacheDirectory",ProjectSettings.globalize_path("user://native-original-bytes-v1")))): return {"catalog":catalog,"error":catalog.failure}
		for mounted in catalog.layers:
			if str(mounted.get("binding_identity",""))=="nwsync:"+hash:manifest_layers[hash]=mounted;break
		index+=1
	phases.manifests_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	for archive in archives:
		stop=stopped(guard,catalog,began,"session archive"); if not stop.is_empty(): return stop
		if not archive is Dictionary:return {"catalog":catalog,"error":"Invalid native archive descriptor"}
		var priority:=int(archive.get("priority",30000000))
		if str(archive.get("source","file"))=="nwsync":
			var archive_manifest_hash:=str(archive.get("manifest",""));var name:=str(archive.get("name",""));var kind:=str(archive.get("kind",""))
			var type:=int(Extensions.TYPES.get(kind,-1));var key:=name.to_lower()+":"+str(type)
			if not manifest_layers.has(archive_manifest_hash) or type<0:return {"catalog":catalog,"error":"NWSync archive manifest is not mounted"}
			var layer: Dictionary=manifest_layers[archive_manifest_hash]
			var entry: Dictionary=layer.entries.get(key,{})
			if entry.is_empty() or str(entry.get("hash",""))!=str(archive.get("entry",{}).get("hash","")):return {"catalog":catalog,"error":"NWSync archive source differs from admission"}
			if not catalog.mount_nwsync_erf(layer.store,entry,priority,name):
				return {"catalog":catalog,"error":catalog.failure,"stats":{"repair":catalog.nested_archive_repair} if not catalog.nested_archive_repair.is_empty() else {}}
		else:
			if not str(archive.get("path","")).is_absolute_path():return {"catalog":catalog,"error":"Invalid native archive descriptor"}
			if not catalog.mount_erf(archive.path,priority):return {"catalog":catalog,"error":catalog.failure}
	phases.session_archives_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	var profile:=str(sources.get("profileDirectory","")); var portraits: Array=[]; var overrides: Array=[]
	if not profile.is_empty():
		if not profile.is_absolute_path(): return {"catalog":catalog,"error":"Native profile directory must be absolute"}
		portraits.append(profile.path_join("portraits")); overrides.append(profile.path_join("override"))
	overrides.append_array([install.path_join("ovr"),install.path_join("override")])
	for selected in roots:
		portraits.append(str(selected.directory).path_join("portraits")); overrides.append(str(selected.directory).path_join("override"))
	if not catalog.mount_directory(install.path_join("data/prt"),90000000,[3,2033],"portraitsinstall"): return {"catalog":catalog,"error":catalog.failure}
	for number in portraits.size():
		stop=stopped(guard,catalog,began,"portraits"); if not stop.is_empty(): return stop
		if not catalog.mount_directory(str(portraits[number]),91000000-number,[3,2033],"portraits"): return {"catalog":catalog,"error":catalog.failure}
	phases.portraits_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	for number in overrides.size():
		stop=stopped(guard,catalog,began,"overrides"); if not stop.is_empty(): return stop
		if not catalog.mount_directory(str(overrides[number]),10000000-number): return {"catalog":catalog,"error":catalog.failure}
	phases.overrides_ms=(Time.get_ticks_usec()-phase_began)/1000.0
	phase_began=Time.get_ticks_usec()
	var ambient_directories: Array[String]=[]
	var music_directories: Array[String]=[]
	if not profile.is_empty():
		ambient_directories.append(profile.path_join("ambient"))
		music_directories.append(profile.path_join("music"))
	ambient_directories.append(install.path_join("data/amb"))
	music_directories.append(install.path_join("data/mus"))
	ambient_directories.append_array(workshop.directories_for(roots,"ambient"))
	if not workshop.failure.is_empty(): return {"catalog":catalog,"error":workshop.failure}
	music_directories.append_array(workshop.directories_for(roots,"music"))
	if not workshop.failure.is_empty(): return {"catalog":catalog,"error":workshop.failure}
	for number in ambient_directories.size():
		stop=stopped(guard,catalog,began,"ambient fallback"); if not stop.is_empty(): return stop
		if not catalog.mount_directory(ambient_directories[number],500000-number,[4]): return {"catalog":catalog,"error":catalog.failure}
	for number in music_directories.size():
		stop=stopped(guard,catalog,began,"music fallback"); if not stop.is_empty(): return stop
		if not catalog.mount_directory(music_directories[number],500000-number,[8]): return {"catalog":catalog,"error":catalog.failure}
	phases.loose_audio_ms=(Time.get_ticks_usec()-phase_began)/1000.0
	stop=stopped(guard,catalog,began,"custom TLK"); if not stop.is_empty(): return stop
	var custom_tlk_check: Dictionary=validate_custom_tlk(sources.get("customTlk"),catalog,profile)
	if custom_tlk_check.has("error"):
		var repair: Dictionary=custom_tlk_check.get("repair",{})
		return {"catalog":catalog,"error":str(custom_tlk_check.error),"stats":{"repair":repair} if not repair.is_empty() else {}}
	stop=stopped(guard,catalog,began,"resource index"); if not stop.is_empty(): return stop
	var index_stats:=catalog.build_resource_index()
	stop=stopped(guard,catalog,began,"publication"); if not stop.is_empty(): return stop
	# Original source reads fall through to the catalog's selected archive and
	# session store on demand. Only explicit diagnostics preload every icon.
	var eager_icons: bool=bool(sources.get("preloadBulkIconSources",false))
	var icon_sources: Dictionary=ItemIconSources.preload_all(catalog,guard,progress_callback) if eager_icons else {"policy":"on-demand","deferred":true,"total":0,"completed":0,"loaded":0,"reused":0,"failures":[],"resident_bytes":ItemIconSources.size_bytes()}
	if icon_sources.get("cancelled",false): return stopped(guard,catalog,began,"item icons")
	if not icon_sources.failures.is_empty(): return {"catalog":catalog,"error":"Item icon source unavailable: "+str(icon_sources.failures[0]),"stats":{"item_icon_sources":icon_sources}}
	var spellbook_sources: Dictionary=SpellbookIconSources.preload_all(catalog,guard,progress_callback) if eager_icons else {"policy":"on-demand","deferred":true,"total":0,"completed":0,"loaded":0,"reused":0,"missing":[],"failures":[],"resident_bytes":SpellbookIconSources.size_bytes()}
	if spellbook_sources.get("cancelled",false): return stopped(guard,catalog,began,"spellbook icons")
	if not spellbook_sources.failures.is_empty(): return {"catalog":catalog,"error":"Spellbook/action icon source unavailable: "+str(spellbook_sources.failures[0]),"stats":{"item_icon_sources":icon_sources,"spellbook_icon_sources":spellbook_sources}}
	return {"catalog":catalog,"error":"","stats":{"mount_ms":(Time.get_ticks_usec()-began)/1000.0,"metadata_backend":"compiled" if Backend.available() else "gd","lookup_index":index_stats,"phases":phases,"layers":catalog.layers.size(),"manifests":index,"workshop_mods":roots.map(func(row):return row.id),"item_icon_sources":icon_sources,"spellbook_icon_sources":spellbook_sources,"worker_thread":OS.get_thread_caller_id(),"rendering_prepared":false,"residency":catalog.residency_stats()}}
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_catalog",began)
func _profile_process(_delta: float) -> void:
	if task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock(); var value:=result; result={}; mutex.unlock()
	if int(value.get("serial",-1))!=serial: return
	var prepared: Dictionary=value.prepared
	completed.emit(serial,prepared.catalog,str(prepared.error),prepared.get("stats",{}))
func close() -> void:
	cancel()
	serial+=1
	if task>=0: WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock(); result={}; mutex.unlock()
func begin_retirement() -> void:
	cancel(); serial+=1; set_process(false)
func worker_tasks() -> Array:
	return [task] if task>=0 else []
func _exit_tree() -> void: close()
