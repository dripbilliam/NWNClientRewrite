extends SceneTree
const Clocks=preload("res://systems/native_data/client_object_clocks.gd")
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const Pause=preload("res://systems/native_data/client_pause_state.gd")
const SCOPE=[7,3,20]
class Eager extends RefCounted:
	var objects: Dictionary={}
	var results: Dictionary={}
	func add(id: int,previous: Dictionary,registration_frame: int=1)->void:objects[id]={"previous":previous.duplicate(),"registrationFrame":registration_frame}
	func reset(id: int,value: Dictionary)->void:objects[id].previous=value.duplicate()
	static func choose(data: Dictionary,id: int)->Dictionary:
		var selector:=Pause.new()
		selector.configure({"flags":data.selector.flags,"exclusions":data.selector.exclusions,"gui":{"known":true,"value":null},"profileMode":0,"controlledId":0},{"world":data.world,"timer1":data.timer1,"timer2":data.timer2},{})
		var chosen:=selector.active_timer(id)
		var answer: Dictionary=chosen.timer.duplicate()
		selector.close();return answer
	func complete(frame: int,data: Dictionary)->void:
		results.clear()
		if not data.eligibility.module or not data.eligibility.area or not data.eligibility.completePass:return
		# Deliberately straightforward eager reference: every registered object
		# writes its previous pair even if no ScriptFloating consumer asks.
		for id in objects:
			var object: Dictionary=objects[id]
			if object.registrationFrame>frame:continue
			var now:=choose(data,id)
			results[id]=NativeWorldTimer.subtract_world_times(now,object.previous,data.dayLength)
			object.previous=now.duplicate()
var checks:=0
var failures: Array=[]
var authored_frames:=0
var authored_queries:=0
var native_cases:=0
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
static func ref(id: int,known: int=1,where: Array=SCOPE)->Dictionary:
	return {"scope":where.duplicate(),"id":id,"nativeLifetime":id+100,"knownLifetime":known,"physicalToken":"physical-"+str(id)}
static func phase(frame: int,order: int=1,after: bool=false)->Dictionary:return {"frame":frame,"phase":"after-ai" if after else "before-ai","order":order}
static func birth(previous: Dictionary,frame: int=1)->Dictionary:
	var stamp:=phase(frame);stamp.kind="birth";stamp.pair=previous.duplicate()
	return {"registeredBeforeAi":true,"registration":phase(frame,2),"stamp":stamp}
static func input(time: int,length: int=1000)->Dictionary:
	return {"clockStreamKnown":true,"world":{"day":10,"time":time},"timer1":{"day":10,"time":time},"timer2":{"day":10,"time":time},"dayLength":length,"selector":{"flags":0,"exclusions":{"known":true,"ids":[]}},"eligibility":{"module":true,"area":true,"completePass":true}}
func complete(clocks,data: Dictionary,frame: int)->void:
	check(clocks.begin_frame(frame,data).ready,"begin-"+str(frame))
	check(clocks.complete_frame().ready,"complete-"+str(frame))
