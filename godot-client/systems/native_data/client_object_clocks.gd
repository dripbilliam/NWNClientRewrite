extends RefCounted
# Conditional lazy equivalent of creature7fbd10 stamps, not a lifecycle owner.
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const SAFE:=9007199254740991
const INVALID:=0x7f000000
var resource_limits: Dictionary={"maxBindings":null,"maxSelectorIds":null}
var scope: Array=[]
var bindings: Dictionary={}
var current: Dictionary={}
var previous_ai: Dictionary={}
var barrier: Dictionary={}
var last_frame: int=-1
var closed:=true
static func unavailable(reason: String)->Dictionary:return {"ready":false,"outputsDefined":false,"reason":reason}
static func natural(value: Variant,maximum: int=SAFE)->bool:
	return NativeWorldTimer.integer(value) and value>=0 and value<=maximum
static func pair(value: Variant)->Dictionary:
	if not value is Dictionary or not natural(value.get("day"),NativeWorldTimer.U32) or not natural(value.get("time"),NativeWorldTimer.U32):return {}
	return {"day":int(value.day),"time":int(value.time)}
static func normalized_scope(value: Variant)->Array:
	if not value is Array or value.size()!=3 or not natural(value[0]) or not natural(value[1]) or not natural(value[2],NativeWorldTimer.U32):return []
	return [int(value[0]),int(value[1]),int(value[2])]
static func token(value: Variant)->Variant:
	if natural(value) and value>0:return int(value)
	if value is String and value.length()>0 and value.length()<=128:
		for byte in value.to_utf8_buffer():
			if byte<32 or byte>126:return null
		return value
	return null
static func normalized_reference(value: Variant,expected_scope: Array)->Dictionary:
	if not value is Dictionary or normalized_scope(value.get("scope"))!=expected_scope:return {}
	if not natural(value.get("id"),NativeWorldTimer.U32):return {}
	for key in ["nativeLifetime","knownLifetime"]:
		# Internal physical-clock references may precede display disclosure.
		# Explicit null is different from an omitted or fabricated lifetime.
		if not value.has(key) or value[key]!=null and (not natural(value[key]) or value[key]<1):return {}
	var physical: Variant=token(value.get("physicalToken"))
	if physical==null:return {}
	if (value.nativeLifetime==null or value.knownLifetime==null) and not physical is String:return {}
	var result:={"scope":expected_scope.duplicate(),"id":int(value.id),"nativeLifetime":null if value.nativeLifetime==null else int(value.nativeLifetime),"knownLifetime":null if value.knownLifetime==null else int(value.knownLifetime),"physicalToken":physical}
	if value.has("lifecycleEpoch"):
		if not natural(value.lifecycleEpoch) or value.lifecycleEpoch<1:return {}
		result.lifecycleEpoch=int(value.lifecycleEpoch)
	return result
static func point(value: Variant)->Dictionary:
	if not value is Dictionary or not natural(value.get("frame")) or not natural(value.get("order")) or value.order<1 or value.get("phase") not in ["before-ai","after-ai"]:return {}
	return {"frame":int(value.frame),"phase":0 if value.phase=="before-ai" else 2,"order":int(value.order)}
static func compare(a: Dictionary,b: Dictionary)->int:
	for key in ["frame","phase","order"]:
		if a[key]!=b[key]:return -1 if a[key]<b[key] else 1
	return 0
static func ai_point(frame: int)->Dictionary:return {"frame":frame,"phase":1,"order":0}
static func selected(value: Dictionary,id: int)->Dictionary:
	var slot:="world"
	if id!=INVALID:
		var flags: int=value.selector.flags
		var ids: Variant=value.selector.exclusions.ids
		var member: bool=ids==null or ids.has(id)
		if (flags&2)!=0 and member:slot="timer2"
		elif (flags&1)!=0 and (flags&2)==0 and member:slot="timer1"
	return {"slot":slot,"pair":value[slot].duplicate()}
