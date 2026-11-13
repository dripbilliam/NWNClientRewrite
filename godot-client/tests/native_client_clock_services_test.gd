extends SceneTree
const Services=preload("res://systems/native_data/client_clock_services.gd")
const WorldClock=preload("res://systems/native_data/world_timer.gd")
const ID:=0x80000005
const SCOPE=[7,3,20]
class Counter extends RefCounted:
	var value: int=0
	var reads:=0
	func read()->Dictionary:
		var answer:=WorldClock.words_from_int(value);value+=1000;reads+=1;return answer
class Lower extends RefCounted:
	var calls: Array=[]
	var failed_scene:=false
	var reference_value: Dictionary={}
	var lifecycle_action:="unknown"
	func object(id: int)->Variant:calls.append(["object",id]);return {"id":id} if id==ID else null
	func as_object(value: Variant)->Variant:calls.append(["asObject",value.id]);return value
	func scene(value: Variant)->Variant:calls.append(["scene",value.id]);return {"id":value.id}
	func scene_virtual(value: Variant,offset: int)->Variant:
		calls.append(["sceneVirtual",value.id,offset]);return {"ready":false} if failed_scene else {"ready":true}
	func reset_object(value: Variant,day: int,time: int)->Dictionary:
		calls.append(["resetObjectTimes",value.id,day,time]);return {"ready":true,"creatureReference":reference_value.duplicate(true)}
	func text(id: int)->void:calls.append(["pauseText",id])
	func audio(on: bool)->void:calls.append(["audio",on])
	func lifecycle(_value: Dictionary)->Dictionary:
		if lifecycle_action=="constructed":return {"ready":true,"action":"constructed","reference":reference_value.duplicate(true),"fact":{"externalType5Construction":true,"typedAbsent":true,"externalHistoryComplete":true,"registeredBeforeAi":true}}
		return {"ready":true,"action":"unknown"}
	func callbacks()->Dictionary:return {"object":object,"asObject":as_object,"scene":scene,"sceneVirtual":scene_virtual,"resetObjectTimes":reset_object,"pauseText":text,"audio":audio,"acceptedLifecycle":lifecycle}
var checks:=0
var failures: Array=[]
var authored_scenarios:=0
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
static func reference_value(where: Array=SCOPE)->Dictionary:return {"scope":where.duplicate(),"id":ID,"nativeLifetime":null,"knownLifetime":null,"physicalToken":"certified-physical-five","lifecycleEpoch":1}
static func owner_facts()->Dictionary:return {"processConstructionKnown":true,"gui":{"known":true,"value":null},"profileMode":0,"controlledId":ID}
static func construction_fact()->Dictionary:return {"externalType5Construction":true,"typedAbsent":true,"externalHistoryComplete":true,"registeredBeforeAi":true}
static func event(serial: int,payload: Dictionary,connection: int=7,complete: bool=true)->Dictionary:return {"kind":"native-clock-protocol","version":1,"connection":connection,"serial":serial,"history":{"complete":complete,"reason":null if complete else "capture-incomplete"},"scope":{"generation":3,"areaId":20},"event":payload.duplicate(true)}
static func eligible(module: bool=true,area: bool=true,full: bool=true)->Dictionary:return {"module":module,"area":area,"completePass":full}
func start(service,counter,lower: Variant=null)->void:
	check(service.construct_process(counter.read,owner_facts(),{} if lower==null else lower.callbacks()).ready,"construct-process")
	check(service.attach_connection(7).ready,"attach-no-reconstruction")
	check(service.set_scope(SCOPE).ready,"scope-explicit")
	check(service.begin_frame(1).ready,"prefix-before-events")
	check(service.receive_clock(event(1,{"type":"begin","lifecycleBound":true})).ready,"accepted-begin")
func close_clean(service)->void:
	check(service.cleanup_connection().ready,"ordered-connection-cleanup")
	check(service.destroy_process().ready,"explicit-process-retirement")
