extends RefCounted
# Explicit process-service composition. No runtime/transport/provider inference.
const WorldClock=preload("res://systems/native_data/world_timer.gd")
const PauseOwner=preload("res://systems/native_data/client_pause_state.gd")
const ObjectClocks=preload("res://systems/native_data/client_object_clocks.gd")
const LOWER=["object","asObject","scene","sceneVirtual","resetObjectTimes","pauseText","audio"]
const GUI_LOWER=["guiActive","guiBlocked","guiSetFlags","guiClearFlags"]
var _constructed:=false
var _construction_known:=false
var _clock_complete:=false
var _transport_complete:=false
var _lifetime_complete:=false
var _connection: int=-1
var _last_connection: int=-1
var _serial: int=0
var _frame: int=-1
var _phase:="idle"
var _scope: Array=[]
var _timers: Dictionary={}
var _lower: Dictionary={}
var _pause
var _objects
var _limits: Dictionary={}
var _resets: Array=[]
var _order: int=0
var _failure:=""
var _frame_failure:=""
var _gui_result: Dictionary={}
var _physical_refs: Dictionary={}
var _unavailable_ids: Dictionary={}
var _cleanup_origin_phase:=""
var _released:=false
var _release_diagnostic: Dictionary={}
static func unavailable(reason: String,partial: bool=false)->Dictionary:return {"ready":false,"partial":partial,"reason":reason}
func _taint(reason: String)->void:
	_clock_complete=false
	if _failure.is_empty():_failure=reason
func _failed(reason: String)->void:
	if _frame_failure.is_empty():_frame_failure=reason
	_taint(reason)
func _clock_call(clock,method: String,args: Array=[])->Dictionary:
	var result: Dictionary=clock.callv(method,args)
	if not result.get("ready",false):_failed("Clock operation unavailable: "+method)
	return result
func _on_pause(clock)->void:_clock_call(clock,"pause")
func _on_unpause(clock)->void:_clock_call(clock,"unpause")
func _on_snapshot(clock)->void:_clock_call(clock,"snapshot")
func _on_sync(clock)->void:_clock_call(clock,"synchronize_previous")
func _on_reset(clock,source)->void:_clock_call(clock,"reset_from",[source])
func _on_time(clock)->Dictionary:return _clock_call(clock,"time")
func _invoke(name: String,args: Array=[])->Variant:
	var provider: Variant=_lower.get(name)
	if not provider is Callable or not provider.is_valid():_failed("Native lower provider is unavailable: "+name);return null
	var result: Variant=provider.callv(args)
	if result is Dictionary and result.has("ready") and result.ready==false:_failed("Native lower provider returned unavailable: "+name)
	return result
func _on_object(id: int)->Variant:
	var value: Variant=_invoke("object",[id])
	return null if value is Dictionary and value.get("ready")==false else value
func _on_as_object(object: Variant)->Variant:
	var value: Variant=_invoke("asObject",[object])
	return null if value is Dictionary and value.get("ready")==false else value
func _on_scene(object: Variant)->Variant:
	var value: Variant=_invoke("scene",[object])
	return null if value is Dictionary and value.get("ready")==false else value
func _on_scene_virtual(scene: Variant,offset: int)->void:_invoke("sceneVirtual",[scene,offset])
func _on_text(id: int)->void:_invoke("pauseText",[id])
func _on_audio(value: bool)->void:_invoke("audio",[value])
func _on_gui_active(gui: Variant)->int:
	var result: Variant=_invoke("guiActive",[gui])
	if not WorldClock.integer(result):_failed("GUI active result is unknown.");return 0
	return WorldClock.i32(result)
func _on_gui_blocked(gui: Variant,value: int)->void:_invoke("guiBlocked",[gui,value])
func _on_gui_set(gui: Variant,bits: int)->void:_invoke("guiSetFlags",[gui,bits])
func _on_gui_clear(gui: Variant,bits: int)->void:_invoke("guiClearFlags",[gui,bits])
func _on_dispose(incoming: Dictionary)->void:
	# This owner allocated the detached incoming list, so its disposal is known.
	incoming.ids=[];incoming.capacity=0;incoming.disposed=true
