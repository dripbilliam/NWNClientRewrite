extends SceneTree
const SessionCatalog=preload("res://systems/native_data/session_catalog.gd")
const Sources=preload("res://systems/native_data/item_icon_sources.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["install","report"]) or FileAccess.file_exists(options.report): quit(2); return
	var progress: Array=[]
	var result: Dictionary=SessionCatalog.prepare({"install":options.install},Callable(),func(phase,completed,total):
		if phase=="item-icons" and (progress.is_empty() or completed==total or completed-progress.back().completed>=512):progress.append({"completed":completed,"total":total}))
	check(str(result.get("error","")).is_empty(),"Full startup catalog and icon source load")
	var catalog=result.get("catalog")
	var record: Dictionary=result.get("stats",{}).get("item_icon_sources",{})
	check(int(record.get("total",0))>5000 and int(record.get("completed",0))==int(record.get("total",0)),"All installed item icon source names were scanned")
	check(int(record.get("loaded",0))==int(record.get("total",-1)) and record.get("failures",[]).is_empty(),"Every installed icon payload is resident")
	var before: Dictionary=catalog.stats.duplicate()
	var bitmap: PackedByteArray=catalog.get_resource("iashlw_011",3)
	var palette: PackedByteArray=catalog.get_resource("ihelm_001",6)
	check(not bitmap.is_empty() and not palette.is_empty() and catalog.failure.is_empty(),"Actual original bitmap and palette icon bytes resolve")
	check(int(catalog.stats.reads)==int(before.reads) and int(catalog.stats.source_memory_hits)>=int(before.source_memory_hits)+2,"Icon lookups use resident payloads with no archive reads")
	var second: Dictionary=SessionCatalog.prepare({"install":options.install})
	check(str(second.get("error","")).is_empty() and int(second.get("stats",{}).get("item_icon_sources",{}).get("reused",0))==int(record.get("total",-1)),"Later catalog reuses every resident installed icon")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"first":record,"second":second.get("stats",{}).get("item_icon_sources",{}),"resident":Sources.snapshot(),"progress":progress,"scope":"Actual installed item bitmap/PLT source residency before menu; no generated item composites or GPU imagery."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"resident":report.resident}))
	quit(0 if failures.is_empty() else 1)