func ordinary_frame_path()->void:
	var service:=Services.new();var counter:=Counter.new()
	check(not service.construct_process(counter.read,{}).ready and counter.reads==0,"no-construction-from-new-instance")
	check(service.construct_process(counter.read,owner_facts()).ready,"known-process-constructs")
	var initial:=service.state_view()
	check(counter.reads==3 and initial.timers.world.counter.lo==0 and initial.timers.timer1.counter.lo==1000 and initial.timers.timer2.counter.lo==2000,"three-independent-sequential-constructor-samples")
	check(not service.construct_process(counter.read,owner_facts()).ready and counter.reads==3,"duplicate-construction-no-samples")
	check(service.attach_connection(7).ready and service.set_scope(SCOPE).ready,"connection-area-do-not-reconstruct")
	var prefix:=service.begin_frame(1)
	check(prefix.ready and prefix.prefixSlots==["world","timer1","timer2"] and counter.reads==6,"native-prefix-three-order")
	check(not service.gui_delta(1).ready and service.queue_delta_ms(reference_value(),1)==null,"no-delta-before-conceptual-ai")
	service.receive_clock(event(1,{"type":"begin","lifecycleBound":true}))
	service.receive_clock(event(2,{"type":"module-info","minutesPerHour":3}))
	var after_rate:=service.state_view()
	check(after_rate.timers.world.minutesPerHour==3 and after_rate.timers.timer1.minutesPerHour==5 and after_rate.timers.timer2.minutesPerHour==5,"module-rate-t0-only")
	check(after_rate.timers.world.dayOffset==initial.timers.world.dayOffset and after_rate.timers.world.timeOffset==initial.timers.world.timeOffset,"rate-does-not-rebase-offsets")
	var before_calendar: Dictionary=service.state_view().timers
	check(service.receive_clock(event(3,{"type":"module-time","mask":255})).clockReset==false,"calendar-no-clock-reset")
	check(service.receive_clock(event(4,{"type":"client-area","areaId":20})).clockReset==false,"area-no-clock-reset")
	check(service.state_view().timers==before_calendar and counter.reads==6,"calendar-area-no-sample-or-reset")
	check(not service.construct_creature(reference_value(),{"registeredBeforeAi":true}).ready,"no-birth-from-ref-or-proxy")
	check(service.construct_creature(reference_value(),construction_fact()).ready,"actual-construction-fact-base-t0")
	check(service.finish_ai(1,eligible()).ready,"finish-before-gui")
	var first:=service.object_delta(reference_value(),1)
	check(first.ready and first.elapsedMilliseconds==0 and first.basisKind=="birth","first-ai-from-captured-t0-birth")
	check(service.gui_delta(1).seconds==WorldClock.f32(0.003),"gui-t2-difference-native-float")
	check(service.retain_creature(reference_value(),{"samePhysical":true}).ready,"retained-a-no-new-birth")
	check(service.begin_frame(2).ready,"second-prefix")
	check(service.finish_ai(2,eligible()).ready,"second-ai")
	check(service.queue_delta_ms(reference_value(),2)==3,"second-object-stamp-is-last-ai-not-birth")
	var detached:=service.state_view();detached.timers.world.counter.lo=999999;detached.scope[0]=999
	var delta:=service.object_delta(reference_value(),2);delta.previousPair.time=0
	check(service.queue_delta_ms(reference_value(),2)==3 and service.state_view().scope==SCOPE,"detached-service-views")
	check(not service.destroy_process().ready,"no-process-retire-before-connection-cleanup")
	var before_cleanup:=counter.reads
	var cleanup:=service.cleanup_connection()
	check(cleanup.ready and cleanup.order==[2,1] and cleanup.timersRetired==false and counter.reads==before_cleanup,"zero-flags-cleanup-native-noops")
	var persisted: Dictionary=service.state_view().timers
	check(service.attach_connection(8).ready and service.set_scope([8,1,30]).ready,"new-connection-borrows-services")
	check(service.state_view().timers==persisted and counter.reads==before_cleanup,"connection-preserves-three-timers")
	check(service.begin_frame(3).ready,"new-connection-prefix")
	service.receive_clock(event(1,{"type":"begin","lifecycleBound":true},8))
	service.finish_ai(3,eligible(false,false))
	check(service.queue_delta_ms(reference_value(),3)==null,"old-reference-never-rebinds-new-connection")
	close_clean(service);authored_scenarios+=1
