extends RefCounted
# Small stored-name cache only. Actual rows remain TalkText/NetworkWorld-owned.
# No renderer callbacks, actor copies, frame processing or speech-time fetch.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const NativeParser=preload("res://systems/native_data/native_talk_parser.gd")
const SOURCE="native_actor_name_state_v1"
const RECEIVED_SOURCE="native_actor_name_received_v1"
var records: Dictionary={}
var pending: Dictionary={}
var connection:=-1
var generation:=-1
var retired_connections: Dictionary={}
var closed:=false
static func unavailable(reason: String)->Dictionary:return {"ready":false,"pending":true,"reason":reason}
static func context(current: Dictionary)->Dictionary:
	var result:=Scope.context(current.get("connection"),current.get("generation"),current.get("areaId"))
	result.history=current.get("actorNameHistoryComplete") is bool and current.actorNameHistoryComplete
	return result
static func witness(row: Dictionary,current: Dictionary)->Array:
	if not Scope.current_context(current) or not current.history or not Scope.integer(row.get("id"),0,Scope.MAX_ID) or not Scope.integer(row.get("nativeLifetime"),1,Scope.MAX_SAFE) or not Scope.integer(row.get("clientKnownLifetime"),1,Scope.MAX_SAFE):return []
	if row.get("objectType")!=5 or row.get("areaId")!=current.areaId or row.get("replicationRemoved",false) or row.get("destroyed",false):return []
	return [int(row.id),int(row.nativeLifetime),int(row.clientKnownLifetime)]
static func scope_tuple(current: Dictionary)->Array:return [current.connection,current.generation,current.areaId]
static func scalar(value: Variant)->bool:return value==null or value is String or value is int or value is float or value is bool
static func name_projection(value: Variant,depth: int=0)->Variant:
	if value is String:return value
	if not value is Dictionary:return null
	var result: Dictionary={}
	for key in ["text","strRef","gender"]:
		if value.has(key) and scalar(value[key]):result[key]=value[key]
	if depth==0:
		for key in ["firstName","lastName"]:
			if value.has(key):result[key]=name_projection(value[key],1)
	return result
static func parser_state(value: Variant)->Dictionary:
	var result: Dictionary={}
	if not value is Dictionary:return result
	for key in ["gender","nativeB8","nativeBC"]:
		if value.has(key) and scalar(value[key]):result[key]=value[key]
	if value.has("context") and value.context==null:result.context={} # Explicit certified native NULL only.
	if value.get("context") is Dictionary:
		var source: Dictionary=value.context;var projected: Dictionary={}
		for key in ["id","objectType","areaId","nativeLifetime","clientKnownLifetime"]:
			if source.has(key) and scalar(source[key]):projected[key]=source[key]
		for section in ["replicated","appearance"]:
			if not source.get(section) is Dictionary:continue
			var raw: Dictionary=source[section];var body: Dictionary={}
			if raw.has("name"):body.name=name_projection(raw.name)
			if section=="replicated" and raw.get("stats") is Dictionary:
				var stats: Dictionary={}
				if raw.stats.has("race") and scalar(raw.stats.race):stats.race=raw.stats.race
				if raw.stats.get("classes") is Array and not raw.stats.classes.is_empty():
					var entry: Dictionary={};var first: Variant=raw.stats.classes[0]
					if first is Dictionary:
						for key in ["id","level"]:
							if first.has(key) and scalar(first[key]):entry[key]=first[key]
					stats.classes=[entry]
				body.stats=stats
			projected[section]=body
		if not projected.is_empty():result.context=projected # Empty proxy is not a native NULL fact.
	return result
static func custom_state(value: Variant)->Dictionary:
	var result:={"ready":false,"tokens":{}}
	if not value is Dictionary or value.get("known")!=true:return result
	if not value.get("records") is Array:return result
	var last:=-1
	for entry in value.records:
		if not entry is Dictionary or not Scope.integer(entry.get("id"),0,2147483647) or int(entry.id)<=last or not entry.get("bytes") is Array:return result
		var bytes:=PackedByteArray()
		for byte in entry.bytes:
			if not Scope.integer(byte,0,255):return result
			bytes.append(int(byte))
		last=int(entry.id);result.tokens[last]=Binary.new(bytes).text(0,bytes.size())
	result.ready=true;return result
