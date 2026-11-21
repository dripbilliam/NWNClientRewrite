extends RefCounted
# Original server25/1 selects the primary (C) or alternate (c) container.
# OBJECT_INVALID closes only the selected container. The bit is not success.
const INVALID:=0x7f000000

static func decode_packet(bytes: PackedByteArray)->Dictionary:
	if bytes.size() not in [12,16] or bytes[0]!=80 or bytes[1]!=25 or bytes[2]!=1 or int(bytes.decode_u32(3))!=bytes.size()-1:return {"error":"Invalid native container-status envelope"}
	var at:=7
	if bytes.size()==16:
		if bytes.slice(7,9)!=PackedByteArray([3,1]) or bytes.slice(13,15)!=PackedByteArray([2,1]):return {"error":"Invalid native container-status typed fields"}
		at=9
	var fragment:=int(bytes[-1])
	if fragment & 0xe0 != 0x80:return {"error":"Invalid native container-status bool fragment"}
	return {"kind":"container-status","targetId":int(bytes.decode_u32(at)),"primary":bool(fragment & 0x10)}

static func request(operation: String,target_id: int=INVALID)->Dictionary:
	if operation=="next":return {"bytes":PackedByteArray([112,25,2])}
	if operation=="previous":return {"bytes":PackedByteArray([112,25,3])}
	if operation!="close" or target_id<0 or target_id>0xffffffff:return {"error":"Invalid native container request"}
	var bytes:=PackedByteArray([112,25,1,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,target_id);bytes[11]=0x60
	return {"bytes":bytes}
