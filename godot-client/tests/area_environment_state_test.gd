extends SceneTree
const Core = preload("res://systems/area_environment_state.gd")
var failures: Array = []
var comparisons := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-fog-range-v2.json"))
	if oracle.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or oracle.rows.size() != 1200: quit(2); return
	for row in oracle.rows:
		var c: Dictionary = row.case
		var actual: Dictionary = Core.fog_range(c.near,c.clip,c.distance,c.amount,c.skybox != 0,c.showSky != 0)
		for key in ["start","end","near","far"]:
			comparisons += 1
			var bits := PackedByteArray();bits.resize(4);bits.encode_float(0,actual[key])
			if bits.hex_encode() != row.expectedBits[key]: failures.append({"case":c,"key":key,"actual":actual[key],"expected":row.expected[key],"actualBits":bits.hex_encode(),"expectedBits":row.expectedBits[key]})
	var phase_oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-atmosphere-v3.json"))
	if phase_oracle.target != oracle.target or phase_oracle.rows.size() != 112: quit(2); return
	for row in phase_oracle.rows:
		var c: Dictionary = row.case
		var actual: Dictionary = Core.phase_sample(phase_oracle.colors,phase_oracle.amounts,c.mode,Core.f(c.elapsed*c.duration),c.duration,c.shadow,bool(c.isNight))
		for call in row.calls:
			if call.kind == "direction": continue
			for i in 3:
				comparisons += 1
				var bits := PackedByteArray();bits.resize(4);bits.encode_float(0,actual[call.kind][i])
				if bits.hex_encode() != call.bits[i]: failures.append({"case":c,"kind":call.kind,"index":i,"bits":bits.hex_encode(),"expected":call.bits[i]})
			if call.kind == "fog":
				comparisons += 1
				if actual.amount != call.argument: failures.append({"case":c,"kind":"amount","actual":actual.amount,"expected":call.argument})
		comparisons += 1
		if actual.isNight != (row.flags.isNight != 0): failures.append({"case":c,"kind":"isNight","actual":actual.isNight,"expected":row.flags.isNight})
		comparisons += 1
		var shadow := PackedByteArray();shadow.resize(4);shadow.encode_float(0,actual.shadow)
		if shadow.hex_encode() != row.shadowBits: failures.append({"case":c,"kind":"shadow","bits":shadow.hex_encode(),"expected":row.shadowBits})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"comparisons":comparisons,"rangeCases":oracle.rows.size(),"phaseCases":phase_oracle.rows.size(),"failures":failures,"scope":"Original bounded fog range, fixed setters and day/night color phase/shadow arithmetic against native Godot; not GPU fog, sky/weather, complete frame or full native culling acceptance"},"\t"));file.close()
	print(JSON.stringify({"passed":failures.is_empty(),"comparisons":comparisons,"failures":failures.size()}));quit(0 if failures.is_empty() else 1)
