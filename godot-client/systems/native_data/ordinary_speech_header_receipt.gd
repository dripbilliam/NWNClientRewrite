extends RefCounted
# Receiver77c140 header only. Native body/overhead parsing has its own owner.
# Capture owns small detached provider values, never an actor/table registry.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const ActorNames=preload("res://systems/native_data/actor_name_state.gd")
const PREFIXES={2:10300,9:10300,18:10300,3:10301,10:10301,19:10301,4:10302,20:10302,5:10299,15:10299,6:10303,22:10303,14:66756,30:66756}
const REMOTE=[2,4,6,14,17,18,19,20,30]
const CHANNELS=[1,2,3,4,5,6,8,9,10,11,12,14,15,17,18,19,20,22,30]
static func pending(reason: String)->Dictionary:return {"ready":false,"pending":true,"reason":reason}
static func literal(value: Variant)->Dictionary:
	if value is String:return {"kind":"literal","value":value}
	if value is Dictionary and value.get("text") is String:return {"kind":"literal","value":value.text}
	return {"kind":"unavailable","reason":"Native stored name bytes have not been projected."}
static func stored_creature(override_value: Variant,first_value: Variant,last_value: Variant)->Dictionary:
	# Pure7f3f00 lower contract. The caller must own these actual stored slots;
	# a wire P/U name declaration or a D+A is not constructor provenance.
	var override:=literal(override_value)
	if override.kind!="literal":return override
	if not str(override.value).is_empty():return override
	return {"kind":"creature","first":literal(first_value),"last":literal(last_value)}
static func bit(value: Variant)->Variant:
	if value is bool:return value
	return int(value)!=0 if Scope.integer(value,0,1) else null
static func wire(value: Variant)->Dictionary:
	var direct:=literal(value)
	if direct.kind=="literal":return direct
	if value is Dictionary and Scope.integer(value.get("strRef"),0,Scope.MAX_ID) and Scope.integer(value.get("gender"),0,1):return {"kind":"reference","ref":int(value.strRef),"gender":int(value.gender)}
	return {"kind":"unavailable","reason":"Native remote localized name declaration is malformed."}
static func scalar(value: Variant)->bool:return value==null or value is String or value is int or value is float or value is bool
static func name_projection(value: Variant,depth: int=0)->Variant:
	if value is String:return value
	if not value is Dictionary:return null
	var copy: Dictionary={}
	for key in ["text","gender","strRef"]:
		if value.has(key) and scalar(value[key]):copy[key]=value[key]
	if depth==0:
		for key in ["firstName","lastName"]:
			if value.has(key):copy[key]=name_projection(value[key],1)
	return copy
static func thin_context(value: Dictionary)->Dictionary:
	var copy: Dictionary={}
	for key in ["id","objectType","areaId","nativeLifetime","clientKnownLifetime"]:
		if value.has(key) and scalar(value[key]):copy[key]=value[key]
	for section in ["replicated","appearance"]:
		if not value.get(section) is Dictionary:continue
		var source: Dictionary=value[section];var selected: Dictionary={}
		if source.has("name"):selected.name=name_projection(source.name)
		if section=="replicated" and source.get("stats") is Dictionary:
			var stats: Dictionary={}
			if source.stats.has("race") and scalar(source.stats.race):stats.race=source.stats.race
			if source.stats.get("classes") is Array and not source.stats.classes.is_empty():
				var first: Variant=source.stats.classes[0];var record: Dictionary={}
				if first is Dictionary:
					for key in ["id","level"]:
						if first.has(key) and scalar(first[key]):record[key]=first[key]
				stats.classes=[record]
			selected.stats=stats
		copy[section]=selected
	return copy
static func call_snapshot(value: Dictionary)->Dictionary:
	var copy: Dictionary={}
	for key in ["gender","nativeB8","nativeBC"]:
		if value.has(key) and scalar(value[key]):copy[key]=value[key]
	if value.get("context") is Dictionary:copy.context=thin_context(value.context)
	return copy
