extends SceneTree
const Policy=preload("res://systems/native_data/tooltip_highlight.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var oracle:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
		if argument.begins_with("--oracle="): oracle=argument.trim_prefix("--oracle=")
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var observed: Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(observed is Dictionary and observed.get("binarySha256","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.get("observations",[]).size()==580,"Pinned original highlight dispatcher and refresh/registration slices produced 580 observations")
	if observed is Dictionary:
		check(int(observed.defaultMs)==Policy.DEFAULT_MS and int(observed.minimumMs)==Policy.MIN_MS and int(observed.maximumMs)==Policy.MAX_MS and int(observed.action97SwitchCase)==49,"Original default/range and action97 dispatch table match the native policy")
		for index in observed.get("observations",[]).size():
			var row: Dictionary=observed.observations[index]; var input: Dictionary=row.input; var policy:=Policy.new()
			policy.held=int(input.held); policy.phase=int(input.phase); policy.previous=int(input.previous); policy.refresh=int(input.refresh); policy.enabled=bool(input.enabled)
			var dispatch:=policy.key(bool(input.pressed),int(input.now),int(input.threshold)) if str(row.kind)=="key" else policy.advance(int(input.now))
			var actual: Dictionary={"held":policy.held,"phase":policy.phase,"previous":policy.previous,"refresh":policy.refresh,"enabled":policy.enabled,"events":[dispatch] if dispatch>=0 else []}
			check(JSON.parse_string(JSON.stringify(actual))==row.output,"Original observation %d (%s): expected %s; actual %s"%[index,str(row.kind),JSON.stringify(row.output),JSON.stringify(actual)])
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure native highlight-key state compared to complete original action97 dispatch and bounded held-refresh/registration execution; explicit lower providers, no window/input/pixel/server claim."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
