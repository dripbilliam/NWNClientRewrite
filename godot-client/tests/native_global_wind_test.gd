extends SceneTree
var checks:=0
var failures: Array=[]
func same_f32(a: Variant,b: Variant) -> bool:
	# JSON decimal parsing may perturb a double below f32 precision. The native
	# fields are f32: compare their original bits, without a tolerance window.
	return PackedFloat32Array(a if a is Array else [a]).to_byte_array()==PackedFloat32Array(b if b is Array else [b]).to_byte_array()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<30: failures.append(label)
func instance(input: Dictionary) -> RefCounted:
	var owner: RefCounted=ClassDB.instantiate("NwnWindManager")
	var result: Dictionary=owner.call("dispatch",0,input)
	check(not result.has("error"),"Native wind configuration "+str(result.get("error","")))
	return owner
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var source:=ProjectSettings.globalize_path("res://../backups/animations/native-global-wind-observations-v1.json").simplify_path()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	check(data.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and data.queries.size()==1080 and data.timers.size()==45,"Original instruction wind corpus identity and counts")
	for row in data.noise:
		var owner:=instance({"seed":int(row.seed)})
		var state: Dictionary=owner.call("dispatch",4,{})
		check(same_f32(state.first,row.first) and same_f32(state.second,row.second),"Original 16x16 multiscale noise float bytes "+str(row.seed))
		check(int(state.seed)==int(row.resultSeed) and int(state.draws)==int(row.draws),"Original noise CRT draw order "+str(row.seed))
	for cached in [false,true]:
		for index in data.queries.size():
			var row: Dictionary=data.queries[index]; var noise: Dictionary=data.noise[int(row.noise)]
			var owner:=instance({"seed":1,"first":noise.first,"second":noise.second,"wind":row.wind,"deviation":row.deviation[0],"pitch":row.deviation[1],"fraction":row.fraction,"cache":cached})
			for point in row.points: owner.call("dispatch",3,{"position":point.slice(0,3),"radius":point[3],"duration":point[4],"strength":point[6]})
			var actual: Variant=owner.call("dispatch",2,{"position":row.position,"factor":row.factor})
			check(actual is Array and same_f32(actual,row.result),"Original global/point/noise/quaternion vector "+str(index)+" cache="+str(cached)+" actual="+str(actual)+" expected="+str(row.result))
			var repeated: Variant=owner.call("dispatch",2,{"position":row.position,"factor":row.factor})
			check(actual==repeated,"Repeated original wind sample retains exact result "+str(index))
			var stats: Dictionary=owner.call("dispatch",7,{})
			check(int(stats.cache_hits)==(1 if cached else 0),"Wind orientation caching follows native immutable cell inputs "+str(index))
	for index in data.timers.size():
		var row: Dictionary=data.timers[index]; var noise: Dictionary=data.noise[1]
		var owner:=instance({"seed":int(row.seed),"first":noise.first,"second":noise.second,"wind":[0.25,-2.0,0.75],"elapsed":row.elapsed,"timeout":row.timeout})
		owner.call("dispatch",1,{"seed":int(row.seed),"delta":row.delta})
		var state: Dictionary=owner.call("dispatch",4,{})
		check(same_f32(state.first,row.result.first) and same_f32(state.second,row.result.second) and same_f32(state.elapsed,row.result.elapsed) and same_f32(state.fraction,row.result.fraction) and same_f32(state.step,row.result.step),"Original timer strict boundary, refill and discarded excess time "+str(index))
		check(int(state.seed)==int(row.resultSeed) and int(state.draws)==int(row.draws),"Original timer refill consumes the same random draws "+str(index))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":data.scope,"original_queries":1080,"noise":4,"timers":45,"full_scene_wind_parity":false}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	print("NATIVE_GLOBAL_WIND ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