static func table_ref(table: String,index: Variant,column: String)->Dictionary:
	return {"kind":"table","table":table,"index":int(index),"column":column} if Scope.integer(index,0,Scope.MAX_ID) else {"kind":"unavailable","reason":"Native name table index is unavailable."}
static func table_reference(descriptor: Dictionary,text)->Dictionary:
	if descriptor.has("reference"):return {"ready":true,"reference":int(descriptor.reference)}
	if not is_instance_valid(text):return pending("Native name table owner is unavailable.")
	var table: Dictionary=text.tables.get(str(descriptor.table),{});var rows: Array=table.get("orderedRows",[]);var index:=int(descriptor.index)
	if index<0 or index>=rows.size():return pending("Native name provider table row is unavailable.")
	var cell: Variant=null
	for key in rows[index]:
		if str(key).to_lower()==str(descriptor.column).to_lower():cell=rows[index][key];break
	if cell is String and cell.is_valid_int():cell=int(cell)
	if not Scope.integer(cell,0,Scope.MAX_ID):return pending("Native name provider reference is unavailable.")
	descriptor.reference=int(cell);return {"ready":true,"reference":int(cell)}
static func capture_reference(receipt: Dictionary,ref: int,text)->void:
	if receipt.overrides.has(ref) or not is_instance_valid(text):return
	if text.overrides.has(ref) and not text.overrides[ref] is String:return
	receipt.overrides[ref]={"present":text.overrides.has(ref),"value":text.overrides[ref] if text.overrides.has(ref) else ""}
static func capture_references(receipt: Dictionary,descriptor: Dictionary,text)->void:
	match str(descriptor.get("kind","")):
		"reference":capture_reference(receipt,int(descriptor.ref),text)
		"remote_split","creature":capture_references(receipt,descriptor.first,text);capture_references(receipt,descriptor.last,text)
		"provider_failure":capture_reference(receipt,5189,text)
		"table":
			var selected:=table_reference(descriptor,text)
			if selected.get("ready",false):capture_reference(receipt,int(selected.reference),text)
		"item":
			capture_references(receipt,descriptor.base,text)
			if not descriptor.identified:capture_reference(receipt,5548,text)
static func provider(row: Dictionary)->Dictionary:
	var type: int=int(row.objectType);var state: Dictionary=row.get("replicated",{});var named: Variant=state.get("name",row.get("appearance",{}).get("name",row.get("staticState",{}).get("name")))
	if type==5:
		# P/appearance.name changes stored first/last; U/replicated.name only
		# changes party text. Neither proves retained stats+40 override bytes.
		return {"kind":"unavailable","reason":"Native creature stored-name/constructor provenance is unavailable."}
	if type==6:
		var item: Variant=row.get("item",state.get("item"))
		if not item is Dictionary:return {"kind":"unavailable","reason":"Native item name provider is unavailable."}
		var identified: Variant=bit(item.get("identified"))
		if identified==null:return {"kind":"unavailable","reason":"Native item identification flag is unavailable."}
		var name:=literal(item.get("name"))
		if identified and name.kind=="literal" and not str(name.value).is_empty():return name
		if identified and name.kind!="literal":return name
		return {"kind":"item","base":table_ref("baseitems",item.get("baseItem"),"Name"),"identified":identified}
	if type in [7,9,10]:
		var name:=literal(named)
		if name.kind!="literal":return name
		if not str(name.value).is_empty() or type==10:return name # Empty door succeeds.
		if type==7:return {"kind":"reference","ref":556,"gender":0}
		return table_ref("placeables",state.get("appearance",row.get("appearance",{}).get("appearance",row.get("staticState",{}).get("appearance"))),"StrRef")
	return {"kind":"provider_failure"}
