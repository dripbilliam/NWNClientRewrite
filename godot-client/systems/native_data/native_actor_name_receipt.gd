extends RefCounted
# Direct protocol-only staging of network_actor_name_state.js. Callers publish
# the returned value only after the surrounding World transaction commits.
const SLOT:="nativeActorNameState"
const SOURCE:="native_actor_name_state_v1"
const MAX_SAFE:=9007199254740991

static func _ok(value: Variant) -> Dictionary:return {"ok":true,"value":value}
static func _fail(reason: String) -> Dictionary:return {"ok":false,"error":"Invalid native actor-name "+reason}
static func _object(value: Variant) -> bool:return value is Dictionary
static func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=low and value<=high
static func _positive(value: Variant) -> bool:return _integer(value,1,MAX_SAFE)
static func _uint(value: Variant) -> bool:return _integer(value,0,0xffffffff)
static func _keys_allowed(value: Dictionary,allowed: Array) -> bool:
	for key in value.keys():
		if not allowed.has(key):return false
	return true
static func _same(a: Variant,b: Variant) -> bool:return JSON.stringify(a,"",false)==JSON.stringify(b,"",false)

static func wire(value: Variant,partial: bool=false) -> Dictionary:
	if not _object(value):return _fail("name declaration")
	var text:bool=value.has("text")
	var ref:bool=value.has("strRef")
	if text:
		if ref or not value.text is String:return _fail("literal")
		return _ok({"text":value.text})
	if ref:
		if not _uint(value.strRef) or not _integer(value.get("gender"),0,1):return _fail("localized reference")
		return _ok({"strRef":value.strRef,"gender":value.gender})
	if value.has("firstName") or value.has("lastName"):
		if not partial and (not value.has("firstName") or not value.has("lastName")):return _fail("split declaration")
		var out:Dictionary={}
		for key in ["firstName","lastName"]:
			if value.has(key):
				var part:Dictionary=wire(value[key])
				if not part.ok:return part
				out[key]=part.value
		return _ok(out)
	if partial and value.is_empty():return _ok({})
	return _fail("name declaration")

static func parser_context(value: Variant) -> Dictionary:
	if value==null:return _ok(null)
	if not _object(value):return _fail("parser context")
	if not _keys_allowed(value,["id","objectType","areaId","nativeLifetime","clientKnownLifetime","replicated","appearance"]):return _fail("parser context fields")
	var out:Dictionary={}
	for key in ["id","objectType","areaId","nativeLifetime","clientKnownLifetime"]:
		if value.has(key):
			if value[key]!=null and not _integer(value[key],0,MAX_SAFE):return _fail("parser context identity")
			out[key]=value[key]
	for section in ["replicated","appearance"]:
		if not value.has(section):continue
		var input:Variant=value[section]
		if not _object(input):return _fail("parser context section")
		if not _keys_allowed(input,["name","stats"]):return _fail("parser context section fields")
		var output:Dictionary={}
		if input.has("name"):
			var parsed_name:Dictionary=wire(input.name,true)
			if not parsed_name.ok:return parsed_name
			output.name=parsed_name.value
		if input.has("stats"):
			if not _object(input.stats):return _fail("parser context stats")
			if not _keys_allowed(input.stats,["race","racialType","classes"]):return _fail("parser context stat fields")
			var stats:Dictionary={}
			for key in ["race","racialType"]:
				if input.stats.has(key):
					if not _uint(input.stats[key]):return _fail("parser context stat")
					stats[key]=input.stats[key]
			if input.stats.has("classes"):
				if not input.stats.classes is Array or input.stats.classes.size()>8:return _fail("parser context classes")
				var classes:Array=[]
				for entry in input.stats.classes:
					if not _object(entry):return _fail("parser context class")
					var row:Dictionary={}
					for key in entry.keys():
						if not ["id","level"].has(key) or not _uint(entry[key]):return _fail("parser context class field")
						row[key]=entry[key]
					classes.append(row)
				stats.classes=classes
			output.stats=stats
		out[section]=output
	return _ok(out)

static func parser_state(value: Variant,absent: bool=false) -> Dictionary:
	if absent:return _ok({})
	if not _object(value):return _fail("parser state")
	if not _keys_allowed(value,["gender","nativeB8","nativeBC","context"]):return _fail("parser state fields")
	var out:Dictionary={}
	for key in ["gender","nativeB8","nativeBC"]:
		if value.has(key):
			if not _uint(value[key]):return _fail("parser state value")
			out[key]=value[key]
	if value.has("context"):
		var context:Dictionary=parser_context(value.context)
		if not context.ok:return context
		out.context=context.value
	return _ok(out)

