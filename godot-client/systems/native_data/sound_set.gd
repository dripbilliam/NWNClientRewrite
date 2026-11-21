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
	# The source parser retains the validated offset table and checks only the
	# requested entry. A corrupt unused row must not suppress a valid line.
	return {"count":count,"table":table,"bytes":bytes}
static func entry(data: Dictionary,code: int) -> Variant:
	code&=65535
	if code>=int(data.count):return null
	var bytes: PackedByteArray=data.bytes
	var at:=int(bytes.decode_u32(int(data.table)+code*4))
	if at==0:return null
	if at>bytes.size()-20:return {"error":"Soundset table or entry is out of bounds"}
	return {"resRef":Binary.new(bytes).text(at,16,true),"strRef":int(bytes.decode_u32(at+16))}
