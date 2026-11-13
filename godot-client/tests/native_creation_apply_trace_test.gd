extends "res://native_live_world.gd"
const SessionEntry=preload("res://native_session_world.gd")
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	args={"report":output+".owned","settings-check":"true","creation-phase-trace":"true"}
	var destination: String=str(args.report)+".phases.jsonl"
	creation_trace("first-snapshot:before");var first: String=FileAccess.get_file_as_string(destination)
	creation_trace("first-snapshot:after");var second: String=FileAccess.get_file_as_string(destination)
	args["creation-phase-trace"]="false";creation_trace("ordinary:never-written")
	var disabled: String=FileAccess.get_file_as_string(destination)
	args["creation-phase-trace"]="true"
	for index in 140:creation_trace("bounded:"+str(index))
	var lines: PackedStringArray=FileAccess.get_file_as_string(destination).strip_edges().split("\n")
	var success: bool=SessionEntry!=null and first.contains("first-snapshot:before") and second.contains("first-snapshot:after") and second==disabled and lines.size()==128 and creation_trace_sequence==128 and not first.contains("token")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":5,"phaseLines":lines.size(),"scope":"Actual inherited native trace writes/flushes before returning, remains inert when disabled, bounds output128; both real root entry scripts compile. No snapshot/network/renderer startup or user process action."},"\t"));file.close();quit(0 if success else 1)
