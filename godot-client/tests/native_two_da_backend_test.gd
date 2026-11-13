extends SceneTree
const Table=preload("res://systems/native_data/two_da.gd")
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func compare(text: String,label: String) -> Dictionary:
	var reference:=Table.new(); var compiled:=Table.new()
	var began:=Time.get_ticks_usec(); var expected:=reference.parse_reference(text); var reference_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var actual:=compiled.parse(text); var compiled_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(reference.failure==compiled.failure and var_to_bytes(expected)==var_to_bytes(actual),label+": exact graph, dictionary insertion/typed keys, ordered duplicate cells, labels and error")
	return {"name":label,"reference_ms":reference_ms,"compiled_ms":compiled_ms,"rows":expected.get("orderedRows",[]).size(),"columns":expected.get("columns",[]).size(),"bytes":text.length()}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	OS.set_environment("NWN_RESOURCE_2DA","compiled"); check(Backend.two_da_available(),"Compiled worker-local table scanner is loaded")
	var fixtures: Array=["","unsupported\n A\n 0 a","2DA V2.0\n","  ;comment\n2DA V2.0\nDEFAULT: 4\n A A B\n-1 x y\n-1 z\n+2 q r s extra\nwords a b c\n","2DA V2.0\n A B\n0 \"a b\" \"double\"\"quote\"\n1 \"\" ****\n2 \"unfinished\n3 \"closed\"after\n","2DA V2.0\nDeFaUlT: \"default value\"\n A B\n0001 abc\n-0 def\n9223372036854775807 ghi\n-9223372036854775808 jkl\n","2DA V2.0\r\n\tA B\r\n0 \"déjà vu\" 火\r\n1 a\rb\r\n","2DA V2.0\n A B\n0 é 火\n","2DA V2.0\nDEFAULT:only\nA\n0 x"]
	for index in fixtures.size(): compare(fixtures[index],"Authored syntax "+str(index))
	var random:=RandomNumberGenerator.new(); random.seed=3061
	var pieces: Array=["x","a b","\"\"","****","x\"\"y","火","é","","\t",";","\"unterminated"]
	for trial in 80:
		var text:="2DA V2.0\nDEFAULT: fallback\n A B A C\n"
		for row in random.randi_range(1,12):
			text+=str(row)+" "
			for column in random.randi_range(0,6):
				var piece: String=pieces[random.randi_range(0,pieces.size()-1)]
				text+=(('"'+piece+'"') if random.randf()<0.45 else piece)+( "\t" if random.randf()<0.5 else " ")
			text+="\n"
		compare(text,"Deterministic token corpus "+str(trial))
	var samples: Array=[]
	if args.has("catalog"):
		var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Exact captured original table corpus mounts")
		for key in catalog.manifest.get("resources",{}):
			if not str(key).ends_with(":2017"): continue
			var bytes:=catalog.get_resource(str(key).trim_suffix(":2017"),2017)
			check(catalog.failure.is_empty(),"Captured table bytes are present: "+str(key))
			if not catalog.failure.is_empty(): continue
			samples.append(compare(Binary.new(bytes).text(0,bytes.size()),str(key)))
		catalog.close_sources()
	# Each worker creates private output; no global parser pool/string table.
	var source:="2DA V2.0\n A B\n0 alpha beta\n1 gamma delta\n"
	var jobs: Array=[]; var outputs: Array=[]; outputs.resize(12)
	for index in 12:
		jobs.append(WorkerThreadPool.add_task(func():outputs[index]=Table.new().parse(source),false,"2DA concurrency fixture"))
	for job in jobs: WorkerThreadPool.wait_for_task_completion(job)
	outputs[0].rows[0].A="private"
	check(outputs[0].orderedRows[0].A=="private" and outputs[0].orderedCells[0][0]=="alpha","Row aliases and physical duplicate-cell view retain reference ownership")
	for index in range(1,12): check(outputs[index].rows[0].A=="alpha","Concurrent parser outputs remain isolated: "+str(index))
	OS.set_environment("NWN_RESOURCE_2DA","gd"); check(not Backend.two_da_available() and Table.new().parse(source)==Table.new().parse_reference(source),"Explicit interpreted reference remains available")
	OS.set_environment("NWN_RESOURCE_2DA","")
	var report:=FileAccess.open(args.report,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Compiled scanner versus existing decoder across syntax/malformed/duplicate/Unicode/CP1252 rules and exact captured 2DAs, private concurrent results. Public dictionary representation preserved; native executable syntax/performance parity not claimed."},"  ")); report.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
