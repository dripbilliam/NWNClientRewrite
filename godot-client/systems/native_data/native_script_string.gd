extends RefCounted
# Normal client subset of src/script_string.js. GDScript returns explicit
# errors where the old JavaScript helper threw on unavailable byte encoding.
const Values=preload("res://systems/native_data/character_record_values.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")
const EXTENSIONS=[0x20ac,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x17d,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x17e,0x178]
const ENCODING_ERROR="Native script string byte encoding is unavailable for this text"
static func _i32(value: Variant) -> int:return Values.signed32(int(value))
static func right(value: Variant,count: Variant) -> Dictionary:
	var amount:=_i32(count)
	if amount<0:return {"value":""}
	var source:=str(value)
	for index in source.length():
		var code:=source.unicode_at(index)
		if code>255 and code not in EXTENSIONS:return {"error":ENCODING_ERROR}
	return {"value":source if amount>=source.length() else source.substr(source.length()-amount,amount)}
static func bytes(value: Variant) -> Dictionary:
	var text: Dictionary=right(value,0x7fffffff)
	if text.has("error"):return text
	var source: String=text.value
	var output:=PackedByteArray()
	for index in source.length():
		var code:=source.unicode_at(index)
		if code<=255:output.append(code)
		else:
			var encoded: Dictionary=GffText.encode(String.chr(code))
			if encoded.has("error") or encoded.bytes.is_empty():return {"error":ENCODING_ERROR}
			output.append(encoded.bytes[0])
	return {"value":output}
static func to_int(value: Variant) -> Dictionary:
	var text: Dictionary=right(value,0x7fffffff)
	if text.has("error"):return text
	var source: String=text.value
	var nul:=source.find(String.chr(0))
	if nul>=0:source=source.substr(0,nul)
	var at:=0
	while at<source.length() and source.unicode_at(at) in [9,10,11,12,13,32]:at+=1
	var negative:=false
	if at<source.length() and source.unicode_at(at) in [43,45]:negative=source.unicode_at(at)==45;at+=1
	var found:=false;var magnitude:=0;var limit:=2147483648 if negative else 2147483647
	while at<source.length():
		var digit:=source.unicode_at(at)-48
		if digit<0 or digit>9:break
		found=true;magnitude=mini(limit,magnitude*10+digit);at+=1
	return {"value":(-magnitude if negative else magnitude) if found else 0}
static func substring(value: Variant,start: Variant,count: Variant) -> Dictionary:
	var begin:=_i32(start);var amount:=_i32(count)
	if begin<0:return {"value":""}
	var text: Dictionary=right(value,0x7fffffff)
	if text.has("error"):return text
	var source: String=text.value
	if begin>=source.length():return {"value":""}
	var available:=source.length()-begin
	return {"value":source.substr(begin,available if amount<0 or amount>available else amount)}
static func change_case(value: Variant,upper: bool=false) -> Dictionary:
	var text: Dictionary=right(value,0x7fffffff)
	if text.has("error"):return text
	var source: String=text.value
	var output: String=""
	for index in source.length():
		var code:=source.unicode_at(index)
		if code>127:return {"error":"Native script string case conversion for locale-specific bytes is unavailable"}
		if upper and code>=97 and code<=122:code-=32
		elif not upper and code>=65 and code<=90:code+=32
		output+=String.chr(code)
	return {"value":output}