func pause_reset_and_cleanup()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new();lower.reference_value=reference_value()
	start(service,counter,lower);service.construct_creature(reference_value(),construction_fact());service.finish_ai(1,eligible())
	service.begin_frame(2)
	var applied:=service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[ID,ID]}))
	check(applied.ready and applied.consumed,"pause-list-consumed-on-actual-transition")
	var staged: Array=service.state_view().stagedResets
	check(staged.size()==2 and staged[0].pair==staged[1].pair and staged[0].fact.order<staged[1].fact.order,"duplicate-ids-reset-in-original-order")
	var sequence: Array=[]
	for call in lower.calls:
		if call[0]=="sceneVirtual":sequence.append(call[2])
		elif call[0]=="resetObjectTimes":sequence.append("reset")
	check(sequence==[0x150,"reset",0x150,"reset"],"incoming-scene150-before-each-reset")
	check(service.finish_ai(2,eligible()).ready and service.queue_delta_ms(reference_value(),2)==0,"postreceive-selector-and-reset-before-ai")
	service.begin_frame(3)
	check(service.state_view().pause.flags==1,"flags-persist-between-frames")
	var reads_before:=counter.reads;var calls_before:=lower.calls.size()
	var duplicate:=service.receive_clock(event(3,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[ID]}))
	check(duplicate.ready and duplicate.changed==false and duplicate.unconsumedIncoming.ids==[ID] and counter.reads==reads_before and lower.calls.size()==calls_before,"native-noop-leaves-owned-incoming-unconsumed")
	service.finish_ai(3,eligible())
	check(service.queue_delta_ms(reference_value(),3)==4,"selected-clock-lazy-elapsed")
	var gui:=service.gui_delta(3)
	check(gui.ready and gui.seconds==WorldClock.f32(0.004),"gui-clock-separate-from-object-selected-time")
	var cleanup:=service.cleanup_connection()
	check(cleanup.ready and cleanup.order==[2,1] and service.state_view().pause.flags==0 and service.state_view().connection==-1,"ordered-mask-cleanup-before-retirement")
	check(service.state_view().constructed and service.state_view().timers.world.ready,"cleanup-retains-process-timers")
	check(service.destroy_process().ready,"pause-process-close");authored_scenarios+=1
func sticky_history_and_unsupported()->void:
	var service:=Services.new();var counter:=Counter.new()
	start(service,counter);service.construct_creature(reference_value(),construction_fact());service.finish_ai(1,eligible())
	service.begin_frame(2)
	check(not service.receive_clock(event(4,{"type":"module-info","minutesPerHour":9})).ready,"serial-gap-rejected")
	var ended:=service.finish_ai(2,eligible())
	check(not ended.ready and not service.gui_delta(2).ready and service.queue_delta_ms(reference_value(),2)==null,"gap-does-not-invent-clock-output")
	var old:=service.state_view();check(old.processConstructionKnown and not old.clockHistoryComplete,"process-construction-distinct-from-stream-certainty")
	check(service.cleanup_connection().ready,"tainted-zero-flags-cleanup")
	service.attach_connection(8);service.set_scope([8,1,30]);service.begin_frame(3)
	service.receive_clock(event(1,{"type":"begin","lifecycleBound":true},8));service.finish_ai(3,eligible(false,false))
	check(not service.state_view().clockHistoryComplete and service.state_view().transportHistoryComplete and not service.gui_delta(3).ready,"new-begin-cannot-recertify-process-clocks")
	close_clean(service)
	service=Services.new();counter=Counter.new();start(service,counter)
	var before: Dictionary=service.state_view().timers
	var unsupported:=service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[]}))
	check(not unsupported.ready and service.state_view().pause.flags==0 and service.state_view().timers==before,"missing-scene-audio-etc-not-fake-noops")
	service.finish_ai(1,eligible(false,false));check(not service.state_view().clockHistoryComplete,"unsupported-transition-remains-unknown")
	close_clean(service);authored_scenarios+=2
