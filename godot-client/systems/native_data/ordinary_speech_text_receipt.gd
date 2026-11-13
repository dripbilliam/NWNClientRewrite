extends RefCounted
# Original77c140/9735f0: a FetchInternal result, then separate localized
# overhead/log copies. This is text presentation data, not a second world store.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const OBJECT_INVALID=0x7f000000
const CHANNELS=[8,9,10,11,12,15]
const LOCALIZED=[11,12]
static func capture(message: Dictionary,text,current: Dictionary) -> Dictionary:
	var receipt:={"message":message.duplicate(true),"tokens":text.custom_tokens.duplicate(true) if is_instance_valid(text) else {},"tokensReady":is_instance_valid(text)}
	snapshot_raw(receipt,text)
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
	var matched:=Scope.received_source(witness,row,admitted)
	if not matched.get("ready",false):
		if matched.get("mismatch",false):matched.pending=true
		return matched
	# The matched lifetime is copied once; later removal/reuse cannot change a
	# deferred named-token provider into the next object's identity.
	receipt.context=context_view(row)
	return {"ready":true}
static func context_view(row: Dictionary) -> Dictionary:
	# Only currently certified providers need names/first-class level. Copying
	# an actor's entire inventory/effects graph for each line is unnecessary.
	var view: Dictionary={}
	for key in ["id","objectType","areaId","nativeLifetime","clientKnownLifetime"]:
		if row.has(key):view[key]=row[key]
	for section in ["replicated","appearance"]:
		if not row.get(section) is Dictionary:continue
		var data: Dictionary=row[section];var selected: Dictionary={}
		if data.has("name"):selected.name=data.name.duplicate(true) if data.name is Dictionary or data.name is Array else data.name
		if section=="replicated" and data.get("stats") is Dictionary:
			var stats: Dictionary={}
			if data.stats.has("classes"):
				var classes: Variant=data.stats.classes
				stats.classes=classes.slice(0,1).duplicate(true) if classes is Array else (classes.duplicate(true) if classes is Dictionary else classes)
			# Historical decoder name: this BYTE maps Stats+68, the native
			# token-context gender getter. Actual racialType is another WORD.
			if data.stats.has("race"):stats.race=data.stats.race
			selected.stats=stats
		view[section]=selected
	return view
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
		if receipt.override:
			# parseFlag0 still parses an override, before message context is set.
			# Retained context/B8/BC are unknown. Pure escapes/CUSTOM and exact
			# no-match tokens may complete without those values.
			initial=text.parse_native(str(receipt.raw),{"gender":int(receipt.gender),"localCustomTokens":receipt.tokens,"localCustomTokensComplete":receipt.tokensReady})
		if not initial.get("ready",false):return initial
		receipt.fetchedBody=str(initial.body)
	var body:=str(receipt.fetchedBody)
	if int(receipt.message.channel) in LOCALIZED:
		snapshot_context(receipt,text,current)
		var call_state:={"nativeB8":0,"nativeBC":0 if for_log else 1,"localCustomTokens":receipt.tokens,"localCustomTokensComplete":receipt.tokensReady}
		if receipt.has("context"):
			call_state.context=receipt.context
			if receipt.context.is_empty() or Scope.integer(receipt.context.get("objectType"),1,4294967295) and int(receipt.context.objectType)!=5:call_state.gender=0
			elif Scope.integer(receipt.context.get("replicated",{}).get("stats",{}).get("race"),0,255):call_state.gender=int(receipt.context.replicated.stats.race)
		# Receiver77c140 invokes GetTokenObjectGender704cc0 separately before
		# each explicit copy. Initial wire/fetch gender is not that value. The
		# mapped Stats+68 BYTE is optional; absent data stays unknown, so only
		# providers that actually need it wait. See context-gender source dossier.
		var parsed: Dictionary=text.parse_native(body,call_state)
		if not parsed.get("ready",false):return parsed
		body=str(parsed.body)
	var result:={"ready":true,"body":body,"forced":float(receipt.forced)}
	receipt[key]=result.duplicate(true)
	return result