func _on_object_reset(object: Variant,day: int,time: int)->void:
	# Lower dispatch must certify creature virtual807680 or an actual base no-op.
	# It must not return a proxy merely because its numeric ID is in the list.
	var dispatched: Variant=_invoke("resetObjectTimes",[object,day,time])
	if not dispatched is Dictionary or dispatched.get("ready")!=true:
		_failed("Native object reset dispatch is unsupported.");return
	if dispatched.get("baseNoop")==true:return
	var ref_value: Variant=dispatched.get("creatureReference")
	if dispatched.get("unboundCreature")==true:
		_block_object(object.id,"Native reset physical reference is unknown.");return
	if not ref_value is Dictionary:_failed("Native reset dispatch kind/reference is unsupported.");return
	if not _stage_reset(ref_value,{"day":day,"time":time}).ready:_block_object(object.id,"Native creature reset reference is not admitted.")
func _callbacks()->Dictionary:
	return {"pause":_on_pause,"unpause":_on_unpause,"snapshot":_on_snapshot,"syncPrevious":_on_sync,"reset":_on_reset,"time":_on_time,"object":_on_object,"asObject":_on_as_object,"scene":_on_scene,"sceneVirtual":_on_scene_virtual,"resetObjectTimes":_on_object_reset,"pauseText":_on_text,"audio":_on_audio,"disposeIncoming":_on_dispose,"guiActive":_on_gui_active,"guiBlocked":_on_gui_blocked,"guiSetFlags":_on_gui_set,"guiClearFlags":_on_gui_clear}
func construct_process(absolute_u64_reader: Callable,owner_facts: Dictionary,providers: Dictionary={},resource_limits: Dictionary={})->Dictionary:
	if _constructed or _released:return unavailable("Process services already exist or have finally exited; connection/area must not reconstruct them.")
	if owner_facts.get("processConstructionKnown")!=true or not absolute_u64_reader.is_valid():return unavailable("Explicit native process-service construction/provider is unavailable.")
	_lower=providers.duplicate();_limits=resource_limits.duplicate(true)
	for key in ["world","timer1","timer2"]:
		var clock:=WorldClock.new();var result:=clock.initialize(absolute_u64_reader)
		if not result.ready:
			clock.close()
			for prior in _timers.values():prior.close()
			_timers.clear();return unavailable("Process timer construction could not obtain all three absolute samples.",true)
		_timers[key]=clock
	_pause=PauseOwner.new()
	var initial:={"flags":0,"exclusions":{"known":true,"ids":[]}}
	for key in ["gui","profileMode","controlledId"]:
		if owner_facts.has(key):initial[key]=owner_facts[key]
	_pause.configure(initial,_timers,_callbacks())
	_objects=ObjectClocks.new();_constructed=true;_construction_known=true;_clock_complete=true;_failure="";_frame_failure=""
	_connection=-1;_last_connection=-1;_serial=0;_frame=-1;_phase="idle";_scope=[];_resets=[];_transport_complete=false;_lifetime_complete=false;_physical_refs={};_unavailable_ids={};_cleanup_origin_phase=""
	return {"ready":true,"processConstructed":true,"transitionsReady":_providers_ready()}
func publish_owner_facts(value: Dictionary)->Dictionary:
	if not _constructed:return unavailable("Process owner is absent.")
	for key in ["profileMode","controlledId"]:
		if value.has(key) and not WorldClock.integer(value[key]):return unavailable("Native owner scalar is unknown: "+key)
	if value.has("gui"):
		var gui: Variant=value.gui
		if not gui is Dictionary or gui.get("known")!=true or not gui.has("value"):return unavailable("GUI owner certainty is unavailable.")
		_pause.gui_known=true;_pause.gui=gui.value
	if value.has("profileMode"):_pause.profile_mode=WorldClock.i32(value.profileMode)
	if value.has("controlledId"):_pause.controlled_id=WorldClock.u32(value.controlledId)
	return {"ready":true,"transitionsReady":_providers_ready()}
func _providers_ready()->bool:
	if not _constructed or not _pause.gui_known or _pause.profile_mode==null or _pause.controlled_id==null:return false
	var required: Array=LOWER.duplicate()
	if _pause.gui!=null:required.append_array(GUI_LOWER)
	for name in required:
		var provider: Variant=_lower.get(name)
		if not provider is Callable or not provider.is_valid():return false
	return true
func attach_connection(value: Variant)->Dictionary:
	if not _constructed or not ObjectClocks.natural(value) or value<=_last_connection or _connection>=0 or _phase=="cleanup-partial":return unavailable("Fresh transport attach is unavailable; cleanup must precede replacement.")
	_connection=int(value);_last_connection=_connection;_serial=0;_transport_complete=false;_lifetime_complete=false
	return {"ready":true,"timersReconstructed":false}