func partial_cleanup()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new();lower.reference_value=reference_value()
	start(service,counter,lower);service.construct_creature(reference_value(),construction_fact())
	service.receive_clock(event(2,{"type":"module-pause-state","mask":2,"value":1,"exclusionIds":[ID]}));service.finish_ai(1,eligible())
	var before:=service.state_view();var reads_before:=counter.reads;lower.failed_scene=true
	var result:=service.cleanup_connection()
	var after:=service.state_view()
	check(not result.ready and result.partial and after.connection==7 and after.phase=="cleanup-partial","failed-cleanup-retains-explicit-partial-owner")
	check(counter.reads>reads_before and after.timers!=before.timers and not after.clockHistoryComplete,"partial-cleanup-does-not-rollback-absolute-samples")
	lower.failed_scene=false
	check(service.cleanup_connection().ready and not service.state_view().clockHistoryComplete,"later-cleanup-does-not-recertify-clock-history")
	check(service.destroy_process().ready,"partial-owner-resource-close");authored_scenarios+=1
func unknown_entity_is_not_missed_clock()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new()
	start(service,counter,lower)
	var known:=reference_value();var other:=reference_value();other.id=ID+2;other.physicalToken="other-certified-owner"
	service.construct_creature(known,construction_fact());service.construct_creature(other,construction_fact())
	var unknown:={"type":"accepted-lifecycle","version":2,"lifecycleEpoch":1,"transaction":1,"operation":"create","recordIndex":0,"objectId":ID+1,"objectType":5,"ownership":"unknown","deletionFlag":null,"areaId":20,"physicalToken":null,"ownerAbsentCertified":false,"constructionCertified":false,"aiRegistrationCertified":false,"constructionHistoryComplete":false}
	var received:=service.receive_clock(event(2,unknown))
	check(received.ready and not received.objectClockReady,"valid-unknown-construction-is-not-missing-wire")
	service.finish_ai(1,eligible())
	check(service.gui_delta(1).ready and service.queue_delta_ms(known,1)==0 and not service.state_view().externalLifetimeComplete,"unknown-other-entity-keeps-timers-and-certified-object")
	service.begin_frame(2);unknown.objectId=ID;unknown.transaction=2
	service.receive_clock(event(3,unknown));service.finish_ai(2,eligible())
	check(service.queue_delta_ms(known,2)==null and service.queue_delta_ms(other,2)==3 and service.gui_delta(2).ready,"only-affected-physical-reference-unavailable")
	check(service.state_view().clockHistoryComplete and service.state_view().transportHistoryComplete,"coverage-independent-of-construction-certainty")
	close_clean(service);authored_scenarios+=1
func early_birth_without_display_rows()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new()
	lower.reference_value=reference_value();lower.lifecycle_action="constructed";start(service,counter,lower)
	var fresh:={"type":"accepted-lifecycle","version":2,"lifecycleEpoch":1,"transaction":1,"operation":"create","recordIndex":0,"objectId":ID,"objectType":5,"ownership":"new","deletionFlag":null,"areaId":20,"physicalToken":"certified-physical-five","ownerAbsentCertified":false,"constructionCertified":true,"aiRegistrationCertified":true,"constructionHistoryComplete":true}
	check(service.receive_clock(event(2,fresh)).ready,"fresh-a-ownerAbsent-false-is-correct")
	check(not service.area_transfer_references(SCOPE,{}).ready,"no-perframe-reference-enumeration-api")
	var boundary:=service.area_transfer_references(SCOPE,{"areaBoundary":true})
	check(boundary.ready and boundary.references.size()==1 and boundary.references[0].nativeLifetime==null and boundary.references[0].knownLifetime==null,"birth-uses-internal-null-display-fields")
	var original: Dictionary=boundary.references[0].duplicate(true);boundary.references[0].physicalToken="mutated"
	service.finish_ai(1,eligible())
	for frame in range(2,5):service.begin_frame(frame);service.finish_ai(frame,eligible())
	check(service.queue_delta_for_physical(ID,"certified-physical-five",SCOPE,4)==3,"late-first-physical-query-is-last-ai-not-enqueue-or-birth")
	check(service.queue_delta_for_physical(ID,"wrong",SCOPE,4)==null and service.queue_delta_for_physical(ID,"certified-physical-five",[7,4,21],4)==null,"physical-query-scope-token-fenced")
	var display:=original.duplicate(true);display.nativeLifetime=900;display.knownLifetime=901
	check(not service.object_delta(display,4).ready,"display-witness-not-fabricated-clock-alias")
	service.begin_frame(5)
	check(service.retire_reference(original,{"referenceRetired":true}).ready,"explicit-old-reference-retired")
	lower.reference_value=reference_value();lower.reference_value.lifecycleEpoch=2;lower.reference_value.physicalToken="new-physical-two"
	fresh.lifecycleEpoch=2;fresh.transaction=2;fresh.physicalToken="new-physical-two"
	check(service.receive_clock(event(3,fresh)).ready,"new-certified-physical-clock")
	service.finish_ai(5,eligible())
	check(service.queue_delta_for_physical(ID,"certified-physical-five",SCOPE,5)==null and service.queue_delta_for_physical(ID,"new-physical-two",SCOPE,5)==0 and not service.object_delta(original,5).ready,"stale-null-display-alias-cannot-follow-reuse")
	close_clean(service);authored_scenarios+=1
