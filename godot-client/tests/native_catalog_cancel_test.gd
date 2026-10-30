extends SceneTree
const Sources=preload("res://systems/native_data/session_catalog.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_loader(loader) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while loader.task>=0 and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.task<0,"Catalog worker publishes a terminal result within its existing bounded check")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var early:=Sources.prepare({"install":"not an install"},func():return true)
	check(early.stats.cancelled and early.stats.phase=="begin" and early.catalog.layers.is_empty(),"An already canceled request does not begin install validation or file work")
	var boundaries: Array=[]
	var installed:=Sources.prepare({"install":install,"archives":[{"path":"not an archive"}]},func():boundaries.append(true); return boundaries.size()>=2)
	check(installed.get("stats",{}).get("cancelled",false) and installed.stats.phase=="installed" and not installed.catalog.layers.is_empty(),"Cancellation after original KEY discovery prevents any subsequent invalid archive work")
	check(not installed.catalog.resolved_ready and not installed.catalog.get_resource("directconnect",2047).is_empty(),"Canceled catalogs retain valid read-only mount data without constructing an unused final index")
	var fixture:=output+".fixture"; var hak:=fixture.path_join("hak"); DirAccess.make_dir_recursive_absolute(hak)
	var good:=hak.path_join("000_good.hak"); var poison:=hak.path_join("001_do_not_read.hak")
	var raw:="HAK V1.0".to_ascii_buffer(); raw.resize(160); raw.encode_u32(24,160); raw.encode_u32(28,160)
	var file:=FileAccess.open(good,FileAccess.WRITE); file.store_buffer(raw); file.close()
	file=FileAccess.open(poison,FileAccess.WRITE); file.store_buffer("invalid archive".to_ascii_buffer()); file.close()
	boundaries.clear()
	var partial:=Sources.prepare({"install":install,"modsDirectory":fixture},func():boundaries.append(true); return boundaries.size()>=5)
	check(partial.get("stats",{}).get("cancelled",false) and partial.stats.phase=="workshop archive","Cancellation is checked between selected Workshop archives")
	check(partial.catalog.layers.any(func(layer):return str(layer.get("archive",{}).get("path","")).replace("\\","/").simplify_path()==good.replace("\\","/").simplify_path()) and not partial.catalog.resolved_ready,"A completed earlier archive remains valid while the next archive and final index are skipped")
	var read_poison:=Sources.prepare({"install":install,"modsDirectory":fixture})
	check(not str(read_poison.error).is_empty() and not read_poison.get("stats",{}).get("cancelled",false),"Without cancellation the next invalid archive is actually rejected, proving it was not silently ignored")
	var normal:=Sources.prepare({"install":install,"archives":[{"path":good}]})
	check(str(normal.error).is_empty() and normal.catalog.resolved_ready and not normal.catalog.get_resource("directconnect",2047).is_empty(),"Uncanceled callers keep normal original-resource/index behavior without supplying a guard")
	var loader:=Sources.new(); root.add_child(loader); var replies: Array=[]
	loader.completed.connect(func(serial,catalog,error,stats):replies.append({"serial":serial,"catalog":catalog,"error":error,"stats":stats}))
	var scope: int=loader.start({"install":install}); loader.cancel(); await wait_loader(loader)
	check(replies.size()==1 and replies[0].serial==scope and replies[0].stats.get("cancelled",false),"The real asynchronous owner publishes one cancellation result for its current request")
	var previous:=scope; scope=loader.start({"install":install}); await wait_loader(loader)
	check(scope>previous and replies.size()==2 and replies[1].serial==scope and str(replies[1].error).is_empty() and replies[1].catalog.resolved_ready,"A fresh start resets cancellation and admits only the new completed catalog")
	loader.start({"install":install}); loader.begin_retirement(); var tasks: Array=loader.worker_tasks()
	check(tasks.size()==1,"Retirement keeps its worker tracked until ownership is joined")
	loader.close(); await process_frame
	check(loader.task<0 and replies.size()==2 and loader.result.is_empty(),"Closing a retired owner joins its worker and cannot emit or retain a late catalog")
	loader.free(); replies.clear(); early={}; installed={}; partial={}; normal={}; read_poison={}; await process_frame; await process_frame
	file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Cooperative cancellation at real original-resource/catalog boundaries, poisoned later-archive refusal and async owner restart/retirement. No drawing, public server, or general loading/performance acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