func configure(next_scope: Array,limits: Dictionary={})->Dictionary:
	var normalized:=normalized_scope(next_scope)
	if normalized.is_empty():return unavailable("Explicit current native scope is unavailable.")
	var admitted:={"maxBindings":null,"maxSelectorIds":null}
	for key in admitted:
		if limits.get(key)!=null:
			if not natural(limits[key]):return unavailable("Caller resource bound is malformed.")
			admitted[key]=int(limits[key])
	resource_limits=admitted
	scope=normalized;bindings.clear();current.clear();previous_ai.clear();barrier.clear();last_frame=-1;closed=false
	return {"ready":true}
func _binding_for(value: Variant)->Dictionary:
	if closed:return {}
	var ref:=normalized_reference(value,scope)
	if ref.is_empty():return {}
	var record: Dictionary=bindings.get(ref.id,{})
	return record if not record.is_empty() and record.ref==ref else {}
func bind(value: Dictionary,fact: Dictionary)->Dictionary:
	if closed:return unavailable("Clock component is closed.")
	var ref:=normalized_reference(value,scope);var registration:=point(fact.get("registration"))
	if ref.is_empty() or registration.is_empty() or fact.get("registeredBeforeAi")!=true:return unavailable("Explicit physical owner/AI registration fact is unavailable.")
	if bindings.has(ref.id):
		return {"ready":true,"changed":false} if bindings[ref.id].ref==ref and bindings[ref.id].registration==registration else unavailable("Existing binding requires explicit retirement or trusted rebind.")
	if resource_limits.maxBindings!=null and bindings.size()>=resource_limits.maxBindings:return unavailable("Caller-configured relevant binding bound reached.")
	var stamps: Array=[]
	if fact.get("stamp")!=null:
		var birth: Variant=fact.stamp;var at:=point(birth)
		var born_pair:=pair(birth.get("pair")) if birth is Dictionary else {}
		if at.is_empty() or born_pair.is_empty() or birth.get("kind")!="birth":return unavailable("Explicit native base-T0 birth stamp is unavailable.")
		stamps.append({"at":at,"pair":born_pair,"kind":"birth"})
	bindings[ref.id]={"ref":ref,"registration":registration,"stamps":stamps,"cachedFrame":-1,"cached":{}}
	return {"ready":true,"changed":true}
func reset_stamp(value: Dictionary,now: Dictionary,fact: Dictionary)->Dictionary:
	var record:=_binding_for(value);var at:=point(fact);var sampled:=pair(now)
	if record.is_empty() or at.is_empty() or sampled.is_empty() or fact.get("nativeReset")!=true:return unavailable("Current explicit native reset witness is unavailable.")
	if current.is_empty() or at.frame!=last_frame or (at.phase==0 and current.get("completed",false)) or (at.phase==2 and not current.get("completed",false)):return unavailable("Reset must match the currently open before-AI or completed after-AI phase.")
	var stamps: Array=record.stamps
	if not stamps.is_empty():
		var latest: Dictionary=stamps.back();var order:=compare(at,latest.at)
		if order<0:return unavailable("Reset order is stale.")
		if order==0:return {"ready":true,"changed":false} if latest.pair==sampled else unavailable("Changed stamp at an immutable phase/order.")
		if latest.at.frame==at.frame and latest.at.phase==at.phase:stamps.pop_back()
	stamps.append({"at":at,"pair":sampled,"kind":"reset"})
	while stamps.size()>2:stamps.pop_front()
	# Before-AI resets occur before completion; after-AI resets never change +58.
	if at.phase==0:record.cachedFrame=-1;record.cached={}
	return {"ready":true,"changed":true}
