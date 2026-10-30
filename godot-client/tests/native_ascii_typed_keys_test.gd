extends SceneTree
const Actor=preload("res://systems/native_data/actor_model.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var baseline_script: GDScript
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func compare(bytes: PackedByteArray,label: String) -> void:
	var reference=baseline_script.new(); reference.packed_keys=true
	var candidate:=Actor.new(); candidate.packed_keys=true
	var began:=Time.get_ticks_usec(); var a: Dictionary=reference.parse(bytes); var reference_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var b: Dictionary=candidate.parse(bytes); var candidate_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(reference.failure==candidate.failure,label+": exact parser error including precedence")
	check(Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b)),label+": every physical field, clip, double key, Bezier tangent and ordering stays byte-exact")
	var runtime_reference:=Actor.new(); runtime_reference.packed_keys=true; runtime_reference.typed_ascii_keys=false
	var c: Dictionary=runtime_reference.parse(bytes)
	check(runtime_reference.failure==reference.failure and Cache.digest(var_to_bytes(c))==Cache.digest(var_to_bytes(a)),label+": runtime array-write reference matches the pinned old parser")
	observations.append({"name":label,"bytes":bytes.size(),"reference_ms":reference_ms,"candidate_ms":candidate_ms,"error":candidate.failure})
func source(controller: String,keys: String) -> PackedByteArray:
	return ("newmodel authored\nbeginmodelgeom authored\nnode dummy root\nparent NULL\nendnode\nendmodelgeom authored\nnewanim test authored\nlength 2\ntranstime 0\nanimroot root\nnode dummy root\n"+controller+"\n"+keys+"\nendnode\ndoneanim test authored\n").to_utf8_buffer()
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var baseline_path:="res://backups/native-loading-inherited-retirement-v1.zip"
	check(FileAccess.get_sha256(baseline_path)=="267ea98a77146ca20c3efe5d1f18170ea1d1fbdf8d73368b33790e0a94a4d75c","Verified authored pre-change checkpoint is unchanged")
	var zip:=ZIPReader.new(); check(zip.open(baseline_path)==OK,"Authored baseline archive opens without game asset copies")
	var code:=zip.read_file("systems/native_data/actor_model.gd"); zip.close()
	check(Cache.digest(code)=="d9b9e4a9be3a10bcbeecefcb223a13c170097d90cf8b37acb446a8ef4e86adbe","Reference packed-key parser source hash is pinned")
	baseline_script=GDScript.new(); baseline_script.source_code=code.get_string_from_utf8()
	check(baseline_script.reload()==OK,"Actual verified old parser compiles as independent reference")
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original ASCII corpus mounts")
	for name in ["pme0","c_nulltail","h_ba_med_weap","h_ba_custom"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); check(not bytes.is_empty() and catalog.failure.is_empty(),"Original captured ASCII source is verified: "+name)
		compare(bytes,name)
	for controller in ["positionkey 3","orientationkey 3","scalekey 3","positionbezierkey 3","scalebezierkey 3"]:
		var width:=4 if controller.begins_with("orientation") else 3 if controller.begins_with("position") else 1
		if "bezier" in controller: width*=3
		var rows: Array=[]
		for index in 3:
			var values: Array=[str(index*0.5)]
			for component in width: values.append(["-0.0","+1.2345678901234567","1.7976931348623157e308","2.2250738585072014e-308","0.3333333333333333"][component%5])
			rows.append("\t".join(values))
		compare(source(controller,"\n".join(rows)),controller+":double-extremes")
	compare(source("positionkey","# before\n0 1 2 3\n\n# middle\n1 4 5 6\nendlist"),"uncounted-comments")
	compare(source("position 1 2 3",""),"constant-controller")
	for count in [0,1,64,65,130]:
		var rows: Array=[]
		for index in count: rows.append(str(index)+" 1 2 3")
		rows.append("endlist")
		compare(source("positionkey","\n".join(rows)),"uncounted-growth:"+str(count))
	var boundary: Array=[]
	for index in 65: boundary.append(str(index)+" 1 2 3")
	boundary.append("0 NaN 2 3"); boundary.append("endlist")
	compare(source("positionkey","\n".join(boundary)),"uncounted-growth-error-precedence")
	for rows in ["0 1 2 3\n-1 4 5 6","1 1 2 3\n0 4 5 6","1 1 2 3\n0 NaN 5 6","0 1 2 3\n1 1e400 5 6","0 1 2 3\n1 4 bad 6","0 1 2\n1 4 5 6","0 1 2 3"]:
		compare(source("positionkey 2",rows),"malformed:"+str(observations.size()))
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"scope":"Byte-exact complete packed model graphs and exact error precedence versus a hashed authored pre-change parser, original ASCII sources plus double/extreme/counted/uncounted/constant/Bezier malformed cases; isolated measurements are not full-world/FPS acceptance"},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
