extends RefCounted
# Session integration only. Protocol and physical-clock state stay with their
# existing owners; this adapter keeps no world rows, models or per-frame scans.
const Services=preload("res://systems/native_data/client_clock_services.gd")
const Source=preload("res://systems/native_data/native_clock_source.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Anchor=preload("res://systems/native_data/script_floating_anchor.gd")
const INVALID:=0x7f000000
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
var diagnostics:={"enabled":false,"ready":false,"protocolFrames":0,"unavailable":0,"lastReason":"","phase":"native-direct-real-candidate"}
func configure(owner)->void:
	client=owner
	# Kept opt-in until actual pause lower-provider and live visual acceptance.
	enabled=client.args.get("native-overhead-clocks","")=="true" and client.args.get("offline-replay","")!="true"
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
	if not ready:return
	current_frame=frame;note(services.begin_frame(frame))
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
	# This callback runs only during the synchronously admitted local protocol
	# envelope, after SessionWorld's connection fence. Server DTO fields never
	# call it directly or supply a constructor flag through ordinary UI data.
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
func reveal_timing()->Dictionary:
	# Original fade reads the existing primary world snapshot. No resample,
	# GUI delta, renderer frame delta or replacement wall-clock is introduced.
	return services.reveal_timing(current_frame) if ready else {"ready":false,"available":false}
func object_delta(id: int,witness: Array,where: Array)->Variant:
	if not ready or where!=current_scope or not is_instance_valid(client.gameplay_ui):return null
	var row: Dictionary=client.gameplay_ui.text.objects.get(id,{})
	var context:=Scope.context(client.native_text_connection(),client.epoch,client.gameplay_ui.area_id)
	if not Anchor.current(row,witness,where,context):return null
	var owner: Variant=row.get("nativeClockOwner")
	if not owner is Dictionary or owner.get("version")!=1 or owner.get("source")!="native-client-clock-owner-v1" or owner.get("connection")!=connection or owner.get("physicalCurrent")!=true or not owner.get("physicalToken") is String:return null
	return services.queue_delta_for_physical(id,owner.physicalToken,where,current_frame)
func cleanup_connection()->void:
	if not ready or connection<0:return
	var result: Dictionary=services.cleanup_connection()
	if not result.ready:note(result);return
	connection=-1;current_scope=[];module_present=false;area_present=false;delivering={};bound_ui=null
func state_view(full: bool=false)->Dictionary:
	var result: Dictionary=diagnostics.duplicate(true)
	result.connection=connection;result.scope=current_scope.duplicate();result.frame=current_frame
	if full and services!=null:result.services=services.state_view()
	if full and source!=null:result.source=source.state_view()
	return result
func close()->void:
	if services!=null:
		cleanup_connection()
		diagnostics.finalServices=services.state_view()
		diagnostics.processRelease=services.release_process({"processExiting":true})
	ready=false;diagnostics.ready=false;bound_ui=null;client=null;source=null;services=null;delivering={};current_scope=[];connection=-1
