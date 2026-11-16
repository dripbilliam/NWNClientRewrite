extends RefCounted
# Original server resource/status coordinator sends header-only 1/1 while
# loading and 1/2 when unavailable. The session owns timeout/retry behavior.

static func accepted(major: int,minor: int)->bool:
	return major==1 and minor in [1,2]

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()!=3 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native server-status envelope"}
	return {"kind":"server-loading" if packet[2]==1 else "server-unavailable","major":1,"minor":int(packet[2])}
