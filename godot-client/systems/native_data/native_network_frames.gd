extends RefCounted
# NWN reliable UDP framing. The CRC covers bytes 3 onward, starts at zero,
# has no final xor, and stores the low 16 bits in network byte order.
static func checksum(bytes: PackedByteArray)->int:
	var crc:=0
	for index in range(3,bytes.size()):
		var value: int=(crc ^ int(bytes[index])) & 255
		for _bit in range(8):value=(value >> 1) ^ (0xedb88320 if value & 1 else 0)
		crc=((crc >> 8) ^ value) & 0xffffffff
	return crc & 65535

static func between(first: int,candidate: int,end: int)->bool:
	return (first<=candidate and candidate<end) or (end<first and (first<=candidate or candidate<end))

static func word(bytes: PackedByteArray,at: int)->int:
	return (int(bytes[at]) << 8) | int(bytes[at+1])

static func put_word(bytes: PackedByteArray,at: int,value: int)->void:
	bytes[at]=(value >> 8) & 255
	bytes[at+1]=value & 255

static func write(kind: int=0,sequence: int=0,expected: int=0,compression: bool=false,frame: PackedByteArray=PackedByteArray())->Dictionary:
	if kind<0 or kind>2:return {"error":"Invalid native frame kind"}
	if sequence<0 or sequence>65535:return {"error":"Invalid native frame sequence"}
	if expected<0 or expected>65535:return {"error":"Invalid native frame expected sequence"}
	if kind==0 and (frame.size()<12 or frame.size()>65466):return {"error":"Invalid native data frame"}
	var bytes:=frame.duplicate() if kind==0 else PackedByteArray()
	if kind!=0:bytes.resize(12)
	bytes[0]=77
	put_word(bytes,3,sequence)
	put_word(bytes,5,(expected-1) & 65535)
	bytes[7]=(int(bytes[7]) & 0x8f) | (kind << 4) | (64 if compression else 0)
	put_word(bytes,1,checksum(bytes))
	return {"bytes":bytes}

static func read(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<12 or bytes.size()>65466 or bytes[0]!=77:return {"error":"Invalid native reliable frame envelope"}
	if word(bytes,1)!=checksum(bytes):return {"error":"Native reliable frame checksum mismatch"}
	var kind: int=(int(bytes[7]) >> 4) & 3
	if kind==3:return {"error":"Unsupported native reliable frame kind"}
	return {"kind":kind,"sequence":word(bytes,3),"acknowledgement":word(bytes,5),"highPriority":bool(int(bytes[7]) & 8),"compression":bool(int(bytes[7]) & 64),"bytes":bytes.duplicate()}
