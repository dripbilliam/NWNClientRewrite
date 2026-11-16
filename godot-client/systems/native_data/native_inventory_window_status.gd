extends RefCounted
# Original server13/1: BOOL lives in the residual bit fragment, while the
# client object ID is copied from the byte body. Both native format modes are
# represented in the original writer observations; network sessions use 1.

static func decode_packet(bytes: PackedByteArray)->Dictionary:
	if bytes.size() not in [12,16] or bytes[0]!=80 or bytes[1]!=13 or bytes[2]!=1 or int(bytes.decode_u32(3))!=bytes.size()-1:return {"error":"Invalid native inventory-window envelope"}
	var at:=7
	if bytes.size()==16:
		if bytes.slice(7,11)!=PackedByteArray([3,1,2,1]):return {"error":"Invalid native inventory-window typed fields"}
		at=11
	var fragment:=int(bytes[-1])
	if fragment & 0xe0 != 0x80:return {"error":"Invalid native inventory-window bool fragment"}
	return {"kind":"inventory-window-status","open":bool(fragment & 0x10),"ownerId":int(bytes.decode_u32(at))}
