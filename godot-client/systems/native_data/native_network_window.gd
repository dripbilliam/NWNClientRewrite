extends RefCounted
const Frames=preload("res://systems/native_data/native_network_frames.gd")
var first:=0
var next:=0
var expected:=0
var end:=16
var capacity:=16
var outgoing: Dictionary={}
var incoming: Dictionary={}
var queued: Array[PackedByteArray]=[]
var nak_enabled:=true
var compression:=false
var ack_delay:=2000
var resend_delay:=3500
var ack_at:=0
var last_received:=0

func _init(now: int=0)->void:
	ack_at=now+ack_delay
	last_received=now

func send_frame(kind: int,sequence: int,frame: PackedByteArray,now: int)->PackedByteArray:
	var result: Dictionary=Frames.write(kind,sequence,expected,compression,frame)
	if result.has("error"):return PackedByteArray()
	ack_at=now+ack_delay
	if kind==2:nak_enabled=false
	if kind==0 and outgoing.has(sequence):outgoing[sequence].deadline=now+resend_delay
	return result.bytes

func enqueue(frame: PackedByteArray,now: int)->Dictionary:
	if frame.size()<12 or frame.size()>65466:return {"error":"Invalid native outgoing frame"}
	queued.append(frame.duplicate())
	return {"send":load_queued(now)}

func load_queued(now: int)->Array[PackedByteArray]:
	var send: Array[PackedByteArray]=[]
	while not queued.is_empty() and outgoing.size()<capacity:
		var frame: PackedByteArray=queued.pop_front()
		var sequence:=next;next=(next+1) & 65535
		outgoing[sequence]={"frame":frame,"deadline":0}
		send.append(send_frame(0,sequence,frame,now))
	return send

func receive(bytes: PackedByteArray,now: int)->Dictionary:
	var frame: Dictionary=Frames.read(bytes)
	if frame.has("error"):return {"accepted":false,"send":[],"delivered":[]}
	last_received=now
	var kind: int=frame.kind;var sequence: int=frame.sequence;var acknowledgement: int=frame.acknowledgement
	var send: Array[PackedByteArray]=[];var delivered: Array[PackedByteArray]=[]
	if kind==0:
		var within: bool=Frames.between(expected,sequence,end)
		if within and sequence!=expected and nak_enabled:send.append(send_frame(2,0,PackedByteArray(),now))
		if within and not incoming.has(sequence):
			incoming[sequence]=frame.bytes
			while incoming.has(expected):
				delivered.append(incoming[expected]);incoming.erase(expected)
				expected=(expected+1) & 65535;end=(end+1) & 65535;nak_enabled=true
	elif kind==2:
		var requested: int=(acknowledgement+1) & 65535
		if Frames.between(first,requested,next) and outgoing.has(requested):send.append(send_frame(0,requested,outgoing[requested].frame,now))
	var acknowledged: Array[int]=[]
	while Frames.between(first,acknowledgement,next):
		acknowledged.append(first);outgoing.erase(first);first=(first+1) & 65535
	send.append_array(load_queued(now))
	return {"accepted":true,"send":send,"delivered":delivered,"acknowledged":acknowledged}

func poll(now: int)->Array[PackedByteArray]:
	var send: Array[PackedByteArray]=[]
	var oldest: int=-1;var deadline: int=9223372036854775807
	for sequence in outgoing:
		var current: int=outgoing[sequence].deadline
		if current<now and current<deadline:oldest=int(sequence);deadline=current
	if oldest>=0:send.append(send_frame(0,oldest,outgoing[oldest].frame,now))
	if ack_at<now:send.append(send_frame(1,0,PackedByteArray(),now))
	return send
