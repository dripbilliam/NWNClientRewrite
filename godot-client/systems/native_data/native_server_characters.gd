extends RefCounted
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Text=preload("res://systems/native_data/native_gff_text.gd")
const MAX_CHARACTER_BYTES:=948*65535-16

# Original HandlePlayerToServerLoginMessage upload ABI (2/1 local, 2/19
# create-server). The BIC remains opaque; server validation owns admission.
static func upload_request(bic: PackedByteArray,subtype: int=1)->Dictionary:
	if subtype not in [1,4,19] or bic.is_empty() or bic.size()>MAX_CHARACTER_BYTES:return {"error":"Invalid native character upload"}
	var bytes:=PackedByteArray([112,2,subtype]);bytes.resize(11)
	bytes.encode_u32(3,bic.size()+11)
	bytes.encode_u32(7,bic.size())
	bytes.append_array(bic);bytes.append(0x60)
	return {"bytes":bytes}

static func reference_bytes(source: int,resref: String)->Dictionary:
	if source not in [2,14,17] or resref.is_empty():return {"error":"Invalid server character source or reference"}
	for character in resref:
		if character.unicode_at(0)<32 or character in ["/","\\",":"]:return {"error":"Invalid server character reference"}
	var encoded: Dictionary=Text.encode(resref)
	if encoded.has("error") or encoded.bytes.size()>16:return {"error":"Invalid server character reference encoding"}
	var fixed:=PackedByteArray();fixed.resize(16)
	for index in range(encoded.bytes.size()):fixed[index]=encoded.bytes[index]
	return {"bytes":fixed}

static func play_request(source: int,resref: String)->Dictionary:
	var reference: Dictionary=reference_bytes(source,resref)
	if reference.has("error"):return reference
	var bytes:=PackedByteArray([112,2,source,23,0,0,0])
	bytes.append_array(reference.bytes)
	bytes.append(0x60)
	return {"bytes":bytes}

static func preview_request(source: int,resref: String)->Dictionary:
	var reference: Dictionary=reference_bytes(source,resref)
	if reference.has("error"):return reference
	var kind:=5 if source==17 else 4 if source==14 else 1
	var bytes:=PackedByteArray([112,17,3,24,0,0,0,kind])
	bytes.append_array(reference.bytes)
	bytes.append(0x60)
	return {"bytes":bytes}

static func localized(reader: Requirements.Reader)->Dictionary:
	if reader.boolean(): return {"gender":reader.byte_bits(1),"strRef":reader.dword()}
	return {"text":reader.string()}

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=17 or packet[2]!=2: return {"error":"Not a server character-list message"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)): return {"error":reader.error}
	var count:=reader.word()
	if count>(reader.byte_size-reader.byte_cursor)/44: return {"error":"Invalid server character count"}
	var characters: Array[Dictionary]=[]
	for _index in range(count):
		var first_name:=localized(reader)
		var last_name:=localized(reader)
		var resref:=reader.resref()
		var source:=reader.byte()
		var portrait:=reader.word()
		var portrait_ref:=reader.resref()
		var classes: Array[Dictionary]=[]
		var class_count:=reader.byte()
		if class_count>(reader.byte_size-reader.byte_cursor)/5: return {"error":"Invalid server character classes"}
		for _class_index in range(class_count): classes.append({"id":reader.signed_dword(),"level":reader.byte()})
		if reference_bytes(source,resref).has("error"): return {"error":"Invalid server character reference"}
		characters.append({"firstName":first_name,"lastName":last_name,"resref":resref,"source":source,"portrait":portrait,"portraitRef":portrait_ref,"classes":classes})
	if not reader.finished(): return {"error":reader.error if not reader.error.is_empty() else "Server character-list stream is incomplete"}
	return {"characters":characters}

static func decode_record(record: PackedByteArray)->Dictionary:
	if record.size()<15 or record[0]!=77 or (int(record[7]) & 4)!=0: return {"error":"Not an uncompressed native game record"}
	return decode_packet(record.slice(12))

static func decode_preview_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=17 or packet[2]!=4:return {"error":"Not a server character preview"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var preview_type:=reader.byte()
	var resref:=reader.resref()
	var length:=reader.dword()
	if preview_type not in [1,4,5] or length>MAX_CHARACTER_BYTES or length>reader.byte_size-reader.byte_cursor:return {"error":"Invalid server character preview length"}
	var bytes:=reader.raw(length)
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Server character preview is incomplete"}
	return {"previewType":preview_type,"resref":resref,"bytes":bytes}
