extends RefCounted
# Original server 53/2 and 36/4. Panel eligibility and blocked-target state
# belong to the connection UI owner, not this byte decoder.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
const INVALID=0x7f000000
const CONTEXT_SOURCES={"ground":[16,-1],"trigger":[17,7],"creature":[18,5],"item":[19,6],"placeable":[20,9],"door":[21,10]}

static func valid_uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=0xffffffff

static func attempt_request(panel_id: Variant,target_id: Variant,include_position: Variant)->Dictionary:
	if not valid_uint(panel_id) or int(panel_id)>22 or int(panel_id) in [0,1,3] or not valid_uint(target_id) or not include_position is bool:
		return {"error":"Invalid native blocked-panel attempt"}
	return _outbound(14,int(panel_id),int(target_id),[0.0,0.0,0.0],bool(include_position))

static func context_request(source_kind: Variant,target_id: Variant,position: Variant,include_position: Variant)->Dictionary:
	if not source_kind is String or not CONTEXT_SOURCES.has(source_kind) or not valid_uint(target_id) or not include_position is bool or not position is Array or position.size()!=3:
		return {"error":"Invalid native world-context GUI event"}
	var source: Array=CONTEXT_SOURCES[source_kind]
	if source_kind=="ground" and int(target_id)!=INVALID or source_kind!="ground" and int(target_id)==INVALID:
		return {"error":"Invalid native world-context target"}
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or not is_finite(float(PackedFloat32Array([float(value)])[0])) or source_kind!="ground" and float(value)!=0.0:
			return {"error":"Invalid native world-context position"}
	return _outbound(26,int(source[0])-15,int(target_id),position,bool(include_position))

static func _outbound(command: int,selection: int,target_id: int,position: Array,include_position: bool)->Dictionary:
	var boundary:=27 if include_position else 15
	var bytes:=PackedByteArray([112,53,1]);bytes.resize(boundary+1)
	bytes.encode_u32(3,boundary)
	bytes.encode_u16(7,command)
	bytes.encode_u16(9,selection)
	bytes.encode_u32(11,target_id)
	if include_position:
		for index in 3:bytes.encode_float(15+index*4,float(position[index]))
	bytes[boundary]=0x60
	return {"bytes":bytes}

static func accepted(major: int,minor: int)->bool:
	return major==53 and minor==2 or major==36 and minor==4