func receive_phase_attach_and_cleanup()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new();lower.reference_value=reference_value()
	service.construct_process(counter.read,owner_facts(),lower.callbacks())
	check(service.begin_frame(1).ready,"prefix-before-first-real-attach")
	var reads:=counter.reads
	check(service.attach_connection(7).ready and counter.reads==reads,"attach-inside-receive-no-extra-prefix-or-sample")
	service.receive_clock(event(1,{"type":"begin","lifecycleBound":true}));service.set_scope(SCOPE)
	service.construct_creature(reference_value(),construction_fact())
	service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[ID]}));service.finish_ai(1,eligible())
	check(service.begin_frame(2).ready,"old-connection-prefix-once")
	var cleanup:=service.cleanup_connection()
	check(cleanup.ready and cleanup.receivePhasePreserved and service.state_view().phase=="receive" and service.state_view().frame==2,"cleanup-inside-receive-preserves-open-prefix")
	reads=counter.reads
	check(service.attach_connection(8).ready and counter.reads==reads,"new-attach-in-same-receive-batch")
	check(service.receive_clock(event(1,{"type":"begin","lifecycleBound":true},8)).ready,"new-begin-without-second-prefix")
	var next_scope:=[8,1,30];service.set_scope(next_scope)
	var next:=reference_value(next_scope);next.physicalToken="connection-eight-physical";lower.reference_value=next
	check(service.construct_creature(next,construction_fact()).ready,"new-receive-batch-physical-birth")
	check(service.finish_ai(2,eligible()).ready and service.gui_delta(2).ready,"sameframe-finish-ai-then-gui-once")
	check(service.queue_delta_for_physical(ID,next.physicalToken,next_scope,2)==0 and service.queue_delta_for_physical(ID,"certified-physical-five",SCOPE,2)==null,"oldscope-never-follows-samebatch-reconnect")
	close_clean(service)
	service=Services.new();counter=Counter.new();service.construct_process(counter.read,owner_facts());service.begin_frame(1)
	check(service.finish_ai(1,eligible(false,false)).ready and service.gui_delta(1).ready,"menu-no-connection-frame-still-has-t2-gui")
	check(service.destroy_process().ready,"menu-process-retirement");authored_scenarios+=1
func prearea_birth_and_reset_transfer()->void:
	var service:=Services.new();var counter:=Counter.new();var lower:=Lower.new()
	service.construct_process(counter.read,owner_facts(),lower.callbacks());service.begin_frame(1);service.attach_connection(7)
	service.receive_clock(event(1,{"type":"begin","lifecycleBound":true}))
	var before_area:=[7,0,0x7f000000];service.set_scope(before_area)
	var first:=reference_value(before_area);var other:=reference_value(before_area);other.id=ID+2;other.physicalToken="prearea-other"
	lower.reference_value=first
	check(service.construct_creature(first,construction_fact()).ready and service.construct_creature(other,construction_fact()).ready,"prearea-birth-before-raw-or-are")
	check(service.finish_ai(1,eligible(true,false)).ready,"prearea-no-ai-still-gui")
	service.begin_frame(2)
	check(service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[ID]})).ready,"prearea-reset-captured")
	var before: Array=service.state_view().stagedResets
	var boundary:=service.area_transfer_references(before_area,{"areaBoundary":true});var transfers: Array=[]
	for old in boundary.references:
		var next: Dictionary=old.duplicate(true);next.scope=SCOPE.duplicate();transfers.append({"previous":old,"next":next,"samePhysical":true})
	var reads_before:=counter.reads;var calls_before:=lower.calls.size()
	check(service.set_scope(SCOPE,transfers,{"continuousHistory":true}).ready,"samebatch-prearea-to-actual-are-transfer")
	var after: Array=service.state_view().stagedResets
	check(before.size()==1 and after.size()==1 and after[0].reference.scope==SCOPE and before[0].pair==after[0].pair and before[0].fact==after[0].fact,"reset-reference-only-remap-keeps-pair-frame-order")
	check(counter.reads==reads_before and lower.calls.size()==calls_before,"scope-transfer-no-timestamp-or-callback-replay")
	lower.reference_value=reference_value()
	check(service.finish_ai(2,eligible()).ready,"postarea-ai-after-earlier-reset")
	check(service.queue_delta_for_physical(ID,first.physicalToken,SCOPE,2)==0,"transferred-reset-applies-to-same-physical-clock")
	check(service.queue_delta_for_physical(ID+2,other.physicalToken,SCOPE,2)==3,"unreset-prearea-birth-not-delayed-to-are")
	check(service.queue_delta_for_physical(ID,first.physicalToken,before_area,2)==null,"prearea-alias-retired")
	close_clean(service);authored_scenarios+=1
