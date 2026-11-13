extends RefCounted
# Original77c140/9735f0: a FetchInternal result, then separate localized
# overhead/log copies. This is text presentation data, not a second world store.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const OBJECT_INVALID=0x7f000000
const CHANNELS=[8,9,10,11,12,15]
const LOCALIZED=[11,12]
static func capture(message: Dictionary,text,current: Dictionary) -> Dictionary:
	var receipt:={"message":message.duplicate(true),"tokens":text.custom_tokens.duplicate(true) if is_instance_valid(text) else {},"tokensReady":is_instance_valid(text),"language":text.base.language if is_instance_valid(text) else 0}
	var admitted:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"))
	if Scope.event(message,admitted).get("ready",false):
		receipt.frame=preload("res://systems/native_data/native_token_context.gd").event_frame(message.nativeTextEvent)
		receipt.wire=message.nativeTextEvent.get("nativeByteProjection")=="windows-1252"
		if receipt.wire:receipt.tokens=preload("res://systems/native_data/native_token_context.gd").tokens(receipt.tokens,true)
	snapshot_raw(receipt,text)
	if receipt.get("wire",false) and receipt.has("raw") and not receipt.has("rawBytes") and not receipt.override:
		var encoded:=preload("res://systems/native_data/native_talk_parser.gd").encode(str(receipt.raw),0)
		if encoded.get("ready",false):receipt.rawBytes=encoded.bytes
	snapshot_context(receipt,text,current)
	return receipt
static func pending(reason: String) -> Dictionary:return {"ready":false,"pending":true,"reason":reason}
static func snapshot_raw(receipt: Dictionary,text) -> Dictionary:
	if receipt.has("raw"):return {"ready":true}
	if not is_instance_valid(text):return pending("Native speech text owner is unavailable.")
	var message: Dictionary=receipt.message
	if not Scope.integer(message.get("channel"),0,255) or not int(message.channel) in CHANNELS:return {"ready":false,"reason":"Native speech receipt channel is unsupported."}
	var value: Variant=message.get("text");var gender:=0
	if value is String:receipt.raw=value;receipt.override=false;receipt.gender=0;receipt.forced=0.0;return {"ready":true}
	if not value is Dictionary:return {"ready":false,"reason":"Native speech text is malformed."}
	if value.has("text"):
		if not value.text is String:return {"ready":false,"reason":"Native speech literal is malformed."}
		receipt.raw=value.text;receipt.override=false;receipt.gender=0;receipt.forced=0.0;return {"ready":true}
	if not Scope.integer(value.get("strRef"),0,4294967295):return {"ready":false,"reason":"Native speech string reference is malformed."}
	if int(message.channel) in LOCALIZED:
		if not Scope.integer(value.get("gender"),0,1):return {"ready":false,"reason":"Native localized speech fetch gender is unavailable."}
		gender=int(value.gender)
	var ref:=int(value.strRef);var fetched: Dictionary=text.fetch_native_reference(ref,gender)
	if not fetched.get("found",false):return pending("Native speech string reference is unavailable.")
	var duration: Variant=fetched.get("duration",0.0)
	if not (duration is int or duration is float) or not is_finite(float(duration)):return {"ready":false,"reason":"Native speech TLK duration is malformed."}
	receipt.raw=str(fetched.get("text",""));receipt.override=fetched.get("override",false);receipt.gender=int(fetched.gender);receipt.forced=float(duration) if int(message.channel) in LOCALIZED else 0.0
	if fetched.get("bytes") is PackedByteArray:receipt.rawBytes=fetched.bytes.duplicate()
	receipt.language=int(fetched.get("language",text.base.language))
	return {"ready":true}
static func snapshot_context(receipt: Dictionary,text,current: Dictionary) -> Dictionary:
	if receipt.has("context"):return {"ready":true}
	var message: Dictionary=receipt.message
	if not int(message.get("channel",-1)) in LOCALIZED:return {"ready":true}
	if not Scope.integer(message.get("contextId"),0,4294967295):return pending("Native speech token context ID is unavailable.")
	if int(message.contextId)==OBJECT_INVALID:receipt.context={};return {"ready":true}
	if not is_instance_valid(text):return pending("Native speech token owner is unavailable.")
	# Gameplay supplies the raw authoritative owner tuple; the standalone
	# speech owner supplies the already-normalized form. Normalize only these
	# owner values, never provenance values selected by the incoming message.
	var admitted:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"))
	var witness:=Scope.localized_context(message,admitted)
	if not witness.get("ready",false):return witness
	var row: Dictionary=text.objects.get(int(message.contextId),{})
	var envelope: Variant=message.get("nativeTextEvent")
	# New dispatches carry the exact token fields, not a later coalesced row.
	# Legacy captures still require their canonical lifetime match below.
	if envelope is Dictionary and envelope.has("contextData"):
		if not envelope.contextData is Dictionary:return pending("Native receipt token fields are unavailable.")
		row=envelope.contextData
	var matched:=Scope.received_source(witness,row,admitted)
	if not matched.get("ready",false):
		if matched.get("mismatch",false):matched.pending=true
		return matched
	# The matched lifetime is copied once; later removal/reuse cannot change a
	# deferred named-token provider into the next object's identity.
	receipt.context=context_view(row)
	if envelope is Dictionary and envelope.has("contextActorName"):
		var packet: Variant=envelope.contextActorName
		if packet is Dictionary and packet.get("version")==1 and packet.get("historyComplete")==true:
			var owner:=preload("res://systems/native_data/actor_name_state.gd").new()
			var captured_current:=current.duplicate();captured_current.actorNameHistoryComplete=true
			receipt.contextNameOwner=owner
			receipt.contextName=owner.capture_received(row,packet.get("state"),text,captured_current)
	return {"ready":true}
