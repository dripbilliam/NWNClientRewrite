extends RefCounted
# Original server 2/16 is a header-only character-needed admission response.
# Character choice and retry belong to the session; the packet carries no ID,
# reason, name, or selection list.

static func accepted(major: int,minor: int)->bool:
	return major==2 and minor==16

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()!=3 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native character-needed envelope"}
	return {"kind":"character-needed","major":2,"minor":16}
