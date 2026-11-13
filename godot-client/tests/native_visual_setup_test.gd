extends "res://tests/native_effect_membership_test.gd"
# Both sides keep the indexed membership and the same selector backend. Only
# setup allocation/callback plumbing differs. Run once per selector backend.
var native_calls:=0
var native_failures:=0
var reused_calls:=0
var peak:=0
var dynamic_cases:=0
func fixture(reused: bool,controlled: int=123) -> Dictionary:
	var f:=super.fixture(true,controlled)
	f.world.reused_selection_setup=reused
	return f
func dispose(f: Dictionary) -> void:
	check(f.world.selection_contexts.is_empty(),"Every invocation releases its own selection context")
	native_calls+=f.world.compiled_selection_calls; native_failures+=f.world.compiled_selection_failures
	reused_calls+=f.world.reused_selection_calls; peak=maxi(peak,f.world.selection_context_peak)
	f.world.bound_hook=Callable()
	for entry in f.world.entries.values():
		if entry.runtime!=null: entry.runtime.attach_hook=Callable()
	super.dispose(f)
func dynamic(reused: bool,kind: String) -> Dictionary:
	var f:=fixture(reused); var w: World=f.world
	reserve(f,1,10,0,state());reserve(f,2,10,0,state({"scope":1,"attached":1}));reserve(f,3,10,0,state({"scope":2,"attached":1}))
	reserve(f,20,20,0,state());reserve(f,21,20,0,state({"scope":1,"attached":1}));reserve(f,22,20,0,state({"scope":2,"attached":1}))
	reserve(f,30,10,77,state())
	var once:={"done":false}
	if kind=="fresh-state-after-all-bindings":
		w.bound_hook=func(entry):
			f.log.put(["bound",entry.id])
			if int(entry.id)==2 and not once.done:
				once.done=true
				# A combined filter/map would have captured entry 1's old state.
				w.entries[1].runtime.configure(state({"type":4,"scope":1,"closed":1}),1,f.log)
				reserve(f,4,10,0,state())
				f.log.put(["nested-enter"]);w.select_actor(20);f.log.put(["nested-exit"])
	elif kind=="nested-selection-and-competing-removal":
		w.entries[1].runtime.attach_hook=func():
			if once.done: return
			once.done=true
			f.log.put(["nested-enter"]);w.select_actor(20);w.detach_competing(w.entries[21]);w.select_actor(10,77);f.log.put(["nested-exit"])
	elif kind=="current-owner-mutated-during-bind":
		w.bound_hook=func(entry):
			f.log.put(["bound",entry.id])
			if int(entry.id)==1 and not once.done:
				once.done=true;w.entries[2].actor=30;w.entries[2].privateToken=1
	elif kind=="close-during-attach":
		w.entries[1].runtime.attach_hook=func():
			if once.done: return
			once.done=true;f.log.put(["close-enter"]);w.close();f.log.put(["close-exit"])
	if kind=="current-owner-mutated-during-bind": w.detach_competing(w.entries[2])
	else: w.select_actor(10)
	var result:={"calls":f.log.events.duplicate(true),"remaining":w.entries.values().map(func(entry):return {"id":entry.id,"actor":entry.actor,"token":entry.privateToken,"state":entry.runtime.state.duplicate(true)})}
	check(once.done,"Dynamic setup case reached its mutation "+kind)
	check(w.selection_contexts.is_empty(),"Nested and closed paths leave no invocation context "+kind)
	if reused and kind=="nested-selection-and-competing-removal": check(w.selection_context_peak==2,"Nested selection uses a separate context instead of overwriting the caller")
	dispose(f);dynamic_cases+=1;return result
func extra_evidence() -> Dictionary:
	for kind in ["fresh-state-after-all-bindings","nested-selection-and-competing-removal","current-owner-mutated-during-bind","close-during-attach"]:
		check(equal(dynamic(false,kind),dynamic(true,kind)),"Fresh-state and imperative callback trace matches allocating setup: "+kind)
	check(reused_calls>0 and peak==2 and native_failures==0,"Reused callback contexts were exercised, nested and released without selector failure")
	return {"compiled_selection":VisualWorld.configured_compiled_selection(),"compiled_selection_calls":native_calls,"compiled_selection_failures":native_failures,"reused_selection_calls":reused_calls,"selection_context_peak":peak,"dynamic_setup_cases":dynamic_cases,"setup_scope":"Same indexed membership/backend; original corpus plus later-bound runtime replacement, nested actor/private-token selection, competing removal, current-owner mutation and close during an in-flight callback. This does not claim FPS or complete renderer acceptance."}
