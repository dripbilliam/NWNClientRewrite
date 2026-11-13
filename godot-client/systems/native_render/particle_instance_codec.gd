extends RefCounted
# Explicit diagnostic reconstruction. Production uploads the packed records;
# this decoder is never run in the particle tick or render callback.
static func to_streams(bytes: PackedByteArray,count: int,capacity: int) -> Dictionary:
	if count<0 or count%6 or capacity<count or bytes.size()!=count/6*80: return {"error":"Invalid packed quad records"}
	var positions:=PackedByteArray(); var attributes:=PackedByteArray(); positions.resize(capacity*12); attributes.resize(capacity*12)
	for id in count/6:
		var at:=id*80
		var a:=int(bytes.decode_float(at+48)); var b:=int(bytes.decode_float(at+52)); var c:=int(bytes.decode_float(at+56)); var d:=int(bytes.decode_float(at+60))
		var head: int=(a|(b<<10)|(c<<20)|((d&3)<<30))&0xffffffff
		var tail: int=(head&0xffffff)|(((d>>2)&255)<<24)
		for vertex in 6:
			var corner: int=[0,1,2,2,1,3][vertex]; var target:=(id*6+vertex)*12
			for axis in 3: positions.encode_float(target+axis*4,bytes.decode_float(at+axis*16+corner*4))
			attributes.encode_u32(target,head if corner<2 else tail)
			attributes.encode_float(target+4,bytes.decode_float(at+68 if corner in [0,2] else at+64))
			attributes.encode_float(target+8,bytes.decode_float(at+76 if corner<2 else at+72))
	return {"positions":positions,"attributes":attributes}
