extends RefCounted
# Original server 16/1..10,12 camera commands. Presentation owns application;
# these packets do not modify canonical world or area state.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==16 and (minor>=1 and minor<=10 or minor==12)

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native camera envelope"}
	var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native camera stream: "+reader.error}
	var message: Dictionary={"major":16,"minor":minor}
	match minor:
		1:
			var mask:=reader.byte();message.kind="camera-location";message.mask=mask
			if (mask&1)!=0:message.yawRadians=reader.float32()
			if (mask&2)!=0:message.distance=reader.float32()
			if (mask&4)!=0:message.pitch=reader.float32()
			if (mask&8)!=0:message.transition=reader.signed_dword()
		2:message.kind="camera-mode";message.mode=reader.byte()
		3:message.kind="camera-store"
		4:message.kind="camera-restore"
		5:message.kind="camera-height";message.height=reader.float32()
		6,7,8:message.kind="camera-lock";message.axis=["pitch","distance","yaw"][minor-6];message.locked=reader.boolean()
		9:message.kind="camera-limits";message.limits={"minPitch":reader.float32(),"maxPitch":reader.float32(),"minDist":reader.float32(),"maxDist":reader.float32()}
		10:message.kind="camera-attach";message.objectId=reader.object_id();message.findClearView=reader.boolean()
		12:message.kind="camera-flags";message.flags=reader.signed_dword()
	if not reader.finished():
		return {"error":"Invalid native camera fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
