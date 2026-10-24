extends SceneTree
const Weather = preload("res://systems/weather_state.gd")
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-weather-state-v1.json"))
	if input.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a": quit(2); return
	var state := Weather.new()
	var failures: Array = []
	var comparisons := 0
	for row in input.rows:
		if row.reset: state = Weather.new()
		if row.request != null: state.request(int(row.request.type),row.request.enabled)
		state.advance(int(row.delta),row.fadeTimes)
		for key in ["current","target","remaining","instances","created","removed"]:
			comparisons += 1
			if state[key] != int(row[key]): failures.append({"row":input.rows.find(row),"key":key,"actual":state[key],"expected":row[key]})
		var bytes := PackedByteArray();bytes.resize(4);bytes.encode_float(0,state.intensity)
		comparisons += 1
		if bytes.hex_encode() != row.intensityBits: failures.append({"row":input.rows.find(row),"key":"intensity","actual":bytes.hex_encode(),"expected":row.intensityBits})
		for event in row.events:
			if event.flags != 0 or event.rateBits == "00000000": continue
			bytes.encode_float(0,state.snapshot().clipFraction)
			comparisons += 1
			if bytes.hex_encode() != event.rateBits: failures.append({"row":input.rows.find(row),"key":"clipFraction","actual":bytes.hex_encode(),"expected":event.rateBits})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"comparisons":comparisons,"rows":input.rows.size(),"failures":failures,"scope":"Original instruction weather requests, transition arithmetic, six-instance lifecycle and animation rates; precipitation presentation pending"},"\t"));file.close()
	print("WEATHER_STATE_TEST ",comparisons," comparisons, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
