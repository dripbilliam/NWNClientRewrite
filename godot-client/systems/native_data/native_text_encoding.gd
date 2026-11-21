extends RefCounted
# Native token scanning always operates on bytes. Decode only at the UI edge;
# retain the raw API for noncanonical DBCS byte sequences and control payloads.
const Binary=preload("res://systems/native_data/binary_data.gd")
const LANGUAGE_CODES={0:1252,1:1252,2:1252,3:1252,4:1252,5:1250,128:949,129:950,130:936,131:932}
static var tables: Dictionary={}
static var reverse: Dictionary={}
static var gb_ranges: Array=[]
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
static func gb18030_point(pointer: int) -> int:
	# WHATWG's index-gb18030-ranges.txt is stored as 207 compact start pairs.
	if pointer>39419 and pointer<189000 or pointer>1237575:return -1
	if pointer==7457:return 0xe7c7
	if gb_ranges.is_empty():
		var index: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/web_gb18030_ranges.json"))
		if not index is Dictionary or not index.get("ranges") is Array or index.ranges.size()!=207:return -1
		gb_ranges=index.ranges
	var low:=0;var high:=gb_ranges.size()
	while low<high:
		var middle: int=(low+high)>>1
		if int(gb_ranges[middle][0])<=pointer:low=middle+1
		else:high=middle
	if low==0:return -1
	var start: Array=gb_ranges[low-1]
	return int(start[1])+pointer-int(start[0])
static func decode(bytes: PackedByteArray,language: int=0,markup: bool=false,terminate_at_nul: bool=true,replace_malformed: bool=false) -> Dictionary:
	var row:=table(language)
	if row.is_empty():return {"ready":false,"reason":"Native talk byte decoding is unavailable."}
	var result:="";var at:=0;var pairs: PackedByteArray=row.pairs;var code:=int(LANGUAGE_CODES[language])
	while at<bytes.size():
		# RGB payloads belong to the native font command, not the language's
		# character decoder. Preserve their historical Rich byte projection.
		if markup and at+5<bytes.size() and bytes[at]==60 and bytes[at+1]==99 and bytes[at+5]==62:
			result+=Binary.new(bytes.slice(at,at+6)).text(0,6);at+=6;continue
		var byte:=int(bytes[at]);var point:=int(row.single[byte])
		if point>=0:
			at+=1
			# WHATWG TextDecoder replaces undefined Windows single-byte slots.
			if replace_malformed and code in [1250,1252] and byte>=0x80 and byte<0xa0 and point==byte:point=0xfffd
			# The original JS uses Shift_JIS, whose four Windows private-use
			# single-byte extensions are decoder errors.
			if replace_malformed and code==932 and byte in [0xa0,0xfd,0xfe,0xff]:point=0xfffd
		else:
			if pairs.is_empty() or at+1>=bytes.size():
				if not replace_malformed:return {"ready":false,"reason":"Native localized text has an incomplete byte sequence."}
				point=0xfffd;at+=1
			else:
				var trail:=int(bytes[at+1])
				if replace_malformed and code==936 and byte>=0x81 and byte<=0xfe and trail>=0x30 and trail<=0x39:
					if at+2>=bytes.size():result+=String.chr(0xfffd);break
					var third:=int(bytes[at+2])
					if third<0x81 or third>0xfe:result+=String.chr(0xfffd);at+=1;continue
					if at+3>=bytes.size():result+=String.chr(0xfffd);break
					var fourth:=int(bytes[at+3])
					if fourth<0x30 or fourth>0x39:result+=String.chr(0xfffd);at+=1;continue
					var pointer:=((byte-0x81)*10*126*10)+((trail-0x30)*126*10)+((third-0x81)*10)+fourth-0x30
					var scalar:=gb18030_point(pointer)
					result+=String.chr(scalar if scalar>=0 else 0xfffd);at+=4;continue
				if replace_malformed and code==950 and byte==0x88 and trail in [0x62,0x64,0xa3,0xa5]:
					result+=String.chr(0x00ca if trail in [0x62,0x64] else 0x00ea)
					result+=String.chr(0x0304 if trail in [0x62,0xa3] else 0x030c)
					at+=2
					continue
				point=pairs.decode_u16(((byte<<8)|trail)*2)
				if point==65535:
					if not replace_malformed:return {"ready":false,"reason":"Native localized text has an invalid byte sequence."}
					point=0xfffd
					# Legacy multibyte decoders reconsume only an ASCII trail.
					at+=(1 if trail<0x80 else 2)
				else:at+=2
		if point==0 and terminate_at_nul:break
		result+=String.chr(point)
	return {"ready":true,"text":result}
