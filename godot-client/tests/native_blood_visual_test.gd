extends "res://tests/native_particle_schedule_test.gd"
const Blood=preload("res://systems/native_data/blood_visual.gd")
func load_oracle(name: String) -> Dictionary:
	var path:="res://../backups/animations/"+name+".json"; var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==BINARY_SHA,"Original blood target "+name); evidence.append({"name":name,"sha256":FileAccess.get_sha256(path)})
	return data
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var selections:=load_oracle("native-client-blood-visual-observations"); check(selections.cases.size()==1020,"1020 original complete selector/reuse cases")
	for row in selections.cases:
		var c: Dictionary=row.case; var calls: Array=[]
		var p:={"kind":func(_actor):return int(c.get("kind",0)),"violence":func():return int(c.violence),"blood":func(_actor):calls.append(["string","appearance",2,"bloodcolr"]); return c.blood,
			"warning":func(_reason):calls.append(["warning"]),"maximum":func(_actor):calls.append(["maximum"]); return int(c.get("maximum",100)),"whiteOverride":func(_actor):return bool(c.get("white",false)),
			"lowViolence":func(id):calls.append(["int",id,"LowViolence"]); return {"found":c.get("lowViolence",true),"value":id+1000},"modelName":func(id):calls.append(["string","visualeffects",id,"imp_impact_node"]); return "blood_"+str(id)}
		var model: Variant=Blood.select({}, {"result":int(c.result),"damage":int(c.damage),"attackType":int(c.get("attackType",0)),"killingBlow":int(c.get("killing",0)),"weaponAttackType":int(c.get("weaponAttackType",1))},p)
		var result:=0
		if model!=null:
			var slots: Array=[]
			for i in 3: slots.append({"i":i} if i<int(c.get("slots",0)) else null)
			var index:=Blood.slot(slots,{"playInfo":func(o,_clip):calls.append(["info",o.i]); return -1.0 if int(c.get("finished",-1))==int(o.i) else 0.25,"destroy":func(o):calls.append(["destroy",o.i])})
			if index>=0: calls.append(["create",model])
			else: result=1
		var difference:=same({"calls":calls,"result":result},{"calls":row.calls,"result":row.result})
		check(difference.is_empty(),"Original selection/reuse "+JSON.stringify(c)+" "+difference)
	var helpers:=load_oracle("native-blood-helper-observations"); check(helpers.acos.size()==2015 and helpers.queries.size()==18,"Original acos/time-query counts")
	for row in helpers.acos:
		var expected:=Blood.from_bits(int(row.output)); var actual:=Blood.acosf(Blood.from_bits(int(row.input)))
		check(is_nan(actual) if is_nan(expected) else Blood.bits(actual)==Blood.bits(expected),"Exact original acos bits "+str(row.input))
	for row in helpers.queries:
		var runs: Array=row.runs.map(func(run):return {"clip0":{"name":run[0]},"time14":run[1]})
		check(Blood.play_info(runs,row.name)==float(row.time),"Original first physical case-insensitive run time "+JSON.stringify(row))
	var success:=load_oracle("native-client-blood-visual-success-observations"); check(success.cases.size()==380,"380 original complete successful pose cases")
	var maximum_error:=0.0; var exact:=0
	for row in success.cases:
		var c: Dictionary=row.case; var expected: Array=row.calls.filter(func(call):return call[0]=="orientation")[0][1]
		var actual:=Blood.orientation(c.get("orientation",[1,0,0]),c.get("direction",[1,0,0]),int(c.get("animation",200)),int(c.get("weaponType",1)) if c.get("weapon",true) else null)
		for i in 4:
			var error:=absf(float(actual[i])-float(expected[i])); maximum_error=maxf(maximum_error,error)
			if Blood.bits(actual[i])==Blood.bits(float(expected[i])): exact+=1
			check(error<0.000001,"Original pose tolerance (captured CRT sin/cos boundaries) "+JSON.stringify(c)+" axis "+str(i))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalEvidence":evidence,"maximum_orientation_error":maximum_error,"exact_orientation_components":exact,"scope":"1020 original complete mode1 selector/reuse, 2015 exact float acos, 18 original physical time queries and 380 successful poses; captured trig/FP services and 1e-6 pose bound retain prior original oracle scope. No real scene/server outcome here."},"\t")); file.close()
	print("NATIVE_BLOOD_VISUAL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
