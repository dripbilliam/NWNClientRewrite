extends RefCounted
# Session integration only. Protocol and physical-clock state stay with their
# existing owners; this adapter keeps no world rows, models or per-frame scans.
const Services=preload("res://systems/native_data/client_clock_services.gd")
const Source=preload("res://systems/native_data/native_clock_source.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Anchor=preload("res://systems/native_data/script_floating_anchor.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const INVALID:=0x7f000000
const LIFECYCLE_SOURCE:="native_client_clock_lifecycle_v1"
const DIRECT_QUEUE_LIMIT:=4096
const DIRECT_PAUSE_ID_LIMIT:=262144
const DIRECT_EVENTS={&"module_information_ready":"module-info",&"area_state_ready":"client-area",&"time_changed":"module-time",&"roster_message_ready":"object-control",&"object_updates_ready":"object-updates",&"module_pause_ready":"module-pause-state",&"diagnostic_event":"diagnostic"}
const DIRECT_GAPS={"network.game-message-invalid":"decoder-rejected","network.object-import-failed":"lifecycle-gap","network.object-record-unhandled":"incomplete-records","network.game-session-failed":"transport-gap","network.area-import-failed":"lifecycle-gap"}
var client
var source
var services
var enabled:=false
var ready:=false
var connection:=-1
var current_frame:=-1
var current_scope: Array=[]
var module_present:=false
var area_present:=false
var delivering: Dictionary={}
var bound_ui: WeakRef
var presentation_stamps: Dictionary={}
var direct_owner: WeakRef
var direct_world: WeakRef
var direct_epoch:=-1
var direct_epoch_invalid:=false
var direct_transaction:=0
var direct_controlled_id:=INVALID
var direct_listeners: Dictionary={}
var direct_queue: Array[Dictionary]=[]
var direct_pause_ids:=0
var direct_gap_reason:=""
var direct_pending_gap:=""
var diagnostics:={"enabled":false,"ready":false,"protocolFrames":0,"directPackets":0,"directOwnersReady":false,"directControlledIdKnown":false,"unavailable":0,"lastReason":"","phase":"native-direct-real-candidate"}
func configure(owner)->void:
	client=owner
	# The process-owned absolute timers and frame prefix are valid for a normal
	# direct session. Pause transitions still require independently bound scene
	# and GUI owners; enabling these clocks never certifies those providers.
	enabled=client.args.get("offline-replay","")!="true" and client.args.get("native-overhead-clocks","")=="true"
	diagnostics.enabled=enabled
	client.report.native_clock_runtime=diagnostics
	if not enabled:return
	source=Source.new()
	var loaded: Dictionary=source.initialize()
	if not loaded.ready:note(loaded);return
	services=Services.new()
	# GUI/profile/scene semantics are not silently replaced with null/no-ops.
	# The unpaused prefix and GUI T2 path need none of those lower providers.
	var result: Dictionary=services.construct_process(source.read,{"processConstructionKnown":true},{"acceptedLifecycle":accepted_lifecycle})
	ready=result.get("ready",false);diagnostics.ready=ready
	if not ready:note(result)
func note(result: Dictionary)->void:
	if result.get("ready",false):return
	diagnostics.unavailable=mini(int(diagnostics.unavailable)+1,9007199254740991)
	diagnostics.lastReason=str(result.get("reason","Native clock result is unavailable.")).left(240)
func prefix(frame: int)->void:
	if direct_owner!=null:
		var owner:=current_direct_owner(connection)
		if owner==null:cleanup_connection()
		else:verify_direct_world(owner)
	if not ready:return
	if client.direct_mode:
		# Area publication can defer the post-receive hook. Close that frame
		# without certifying an AI pass so the following prefix can run.
		if services.receive_frame_open(current_frame):
			note(services.finish_ai(current_frame,{"module":module_present,"area":area_present,"completePass":false}))
	current_frame=frame;note(services.begin_frame(frame))
	drain_direct_clock()
func attach_direct_session(owner: Node,source_connection: int)->Dictionary:
	if client==null or not is_instance_valid(owner) or client.get("direct_session")!=owner or client.native_text_connection()!=source_connection or owner.get("phase") in ["closed","failed"] or not Scope.integer(source_connection,0,Scope.MAX_SAFE):
		return {"ready":false,"reason":"Direct clock has no current session owner."}
	if current_direct_owner(source_connection)==owner:return {"ready":true,"reused":true}
	var world: Variant=owner.get("world_state")
	if not world is RefCounted or not world.get("clock_lifecycle") is RefCounted:
		return {"ready":false,"reason":"Direct clock lifecycle owner is unavailable."}
	for signal_name in DIRECT_EVENTS:
		if not owner.has_signal(signal_name):return {"ready":false,"reason":"Direct clock event owner is unavailable: "+str(signal_name)}
	if not owner.has_signal("phase_changed"):return {"ready":false,"reason":"Direct clock retirement owner is unavailable."}
	var history: Dictionary=world.clock_lifecycle.bind_connection(world,source_connection)
	if history.get("source")!=LIFECYCLE_SOURCE or history.get("version")!=1 or not Scope.integer(history.get("epoch"),1,Scope.MAX_SAFE) or history.get("connection")!=source_connection:
		return {"ready":false,"reason":"Direct clock lifecycle connection bind failed."}
	var early: bool=owner.phase=="idle" and world.registry.is_empty() and world.module.is_empty() and world.area.is_empty()
	var record_history: bool=early and history.get("recordHistoryComplete")==true
	if ready:
		var attached: Dictionary=services.attach_direct_connection(source_connection,record_history,history.get("constructionHistoryComplete")==true)
		if not attached.ready:note(attached);return attached
	connection=source_connection;module_present=false;area_present=false
	direct_owner=weakref(owner);direct_world=weakref(world);direct_epoch=int(history.epoch)
	for signal_name in DIRECT_EVENTS:
		var listener:=observe_direct_clock.bind(source_connection,DIRECT_EVENTS[signal_name])
		direct_listeners[signal_name]=listener
		owner.connect(signal_name,listener)
	var phase_listener:=observe_direct_phase.bind(source_connection)
	direct_listeners[&"phase_changed"]=phase_listener
	owner.phase_changed.connect(phase_listener)
	if not record_history:mark_direct_gap("lifecycle-gap" if early else "late-bind")
	return {"ready":true,"reused":false,"connection":connection,"epoch":direct_epoch,"historyComplete":record_history,"clockSampling":ready}
func current_direct_owner(source_connection: int)->Node:
	if direct_owner==null or client==null or source_connection!=connection or client.native_text_connection()!=source_connection:return null
	var owner: Variant=direct_owner.get_ref()
	return owner if is_instance_valid(owner) and client.get("direct_session")==owner else null
func verify_direct_world(owner: Node)->bool:
	if direct_epoch_invalid:return false
	var world: Variant=direct_world.get_ref()
	if world==null or owner.get("world_state")!=world:
		direct_epoch_invalid=true;mark_direct_gap("reset-unverified");return false
	var history: Variant=world.clock_lifecycle.history(world)
	if not history is Dictionary or history.get("epoch")!=direct_epoch or history.get("connection")!=connection:
		direct_epoch_invalid=true;mark_direct_gap("reset-unverified");return false
	if history.get("recordHistoryComplete")!=true:mark_direct_gap("lifecycle-gap")
	return true
func observe_direct_phase(phase: String,source_connection: int)->void:
	if direct_owner==null or source_connection!=connection:return
	if phase in ["closed","failed"]:cleanup_connection();return
	var owner:=current_direct_owner(source_connection)
	if owner!=null:verify_direct_world(owner)
func mark_direct_gap(reason: String)->void:
	if not direct_gap_reason.is_empty():return
	direct_gap_reason=reason
	if not ready:return
	if direct_queue.size()>=DIRECT_QUEUE_LIMIT:direct_pending_gap=reason
	else:direct_queue.append({"type":"history-gap","cause":reason})
func enqueue_direct_clock(event: Dictionary,generation: int,area: int)->void:
	var exclusions: Variant=event.get("message",{}).get("exclusionIds")
	var ids: int=exclusions.size() if exclusions is Array else 0
	if direct_queue.size()>=DIRECT_QUEUE_LIMIT or ids>DIRECT_PAUSE_ID_LIMIT-direct_pause_ids:mark_direct_gap("queue-overflow");return
	if ids>0:event.message=event.message.duplicate(true)
	direct_pause_ids+=ids
	event.scope={"generation":generation,"areaId":area}
	direct_queue.append(event)
func observe_direct_clock(message: Dictionary,source_connection: int,type: String)->void:
	var owner:=current_direct_owner(source_connection)
	if owner==null:return
	if type=="diagnostic":
		var reason: String=DIRECT_GAPS.get(message.get("code"),"")
		if not reason.is_empty():mark_direct_gap(reason)
		return
	if not ready and type!="object-updates":return
	if type=="object-updates" and message.get("complete")!=true:mark_direct_gap("incomplete-records")
	if not verify_direct_world(owner):return
	var world: RefCounted=direct_world.get_ref()
	var generation: int=owner.area_generation
	var area: int=world.area_id
	match type:
		"module-info":enqueue_direct_clock({"type":type,"minutesPerHour":message.get("minutesPerHour")},generation,area)
		"client-area":enqueue_direct_clock({"type":type,"areaId":message.get("area",{}).get("id")},generation,area)
		"module-time":enqueue_direct_clock({"type":type},generation,area)
		"object-control":
			if message.get("kind")==type:
				enqueue_direct_clock({"type":type,"playerId":message.get("playerId"),"objectId":message.get("objectId"),"sourceMajor":message.get("major"),"sourceMinor":message.get("minor")},generation,area)
				if message.get("major")==5 and message.get("minor")==2:direct_controlled_id=int(world.local_object_id)
		"module-pause-state":
			if message.get("generation")==generation and message.get("areaId")==area and message.get("message") is Dictionary:
				enqueue_direct_clock({"type":type,"message":message.message.duplicate()},generation,area)
			else:mark_direct_gap("source-unknown")
		"object-updates":
			observe_direct_lifecycle(world,message,generation,area)
			# The direct world can also establish control through its accepted
			# player record. Process that change after this packet's lifecycle.
			if ready and world.local_object_id!=direct_controlled_id:
				direct_controlled_id=int(world.local_object_id)
				enqueue_direct_clock({"type":"controlled-actor","objectId":direct_controlled_id},generation,area)
func observe_direct_lifecycle(world: RefCounted,message: Dictionary,generation: int,area: int)->void:
	var transaction:=direct_transaction
	var records: Array=message.get("records",[])
	var events: Array[Dictionary]=[]
	var complete:=true
	for boundary in world.clock_last_boundaries:
		var accepted: Variant=world.clock_lifecycle.accepted_boundary(world,boundary)
		if not accepted is Dictionary or accepted.get("version")!=1 or accepted.get("source")!=LIFECYCLE_SOURCE or accepted.get("epoch")!=direct_epoch or accepted.get("connection")!=connection or not accepted.get("complete") is bool or accepted.get("recordHistoryComplete")!=accepted.complete or not accepted.get("constructionHistoryComplete") is bool or not accepted.get("fact") is Dictionary:
			mark_direct_gap("lifecycle-gap");return
		var received: Variant=accepted.get("transaction")
		# A rejected transaction can leave the previous receipt in the world.
		# Its already-consumed boundaries must never be replayed.
		if Scope.integer(received,1,Scope.MAX_SAFE) and received<=direct_transaction:continue
		var fact: Dictionary=accepted.fact
		if not Scope.integer(received,1,Scope.MAX_SAFE) or transaction!=direct_transaction and received!=transaction or not Scope.integer(fact.get("recordIndex"),0,records.size()-1) or not Scope.integer(fact.get("objectId"),0x80000000,Scope.MAX_ID):
			mark_direct_gap("lifecycle-gap");return
		transaction=int(received)
		complete=complete and accepted.complete
		var event:=fact.duplicate(true)
		event.merge({"type":"accepted-lifecycle","version":2,"lifecycleEpoch":direct_epoch,"transaction":transaction,"constructionHistoryComplete":accepted.get("constructionHistoryComplete")},true)
		var projected:=Services._lifecycle_fields(event)
		if projected.is_empty():mark_direct_gap("lifecycle-gap");return
		events.append(projected)
	direct_transaction=transaction
	if not complete:mark_direct_gap("incomplete-records")
	for event in events:
		# Visibility consumes accepted construction even with no clock samples.
		if client.has_method("native_visibility_lifecycle") and generation>=client.epoch:client.native_visibility_lifecycle(event)
		if ready:enqueue_direct_clock(event,generation,area)
func drain_direct_clock()->void:
	if direct_owner==null or not services.receive_frame_open(current_frame):return
	var queued:=direct_queue;direct_queue=[];direct_pause_ids=0
	if not direct_pending_gap.is_empty():
		queued.append({"type":"history-gap","cause":direct_pending_gap});direct_pending_gap=""
	for event in queued:
		if direct_owner==null:return
		var type: String=event.type
		if event.has("scope"):
			var expected: Array=[connection,event.scope.generation,event.scope.areaId]
			set_scope(event.scope)
			if current_scope!=expected:
				note(services.receive_direct_event({"type":"history-gap","cause":"source-unknown"},connection));continue
		delivering=event
		var result: Dictionary
		if type=="module-pause-state":
			diagnostics.directPackets=mini(int(diagnostics.directPackets)+1,Scope.MAX_SAFE)
			result=services.receive_server_pause(event.message,connection,event.scope.areaId,event.scope.generation)
		else:result=services.receive_direct_event(event,connection)
		delivering={}
		if result.get("ready",false):
			if type=="module-info":module_present=true
			elif type=="client-area":area_present=int(event.areaId)!=INVALID
			elif type=="controlled-actor" or type=="object-control" and result.get("localControlChanged",false):diagnostics.directControlledIdKnown=true
			note(result)
func bind_direct_owners(facts: Dictionary,providers: Dictionary)->Dictionary:
	if not ready:return {"ready":false,"reason":"Native direct clock process is unavailable."}
	var result: Dictionary=services.bind_direct_owners(facts,providers)
	diagnostics.directOwnersReady=result.get("ready",false) and result.get("transitionsReady",false)
	if not result.ready:note(result)
	return result
func publish_direct_controlled_id(value: int,source_connection: int,source_generation: int,source_area: int)->Dictionary:
	# This is the actual admitted actor ID, not a substitute for the native
	# profile/GUI or scene providers required by a pause transition.
	if not ready or client==null or not Scope.integer(value,0,Scope.MAX_ID):return {"ready":false,"reason":"Direct controlled actor or process clock is unavailable."}
	if not client.has_method("native_clock_direct_scope"):return {"ready":false,"reason":"Direct clock live area owner is unavailable."}
	var live_scope: Variant=client.native_clock_direct_scope()
	if not live_scope is Dictionary or live_scope.get("connection")!=source_connection or live_scope.get("generation")!=source_generation or live_scope.get("areaId")!=source_area:return {"ready":false,"reason":"Direct controlled actor does not match the live area owner."}
	if direct_owner!=null:
		var owner:=current_direct_owner(source_connection)
		if owner==null or not verify_direct_world(owner) or owner.world_state.local_object_id!=value:return {"ready":false,"reason":"Direct controlled actor has no accepted owner."}
		# The accepted signal owns chronology. Rendering may publish this ID
		# reentrantly while the corresponding world event is still being sent.
		return {"ready":true}
	var result: Dictionary=services.publish_owner_facts({"controlledId":value})
	if result.get("ready",false):diagnostics.directControlledIdKnown=true
	else:note(result)
	return result
func receive_direct_pause(message: Dictionary,source_connection: int,source_generation: int,source_area: int)->Dictionary:
	# Only the admitted direct session may supply this connection. The three
	# absolute timers were already prefixed by NativeSessionWorld this frame.
	if not ready or not diagnostics.directOwnersReady or current_frame<0:
		return {"ready":false,"reason":"Direct clock frame or lower owners are unavailable."}
	if not Scope.integer(source_connection,0,Scope.MAX_SAFE) or not Scope.integer(source_generation,0,Scope.MAX_SAFE) or not Scope.integer(source_area,0,Scope.MAX_ID):
		return {"ready":false,"reason":"Direct clock connection or area scope is invalid."}
	if client==null or not client.has_method("native_text_connection") or client.native_text_connection()!=source_connection:
		return {"ready":false,"reason":"Direct clock packet has no current accepted connection."}
	if not client.has_method("native_clock_direct_scope"):
		return {"ready":false,"reason":"Direct clock live area owner is unavailable."}
	var live_scope: Variant=client.native_clock_direct_scope()
	if not live_scope is Dictionary or live_scope.get("connection")!=source_connection or live_scope.get("generation")!=source_generation or live_scope.get("areaId")!=source_area:
		return {"ready":false,"reason":"Direct clock packet does not match the live area owner."}
	if connection<0:
		var attached: Dictionary=services.attach_connection(source_connection)
		if not attached.ready:note(attached);return attached
		connection=source_connection
	elif connection!=source_connection:return {"ready":false,"reason":"Direct clock packet belongs to another connection."}
	var scope: Dictionary={"generation":source_generation,"areaId":source_area}
	set_scope(scope)
	if current_scope!=[source_connection,source_generation,source_area]:
		return {"ready":false,"reason":"Direct clock area scope was not admitted."}
	diagnostics.directPackets=mini(int(diagnostics.directPackets)+1,9007199254740991)
	var result: Dictionary=services.receive_server_pause(message,source_connection,source_area,source_generation)
	if not result.ready:note(result)
	return result
func set_scope(value: Dictionary)->void:
	var generation: Variant=value.get("generation");var area: Variant=value.get("areaId")
	if not Scope.integer(generation,0,Scope.MAX_SAFE) or not Scope.integer(area,0,Scope.MAX_ID):return
	var next: Array=[connection,int(generation),int(area)]
	if next==current_scope:return
	var transfers: Array=[]
	if not current_scope.is_empty():
		var retained: Dictionary=services.area_transfer_references(current_scope,{"areaBoundary":true})
		if not retained.ready:note(retained);return
		for previous in retained.references:
			var following: Dictionary=previous.duplicate(true);following.scope=next.duplicate()
			transfers.append({"previous":previous,"next":following,"samePhysical":true})
	var result: Dictionary=services.set_scope(next,transfers,{"continuousHistory":true})
	if result.ready:current_scope=next
	else:note(result)
func receive(message: Dictionary)->void:
	diagnostics.protocolFrames=mini(int(diagnostics.protocolFrames)+1,9007199254740991)
	if not ready:return
	var event: Variant=message.get("event")
	if not event is Dictionary:return
	if event.get("type")=="begin":
		var attached: Dictionary=services.attach_connection(message.get("connection"))
		if not attached.ready:note(attached);return
		connection=int(message.connection);module_present=false;area_present=false
	if message.get("connection")!=connection:return
	if message.get("scope") is Dictionary:set_scope(message.scope)
	delivering=event
	var result: Dictionary=services.receive_clock(message)
	delivering={}
	if result.get("ready",false):
		if event.get("type")=="module-info":module_present=true
		elif event.get("type")=="client-area":area_present=int(event.get("areaId",INVALID))!=INVALID
	else:note(result)
func accepted_lifecycle(event: Dictionary)->Dictionary:
	# Only an admitted local lifecycle receipt reaches this callback. Server
	# message fields and ordinary snapshot rows confer no constructor proof.
	if delivering.get("type")!="accepted-lifecycle" or delivering.get("version")!=2:return {"ready":false}
	for key in ["version","lifecycleEpoch","transaction","operation","recordIndex","objectId","objectType","ownership","deletionFlag","areaId","physicalToken","ownerAbsentCertified","constructionCertified","aiRegistrationCertified","constructionHistoryComplete"]:
		if not event.has(key) or not delivering.has(key) or event[key]!=delivering[key]:return {"ready":false}
	var physical_ref:={"scope":current_scope.duplicate(),"id":event.objectId,"nativeLifetime":null,"knownLifetime":null,"physicalToken":event.physicalToken,"lifecycleEpoch":event.lifecycleEpoch}
	if event.operation=="create" and event.ownership=="new" and event.constructionCertified and event.aiRegistrationCertified and event.constructionHistoryComplete and event.physicalToken!=null:
		return {"ready":true,"action":"constructed","reference":physical_ref,"fact":{"externalType5Construction":true,"typedAbsent":true,"externalHistoryComplete":true,"registeredBeforeAi":true}}
	if event.operation=="create" and event.ownership=="retained" and event.physicalToken!=null:
		return {"ready":true,"action":"retained","reference":physical_ref,"fact":{"samePhysical":true}}
	# Dropping a clock binding is not native hard destruction. An ambiguous A
	# must not make a former token queryable or transfer it to a different area.
	services.retire_current_reference(event.objectId,current_scope,{"acceptedLifecycleRetirement":true})
	return {"ready":true,"action":"remove" if event.operation=="remove" else "unknown"}
func post_receive()->void:
	if not ready:return
	drain_direct_clock()
	note(services.finish_ai(current_frame,{"module":module_present,"area":area_present,"completePass":true}))
	bind_text_consumers()
func bind_text_consumers()->void:
	var ui=client.gameplay_ui
	if not is_instance_valid(ui) or bound_ui!=null and bound_ui.get_ref()==ui:return
	if not is_instance_valid(ui.overhead) or not is_instance_valid(ui.script_floating) or not is_instance_valid(ui.overhead_popup_registry):return
	ui.overhead.gui_delta_reader=gui_delta
	ui.script_floating.gui_delta_reader=gui_delta
	ui.overhead_popup_registry.gui_delta_reader=gui_delta
	ui.script_floating_object_delta_query=object_delta
	bound_ui=weakref(ui)
func gui_delta()->Dictionary:
	return services.gui_delta(current_frame) if ready else {"ready":false}
func world_timer()->Variant:
	return services.world_timer() if ready and services!=null else null
func reveal_timing()->Dictionary:
	# Original fade reads the existing primary world snapshot. No resample,
	# GUI delta, renderer frame delta or replacement wall-clock is introduced.
	return services.reveal_timing(current_frame) if ready else {"ready":false,"available":false}
func clock_object_id(id: int)->int:
	return id&0xffffffff if id==INVALID else (id|0x80000000)&0xffffffff
func current_clock_owner(id: int,object: Dictionary)->Dictionary:
	if direct_owner==null:
		var prior: Variant=object.get("nativeClockOwner")
		if not prior is Dictionary or prior.get("version")!=1 or prior.get("source")!="native-client-clock-owner-v1" or prior.get("connection")!=connection or prior.get("physicalCurrent")!=true or not prior.get("physicalToken") is String:return {}
		return prior
	var owner:=current_direct_owner(connection)
	var world: Variant=direct_world.get_ref()
	if owner==null or world==null or owner.world_state!=world or direct_epoch_invalid or current_scope!=[connection,owner.area_generation,world.area_id]:return {}
	var raw_id:=clock_object_id(id)
	var canonical: Dictionary=world.registry.get(raw_id,{})
	if canonical.is_empty() or Lifetime.token(object)!=Lifetime.token(canonical):return {}
	var fact: Variant=world.clock_owner_transport(raw_id)
	if not fact is Dictionary or fact.get("epoch")!=direct_epoch or fact.get("connection")!=connection or fact.get("physicalCurrent")!=true or not fact.get("physicalToken") is String:return {}
	return fact
func object_delta(id: int,witness: Array,where: Array)->Variant:
	if not ready or where!=current_scope or not is_instance_valid(client.gameplay_ui):return null
	var row: Dictionary=client.gameplay_ui.text.objects.get(id,{})
	var context:=Scope.context(client.native_text_connection(),client.epoch,client.gameplay_ui.area_id)
	if not Anchor.current(row,witness,where,context):return null
	var owner:=current_clock_owner(id,row)
	if owner.is_empty():return null
	return services.queue_delta_for_physical(clock_object_id(id) if direct_owner!=null else id,owner.physicalToken,where,current_frame)

func presentation_now(id: int,object: Dictionary)->Dictionary:
	# The former ClientPausePresentation.now uses milliseconds for its initial
	# scheduler stamp and for every selected per-object timer delta. The native
	# clock service already performs that selected subtraction after AI.
	if not ready or current_scope.size()!=3 or current_frame<0 or int(object.get("objectType",0))!=5:
		return {"ready":false,"reason":"Current creature clock owner is unavailable."}
	var owner:=current_clock_owner(id,object)
	if owner.is_empty():
		return {"ready":false,"reason":"Current physical creature clock token is unavailable."}
	if object.has("areaId") and int(object.areaId)!=int(current_scope[2]):
		return {"ready":false,"reason":"Creature clock area does not match the current scope."}
	var client_id:=clock_object_id(id)
	var token: String=owner.physicalToken
	var stamp: Dictionary=presentation_stamps.get(client_id,{})
	if stamp.is_empty() or stamp.get("token")!=token or stamp.get("connection")!=connection:
		var initial: int=Time.get_ticks_msec()
		presentation_stamps[client_id]={"token":token,"connection":connection,"frame":current_frame,"timeMs":initial}
		return {"ready":true,"timeMs":initial,"initial":true}
	if int(stamp.frame)==current_frame:return {"ready":true,"timeMs":int(stamp.timeMs),"cached":true}
	var elapsed: Variant=services.queue_delta_for_physical(client_id,token,current_scope,current_frame)
	stamp.frame=current_frame
	if elapsed==null:
		presentation_stamps[client_id]=stamp
		return {"ready":true,"timeMs":int(stamp.timeMs),"frozen":true,"reason":"Selected creature elapsed output is unavailable."}
	stamp.timeMs=int(stamp.timeMs)+int(elapsed)
	presentation_stamps[client_id]=stamp
	return {"ready":true,"timeMs":int(stamp.timeMs)}
func retire_direct_owner()->void:
	var owner: Variant=direct_owner.get_ref() if direct_owner!=null else null
	# Fence any captured callback before disconnecting it, as on the old host.
	direct_owner=null;direct_world=null;direct_epoch=-1;direct_epoch_invalid=false;direct_transaction=0;direct_controlled_id=INVALID
	direct_queue=[];direct_pause_ids=0;direct_gap_reason="";direct_pending_gap=""
	if is_instance_valid(owner):
		for signal_name in direct_listeners:
			if owner.is_connected(signal_name,direct_listeners[signal_name]):owner.disconnect(signal_name,direct_listeners[signal_name])
	direct_listeners.clear()
func cleanup_connection()->void:
	retire_direct_owner()
	if ready and connection>=0:
		var result: Dictionary=services.cleanup_connection()
		if not result.ready:note(result);return
	connection=-1;current_scope=[];module_present=false;area_present=false;delivering={};bound_ui=null;presentation_stamps.clear()
	diagnostics.directOwnersReady=false
	diagnostics.directControlledIdKnown=false
func state_view(full: bool=false)->Dictionary:
	var result: Dictionary=diagnostics.duplicate(true)
	result.connection=connection;result.scope=current_scope.duplicate();result.frame=current_frame
	if full and services!=null:result.services=services.state_view()
	if full and source!=null:result.source=source.state_view()
	return result
func close()->void:
	cleanup_connection()
	if services!=null:
		diagnostics.finalServices=services.state_view()
		diagnostics.processRelease=services.release_process({"processExiting":true})
	ready=false;diagnostics.ready=false;bound_ui=null;client=null;source=null;services=null;delivering={};current_scope=[];connection=-1;presentation_stamps.clear()