func _normalized_frame(frame: int,value: Dictionary)->Dictionary:
	var result:={"frame":frame,"scope":scope.duplicate(),"completed":false,"ready":true}
	if value.get("clockStreamKnown")!=true:return {}
	result.clockStreamKnown=true
	for key in ["world","timer1","timer2"]:
		var sampled:=pair(value.get(key))
		if sampled.is_empty():return {}
		result[key]=sampled
	if not natural(value.get("dayLength"),NativeWorldTimer.U32) or value.dayLength==0:return {}
	result.dayLength=int(value.dayLength)
	var selector: Variant=value.get("selector")
	if not selector is Dictionary or not natural(selector.get("flags"),255):return {}
	var excluded: Variant=selector.get("exclusions")
	if not excluded is Dictionary or excluded.get("known")!=true or not excluded.has("ids"):return {}
	var ids: Variant=excluded.ids
	if ids!=null:
		if not ids is Array:return {}
		if resource_limits.maxSelectorIds!=null and ids.size()>resource_limits.maxSelectorIds:return {}
		var copied: Array=[]
		for id in ids:
			if not natural(id,NativeWorldTimer.U32):return {}
			copied.append(int(id))
		ids=copied
	result.selector={"flags":int(selector.flags),"exclusions":{"known":true,"ids":ids}}
	var eligibility: Variant=value.get("eligibility")
	if not eligibility is Dictionary:return {}
	for key in ["module","area","completePass"]:
		if not eligibility.get(key) is bool:return {}
	result.eligibility={"module":eligibility.module,"area":eligibility.area,"completePass":eligibility.completePass}
	return result
func begin_frame(frame_value: Variant,value: Dictionary)->Dictionary:
	if closed or not natural(frame_value):return unavailable("Current native AI frame is unknown.")
	var frame:=int(frame_value)
	if frame<=last_frame or not current.is_empty() and not current.get("completed",false):return unavailable("Frame order/open phase is invalid.")
	if last_frame<0 or frame!=last_frame+1:
		previous_ai.clear();barrier={"frame":frame,"phase":0,"order":0}
	last_frame=frame
	var next:=_normalized_frame(frame,value)
	if next.is_empty():
		previous_ai.clear();barrier={"frame":frame,"phase":2,"order":0}
		current={"frame":frame,"completed":false,"ready":false}
		return unavailable("Post-receive timer/selector/eligibility input is unknown.")
	# Ingress owns the detached scalar snapshot. Internal snapshots are never
	# mutated after completion, so no selector/binding recopy is needed here.
	next.prior=previous_ai;current=next
	return {"ready":true}
func complete_frame()->Dictionary:
	if closed or current.is_empty() or current.get("completed",false):return unavailable("No open native AI phase.")
	current.completed=true
	if not current.get("ready",false):return unavailable("Unknown frame cannot certify AI history.")
	var eligible: Dictionary=current.eligibility
	if not eligible.module or not eligible.area:return {"ready":true,"aiRan":false}
	if not eligible.completePass:
		previous_ai.clear();barrier={"frame":int(current.frame),"phase":2,"order":0}
		return unavailable("A partial/unknown AI pass cannot certify per-object stamps.")
	# Constant work: retain three already resolved pairs, never scan bindings.
	previous_ai=current.duplicate();previous_ai.erase("prior")
	return {"ready":true,"aiRan":true}
func sample(value: Dictionary,frame_value: Variant)->Dictionary:
	var record:=_binding_for(value)
	if record.is_empty() or not natural(frame_value) or current.is_empty() or frame_value!=current.frame or current.get("scope",[])!=scope or not current.get("completed",false) or not current.get("ready",false):return unavailable("Reference/current completed AI frame is unavailable.")
	if record.cachedFrame==current.frame:return record.cached.duplicate(true)
	var result:=_sample_record(record)
	record.cachedFrame=current.frame;record.cached=result.duplicate(true)
	return result.duplicate(true)
