extends RefCounted
# Random-access original TLK records. Only requested text is decoded/cached;
# original tables remain installed and no resolved UI text comes from JS.
const Binary=preload("res://systems/native_data/binary_data.gd")
var file: FileAccess
var bytes:=PackedByteArray()
var failure:=""
var count:=0
var language:=0
var text_offset:=0
var length:=0
var records: Dictionary={}
var reads:=0
func range_valid(at: int,size: int) -> bool: return at>=0 and size>=0 and at<=length and size<=length-at
func read(at: int,size: int) -> PackedByteArray:
	if not range_valid(at,size): failure="Original TLK range exceeds file bounds"; return PackedByteArray()
	if file!=null: file.seek(at); return file.get_buffer(size)
	return bytes.slice(at,at+size)
func header() -> bool:
	var data:=read(0,20)
	if data.size()!=20 or data.slice(0,8).get_string_from_ascii()!="TLK V3.0": failure="Invalid original TLK header"; return false
	language=int(data.decode_u32(8)); count=int(data.decode_u32(12)); text_offset=int(data.decode_u32(16))
	if count>1000000 or not range_valid(20,count*40) or text_offset<20+count*40 or text_offset>length: failure="Invalid original TLK tables"; return false
	if language not in [0,1,2,3,4]: failure="Native non-Western TLK decoding is pending"; return false
	return true
func open_file(path: String) -> bool:
	close(); file=FileAccess.open(path,FileAccess.READ)
	if file==null: failure="Original TLK file is unavailable"; return false
	length=file.get_length(); return header()
func open_bytes(source: PackedByteArray) -> bool:
	close(); bytes=source; length=bytes.size(); return header()
func entry(index: int) -> Dictionary:
	failure=""
	if index<0 or index>=count: return {"found":false,"text":""}
	if records.has(index): return records[index]
	var row:=read(20+index*40,40)
	if row.size()!=40: return {"found":false,"text":""}
	var flags:=int(row.decode_u32(0)); var raw:=PackedByteArray(); var size:=int(row.decode_u32(32))
	if flags&1:
		var start:=text_offset+int(row.decode_u32(28))
		if start<text_offset or size>16*1024*1024 or not range_valid(start,size): failure="Original TLK string exceeds bounds"; return {"found":false,"text":""}
		raw=read(start,size)
		# Presentation consumes a terminated native string. Avoid passing NUL
		# into Godot's Unicode conversion; stored byte length remains recorded.
		var zero:=raw.find(0)
		if zero>=0: raw=raw.slice(0,zero)
	var result:={"found":true,"text":Binary.new(raw).text(0,raw.size()),"flags":flags,"stored_bytes":size,"sound":Binary.new(row).text(4,16,true),"duration":row.decode_float(36)}
	reads+=1
	if records.size()>=4096: records.erase(records.keys()[0])
	records[index]=result; return result
func close() -> void:
	file=null; bytes=PackedByteArray(); records.clear(); count=0; language=0; text_offset=0; length=0; reads=0; failure=""
