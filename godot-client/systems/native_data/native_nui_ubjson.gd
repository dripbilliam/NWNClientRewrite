extends RefCounted
# Original NWN NUI JSON transport is nlohmann UBJSON. Decode inside a bounded
# Godot owner; no JavaScript, text-JSON fallback or executable payload.
const MAX_SIZE:=64*1024*1024
const MAX_DEPTH:=512
const NUMBER_MARKERS:=[85,105,73,108,76,100,68]
const CONTAINER_TYPES:=[90,84,70,85,105,73,108,76,100,68,67,83,72,91,123]
class BigInteger:
	extends RefCounted
	var decimal: String
	func _init(value: String)->void:decimal=value
var data:=PackedByteArray()
var cursor:=0
var nodes:=0
var failure: String=""
var encoded:=PackedByteArray()

static func decode(bytes: PackedByteArray)->Dictionary:
	if bytes.is_empty() or bytes.size()>MAX_SIZE:return {"error":"Invalid NUI UBJSON size"}
	var reader:=new();reader.data=bytes
	var value: Variant=reader.read_value(-1,0)
	while reader.failure.is_empty() and reader.cursor<bytes.size() and bytes[reader.cursor]==78:reader.cursor+=1
	if not reader.failure.is_empty():return {"error":reader.failure}
	if reader.cursor!=bytes.size():return {"error":"Trailing NUI UBJSON data"}
	return {"value":value}

func need(count: int)->bool:
	if count<0 or count>data.size()-cursor:
		failure="Truncated NUI UBJSON"
		return false
	return true

func take()->int:
	if not need(1):return -1
	var value:=int(data[cursor]);cursor+=1;return value

func marker()->int:
	var value:=take()
	while value==78 and failure.is_empty():value=take()
	return value

func number(kind: int)->Variant:
	var size: int={85:1,105:1,73:2,108:4,76:8,100:4,68:8}.get(kind,0)
	if size==0:failure="Invalid NUI UBJSON number marker";return null
	if not need(size):return null
	var value: Variant=null
	if kind==85:value=int(data[cursor])
	elif kind==105:
		var raw:=int(data[cursor]);value=raw-256 if raw>127 else raw
	else:
		var reversed:=PackedByteArray();reversed.resize(size)
		for index in size:reversed[index]=data[cursor+size-1-index]
		match kind:
			73:value=int(reversed.decode_s16(0))
			108:value=int(reversed.decode_s32(0))
			76:value=int(reversed.decode_s64(0))
			100:
				var single:=float(reversed.decode_float(0));value=single if is_finite(single) else null
			68:
				var double:=float(reversed.decode_double(0));value=double if is_finite(double) else null
	cursor+=size
	return value

func length()->int:
	var kind:=marker()
	if not failure.is_empty():return -1
	var value: Variant=number(kind)
	if not failure.is_empty():return -1
	if not value is int or int(value)<0 or int(value)>MAX_SIZE:
		failure="Invalid NUI UBJSON length"
		return -1
	return int(value)

func read_string()->String:
	var count:=length()
	if not failure.is_empty() or not need(count):return ""
	var raw:=data.slice(cursor,cursor+count);cursor+=count
	var value:=raw.get_string_from_utf8()
	if value.to_utf8_buffer()!=raw:failure="Invalid NUI UBJSON UTF-8";return ""
	return value

func read_value(known_marker: int=-1,depth: int=0)->Variant:
	if depth>MAX_DEPTH or nodes>=MAX_SIZE:failure="NUI UBJSON nesting limit";return null
	nodes+=1
	var kind:=known_marker if known_marker>=0 else marker()
	if not failure.is_empty():return null
	match kind:
		90:return null
		84:return true
		70:return false
		67:
			var code:=take()
			if code>127:failure="Invalid NUI UBJSON character";return null
			return char(code)
		83:return read_string()
		72:
			var source:=read_string()
			if not failure.is_empty():return null
			var valid:=RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[Ee][+-]?[0-9]+)?$")
			if valid.search(source)==null:failure="Invalid NUI high-precision number";return null
			if source.is_valid_int():
				var digits:=source.substr(1) if source.begins_with("-") else source
				var limit:="9223372036854775808" if source.begins_with("-") else "9223372036854775807"
				if digits.length()<limit.length() or (digits.length()==limit.length() and digits<=limit):return int(source)
				return BigInteger.new(source)
			if source.contains(".") or source.contains("e") or source.contains("E"):
				var decimal:=float(source);return decimal if is_finite(decimal) else null
			return BigInteger.new(source)
		91,123:return read_container(kind,depth)
		_:return number(kind)

