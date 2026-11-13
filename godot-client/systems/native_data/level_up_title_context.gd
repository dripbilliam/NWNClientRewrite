extends RefCounted
# Detached presentation context only. No canonical level-up snapshot fields.
const Format=preload("res://systems/native_data/level_up_title.gd")
const Received=preload("res://systems/native_data/level_up_received_context.gd")
const Scalar=preload("res://systems/native_data/level_up_class_state.gd")
var identity: Array=[]
var token: int=-1
var native_lifetime: int=-1
var known_lifetime: int=-1
var captured_name: Variant=null
var frozen: Dictionary={}
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func c_string(value: Variant) -> bool:return value is String and not value.to_utf8_buffer().has(0)
static func name(parts: Variant) -> Dictionary:
	if not parts is Dictionary or not c_string(parts.get("override")):return pending("Private name override availability is unknown.")
	#7f3f00 reads neither split string when the override length is nonzero.
	if not parts.override.is_empty():return {"ready":true,"text":parts.override,"branch":"override"}
	if not c_string(parts.get("first")) or not c_string(parts.get("last")):return pending("Required private split-name strings are unavailable.")
	return {"ready":true,"text":parts.first+(" " if not parts.first.is_empty() and not parts.last.is_empty() else "")+parts.last,"branch":"split"}
static func localized(value: Variant,text) -> Dictionary:
	if not value is Dictionary:return pending("Received localized name is unavailable.")
	var keys: Array=value.keys();keys.sort()
	if keys==["text"]:
		return {"ready":true,"text":value.text} if c_string(value.text) else pending("Received literal name is malformed.")
	if keys!=["gender","strRef"] or not Scalar.integer(value.gender,0,1) or not Scalar.integer(value.strRef,0,4294967295):return pending("Received localized-name branch is malformed.")
	if text==null or not text.has_method("fetch_reference") or not text.has_method("raw"):return pending("Active name text resolver is unavailable.")
	var reference: Dictionary=text.fetch_reference(int(value.strRef),int(value.gender))
	if not reference.get("found",false):return pending("Active name TLK reference is not available.")
	var resolved: Variant=text.raw(value,int(value.gender))
	return {"ready":true,"text":resolved} if c_string(resolved) else pending("Resolved private name is malformed.")
static func project(raw: Variant,text) -> Dictionary:
	if not raw is Dictionary:return pending("Received name branch was not supplied.")
	var keys: Array=raw.keys();keys.sort()
	if keys==["text"]:
		if not c_string(raw.text):return pending("Received override name is malformed.")
		if raw.text.is_empty():return pending("An empty override does not disclose the required split names.")
		return {"ready":true,"branch":"override","parts":{"override":raw.text},"known":{"override":true,"first":false,"last":false}}
	if keys!=["firstName","lastName"]:return pending("Received name schemas are missing or ambiguous.")
	var first:=localized(raw.firstName,text);var last:=localized(raw.lastName,text)
	if not first.ready:return first
	if not last.ready:return last
	return {"ready":true,"branch":"split","parts":{"first":first.text,"last":last.text,"override":""},"known":{"override":true,"first":true,"last":true}}
static func compose(parts: Variant,classes: Variant,caption: Variant,tables: Dictionary,text) -> Dictionary:
	if not c_string(caption) or "\n" in caption or "\r" in caption:return pending("Actual first caption line is unavailable.")
	var full:=name(parts)
	if not full.ready:return full
	var summary:=Format.classes(classes,tables,text)
	if not summary.ready:return summary
	return {"ready":true,"text":(full.text+"   " if not full.text.is_empty() else "")+summary.text+"        "+caption,"name":full.text,"classes":summary.text,"branch":full.branch}
func capture(actor: Dictionary,scope: Array,begin_token: int,text) -> Dictionary:
	close()
	if not Received.actor_valid(actor,scope) or not Scalar.integer(begin_token,0,9007199254740991):return pending("Controlled private title identity is unavailable.")
	identity=scope.duplicate();token=begin_token;native_lifetime=int(actor.nativeLifetime);known_lifetime=int(actor.clientKnownLifetime)
	var replicated: Variant=actor.get("replicated")
	captured_name=replicated.get("name").duplicate(true) if replicated is Dictionary and replicated.get("name") is Dictionary else null
	return resolve(actor,scope,begin_token,text)
func resolve(actor: Dictionary,scope: Array,begin_token: int,text) -> Dictionary:
	if identity!=scope or token!=begin_token or not Received.actor_valid(actor,scope) or actor.nativeLifetime!=native_lifetime or actor.clientKnownLifetime!=known_lifetime:
		close();return pending("The private title actor/menu lifetime retired.")
	if frozen.is_empty():
		var value:=project(captured_name,text)
		if not value.ready:return value
		frozen=value.duplicate(true)
	return frozen.duplicate(true)
func close() -> void:
	identity=[];token=-1;native_lifetime=-1;known_lifetime=-1;captured_name=null;frozen={}