static func selection(value: Variant)->Dictionary:
	if not value is Dictionary or not value.get("known") is bool:return {}
	if not value.known:return {"known":false}
	if not value.get("present") is bool:return {}
	if value.present and not value.get("text") is String:return {}
	return {"known":true,"present":value.present,"text":value.text} if value.present else {"known":true,"present":false}
static func descriptor(value: Variant)->Dictionary:
	if not value is Dictionary:return {}
	if value.get("kind")=="literal" and value.get("text") is String:return {"kind":"literal","text":value.text}
	if value.get("kind")!="reference" or not Scope.integer(value.get("strRef"),0,Scope.MAX_ID) or not Scope.integer(value.get("gender"),0,1):return {}
	var selected:=selection(value.get("override"))
	return {"kind":"reference","strRef":int(value.strRef),"gender":int(value.gender),"override":selected} if not selected.is_empty() else {}
static func metadata(value: Variant,id: int)->Dictionary:
	if not value is Dictionary or value.get("source")!=SOURCE or not Scope.integer(value.get("version"),1,1) or not Scope.integer(value.get("id"),0,Scope.MAX_ID) or int(value.id)!=id or not Scope.integer(value.get("revision"),1,Scope.MAX_SAFE):return {}
	if not value.get("presence") in ["present","removed","unknown"] or not value.get("construction") is Dictionary:return {}
	var ctor: Dictionary=value.construction
	if not ctor.get("kind") in ["new","retained","unknown"] or not ctor.get("source") in ["A/type5","preexisting"] or not Scope.integer(ctor.get("sequence"),1,int(value.revision)):return {}
	var override: Variant=value.get("override")
	if not override is Dictionary or not override.get("known") is bool or override.known and not override.get("text") is String:return {}
	var saved_override:={"known":override.known}
	if override.get("text") is String:saved_override.text=override.text
	var result:={"revision":int(value.revision),"presence":str(value.presence),"construction":{"kind":str(ctor.kind),"source":str(ctor.source),"sequence":int(ctor.sequence)},"override":saved_override,"publication":null}
	if not value.has("publication"):return {}
	if value.publication==null:return result
	if not value.publication is Dictionary:return {}
	var publication: Dictionary=value.publication
	if not Scope.integer(publication.get("revision"),1,int(value.revision)) or not publication.get("current") is bool or not publication.get("environment") is Dictionary:return {}
	var first:=descriptor(publication.get("first"));var last:=descriptor(publication.get("last"))
	if first.is_empty() or last.is_empty():return {}
	if first.kind=="reference" and last.kind=="reference" and first.strRef==last.strRef and first.override!=last.override:return {}
	var environment: Dictionary=publication.environment
	result.publication={"revision":int(publication.revision),"current":publication.current,"first":first,"last":last,"environment":{"customTokens":custom_state(environment.get("customTokens")),"parserState":parser_state(environment.get("parserState"))}}
	return result
static func fresh_slots()->Dictionary:
	# Source-certified7ea230 initializes first+20/last+30/override+40 empty.
	# Only explicit construction.kind=new can reach this default.
	return {"first":{"ready":true,"text":"","source":"constructor"},"last":{"ready":true,"text":"","source":"constructor"}}
