extends RefCounted
# Original party roster and invitation packets. Membership only reports raw
# server object IDs; it never creates, removes, or owns replicated creatures.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==14 and minor in [1,3,4] or major==36 and minor==3

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native party envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native party stream: "+reader.error}
	var message: Dictionary={"major":major,"minor":minor}
	if major==36:
		message.kind="party-invite-notice"
		message.name=reader.string()
	else:
		var count:=reader.signed_dword()
		if count>int((reader.byte_size-reader.byte_cursor)/4):
			return {"error":"Invalid native party-list count"}
		var ids: Array[int]=[]
		for _index in range(maxi(0,count)):ids.append(reader.object_id())
		message.kind="party-list"
		message.operation={1:"all",3:"add",4:"remove"}[minor]
		message.count=count
		message.ids=ids
	if not reader.finished():
		return {"error":"Invalid native party fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
