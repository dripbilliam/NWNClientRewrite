extends SceneTree
var checks:=0
var failures: Array=[]
var maximum_error:=0.0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<32: failures.append(label)
func numeric(actual: Variant,expected: Variant,label: String) -> void:
	if actual is Array and expected is Array:
		check(actual.size()==expected.size(),label+" size")
		for n in mini(actual.size(),expected.size()): numeric(actual[n],expected[n],label+"/"+str(n))
	else:
		var error:=absf(float(actual)-float(expected)); maximum_error=maxf(maximum_error,error)
		check(error<.000001,label+" error "+str(error))
func _initialize() -> void: call_deferred("run")
func ids(value: Array) -> Array: return value.map(func(n):return int(n))
func run() -> void:
	var report:=""; var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--oracle="): path=arg.substr(9)
	if report.is_empty() or path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original instruction corpus")
	check(ClassDB.class_exists("NwnLightHistory"),"Native owner registers")
	if ClassDB.class_exists("NwnLightHistory"):
		for index in oracle.rows.size():
			var row: Dictionary=oracle.rows[index]; var owner=ClassDB.instantiate("NwnLightHistory"); var initialized: Dictionary=owner.dispatch(0,row.case)
			check(not initialized.has("error"),"Native configure "+str(index)+" "+str(initialized.get("error","")))
			for n in row.case.frames.size():
				var input: Dictionary=row.case.frames[n].duplicate(true); input.full=true
				input.lights=row.case.lights.duplicate(true)
				for id in input.lights.size():
					input.lights[id].id=id; input.lights[id].in_view=input.get("in_view",{}).get(str(id),true)
				var actual: Dictionary=owner.dispatch(1,input); var expected: Dictionary=row.frames[n]; var label:=str(index)+"/"+str(n)
				check(not actual.has("error"),"Native step "+label+" "+str(actual.get("error","")))
				if actual.has("error"): break
				check(ids(actual.order)==ids(expected.order),"Original unstable sort order "+label)
				if input.has("collect_radius"): check(ids(actual.collected)==ids(expected.collected),"Original main-world collection "+label)
				check(ids(actual.active0)==ids(expected.active0) and ids(actual.active1)==ids(expected.active1),"Original retained slots "+label+" actual "+str(actual.active0)+" expected "+str(expected.active0))
				var fades: Array=actual.lights.map(func(light):return [light.fade0,light.fade1])
				numeric(fades,expected.fades,"Both original fade channels "+label)
				numeric(actual.area_fades,expected.area_fades,"Original area fade channels "+label)
				check(actual.calls.size()==expected.calls.size(),"Original draw/disable count "+label)
				for c in mini(actual.calls.size(),expected.calls.size()):
					var a: Dictionary=actual.calls[c]; var e: Dictionary=expected.calls[c]
					check(a.kind==e.kind and int(a.get("id",-1))==int(e.get("id",-1)) and int(a.get("slot",-1))==int(e.get("slot",-1)),"Original draw/disable sequence "+label+"/"+str(c))
					if e.has("fade"): numeric(a.get("fade",-1),e.fade,"Original submitted fade "+label+"/"+str(c))
			owner.dispatch(8,{})
			check(owner.dispatch(1,{"candidates":[]}).has("error"),"Closed history cannot resurrect")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"maximum_error":maximum_error,"sequences":oracle.rows.size(),"publicConnections":0,"scope":"Unchanged original priority, native unstable sort, retained slots, two independent fade channels and render submissions. Caller supplies BSP candidates and per-light view admission; no GPU or BSP parity claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
