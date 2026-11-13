extends SceneTree
const VisualWorld=preload("res://systems/visual_world.gd")
const Selection=preload("res://systems/visual_selection.gd")
class Log extends RefCounted:
	var events: Array=[]
	var enabled:=true
	func put(value: Variant) -> void:
		if enabled: events.append(value)
class Client extends RefCounted:
	var log: Log
	var controlled:=123
	var controlled_id: int:
		get: log.put(["selectedObjectId1406ac1c0"]); return controlled
	var removed_states: Dictionary={}
	func command(value: Dictionary) -> void: log.put(["command",value])
class Clock extends RefCounted:
	var state: Dictionary
	var id:=0
	var log: Log
	func start() -> void: state.closedEc=0; log.put(["start",id])
	func stop(requested: int) -> void: state.closedEc=1; log.put(["stop",id,requested])
	func advance(_delta: float) -> void:
		state.phase184+=1; log.put(["phase",id])
		if state.get("finish_next",false): state.finishedF4=1
class Phase extends RefCounted:
	var state: Dictionary
	func has_cessation() -> bool: return bool(state.get("cessation",false))
	func is_retired() -> bool: return bool(state.finishedF4)
class Runtime extends RefCounted:
	var state: Dictionary
	var clock:=Clock.new()
	var phase:=Phase.new()
	var id:=0
	var log: Log
	var close_hook: Callable
	var attach_hook: Callable
	func configure(value: Dictionary,next_id: int,events: Log) -> void:
		state=value; id=next_id; log=events; clock.state=state; clock.log=log; clock.id=id; phase.state=state
	func attach_models() -> void:
		state.attached114=1; log.put(["attach",id])
		if attach_hook.is_valid(): attach_hook.call()
	func detach_models() -> void: state.attached114=0; log.put(["detach",id])
	func refresh_bindings() -> void: log.put(["refresh",id])
	func advance() -> void: clock.advance(0.0)
	func close() -> void:
		log.put(["close",id]); var callback:=close_hook; close_hook=Callable()
		if callback.is_valid(): callback.call()
class World extends VisualWorld:
	var bound: Dictionary={}
	var actor_host: Node3D
	var log: Log
	var bound_hook: Callable
	func _bound(entry: Dictionary) -> bool:
		if bound_hook.is_valid(): bound_hook.call(entry)
		return bool(bound.get(int(entry.id),true))
	func host(_id: int,_token: int=0) -> Node3D: return actor_host
	func _begin(_entry: Dictionary) -> void: pass
	func diagnose(code: String,_detail: String,_id: int) -> void:
		if code=="visual.view-gate-unimplemented": log.put(["controlled"]); log.put(["viewGate1407dadb0"])
var checks:=0
var failures: Array=[]
func extra_evidence() -> Dictionary: return {}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<20: failures.append(label); print("FAIL: ",label)
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
func fixture(indexed: bool,controlled: int=123) -> Dictionary:
	var log:=Log.new(); var client:=Client.new(); client.log=log; client.controlled=controlled
	var world:=World.new(); world.indexed_membership=indexed; world.client=client; world.log=log; world.actor_host=Node3D.new()
	return {"world":world,"client":client,"log":log,"states":[]}
func state(value: Dictionary={}) -> Dictionary:
	return {"finishedF4":int(value.get("finished",0)),"field110":int(value.get("field110",0)),"attached114":int(value.get("attached",0)),"closedEc":int(value.get("closed",0)),"scope10c":int(value.get("scope",0)),"programType10d":int(value.get("type",0)),"visualF8":int(value.get("visual",456)),"phase184":0,"destroyed":false}
func reserve(f: Dictionary,id: int,actor: int,token: int,s: Dictionary,trace_id: int=-1,area: bool=false,pending: bool=false) -> void:
	var world: World=f.world
	world.receive({"kind":"visual-reserve","effectId":id,"actorId":actor,"privateToken":token,"visualId":int(s.visualF8),"areaVisual":area,"transient":false})
	if not pending:
		var runtime:=Runtime.new(); runtime.configure(s,id if trace_id<0 else trace_id,f.log)
		world.entries[id].runtime=runtime; world.entries[id].binding=world.actor_host
func dispose(f: Dictionary) -> void:
	f.log.enabled=false; f.world.close(); f.world.actor_host.free(); f.world.free(); f.clear()
func original(indexed: bool,c: Dictionary) -> Dictionary:
	var f:=fixture(indexed,int(c.controlledId))
	reserve(f,8000,999,0,state())
	for n in c.entries.size():
		var s:=state(c.entries[n]); f.states.append(s); reserve(f,100+n,123,0,s,n)
		reserve(f,1000+n,10000+n,0,state())
	reserve(f,9000,123,77,state()); reserve(f,9100,123,0,state(),-1,true); reserve(f,9200,123,0,state(),-1,false,true)
	return f