func set_scope(value: Array,transfers: Array=[],fact: Dictionary={})->Dictionary:
	var next:=ObjectClocks.normalized_scope(value)
	if not _constructed or _connection<0 or next.is_empty() or next[0]!=_connection:return unavailable("Accepted native connection/scope is unavailable.")
	var result: Dictionary
	if _scope.is_empty():result=_objects.configure(next,_limits)
	elif next==_scope:return {"ready":true,"changed":false}
	else:result=_objects.rebind_scope(next,transfers,fact)
	if result.ready:
		if not _scope.is_empty():
			var admitted: Dictionary={};var unavailable_ids: Dictionary={};var moves: Dictionary={}
			for transfer in transfers:
				var id: int=transfer.next.id
				var next_ref:=ObjectClocks.normalized_reference(transfer.next,next)
				moves[id]={"previous":ObjectClocks.normalized_reference(transfer.previous,_scope),"next":next_ref}
				if _physical_refs.has(id):admitted[id]=next_ref
				if _unavailable_ids.has(id):unavailable_ids[id]=_unavailable_ids[id]
			# A same-batch area publication changes only the admitted reference.
			# Preserve the captured pair/frame/order; never re-run its provider.
			var remapped: Array=[]
			for reset in _resets:
				var move: Dictionary=moves.get(reset.reference.id,{})
				if not move.is_empty() and reset.reference==move.previous:
					var receipt: Dictionary=reset.duplicate(true);receipt.reference=move.next.duplicate(true);remapped.append(receipt)
			_resets=remapped
			_physical_refs=admitted;_unavailable_ids=unavailable_ids
		_scope=next
	return result
func _block_object(id_value: Variant,reason: String)->void:
	if ObjectClocks.natural(id_value,WorldClock.U32) and _physical_refs.has(int(id_value)):_unavailable_ids[int(id_value)]=reason
static func _lifecycle_fields(value: Dictionary)->Dictionary:
	if value.get("version")!=2 or value.get("operation") not in ["create","remove"] or value.get("ownership") not in ["new","retained","unknown"] or value.get("objectType")!=5:return {}
	var result:={"type":"accepted-lifecycle","version":2,"operation":value.operation,"ownership":value.ownership,"objectType":5}
	for key in ["lifecycleEpoch","transaction","recordIndex","objectId"]:
		if not ObjectClocks.natural(value.get(key),WorldClock.U32 if key=="objectId" else ObjectClocks.SAFE) or key in ["lifecycleEpoch","transaction"] and value[key]<1:return {}
		result[key]=int(value[key])
	for key in ["ownerAbsentCertified","constructionCertified","aiRegistrationCertified","constructionHistoryComplete"]:
		if not value.get(key) is bool:return {}
		result[key]=value[key]
	for key in ["areaId","deletionFlag","physicalToken"]:
		if not value.has(key):return {}
		var field: Variant=value[key]
		if field!=null:
			if key=="physicalToken":
				if not field is String or ObjectClocks.token(field)==null:return {}
			elif not ObjectClocks.natural(field,1 if key=="deletionFlag" else WorldClock.U32) or field is bool:return {}
		result[key]=field
	for key in ["nativeLifetime","knownLifetimeBefore","knownLifetimeAfter"]:
		if value.has(key):
			if value[key]!=null and (not ObjectClocks.natural(value[key]) or value[key]<1):return {}
			result[key]=value[key]
	return result
func begin_frame(frame_value: Variant)->Dictionary:
	if not _constructed or not ObjectClocks.natural(frame_value) or frame_value<=_frame or _phase=="receive":return unavailable("Native frame order/owner is unavailable.")
	_frame=int(frame_value);_phase="receive";_order=0;_resets=[];_gui_result={};_frame_failure=""
	var prefixed: Dictionary=_pause.snapshot_before_receive()
	if not prefixed.ready or not _frame_failure.is_empty():_taint("Native frame snapshot prefix is unavailable.");return unavailable(_failure,true)
	return {"ready":true,"prefixSlots":prefixed.slots.duplicate()}
