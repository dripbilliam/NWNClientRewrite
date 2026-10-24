extends SceneTree
const SkyState = preload("res://systems/area_sky_state.gd")
const Core = preload("res://systems/area_environment_state.gd")
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-sky-state-v1.json"))
	if input.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a": quit(2); return
	var state := SkyState.new()
	var failures: Array = []
	var comparisons := 0
	for row in input.rows:
		if row.reset: state.reset(int(row.initial))
		state.advance(row.mode,Core.f(row.elapsed),Core.f(row.duration),row.initial == 3)
		for key in ["current","target","completed","requested"]:
			comparisons += 1
			if state[key] != int(row[key]): failures.append({"row":row,"key":key,"actual":state[key]})
		var bytes := PackedByteArray();bytes.resize(4);bytes.encode_float(0,state.alpha)
		comparisons += 1
		if bytes.hex_encode() != row.alphaBits: failures.append({"row":row,"key":"alpha","bits":bytes.hex_encode()})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"comparisons":comparisons,"rows":input.rows.size(),"failures":failures,"scope":"Original instruction sky state oracle; not full GPU/weather parity"},"\t"));file.close()
	print("SKY_STATE_TEST ",comparisons," comparisons, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
