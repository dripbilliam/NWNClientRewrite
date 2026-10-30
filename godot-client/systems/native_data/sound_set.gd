extends RefCounted
# Original CSoundSet7d7ba0 V1.0 offset entries; decoding never consults JS/TLK
# audio defaults. A valid SSF entry's explicit empty name remains empty.
const Binary=preload("res://systems/native_data/binary_data.gd")
var failure:=""
func parse(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()<40 or bytes.slice(0,8).get_string_from_ascii()!="SSF V1.0": failure="Unsupported soundset header"; return {}
	var count:=int(bytes.decode_u32(8)); var table:=int(bytes.decode_u32(12))
	if count>1000000 or table>bytes.size() or count*4>bytes.size()-table: failure="Invalid soundset table"; return {}
	var reader:=Binary.new(bytes); var entries: Array=[]
	for index in count:
		var at:=int(bytes.decode_u32(table+index*4))
		if at==0: entries.append(null); continue
		if at>bytes.size()-20: failure="Invalid soundset entry"; return {}
		entries.append({"resRef":reader.text(at,16,true),"strRef":int(bytes.decode_u32(at+16))})
	return {"count":count,"entries":entries}
static func entry(data: Dictionary,code: int) -> Variant:
	code&=65535
	return data.entries[code] if code<int(data.count) else null
