extends "res://tests/native_particle_schedule_test.gd"
const State=preload("res://systems/model_reference_state.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var index:=0
	for row in original("native-reference-reattach-observations",783):
		var c: Dictionary=row.case; var calls: Array=[]; var owner:={"position":M.values(c.position),"quaternion":M.values(c.quaternion)}; var target: Dictionary={}; var parts: Array=[]
		for part_index in c.references.size(): parts.append({"index":part_index,"reference":c.references[part_index],"header8":{"flags98":c.flags[part_index],"reattachableE0":c.reattachable[part_index]},"model68":{"index":part_index,"position":M.values(c.childPositions[part_index])} if c.present[part_index] else null,"children38":[]})
		for part_index in parts.size():
			for child in c.children[part_index]: parts[part_index].children38.append(parts[int(child)])
		State.reattach(owner,target if c.target else null,"impact",{"root":func(_model):return parts[0],"asReference":func(part):return part if part.reference else null,"name":func(part):return "part"+str(part.index),"attach":func(model,parent,name,flags):calls.append(["attach",model.index,"target" if is_same(parent,target) else "owner",name,flags]),"position":func(model):
			if not is_same(model,owner): calls.append(["position",model.index,owner.quaternion.duplicate()])
			return model.position,
			"orientation":func(model):return model.quaternion,"setOrientation":func(model,value):model.quaternion=value})
		var difference:=same({"calls":calls,"quaternion":owner.quaternion},{"calls":row.calls,"quaternion":row.quaternion})
		check(difference.is_empty(),"Original BFS eligibility/attachment/quaternion "+str(index)+" "+difference); index+=1
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"Existing native BFS reattachment/calculation owner against stored original cases; transform and target Part resolution remain explicit providers"},"\t")); file.close()
	print("NATIVE_REFERENCE_REATTACH ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