func observe(row: Dictionary,protocol_metadata: Variant,text,current: Dictionary)->Dictionary:
	if closed:return unavailable("Native actor-name owner is closed.")
	var admitted:=context(current)
	if Scope.current_context(admitted):
		if retired_connections.has(int(admitted.connection)):return unavailable("Native actor-name connection is retired.")
		if connection==int(admitted.connection) and int(admitted.generation)<generation:return unavailable("Native actor-name state update belongs to a retired generation.")
	var identity:=witness(row,admitted)
	if identity.is_empty():
		if Scope.current_context(admitted) and connection==int(admitted.connection) and generation==int(admitted.generation) and Scope.integer(row.get("id"),0,Scope.MAX_ID) and records.has(int(row.id)) and Scope.integer(row.get("nativeLifetime"),1,Scope.MAX_SAFE) and int(row.nativeLifetime)==int(records[int(row.id)].witness[1]):retire(int(row.id))
		return unavailable("Native actor-name scope/history/source witness is unavailable.")
	var id:=int(row.id);var next:=metadata(protocol_metadata,id)
	if next.is_empty():retire(id);return unavailable("Native actor-name protocol provenance is unavailable.")
	if connection!=int(admitted.connection):
		if connection>=0:retired_connections[connection]=true
		records.clear();pending.clear();generation=-1;connection=int(admitted.connection)
	generation=int(admitted.generation)
	var previous: Dictionary=records.get(id,{})
	if not previous.is_empty() and next.revision<previous.meta.revision:return unavailable("Native actor-name publication is stale.")
	if not previous.is_empty() and next.revision==previous.meta.revision and next!=previous.meta:retire(id);return unavailable("Native actor-name immutable revision changed.")
	var same_owner: bool=not previous.is_empty() and int(previous.witness[1])==int(identity[1]) and previous.meta.construction==next.construction
	if not previous.is_empty() and int(previous.witness[1])!=int(identity[1]) and previous.meta.construction==next.construction:retire(id);return unavailable("Native actor-name constructor fact belongs to a different source lifetime.")
	var old_publication: Variant=previous.get("meta",{}).get("publication")
	var same_publication: bool=same_owner and ((old_publication==null and next.publication==null) or old_publication is Dictionary and next.publication is Dictionary and old_publication.revision==next.publication.revision)
	var reader: int=text.get_instance_id() if is_instance_valid(text) else -1
	var same_binding: bool=same_owner and previous.scope==scope_tuple(admitted) and previous.witness==identity and previous.reader==reader
	var record:={"scope":scope_tuple(admitted),"witness":identity,"meta":next,"reader":reader,"slots":{},"blocked":false,"active":next.presence=="present"}
	if same_publication:
		record.slots=previous.slots.duplicate(true);record.blocked=previous.blocked
		if not same_binding and not complete_slots(record.slots):record.blocked=true
	elif next.publication==null:
		if next.construction.kind=="new":record.slots=fresh_slots()
	else:record.slots={"first":{"ready":false},"last":{"ready":false}}
	if next.publication is Dictionary and not next.publication.current:record.blocked=true
	records[id]=record
	if record.active and not record.blocked:resolve_record(id,text,admitted)
	else:pending.erase(id)
	return name(row,current)
static func complete_slots(slots: Dictionary)->bool:return slots.get("first",{}).get("ready",false) and slots.get("last",{}).get("ready",false)
func resolve_slot(record: Dictionary,key: String,text)->Dictionary:
	if record.slots.get(key,{}).get("ready",false):return record.slots[key]
	var publication: Variant=record.meta.publication
	if not publication is Dictionary:return unavailable("Native actor first/last have no certified publication.")
	var input: Dictionary=publication[key]
	if input.kind=="literal":return {"ready":true,"text":str(input.text),"source":"literal"}
	if not is_instance_valid(text) or not text.has_method("fetch_native_reference_snapshot"):return unavailable("Native selected-reference reader is unavailable.")
	var saved: Dictionary=record.slots.get(key,{})
	if not saved.has("fetched"):
		var fetched: Dictionary=text.fetch_native_reference_snapshot(input.strRef,input.gender,input.override)
		if not fetched.get("found",false):
			if fetched.get("lookupComplete",false):return {"ready":true,"text":"","source":"failed-native-fetch"}
			return unavailable(str(fetched.get("reason","Native stored-name file/provider is pending.")))
		saved.fetched=fetched.duplicate(true);record.slots[key]=saved
	var selected: Dictionary=saved.fetched;var raw:=str(selected.get("text",""))
	if not selected.get("override",false):return {"ready":true,"text":raw,"source":"base-reference","gender":selected.gender}
	var environment: Dictionary=publication.environment;var call: Dictionary=environment.parserState.duplicate(true)
	call.gender=selected.gender;call.localCustomTokens=environment.customTokens.tokens;call.localCustomTokensComplete=environment.customTokens.ready
	# Only direct P reference selections were captured. Nested named-token
	# lookups must use one of those exact snapshots or remain unavailable;
	# never let a later live override change a stored actor name.
	var selections: Dictionary={}
	for component in [publication.first,publication.last]:
		if component.kind=="reference":selections[int(component.strRef)]=component.override.duplicate(true)
	call.nativeOverrideSelections=selections
	var parsed: Dictionary=text.parse_native(raw,call)
	if not parsed.get("ready",false):return parsed
	return {"ready":true,"text":str(parsed.body),"source":"override-reference","gender":selected.gender}
