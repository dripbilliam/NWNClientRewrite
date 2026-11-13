extends "res://native_session_world.gd"
# NEW dedicated headless direct-route entry; old local-host tests are separate.
var direct_retired_refs: Array=[]
var direct_probe
var direct_progress_at:=0
var direct_frontier_before: Dictionary={}
var direct_frontier_after: Dictionary={}
const DIRECT_PROGRESS_SUFFIXES={"kind":"Kind","connection":"Connection","generation":"Generation","serial":"Serial","ticksMs":"TicksMs"}
const DIRECT_READ_ERROR_FIELDS={"error":"tcpReadErrorCode","bytes":"tcpReadErrorBytes","expected":"tcpReadErrorExpected","ticks_ms":"tcpReadErrorTicksMs"}
func direct_progress_enabled()->bool:
	return args.get("direct-handoff-check","")=="true" and args.get("direct-handoff-progress","")=="true" and DisplayServer.get_name()=="headless"
static func direct_progress_integer(value: Variant)->Variant:
	if (value is int or value is float) and is_finite(float(value)) and abs(float(value))<=9007199254740991.0 and float(value)==floor(float(value)):return int(value)
	return null
func direct_frontier(message: Dictionary)->Dictionary:
	var kind: Variant=message.get("kind")
	return {"kind":kind.left(64) if kind is String else null,"connection":direct_progress_integer(message.get("connection")),"generation":direct_progress_integer(message.get("generation")),"serial":direct_progress_integer(message.get("serial")),"ticksMs":Time.get_ticks_msec()}
func direct_pending_progress()->Dictionary:
	var count:=frames.pending.size()
	var value: Dictionary={"pendingFirstByte":null,"pendingLastByte":null,"pendingLfIndex":null,"pendingLfSearchBytes":0,"binaryDeclaredLength":null}
	if count>0:
		value.pendingFirstByte=int(frames.pending[0])
		value.pendingLastByte=int(frames.pending[count-1])
		if frames.pending[0]==0x89:
			if count>=8:value.binaryDeclaredLength=int(frames.pending.decode_u32(4))
		elif count<=1048576:
			# JSON framing is bounded by BridgeFrames.MAX_JSON. Binary data is
			# not searched or copied; no pending bytes enter the diagnostic DTO.
			value.pendingLfIndex=frames.pending.find(10)
			value.pendingLfSearchBytes=count
	var read_error: Variant=report.get("protocol_read_error")
	for field in DIRECT_READ_ERROR_FIELDS:
		var target: String=DIRECT_READ_ERROR_FIELDS[field]
		value[target]=direct_progress_integer(read_error.get(field)) if read_error is Dictionary else null
	return value
func _profile_tick()->void:
	super._profile_tick()
	if not direct_progress_enabled() or not authenticated or closing:return
	var now:=Time.get_ticks_msec()
	if now<direct_progress_at:return
	direct_progress_at=now+2000
	var present:=is_instance_valid(world)
	var inflight: bool=not raw_world.is_empty()
	var chunk: Variant=raw_world.get("data",{}).get("objects")
	var value:={"kind":"direct-handoff-progress","connection":session_connection,"epoch":epoch,"areaId":world.area_id if present else -1,"initialized":initialized,"worldPresent":present,"worldReady":world.ready_for_control() if present else false,"pendingBatches":world.batches.size() if present else null,"instances":world.instances.size() if present else null,"desired":world.desired.size() if present else null,"acceptedRawSerial":accepted_raw_serial,"rawSerial":raw_serial,"rawInFlight":inflight,"rawInFlightCount":chunk.size() if chunk is Array else 0,"rawExpectedCount":raw_world.get("count",0),"peerStatus":peer.get_status(),"peerAvailableBytes":peer.get_available_bytes() if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED else 0,"framePendingBytes":frames.pending.size(),"outputQueuedBytes":protocol_output.queued_bytes,"outputPendingMessages":protocol_output.pending.size()-protocol_output.head,"outputBytesSent":protocol_output.stats.get("bytes_sent",0),"receivedSnapshots":received,"processFrames":Engine.get_process_frames(),"ticksMs":now}
	value.merge(direct_pending_progress())
	for prefix in ["before","after"]:
		var frontier: Dictionary=direct_frontier_before if prefix=="before" else direct_frontier_after
		for key in DIRECT_PROGRESS_SUFFIXES:value[prefix+DIRECT_PROGRESS_SUFFIXES[key]]=frontier.get(key)
	report.direct_handoff_progress=value.duplicate()
	send(value)
func reset_session()->void:
	if is_instance_valid(world):
		for previous_owner in [world,gameplay_ui,hud,catalog]:
			if is_instance_valid(previous_owner) and direct_retired_refs.size()<32:direct_retired_refs.append(weakref(previous_owner))
	super.reset_session()
func receive(message: Dictionary)->void:
	if direct_progress_enabled():
		direct_frontier_before=direct_frontier(message)
		report.direct_handoff_frontier={"before":direct_frontier_before.duplicate(),"after":direct_frontier_after.duplicate()}
	receive_direct(message)
	if direct_progress_enabled():
		direct_frontier_after=direct_frontier(message)
		report.direct_handoff_frontier={"before":direct_frontier_before.duplicate(),"after":direct_frontier_after.duplicate()}
func receive_direct(message: Dictionary)->void:
	if message.get("kind")=="probe-direct-handoff":
		if args.get("direct-handoff-check","")!="true" or DisplayServer.get_name()!="headless" or closing:return
		if message.get("connection")!=session_connection or session_connection==cancelled_connection:return
		if not is_instance_valid(direct_probe):
			direct_probe=preload("res://tests/native_direct_handoff_probe.gd").new()
			host.add_child(direct_probe)
		direct_probe.run(self,message)
		return
	super.receive(message)
func application_exit_policy()->bool:
	report.scope="Owned headless native-session-host direct handoff. Dedicated actual ownership/catalog/character/waypoint evidence applies; legacy local-host, movement, pixel and performance acceptance are not claimed."
	return true
