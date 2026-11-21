extends RefCounted
# Original map pin GUI click and personal map-note request packets.
const Hud=preload("res://systems/native_data/native_network_hud.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func f32(value: float)->float:
	var bytes:=PackedByteArray([0,0,0,0]);bytes.encode_float(0,value)
	return bytes.decode_float(0)

static func vector(value: Variant)->bool:
	if not value is Array or value.size()!=3:return false
	for coordinate in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or not is_finite(f32(float(coordinate))):return false
	return true

static func map_pin_click_request(request: Dictionary)->Dictionary:
	var reference: Variant=request.get("reference")
	var include_position: Variant=request.get("includePosition")
	if not uint(reference) or not include_position is bool:return {"error":"Invalid native map-pin click"}
	# Old NativeMessageWriter(1) writes GUI event WORD 7, selection WORD 0,
	# raw reference object ID and optional three zero float32 coordinates.
	return {"bytes":Hud.gui_request(7,0,int(reference),include_position)}

static func map_note_request(request: Dictionary)->Dictionary:
	var operation: Variant=request.get("operation")
	var reference: Variant=request.get("reference")
	var position: Variant=request.get("position")
	var text_value: Variant=request.get("text")
	if operation not in ["add","change","delete"] or operation!="add" and not uint(reference):
		return {"error":"Invalid native map-note operation"}
	var encoded:=PackedByteArray()
	if operation!="delete":
		if not vector(position) or not text_value is String or str(text_value).contains(String.chr(0)):
			return {"error":"Invalid native map-note fields"}
		var result: Dictionary=GffText.encode(str(text_value))
		if result.has("error"):return result
		encoded=result.bytes
		if encoded.size()>65535:return {"error":"Native map note exceeds the supported text allocation"}
	var size:=12 if operation=="delete" else (28 if operation=="change" else 24)+encoded.size()
	var bytes:=PackedByteArray([112,32,2 if operation=="add" else 5 if operation=="change" else 3]);bytes.resize(size)
	bytes.encode_u32(3,size-1)
	var offset:=7
	if operation!="delete":
		for index in range(3):bytes.encode_float(offset+index*4,f32(float(position[index])))
		offset+=12
		bytes.encode_u32(offset,encoded.size());offset+=4
		for code in encoded:bytes[offset]=code;offset+=1
	if operation!="add":bytes.encode_s32(offset,int(reference) if int(reference)<0x80000000 else int(reference)-0x100000000)
	bytes[size-1]=0x60
	return {"bytes":bytes}
