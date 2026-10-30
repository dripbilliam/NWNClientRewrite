extends SceneTree
# Offline reproduction/acceptance against an existing local content set. No
# downloads or server login; generated output goes to a private temporary cache.
const Controller=preload("res://systems/native_asset_prework.gd")
const Discovery=preload("res://systems/native_data/prework_sources.gd")
var last_print:=-100
class Bounded:
	extends "res://systems/native_asset_prework.gd"
	var limit:=512
	var prepared:=0
	var source_errors: Array=[]
	func start(catalog,cache_path: String,all_models: bool=true) -> bool:
		var ok:=super.start(catalog,cache_path,all_models)
		if ok:
			names=names.slice(0,mini(names.size(),limit)); state.total=names.size()*2
			service.completed.connect(func(_id: int,result: Dictionary):
				if not str(result.get("error","")).is_empty() and source_errors.size()<32: source_errors.append({"name":result.get("resource_name",""),"error":result.error})
				prepared+=1)
		return ok
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or not args.has("profile") or FileAccess.file_exists(str(args.report)): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-prework-corpus-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var profile:=str(args.profile)
	var sources:={"install":str(args.install),"profileDirectory":profile,"modsDirectory":"","disabledMods":[],"cacheDirectory":profile.path_join("replacement-client/server-content"),"nativeDirectory":profile.path_join("nwsync"),"helper":ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe"),"rawCacheDirectory":folder.path_join("raw")}
	var choices:=Discovery.discover(sources); var selected: Dictionary={}
	for choice in choices.choices:
		if str(choice.label).to_lower().contains(str(args.get("content","arelith")).to_lower()): selected=choice; break
	if args.has("request"):
		var request: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.request)))
		if request is Dictionary and request.get("sources") is Dictionary: selected={"label":"Selected local content","sources":request.sources}
	if selected.is_empty(): print("PREWORK_CORPUS_NO_CONTENT"); quit(2); return
	var owner:=Bounded.new(); root.add_child(owner); owner.limit=int(args.get("limit",512)); owner.set_workers(int(args.get("workers",8)))
	var progress:=FileAccess.open(str(args.report)+".progress.jsonl",FileAccess.WRITE)
	var diagnostics:=FileAccess.open(str(args.report)+".models.jsonl",FileAccess.WRITE)
	owner.diagnostic_event.connect(func(event: Dictionary):diagnostics.store_line(JSON.stringify(event)); diagnostics.flush())
	owner.changed.connect(func(state: Dictionary):
		progress.store_line(JSON.stringify(state)); progress.flush()
		if int(state.completed)>=last_print+100 or not state.active: print("PREWORK_CORPUS ",state.completed,"/",state.total," ",state.message); last_print=int(state.completed))
	print("PREWORK_CORPUS_START ",selected.label," cache=",folder," workers=",owner.worker_count)
	owner.start_sources(selected.sources,folder.path_join("prepared"))
	var deadline:=Time.get_ticks_msec()+int(args.get("timeout",120))*1000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	var timed_out: bool=owner.state.active
	if timed_out: owner.cancel(); await process_frame
	var result:={"success":not timed_out and owner.state.completed==owner.state.total,"state":owner.state.duplicate(true),"source_errors":owner.source_errors,"content":selected.label,"cache":folder,"public_connections":0,"timed_out":timed_out,"scope":"Bounded offline real-content preparation; unavailable source assets are reported separately from process/thread safety"}
	owner.close(); owner.queue_free(); await process_frame; await process_frame; progress.close(); diagnostics.close()
	var output:=FileAccess.open(str(args.report),FileAccess.WRITE); output.store_string(JSON.stringify(result,"\t")); output.close(); quit(0 if result.success else 1)