static func capture(message: Dictionary,text,current: Dictionary,retained_call_state: Dictionary={}) -> Dictionary:
	var receipt:={"version":1,"channel":message.get("channel") if scalar(message.get("channel")) else null,"objectId":message.get("objectId") if scalar(message.get("objectId")) else null,"tokens":{},"tokensReady":is_instance_valid(text),"retained":call_snapshot(retained_call_state),"fetches":{},"overrideOwnerKnown":is_instance_valid(text),"overrides":{},"source":{"kind":"unavailable","reason":"Native received name owner is unavailable."}}
	if is_instance_valid(text):
		for key in text.custom_tokens:
			if Scope.integer(key,0,Scope.MAX_ID) and text.custom_tokens[key] is String:receipt.tokens[int(key)]=text.custom_tokens[key]
			else:receipt.tokensReady=false
	if not Scope.integer(receipt.channel,0,255) or not int(receipt.channel) in CHANNELS:receipt.invalid="Native header channel is unsupported.";return receipt
	var channel:=int(receipt.channel);receipt.system=channel in [5,15]
	var envelope: Variant=message.get("nativeTextEvent")
	if envelope is Dictionary and envelope.has("actorName"):
		receipt.actorPacket=envelope.actorName.duplicate(true) if envelope.actorName is Dictionary else envelope.actorName
		receipt.actorEnvelope={}
		for key in ["version","serial","connection","generation","areaId","source"]:
			if envelope.has(key):receipt.actorEnvelope[key]=envelope[key].duplicate(true) if envelope[key] is Dictionary or envelope[key] is Array else envelope[key]
	if REMOTE.has(channel):
		var value: Variant=message.get("speakerName")
		receipt.remote={"kind":"remote_split","first":wire(value.get("firstName")),"last":wire(value.get("lastName"))} if value is Dictionary and (value.has("firstName") or value.has("lastName")) else wire(value)
		capture_references(receipt,receipt.remote,text)
	# Freeze only this header's possible reference keys, not the whole runtime
	# override map or any native table. Parsing/fetch order remains deferred.
	capture_reference(receipt,5189,text)
	if PREFIXES.has(channel):capture_reference(receipt,int(PREFIXES[channel]),text)
	if receipt.system:return receipt
	var admitted:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"));var event:=Scope.event(message,admitted)
	if not event.get("ready",false):return receipt
	if not event.get("anchor",false):receipt.source={"kind":"provider_failure"};return receipt
	if not Scope.integer(receipt.objectId,0,Scope.MAX_ID) or int(receipt.objectId)!=int(event.source.id):return receipt
	if not is_instance_valid(text):return receipt
	var row: Dictionary=text.objects.get(int(receipt.objectId),{})
	if not Scope.received_source(event,row,admitted).get("ready",false):return receipt
	receipt.witness=event.witness.duplicate();receipt.scope=event.scope.duplicate();receipt.source=provider(row);capture_references(receipt,receipt.source,text)
	return receipt
static func state_for(receipt: Dictionary,supplied: Dictionary)->Dictionary:
	if not receipt.has("effectiveState"):receipt.effectiveState=receipt.retained.duplicate(true)
	# Body11/12 may supply a first safely captured context later. Fill only
	# unknown fields; a later actor/reuse must never rewrite a captured frame.
	var supplied_state:=call_snapshot(supplied)
	for key in supplied_state:
		if not receipt.effectiveState.has(key):receipt.effectiveState[key]=supplied_state[key]
	var state: Dictionary=receipt.effectiveState.duplicate(true)
	state.localCustomTokens=receipt.tokens;state.localCustomTokensComplete=receipt.tokensReady
	return state
static func native_actor_mode(receipt: Dictionary)->String:
	if receipt.has("actorMode"):return str(receipt.actorMode)
	var result:=actor_mode_value(receipt);receipt.actorMode=result;return result
static func actor_mode_value(receipt: Dictionary)->String:
	if not receipt.has("actorPacket"):return "legacy"
	var packet: Variant=receipt.actorPacket
	if not packet is Dictionary or not Scope.integer(packet.get("version"),1,1) or not packet.get("historyComplete") is bool or not packet.has("state"):return "invalid"
	if not packet.historyComplete or packet.state==null:return "legacy" # No certified stored owner yet (e.g. imported/BIC-loaded).
	if not Scope.integer(receipt.get("objectId"),0,Scope.MAX_ID):return "invalid"
	var projected:=ActorNames.metadata(packet.state,int(receipt.objectId))
	if projected.is_empty():return "invalid"
	return "native" if projected.override.known else "legacy"
