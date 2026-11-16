extends RefCounted
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=3 or packet[2]!=3:return {"error":"Not a native module-time packet"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var mask:=reader.byte()
	var changes: Dictionary={}
	if mask&1:
		changes.timeOfDay=reader.byte()
		if changes.timeOfDay in [3,4]:changes.transition=reader.dword()
	if mask&2:changes.hour=reader.byte()
	if mask&4:changes.day=reader.byte()
	if mask&8:changes.month=reader.byte()
	if mask&16:changes.year=reader.dword()
	if not reader.finished():return {"error":"Native module-time fields are incomplete"}
	return {"mask":mask,"changes":changes}