func _sample_record(record: Dictionary)->Dictionary:
	var eligibility: Dictionary=current.eligibility
	if not eligibility.module or not eligibility.area or not eligibility.completePass:return unavailable("No certified complete object AI update occurred this frame.")
	var ai:=ai_point(int(current.frame))
	if compare(record.registration,ai)>=0:return unavailable("Object was not explicitly registered before this AI phase.")
	var previous: Dictionary={};var basis: Dictionary={};var basis_kind:=""
	var prior: Dictionary=current.prior
	if not prior.is_empty() and compare(record.registration,ai_point(int(prior.frame)))<0:
		previous=selected(prior,int(record.ref.id)).pair;basis=ai_point(int(prior.frame));basis_kind="previous-ai"
	for stamp in record.stamps:
		if compare(stamp.at,ai)<0 and (basis.is_empty() or compare(stamp.at,basis)>0) and (barrier.is_empty() or compare(stamp.at,barrier)>0):
			previous=stamp.pair.duplicate();basis=stamp.at.duplicate();basis_kind=stamp.kind
	if previous.is_empty():return unavailable("No preceding completed AI stamp or current trusted birth/reset is known.")
	var chosen:=selected(current,int(record.ref.id));var now: Dictionary=chosen.pair
	var difference:=NativeWorldTimer.subtract_world_times(now,previous,current.dayLength)
	if not difference.get("ready",false) or not difference.get("outputsDefined",false):
		return {"ready":false,"outputsDefined":false,"status":difference.get("status"),"reason":"Native subtraction output is unavailable; no zero/rebase/scratch is substituted."}
	return {"ready":true,"outputsDefined":true,"status":difference.status,"elapsedMilliseconds":difference.time,"elapsedDays":difference.day,"selectedSlot":chosen.slot,"currentPair":now.duplicate(),"previousPair":previous.duplicate(),"basis":basis.duplicate(),"basisKind":basis_kind,"frame":current.frame,"reference":record.ref.duplicate(true)}
func retire(value: Dictionary)->Dictionary:
	var record:=_binding_for(value)
	if record.is_empty():return unavailable("Retired/stale reference is not bound.")
	bindings.erase(record.ref.id)
	return {"ready":true,"physicalDestructionInferred":false}
func rebind_scope(next_scope: Array,transfers: Array,fact: Dictionary)->Dictionary:
	var normalized:=normalized_scope(next_scope)
	if closed or normalized.is_empty() or normalized[0]!=scope[0] or fact.get("continuousHistory")!=true or not current.is_empty() and not current.get("completed",false):return unavailable("Trusted same-connection continuous scope rebind is unavailable.")
	if resource_limits.maxBindings!=null and transfers.size()>resource_limits.maxBindings:return unavailable("Caller-configured transfer binding bound reached.")
	var next: Dictionary={}
	for transfer in transfers:
		if not transfer is Dictionary or transfer.get("samePhysical")!=true:return unavailable("Explicit same-physical transfer is unavailable.")
		var record:=_binding_for(transfer.get("previous"));var ref:=normalized_reference(transfer.get("next"),normalized)
		if record.is_empty() or ref.is_empty() or record.ref.id!=ref.id or record.ref.physicalToken!=ref.physicalToken or typeof(record.ref.physicalToken)!=typeof(ref.physicalToken) or record.ref.get("lifecycleEpoch")!=ref.get("lifecycleEpoch") or next.has(ref.id):return unavailable("Transfer cannot prove the same current physical token, epoch and ID.")
		var copied: Dictionary=record.duplicate(true);copied.ref=ref;copied.cachedFrame=-1;copied.cached={};next[ref.id]=copied
	scope=normalized;bindings=next
	return {"ready":true,"bindings":bindings.size()}
func state_view()->Dictionary:
	return {"closed":closed,"scope":scope.duplicate(),"resourceLimits":resource_limits.duplicate(),"frame":current.duplicate(true),"previousAi":previous_ai.duplicate(true),"historyBarrier":barrier.duplicate(),"bindingCount":bindings.size()}
func binding_view(value: Dictionary)->Dictionary:return _binding_for(value).duplicate(true)
func close()->void:
	closed=true;scope.clear();bindings.clear();current.clear();previous_ai.clear();barrier.clear();last_frame=-1
