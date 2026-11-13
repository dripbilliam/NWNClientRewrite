extends SceneTree
const Census=preload("res://tools/nwn64/source_input_census.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rows: Array=[
		{"id":1,"has_owner":true,"prepared":true,"pose_id":11,"source_id":100,"kind":0,"emitter_flags":4},
		{"id":2,"has_owner":true,"prepared":true,"pose_id":12,"source_id":100,"kind":1,"emitter_flags":4},
		{"id":3,"has_owner":true,"prepared":false,"pose_id":13,"source_id":100,"kind":2,"emitter_flags":16},
		{"id":4,"has_owner":false},
		{"id":5,"has_owner":true,"prepared":true,"pose_id":14,"source_id":100,"kind":0,"emitter_flags":4},
		{"id":6,"has_owner":true,"prepared":true,"pose_id":20,"source_id":20,"kind":0,"emitter_flags":0},
	]
	var result: Dictionary=Census.summarize(rows,6)
	check(result.success and result.owned==5 and result.prepared==4,"Owner and prepared partitions")
	check(result.unique_sources==2 and result.repeated_source_owners==4,"Registration identity sharing")
	check(result.separate_source_pose_reads==3 and result.same_pose_source==1,"Actual separate source-read shape")
	check(result.potential_duplicate_source_reads==2 and result.adjacent_source_repeats==1,"Duplicate upper bound and registration-order adjacency")
	check(result.kind_counts=={0:3,1:1,2:1} and result.emitter_flags_counts=={4:3,16:1,0:1},"Effect family and flags remain counted")
	check(not Census.summarize(rows,7).success,"Registration mismatch fails closed")
	var duplicate: Array=rows.duplicate(true);duplicate[1].id=1
	check(not Census.summarize(duplicate,6).success,"Duplicate identity fails closed")
	var missing: Array=rows.duplicate(true);missing[0].erase("source_id")
	check(not Census.summarize(missing,6).success,"Missing source identity fails closed")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Synthetic cold census arithmetic only; no original scene or timing."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
