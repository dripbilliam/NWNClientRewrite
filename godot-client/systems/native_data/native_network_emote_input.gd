extends RefCounted
# Original client 6/4 emote sender. This serializes the request only; native
# selection, model timing and voice presentation remain with their owners.

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func word(value: Variant)->bool:
	return uint(value) and value<=65535

static func f32(value: float)->float:
	var bytes:=PackedByteArray([0,0,0,0]);bytes.encode_float(0,value)
	return bytes.decode_float(0)

static func emote_animation_request(request: Dictionary)->Dictionary:
	var actor_id: Variant=request.get("actorId")
	var animation: Variant=request.get("animation")
	var position: Variant=request.get("position")
	var duration: Variant=request.get("duration")
	if not uint(actor_id) or not word(animation) or not position is Array or position.size()!=3:
		return {"error":"Invalid native emote animation request"}
	for coordinate in position:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or not is_finite(f32(float(coordinate))):
			return {"error":"Invalid native emote animation request"}
	if not (duration is int or duration is float) or not is_finite(float(duration)) or not is_finite(f32(float(duration))) or duration<0:
		return {"error":"Invalid native emote animation request"}
	var bytes:=PackedByteArray([112,6,4]);bytes.resize(30)
	bytes.encode_u32(3,29)
	bytes.encode_u16(7,int(animation))
	bytes.encode_u32(9,int(actor_id))
	for index in range(3):bytes.encode_float(13+index*4,f32(float(position[index])))
	bytes.encode_float(25,f32(float(duration)))
	bytes[29]=0x60
	return {"bytes":bytes}
