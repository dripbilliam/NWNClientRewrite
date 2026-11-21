extends RefCounted
# Direct transport owner for the native journal open/close pair. Journal data
# and panel visibility stay with the server/UI; this only orders packet sends.
signal advanced
const Hud=preload("res://systems/native_data/native_network_hud.gd")
const OBJECT_INVALID:=0x7f000000
const MAX_PENDING:=64
var state: Dictionary={}
var pending:=0

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func safe_integer(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<=9007199254740991.0

static func same_scope(a: Dictionary,b: Dictionary)->bool:
	return a.get("world")==b.get("world") and a.get("peer")==b.get("peer") and a.get("actor")==b.get("actor") and a.get("areaId")==b.get("areaId") and a.get("areaGeneration")==b.get("areaGeneration")

static func journal_gui_event_request(opened: Variant,include_position: Variant)->Dictionary:
	if not opened is bool or not include_position is bool:return {"error":"Invalid native journal GUI event"}
	# NativeMessageWriter(1), GUI 53/1, WORD event 10/11, WORD selection 0,
	# OBJECT_INVALID, and three zero float32 coordinates on newer builds.
	return {"bytes":Hud.gui_request(10 if opened else 11,0,OBJECT_INVALID,include_position)}

func current_error(token: RefCounted,logical: Dictionary,assert_current: Callable)->String:
	if state.get("token")!=token or bool(logical.get("cancelled",false)):
		return "Native journal owner or scope has retired"
	var current: Variant=assert_current.call()
	if current is Dictionary and current.has("error"):return str(current.error)
	if current is bool and not current:return "Native journal owner or scope has retired"
	return ""

func transition(request: Dictionary,scope: Dictionary,assert_current: Callable,send: Callable)->Dictionary:
	var opened: Variant=request.get("open")
	var include_position: Variant=request.get("includePosition")
	var lifetime: Variant=request.get("journalLifetime")
	if not opened is bool or not include_position is bool or not safe_integer(lifetime) or lifetime<=0:
		return {"error":"Invalid native journal lifetime"}
	if scope.get("world")==null or scope.get("peer")==null or scope.get("actor")==null or not uint(scope.get("areaId")) or not safe_integer(scope.get("areaGeneration")) or scope.areaGeneration<0 or not assert_current.is_valid() or not send.is_valid():
		return {"error":"Invalid native journal transport scope"}
	var first: Variant=assert_current.call()
	if first is Dictionary and first.has("error"):return {"error":str(first.error)}
	if first is bool and not first:return {"error":"Native journal owner or scope has retired"}
	if state.is_empty() or not same_scope(state.scope,scope):
		state={"token":RefCounted.new(),"scope":{"world":scope.world,"peer":scope.peer,"actor":scope.actor,"areaId":scope.areaId,"areaGeneration":scope.areaGeneration},"latest":0,"wanted":false,"logical":{},"next":0,"completed":0}
	var owner: Dictionary=state
	var token: RefCounted=owner.token
	var serial:=int(lifetime)
	if serial<int(owner.latest) or not opened and serial!=int(owner.latest):
		return {"error":"Native journal owner or scope has retired"}
	if serial==int(owner.latest):
		if opened and not bool(owner.wanted):return {"error":"Native journal owner or scope has retired"}
		if opened==bool(owner.wanted):return {"sent":false,"duplicate":true}
	if pending>=MAX_PENDING:return {"error":"Native journal transition queue is full"}
	var logical: Dictionary=owner.logical
	if opened:
		if not logical.is_empty() and not bool(logical.get("closed",false)):logical.cancelled=true
		logical={"lifetime":serial,"closed":false,"cancelled":false}
		owner.logical=logical
		owner.latest=serial
	else:
		if logical.is_empty() or bool(logical.get("closed",false)):
			return {"error":"Native journal owner or scope has retired"}
		logical.closed=true
	owner.wanted=opened
	pending+=1
	owner.next=int(owner.next)+1
	var turn:=int(owner.next)
	var gui: Dictionary=journal_gui_event_request(opened,include_position)
	var packets: Array=[Hud.journal_window_request(true),gui.bytes] if opened else [gui.bytes,Hud.journal_window_request(false)]
	while int(owner.completed)<turn-1:await advanced
	var outcome: Dictionary={"sent":true}
	for packet in packets:
		var error:=current_error(token,logical,assert_current)
		if not error.is_empty():
			outcome={"error":error}
			break
		var result: Variant=await send.call(packet)
		if result is Dictionary and result.has("error"):
			outcome={"error":str(result.error)}
			break
		if result is bool and not result:
			outcome={"error":"Native journal send failed"}
			break
		error=current_error(token,logical,assert_current)
		if not error.is_empty():
			outcome={"error":error}
			break
	pending-=1
	owner.completed=turn
	advanced.emit()
	return outcome
