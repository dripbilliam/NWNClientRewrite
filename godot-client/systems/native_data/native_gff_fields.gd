extends RefCounted

const Text=preload("res://systems/native_data/native_gff_text.gd")

# CExoString explicit-length assignment clears a string whose first byte is NUL.
static func assigned_string(value: String) -> String:
	return "" if value.begins_with("\u0000") else value

# GetFieldByLabel copies at most 16 CP1252 bytes before its four-DWORD compare.
static func label(name: String) -> String:
	var encoded: Dictionary=Text.encode(name)
	if encoded.has("error"):
		push_error(str(encoded.error))
		return ""
	var bytes: PackedByteArray=encoded.bytes
	var nul:=bytes.find(0)
	return Text.decode(bytes.slice(0,mini(16,nul if nul>=0 else bytes.size())))

# The parsed document supplies the record's physical field-type table. This is
# the Godot equivalent of the old parser's WeakMap metadata on each record.
static func read(data: Variant,types: Variant,name: String,type: int,fallback: Variant) -> Dictionary:
	name=label(name)
	if not data is Dictionary or not data.has(name): return {"status":0,"value":fallback}
	if not types is Dictionary:
		return {"status":-1,"value":fallback,"error":"Native GFF type metadata for "+name+" is unavailable"}
	if types.get(name)!=type: return {"status":0,"value":fallback}
	var value: Variant=data[name]
	match type:
		4: value=int(value)&0xffffffff
		5:
			value=int(value)&0xffffffff
			if value>=0x80000000:value-=0x100000000
		8:
			var bytes:=PackedByteArray()
			bytes.resize(4)
			bytes.encode_float(0,float(value))
			value=bytes.decode_float(0)
		10: value=assigned_string(str(value))
	return {"status":1,"value":value}
