extends SceneTree
const NativeWorld=preload("res://systems/native_render/effect_world.gd")
const Dummy=preload("res://systems/native_render/client_dummies.gd")
const Fixtures=preload("res://tests/native_effect_membership_test.gd")
var checks:=0
var failures: Array=[]
class ObservedRuntime extends RefCounted:
	var value: Dictionary
	var hook: Callable
	var state: Dictionary:
		get:
			if hook.is_valid(): hook.call()
			return value
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<24: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func fixture() -> Dictionary:
	var log:=Fixtures.Log.new();var world:=NativeWorld.new();world.client=world;world.controlled_id=123
	world.world={"desired":{}};world.client_dummies=Dummy.new()
	return {"world":world,"log":log,"states":[]}
func reserve(f: Dictionary,id: int,actor: int,token: int,s: Dictionary,area: bool=false,pending: bool=false) -> void:
	var w=f.world
	w.receive({"kind":"visual-reserve","effectId":id,"actorId":actor,"privateToken":token,"visualId":int(s.visualF8),"areaVisual":area,"transient":false})
	if not pending:
		var runtime:=Fixtures.Runtime.new();runtime.configure(s,id,f.log);w.entries[id].runtime=runtime;f.states.append(s)
func dispose(f: Dictionary) -> void:
	f.log.enabled=false
	for entry in f.world.entries.values():
		if entry.runtime is Fixtures.Runtime: entry.runtime.attach_hook=Callable()
	f.world.client_dummies.entries.clear();f.world.close();f.world.client_dummies.free();f.world.free();f.clear()
func scripted(w,actor: int,token: int) -> Dictionary:
	var selected: Array=w._selection_entries(actor,token)
	var states: Array=w._selection_states(selected);var types: Dictionary={}
	for state in states: types[int(state.programType10d)&255]=true
	return {"selected":selected,"states":states,"types":types.keys()}
func compare(w,actor: int,token: int,label: String) -> void:
	var expected:=scripted(w,actor,token);var actual: Dictionary=w._selection_snapshot(actor,token)
	check(not actual.has("error"),label+" accepted")
	if actual.has("error"): return
	check(expected.selected.size()==actual.selected.size(),label+" exact member count")
	for index in mini(expected.selected.size(),actual.selected.size()):
		check(is_same(expected.selected[index],actual.selected[index]),label+" physical entry identity")
		check(is_same(expected.states[index],actual.states[index]),label+" live state identity")
	check(expected.types==actual.types,label+" first-occurrence masked type order")
func randomized() -> void:
	var random:=RandomNumberGenerator.new();random.seed=0x1a7e924b
	for trial in 512:
		var f:=fixture();var w=f.world;w.indexed_membership=(trial&1)==0
		var actor: int=4294967086 if trial%3 else (1<<54)+123
		var lifetime: Variant=float(1<<40) if trial%2 else (1<<54)+7
		w.world.desired[actor]={"object":{"nativeLifetime":lifetime}}
		w.world.desired[actor+1]={"object":{}}
		w.client_dummies.entries[actor]={"token":9};w.client_dummies.closed=trial%11==0
		for index in 24:
			var id: int=(1<<54)+trial*100+index
			var owner:=actor if index%5 else actor+1;var token:=0 if index%3 else 9
			var s:={"finishedF4":index%7==0,"field110":0,"attached114":0,"closedEc":0,"scope10c":index%4,"programType10d":random.randi_range(-1024,1024),"visualF8":456}
			reserve(f,id,owner,token,s,index%13==0,index%17==0)
			if index%4: w.records[id]={"lifetime":lifetime if owner==actor else 0,"area":false}
			if index%6==0 and w.records.has(id): w.records[id].lifetime=3
		for token in [0,9,8]: compare(w,actor,token,"mixed "+str(trial)+"/"+str(token))
		# Neither binding nor the absence of a binding may persist across calls.
		w.world.desired.erase(actor);compare(w,actor,0,"retired actor "+str(trial))
		w.client_dummies.entries[actor].token=8;compare(w,actor,9,"reused private owner "+str(trial))
		dispose(f)
func projection(compiled: bool) -> Dictionary:
	var f:=fixture();var w=f.world;w.world.desired[123]={"object":{"nativeLifetime":4}}
	for index in 3:
		reserve(f,index+1,123,0,{"programType10d":index,"visualF8":1})
		w.records[index+1]={"lifetime":4,"area":false}
	var first:=ObservedRuntime.new();first.value={"programType10d":0}
	var last:=ObservedRuntime.new();last.value={"programType10d":2}
	w.entries[1].runtime=first;w.entries[3].runtime=last
	last.hook=func():first.value.programType10d=260;w.world.desired.clear();f.log.put("last-state")
	var result: Dictionary=w._selection_snapshot(123,0) if compiled else scripted(w,123,0)
	check(not result.has("error"),"Property projection remains a separate accepted walk")
	var output:={"ids":result.selected.map(func(e):return e.id),"states":result.states.duplicate(true),"types":result.types,"calls":f.log.events.duplicate(true)}
	last.hook=Callable();w.entries[1].runtime=null;w.entries[3].runtime=null;dispose(f);return output
func lifecycle(compiled: bool) -> Dictionary:
	var f:=fixture();var w=f.world;w.compiled_snapshot=compiled
	w.world.desired={123:{"object":{"nativeLifetime":4}},456:{"object":{"nativeLifetime":5}}}
	for index in 4:
		var s:={"finishedF4":0,"field110":0,"attached114":0,"closedEc":0,"scope10c":index%3,"programType10d":0,"visualF8":456}
		reserve(f,index+1,123 if index<3 else 456,0,s);w.records[index+1]={"lifetime":4 if index<3 else 5,"area":false}
	var once:={"done":false}
	w.entries[1].runtime.attach_hook=func():
		if once.done: return
		once.done=true;f.log.put("nested-enter");w.select_actor(456);f.log.put("nested-exit");w.world.desired[123].object.nativeLifetime=7
	w.select_actor(123);w.select_actor(123)
	w.records[1].lifetime=7;w.records[2].lifetime=7;w.records[3].lifetime=7;w.select_actor(123)
	var result:={"events":f.log.events.duplicate(true),"states":f.states.duplicate(true)}
	check(once.done and w.compiled_snapshot_failures==0,"Nested attach and owner reuse finish without snapshot errors")
	check((w.compiled_snapshot_calls>0)==compiled,"Actual canonical world exercises exactly the selected snapshot path")
	check(w.selection_contexts.is_empty(),"No invocation context remains after nested selection")
	dispose(f);return result
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(ClassDB.class_has_method("NwnParticleKernel","visual_snapshot"),"Native snapshot implementation is loaded")
	randomized()
	check(projection(false)==projection(true),"All bindings precede all runtime reads, and all runtime reads precede type discovery")
	check(lifecycle(false)==lifecycle(true),"Nested selection, mutable lifetime and later fresh admission match the retained actual-world path")
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"randomized_worlds":512,"public_connections":0,"scope":"Canonical actual-world snapshot versus retained filter/map/type setup: physical identity/order, pending/area entries, signed/wide IDs and lifetimes, JSON numeric values, private tokens, retired/reused owners, separate mutable runtime projection, type masking and nested imperative selection. Original selector/phase/image proofs remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