func resolve_record(id: int,text,current: Dictionary)->void:
	if not records.has(id):return
	var record: Dictionary=records[id]
	if not record.active or record.blocked or record.scope!=scope_tuple(current) or not current.history or not is_instance_valid(text) or record.reader!=text.get_instance_id():pending.erase(id);return
	for key in ["first","last"]:
		var result:=resolve_slot(record,key,text)
		if not result.get("ready",false):pending[id]=true;record.reason=str(result.get("reason","Native actor-name publication is pending."));return
		record.slots[key]=result
	pending.erase(id);record.reason=""
func data_changed(text,current: Dictionary)->void:
	if closed:return
	var admitted:=context(current)
	if not Scope.current_context(admitted) or connection!=int(admitted.connection) or generation!=int(admitted.generation):return
	if not admitted.history:pending.clear();return
	for raw_id in pending.keys():
		var id:=int(raw_id);var row: Dictionary=text.objects.get(id,{}) if is_instance_valid(text) else {}
		if not records.has(id) or witness(row,admitted)!=records[id].witness or records[id].scope!=scope_tuple(admitted):pending.erase(id);continue
		resolve_record(id,text,admitted)
func name(row: Dictionary,current: Dictionary)->Dictionary:
	var admitted:=context(current);var identity:=witness(row,admitted)
	if closed or identity.is_empty() or not records.has(int(identity[0])):return unavailable("Native actor stored-name owner is unavailable.")
	var record: Dictionary=records[int(identity[0])]
	if connection!=int(admitted.connection) or generation!=int(admitted.generation) or record.scope!=scope_tuple(admitted) or record.witness!=identity or not record.active or record.blocked:return unavailable("Native actor-name binding/publication is retired or unavailable.")
	return stored_result(record)
static func stored_result(record: Dictionary)->Dictionary:
	var override: Dictionary=record.meta.override
	if not override.known:return unavailable("Native actor stored override is unknown.")
	var override_text:=str(override.get("text",""));var first: Variant=null;var last: Variant=null;var result: String
	if not override_text.is_empty():result=override_text
	else:
		if not complete_slots(record.slots):return unavailable(str(record.get("reason","Native actor stored first/last are unavailable.")))
		first=str(record.slots.first.text);last=str(record.slots.last.text);result=first+(" " if not first.is_empty() and not last.is_empty() else "")+last
	return {"ready":true,"name":result,"override":{"known":true,"text":override_text},"first":{"known":first!=null,"text":first if first!=null else ""},"last":{"known":last!=null,"text":last if last!=null else ""},"witness":record.witness.duplicate(),"scope":record.scope.duplicate(),"construction":record.meta.construction.duplicate(true),"revision":record.meta.revision,"publication":int(record.meta.publication.revision) if record.meta.publication is Dictionary else null}