func read_container(kind: int,depth: int)->Variant:
	var is_array:=kind==91
	var end:=93 if is_array else 125
	var typed:=-1
	var count:=-1
	if cursor<data.size() and data[cursor]==36:
		cursor+=1;typed=take()
		if typed not in CONTAINER_TYPES:failure="Invalid NUI UBJSON container type";return null
		if cursor>=data.size() or data[cursor]!=35:failure="Typed NUI UBJSON container needs a count";return null
	if cursor<data.size() and data[cursor]==35:
		cursor+=1;count=length()
		if not failure.is_empty():return null
	var array: Array=[]
	var object: Dictionary={}
	var index:=0
	while failure.is_empty() and (index<count if count>=0 else cursor<data.size() and data[cursor]!=end):
		if index>=MAX_SIZE:failure="NUI UBJSON nesting limit";break
		if cursor>=data.size() and typed not in [90,84,70]:failure="Truncated NUI UBJSON container";break
		var key:=str(index) if is_array else read_string()
		if not failure.is_empty():break
		var value: Variant=read_value(typed,depth+1)
		if not failure.is_empty():break
		if is_array:array.append(value)
		else:object[key]=value
		index+=1
	if count<0:
		if not need(1):return null
		if data[cursor]!=end:failure="Truncated NUI UBJSON container";return null
		cursor+=1
	return array if is_array else object

static func encode(value: Variant)->Dictionary:
	var writer:=new()
	writer.write_value(value,0)
	if not writer.failure.is_empty():return {"error":writer.failure}
	return {"bytes":writer.encoded}

func append_byte(value: int)->void:
	if encoded.size()>=MAX_SIZE:failure="NUI UBJSON exceeds message storage";return
	encoded.append(value&255)

func append_big(bytes: PackedByteArray)->void:
	if bytes.size()>MAX_SIZE-encoded.size():failure="NUI UBJSON exceeds message storage";return
	for index in range(bytes.size()-1,-1,-1):encoded.append(bytes[index])

func write_integer(value: int)->void:
	var kind:=105;var size:=1
	if value>=128 and value<=255:kind=85
	elif value>=-128 and value<=127:pass
	elif value>=-32768 and value<=32767:kind=73;size=2
	elif value>=-2147483648 and value<=2147483647:kind=108;size=4
	else:kind=76;size=8
	append_byte(kind)
	if not failure.is_empty():return
	var bytes:=PackedByteArray();bytes.resize(size)
	match size:
		1:bytes[0]=value&255
		2:bytes.encode_s16(0,value)
		4:bytes.encode_s32(0,value)
		8:bytes.encode_s64(0,value)
	append_big(bytes)

func write_string(value: String)->void:
	var bytes:=value.to_utf8_buffer()
	if bytes.size()>MAX_SIZE:failure="NUI UBJSON string is too large";return
	write_integer(bytes.size())
	if bytes.size()>MAX_SIZE-encoded.size():failure="NUI UBJSON exceeds message storage";return
	encoded.append_array(bytes)

func write_value(value: Variant,depth: int)->void:
	if not failure.is_empty():return
	if depth>MAX_DEPTH:failure="NUI UBJSON nesting limit";return
	if value==null:append_byte(90);return
	if value is bool:append_byte(84 if value else 70);return
	if value is BigInteger:
		var source: String=str(value.decimal)
		if RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)$").search(source)==null:failure="Invalid NUI high-precision number";return
		append_byte(72);write_string(source);return
	if value is int:write_integer(value);return
	if value is float:
		if not is_finite(value):append_byte(90);return
		var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
		var negative_zero: bool=value==0.0 and (int(bytes[7])&0x80)!=0
		if not negative_zero and value==floor(value) and absf(value)<=9007199254740991.0:write_integer(int(value));return
		append_byte(68);append_big(bytes)
		return
	if value is String:append_byte(83);write_string(value);return
	if value is Array:
		append_byte(91)
		for item in value:write_value(item,depth+1)
		append_byte(93)
		return
	if value is Dictionary:
		append_byte(123)
		var keys: Array=value.keys();keys.sort()
		for key in keys:
			if not key is String:failure="Invalid NUI object key";return
			write_string(str(key));write_value(value[key],depth+1)
		append_byte(125)
		return
	failure="Invalid NUI JSON value"
