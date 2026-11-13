extends SceneTree
const Latch=preload("res://tools/native_parity/visibility/perception_latch.gd")
const Controller=preload("res://tools/native_parity/visibility/perception_controller.gd")
var count:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	count+=1
	if not value:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scope:={"connection_epoch":"one","area_generation":4,"area_id":42,"object_id":4294967295,"entity_lifetime":17}
	for initial in [false,true]:
		for mask in 8:
			var flags: Array=[(mask&1)!=0,(mask&2)!=0,(mask&4)!=0]
			var old:={"version":1,"scope":scope.duplicate(),"latched":initial}
			var result:=Latch.reduce(old,scope,flags)
			var applies: bool=(not flags[1] and flags[0]) or flags[2]
			var removes: bool=not applies and flags[1] and not flags[2]
			var expected: String="apply6" if applies and not initial else "remove6" if removes and initial else "noop"
			check(result.available and result.action.kind==expected,"all triples and old latches")
			check(result.state.latched==(true if applies else false if removes else initial),"native resulting latch")
			check(old.latched==initial,"previous state immutable")
			var again:=Latch.reduce(result.state,scope,flags)
			check(again.action.kind=="noop","repeat is idempotent")
	for flags in [null,[],[0,0],[1,0,0,1],["1",0,0],[2,0,0],[NAN,0,0],[INF,0,0],Vector3.ZERO]:
		var previous:={"version":1,"scope":scope.duplicate(),"latched":true}
		var missing:=Latch.reduce(previous,scope,flags)
		check(not missing.available and missing.action==null and missing.state.latched,"missing/invalid never coerced false")
	check(Latch.reduce({},scope,[1.0,0.0,0.0]).action.kind=="apply6","bridge float flags admitted")
	var retained:=Latch.reduce({"version":1,"scope":scope,"latched":true},scope,[0,0,0]);check(retained.action.kind=="noop" and retained.state.latched,"bothfalse retains prior")
	var third:=Latch.reduce({},scope,[0,1,1]);check(third.action.kind=="apply6","third overrides second")
	for key in Latch.SCOPE_KEYS:
		var next:=scope.duplicate();next[key]="new" if key in ["connection_epoch","entity_lifetime"] else 0 if key=="object_id" else int(scope[key])+1
		var changed:=Latch.reduce({"version":1,"scope":scope,"latched":true},next,[1,0,0])
		check(changed.scope_reset and changed.action.kind=="apply6","every scope axis resets lifetime latch")
	var missing_scope:=scope.duplicate();missing_scope.erase("entity_lifetime")
	check(not Latch.reduce({},missing_scope,[1,0,0]).available,"missing scope denied")
	var controller:=Controller.new();var first:=controller.observe(scope,[1,0,0]);first.state.latched=false;first.state.scope.object_id=0
	check(controller.snapshot().state.latched and controller.snapshot().state.scope.object_id==4294967295,"controller result detached")
	check(controller.observe(scope,null).action==null and controller.snapshot().state.latched,"missing state retains controller latch")
	var reused:=scope.duplicate();reused.entity_lifetime=18
	check(not controller.observe(reused,[1,0,0]).available and controller.snapshot().state.scope.entity_lifetime==17,"old controller cannot migrate to reused entity")
	var replacement:=Controller.new();check(replacement.observe(reused,[1,0,0]).action.kind=="apply6","new lifetime gets new controller and native latch")
	check(controller.observe(scope,[1,1,0]).action.kind=="remove6","controller removal")
	controller.retire();check(not controller.observe(scope,[1,0,0]).available,"retired controller cannot reactivate")
	var native_cases:=0;var native_steps:=0;var lookup_miss_steps:=0
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--oracle="):continue
		var file:=FileAccess.open(argument.substr(9),FileAccess.READ)
		var oracle: Variant=JSON.parse_string(file.get_as_text()) if file!=null else null
		check(oracle is Dictionary and oracle.get("binarySha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","original oracle source pin")
		if not oracle is Dictionary:continue
		for row in oracle.rows:
			var input: Dictionary=row.case;var packed:=int(input.packed_flags)
			var flags: Array=[(packed&2)!=0,(packed&1)!=0,(packed&16)!=0]
			var previous:={"version":1,"scope":scope.duplicate(),"latched":int(input.latched)==1}
			for step in row.steps:
				var actions: Array=step.calls.filter(func(event):return event.kind in ["apply6","remove6"])
				if not input.present:
					check(actions.is_empty() and int(step.latched)==int(input.latched),"native missing lookup suppresses actions")
					lookup_miss_steps+=1;continue
				var result:=Latch.reduce(previous,scope,flags)
				check(result.action.kind==(actions[0].kind if not actions.is_empty() else "noop"),"original instruction action parity")
				check(result.state.latched==(int(step.latched)==1),"original instruction latch parity")
				previous=result.state;native_steps+=1
			native_cases+=1
	var report:={"checks":count,"failures":failures,"native_cases":native_cases,"native_reducer_steps":native_steps,"native_lookup_boundary_miss_steps":lookup_miss_steps,"scope":"isolated pure perception reducer/controller; no rendering, server or opacity policy; entity lookup remains caller-owned"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