func _apply_pause(mask: int,value: int,incoming: Variant)->Dictionary:
	var noop: bool=(_pause.flags_known and (_pause.flags&mask)==WorldClock.u32(value)) or mask==0 and value==0
	if not noop and not _providers_ready():_taint("Native pause lower providers/owners are unsupported.");return unavailable(_failure)
	var result: Dictionary=_pause.apply(mask,value,incoming)
	if not result.ready or not _frame_failure.is_empty():_taint("Native pause transition is partial or unavailable.");return unavailable(_failure,true)
	if incoming is Dictionary and incoming.get("disposed")!=true:result.unconsumedIncoming=incoming.duplicate(true)
	return result
func receive_clock(dto: Dictionary)->Dictionary:
	if not _constructed or _connection<0 or _phase!="receive":return unavailable("Protocol facts require the open native receive phase.")
	if dto.get("connection")!=_connection:return unavailable("Old connection clock fact ignored.")
	if dto.get("kind")!="native-clock-protocol" or dto.get("version")!=1 or not ObjectClocks.natural(dto.get("serial")) or dto.serial!=_serial+1:
		_transport_complete=false;_lifetime_complete=false;_taint("Clock protocol serial/schema gap.");return unavailable(_failure)
	_serial=int(dto.serial)
	var history: Variant=dto.get("history");var event: Variant=dto.get("event")
	if not history is Dictionary or not history.get("complete") is bool or not event is Dictionary:
		_transport_complete=false;_lifetime_complete=false;_taint("Clock protocol history/event is unknown.");return unavailable(_failure)
	if history.complete!=true:
		_transport_complete=false;_lifetime_complete=false;_taint("Clock protocol history is incomplete.")
	var type: Variant=event.get("type")
	if type=="begin":
		if _serial!=1:_taint("Clock begin is out of order.");return unavailable(_failure)
		_transport_complete=history.complete==true
		_lifetime_complete=event.get("constructionHistoryComplete")==true
		return {"ready":true,"clockHistoryComplete":_clock_complete,"processReconstructed":false}
	if _serial==1:_transport_complete=false;_taint("Native clock begin was not received.")
	if type=="history-gap":_transport_complete=false;_lifetime_complete=false;_taint("Explicit native clock history gap.");return unavailable(_failure)
	if type=="module-info":
		if not ObjectClocks.natural(event.get("minutesPerHour"),255):_taint("Module rate BYTE is unavailable.");return unavailable(_failure)
		return _clock_call(_timers.world,"set_minutes_per_hour",[event.minutesPerHour])
	if type in ["module-time","client-area"]:
		if type=="module-time" and not ObjectClocks.natural(event.get("mask"),255) or type=="client-area" and not ObjectClocks.natural(event.get("areaId"),WorldClock.U32):_taint("Native calendar/area boundary is malformed.");return unavailable(_failure)
		return {"ready":true,"clockReset":false}
	if type=="object-control":
		if not ObjectClocks.natural(event.get("playerId"),WorldClock.U32) or not ObjectClocks.natural(event.get("objectId"),WorldClock.U32) or not ObjectClocks.natural(event.get("sourceMajor"),255) or not ObjectClocks.natural(event.get("sourceMinor"),255):_taint("Native object-control IDs/source pair are unavailable.");return unavailable(_failure)
		var major: int=int(event.sourceMajor);var minor: int=int(event.sourceMinor)
		if major==5 and minor==2:
			_pause.controlled_id=int(event.objectId);return {"ready":true,"localControlChanged":true}
		if major==14 and minor==14:return {"ready":true,"localControlChanged":false}
		_taint("Unsupported native object-control source pair.");return unavailable(_failure)
	if type=="module-pause-state":
		if not ObjectClocks.natural(event.get("mask"),3) or not ObjectClocks.natural(event.get("value"),1) or not event.get("exclusionIds") is Array:_taint("Native pause protocol operands are invalid.");return unavailable(_failure)
		for id in event.exclusionIds:
			if not ObjectClocks.natural(id,WorldClock.U32):_taint("Native pause exclusion ID is invalid.");return unavailable(_failure)
		var incoming:=PauseOwner.owned_incoming(event.exclusionIds)
		return _apply_pause(int(event.mask),int(event.value),incoming)
	if type=="accepted-lifecycle":
		if event.has("deletionFlag") and event.deletionFlag!=null and (not ObjectClocks.natural(event.deletionFlag,1) or event.deletionFlag is bool):_lifetime_complete=false;return unavailable("Native deletion flag must retain numeric 0/1 or null.")
		if event.get("version")!=2:
			_block_object(event.get("objectId"),"Compatibility lifecycle metadata cannot certify construction.")
			return unavailable("Versionless lifecycle facts remain physically unproven.")
		var lifecycle:=_lifecycle_fields(event)
		if lifecycle.is_empty():_block_object(event.get("objectId"),"Malformed lifecycle certification metadata.");return unavailable("Version2 lifecycle schema is unavailable.")
		# Epoch/physical/certification admission belongs to the private Root
		# lifecycle reader, never to proxy existence or this protocol DTO.
		var reader: Variant=_lower.get("acceptedLifecycle")
		if not reader is Callable or not reader.is_valid():_lifetime_complete=false;_block_object(event.get("objectId"),"Private lifecycle reader is unbound.");return unavailable("Private native lifecycle reader is unbound.")
		var accepted: Variant=reader.call(lifecycle)
		if not accepted is Dictionary or accepted.get("ready")!=true:_lifetime_complete=false;_block_object(event.get("objectId"),"Private lifecycle certification is unknown.");return unavailable("Private native lifecycle certification is unavailable.")
		if accepted.get("action")=="constructed":
			# ownerAbsentCertified identifies a known-absent D no-op, not fresh A.
			if lifecycle.ownership!="new" or not lifecycle.constructionCertified or not lifecycle.aiRegistrationCertified or not lifecycle.constructionHistoryComplete or lifecycle.physicalToken==null:return unavailable("Fresh physical construction is not certified.")
			var certified: Variant=accepted.get("reference")
			if not certified is Dictionary or certified.get("id")!=lifecycle.objectId or certified.get("physicalToken")!=lifecycle.physicalToken or certified.get("lifecycleEpoch")!=lifecycle.lifecycleEpoch:return unavailable("Private constructor reference does not match its physical certificate.")
			return construct_creature(accepted.get("reference",{}),accepted.get("fact",{}))
		if accepted.get("action")=="retained":return retain_creature(accepted.get("reference",{}),accepted.get("fact",{}))
		if accepted.get("action")=="remove":
			# A numeric deletionFlag 0/1 is not native physical destruction.
			return {"ready":true,"physicalDestructionInferred":false}
		if accepted.get("action")=="unknown":
			_lifetime_complete=false;_block_object(event.get("objectId"),"Physical construction/registration remains unknown.")
			return {"ready":true,"objectClockReady":false,"physicalConstructionKnown":false}
		_lifetime_complete=false;_block_object(event.get("objectId"),"Unsupported lifecycle action.");return unavailable("Unsupported native lifecycle action.")
	_taint("Unsupported clock protocol event.");return unavailable(_failure)