static func stored_actor(receipt: Dictionary,text,current: Dictionary,owner)->Dictionary:
	if native_actor_mode(receipt)!="native":return {"ready":false,"reason":"Native actor stored-name provenance is malformed."}
	if not is_instance_valid(owner) or not owner.has_method("capture_received"):return pending("Native actor-name owner is unavailable.")
	var admitted:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"))
	var event:=Scope.event({"nativeTextEvent":receipt.actorEnvelope},admitted)
	if not event.get("ready",false):return event
	if not event.get("anchor",false) or event.source.objectType!=5 or int(event.source.id)!=int(receipt.objectId):return {"ready":false,"reason":"Native actor-name event source does not match its header."}
	if not Scope.integer(event.source.get("areaId"),0,Scope.MAX_ID):return pending("Native actor-name event area is unavailable.")
	var row:={"id":int(event.source.id),"objectType":5,"areaId":int(event.source.areaId),"nativeLifetime":int(event.source.nativeLifetime),"clientKnownLifetime":int(event.source.knownLifetime)}
	var call: Dictionary=current.duplicate();call.actorNameHistoryComplete=true # Captured event certainty, not a later live history flag.
	if not receipt.has("actorReceipt"):receipt.actorReceipt=owner.capture_received(row,receipt.actorPacket.state,text,call)
	var named: Dictionary=owner.resolve_received(receipt.actorReceipt,text,call)
	return {"ready":true,"text":str(named.name),"nativeStored":true} if named.get("ready",false) else named
static func fetch(receipt: Dictionary,slot: String,ref: int,gender: int,text,state: Dictionary)->Dictionary:
	if receipt.fetches.has(slot) and receipt.fetches[slot].has("result"):return receipt.fetches[slot].result.duplicate(true)
	if ref==Scope.MAX_ID or gender>1:
		var empty:={"ready":true,"text":""};receipt.fetches[slot]={"result":empty};return empty.duplicate(true)
	if not is_instance_valid(text):return pending("Native header text owner is unavailable.")
	var selected: Dictionary=receipt.fetches.get(slot,{})
	if selected.is_empty():
		if not receipt.overrideOwnerKnown or not receipt.overrides.has(ref):return pending("Native header receipt-time override lookup is unavailable.")
		var snapshot:={"known":true,"present":receipt.overrides[ref].present}
		if snapshot.present:snapshot.text=str(receipt.overrides[ref].value)
		selected=text.fetch_native_reference_snapshot(ref,gender,snapshot).duplicate(true)
		if not selected.get("found",false):
			if not selected.get("lookupComplete",false):return pending(str(selected.get("reason","Native header TLK reference is unavailable.")))
			selected={"found":true,"text":"","override":false,"gender":selected.get("gender",gender)}
		receipt.fetches[slot]=selected
	var body:=str(selected.get("text",""))
	if selected.get("override",false):
		var call: Dictionary=state.duplicate(true);call.gender=selected.gender
		call.nativeOverrideSelections={}
		for key in receipt.overrides:
			var captured: Dictionary=receipt.overrides[key];var choice:={"known":true,"present":captured.present}
			if choice.present:choice.text=str(captured.value)
			call.nativeOverrideSelections[key]=choice
		var parsed: Dictionary=text.parse_native(body,call)
		if not parsed.get("ready",false):return parsed
		body=str(parsed.body)
	var result:={"ready":true,"text":body};receipt.fetches[slot].result=result.duplicate(true);return result
