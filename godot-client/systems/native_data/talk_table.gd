extends RefCounted
# Random-access original TLK records. Only requested text is decoded/cached;
# original tables remain installed and no resolved UI text comes from JS.
const Binary=preload("res://systems/native_data/binary_data.gd")
const Encoding=preload("res://systems/native_data/native_text_encoding.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")
var file: FileAccess
var bytes:=PackedByteArray()
var failure:=""
var count:=0
var language:=0
var decode_language:=0
var text_offset:=0
var length:=0
var records: Dictionary={}
var native_records: Dictionary={}
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
	# The old installed parser preserves the header ID but decodes unknown IDs
	# with Windows-1252. Keep known language mappings unchanged.
	decode_language=language if Encoding.LANGUAGE_CODES.has(language) else 0
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
		if start<text_offset or not range_valid(start,size): failure="Original TLK string exceeds bounds"; return {"found":false,"text":""}
		raw=read(start,size)
		if raw.size()!=size:failure="Original TLK text read is incomplete";return {"found":false,"text":""}
	# The network UI's parseTalkTable.get decodes the complete counted byte span,
	# including an empty span or embedded NUL, before caching the string.
	var decoded:=Encoding.decode(raw,decode_language,false,false,true)
	if not decoded.get("ready",false):failure=str(decoded.reason);return {"found":false,"text":""}
	var duration_bits:=int(row.decode_u32(36)) if (flags&4)!=0 else 0
	var result:={"found":true,"text":str(decoded.text),"bytes":raw,"language":language,"flags":flags,"stored_bytes":size,"sound":Binary.new(row).text(4,16,true) if (flags&2)!=0 else "","durationBits":duration_bits,"duration":row.decode_float(36) if (flags&4)!=0 else 0.0}
	reads+=1
	records[index]=result; return result
func native_record(index: int) -> Dictionary:
	# Native FetchInternal uses raw CExoString bytes, independent of the UI's
	# TextDecoder cache above. The installed multiplayer bridge requested parse=0.
	var result:={"found":false,"text":"","bytes":PackedByteArray(),"sound":"","durationBits":0,"duration":0.0,"flags":0,"language":language}
	if index<0 or index>=count:result.warningLine=0x1d2;return result
	if native_records.has(index):return native_records[index].duplicate(true)
	var entry_offset: int=(index*40+20)&0xffffffff
	if entry_offset>length:result.warningLine=0x1d2;return result
	var row:=read(entry_offset,40)
	if row.size()!=40:result.warningLine=0x1eb;return result
	var flags:=int(row.decode_u32(0));result.flags=flags
	result.durationBits=int(row.decode_u32(36)) if flags&4 else 0
	result.duration=row.decode_float(36) if flags&4 else 0.0
	if flags&2:
		var sound_bytes: PackedByteArray=row.slice(4,20);var end:=sound_bytes.find(0)
		result.sound=GffText.decode(sound_bytes.slice(0,end if end>=0 else sound_bytes.size()))
	if (flags&1)==0:
		result.found=true
		return result
	var text_at: int=(text_offset+int(row.decode_u32(28)))&0xffffffff
	var text_length:=int(row.decode_u32(32))
	if text_at>length or text_length==0:
		result.sound=""
		result.warningLine=0x219 if text_at>length else 0x22b
		return result
	if text_length>64*1024*1024:
		result.sound="";result.error="Native talk-table text exceeds supported size"
		return result
	var value:=read(text_at,text_length)
	if value.size()!=text_length:
		result.sound="";result.error="Native TLK short text read leaves unknown allocated bytes"
		return result
	result.bytes=PackedByteArray() if value[0]==0 else value
	result.text=GffText.decode(result.bytes)
	result.found=true
	native_records[index]=result.duplicate(true)
	return result
func close() -> void:
	file=null; bytes=PackedByteArray(); records.clear(); native_records.clear(); count=0; language=0; decode_language=0; text_offset=0; length=0; reads=0; failure=""