func construct_creature(value: Dictionary,fact: Dictionary)->Dictionary:
	if not _constructed or _phase!="receive" or _scope.is_empty() or fact.get("externalType5Construction")!=true or fact.get("typedAbsent")!=true or fact.get("externalHistoryComplete")!=true or fact.get("registeredBeforeAi")!=true:return unavailable("Explicit fresh external type5 construction/registration fact is unavailable.")
	var normalized:=ObjectClocks.normalized_reference(value,_scope)
	if normalized.is_empty() or (int(normalized.id)&0x80000000)==0 or not normalized.physicalToken is String:return unavailable("Certified external creature reference is unavailable.")
	# Internal physical clocks precede coalesced raw/UI lifetime publication.
	normalized.nativeLifetime=null;normalized.knownLifetime=null
	var base: Dictionary=_clock_call(_timers.world,"time")
	if not base.ready:return base
	_order+=1;var born:={"frame":_frame,"phase":"before-ai","order":_order,"kind":"birth","pair":{"day":base.day,"time":base.time}}
	_order+=1
	var bound: Dictionary=_objects.bind(normalized,{"registeredBeforeAi":true,"registration":{"frame":_frame,"phase":"before-ai","order":_order},"stamp":born})
	if bound.ready:_physical_refs[normalized.id]=normalized.duplicate(true);_unavailable_ids.erase(normalized.id)
	return bound
