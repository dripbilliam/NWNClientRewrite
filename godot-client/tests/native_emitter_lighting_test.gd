extends "res://tests/native_focus_light_sample_test.gd"
func run() -> void:
	var path:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if path.is_empty() or oracle.is_empty() or FileAccess.file_exists(path): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==297,"Pinned original emitter light sample corpus loads")
	var owner: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var actual: Dictionary=owner.call("dispatch",12,row.case)
		check(not actual.has("error") and actual.has("sample"),"Compiled CPU emitter sample executes "+str(index)+" "+str(actual.get("error","")))
		if actual.has("sample"):
			var expected:=Sample.vector(row.sample); var error:=maxf(absf(float(actual.sample[0])-expected.x),maxf(absf(float(actual.sample[1])-expected.y),absf(float(actual.sample[2])-expected.z)))
			maximum_error=maxf(maximum_error,error); check(error<=.000001,"Compiled GetEmitterLighting matches unchanged original "+str(index)+" error="+str(error))
	owner.call("dispatch",5,{}); owner=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"maximum_error":maximum_error,"publicConnections":0,"scope":"Compiled native CPU GetEmitterLighting against 297 unchanged original instruction cases: raw radii, fades, exclusion boundaries, headlight and both area channels. Caller supplies admitted list; not complete vision/admission/world acceptance."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