func capture_received(row: Dictionary,protocol_metadata: Variant,text,current: Dictionary)->Dictionary:
	# CHAT can precede the coalesced raw P snapshot. Its private protocol state,
	# not a later raw row or this owner's newest P, defines this receipt.
	if closed:return unavailable("Native actor-name owner is closed.")
	var admitted:=context(current);var identity:=witness(row,admitted)
	if identity.is_empty() or retired_connections.has(int(admitted.connection)):return unavailable("Native received-name scope/history/source witness is unavailable.")
	var captured:=metadata(protocol_metadata,int(identity[0]))
	if captured.is_empty() or captured.presence!="present":return unavailable("Native received-name protocol provenance is unavailable.")
	var reader: int=text.get_instance_id() if is_instance_valid(text) else -1
	var record:={"scope":scope_tuple(admitted),"witness":identity.duplicate(),"meta":captured,"reader":reader,"slots":{},"blocked":false,"active":true}
	var previous: Dictionary=records.get(int(identity[0]),{})
	if not previous.is_empty() and previous.scope==record.scope and previous.witness==identity and previous.meta==captured and previous.active and not previous.blocked and (previous.reader==reader or stored_result(previous).ready):
		record.slots=previous.slots.duplicate(true)
	elif captured.publication==null:
		if captured.construction.kind=="new":record.slots=fresh_slots()
	else:record.slots={"first":{"ready":false},"last":{"ready":false}}
	if captured.publication is Dictionary and not captured.publication.current:record.blocked=true
	var receipt:={"version":1,"source":RECEIVED_SOURCE,"historyComplete":true,"scope":record.scope.duplicate(),"witness":identity.duplicate(),"record":record,"result":null}
	resolve_received(receipt,text,current)
	return receipt
func resolve_received(receipt: Dictionary,text,current: Dictionary)->Dictionary:
	# No current row, name, live CUSTOM or global cache is consulted here.
	# Resource readiness can finish only the exact captured P environment.
	if closed:return unavailable("Native actor-name owner is closed.")
	var admitted:=context(current)
	if not Scope.current_context(admitted) or retired_connections.has(int(admitted.connection)):return unavailable("Native received-name current scope is unavailable.")
	if receipt.get("version")!=1 or receipt.get("source")!=RECEIVED_SOURCE or not receipt.get("historyComplete") is bool or not receipt.historyComplete or not receipt.get("scope") is Array or receipt.scope.size()!=3 or not receipt.get("witness") is Array or receipt.witness.size()!=3 or not receipt.get("record") is Dictionary:return unavailable("Native received-name receipt is unavailable or belongs to another scope.")
	var captured_scope:=Scope.context(receipt.scope[0],receipt.scope[1],receipt.scope[2])
	if not Scope.current_context(captured_scope) or scope_tuple(captured_scope)!=scope_tuple(admitted):return unavailable("Native received-name receipt belongs to another scope.")
	for at in 3:
		if not Scope.integer(receipt.witness[at],0 if at==0 else 1,Scope.MAX_ID if at==0 else Scope.MAX_SAFE):return unavailable("Native received-name witness is malformed.")
	var record: Dictionary=receipt.record
	if record.get("scope")!=receipt.scope or record.get("witness")!=receipt.witness or not record.get("active",false) or record.get("blocked",true):return unavailable("Native received-name publication is unavailable.")
	if receipt.get("result") is Dictionary:return receipt.result.duplicate(true)
	var resolved:=stored_result(record)
	if resolved.ready:receipt.result=resolved.duplicate(true);return resolved
	if not is_instance_valid(text) or record.get("reader",-1)!=text.get_instance_id():return unavailable("Native received-name pending lookup belongs to another text owner.")
	for key in ["first","last"]:
		var part:=resolve_slot(record,key,text)
		if not part.get("ready",false):record.reason=str(part.get("reason","Native received-name component is pending."));return part.duplicate(true)
		record.slots[key]=part
	resolved=stored_result(record)
	if resolved.ready:receipt.result=resolved.duplicate(true)
	return resolved
func retire(id: int)->void:
	pending.erase(id)
	if records.has(id):records[id].active=false
func reset()->void:records.clear();pending.clear();retired_connections.clear();connection=-1;generation=-1
func close()->void:reset();closed=true
