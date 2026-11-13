extends RefCounted
# Event-bound waiting for an independent received S9c row. This never changes
# the network transaction/comparison snapshot and exposes no editable draft.
const Received=preload("res://systems/native_data/level_up_received_context.gd")
const Scalar=preload("res://systems/native_data/level_up_class_state.gd")
var armed:=false
var matched:=false
var identity: Array=[]
var token:=-1
var serial:=-1
var native_lifetime: Variant=null
var known_lifetime: Variant=null
var original: Dictionary={}
static func unavailable(reason: String) -> Dictionary:return {"ready":false,"waiting":false,"reason":reason}
static func pending(reason: String) -> Dictionary:return {"ready":false,"waiting":true,"reason":reason}
func capture(value: Dictionary,scope: Array,request: int,actor: Dictionary) -> Dictionary:
	if armed:return unavailable("Another received-context wait already owns this entry.")
	close()
	if not Scalar.integer(value.get("token"),0,9007199254740991) or not value.get("snapshot") is Dictionary or not Received.actor_valid(actor,scope) or value.snapshot.get("actorId")!=scope[2]:return unavailable("Received level-up context identity is unavailable.")
	var context: Variant=value.get("draftContext")
	if not context is Dictionary or not context.has("baseFortitude") or context.baseFortitude!=null:return unavailable("This entry does not have missing received Fortitude.")
	armed=true;identity=scope.duplicate();token=int(value.token);serial=request;native_lifetime=actor.nativeLifetime;known_lifetime=actor.clientKnownLifetime;original=value.duplicate(true)
	# The native row may have reached Godot just before the asynchronous begin
	# reply. Both absent→received and already-received orderings use this fence.
	return observe(scope,token,request,actor)
func observe(scope: Array,current_token: int,request: int,actor: Dictionary) -> Dictionary:
	if not armed:return unavailable("No received-context wait is active.")
	if identity!=scope or token!=current_token or serial!=request or not Received.actor_valid(actor,scope) or actor.nativeLifetime!=native_lifetime or actor.clientKnownLifetime!=known_lifetime:
		close();return unavailable("The received character context retired.")
	var snapshot:=Received.snapshot(actor)
	if not snapshot.ready:
		if matched:close();return unavailable("The received level-up comparison became unavailable.")
		return pending("Waiting for matching character data…")
	if snapshot.value!=original.snapshot:
		if matched:close();return unavailable("The received level-up comparison changed.")
		return pending("Waiting for matching character data…")
	matched=true
	if Received.fortitude(actor)==null:return pending("Waiting for character data…")
	return {"ready":true,"waiting":false,"reason":""}
func consume(scope: Array,current_token: int,request: int,actor: Dictionary) -> Dictionary:
	var observed:=observe(scope,current_token,request,actor)
	if not observed.ready:return observed
	var value:=original.duplicate(true);value.draftContext.baseFortitude=int(Received.fortitude(actor));close()
	return {"ready":true,"waiting":false,"result":value,"serverAcknowledged":false,"sends":0}
func close() -> void:
	armed=false;matched=false;identity=[];token=-1;serial=-1;native_lifetime=null;known_lifetime=null;original={}
