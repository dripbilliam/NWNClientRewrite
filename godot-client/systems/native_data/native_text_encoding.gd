extends RefCounted
# Native token scanning always operates on bytes. Decode only at the UI edge;
# retain the raw API for noncanonical DBCS byte sequences and control payloads.
const Binary=preload("res://systems/native_data/binary_data.gd")
const LANGUAGE_CODES={0:1252,1:1252,2:1252,3:1252,4:1252,5:1250,128:949,129:950,130:936,131:932}
static var tables: Dictionary={}
static var reverse: Dictionary={}
static func table(language: int) -> Dictionary:
	if not LANGUAGE_CODES.has(language):return {}
	var code:=int(LANGUAGE_CODES[language])
	if not tables.has(code):
		var document: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/native_text_codepages.json"))
		if not document is Dictionary or document.get("version")!=1:return {}
		var row: Dictionary=document.get("tables",{}).get(str(code),{})
		if not row.get("single") is Array or row.single.size()!=256 or not row.get("pairs") is String:return {}
		row.pairs=Marshalls.base64_to_raw(row.pairs)
		if code not in [1250,1252] and row.pairs.size()!=131072:return {}
		tables[code]=row
	return tables[code]
static func encode(value: String,language: int=0) -> Dictionary:
	var row:=table(language)
	if row.is_empty():return {"ready":false,"reason":"Native talk byte encoding is unavailable."}
	var code:=int(LANGUAGE_CODES[language])
	if not reverse.has(code):
		var map: Dictionary={}
		for byte in 256:
			if int(row.single[byte])>=0:map[int(row.single[byte])]=byte
		var pairs: PackedByteArray=row.pairs
		for key in range(32768,65536) if not pairs.is_empty() else []:
			var point:=pairs.decode_u16(key*2)
			if point!=65535 and not map.has(point):map[point]=key
		for key in row.get("preferred",{}):map[int(key)]=int(row.preferred[key])
		reverse[code]=map
	var bytes:=PackedByteArray();var mapping: Dictionary=reverse[code]
	for at in value.length():
		var point:=value.unicode_at(at)
		if not mapping.has(point):return {"ready":false,"reason":"Native talk byte encoding cannot represent this character."}
		var key:=int(mapping[point])
		if key>255:bytes.append(key>>8)
		bytes.append(key&255)
	return {"ready":true,"bytes":bytes}
static func decode(bytes: PackedByteArray,language: int=0,markup: bool=false) -> Dictionary:
	var row:=table(language)
	if row.is_empty():return {"ready":false,"reason":"Native talk byte decoding is unavailable."}
	var result:="";var at:=0;var pairs: PackedByteArray=row.pairs
	while at<bytes.size():
		# RGB payloads belong to the native font command, not the language's
		# character decoder. Preserve their historical Rich byte projection.
		if markup and at+5<bytes.size() and bytes[at]==60 and bytes[at+1]==99 and bytes[at+5]==62:
			result+=Binary.new(bytes.slice(at,at+6)).text(0,6);at+=6;continue
		var point:=int(row.single[bytes[at]])
		if point>=0:at+=1
		else:
			if pairs.is_empty() or at+1>=bytes.size():return {"ready":false,"reason":"Native localized text has an incomplete byte sequence."}
			point=pairs.decode_u16(((int(bytes[at])<<8)|int(bytes[at+1]))*2);at+=2
			if point==65535:return {"ready":false,"reason":"Native localized text has an invalid byte sequence."}
		if point==0:break
		result+=String.chr(point)
	return {"ready":true,"text":result}