func current_reference_retirement_by_id()->void:
	var service:=Services.new();var counter:=Counter.new();start(service,counter)
	var original:=reference_value();service.construct_creature(original,construction_fact());service.finish_ai(1,eligible())
	check(service.queue_delta_for_physical(ID,original.physicalToken,SCOPE,1)==0,"id-retirement-original-physical-clock-ready")
	check(not service.retire_current_reference(ID,SCOPE,{}).ready and not service.retire_current_reference(ID,[7,4,21],{"acceptedLifecycleRetirement":true}).ready,"id-retirement-requires-trusted-current-scope")
	check(service.queue_delta_for_physical(ID,original.physicalToken,SCOPE,1)==0,"rejected-id-retirement-does-not-alter-binding")
	var retired:=service.retire_current_reference(ID,SCOPE,{"acceptedLifecycleRetirement":true})
	check(retired.ready and retired.retired and retired.physicalDestructionInferred==false,"id-retirement-not-native-physical-destruction")
	check(not service.object_delta(original,1).ready and service.queue_delta_for_physical(ID,original.physicalToken,SCOPE,1)==null,"id-retirement-old-ref-and-physical-query-unavailable")
	var boundary:=service.area_transfer_references(SCOPE,{"areaBoundary":true})
	check(boundary.ready and boundary.references.is_empty(),"id-retirement-not-enumerated-for-transfer")
	var absent:=service.retire_current_reference(ID,SCOPE,{"acceptedLifecycleRetirement":true})
	check(absent.ready and absent.retired==false and absent.physicalDestructionInferred==false,"id-retirement-known-absent-needs-no-token-placeholder")
	check(service.gui_delta(1).ready and service.state_view().clockHistoryComplete,"id-retirement-does-not-retire-gui-clock")
	close_clean(service)
	service=Services.new();counter=Counter.new();var lower:=Lower.new();lower.reference_value=original
	start(service,counter,lower);service.construct_creature(original,construction_fact())
	service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[ID]}))
	check(service.state_view().stagedResets.size()==1,"old-reset-captured-before-logical-retirement")
	check(service.retire_current_reference(ID,SCOPE,{"acceptedLifecycleRetirement":true}).ready,"id-retirement-with-pending-reset-is-constant-work")
	var replacement:=reference_value();replacement.physicalToken="replacement-after-retirement";replacement.lifecycleEpoch=2
	check(service.construct_creature(replacement,construction_fact()).ready,"replacement-has-its-own-trusted-birth")
	lower.reference_value=replacement;service.finish_ai(1,eligible())
	check(service.queue_delta_for_physical(ID,original.physicalToken,SCOPE,1)==null and service.queue_delta_for_physical(ID,replacement.physicalToken,SCOPE,1)==0,"old-pending-reset-cannot-block-or-retarget-replacement")
	close_clean(service)
	service=Services.new();counter=Counter.new();lower=Lower.new();lower.reference_value=original
	start(service,counter,lower);service.construct_creature(original,construction_fact())
	service.receive_clock(event(2,{"type":"module-pause-state","mask":2,"value":1,"exclusionIds":[ID]}));service.finish_ai(1,eligible())
	lower.failed_scene=true
	check(not service.cleanup_connection().ready,"release-fixture-has-real-partial-cleanup")
	var reads_before:=counter.reads
	check(not service.release_process({}).ready and not service.release_process({"processExiting":false}).ready and service.state_view().connection==7,"release-requires-explicit-final-process-fact")
	var weak: WeakRef=weakref(service)
	var released:=service.release_process({"processExiting":true})
	check(released.ready and released.released and released.connectionCleanupAccepted==false and released.priorConnection==7 and released.priorPhase=="cleanup-partial" and not released.priorFailure.is_empty(),"release-preserves-failed-cleanup-diagnostic")
	check(counter.reads==reads_before and not service.state_view().constructed and service.queue_delta_for_physical(ID,original.physicalToken,SCOPE,1)==null,"release-closes-resources-without-sampling-or-clock-output")
	check(not service.construct_process(counter.read,owner_facts()).ready and counter.reads==reads_before,"final-release-cannot-reconstruct-or-recertify-process")
	service=null
	check(weak.get_ref()==null,"release-breaks-service-pause-callback-cycle")
	authored_scenarios+=1