static func value(receipt: Dictionary,slot: String,descriptor: Dictionary,text,state: Dictionary)->Dictionary:
	match str(descriptor.get("kind","")):
		"literal":return {"ready":true,"text":str(descriptor.value)}
		"reference":return fetch(receipt,slot,int(descriptor.ref),int(descriptor.gender),text,state)
		"unavailable":return pending(str(descriptor.reason))
		"provider_failure":return fetch(receipt,slot+".unknown",5189,0,text,state)
		"remote_split","creature":
			var first:=value(receipt,slot+".first",descriptor.first,text,state)
			if not first.get("ready",false):return first
			var last:=value(receipt,slot+".last",descriptor.last,text,state)
			if not last.get("ready",false):return last
			var separator:=" " if descriptor.kind=="remote_split" or not str(first.text).is_empty() and not str(last.text).is_empty() else ""
			return {"ready":true,"text":str(first.text)+separator+str(last.text)}
		"table":
			var selected:=table_reference(descriptor,text)
			return fetch(receipt,slot,int(selected.reference),0,text,state) if selected.get("ready",false) else selected
		"item":
			var base:=value(receipt,slot+".base",descriptor.base,text,state)
			if not base.get("ready",false) or descriptor.identified:return base
			var suffix:=fetch(receipt,slot+".unidentified",5548,0,text,state)
			return {"ready":true,"text":str(base.text)+" "+str(suffix.text)} if suffix.get("ready",false) else suffix
	return pending("Native header name provider is unavailable.")
static func prepare_name(receipt: Dictionary,text,current: Dictionary,body_call_state: Dictionary={},actor_owner=null) -> Dictionary:
	if receipt.has("invalid"):return {"ready":false,"reason":str(receipt.invalid)}
	if receipt.has("nameResult"):
		if native_actor_mode(receipt)!="legacy":
			var admitted:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"))
			var event:=Scope.event({"nativeTextEvent":receipt.actorEnvelope},admitted)
			if not event.get("ready",false):return event
		return receipt.nameResult.duplicate(true)
	if receipt.system:receipt.nameResult={"ready":true,"name":"","system":true};return receipt.nameResult.duplicate(true)
	var state:=state_for(receipt,body_call_state);var resolved: Dictionary={}
	if receipt.has("remote"):
		resolved=value(receipt,"remote",receipt.remote,text,state)
		if not resolved.get("ready",false):return resolved
	if resolved.is_empty() or str(resolved.text).is_empty():
		if native_actor_mode(receipt)!="legacy":resolved=stored_actor(receipt,text,current,actor_owner)
		else:resolved=value(receipt,"source",receipt.source,text,state)
	if not resolved.get("ready",false):return resolved
	receipt.nameResult={"ready":true,"name":str(resolved.text),"system":false};return receipt.nameResult.duplicate(true)
static func prepare_prefix(receipt: Dictionary,text,current: Dictionary,body_call_state: Dictionary={}) -> Dictionary:
	# Shared integration may retain its separate canonical-name path. Do not
	# make that missing provider block this independently proven label stage.
	# Caller/prepare() owns native body -> name -> prefix ordering.
	if receipt.has("invalid"):return {"ready":false,"reason":str(receipt.invalid)}
	if receipt.has("prefixResult"):return receipt.prefixResult.duplicate(true)
	var channel:=int(receipt.channel);var label:={"ready":true,"text":""}
	if PREFIXES.has(channel):label=fetch(receipt,"prefix",int(PREFIXES[channel]),0,text,state_for(receipt,body_call_state))
	if not label.get("ready",false):return label
	# Return the raw label. Existing receiver punctuation/brackets stay owned by
	# the caller, not a second combined-log parse or invented text formatter.
	receipt.prefixResult={"ready":true,"prefix":str(label.text)};return receipt.prefixResult.duplicate(true)
static func prepare(receipt: Dictionary,text,current: Dictionary,body_call_state: Dictionary={}) -> Dictionary:
	var name:=prepare_name(receipt,text,current,body_call_state)
	if not name.get("ready",false):return name
	var prefix:=prepare_prefix(receipt,text,current,body_call_state)
	if not prefix.get("ready",false):return prefix
	return {"ready":true,"name":name.name,"prefix":prefix.prefix,"system":name.system}
