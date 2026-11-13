extends SceneTree
const Cache=preload("res://systems/native_data/ruleset_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==72,"Parser corpus pins unchanged original atoi and decimal parser")
	for row in oracle.rows: check(Cache.atoi(str(row.text))==int(row.value),"Native decimal prefix/sign/overflow/C-locale parsing: "+str(row.text))
	var source:={"columns":["LABEL","VALUE"],"orderedRows":[{"LABEL":"Exact","VALUE":"3"},{"LABEL":"Exact","VALUE":"****"},{"LABEL":"Exact","VALUE":"  -7tail"},{"LABEL":"exact","VALUE":"9"},{"LABEL":"Zero","VALUE":"0"},{"LABEL":"Invalid","VALUE":"words"},{"LABEL":"Hex","VALUE":"0x12"},{"LABEL":"Limit","VALUE":"4294967295"},{"LABEL":"","VALUE":"1"},{"LABEL":"****","VALUE":"2"}]}
	var owner:=Cache.Owner.new(); var entry:=owner.prepare(source,[1,"server-a",1]); var tables:=entry.overlay({})
	check(Cache.current(tables)==entry and entry.integer("Exact",5)==-7 and entry.integer("exact",5)==9 and entry.integer("EXACT",5)==5,"Original exact label and last nonempty duplicate semantics")
	check(entry.integer("Zero",5)==0 and entry.integer("Invalid",5)==0 and entry.integer("Absent",5)==5,"Explicit zero, invalid text and missing labels remain distinct")
	check(entry.integer("Hex",5)==0 and entry.integer("Limit",5)==2147483647,"Ruleset parses decimal prefixes and clamps original signed32 overflow")
	check(not entry.values_view().has("") and not entry.values_view().has("****"),"Original missing/empty labels do not create cache entries")
	check(entry.source_view().is_read_only() and entry.source_view().orderedRows.is_read_only() and entry.source_view().orderedRows[0].is_read_only() and entry.values_view().is_read_only(),"Published source and index are recursively immutable")
	check(not source.is_read_only() and not source.orderedRows.is_read_only() and not source.orderedRows[0].is_read_only(),"The resource caller retains mutable ownership of its original input")
	source.orderedRows[0].VALUE="99"; source.orderedRows.append({"LABEL":"Added","VALUE":"4"})
	check(entry.integer("Added",5)==5 and entry.source_view().orderedRows.size()==10,"Caller mutation cannot change a published source or cached data")
	var next:=owner.prepare(source,[1,"server-a",2]); var updated:=next.overlay({})
	check(Cache.current(tables)==null and Cache.current(updated)==next and next.integer("Added",5)==4,"Republishing even the same caller dictionary invalidates old cache leases")
	var bypass:=updated.duplicate(); bypass.ruleset={"orderedRows":[{"Label":"Exact","Value":"12"}]}
	check(Cache.current(bypass)==null and Cache.from_source(bypass,"Exact",5)==12,"A bypass replacement never resolves the old source index")
	owner.retire(); check(Cache.current(updated)==null,"Reconnect/close retirement rejects all preceding cache references")
	var other_owner:=Cache.Owner.new(); var other:=other_owner.prepare({"orderedRows":[{"Label":"Exact","Value":"42"}]},[2,"server-b",1]); var other_tables:=other.overlay({})
	check(Cache.current(other_tables)==other and other.integer("Exact",5)==42,"Independent resource owners never share caches by filename")
	for label in ["Exact","exact","EXACT","Zero","Invalid","Absent","Hex","Limit","","****"]:
		check(Cache.from_source({"ruleset":source},label,5)==next.integer(label,5),"Uncached source fallback uses the same native parser: "+label)
	check(Cache.current({})==null and Cache.from_source({},"Unknown",13)==13,"Unpublished/missing tables have no cache and preserve the caller default")
	var snapshot:=other.snapshot(); snapshot.scope[0]=99
	check(other.snapshot().scope[0]==2,"Diagnostic scopes are detached")
	other_owner.retire(); var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"productionIntegrated":false,"gpuBenchmark":false},"  ")+"\n"); output.close(); quit(0 if failures.is_empty() else 1)
