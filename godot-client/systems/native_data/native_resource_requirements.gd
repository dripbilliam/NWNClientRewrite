extends RefCounted
const Text=preload("res://systems/native_data/native_gff_text.gd")
class Reader extends RefCounted:
	const Western=preload("res://systems/native_data/native_gff_text.gd")
	var bytes:=PackedByteArray()
	var byte_size:=0
	var byte_cursor:=0
	var fragments:=PackedByteArray()
	var fragment_size:=0
	var fragment_cursor:=0
	var bit_cursor:=0
	var last_byte_bits:=0
	var format_mode:=1
	var error: String=""
	func configure(source: PackedByteArray,mode: int=1)->bool:
		bytes=source
		format_mode=mode
		if mode not in [0,1]:error="Native message format is invalid";return false
		if bytes.size()<5:error="Native message body is truncated";return false
		var boundary: int=bytes.decode_u32(0)
		var offset: int=(boundary-3) & 0xffffffff
		if offset>=bytes.size() or offset<4:error="Native message fragment offset is invalid";return false
		byte_size=offset;byte_cursor=4;fragments=bytes.slice(offset);fragment_size=fragments.size()
		expect_type(3)
		last_byte_bits=unsigned(3)
		return error.is_empty()
	func expect_type(expected: int)->void:
		if format_mode!=0:return
		var tag:=raw(1)
		if tag.size()!=1 or int(tag[0])!=expected:error="Native message type tag differs"
	func raw(count: int)->PackedByteArray:
		var at:=byte_cursor;byte_cursor+=count
		if count<0 or byte_cursor>byte_size:error="Native message byte stream overflow";return PackedByteArray()
		return bytes.slice(at,at+count)
	func unsigned(bits: int)->int:
		if bits<0 or bits>32:error="Invalid native bit width";return 0
		expect_type(1)
		var value:=0
		for _index in range(bits):
			if fragment_cursor>=fragment_size:error="Native message bit stream overflow";return 0
			value=(value << 1) | ((int(fragments[fragment_cursor]) >> (7-bit_cursor)) & 1)
			bit_cursor+=1
			if bit_cursor==8:bit_cursor=0;fragment_cursor+=1
		return value
	func boolean()->bool:
		expect_type(2)
		return sized_unsigned(1)!=0
	func byte_bits(bits: int)->int:
		expect_type(3)
		return sized_unsigned(bits)
	func word_bits(bits: int)->int:
		expect_type(5)
		return sized_unsigned(bits)
	func dword_bits(bits: int)->int:
		expect_type(7)
		return sized_unsigned(bits)
	func sized_unsigned(bits: int)->int:
		if bits<0 or bits>32:error="Invalid native unsigned width";return 0
		var result:=0;var left:=bits
		for size in [4,2,1]:
			while left>=size*8:
				expect_type(7 if size==4 else 5 if size==2 else 3)
				var part:=raw(size)
				if part.size()!=size:return 0
				var value:=part.decode_u32(0) if size==4 else part.decode_u16(0) if size==2 else int(part[0])
				result=(result << (size*8)) | value
				left-=size*8
		if left>0:result=(result << left) | unsigned(left)
		return result
	func signed(bits: int)->int:
		if bits<2 or bits>32:error="Invalid native signed width";return 0
		expect_type(8)
		var negative:=unsigned(1)!=0;var magnitude:=sized_unsigned(bits-1)
		if negative:return -magnitude
		return magnitude
	func byte()->int:
		expect_type(3)
		var value:=raw(1)
		return int(value[0]) if value.size()==1 else 0
	func word()->int:
		expect_type(5)
		var value:=raw(2)
		return int(value.decode_u16(0)) if value.size()==2 else 0
	func dword()->int:
		expect_type(7)
		var value:=raw(4)
		return int(value.decode_u32(0)) if value.size()==4 else 0
	func object_id()->int:
		var value:=raw(4)
		return int(value.decode_u32(0)) if value.size()==4 else 0
	func signed_dword()->int:
		expect_type(8)
		var value:=raw(4)
		return int(value.decode_s32(0)) if value.size()==4 else 0
	func short()->int:
		expect_type(6)
		var value:=raw(2)
		return int(value.decode_s16(0)) if value.size()==2 else 0
	func signed_byte()->int:
		expect_type(4)
		var value:=raw(1)
		return int(value[0])-256 if value.size()==1 and value[0]>=128 else int(value[0]) if value.size()==1 else 0
	func float32()->float:
		expect_type(11)
		var value:=raw(4)
		return value.decode_float(0) if value.size()==4 else 0.0
	func float_scaled(scale: float,bits: int)->float:
		if bits==32 and scale==1.0:return float32()
		expect_type(11)
		return float(sized_unsigned(bits))/scale
	func float_range(minimum: float,maximum: float,bits: int)->float:
		if bits==32:return float32()
		expect_type(11)
		var denominator: float=float((1 << bits)-1)
		return float(sized_unsigned(bits))*(maximum-minimum)/denominator+minimum
	func string()->String:
		expect_type(14);expect_type(8)
		var size_bytes:=raw(4)
		if size_bytes.size()!=4:return ""
		var length: int=size_bytes.decode_u32(0)
		if length>64*1024*1024:error="Native message string exceeds bound";return ""
		var value:=raw(length)
		if value.size()!=length or value.is_empty() or value[0]==0:return ""
		return Western.decode(value)
	func resref()->String:
		expect_type(13)
		var value:=raw(16)
		if value.size()!=16:return ""
		var end:=value.find(0)
		return Western.decode(value.slice(0,end if end>=0 else value.size()))
	func finished()->bool:
		if not error.is_empty() or byte_cursor>byte_size or fragment_cursor>fragment_size:return false
		var remaining:=fragment_size-fragment_cursor
		return byte_cursor==byte_size and (remaining==0 or remaining==1 and bit_cursor>=last_byte_bits)

static func sha1(value: String)->Variant:
	var prefix: String=""
	for character in value:
		if character.to_lower() not in "0123456789abcdef":break
		prefix+=character
	if prefix.length()!=40 or prefix=="0".repeat(40):return null
	return prefix.to_lower()

static func advertisement(reader: Reader)->Variant:
	if not reader.boolean():return null
	var hash: Variant=sha1(reader.string())
	var version:=reader.byte()
	var url:=reader.string()
	var count:=reader.byte()
	var manifests: Array[Dictionary]=[]
	for _index in range(count):manifests.append({"hash":sha1(reader.string()),"flags":reader.byte(),"language":reader.byte()})
	return {"hash":hash,"version":version,"url":url,"manifests":manifests}

static func decode_record(record: PackedByteArray)->Dictionary:
	if record.size()<15 or record[0]!=77 or (int(record[7]) & 4)!=0 or record[12]!=80 or record[13]!=1 or record[14]!=3:return {"error":"Not an uncompressed native resource message"}
	return decode_packet(record.slice(12))

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<3 or packet[0]!=80 or packet[1]!=1 or packet[2]!=3:return {"error":"Not a native resource message"}
	var reader:=Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var reserved:=reader.string()
	var ad: Variant=advertisement(reader)
	var custom_tlk:=reader.string()
	var nwm:=reader.string()
	var count:=reader.byte()
	var haks: Array[String]=[]
	for _index in range(count):haks.append(reader.resref())
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Native resource message stream is incomplete"}
	return {"reserved":reserved,"advertisement":ad,"customTlk":custom_tlk,"nwmResourceName":nwm,"haks":haks}