func retain_creature(value: Dictionary,fact: Dictionary)->Dictionary:
	if not _constructed or fact.get("samePhysical")!=true:return unavailable("Explicit retained physical-owner fact is unavailable.")
	var physical:=_lookup_physical(value.get("id"),value.get("physicalToken"),value.get("scope",[]))
	if physical.is_empty() or value.has("lifecycleEpoch") and value.lifecycleEpoch!=physical.get("lifecycleEpoch"):return unavailable("Retained physical token/epoch/scope is unavailable.")
	var retained: Dictionary=_objects.binding_view(physical)
	return {"ready":true,"birth":false} if not retained.is_empty() else unavailable("Retained lifetime is not currently bound; trusted bulk scope transfer is required.")
func retire_reference(value: Dictionary,fact: Dictionary)->Dictionary:
	if not _constructed or fact.get("referenceRetired")!=true:return unavailable("Explicit scoped reference retirement is unavailable.")
	var result: Dictionary=_objects.retire(value)
	if result.ready:_physical_refs.erase(value.id);_unavailable_ids.erase(value.id)
	return result
func retire_current_reference(id_value: Variant,where: Array,fact: Dictionary)->Dictionary:
	if not _constructed or fact.get("acceptedLifecycleRetirement")!=true or not ObjectClocks.natural(id_value,WorldClock.U32) or ObjectClocks.normalized_scope(where)!=_scope:return unavailable("Trusted current accepted-lifecycle retirement is unavailable.")
	# O(1): only this owner's current thin reference is inspected. The caller
	# needs no token/row mirror and null-token unknown A never invents a token.
	var current_ref: Dictionary=_physical_refs.get(int(id_value),{})
	if current_ref.is_empty():return {"ready":true,"retired":false,"physicalDestructionInferred":false}
	var result:=retire_reference(current_ref,{"referenceRetired":true})
	if result.ready:result.retired=true
	return result
func _lookup_physical(id_value: Variant,physical_token: Variant,where: Variant)->Dictionary:
	if not _constructed or not ObjectClocks.natural(id_value,WorldClock.U32) or ObjectClocks.normalized_scope(where)!=_scope:return {}
	var found: Dictionary=_physical_refs.get(int(id_value),{})
	if found.is_empty() or found.physicalToken!=physical_token or typeof(found.physicalToken)!=typeof(physical_token):return {}
	return found
func area_transfer_references(where: Array,fact: Dictionary)->Dictionary:
	if not _constructed or fact.get("areaBoundary")!=true or ObjectClocks.normalized_scope(where)!=_scope:return unavailable("Thin reference enumeration requires an explicit current area boundary.")
	return {"ready":true,"references":_physical_refs.values().duplicate(true)}
func _stage_reset(value: Dictionary,pair_value: Dictionary)->Dictionary:
	if _phase not in ["receive","cleanup-before-ai","cleanup-after-ai"] or _scope.is_empty():return unavailable("Reset was not captured in a native receive/cleanup phase.")
	var ref_value:=_lookup_physical(value.get("id"),value.get("physicalToken"),value.get("scope",[]));var sampled:=ObjectClocks.pair(pair_value)
	if value.has("lifecycleEpoch") and value.lifecycleEpoch!=ref_value.get("lifecycleEpoch"):return unavailable("Native reset physical epoch is stale.")
	if ref_value.is_empty() or sampled.is_empty() or _objects.binding_view(ref_value).is_empty():return unavailable("Current native reset binding is unavailable.")
	_order+=1
	var stamp_fact:={"frame":_frame,"phase":"after-ai" if _phase=="cleanup-after-ai" else "before-ai","order":_order,"nativeReset":true}
	if _phase=="cleanup-after-ai":
		var reset_result: Dictionary=_objects.reset_stamp(ref_value,sampled,stamp_fact)
		if reset_result.ready:_unavailable_ids.erase(ref_value.id)
		return reset_result
	_resets.append({"reference":ref_value,"pair":sampled,"fact":stamp_fact})
	_unavailable_ids.erase(ref_value.id)
	return {"ready":true}
func native_reset(value: Dictionary,pair_value: Dictionary,fact: Dictionary)->Dictionary:
	if fact.get("nativeCreatureReset")!=true:return unavailable("Actual native creature reset dispatch is unknown.")
	return _stage_reset(value,pair_value)
