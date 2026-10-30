extends "res://tests/native_particle_schedule_test.gd"
const Scopes=preload("res://systems/native_data/model_colour_scopes.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target==BINARY_SHA and oracle.cases.size()==1024,"Pinned original colour scope/composer corpus")
	for row in oracle.cases:
		var input: Dictionary=row.input; var state:=Scopes.create(); state.present=input.present; state.colours=input.colours.duplicate(true)
		for i in 5: state.active[i]=(int(input.mask)&(1<<i))!=0
		var result:=Scopes.set_colour(state,int(input.scope),input.colour if input.operation=="set" else null)
		var selected: Variant=Scopes.selected(state); var calls: Array=[]
		if result: calls=[{"method":"0x180","rgb":selected if selected!=null else [0.0,0.0,0.0],"flags":1},{"method":"0x178","rgb":selected if selected!=null else [1.0,1.0,1.0],"alpha":input.alpha,"flags":1}]
		var difference:=same(calls,row.calls)
		check(int(result)==int(row.result) and state.active==row.active and same(state.colours,row.colours).is_empty() and difference.is_empty(),"Original colour state/selection "+str(checks)+" "+difference)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(args.oracle),"scope":"1024 original colour set/clear/composer instruction cases; raw virtual method outputs and scope priority, not full original shader rendering","publicConnections":0},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
