extends "res://tests/native_particle_schedule_test.gd"
const Parry=preload("res://systems/native_data/parry_visual.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle:="res://../backups/animations/native-client-parry-visual-observations.json"; var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(data.target==BINARY_SHA,"Original mode0 target identity")
	check(data.cases.size()==52,"52 complete original parry placement executions")
	for row in data.cases:
		var c: Dictionary=row.case; var calls: Array=[]; var source:={"id":1}; var target:={"id":2}
		var result:=Parry.place(source,{"targetId":func(_actor):return c.targetId,"object":func(id):calls.append(["target",id]); return null if c.get("missingTarget",false) else target,
			"creatureSpace":func(_actor):calls.append(["space"]); return c.space,"impactPose":func(_actor):calls.append(["impact"]); return null if c.get("missingImpact",false) else c.impact,
			"position":func(actor):return c.position if int(actor.id)==1 else c.target,"orientation":func(_actor):return c.orientation,"warning":func(_reason):calls.append(["warning"]),
			"areaVisual":func(_actor,id,position):calls.append(["area",id,position]); return int(c.get("areaResult",1))})
		var difference:=same({"calls":calls,"result":result},{"calls":row.calls,"result":row.result})
		check(difference.is_empty(),"Complete original mode0 "+JSON.stringify(c)+" "+difference)
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(oracle),"scope":"52 complete original SpawnHitVisuals mode0 executions with explicit object/2DA/impact/area services; no real actor, server outcome or pixels here."},"\t")); file.close()
	print("NATIVE_PARRY_VISUAL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
