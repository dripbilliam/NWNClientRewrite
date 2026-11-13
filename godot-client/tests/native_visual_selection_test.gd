extends SceneTree
const Selection=preload("res://systems/visual_selection.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<24: failures.append(label)
func equal(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a)==float(b)
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for n in a.size():
			if not equal(a[n],b[n]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	return typeof(a)==typeof(b) and a==b
func state(id: int,data: Dictionary={}) -> Dictionary:
	return {"id":id,"finishedF4":data.get("finished",0),"field110":data.get("field110",0),"attached114":data.get("attached",0),"closedEc":data.get("closed",0),"scope10c":data.get("scope",0),"programType10d":data.get("type",0),"visualF8":data.get("visual",0)}
func ports(calls: Array,controlled: int,view: bool,hook: Callable=Callable()) -> Dictionary:
	return {"programType":func(e):return int(e.programType10d)&255,
		"selectedObjectId1406ac1c0":func():calls.append(["selectedObjectId1406ac1c0"]);return controlled,
		"viewGate1407dadb0":func():calls.append(["controlled"]);calls.append(["viewGate1407dadb0"]);return view,
		"attach":func(e):calls.append(["attach",e.id]);e.attached114=1;if hook.is_valid():hook.call("attach",e),
		"detach":func(e):calls.append(["detach",e.id]);e.attached114=0;if hook.is_valid():hook.call("detach",e),
		"start":func(e):calls.append(["start",e.id]);e.closedEc=0;if hook.is_valid():hook.call("start",e),
		"stop":func(e,value):calls.append(["stop",e.id,value]);e.closedEc=1;if hook.is_valid():hook.call("stop",e)}
func invoke(native: bool,actor: Dictionary,kind: int,p: Dictionary,current: Variant=null) -> Dictionary:
	if native:
		return ClassDB.class_call_static("NwnParticleKernel","visual_select",actor,kind,p) if current==null else ClassDB.class_call_static("NwnParticleKernel","visual_detach_competing",actor,current,p)
	if current==null: Selection.select(actor,kind,p)
	else: Selection.detach_competing(actor,current,p)
	return {}
func original_cases() -> int:
	var total:=0;var base:=ProjectSettings.globalize_path("res://").path_join("../backups/animations").simplify_path()
	for name in ["selection","competing-removal"]:
		var observations: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("native-visual-"+name+"-observations.json")))
		check(observations.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original build identity")
		for row in observations.rows:
			var c: Dictionary=row.case;var outputs: Array=[]
			for native in [false,true]:
				var calls: Array=[];var entries: Array=[]
				for index in c.entries.size(): entries.append(state(index,c.entries[index]))
				var p:=ports(calls,int(c.controlledId),bool(c.viewGate1407dadb0));var actor:={"id":123,"suppressed108":c.suppressed,"visuals80":entries}
				var result:=invoke(native,actor,int(c.type),p) if name=="selection" else invoke(native,actor,0,p,entries[int(c.remove)])
				check(not result.has("error"),"Original native selector input accepted "+str(total))
				check(equal(calls,row.calls),"Original exact callback order "+name+"/"+str(total)+"/"+str(native))
				check(equal(entries.map(func(e):return e.attached114),row.attached),"Original exact attachment state "+str(total))
				if name=="selection": check(equal(entries.map(func(e):return e.closedEc),row.closed),"Original restart/stop state "+str(total))
				outputs.append({"calls":calls.duplicate(true),"entries":entries.duplicate(true)});p.clear()
			check(equal(outputs[0],outputs[1]),"Native/script complete mutations "+str(total));total+=1
	return total
func dynamic_case(native: bool,mode: String) -> Dictionary:
	var calls: Array=[];var entries: Array=[];var actor:={"id":4294967086,"suppressed108":0,"visuals80":entries};var once:={"done":false}
	if mode in ["identity","alias"]:
		var shared:=state(0,{"scope":1,"attached":1});entries.append(shared);entries.append(shared if mode=="alias" else shared.duplicate(true))
	else: entries.append(state(0));entries.append(state(1,{"scope":1,"attached":1,"type":4,"closed":1}))
	if mode=="wide-id": entries[0].visualF8=182
	var hook:=func(operation,e):
		if once.done: return
		once.done=true
		if mode=="mutate" and operation=="attach": entries[1].finishedF4=1;entries[1].scope10c=2
		elif mode=="append": actor.visuals80.append(state(2))
		elif mode=="replace": actor.visuals80=[state(2,{"scope":1,"attached":1})]
		elif mode=="reentrant":
			calls.append(["nested-enter"]);var nested_calls: Array=[];var p2:=ports(nested_calls,123,true)
			var result:=invoke(native,{"id":123,"suppressed108":0,"visuals80":[state(8,{"type":4,"scope":1,"closed":1})]},4,p2)
			check(not result.has("error"),"Nested native selector succeeds");calls.append_array(nested_calls);calls.append(["nested-exit"]);p2.clear();entries[1].attached114=0
	var p:=ports(calls,4294967086,true,hook);var result:=invoke(native,actor,0 if mode not in ["identity","alias"] else 0,p)
	check(not result.has("error"),"Dynamic selector input accepted "+mode)
	var output:={"calls":calls.duplicate(true),"initial":entries.duplicate(true),"final":actor.visuals80.duplicate(true)};p.clear();return output
func failures_and_gates() -> void:
	var suppressed: Dictionary=ClassDB.class_call_static("NwnParticleKernel","visual_select",{"suppressed108":1},0,{})
	check(not suppressed.has("error"),"Suppression returns before touching an absent list or unused providers")
	var empty: Dictionary=ClassDB.class_call_static("NwnParticleKernel","visual_select",{"suppressed108":0,"visuals80":[]},0,{})
	check(not empty.has("error"),"Empty list never touches unused ports")
	var calls: Array=[];var first:=state(0);var second:=state(1,{"type":4,"scope":1,"closed":1})
	var p:=ports(calls,123,true);p.erase("start")
	# First type-0 mutation happens before a later same-type callback failure.
	second.programType10d=0;second.scope10c=0
	var actor:={"id":123,"suppressed108":0,"visuals80":[first,second]}
	p.attach=func(e):calls.append(["attach",e.id]);e.attached114=1;p.erase("attach")
	var failed: Dictionary=ClassDB.class_call_static("NwnParticleKernel","visual_select",actor,0,p)
	check(failed.has("error") and failed.partial and int(failed.callback_attempts)==2,"Failure reports a partial imperative walk, never a retryable action plan")
	check(equal(calls,[["attach",0]]) and first.attached114==1 and second.attached114==0,"Already executed callback is retained exactly once on failure")
	p.clear()
func restart_state(native: bool) -> Dictionary:
	var calls: Array=[];var effect:=state(0,{"type":4,"scope":1,"closed":1})
	var hook:=func(operation,e):
		if operation=="start": e.attached114=1;e.programType10d=260
	var p:=ports(calls,123,true,hook);var result:=invoke(native,{"id":123,"suppressed108":0,"visuals80":[effect]},260,p)
	check(not result.has("error"),"Restart callback with a mutable cached type succeeds")
	var output:={"calls":calls.duplicate(true),"state":effect.duplicate(true)};p.clear();return output
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	check(ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","visual_select"),"Compiled native selector is loaded")
	if not failures.is_empty(): quit(1);return
	var total:=original_cases()
	for mode in ["identity","alias","mutate","append","replace","reentrant","wide-id"]:
		var a:=dynamic_case(false,mode);var b:=dynamic_case(true,mode)
		check(equal(a,b),"Exact live-state/list/identity/reentrant trace "+mode)
	check(equal(restart_state(false),restart_state(true)),"Clock restart mutation is read before deciding whether to attach")
	failures_and_gates();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"recorded_original_cases":total,"dynamic_cases":7,"public_connections":0,"scope":"Both original selection/removal instruction corpora plus mutable states/lists, distinct equal dictionaries, aliased states, wide unsigned object IDs, nested calls, suppression and partial callback failure. Uses cached programType10d byte matching the production world's pure type getter. Full native world lifetime/phase integration and performance are separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
