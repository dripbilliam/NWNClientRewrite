extends RefCounted
# Original77e330..77e3bb, after decoded-source and GUI admission. Original
# vtable+18 returns CNWCObject for positional sources; module/area return null.
const Sound=preload("res://systems/world_sound_state.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
static func positional_type(type: int) -> Variant:
	if type in [3,4]: return false
	if type in [5,6,7,8,9,10,11,12,14,16]: return true
	return null # No invented cast for an unsupported client proxy subclass.
static func cue(text: String,positional: bool,point: Variant) -> Dictionary:
	var bytes:=PackedByteArray()
	for character in text:
		if character.unicode_at(0)==0 or bytes.size()==16: break
		if Rich.byte_value(character.unicode_at(0))<0: return {"error":"Sound reference is not a native byte string"}
		bytes.append(Rich.byte_value(character.unicode_at(0)))
	return cue_bytes(bytes,positional,point)
static func cue_bytes(bytes: PackedByteArray,positional: bool,point: Variant) -> Dictionary:
	# Preserve the decoded CExoString bytes across transport: constructing an
	# intermediate Godot Unicode string would diagnose embedded NULs before
	# the original CResRef constructor has a chance to terminate at that byte.
	var count:=mini(16,bytes.size()); var end:=bytes.find(0)
	if end>=0: count=mini(count,end)
	var name:=Binary.new(bytes).text(0,count)
	if positional:
		if not point is Array or point.size()!=3 or not point.all(func(v):return (v is int or v is float) and is_finite(float(v))): return {"error":"Positional script sound source has no valid pose"}
	return {"resRef":name,"position":Sound.position(point,0) if positional else null,"priority":8,"volume":0,"delay":0,"height":0.0,"error":""}
static func raw_position(source: Dictionary) -> Variant:
	for field in ["replicated","staticState","lightState","state","mapPin"]:
		if source.get(field) is Dictionary and source[field].has("position"): return source[field].position
	return null
