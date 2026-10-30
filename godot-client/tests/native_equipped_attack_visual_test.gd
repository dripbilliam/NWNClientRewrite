extends "res://tests/native_particle_schedule_test.gd"
const Equipped=preload("res://systems/native_data/equipped_attack_visual.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target==BINARY_SHA and oracle.cases.size()==952,"Pinned original equipped owner corpus")
	for row in oracle.cases:
		var input: Dictionary=row.input; var state:={"enabled":int(input.initial),"attackType":int(input.attackType)}; var calls: Array=[]
		var p:={"exists":func(model):calls.append({"operation":"exists","resource":model}); return int(input.exists),
			"load":func(model,slot,flags):calls.append({"operation":"load","resource":model,"slot":slot,"flags":flags}); return int(input.load),
			"configure":func(slot,a,b):calls.append({"operation":"configure","slot":slot,"arg2":a,"arg3":b}),
			"colour":func(rgb,scope,flags):calls.append({"operation":"colour","rgb":rgb,"scope":scope,"flags":flags}),
			"remove":func(slot):calls.append({"operation":"remove","slot":slot}),"clear_colour":func(scope):calls.append({"operation":"clear-colour","scope":scope}),
			"unarmed":func(enabled):
				# Controlled lower boundary matches the original corpus: gate0,
				# absent special slots. Full loader/play have separate original tests.
				if enabled==1 and int(state.attackType) in [39,296]: calls.append({"operation":"special-load","kind":2 if int(state.attackType)==39 else 3})}
		Equipped.transition(state,int(input.enabled),input if input.equipped else null,p)
		var difference:=same(calls,row.calls)
		check(difference.is_empty() and int(state.enabled)==int(row.enabled) and int(state.attackType)==int(row.attackType),"Original equipped transition "+str(checks)+" "+difference)
	check(Equipped.resource("abcdefghijklmn").is_empty(),"Out-of-contract long resource never reproduces native stack corruption")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(args.oracle),"scope":"952 unchanged original equipped attack-visual transition instruction cases; actual model/colour/lifecycle providers require separate integration checks","publicConnections":0},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
