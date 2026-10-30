extends SceneTree
const Policy=preload("res://systems/native_data/character_lobby_keys.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==192,"Key comparison pins192 original populated-list dispatch/callback executions")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var data: Dictionary=row.case; var delta:=Policy.direction(int(data.key)); var result:=Policy.move(int(data.selected),int(data.count),delta,int(data.scroll),int(data.rowHeight),int(data.viewportHeight))
		check(result.index==int(row.selected) and result.scroll==row.scrollRequest,"Original key bounds and conditional pixel-scroll request case %d"%index)
		check(row.calls.filter(func(call):return call[0]=="preview").size()==int(delta!=0),"Original cursor dispatch invokes selection once; irrelevant base keys are not selection actions case %d"%index)
	check(Policy.move(-1,0,1,0,43,90)=={"index":-1,"scroll":null},"Empty UI lists never select a nonexistent character")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Original populated-list cursor dispatch and selection/scroll arithmetic, with an empty-list guard. Native pointer/keyboard and authoritative acknowledgment require separate checks."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
