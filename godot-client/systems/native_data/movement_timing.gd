extends RefCounted
# Diagnostic projection only. Never writes received state or invents absent fields.
const Driver=preload("res://systems/keyboard_drive.gd")
const VECTORS=["position","render","orientation","targetOrientation","previewFacing","movementDirection"]
const SCALARS=["animation","active","cursor","acceleration","correction","script","factor","newPath","driveHeld","driveSequence","driveSentSequence","driveSentRequestId","releasedTerminalCorrections","releasedTerminalSequence","walkRate","runRate","walkDistance","runDistance"]
static func integer(value: Variant,maximum: int=4294967295) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=maximum
static func sample(current: Dictionary,keyboard,connection: int,generation: int,area_id: int) -> Dictionary:
	if current.is_empty() or not current.get("state") is Dictionary or not integer(current.get("id")) or not integer(current.state.get("lifetime")):return {}
	var state: Dictionary=current.state;var view: Dictionary={}
	for field in VECTORS:
		var value: Variant=state.get(field)
		if value is Vector3:view[field]=[value.x,value.y,value.z]
	for field in SCALARS:
		if state.has(field):view[field]=state[field]
	if current.get("position") is Vector3:view.received_position=[current.position.x,current.position.y,current.position.z]
	var input: Dictionary={}
	if is_instance_valid(keyboard):
		input={"flags":Driver.flags(keyboard.held,keyboard.walking or not keyboard.walk_forward_held.is_empty()),"moving":keyboard.moving,"request_serial":keyboard.request_serial,"accepted_serial":keyboard.accepted_serial}
	return {"kind":"movement-sample","connection":connection,"generation":generation,"areaId":area_id,"actorId":current.id,"lifetime":state.lifetime,"native_ticks_us":Time.get_ticks_usec(),"native_frame":Engine.get_process_frames(),"state":view,"keyboard":input}
static func replay(value: Dictionary,current: Dictionary,keyboard,predict: Callable,end_prediction: Callable) -> Dictionary:
	# Caller additionally admits only offline-replay + movement-timing, and checks
	# connection, generation and area. Replay invokes the ordinary preview method;
	# captured positions are evidence, never a forced pose or authoritative write.
	if current.is_empty() or not is_instance_valid(keyboard) or not current.get("state") is Dictionary:return {"accepted":false,"reason":"no controlled context"}
	if not integer(value.get("actorId")) or not integer(value.get("lifetime")) or int(value.actorId)!=int(current.id) or int(value.lifetime)!=int(current.state.get("lifetime",-1)):return {"accepted":false,"reason":"retired actor lifetime"}
	if not integer(value.get("requestId")) or int(value.requestId)<=keyboard.request_serial:return {"accepted":false,"reason":"retired request"}
	var operation: String=str(value.get("operation",""));var flags:=0;var heading:=-1
	if operation=="drive":
		if not integer(value.get("flags"),63) or int(value.flags)==0 or not integer(value.get("heading"),3599) or not value.get("transmit") is bool:return {"accepted":false,"reason":"invalid drive"}
		flags=int(value.flags);heading=int(value.heading) if value.transmit else -1
	elif operation=="turn":
		var recorded: Variant=value.get("movementTrace",{}).get("keyboard",{}).get("flags")
		if not integer(recorded,63) or int(recorded) not in [16,32]:return {"accepted":false,"reason":"missing turn decision"}
		flags=int(recorded)
	elif operation!="stop":return {"accepted":false,"reason":"unsupported movement operation"}
	if operation=="stop" and not end_prediction.is_valid() or operation!="stop" and not predict.is_valid():return {"accepted":false,"reason":"prediction owner unavailable"}
	keyboard.owner_identity=str(current.identity);keyboard.minimum_serial=mini(keyboard.minimum_serial,int(value.requestId));keyboard.request_serial=int(value.requestId)
	keyboard.moving=operation=="drive";keyboard.last_flags=flags
	if operation=="stop":end_prediction.call(int(current.id))
	else:predict.call(int(current.id),flags,heading)
	return {"accepted":true,"operation":operation,"requestId":value.requestId}
