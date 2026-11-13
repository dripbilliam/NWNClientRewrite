extends "res://tests/native_visual_selection_test.gd"
const NativeWorld=preload("res://systems/native_render/effect_world.gd")
const Dummies=preload("res://systems/native_render/client_dummies.gd")
const Fixtures=preload("res://tests/native_effect_membership_test.gd")
var proven_cases:=0
var full_cases:=0
func proof(entries: Array) -> Dictionary:
	var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","visual_no_actions_proof",entries)
	check(not result.has("error"),"Complete selector schema can be checked without actions")
	return result
func all_types(entries: Array,calls: Array) -> void:
	var types: Dictionary={}
	for entry in entries:types[int(entry.programType10d)&255]=true
	var p:=ports(calls,123,false)
	for type in types: Selection.select({"id":123,"suppressed108":0,"visuals80":entries},int(type),p)
	p.clear()
func inspect_case(entries: Array,label: String) -> void:
	var before:=entries.duplicate(true);var result:=proof(entries)
	check(equal(entries,before),"Proof itself never mutates state: "+label)
	var calls: Array=[];all_types(entries,calls)
	if result.get("no_actions_proven",false):
		proven_cases+=1
		check(calls.is_empty(),"Proven invocation has no original callbacks, gates or diagnostics: "+label)
		check(equal(entries,before),"Proven invocation has no original mutations: "+label)
	else: full_cases+=1
func original_proof() -> int:
	var path:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-visual-selection-observations.json").simplify_path()
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var count:=0
	check(capture.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Immutable original selector build identity")
	for row in capture.rows:
		var entries: Array=[]
		for index in row.case.entries.size():entries.append(state(index,row.case.entries[index]))
		var result:=proof(entries)
		if result.get("no_actions_proven",false):check(row.calls.is_empty(),"No-action proof agrees with captured original instruction callbacks "+str(count))
		inspect_case(entries,"original "+str(count));count+=1
	return count
func randomized_proof() -> void:
	var random:=RandomNumberGenerator.new();random.seed=0x1ab76290
	for trial in 4096:
		var entries: Array=[]
		for index in random.randi_range(0,12):
			var data:={"type":random.randi_range(-256,512),"scope":random.randi_range(0,4),"attached":random.randi_range(0,1),"closed":random.randi_range(0,1),"finished":random.randi_range(0,1),"field110":0,"visual":456}
			if trial%5==0:data.scope=0;data.attached=1;data.finished=0
			if trial%5==1:data.type=4;data.finished=0;data.scope=1+index%3;data.closed=0;data.attached=0
			if trial%5==2:data.field110=index%2;data.visual=182 if index%3 else 65536+243
			var next:=state(index,data)
			if index%2==0:next.scope10c=float(next.scope10c);next.programType10d=float(next.programType10d)
			entries.append(next)
		if trial%5==1:
			var warm: Array=[];all_types(entries,warm)
			check(proof(entries).get("no_actions_proven",false),"Settled competing scopes/type-4 restarts can be proven without callbacks")
		inspect_case(entries,"mixed "+str(trial))
	for alias in [false,true]:
		var shared:=state(1,{"scope":1,"type":4,"attached":1})
		var entries: Array=[shared,shared if alias else shared.duplicate(true)]
		check(bool(proof(entries).get("no_actions_proven",false))==alias,"Equal dictionary values do not replace physical identity")
		inspect_case(entries,"alias "+str(alias))
func integration() -> void:
	var log:=Fixtures.Log.new();var w:=NativeWorld.new();w.client=w;w.controlled_id=123
	w.world={"desired":{123:{"object":{"nativeLifetime":4}}}};w.client_dummies=Dummies.new();w.compiled_snapshot=true;w.reused_selection_setup=true
	var s:={"finishedF4":0,"field110":0,"attached114":1,"closedEc":0,"scope10c":0,"programType10d":0,"visualF8":456}
	w.receive({"kind":"visual-reserve","effectId":1,"actorId":123,"visualId":456,"transient":false})
	var runtime:=Fixtures.Runtime.new();runtime.configure(s,1,log);w.entries[1].runtime=runtime;w.records[1]={"area":false,"lifetime":4}
	w.select_actor(123)
	check(w.compiled_snapshot_noops==1 and log.events.is_empty() and w.selection_contexts.is_empty(),"Actual canonical world skips only the proven empty selection action set")
	s.attached114=0;w.select_actor(123)
	check(w.compiled_snapshot_noops==1 and log.events==[["attach",1]] and s.attached114==1,"A freshly changed attachment forces the full original action exactly once")
	s.field110=1;w.select_actor(123)
	check(w.compiled_snapshot_noops==1 and log.events.back()==["detach",1] and not w.diagnostics.is_empty(),"Observable native view gate and its diagnostic force the full path")
	check(w.compiled_snapshot_failures==0 and w.selection_contexts.is_empty(),"Action fallback leaves no selection failure or invocation context")
	log.enabled=false;w.client_dummies.entries.clear();w.close();w.client_dummies.free();w.free()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(ClassDB.class_has_method("NwnParticleKernel","visual_no_actions_proof"),"Native no-action proof is loaded")
	var originals:=original_proof();randomized_proof();integration()
	check(proven_cases>1000 and full_cases>1000,"Both proven and retained-action paths are exercised extensively")
	await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_cases":originals,"proven_cases":proven_cases,"full_cases":full_cases,"public_connections":0,"scope":"Fresh immutable-invocation no-action proof versus original recorded selector callbacks and the retained all-types selector. Includes mixed types/scopes, settled winners, tie/alias identity, finish/restart flags, view/controlled gates, numeric masks and actual canonical-world fallback. Clocks, phase updates, removal, retirement and rendering are not skipped."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