func finish_ai(frame_value: Variant,eligibility: Dictionary)->Dictionary:
	if not _constructed or _phase!="receive" or frame_value!=_frame:return unavailable("No matching receive/AI frame is open.")
	var data:={"clockStreamKnown":_clock_complete and _transport_complete,"selector":{},"eligibility":{}}
	for key in ["world","timer1","timer2"]:
		var sampled: Dictionary=_clock_call(_timers[key],"time")
		if not sampled.ready:data.clockStreamKnown=false
		data[key]={"day":sampled.get("day"),"time":sampled.get("time")}
	data.dayLength=_timers.world.day_length
	var selector: Dictionary=_pause.state_view();data.selector={"flags":selector.flags,"exclusions":selector.exclusions}
	for key in ["module","area","completePass"]:
		if not eligibility.get(key) is bool:_phase="complete";return unavailable("Explicit conceptual AI eligibility/pass owner is unknown.")
		data.eligibility[key]=eligibility[key]
	var object_result: Dictionary=unavailable("No admitted area scope for object AI.")
	if not _scope.is_empty():
		object_result=_objects.begin_frame(_frame,data)
		if object_result.ready:
			for reset in _resets:
				# Logical retirement/reconstruction may occur after capture in this
				# receive batch. Old reset receipts never target its replacement.
				if _physical_refs.get(reset.reference.id,{})!=reset.reference:continue
				var reset_result: Dictionary=_objects.reset_stamp(reset.reference,reset.pair,reset.fact)
				if not reset_result.ready:_lifetime_complete=false;_block_object(reset.reference.id,"Captured native reset could not be replayed.")
		var completed: Dictionary=_objects.complete_frame()
		if object_result.ready:object_result=completed
	_resets=[];_phase="complete"
	var difference: Dictionary=_timers.timer2.snapshot_difference()
	_gui_result=WorldClock.frame_seconds_from_difference(difference.microseconds) if difference.get("ready",false) else unavailable("GUI T2 difference is unknown.")
	if not _clock_complete:_gui_result=unavailable("Process clock history is incomplete.")
	return {"ready":_gui_result.get("ready",false),"objectsReady":object_result.get("ready",false),"objectResult":object_result,"guiReady":_gui_result.get("ready",false)}
func object_delta(value: Dictionary,frame_value: Variant)->Dictionary:
	if not _constructed or _phase!="complete" or frame_value!=_frame or not _clock_complete or not _transport_complete:return unavailable("Current object clock scope/history/phase is unavailable.")
	if _unavailable_ids.has(value.get("id")):return unavailable(_unavailable_ids[value.id])
	return _objects.sample(value,frame_value)
func queue_delta_ms(value: Dictionary,frame_value: Variant)->Variant:
	var result:=object_delta(value,frame_value)
	return result.elapsedMilliseconds if result.get("ready",false) else null
func object_delta_for_physical(id_value: Variant,physical_token: Variant,where: Array,frame_value: Variant)->Dictionary:
	var internal:=_lookup_physical(id_value,physical_token,where)
	return object_delta(internal,frame_value) if not internal.is_empty() else unavailable("Current internal physical clock reference is unavailable.")
func queue_delta_for_physical(id_value: Variant,physical_token: Variant,where: Array,frame_value: Variant)->Variant:
	var result:=object_delta_for_physical(id_value,physical_token,where,frame_value)
	return result.elapsedMilliseconds if result.get("ready",false) else null
func gui_delta(frame_value: Variant)->Dictionary:
	if not _constructed or _phase!="complete" or frame_value!=_frame:return unavailable("GUI delta is available only after this frame's conceptual AI phase.")
	return _gui_result.duplicate(true)
func reveal_timing(frame_value: Variant)->Dictionary:
	# CNWC fade762e40 calls AppManager6ac330 (Client+50) then WorldTimer597050.
	# Read the existing primary world snapshot, never sample the absolute source,
	# choose an object pause timer, borrow GUI T2 or advance another clock here.
	if not _constructed or _connection<0 or not ObjectClocks.natural(frame_value) or frame_value!=_frame or _phase not in ["receive","complete"] or not _clock_complete or not _transport_complete:return unavailable("Current native world snapshot phase/history is unavailable.")
	var clock: Variant=_timers.get("world")
	if not is_instance_valid(clock):return unavailable("Existing primary world timer is unavailable.")
	var difference: Dictionary=clock.snapshot_difference()
	var words:=WorldClock.words(difference.get("microseconds"))
	if difference.get("ready")!=true or words.is_empty():return unavailable("Existing world snapshot counter difference is unavailable.")
	# The current pure fade adapter accepts a nonnegative signed63 microsecond
	# scalar. Preserve unsupported unsigned64 values explicitly, never FLOAT-cast.
	if words.hi>=0x80000000:return unavailable("World snapshot exceeds the current signed63 fade carrier.")
	var result:={"ready":true,"available":true,"source":"native-primary-world-snapshot-v1","frame":_frame,"snapshot_us":int(words.hi)*WorldClock.TWO32+int(words.lo),"snapshot_words":words}
	# Calendar fields are optional: ordinary tile/entry fades have expiry0 and
	# do not require them. The existing world owner alone supplies valid time.
	var now: Dictionary=clock.time()
	if now.get("ready")==true:result.now_day=now.day;result.now_ms=now.time
	return result