static func decode_packet(packet: PackedByteArray,build: Dictionary={})->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native GUI access envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	if major==53 and (not build.has("number") or not build.has("revision") or not build.has("postfix")):
		return {"error":"Native GUI access server build is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native GUI access stream: "+reader.error}
	var panel_id:=reader.signed_dword()
	var message: Dictionary={"major":major,"minor":minor,"panelId":panel_id}
	if major==53:
		message.kind="gui-panel-disabled"
		message.disabled=reader.boolean()
		var target_received:=Area.at_least(build,35)
		message.targetId=reader.object_id() if target_received else INVALID
		message.targetSource="received" if target_received else "legacy_protocol_default"
	else:message.kind="gui-panel-popup"
	if not reader.finished():
		return {"error":"Invalid native GUI access fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message

class State extends RefCounted:
	# Port of network_gui_panel_access.js::GuiPanelAccess. The decoder has no
	# authority to invent actor/area context; Session binds that after applying
	# the received packet to its canonical world object registry.
	const EVENT_LIMIT:=32
	const MAX_SERIAL:=9007199254740991
	var disabled: Dictionary={}
	var events: Array[Dictionary]=[]
	var sequence:=0
	var last_input: Variant=null
	var last_sequence:=0
	var actor: Variant=null
	var actor_id: Variant=null
	var actor_lifetime: Variant=null
	var control_lifetime:=0
	var cached: Dictionary={}

	static func integer(value: Variant,maximum: int=MAX_SERIAL)->bool:
		return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=maximum
	static func panel(value: Variant)->bool:return integer(value,22)
	static func uint(value: Variant)->bool:return integer(value,4294967295)

	func observe(message: Dictionary)->Dictionary:
		last_input=null;last_sequence=0
		if not panel(message.get("panelId")):return {"accepted":false,"reason":"Unsupported native GUI panel ID."}
		if sequence>=MAX_SERIAL:return {"accepted":false,"reason":"Native GUI access serial exhausted."}
		var panel_id:=int(message.panelId)
		var event: Dictionary={"panelId":panel_id}
		match message.get("kind"):
			"gui-panel-disabled":
				if not message.get("disabled") is bool or not uint(message.get("targetId")) or message.get("targetSource") not in ["received","legacy_protocol_default"] or message.get("targetSource")=="legacy_protocol_default" and int(message.targetId)!=0x7f000000:
					return {"accepted":false,"reason":"Invalid received native GUI access fields."}
				var target_id:=int(message.targetId)
				if message.disabled:
					if not disabled.has(panel_id):disabled[panel_id]={}
					disabled[panel_id][target_id]=str(message.targetSource)
				elif disabled.has(panel_id):
					disabled[panel_id].erase(target_id)
					if disabled[panel_id].is_empty():disabled.erase(panel_id)
				event.merge({"kind":"disabled","disabled":bool(message.disabled),"targetId":target_id,"targetSource":str(message.targetSource)})
			"gui-panel-popup":event.merge({"kind":"popup","scope":null})
			_:return {"accepted":false,"reason":"Unsupported native GUI access instruction."}
		sequence+=1;event.sequence=sequence;events.append(event)
		if events.size()>EVENT_LIMIT:events.pop_front()
		last_input=message;last_sequence=sequence;cached={}
		return {"accepted":true,"sequence":sequence}

	func context(value: Dictionary)->Dictionary:
		var id: Variant=value.get("actorId")
		var candidate: Variant=value.get("actor")
		var known: bool=candidate is Dictionary and candidate.get("objectType")==5 and candidate.get("id")==id and uint(id) and int(id)!=0x7f000000
		var next_actor: Variant=candidate if known else null
		var next_id: Variant=int(id) if known else null
		# NativeNetworkWorld deep-copies its registry on ordinary updates. Its
		# receive-lifetime pair is stable across those copies and changes when an
		# object instance is replaced. Source-oracle actors lack this pair, so
		# retain the original JS reference-identity rule for those fixtures.
		var next_lifetime: Variant=null
		if known and integer(candidate.get("nativeLifetime")) and int(candidate.nativeLifetime)>0 and integer(candidate.get("clientKnownLifetime")) and int(candidate.clientKnownLifetime)>0:
			next_lifetime=[int(candidate.nativeLifetime),int(candidate.clientKnownLifetime)]
		var changed: bool=next_id!=actor_id
		if next_lifetime!=null or actor_lifetime!=null:
			changed=changed or next_lifetime!=actor_lifetime
		else:
			changed=changed or not is_same(next_actor,actor)
		if changed:control_lifetime+=1
		actor=next_actor;actor_id=next_id;actor_lifetime=next_lifetime
		var area: Variant=value.get("areaId");var generation: Variant=value.get("areaGeneration")
		return {"actorId":next_id,"areaId":int(area) if uint(area) and int(area)!=0x7f000000 else null,"areaGeneration":int(generation) if integer(generation) else null,"controlLifetime":control_lifetime if known else null,"source":"client_receive_context"}

	func bind_event(message: Dictionary,source: Dictionary)->Dictionary:
		if last_sequence==0 or not is_same(message,last_input) or events.is_empty() or int(events[-1].sequence)!=last_sequence:return {}
		if events[-1].kind=="popup" and events[-1].scope==null:
			events[-1].scope=context(source);cached={}
		var result: Dictionary=events[-1].duplicate(true)
		result.retiredThrough=int(events[0].sequence)-1
		return result

	func snapshot(source: Dictionary)->Dictionary:
		var control: Dictionary=context(source)
		if cached.is_empty():
			var members: Array=[]
			for panel_id in disabled:
				for target_id in disabled[panel_id]:members.append({"panelId":panel_id,"targetId":target_id,"targetSource":disabled[panel_id][target_id]})
			cached={"revision":sequence,"retiredThrough":int(events[0].sequence)-1 if not events.is_empty() else 0,"disabled":members,"events":events.duplicate(true)}
		var result: Dictionary=cached.duplicate(true);result.control=control
		return result

	func matches(panel_id: int,target_id: int)->bool:
		return panel(panel_id) and uint(target_id) and disabled.has(panel_id) and (disabled[panel_id].has(target_id) or disabled[panel_id].has(0x7f000000))

	func reset()->void:
		disabled.clear();events.clear();sequence=0;last_input=null;last_sequence=0;actor=null;actor_id=null;actor_lifetime=null;control_lifetime=0;cached={}