static func selection(ref: Variant,overrides: Variant,absent: bool=false) -> Dictionary:
	if ref==0xffffffff:return _ok({"known":true,"present":false})
	if absent:return _ok({"known":false})
	if not overrides is Dictionary:return _fail("override owner")
	if not overrides.has(ref):return _ok({"known":true,"present":false})
	var text:Variant=overrides[ref]
	if not text is String:return _fail("override text")
	return _ok({"known":true,"present":true,"text":text})

static func descriptor(value: Variant,overrides: Variant,overrides_absent: bool=false) -> Dictionary:
	var parsed:Dictionary=wire(value)
	if not parsed.ok:return parsed
	var input:Dictionary=parsed.value
	if input.has("text"):return _ok({"kind":"literal","text":input.text})
	if not input.has("strRef"):return _fail("component")
	var selected:Dictionary=selection(input.strRef,overrides,overrides_absent)
	if not selected.ok:return selected
	return _ok({"kind":"reference","strRef":input.strRef,"gender":input.gender,"override":selected.value})

static func custom_records(input: Variant,absent: bool=false) -> Dictionary:
	if absent:return _ok({"known":false})
	if not _object(input) or not input.get("records") is Array:return _fail("CUSTOM owner")
	var previous:int=-1
	var records:Array=[]
	for record in input.records:
		if not _object(record) or not _integer(record.get("id"),0,0x7fffffff) or int(record.id)<=previous:return _fail("CUSTOM record")
		previous=int(record.id)
		var bytes:Variant=record.get("bytes")
		if not bytes is PackedByteArray and not bytes is Array:return _fail("CUSTOM bytes")
		var copy:Array=[]
		for byte in bytes:
			if not _integer(byte,0,255):return _fail("CUSTOM byte")
			copy.append(byte)
		records.append({"id":record.id,"bytes":copy})
	return _ok({"known":true,"records":records})

static func equal_custom(snapshot: Dictionary,input: Variant,absent: bool=false) -> bool:
	if not snapshot.get("known",false):return absent
	if not _object(input) or not input.get("records") is Array or input.records.size()!=snapshot.records.size():return false
	for index in range(snapshot.records.size()):
		var row:Dictionary=snapshot.records[index]
		var other:Variant=input.records[index]
		if not _object(other) or row.id!=other.get("id") or (not other.get("bytes") is PackedByteArray and not other.get("bytes") is Array):return false
		if row.bytes.size()!=other.bytes.size():return false
		for byte_index in range(row.bytes.size()):
			if row.bytes[byte_index]!=other.bytes[byte_index]:return false
	return true

static func needs_environment(components: Array) -> bool:
	for value in components:
		if value.kind=="reference" and (not value.override.known or value.override.get("present",false)):return true
	return false

static func valid_selection(value: Variant) -> bool:
	return _object(value) and value.get("known") is bool and (not value.known or value.get("present") is bool and (not value.present or value.get("text") is String))
static func valid_descriptor(value: Variant) -> bool:
	return _object(value) and ((value.get("kind")=="literal" and value.get("text") is String) or (value.get("kind")=="reference" and _uint(value.get("strRef")) and _integer(value.get("gender"),0,1) and valid_selection(value.get("override"))))
static func valid_custom(value: Variant) -> bool:
	if not _object(value) or not value.get("known") is bool:return false
	if not value.known:return true
	if not value.get("records") is Array:return false
	var previous:int=-1
	for row in value.records:
		if not _object(row) or not _integer(row.get("id"),0,0x7fffffff) or int(row.id)<=previous or not row.get("bytes") is Array:return false
		previous=int(row.id)
		for byte in row.bytes:
			if not _integer(byte,0,255):return false
	return true

static func valid(value: Variant) -> bool:
	if not _object(value) or value.get("version")!=1 or value.get("source")!=SOURCE or not _uint(value.get("id")) or not _positive(value.get("revision")) or not ["present","removed","unknown"].has(value.get("presence")):return false
	if not value.has("construction") or not value.has("override") or not value.has("publication"):return false
	var construction:Variant=value.construction
	var override:Variant=value.override
	var publication:Variant=value.publication
	if not _object(construction) or not ["new","retained","unknown"].has(construction.get("kind")) or not ["A/type5","preexisting"].has(construction.get("source")) or not _positive(construction.get("sequence")) or construction.sequence>value.revision:return false
	if not _object(override) or not override.get("known") is bool or (override.has("text") and not override.text is String) or (override.known and not override.has("text")):return false
	if publication==null:return true
	if not _object(publication) or not _positive(publication.get("revision")) or publication.revision>value.revision or not publication.get("current") is bool or not valid_descriptor(publication.get("first")) or not valid_descriptor(publication.get("last")):return false
	var environment:Variant=publication.get("environment")
	if not _object(environment) or not _object(environment.get("customTokens")) or not _object(environment.get("parserState")):return false
	if not valid_custom(environment.customTokens):return false
	var parsed:Dictionary=parser_state(environment.parserState)
	return parsed.ok and _same(environment.parserState,parsed.value)

