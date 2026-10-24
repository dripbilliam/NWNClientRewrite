extends SceneTree
const Beam = preload("res://systems/visual_beam.gd")
const Reference = preload("res://systems/model_reference_state.gd")
const Compare = preload("res://tests/client_fade_test.gd")
static func reference_values(value: Variant) -> Variant:
	# Original callbacks contain FLOAT quaternions. JSON parses decimal numbers
	# as doubles; compare their FLOAT values rather than parser rounding residue.
	if value is float or value is int:return Reference.f(value)
	if value is Array:return value.map(func(v):return reference_values(v))
	return value
func _initialize() -> void:
	var beam_path := "";var reference_path := "";var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--beam-oracle="):beam_path = arg.substr(14)
		if arg.begins_with("--reference-oracle="):reference_path = arg.substr(19)
		if arg.begins_with("--report="):output = arg.substr(9)
	if output.is_empty() or beam_path.is_empty() or reference_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var beam: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(beam_path));var references: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var target := "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
	if beam.binarySha256 != target or references.binarySha256 != target:quit(2);return
	var failures: Array = [];var comparisons := 0
	for row in beam.rows:
		var c: Dictionary = row.case;var calls: Array = [];var models := [{"index":0},{"index":1}]
		var e := {"target54":123,"source58":789,"proceduralB8":models[0] if c.model else null,"sourceAnchor28":c.sourceAnchor,"targetAnchor38":c.targetAnchor,"updateProgramD8":c.enabled}
		var p := {"clientObject":func(id):calls.append(["object",id]);return ({"who":"target"} if c.target else null) if id == 123 else ({"who":"source"} if c.source else null),
			"renderObject":func(object):calls.append(["render",object.who]);return object if c[object.who+"Render"] else null,
			"modelHandle":func(object,part,mode):calls.append(["handle",object.who,part,mode]);return object.who if c[object.who+"Handle"] else null,
			"setParent":func(model,parent,name,flags):
				calls.append(["parent",model.index,parent,str(name),flags])
				if c.replace:e.proceduralB8 = models[1],
			"reattachReferences":func(model,parent,name):calls.append(["reattach",model.index,parent,name]),
			"programString":func(id,column):calls.append(["string",id,column]);return {"found":c.found,"value":c.animation},
			"playAnimation":func(model,name,speed,flags,time):calls.append(["play",model.index,name,speed,flags,time]),"setScene":func(model,scene):calls.append(["scene",model.index,scene])}
		if c.mode == "attach":Beam.attach(e,p)
		else:
			if c.enabled:calls.append(["type",int(c.program)&65535])
			if c.mode == "start":Beam.start(e,int(c.program),p)
			else:Beam.stop(e,p)
		for pair in [[calls,row.calls],[e.proceduralB8.index if e.proceduralB8 != null else null,row.model]]:
			comparisons += 1
			if not Compare.same(pair[0],pair[1]):failures.append({"kind":"beam","case":c,"actual":pair[0],"expected":pair[1]})
	for row in references.rows:
		var c: Dictionary = row.case;var calls: Array = [];var owner := {"position":c.position.map(func(v):return Reference.f(v)),"quaternion":c.quaternion.map(func(v):return Reference.f(v))};var target_owner := {"target":true}
		var parts: Array = []
		for i in c.references.size():parts.append({"index":i,"reference":c.references[i],"header8":{"flags98":c.flags[i],"reattachableE0":c.reattachable[i]},"model68":{"index":i,"position":c.childPositions[i].map(func(v):return Reference.f(v))} if c.present[i] else null,"children38":[]})
		for i in parts.size():
			for child in c.children[i]:parts[i].children38.append(parts[int(child)])
		Reference.reattach(owner,target_owner if c.target else null,"impact",{"root":func(_owner):return parts[0],"asReference":func(part):return part if part.reference else null,"name":func(part):return "part"+str(part.index),
			"attach":func(model,parent,name,flags):calls.append(["attach",model.index,"target" if is_same(parent,target_owner) else "owner",name,flags]),
			"position":func(model):
				if not is_same(model,owner):calls.append(["position",model.index,owner.quaternion.duplicate()])
				return model.position,
			"orientation":func(object):return object.quaternion,"setOrientation":func(object,q):object.quaternion = q})
		for pair in [[calls,row.calls],[owner.quaternion,row.quaternion]]:
			comparisons += 1
			if not Compare.same(reference_values(pair[0]),reference_values(pair[1])):failures.append({"kind":"references","case":c,"actual":pair[0],"expected":pair[1]})
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"beamCases":beam.rows.size(),"referenceCases":references.rows.size(),"comparisons":comparisons,"failures":failures,"beamSourceSha256":FileAccess.get_sha256("res://systems/visual_beam.gd"),"referenceSourceSha256":FileAccess.get_sha256("res://systems/model_reference_state.gd")},"\t"));file.close();print("BEAM_REFERENCE_STATE ",comparisons," comparisons; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
