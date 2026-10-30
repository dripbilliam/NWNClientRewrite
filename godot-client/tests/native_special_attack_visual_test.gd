extends "res://tests/native_particle_schedule_test.gd"
const Special=preload("res://systems/native_data/special_attack_visual.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var file_name:="res://reports/native-special-attack-original-v1.json"; var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file_name))
	check(oracle.target==BINARY_SHA,"Original special-attack executable identity")
	check(oracle.gates.size()==112 and oracle.loads.size()==728 and oracle.plays.size()==96,"Complete stored gate/load/play case counts")
	for row in oracle.gates:
		var c: Dictionary=row.input
		check(Special.gate(c.classes,c.feats,int(c.mode))==int(row.result),"Original gate "+JSON.stringify(c))
	for group in ["loads","plays"]:
		for row in oracle[group]:
			var c: Dictionary=row.input; var calls: Array=[]; var s:=Special.create(); var serial: Array=[0]
			for i in 4:
				if (int(c.slots)>>i)&1: s.slots[i]={"slot":i}
			var providers:={"animation":func():return int(c.get("animation",0)),"modelPart":func(_slot):return int(c.get("partFE",0)),"sourceModel":func(_slot,_flags):return 1,
				"create":func(resource,name):calls.append({"operation":"create","resource":resource,"name":name}); serial[0]+=1; return {"resource":resource,"serial":serial[0]},
				"attach":func(handle,_host,part,flags):calls.append({"operation":"attach","slot":s.slots.find(handle),"part":part,"flags":flags}),
				"play":func(handle,clip,speed,flags,time):calls.append({"operation":"play","slot":s.slots.find(handle),"clip":clip,"speed":speed,"flags":flags,"time":time}),
				"warning":func(_reason):calls.append({"operation":"warning"})}
			if group=="loads": Special.load_models(s,int(c.kind),providers)
			else: Special.play(s,int(c.kind),providers)
			var actual:={"calls":calls}; var expected:={"calls":row.calls}
			if group=="loads": actual.slots=s.slots.map(func(handle):return handle!=null); expected.slots=row.slots
			var difference:=same(actual,expected)
			check(difference.is_empty(),"Original "+group+" "+JSON.stringify(c)+" "+difference)
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(file_name),"scope":"936 unchanged original gate/load/play executions with controlled constructor/vtable boundaries; actual scene/server and full outer effect-owner lifetime are separate acceptance."},"\t")); file.close()
	print("NATIVE_SPECIAL_ATTACK_DATA ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
