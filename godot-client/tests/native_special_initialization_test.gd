extends "res://tests/native_particle_schedule_test.gd"
const Init=preload("res://systems/native_data/special_initialization.gd")
const Special=preload("res://systems/native_data/special_attack_visual.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://reports/native-special-initialization-original-v1.json"; var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.target==BINARY_SHA and oracle.initializers.size()==192 and oracle.eyes.size()==672,"Unchanged original initialization/aura target and case counts")
	for entry in oracle.initializers:
		var c: Dictionary=entry.input; var s:=Special.create(); var calls: Array=[]
		for i in 2:
			if (int(c.slots)>>i)&1: s.slots[i]={"slot":i}
		var p:={"gate":func(mode):calls.append({"operation":"gate","mode":mode}); return int(c.gates[mode]),"present":func():return bool(c.present),"style":func():return int(c.style),"eyes":func():calls.append({"operation":"eyes"}),
			"play":func(h,clip,speed,flags,time):calls.append({"operation":"play","slot":h.slot,"clip":clip,"speed":speed,"flags":flags,"time":time})}
		# The original corpus controls the loader boundary here. Gate/load/play
		# have their own complete unchanged-instruction corpus and native tests.
		p.animation=func():calls.append({"operation":"load","kind":0}); return 0
		p.create=func(_resource,_name):return {}
		p.modelPart=func(_slot):return 0
		Init.initialize(s,p)
		check(same(calls,entry.calls).is_empty(),"Original initialization "+JSON.stringify(c)+" "+same(calls,entry.calls))
	for entry in oracle.eyes:
		var c: Dictionary=entry.input; var s:=Init.create_eye(); s.flags=c.flags.duplicate(); s.model={} if c.existing else null; var calls: Array=[]
		var p:={"destroy":func(_h):calls.append({"operation":"destroy"}),"create":func(resource,name):calls.append({"operation":"create","resource":resource,"name":name}); return null if c.failed else {},"sourceModel":func(_slot,_flags):return 1,
			"attach":func(_h,_host,part,flags):calls.append({"operation":"attach","part":part,"flags":flags}),"scale_entry":func(row,column):calls.append({"operation":"table","row":row,"column":column}); return {"found":c.scaleFound,"value":c.scale},
			"scale":func(_h,value,flags):calls.append({"operation":"scale","value":value,"flags":flags}),"play":func(_h,clip,speed,flags,time):calls.append({"operation":"play","clip":clip,"speed":speed,"flags":flags,"time":time})}
		Init.eye(s,int(c.alignment),int(c.appearance),int(c.gender),int(c.phenotype),p)
		var actual:={"calls":calls,"flags":s.flags,"model":s.model!=null}; var expected:={"calls":entry.calls,"flags":entry.flags,"model":entry.model}
		check(same(actual,expected).is_empty(),"Original eye owner "+JSON.stringify(c)+" "+same(actual,expected))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(path),"scope":"Original initialization plus eye-model selection/cache/failure/attachment/scale/play order. Controlled table and model boundaries; real native models/server/visible pixels accepted separately."},"\t")); file.close()
	print("NATIVE_SPECIAL_INITIALIZATION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
