extends RefCounted
# Original server 29/1..4. These are acknowledgements and class availability;
# character progression itself arrives later through authoritative updates.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==29 and minor>=1 and minor<=4

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<3 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native level-up envelope"}
	var minor:=int(packet[2])
	if minor!=4:
		if packet.size()!=3:return {"error":"Invalid native level-up acknowledgement"}
		return {"major":29,"minor":minor,"kind":"level-up-available"} if minor==3 else {"major":29,"minor":minor,"kind":"level-up-result","accepted":minor==1}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native level-up stream: "+reader.error}
	var count:=reader.byte()
	var available: Array[bool]=[]
	for _index in count:available.append(reader.boolean())
	if not reader.finished():
		return {"error":"Invalid native level-up classes: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"major":29,"minor":4,"kind":"level-up-classes","available":available}