static func context_view(row: Dictionary) -> Dictionary:
	return preload("res://systems/native_data/native_token_context.gd").project(row)
static func prepare(receipt: Dictionary,text,current: Dictionary,for_log: bool=false) -> Dictionary:
	var key:="log" if for_log else "overhead"
	if receipt.has(key):return receipt[key].duplicate(true)
	# Original receiver executes BC1 before the separate BC0 log copy even
	# for channel12/no speaker/no popup. Do not accidentally omit that call
	# merely because the log is this receipt's first actual consumer.
	if for_log and int(receipt.message.channel) in LOCALIZED and not receipt.has("overhead"):
		var first:=prepare(receipt,text,current,false)
		if not first.get("ready",false):return first
	var fetched:=snapshot_raw(receipt,text)
	if not fetched.get("ready",false):return fetched
	if not receipt.has("fetchedBody"):
		var initial:={"ready":true,"body":str(receipt.raw)}
		if receipt.get("rawBytes") is PackedByteArray:initial.bytes=receipt.rawBytes.duplicate()
		if receipt.override:
			# parseFlag0 still parses an override, before message context is set.
			# Retained context/B8/BC are unknown. Pure escapes/CUSTOM and exact
			# no-match tokens may complete without those values.
			var initial_state: Dictionary=receipt.get("frame",{}).duplicate(true)
			initial_state.merge({"gender":int(receipt.gender),"localCustomTokens":receipt.tokens,"localCustomTokensComplete":receipt.tokensReady},true)
			initial_state.language=int(receipt.get("language",text.base.language))
			initial=text.parse_native_bytes(receipt.rawBytes,initial_state) if receipt.get("rawBytes") is PackedByteArray else text.parse_native(str(receipt.raw),initial_state)
		if not initial.get("ready",false):return initial
		receipt.fetchedBody=str(initial.body)
		if initial.get("bytes") is PackedByteArray:receipt.fetchedBytes=initial.bytes.duplicate()
	var body:=str(receipt.fetchedBody)
	if int(receipt.message.channel) in LOCALIZED:
		snapshot_context(receipt,text,current)
		if receipt.has("contextNameOwner") and receipt.has("context"):
			var captured_current:=current.duplicate();captured_current.actorNameHistoryComplete=true
			var name_result: Dictionary=receipt.contextNameOwner.resolve_received(receipt.contextName,text,captured_current)
			if name_result.get("ready",false):receipt.context.nativeStoredName=name_result
		var call_state: Dictionary=receipt.get("frame",{}).duplicate(true)
		call_state.merge({"nativeB8":0,"nativeBC":0 if for_log else 1,"localCustomTokens":receipt.tokens,"localCustomTokensComplete":receipt.tokensReady},true)
		call_state.language=int(receipt.get("language",text.base.language))
		if receipt.has("context"):
			call_state.context=receipt.context
			if receipt.context.is_empty() or Scope.integer(receipt.context.get("objectType"),1,4294967295) and int(receipt.context.objectType)!=5:call_state.gender=0
			elif Scope.integer(receipt.context.get("replicated",{}).get("stats",{}).get("race"),0,255):call_state.gender=int(receipt.context.replicated.stats.race)
		# Receiver77c140 invokes GetTokenObjectGender704cc0 separately before
		# each explicit copy. Initial wire/fetch gender is not that value. The
		# mapped Stats+68 BYTE is optional; absent data stays unknown, so only
		# providers that actually need it wait. See context-gender source dossier.
		var parsed: Dictionary=text.parse_native_bytes(receipt.fetchedBytes,call_state) if receipt.get("fetchedBytes") is PackedByteArray else text.parse_native(body,call_state)
		if not parsed.get("ready",false):return parsed
		body=str(parsed.body)
	var result:={"ready":true,"body":body,"forced":float(receipt.forced)}
	receipt[key]=result.duplicate(true)
	return result