func cleanup_connection()->Dictionary:
	if not _constructed or _connection<0:return unavailable("Connection cleanup requires an active process/connection owner.")
	if _phase!="cleanup-partial":_cleanup_origin_phase=_phase
	var receive_open: bool=_cleanup_origin_phase=="receive"
	_frame_failure="";_phase="cleanup-before-ai" if receive_open else "cleanup-after-ai"
	# Preserve native no-op/list semantics; do not force an extra clear/reset.
	var first:=_apply_pause(2,0,null)
	if not first.ready:_phase="cleanup-partial";return unavailable("Mask2 cleanup is partial/unavailable; connection is retained.",true)
	var second:=_apply_pause(1,0,null)
	if not second.ready:_phase="cleanup-partial";return unavailable("Mask1 cleanup is partial/unavailable; connection is retained.",true)
	_objects.close();_scope=[];_resets=[];_connection=-1;_serial=0;_transport_complete=false;_lifetime_complete=false;_phase="receive" if receive_open else "idle";_gui_result={};_physical_refs={};_unavailable_ids={};_cleanup_origin_phase=""
	return {"ready":true,"order":[2,1],"timersRetired":false,"clockHistoryComplete":_clock_complete,"receivePhasePreserved":receive_open}
func state_view()->Dictionary:
	var clocks: Dictionary={}
	for key in _timers:clocks[key]=_timers[key].state_view()
	return {"constructed":_constructed,"processConstructionKnown":_construction_known,"clockHistoryComplete":_clock_complete,"transportHistoryComplete":_transport_complete,"externalLifetimeComplete":_lifetime_complete,"connection":_connection,"serial":_serial,"frame":_frame,"phase":_phase,"scope":_scope.duplicate(),"timers":clocks,"pause":_pause.state_view() if _constructed else {},"objects":_objects.state_view() if _constructed else {},"stagedResets":_resets.duplicate(true),"unavailableObjects":_unavailable_ids.duplicate(),"failure":_failure,"frameFailure":_frame_failure}
func destroy_process()->Dictionary:
	if _connection>=0:return unavailable("Native connection cleanup must precede process retirement.")
	for clock in _timers.values():clock.close()
	if _pause!=null:_pause.close()
	if _objects!=null:_objects.close()
	_timers.clear();_lower.clear();_scope=[];_resets=[];_physical_refs={};_unavailable_ids={};_constructed=false;_construction_known=false;_clock_complete=false;_phase="idle"
	return {"ready":true}
func release_process(fact: Dictionary)->Dictionary:
	if fact.get("processExiting")!=true:return unavailable("Final process resource release requires explicit processExiting:true.")
	if _released:
		var repeated: Dictionary=_release_diagnostic.duplicate(true);repeated.released=false;repeated.alreadyReleased=true;return repeated
	var diagnostic:={"ready":true,"released":_constructed,"processExitOnly":true,"connectionCleanupAccepted":_connection<0,"priorConnection":_connection,"priorPhase":_phase,"priorFailure":_failure,"priorFrameFailure":_frame_failure,"clockHistoryCompleteBeforeRelease":_clock_complete}
	# Resource release only: no Pause.apply, provider invocation, sample,
	# rollback, clock-zero calibration, or claim of accepted connection cleanup.
	for clock in _timers.values():clock.close()
	if _pause!=null:_pause.close()
	if _objects!=null:_objects.close()
	_timers.clear();_lower.clear();_scope=[];_resets=[];_physical_refs={};_unavailable_ids={};_gui_result={}
	_constructed=false;_construction_known=false;_clock_complete=false;_transport_complete=false;_lifetime_complete=false;_connection=-1;_phase="released";_released=true
	_release_diagnostic=diagnostic.duplicate(true)
	return diagnostic
