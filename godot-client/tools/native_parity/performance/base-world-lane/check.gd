extends SceneTree
const Before=preload("res://before_planner.gd")
const Candidate=preload("res://candidate_planner.gd")
const Base=preload("res://base_world_scenery.gd")
const Owner=preload("res://configure_owner.gd")
const NoMemo=preload("res://no_memo_planner.gd")
const Received=preload("res://receive_owner.gd")
var checks:=0
var failures: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize():run.call_deferred()
func row(id: int,kind: int,x: float,wire_static: bool=false) -> Dictionary:
	var value:={"id":id,"objectType":kind,"areaId":1,"replicated":{"position":[x,0.,0.]}}
	if wire_static:value.staticState={"id":id,"appearance":2,"position":[x,0.,0.],"orientation":[0.,1.,0.]}
	return value
func want(world,value: Dictionary,key: String="") -> void:
	world.desired[value.id]={"key":str(value.id) if key.is_empty() else key,"object":value}
func ids(values: Array) -> Array:return values.map(func(value):return int(value.id))
func ready(world) -> void:
	world.control_ready=true;world.terrain_ready=true
	want(world,row(1,5,0.),"player");world.installed[1]="player";world.instances[1]={"position":Vector3.ZERO}
func empty(plan: Dictionary) -> bool:return plan.actors.is_empty() and plan.statics.is_empty() and plan.base_statics.is_empty()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or not report.is_absolute_path() or FileAccess.file_exists(report):quit(2);return
	check(DisplayServer.get_name()=="headless","No physical rendering or input is involved")
	var value:=row(20,9,2.,true)
	check(Base.classify(value,1)=={"available":true,"base":true,"reason":"received-clientarea-static-geometry"},"Dedicated received ClientArea static record is verified")
	var missing:=row(20,9,2.)
	check(not Base.classify(missing,1).available and not Base.classify(missing,1).base,"Missing static provenance is explicit unknown, not invented non-usability")
	for kind in [5,6,7,10,16]:
		var other:=row(20,kind,2.,true)
		check(Base.classify(other,1).available and not Base.classify(other,1).base,"Object kind does not become static geometry: "+str(kind))
	for field in ["field264","nativeUseable264","usable","Useable"]:
		var other:=value.duplicate(true)
		if field=="field264":other.replicated[field]=1
		elif field=="Useable":other.authored={field:true}
		else:other[field]=true
		check(not Base.classify(other,1).available and not Base.classify(other,1).base and Base.classify(other,1).reason=="contradictory-live-usability","Contradictory live usability is explicitly unresolved: "+field)
	var false_known:=value.duplicate(true);false_known.replicated.field264=0.;false_known.usable=false
	check(Base.classify(false_known,1).base,"Explicit false live aliases do not erase verified wire provenance")
	false_known.usable=true
	check(not Base.classify(false_known,1).base,"Contradictory positive alias is conservatively outside base lane")
	var unknown:=value.duplicate(true);unknown.replicated.field264="false"
	check(not Base.classify(unknown,1).available,"Malformed usability remains unavailable")
	for field in ["id","appearance","position","orientation"]:
		var other:=value.duplicate(true);other.staticState.erase(field)
		check(not Base.classify(other,1).available,"Missing required wire record field stays unavailable: "+field)
	var mismatched:=value.duplicate(true);mismatched.staticState.id=21
	check(not Base.classify(mismatched,1).available,"Static record ID cannot name a different canonical entity")
	var high:=row(4294967089,9,2.,true)
	check(Base.classify(high,1).base,"High-bit client IDs retain exact uint32 identity")
	var float_ids:=high.duplicate(true);float_ids.id=float(high.id);float_ids.staticState.id=float(high.id);float_ids.objectType=9.;float_ids.areaId=1.
	check(Base.classify(float_ids,1).base,"Integral numeric JSON representations are accepted")
	var fractional:=value.duplicate(true);fractional.id=20.5
	check(not Base.classify(fractional,1).available,"Fractional identity is not truncated")
	for flag in ["replicationRemoved","destroyed"]:
		var other:=value.duplicate(true);other[flag]=true
		check(not Base.classify(other,1).base,"Retired data cannot enter base lane: "+flag)
	check(not Base.classify(value,2).base,"Different-area data cannot enter this base lane")
	var light_only:=row(30,9,1.);light_only.lightState={"id":30,"appearance":2,"position":[1.,0.,0.]}
	check(not Base.classify(light_only,1).available,"Light record or static pose alone does not prove non-interactable scenery")
	var input_before:=value.duplicate(true);Base.classify(value,1)
	check(value==input_before,"Classification never mutates canonical received data")

	var world:=Candidate.new();var original:=Before.new()
	for index in 145:
		want(world,row(100+index,9,float(index+1),true));want(original,row(100+index,9,float(index+1),true))
	want(world,row(9000,5,.1));want(world,row(9001,10,.2));want(world,row(9002,9,.3));want(world,light_only)
	var plan: Dictionary=world.pending_plan({})
	check(plan.actors.is_empty() and plan.statics.is_empty() and plan.base_statics.size()==64,"Base lane can start before terrain and controlled replication")
	check(ids(plan.base_statics)==range(100,164),"Received entry origin ranks the nearest verified scenery first")
	check(original.pending_plan({}).statics.is_empty(),"Original coupling blocks the same known static records")
	check(not ids(plan.base_statics).has(9001) and not ids(plan.base_statics).has(9002),"Doors and unknown live placeables stay out of early lane")
	want(world,row(1,5,0.),"player")
	plan=world.pending_plan({})
	check(ids(plan.actors)==[1] and plan.base_statics.is_empty() and plan.statics.is_empty(),"Controlled appearance is the exclusive next request when available")
	plan=world.pending_plan({1:true})
	check(plan.base_statics.size()==64 and plan.actors.is_empty(),"Base lane overlaps controlled preparation without requiring full terrain")
	var total: Array=[]
	for wave in 3:
		plan=world.pending_plan({1:true})
		total.append_array(ids(plan.base_statics))
		for entry in plan.base_statics:
			world.installed[entry.id]=world.desired[entry.id].key;world.instances[entry.id]={};world.note_base_scenery_publication(int(entry.id))
		world.stats.entry_prefetch_batches=int(world.stats.get("entry_prefetch_batches",0))+1
	check(total==range(100,245),"Continuing multiple waves admit all verified base rows, not a one-shot prefetch")
	check(plan.base_statics.size()==17 and int(world.stats.entry_prefetch_batches)==3,"Last partial wave and repeated-wave progress remain explicit")
	check(not world.pending_plan({1:true}).base_statics.size(),"Exhausted base rows are not duplicated")
	world.installed.erase(124);world.batches=[{"actors":false,"keys":{124:"124"},"base_scenery":true}]
	check(world.pending_plan({1:true,124:true}).base_statics.is_empty(),"Existing base owner prevents a second simultaneous base owner")
	world.batches=[{"actors":false,"keys":{}},{"actors":true,"keys":{200:"200"}}]
	check(empty(world.pending_plan({1:true})),"Two background owners preserve reserved controlled capacity")
	plan=world.pending_plan({})
	check(ids(plan.actors)==[1],"Controlled replacement still wins with two background owners")
	world.batches=[];world.failed_objects[124]={"key":"124"}
	check(world.pending_plan({1:true}).base_statics.is_empty(),"Exact failed appearance is not retried forever")
	world.desired[124].key="changed"
	check(ids(world.pending_plan({1:true}).base_statics)==[124],"Changed appearance invalidates old failure binding")
	world.desired.erase(124)
	check(world.pending_plan({1:true}).base_statics.is_empty(),"Removed canonical row cannot remain in a queued lane")
	world.has_priority_origin=false;world.desired.erase(1)
	want(world,row(500,9,1.,true))
	check(empty(world.pending_plan({})),"No received origin or player pose produces an explicit empty early plan")
	want(world,row(1,5,3.),"player")
	check(ids(world.pending_plan({1:true}).base_statics)==[500],"Controlled received pose is a valid origin fallback")
	world.entry_prefetch_enabled=false
	check(empty(world.pending_plan({1:true})),"Explicitly disabled initial overlap remains respected")
	world.entry_prefetch_enabled=true;world.closed=true
	check(empty(world.pending_plan({1:true})),"Closed scope cannot schedule new owners")
	world.closed=false;world.retiring=true
	check(empty(world.pending_plan({1:true})),"Retiring scope cannot schedule new owners")
	world.retiring=false;world.stats.errors=["scope"]
	check(empty(world.pending_plan({1:true})),"Scope failure blocks scheduling")

	var after:=Candidate.new();ready(after)
	for index in 70:want(after,row(1000+index,9,float(index+10),true))
	want(after,row(50,5,.1));want(after,row(51,10,.2));want(after,row(52,9,.3))
	plan=after.pending_plan({})
	check(plan.base_statics.size()==64,"After control, base lane continues in bounded normal waves")
	check(ids(plan.actors)==[50] and plan.statics.is_empty(),"Spare owner can stream nearest live group while base wave starts")
	check(not plan.statics.any(func(entry):return entry.has("staticState")),"Base scenery never rejoins mixed live statics wave")
	after.batches=[{"actors":false,"keys":{1000:"1000"},"base_scenery":true}]
	plan=after.pending_plan({1000:true})
	check(plan.base_statics.is_empty() and ids(plan.actors)==[50],"In-flight base work leaves spare capacity for live actors")
	after.batches.append({"actors":true,"keys":{50:"50"}})
	check(empty(after.pending_plan({1000:true,50:true})),"Combined base/live owner count stays bounded to two")
	after.batches=[]
	var completed: Array=[]
	for wave in 2:
		plan=after.pending_plan({})
		completed.append_array(ids(plan.base_statics))
		for entry in plan.base_statics:
			after.installed[entry.id]=after.desired[entry.id].key;after.instances[entry.id]={};after.note_base_scenery_publication(int(entry.id))
	check(completed==range(1000,1070),"Far base scenery also completes across later waves without a distance cutoff")
	check(after.pending_plan({}).base_statics.is_empty(),"Complete base phase is represented without claiming pending live actors complete")
	var stable:=Candidate.new();var reference:=Before.new();ready(stable);ready(reference)
	for entry in [row(2,5,2.),row(3,10,1.),row(4,9,3.),row(5,6,4.)]:want(stable,entry);want(reference,entry)
	var stable_before: Dictionary=stable.desired.duplicate(true)
	var a: Dictionary=stable.pending_plan({});var b: Dictionary=reference.pending_plan({})
	check(a.base_statics.is_empty() and a.actors==b.actors and a.statics==b.statics,"Worlds without verified base rows retain original live wave membership/order")
	check(stable.desired==stable_before,"Planning does not mutate received objects or appearance bindings")
	var phase:=Candidate.new();phase.base_scenery_population_known=false
	check(not phase.base_scenery_snapshot().available and phase.base_scenery_snapshot().reason=="population-unavailable","An unreceived base population cannot report complete or zero pending")
	phase.base_scenery_population_known=true
	for id in [300,301,302]:want(phase,row(id,9,float(id-299),true))
	phase.pending_plan({})
	var progress: Dictionary=phase.base_scenery_snapshot()
	check(progress.available and progress.expected==3 and progress.resolved==0 and progress.pending==3 and not progress.complete,"Planner pass reports known expected and pending base records")
	check(progress.first_resolved_ms==null and progress.first_complete_ms==null,"Missing milestone data remains null")
	phase.installed[300]="300";phase.instances[300]={};phase.note_base_scenery_publication(300)
	check(not phase.base_scenery_snapshot().available,"A changed install boundary invalidates stale completion/counts until its existing planner pass")
	phase.pending_plan({})
	progress=phase.base_scenery_snapshot()
	check(progress.resolved==1 and progress.instances_resolved==1 and progress.hidden_resolved==0 and progress.first_resolved_ms!=null,"Actual current install records first resolved milestone and count")
	var first_resolved: Variant=progress.first_resolved_ms
	phase.installed[301]="301";phase.hidden[301]=true;phase.note_base_scenery_publication(301)
	phase.failed_objects[302]={"key":"302"};phase.base_scenery_progress_dirty=true
	phase.pending_plan({})
	progress=phase.base_scenery_snapshot()
	check(progress.resolved==2 and progress.hidden_resolved==1 and progress.failed==1 and progress.pending==1 and not progress.complete,"Intentionally hidden helpers resolve; failed required scenery remains pending and prevents false completion")
	check(progress.first_resolved_ms==first_resolved and progress.first_complete_ms==null,"Later hidden publication preserves first milestone without inventing completion")
	phase.failed_objects.erase(302);phase.installed[302]="302";phase.instances[302]={};phase.note_base_scenery_publication(302)
	phase.pending_plan({})
	progress=phase.base_scenery_snapshot()
	check(progress.complete and progress.expected==3 and progress.resolved==3 and progress.pending==0 and progress.first_complete_ms!=null,"First complete milestone requires every known base record resolved")
	var first_complete: Variant=progress.first_complete_ms
	phase.desired[300].key="new-look";phase.base_scenery_progress_dirty=true
	phase.pending_plan({})
	progress=phase.base_scenery_snapshot()
	check(not progress.complete and progress.pending==1 and progress.first_complete_ms==first_complete,"Appearance replacement reopens current phase without erasing historical entry milestone")
	phase.desired.erase(300);phase.instances.erase(300);phase.installed.erase(300);phase.base_scenery_progress_dirty=true
	phase.pending_plan({})
	check(phase.base_scenery_snapshot().complete and phase.base_scenery_snapshot().expected==2,"Removal updates expected category rather than leaving phantom pending content")
	want(phase,row(300,9,1.,true),"lifetime-two");phase.base_scenery_progress_dirty=true;phase.pending_plan({})
	check(not phase.base_scenery_snapshot().complete and phase.base_scenery_snapshot().pending==1,"Reused ID with a new lifetime/key cannot inherit resolved status")
	phase.desired[300].object.replicated.field264=1;phase.base_scenery_progress_dirty=true;ready(phase);phase.pending_plan({})
	progress=phase.base_scenery_snapshot()
	check(not progress.complete and progress.expected==3 and progress.unresolved_static==1 and progress.pending==1 and ids(phase.pending_plan({}).statics).has(300),"Contradictory potential-static row remains unresolved rather than silently shrinking expected population")
	phase.desired[300].object.erase("staticState");phase.base_scenery_progress_dirty=true;phase.base_live_revision+=1;phase.pending_plan({})
	check(phase.base_scenery_snapshot().complete and phase.base_scenery_snapshot().expected==2 and ids(phase.pending_plan({}).statics).has(300),"A canonical replacement which removes wire-static provenance moves to the live category")
	var malformed:=row(350,9,2.,true);malformed.staticState.erase("orientation");want(phase,malformed);phase.base_scenery_progress_dirty=true;phase.base_live_revision+=1;phase.pending_plan({})
	check(not phase.base_scenery_snapshot().complete and phase.base_scenery_snapshot().unresolved_static==1,"Malformed potential-static record also blocks false base completion")
	phase.desired.erase(350);phase.base_scenery_progress_dirty=true;phase.base_live_revision+=1
	want(phase,row(400,9,1.));phase.base_scenery_progress_dirty=true;phase.pending_plan({})
	check(phase.base_scenery_snapshot().unknown_placeables==1 and ids(phase.pending_plan({}).statics).has(400),"Unknown placeables remain separately counted and scheduled in live lane")
	phase.base_scenery_progress_dirty=true;phase.batches=[{"actors":false,"keys":{}},{"actors":false,"keys":{}}]
	phase.pending_plan({})
	check(not phase.base_scenery_snapshot().available,"Capacity return never presents stale progress as current")
	phase.stats.errors=["scope"]
	check(not phase.base_scenery_snapshot().available and phase.base_scenery_snapshot().reason=="scope-errors","Scope errors cannot preserve a current completed phase claim")
	var memo:=Candidate.new();var no_memo:=NoMemo.new();ready(memo);ready(no_memo)
	for owner in [memo,no_memo]:want(owner,row(700,9,1.,true));owner.pending_plan({});owner.batches=[{"actors":false,"keys":{700:"700"},"base_scenery":true}]
	var scans_before:=int(memo.stats.base_scenery_scans)
	a=memo.pending_plan({700:true});b=no_memo.pending_plan({700:true})
	check(a==b and int(memo.stats.base_scenery_scans)==scans_before,"Active base owner with no possible live work skips repeated full-row scan without changing plan")
	for owner in [memo,no_memo]:want(owner,row(800,5,1.));owner.base_live_revision+=1;owner.base_scenery_progress_dirty=true
	a=memo.pending_plan({700:true});b=no_memo.pending_plan({700:true})
	check(a==b and ids(a.actors)==[800],"New live arrival invalidates no-live-work memo during base preparation")
	for owner in [memo,no_memo]:owner.batches.append({"actors":true,"keys":{800:"800"}})
	check(memo.pending_plan({700:true,800:true})==no_memo.pending_plan({700:true,800:true}),"Two-owner capacity behavior remains exactly equal with memo")
	for owner in [memo,no_memo]:owner.batches.pop_back();owner.installed[800]="800";owner.instances[800]={};owner.base_live_revision+=1
	check(memo.pending_plan({700:true})==no_memo.pending_plan({700:true}),"Completed live owner leaves no phantom live work")
	for owner in [memo,no_memo]:owner.desired[800].key="changed-look";owner.base_live_revision+=1;owner.base_scenery_progress_dirty=true
	a=memo.pending_plan({700:true});b=no_memo.pending_plan({700:true})
	check(a==b and ids(a.actors)==[800],"Changed live appearance invalidates cached absence while base remains active")
	for owner in [memo,no_memo]:owner.failed_objects[800]={"key":"changed-look"};owner.base_scenery_progress_dirty=true
	check(memo.pending_plan({700:true})==no_memo.pending_plan({700:true}),"Exact live failure does not create a starved retry or change failure policy")
	for owner in [memo,no_memo]:owner.desired.erase(800);owner.installed.erase(800);owner.instances.erase(800);owner.failed_objects.erase(800);owner.base_live_revision+=1
	check(memo.pending_plan({700:true})==no_memo.pending_plan({700:true}),"Live removal preserves exact empty plan under the active base owner")
	for owner in [memo,no_memo]:want(owner,row(800,5,.5),"lifetime-two");owner.base_live_revision+=1
	a=memo.pending_plan({700:true});b=no_memo.pending_plan({700:true})
	check(a==b and ids(a.actors)==[800],"Same-ID new lifetime cannot inherit no-live-work memo")
	for owner in [memo,no_memo]:want(owner,row(2,5,1.),"new-control");owner.controlled_id=2;owner.control_ready=false;owner.base_live_revision+=1
	a=memo.pending_plan({700:true});b=no_memo.pending_plan({700:true})
	check(a==b and ids(a.actors)==[2],"Controlled swap retains exclusive request before memo checks")
	for owner in [memo,no_memo]:owner.controlled_id=1;owner.control_ready=true;owner.batches=[];owner.failed_objects[700]={"key":"700"};owner.base_scenery_progress_dirty=true
	a=memo.pending_plan({});b=no_memo.pending_plan({})
	check(a==b and memo.base_scenery_snapshot().failed==1 and not memo.base_scenery_snapshot().complete,"Base owner failure reopens planning and remains explicitly incomplete")
	for owner in [memo,no_memo]:owner.failed_objects.erase(700);owner.installed[700]="700";owner.instances[700]={};owner.base_scenery_progress_dirty=true
	a=memo.pending_plan({});b=no_memo.pending_plan({})
	check(a==b and memo.base_scenery_snapshot().complete,"Base owner completion refreshes progress despite prior cached absence")
	# These calls execute the actual candidate receive/filter bodies, rather
	# than injecting a malformed row directly into desired as v2 did.
	var received:=Received.new();received.stats={"errors":[],"removed":0};received.base_scenery_population_known=false
	var absent:=row(900,9,1.,true);absent.replicated.erase("position");absent.staticState.erase("position");absent.nativeLifetime=1
	received.receive([absent],1)
	check(received.desired.is_empty() and received.base_scenery_omitted=={900:"malformed-clientarea-static-record"},"Actual full receive filter preserves sparse unresolved provenance for omitted no-pose static")
	check(not received.base_scenery_snapshot().available,"Actual receive invalidates current progress before its existing planner recount")
	received.pending_plan({});progress=received.base_scenery_snapshot()
	check(progress.available and progress.expected==1 and progress.pending==1 and progress.unresolved_static==1 and progress.omitted_static==1 and not progress.complete,"Renderer-filtered static remains explicitly expected/unresolved and cannot falsely complete")
	check(progress.unresolved_reasons=={"malformed-clientarea-static-record":1} and received.base_scenery_omitted.values().all(func(reason):return reason is String),"Sparse omission retains only reason strings, not canonical rows or presentation resources")
	check(not received.snapshot(false).object_visuals_complete,"Overall visual-complete flag cannot hide a missing no-pose base static")
	check(received.motion.objects.is_empty() and received.instances.is_empty(),"Omitted row does not create an actor or visual as a side effect")
	var repaired:=row(900,9,1.,true);repaired.nativeLifetime=1
	received.receive_delta([repaired],[],1)
	check(received.base_scenery_omitted.is_empty() and received.desired.has(900),"Actual delta repair clears omission and returns canonical static to desired")
	check(ids(received.pending_plan({}).base_statics)==[900],"Repaired omitted static is eligible for the continuing base lane")
	received.installed[900]=received.desired[900].key;received.hidden[900]=true;received.note_base_scenery_publication(900);received.pending_plan({})
	check(received.base_scenery_snapshot().complete and received.base_scenery_snapshot().resolved==1,"Repaired row completes only after actual matching admission or intentional hide")
	var complete_time: Variant=received.base_scenery_snapshot().first_complete_ms
	var next_life:=absent.duplicate(true);next_life.nativeLifetime=2
	received.receive_delta([next_life],[],1)
	var exported: Dictionary=received.snapshot(false)
	check(not exported.has("base_scenery_progress") and not exported.base_scenery.available and not exported.base_scenery.has("complete"),"Dirty actual snapshot exposes one unavailable current view, never a separately cached completed stats dictionary")
	received.pending_plan({});progress=received.base_scenery_snapshot()
	check(not received.desired.has(900) and not received.installed.has(900) and progress.unresolved_static==1 and not progress.complete,"Malformed replacement lifetime cannot inherit the previous ID's installed completion")
	check(progress.first_complete_ms==complete_time,"Historical first-complete milestone stays separate from incomplete current population")
	var dynamic:=row(900,9,2.);dynamic.replicated.field264=1;dynamic.nativeLifetime=3
	received.receive_delta([dynamic],[],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.desired.has(900) and received.base_scenery_snapshot().expected==0 and received.base_scenery_snapshot().complete,"Canonical dynamic takeover removes static provenance and omission without forcing it into the base lane")
	received.receive_delta([next_life],[],1);received.pending_plan({});received.receive_delta([],[900],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.base_scenery_snapshot().expected==0 and received.base_scenery_snapshot().complete,"Explicit removal retires a renderer-filtered static's sparse unresolved entry")
	received.receive_delta([next_life],[],1);received.pending_plan({});received.receive([],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.base_scenery_snapshot().expected==0,"Full canonical replacement retires missing static population without phantom pending IDs")
	received.receive([next_life],1);received.pending_plan({});received.receive([repaired],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.base_scenery_snapshot().expected==1 and received.base_scenery_snapshot().unresolved_static==0,"Actual full repair replaces the sparse omission set rather than retaining old unresolved state")
	received.receive_delta([next_life],[],1)
	var other_area:=next_life.duplicate(true);other_area.areaId=2
	received.receive_delta([other_area],[],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.base_scenery_snapshot().expected==0,"Received other-area replacement retires current-world omitted identity")
	var removed_row:=next_life.duplicate(true);removed_row.replicationRemoved=true
	received.receive([next_life],1);received.receive_delta([removed_row],[],1);received.pending_plan({})
	check(received.base_scenery_omitted.is_empty() and received.base_scenery_snapshot().complete,"Received removed flag retires sparse omission at the same delta boundary")
	received.receive([next_life],1);received.closed=true;received.receive([],1)
	check(received.base_scenery_omitted.has(900) and not received.base_scenery_snapshot().available,"Retired world ignores later traffic and cannot export available population")
	var reconnected:=Received.new();reconnected.stats={"errors":[],"removed":0};reconnected.receive([repaired],1);reconnected.pending_plan({})
	check(reconnected.base_scenery_omitted.is_empty() and reconnected.base_scenery_snapshot().unresolved_static==0 and reconnected.base_scenery_snapshot().first_complete_ms==null,"Reconnect starts a new scope without stale omission/completion history for reused IDs")
	var transitioned:=Received.new();transitioned.stats={"errors":[],"removed":0};transitioned.area_id=2;transitioned.receive([other_area],1);transitioned.pending_plan({})
	check(transitioned.base_scenery_omitted.has(900) and transitioned.base_scenery_snapshot().unresolved_static==1 and transitioned.base_scenery_snapshot().first_complete_ms==null,"New area with same ID tracks only its own source row/lifetime")
	transitioned.receive_delta([next_life],[],1);transitioned.pending_plan({})
	check(transitioned.base_scenery_omitted.is_empty() and transitioned.base_scenery_snapshot().expected==0,"Prior-area traffic cannot keep an omitted ID alive in a new world's category")
	var malformed_area:=next_life.duplicate(true);malformed_area.erase("areaId")
	reconnected.receive([malformed_area],1);reconnected.pending_plan({})
	check(reconnected.base_scenery_snapshot().unresolved_static==1 and reconnected.base_scenery_snapshot().unresolved_reasons.has("area-unavailable"),"Potential source-static row filtered for unavailable area remains explicitly unresolved")
	var fractional_id:=next_life.duplicate(true);fractional_id.id=900.5
	reconnected.note_omitted_base_scenery(fractional_id);reconnected.pending_plan({})
	check(not reconnected.snapshot(false).object_visuals_complete,"Unaddressable population uncertainty also prevents overall visual-complete claim")
	check(not reconnected.base_scenery_snapshot().available and reconnected.base_scenery_snapshot().reason=="static-population-identity-unavailable","Unaddressable omission cannot claim a numeric population or completion")
	reconnected.receive([],1);reconnected.pending_plan({})
	check(reconnected.snapshot(false).object_visuals_complete,"Full empty canonical replacement can explicitly complete the overall visual category")
	check(reconnected.base_scenery_snapshot().available and reconnected.base_scenery_snapshot().complete,"Full received replacement explicitly clears unaddressable population uncertainty")
	reconnected.receive([repaired],1);var old_key: String=reconnected.desired[900].key
	reconnected.installed[900]=old_key;reconnected.hidden[900]=true;reconnected.failed_objects[900]={"key":old_key};reconnected.motion.objects[900]={};reconnected.motion_revisions[900]=1
	var replaced:=repaired.duplicate(true);replaced.nativeLifetime=4
	reconnected.receive_delta([replaced],[],1);reconnected.pending_plan({})
	check(reconnected.stats.lifetime_replacements==1 and not reconnected.installed.has(900) and not reconnected.hidden.has(900) and not reconnected.failed_objects.has(900),"Actual valid same-ID lifetime replacement clears old installed, hidden and failure bindings")
	check(not reconnected.motion.objects.has(900) and not reconnected.motion_revisions.has(900) and reconnected.base_scenery_snapshot().pending==1,"Lifetime replacement preserves actual movement retirement and pending new appearance")
	var capped:=Candidate.new();capped.maximum_base_static_batch=5
	for index in 12:want(capped,row(10000+index,9,float(12-index),true))
	check(ids(capped.pending_plan({}).base_statics)==[10011,10010,10009,10008,10007],"Separate base wave bound remains configurable and strictly nearest-first before control")
	for workers in [1,4]:
		var worker_checks: Array=[];var request_checks: Array=[]
		# Preserve the original empty-batch three-table checks and additionally
		# exercise the exact new configure predicate on static/mixed/live inputs.
		var all_tables: Array=["placeables","genericdoors","doortypes"]
		for sample in [
			{"objects":[],"names":all_tables,"static_only":false},
			{"objects":[row(11000,9,1.,true)],"names":["placeables"],"static_only":true},
			{"objects":[row(11000,9,1.,true),row(11001,10,2.)],"names":all_tables,"static_only":false},
			{"objects":[row(11002,5,1.)],"names":all_tables,"static_only":false},
			{"objects":[row(11003,9,1.)],"names":all_tables,"static_only":false},
			{"objects":[row(11004,6,1.)],"names":all_tables,"static_only":false}
		]:
			var owner:=Owner.new();root.add_child(owner);owner.maximum_asset_workers=workers
			owner.configure(null,null,sample.objects,1,"private-cache")
			worker_checks.append(owner.assets.calls.size()==sample.names.size() and owner.assets.calls.all(func(call):return call.workers==workers))
			request_checks.append(owner.assets.calls.map(func(call):return call.name)==sample.names and owner.initial_static_tables_only==sample.static_only)
			owner.free()
		check(worker_checks.all(func(passed):return passed),"Worker limit precedes all immediate requests for original empty and new static/mixed/live batches: "+str(workers))
		check(request_checks.all(func(passed):return passed),"Original empty three-table order remains intact; verified-static uses one and mixed/live retains three")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Small actual-extracted receive/delta/pose/planner/classifier/configure/snapshot-prefix checks. No world/asset/GPU/native/server/performance acceptance; collision, terrain contention, complete dependency typing and actual loading remain pending.","gpuTests":0,"serverConnections":0,"nativeBuilds":0}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BASE_SCENERY_LANE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