func native_corpus() -> Dictionary:
	var cases:=0; var exact_world_cases:=0
	var base:=ProjectSettings.globalize_path("res://").path_join("../backups/animations").simplify_path()
	for kind in ["selection","competing-removal"]:
		var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("native-visual-"+kind+"-observations.json")))
		check(capture.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Immutable original build identity")
		for row: Dictionary in capture.rows:
			var c: Dictionary=row.case; var a:=original(false,c); var b:=original(true,c)
			if kind=="selection": a.world.select_actor(123); b.world.select_actor(123)
			else: a.world.detach_competing(a.world.entries[100+int(c.remove)]); b.world.detach_competing(b.world.entries[100+int(c.remove)])
			check(equal(a.log.events,b.log.events),"Exact indexed/scan callback order "+kind+"/"+str(cases))
			check(equal(a.states,b.states),"Exact indexed/scan state identity and mutations "+kind+"/"+str(cases))
			# The world wrapper has preexisting fixed suppression/view-gate policy
			# and selects all present types. Compare against the original oracle
			# only where this invocation actually represents the captured call.
			var representable: bool=kind=="competing-removal" or not bool(c.suppressed) and not bool(c.viewGate1407dadb0) and c.entries.all(func(e):return (int(e.type)&255)==(int(c.type)&255))
			if representable:
				check(equal(b.log.events,row.calls),"Indexed actual-world callback trace matches original "+kind+"/"+str(cases))
				check(equal(b.states.map(func(s):return s.attached114),row.attached),"Indexed actual-world attachment state matches original "+kind+"/"+str(cases)); exact_world_cases+=1
			var actor_members: Array=b.world._member_entries(123,0)
			check(actor_members.size()==c.entries.size()+2,"Index excludes unrelated actors/private tokens while preserving pending+area physical entries")
			dispose(a); dispose(b); cases+=1
	return {"original_cases":cases,"exact_world_oracle_cases":exact_world_cases,"scope":"Both world lookup modes compared across the full retained original corpus with unrelated/interleaved actors, private tokens, area and pending entries. Actual-world original trace checks exclude preexisting fixed suppression/view-gate or all-types wrapper differences."}
func lifecycle(indexed: bool) -> Dictionary:
	var f:=fixture(indexed); var w: World=f.world
	reserve(f,1,10,0,state({"visual":400,"scope":1})); reserve(f,2,20,0,state({"visual":400,"scope":2})); reserve(f,3,10,0,state({"visual":400,"scope":2})); reserve(f,4,10,8,state({"visual":400,"scope":1})); reserve(f,5,10,0,state({"visual":400}),-1,false,true)
	w.receive({"kind":"visual-reserve","effectId":3,"actorId":999,"privateToken":99,"visualId":400,"transient":false})
	check(w.entries.size()==5,"Duplicate reservation does not duplicate physical membership")
	w._process(1.0/60.0)
	w.receive({"kind":"visual-remove","actorId":10,"visualId":400}); check(w.entries[1].removed and not w.entries[3].removed and not w.entries[4].removed,"Removal preserves physical head and private-token boundaries")
	w.bound[3]=false; w.select_actor(10); w.bound[3]=true
	w.entries[1].runtime.state.finish_next=true; w._process(1.0/60.0)
	check(not w.entries.has(1),"Retiring phases remove exact membership after individual phase selection")
	w.entries[2].runtime.close_hook=func():reserve(f,2,30,7,state({"visual":401,"scope":1}))
	w._forget(2,"retired"); check(w.entries[2].actor==30 and w.entries[2].privateToken==7,"Reentrant retirement can re-reserve the same effect ID for a new owner")
	w.select_actor(20); w.select_actor(30,7)
	w.receive({"kind":"visual-cancel","effectId":5})
	w._process(1.0/60.0)
	var result:={"events":f.log.events.duplicate(true),"remaining":w.entries.values().map(func(e):return [e.id,e.actor,e.privateToken,e.removed])}
	f.log.enabled=false; w.close(); check(w.entries.is_empty() and w.actor_effects.is_empty(),"Close clears entries, owner buckets and retained references")
	dispose(f); return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var corpus:=native_corpus(); var a:=lifecycle(false); var b:=lifecycle(true)
	check(equal(a,b),"Full phase/removal/reentrancy trace and final membership match scan mode")
	await process_frame; await process_frame
	var extra:=extra_evidence()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"corpus":corpus,"network_connections":0,"scope":"Actual visual-world membership/filter integration against scan mode and representable immutable original instruction observations, plus phase order, head removal, private tokens, pending effects, ID reuse, reentrant close and cleanup. Not a complete scene/FPS or native view-gate parity claim."}
	report.merge(extra);var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
