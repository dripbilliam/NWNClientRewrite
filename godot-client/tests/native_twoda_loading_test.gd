extends SceneTree
const Table=preload("res://systems/native_data/two_da.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("baseline") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var path:=str(args.baseline).path_join("systems/native_data/two_da.gd")
	var old_script:=GDScript.new(); old_script.source_code=FileAccess.get_file_as_string(path)
	check(old_script.reload()==OK,"Verified authored pre-change tokenizer compiles as the differential reference")
	var old=old_script.new(); var next:=Table.new()
	var cases: Array=["","  \t  ","a b\tc","a\rb\nc","a\u00a0b c",'"hello world" tail','"" 0','"a""b" x','"a"tail','"unterminated','"a""',"0 duplicate duplicate ****"]
	for index in 50: cases.append(str(index)+"\talpha_"+str(index)+"  ****  -1 1.25 0xFF")
	check(cases.all(func(line):return old.tokens(line)==next.tokens(line)),"Unquoted fast path and quoted/Unicode edge cases preserve original scanner output")
	var catalog:=Recorded.new(); check(catalog.mount(str(args.catalog)),"Recorded native table corpus mounts")
	var samples: Array=[]
	for name in ["appearance","racialtypes","gender","phenotype","capart","parts_robe","tailmodel","wingmodel","cloakmodel","baseitems","parts_chest","spells","feat"]:
		if not catalog.manifest.resources.has(name+":2017"): continue
		var bytes:=catalog.get_resource(name,2017); var text:=Binary.new(bytes).text(0,bytes.size())
		var began:=Time.get_ticks_usec(); var a: Dictionary=old.parse(text); var old_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); var b:=next.parse(text); var new_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(catalog.failure.is_empty() and old.failure.is_empty() and next.failure.is_empty(),"Both native parsers accept captured table: "+name)
		var previous_fields: Dictionary=b.duplicate(); previous_fields.erase("rowLabels")
		check(Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(previous_fields)),"Every existing column/default/row/cell remains exact: "+name)
		var labels: Array=[]; var lines: Array=[]
		for source in text.replace("\r", "").split("\n"):
			var line:=source.strip_edges()
			if not line.is_empty() and not line.begins_with(";"): lines.append(line)
		var start:=3 if str(lines[1]).to_upper().begins_with("DEFAULT:") else 2
		for index in range(start,lines.size()):
			var tokens: Array=old.tokens(lines[index])
			if not tokens.is_empty(): labels.append(str(tokens[0]))
		check(b.rowLabels==labels and b.rowLabels.size()==b.orderedRows.size(),"New physical labels retain exact order without changing existing row lookup: "+name)
		samples.append({"name":name,"source_sha256":Cache.digest(bytes),"bytes":bytes.size(),"rows":b.orderedRows.size(),"columns":b.columns.size(),"old_ms":old_ms,"new_ms":new_ms})
	check(samples.size()>=11,"All controlled-appearance table dependencies are covered")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"baseline_tokenizer_sha256":FileAccess.get_sha256(path),"publicConnections":0},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
