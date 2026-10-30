extends SceneTree
const Loader=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("sources") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var sources: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.sources))
	var loader:=Loader.new(); root.add_child(loader); var prepared: Dictionary={}; var frames:=0
	loader.completed.connect(func(_serial: int, catalog: RefCounted, error: String, stats: Dictionary): prepared.merge({"catalog":catalog,"error":error,"stats":stats}))
	loader.start(sources)
	# Caller mutation must not change queued native source ownership.
	sources.nwsync.clear()
	var deadline:=Time.get_ticks_msec()+60000
	while prepared.is_empty() and Time.get_ticks_msec()<deadline: frames+=1; await process_frame
	check(not prepared.is_empty() and str(prepared.get("error","unfinished")).is_empty(),"Installed native NWSync catalog mounts: "+str(prepared.get("error","unfinished")))
	var metrics: Dictionary={}
	if not prepared.is_empty() and str(prepared.error).is_empty():
		var catalog=prepared.catalog; metrics.catalog=prepared.stats
		check(frames>1 and int(prepared.stats.worker_thread)!=OS.get_main_thread_id(),"Large catalog indexes on a native worker while frames continue")
		check(prepared.stats.manifests==1,"Queued sources are isolated from caller mutation")
		check(catalog.location("appearance",2017).layer.kind=="nwsync","Custom rules select installed NWSync source")
		check(catalog.location("c_golstone",2002).layer.kind=="key","Original models retain KEY fallback")
		var worker:=Assets.new(); root.add_child(worker); worker.configure(catalog)
		var delivered: Dictionary={}; worker.completed.connect(func(id: int, result: Dictionary): delivered[id]=result)
		var requests: Dictionary={}
		for spec in [["appearance",2017,"2da"],["invis_cr_160",2002,"actor-model"],["pfd34_forel017",2002,"mdl-original"],["c_ayala",2002,"static-model"]]:
			var id:=worker.request(str(spec[0]),int(spec[1]),str(spec[2])); requests[id]=spec
		deadline=Time.get_ticks_msec()+60000
		while delivered.size()<requests.size() and Time.get_ticks_msec()<deadline: await process_frame
		metrics.resources=[]
		check(delivered.size()==requests.size(),"Native original-resource worker jobs finish")
		for id in requests:
			var result: Dictionary=delivered.get(id,{}); var spec: Array=requests[id]
			var error:=str(result.get("error","unfinished")); var model: Dictionary=result.get("value",{})
			metrics.resources.append({"name":spec[0],"decoder":spec[2],"bytes":result.get("bytes",PackedByteArray()).size(),"worker_ms":result.get("worker_ms",0),"nodes":model.get("nodes",[]).size(),"textures":result.get("textures",{}).size(),"error":error})
			check(error.is_empty(),"Native preparation succeeds: "+str(spec[0])+": "+error)
			check(int(result.get("thread",OS.get_main_thread_id()))!=OS.get_main_thread_id(),"Resource preparation stays on native worker: "+str(spec[0]))
		worker.close(); worker.queue_free()
		for layer in catalog.layers:
			if layer.kind=="nwsync": layer.store.close()
	loader.close(); loader.queue_free(); prepared.clear(); await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"network_connections":0,"js_rendering":false,"scope":"Headless original installed server resources; no rendered world, GPU or public-server acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
