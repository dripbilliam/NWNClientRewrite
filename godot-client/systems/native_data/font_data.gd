extends RefCounted
# Bounds-check original SFNT table storage in a native worker. FontFile and
# FreeType resources are created by the main-thread publication owner.
var failure:=""
static func u16(bytes: PackedByteArray,at: int) -> int: return (int(bytes[at])<<8)|int(bytes[at+1])
static func u32(bytes: PackedByteArray,at: int) -> int: return (int(bytes[at])<<24)|(int(bytes[at+1])<<16)|(int(bytes[at+2])<<8)|int(bytes[at+3])
func reject(reason: String) -> Dictionary: failure=reason; return {}
func parse(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()<12 or bytes.size()>32*1024*1024: return reject("Original font header/size is invalid")
	var tag:=u32(bytes,0)
	if tag not in [0x00010000,0x4f54544f,0x74727565]: return reject("Original font SFNT format is unsupported")
	var count:=u16(bytes,4)
	if count<1 or count>4096 or 12+count*16>bytes.size(): return reject("Original font table directory exceeds bounds")
	var tables: Dictionary={}
	for index in count:
		var at:=12+index*16; var name:=bytes.slice(at,at+4).get_string_from_ascii(); var offset:=u32(bytes,at+8); var length:=u32(bytes,at+12)
		if offset>bytes.size() or length>bytes.size()-offset or tables.has(name): return reject("Original font table range/identity is invalid")
		tables[name]={"offset":offset,"length":length,"checksum":u32(bytes,at+4)}
	return {"data":bytes,"sfnt_tag":tag,"tables":tables}
