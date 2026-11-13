extends SceneTree
const Census=preload("res://tests/nwn64_emitter_boundary_census.gd")
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func run() -> void:
	var accepted: Dictionary={"enabled":true,"coarse_phases":true,"stride":120,"min_members":1800,"errors":0,"excluded_detailed_samples":0,"phase_success_samples":2,"phase_success_means":{"entry_advance_ms":2.3},"records":[{"success":true,"phase_complete":true,"entry_advance_ms":2.1},{"success":true,"phase_complete":true,"entry_advance_ms":2.5}]}
	check(bool(Census.assess(accepted,1803,false).ready),"Exact sparse profile-off production configuration admitted")
	check(not bool(Census.assess(accepted,1799,false).ready),"Too-small world cannot claim busy-area phase sample")
	check(not bool(Census.assess(accepted,1803,true).ready),"Detailed GDScript profiling excluded")
	for key in ["enabled","coarse_phases","stride","min_members","errors","excluded_detailed_samples","phase_success_samples"]:
		var stale:=accepted.duplicate(true)
		match key:
			"enabled","coarse_phases":stale[key]=false
			"stride":stale[key]=1
			"min_members":stale[key]=0
			"errors","excluded_detailed_samples":stale[key]=1
			"phase_success_samples":stale[key]=0
		check(not bool(Census.assess(stale,1803,false).ready),"Invalid "+key+" rejected")
	var missing:=accepted.duplicate(true);missing.records=[{"success":true,"phase_complete":true,"entry_advance_ms":2.1}]
	check(not bool(Census.assess(missing,1803,false).ready),"Incomplete retained records rejected")
	missing=accepted.duplicate(true);missing.records[0].entry_advance_ms=0.0
	check(not bool(Census.assess(missing,1803,false).ready),"Missing inner advance phase rejected")
	var report:={"issue":"NWN-64","passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure sparse diagnostic gate semantics; no live capture, benchmark, FPS or engine mutation."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.substr(9)
			if FileAccess.file_exists(path):failures.append("report-exists")
			else:
				var file:=FileAccess.open(path,FileAccess.WRITE)
				if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