static func sequence(boundary: Dictionary,current: Variant) -> Dictionary:
	if not _positive(boundary.get("sequence")) or (current!=null and boundary.sequence<=current.revision):return _fail("accepted sequence")
	return _ok(boundary.sequence)

static func begin(id: Variant,revision: Variant,kind: String,source: String) -> Dictionary:
	return {"version":1,"source":SOURCE,"id":id,"revision":revision,"presence":"present","construction":{"kind":kind,"source":source,"sequence":revision},"override":{"known":false},"publication":null}

static func stage(current: Variant,record: Variant,boundary: Variant={},environment: Variant={}) -> Dictionary:
	if current!=null and not valid(current):return _fail("current state")
	if not _object(record) or not _object(boundary) or not _object(environment):return _fail("input")
	if record.get("objectType")!=5 or not ["create","delete","appearance"].has(record.get("action")):return _ok(current)
	if not _uint(record.get("id")) or (current!=null and current.id!=record.id):return _fail("source identity")
	if record.action=="delete":
		if current==null or current.presence=="removed":return _ok(current)
		var accepted:Dictionary=sequence(boundary,current)
		if not accepted.ok:return accepted
		var removed:Dictionary=current.duplicate(false)
		removed.revision=accepted.value
		removed.presence="removed"
		return _ok(removed)
	if record.action=="create":
		if not ["absent","present","unknown"].has(boundary.get("typedOwner")) or not boundary.get("historyComplete") is bool:return _fail("construction boundary")
		if current==null:
			var fresh:bool=boundary.historyComplete and boundary.typedOwner=="absent"
			var accepted:Dictionary=sequence(boundary,null)
			if not accepted.ok:return accepted
			var kind:String="new" if fresh else ("retained" if boundary.typedOwner=="present" else "unknown")
			var out:Dictionary=begin(record.id,accepted.value,kind,"A/type5")
			if fresh:out.override={"known":true,"text":""}
			return _ok(out)
		if boundary.typedOwner=="present" and current.presence=="present":return _ok(current)
		var accepted:Dictionary=sequence(boundary,current)
		if not accepted.ok:return accepted
		var out:Dictionary=current.duplicate(false)
		out.revision=accepted.value
		out.presence="present"
		if boundary.typedOwner=="present":return _ok(out)
		# D+A can be reuse or reconstruction; retain bytes but revoke currentness.
		if current.override.known and current.override.text!="":
			out.override=current.override.duplicate(false)
			out.override.known=false
		if current.publication!=null:
			out.publication=current.publication.duplicate(false)
			out.publication.current=false
		return _ok(out)
	if not _uint(record.get("mask")) or record.mask>0xffff:return _fail("appearance mask")
	var has_name:bool=_object(record.get("state")) and record.state.has("name")
	if (int(record.mask)&0x400)==0:
		if has_name:return _fail("appearance name mask")
		return _ok(current)
	if not has_name:return _fail("appearance name")
	if not ["absent","present","unknown"].has(boundary.get("typedOwner")):return _fail("appearance boundary")
	if boundary.typedOwner!="present":return _ok(current)
	var parsed_name:Dictionary=wire(record.state.name)
	if not parsed_name.ok:return parsed_name
	var name:Dictionary=parsed_name.value
	var overrides:Variant=environment.get("overrides")
	var first:Dictionary=descriptor(name if name.has("text") else name.get("firstName"),overrides,not environment.has("overrides"))
	if not first.ok:return first
	var last:Dictionary=descriptor({"text":""} if name.has("text") else name.get("lastName"),overrides,not environment.has("overrides"))
	if not last.ok:return last
	var needed:bool=needs_environment([first.value,last.value])
	var parse:Variant={}
	if needed:
		var parsed_state:Dictionary=parser_state(environment.get("parserState"),not environment.has("parserState"))
		if not parsed_state.ok:return parsed_state
		parse=parsed_state.value
	var prior:Variant=current.publication if current!=null else null
	if current!=null and current.presence=="present" and prior!=null and prior.current and _same(first.value,prior.first) and _same(last.value,prior.last) and _same(parse,prior.environment.parserState) and (not needed or equal_custom(prior.environment.customTokens,environment.get("customTokens"),not environment.has("customTokens"))):return _ok(current)
	var accepted:Dictionary=sequence(boundary,current)
	if not accepted.ok:return accepted
	var out:Dictionary=current.duplicate(false) if current!=null else begin(record.id,accepted.value,"unknown","preexisting")
	out.revision=accepted.value
	out.presence="present"
	var custom:Variant={"known":false}
	if needed:
		var captured:Dictionary=custom_records(environment.get("customTokens"),not environment.has("customTokens"))
		if not captured.ok:return captured
		custom=captured.value
	out.publication={"revision":accepted.value,"current":true,"first":first.value,"last":last.value,"environment":{"customTokens":custom,"parserState":parse}}
	return _ok(out)
