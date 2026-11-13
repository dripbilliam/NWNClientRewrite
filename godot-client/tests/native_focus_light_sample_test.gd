extends SceneTree
const Sample=preload("res://systems/native_render/focus_light_sample.gd")
var checks:=0
var failures: Array=[]
var maximum_error:=0.0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if path.is_empty() or oracle.is_empty() or FileAccess.file_exists(path): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==297 and original.gates.size()==56,"Pinned unchanged original instruction corpus loads")
	var row_index:=0
	for row in original.rows:
		var actual:=Sample.sample(row.case); var expected:=Sample.vector(row.sample)
		var error:=maxf(absf(actual.x-expected.x),maxf(absf(actual.y-expected.y),absf(actual.z-expected.z))); maximum_error=maxf(maximum_error,error)
		check(error<=.000001,"Exact-order original emitter sample "+str(row_index)+" error "+str(error))
		for state in row.gates:
			var gate:=Sample.new(); gate.active=bool(state.previous)
			check(gate.select(actual)==bool(state.returned) and gate.active==bool(state.stored),"Original hysteresis over sampled lights "+str(row_index)+"/"+str(state.previous))
		row_index+=1
	for index in original.gates.size():
		var row: Dictionary=original.gates[index]; var gate:=Sample.new(); gate.active=bool(row.previous)
		check(gate.select(Sample.vector(row.sample),bool(row.present))==bool(row.returned) and gate.active==bool(row.stored),"Original exact threshold/missing-scene boundary "+str(index))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"maximum_error":maximum_error,"publicConnections":0,"scope":"297 unchanged original CPU light samples and 56 exact vision threshold boundaries. Caller-supplied admitted lists/fades; live native admission, focus placement and GPU appearance remain separate."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