func local_control_source_pair()->void:
	var service:=Services.new();var counter:=Counter.new();start(service,counter)
	var samples_before:=counter.reads
	var local:={"type":"object-control","playerId":1,"objectId":ID+2,"sourceMajor":5,"sourceMinor":2}
	var admitted:=service.receive_clock(event(2,local))
	check(admitted.ready and admitted.localControlChanged and service.state_view().pause.controlledId==ID+2,"actual-5-2-updates-local-controlled-id")
	var roster:={"type":"object-control","playerId":9,"objectId":ID+4,"sourceMajor":14,"sourceMinor":14}
	var other:=service.receive_clock(event(3,roster))
	check(other.ready and other.localControlChanged==false and service.state_view().pause.controlledId==ID+2,"actual-14-14-roster-does-not-steal-local-control")
	var malformed: Array=[]
	var invalid:=local.duplicate();invalid.sourceMinor=14;malformed.append(invalid)
	invalid=roster.duplicate();invalid.sourceMinor=2;malformed.append(invalid)
	invalid=local.duplicate();invalid.erase("playerId");malformed.append(invalid)
	invalid=local.duplicate();invalid.erase("objectId");malformed.append(invalid)
	invalid=local.duplicate();invalid.erase("sourceMajor");malformed.append(invalid)
	invalid=local.duplicate();invalid.erase("sourceMinor");malformed.append(invalid)
	invalid=local.duplicate();invalid.playerId=-1;malformed.append(invalid)
	invalid=local.duplicate();invalid.objectId=4294967296;malformed.append(invalid)
	invalid=local.duplicate();invalid.sourceMajor=true;malformed.append(invalid)
	invalid=local.duplicate();invalid.playerId=0.5;malformed.append(invalid)
	var serial:=4
	for value in malformed:
		check(not service.receive_clock(event(serial,value)).ready and service.state_view().pause.controlledId==ID+2,"malformed-control-does-not-change-local-id-"+str(serial));serial+=1
	var boundary:=local.duplicate();boundary.playerId=4294967295
	check(service.receive_clock(event(serial,boundary)).ready and service.state_view().pause.controlledId==ID+2,"actual-control-uint32-player-boundary")
	check(counter.reads==samples_before and service.state_view().objects.bindingCount==0,"control-is-not-clock-sample-or-creature-construction")
	service.finish_ai(1,eligible(false,false));close_clean(service);authored_scenarios+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	ordinary_frame_path();pause_reset_and_cleanup();sticky_history_and_unsupported();partial_cleanup();unknown_entity_is_not_missed_clock();early_birth_without_display_rows();receive_phase_attach_and_cleanup();prearea_birth_and_reset_transfer();current_reference_retirement_by_id();local_control_source_pair()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"authoredScenarios":authored_scenarios,"retainedNativeCasesReexecuted":0,"scope":"Authored process/connection/frame/provider composition on actual timer/pause/lazy primitives. Existing native corpora are separately pinned basis; no new native execution, provider/runtime/physical-lifecycle admission or GUI execution."}
	var target:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):target=arg.trim_prefix("--report=")
	var file:=FileAccess.open(target,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