func retained_native(fixture: Dictionary)->void:
	check(fixture.get("binarySha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","retained-target")
	check(fixture.rows.size()==90,"retained-90-caller-cases")
	for row in fixture.rows:
		var clocks:=Clocks.new();clocks.configure(SCOPE)
		var previous:={"day":row.case.previous[0],"time":row.case.previous[1]}
		var data:=input(int(row.case.now[1]));data.world.day=row.case.now[0];data.timer1=data.world.duplicate();data.timer2=data.world.duplicate()
		clocks.bind(ref(99),birth(previous));complete(clocks,data,1)
		var got:=clocks.sample(ref(99),1)
		if int(row.status)==0:
			check(got.ready and got.outputsDefined and got.elapsedMilliseconds==row.elapsed and got.elapsedDays==row.outputDay,"native-defined-"+str(native_cases))
		else:
			check(not got.ready and not got.outputsDefined and not got.has("elapsedMilliseconds") and NativeWorldTimer.u32(got.status)==int(row.status),"native-unwritten-"+str(native_cases))
		clocks.close();native_cases+=1
func eager_sequences()->void:
	var lazy:=Clocks.new();lazy.configure(SCOPE);var eager:=Eager.new()
	for id in range(10,42):
		eager.add(id,{"day":100,"time":0})
		if id!=41:check(lazy.bind(ref(id),birth({"day":100,"time":0})).ready,"initial-bind-"+str(id))
	var previous_flags:=0;var previous_ids: Variant=[]
	for frame in range(1,49):
		var length:=1000 if frame<29 else 2000
		var data:=input(0,length)
		data.world={"day":100,"time":frame*17%length}
		data.timer1={"day":100,"time":(frame*9 if frame<20 else 180)%length}
		data.timer2={"day":100,"time":frame*23%length}
		var flags:=0 if frame<8 else 1 if frame<16 else 2 if frame<24 else 3 if frame<32 else 0
		var ids: Variant=[10,12,14] if frame<16 else null if frame<24 else [12,13,15]
		data.selector={"flags":flags,"exclusions":{"known":true,"ids":ids}}
		data.eligibility.module=frame%7!=0;data.eligibility.area=frame%11!=0
		check(lazy.begin_frame(frame,data).ready,"sequence-begin-"+str(frame))
		if flags!=previous_flags:
			for id in range(10,42):
				if previous_ids==null or ids==null or previous_ids.has(id) or ids.has(id):
					var chosen:=Eager.choose(data,id);eager.reset(id,chosen)
					if id!=41 or frame>=40:
						var reset:=phase(frame,10);reset.nativeReset=true
						check(lazy.reset_stamp(ref(id),chosen,reset).ready,"transition-reset-"+str(frame)+"-"+str(id))
		previous_flags=flags;previous_ids=ids.duplicate() if ids is Array else null
		if frame==40:
			# First enqueue/bind long after birth. Previous full AI, not birth
			# or enqueue time, is the baseline of this already registered actor.
			check(lazy.bind(ref(41),birth({"day":100,"time":0})).ready,"late-first-binding")
		eager.complete(frame,data);check(lazy.complete_frame().ready,"sequence-complete-"+str(frame));authored_frames+=1
		var queries: Array=[10,12,15] if frame%3==0 else [22]
		if frame>=40:queries.append(41)
		for id in queries:
			var actual:=lazy.sample(ref(id),frame)
			if not data.eligibility.module or not data.eligibility.area:
				check(not actual.ready and not actual.has("elapsedMilliseconds"),"ineligible-no-tick-"+str(frame))
			else:
				var expected: Dictionary=eager.results[id]
				check(actual.ready==expected.outputsDefined,"eager-readiness-"+str(frame)+"-"+str(id))
				if expected.outputsDefined:check(actual.elapsedMilliseconds==expected.time and actual.elapsedDays==expected.day,"eager-difference-"+str(frame)+"-"+str(id))
			check(lazy.sample(ref(id),frame)==actual,"same-frame-query-"+str(frame)+"-"+str(id));authored_queries+=1
	check(lazy.state_view().bindingCount==32,"bounded-relevant-bindings")
	lazy.close()
func phase_and_isolation()->void:
	var clocks:=Clocks.new();var where:=SCOPE.duplicate();clocks.configure(where);where[1]=999
	var reference:=ref(5);var copied_ref:=reference.duplicate(true)
	check(clocks.bind(reference,birth({"day":10,"time":50})).ready,"birth-known-base-t0")
	reference.physicalToken="mutated";reference.scope[0]=999
	var data:=input(100);check(clocks.begin_frame(1,data).ready,"isolated-begin")
	data.world.time=999;data.selector.flags=3;data.selector.exclusions.ids.append(5)
	var reset:=phase(1,3);reset.nativeReset=true
	check(clocks.reset_stamp(copied_ref,{"day":10,"time":70},reset).ready,"first-ordered-reset")
	reset.order=4;check(clocks.reset_stamp(copied_ref,{"day":10,"time":80},reset).ready,"last-ordered-reset")
	check(not clocks.reset_stamp(copied_ref,{"day":10,"time":81},reset).ready,"same-order-changed-reset-rejected")
	check(not clocks.sample(copied_ref,1).ready,"no-before-completion-query")
	check(clocks.complete_frame().ready,"phase-complete")
	var after:=phase(1,5,true);after.nativeReset=true
	check(clocks.reset_stamp(copied_ref,{"day":10,"time":90},after).ready,"after-ai-reset")
	var first:=clocks.sample(copied_ref,1)
	check(first.ready and first.elapsedMilliseconds==20 and first.previousPair.time==80,"after-ai-does-not-rewrite-current-elapsed")
	first.elapsedMilliseconds=999;first.previousPair.time=999
	var view:=clocks.state_view();view.frame.world.time=999;view.scope[0]=999
	var binding:=clocks.binding_view(copied_ref);binding.stamps.clear();binding.ref.nativeLifetime=999
	check(clocks.sample(copied_ref,1).elapsedMilliseconds==20,"detached-cache-and-views")
	complete(clocks,input(120),2)
	check(clocks.sample(copied_ref,2).elapsedMilliseconds==30,"after-ai-reset-next-frame")
	check(not clocks.sample(copied_ref,1).ready,"old-frame-callback-rejected")
	check(not clocks.reset_stamp(copied_ref,{"day":10,"time":0},reset).ready,"late-before-ai-reset-rejected")
	complete(clocks,input(140),3)
	check(clocks.sample(copied_ref,3).elapsedMilliseconds==20,"prior-ai-overrides-older-reset")
	var gap:=input(180);check(clocks.begin_frame(5,gap).ready,"gap-explicit-current")
	clocks.complete_frame();check(not clocks.sample(copied_ref,5).ready,"gap-cannot-invent-baseline")
	complete(clocks,input(200),6);check(clocks.sample(copied_ref,6).elapsedMilliseconds==20,"one-full-phase-restores-next-baseline")
	var partial:=input(220);partial.eligibility.completePass=false
	check(clocks.begin_frame(7,partial).ready,"partial-input-explicit");check(not clocks.complete_frame().ready,"partial-not-certified")
	complete(clocks,input(240),8);check(not clocks.sample(copied_ref,8).ready,"partial-history-blocks-first-following")
	complete(clocks,input(260),9);check(clocks.sample(copied_ref,9).elapsedMilliseconds==20,"partial-recovery-after-full-ai")
	var unknown:=input(280);unknown.selector.exclusions.known=false
	check(not clocks.begin_frame(10,unknown).ready,"unknown-selector-rejected");clocks.complete_frame()
	complete(clocks,input(300),11);check(not clocks.sample(copied_ref,11).ready,"unknown-does-not-fall-back-zero")
	var stream_unknown:=input(320);stream_unknown.clockStreamKnown=false
	check(not clocks.begin_frame(12,stream_unknown).ready,"sampler-does-not-certify-global-clock-history");clocks.complete_frame()
	clocks.close()
func birth_selection_and_unknown()->void:
	var clocks:=Clocks.new();clocks.configure(SCOPE)
	clocks.bind(ref(5),birth({"day":10,"time":30}))
	var data:=input(100);data.timer1.time=200;data.selector.flags=1;data.selector.exclusions.ids=[5]
	complete(clocks,data,1)
	var first:=clocks.sample(ref(5),1)
	check(first.ready and first.previousPair.time==30 and first.elapsedMilliseconds==170 and first.selectedSlot=="timer1","birth-base-t0-distinct-from-selected-first-ai")
	clocks.close();clocks.configure(SCOPE)
	var unknown:={"registeredBeforeAi":true,"registration":phase(1),"stamp":null}
	clocks.bind(ref(5),unknown);complete(clocks,input(10),1)
	check(not clocks.sample(ref(5),1).ready,"unknown-birth-never-invented-zero")
	complete(clocks,input(30),2)
	check(clocks.sample(ref(5),2).elapsedMilliseconds==20,"explicit-full-ai-can-establish-previous-stamp-without-birth-inference")
	clocks.close();clocks.configure(SCOPE)
	var late:=birth({"day":10,"time":30});late.registration=phase(1,2,true)
	clocks.bind(ref(5),late);complete(clocks,input(100),1)
	check(not clocks.sample(ref(5),1).ready,"registration-after-ai-does-not-claim-current-pass")
	complete(clocks,input(120),2)
	check(clocks.sample(ref(5),2).elapsedMilliseconds==90,"first-eligible-ai-after-registration-uses-known-birth")
	clocks.close()
func scope_and_retirement()->void:
	var clocks:=Clocks.new();clocks.configure(SCOPE);var old:=ref(9)
	check(not clocks.bind(old,{"registeredBeforeAi":false,"registration":phase(1)}).ready,"no-inferred-AI-registration")
	clocks.bind(old,birth({"day":10,"time":0}));complete(clocks,input(10),1)
	var next_scope:=[7,4,21];var next_ref:=ref(9,2,next_scope)
	check(not clocks.rebind_scope(next_scope,[{"previous":old,"next":next_ref,"samePhysical":false}],{"continuousHistory":true}).ready,"no-ambiguous-D-A-rebind")
	check(clocks.rebind_scope(next_scope,[{"previous":old,"next":next_ref,"samePhysical":true}],{"continuousHistory":true}).ready,"trusted-same-physical-rebind")
	check(not clocks.sample(old,1).ready and not clocks.sample(next_ref,1).ready,"scope-change-does-not-rebind-old-frame")
	complete(clocks,input(30),2);check(clocks.sample(next_ref,2).elapsedMilliseconds==20,"continuous-physical-transfer-keeps-prior-ai")
	var reconnect:=[8,4,21]
	check(not clocks.rebind_scope(reconnect,[{"previous":next_ref,"next":ref(9,3,reconnect),"samePhysical":true}],{"continuousHistory":true}).ready,"connection-rebind-forbidden")
	var retired:=clocks.retire(next_ref);check(retired.ready and retired.physicalDestructionInferred==false,"retirement-not-physical-delete")
	check(not clocks.sample(next_ref,2).ready,"retired-ref-unavailable")
	var reused:=ref(9,3,next_scope);reused.nativeLifetime=999;reused.physicalToken="different-owner"
	check(not clocks.bind(reused,{"registeredBeforeAi":false,"registration":phase(2)}).ready,"ambiguous-reuse-no-stamp")
	clocks.close();check(not clocks.sample(next_ref,2).ready,"closed-owner-no-query")
	var bounded:=Clocks.new();bounded.configure(SCOPE,{"maxBindings":1,"maxSelectorIds":0})
	check(bounded.bind(ref(1),birth({"day":10,"time":0})).ready,"caller-bound-first")
	check(not bounded.bind(ref(2),birth({"day":10,"time":0})).ready,"caller-bound-explicit-unavailable")
	var bounded_data:=input(10);bounded_data.selector.exclusions.ids=[1]
	check(not bounded.begin_frame(1,bounded_data).ready,"caller-selector-bound-explicit-unavailable");bounded.close()
func nullable_physical_reference()->void:
	var clocks:=Clocks.new();clocks.configure(SCOPE)
	var physical:=ref(55);physical.nativeLifetime=null;physical.knownLifetime=null;physical.lifecycleEpoch=9
	var missing:=physical.duplicate(true);missing.erase("knownLifetime")
	check(not clocks.bind(missing,birth({"day":10,"time":0})).ready,"missing-is-not-explicit-null-display-life")
	var numeric:=physical.duplicate(true);numeric.physicalToken=1
	check(not clocks.bind(numeric,birth({"day":10,"time":0})).ready,"nullable-display-needs-opaque-certified-physical-token")
	check(clocks.bind(physical,birth({"day":10,"time":0})).ready,"trusted-null-display-birth")
	for frame in range(1,5):complete(clocks,input(frame*20),frame)
	var first:=clocks.sample(physical,4)
	check(first.ready and first.elapsedMilliseconds==20 and first.basisKind=="previous-ai","null-display-late-first-query-not-since-birth")
	var display_alias:=physical.duplicate(true);display_alias.nativeLifetime=123;display_alias.knownLifetime=456
	check(not clocks.sample(display_alias,4).ready,"later-display-alias-does-not-rebind-internal-clock")
	var wrong_token:=physical.duplicate(true);wrong_token.physicalToken="other-physical"
	check(not clocks.sample(wrong_token,4).ready,"null-display-wrong-physical-token")
	var wrong_epoch:=physical.duplicate(true);wrong_epoch.lifecycleEpoch=10
	check(not clocks.sample(wrong_epoch,4).ready,"null-display-wrong-physical-epoch")
	var next_scope:=[7,4,21];var transfer:=physical.duplicate(true);transfer.scope=next_scope
	var changed_epoch:=transfer.duplicate(true);changed_epoch.lifecycleEpoch=10
	check(not clocks.rebind_scope(next_scope,[{"previous":physical,"next":changed_epoch,"samePhysical":true}],{"continuousHistory":true}).ready,"same-token-different-epoch-not-same-owner")
	check(clocks.rebind_scope(next_scope,[{"previous":physical,"next":transfer,"samePhysical":true}],{"continuousHistory":true}).ready,"null-display-explicit-physical-scope-transfer")
	complete(clocks,input(100),5)
	check(not clocks.sample(physical,5).ready and clocks.sample(transfer,5).elapsedMilliseconds==20,"null-display-stale-scope-cannot-follow-transfer")
	clocks.close()
func _initialize()->void:call_deferred("run")
func run()->void:
	var report_path:="";var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		elif arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary:check(false,"fixture-readable")
	else:retained_native(fixture)
	eager_sequences();phase_and_isolation();birth_selection_and_unknown();scope_and_retirement();nullable_physical_reference()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"retainedNativeCallerCases":native_cases,"authoredEagerFrames":authored_frames,"authoredLazyQueries":authored_queries,"scope":"Conditional lazy stamp equivalence under explicit supplied lifecycle/AI facts. Native90 caller/subtraction basis is separate from authored eager timelines; no provider/clock origin/physical lifecycle/runtime admission inferred."}
	var output:=FileAccess.open(report_path,FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(report,"\t"));output.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
