extends RefCounted
const Text=preload("res://systems/native_data/native_gff_text.gd")
static func byte(bytes: PackedByteArray,value: int)->void:bytes.append(value & 255)
static func word(bytes: PackedByteArray,value: int)->void:
	byte(bytes,value);byte(bytes,value >> 8)
static func dword(bytes: PackedByteArray,value: int)->void:
	for shift in [0,8,16,24]:byte(bytes,value >> shift)
static func string(bytes: PackedByteArray,value: Variant)->bool:
	if not value is String:return false
	var encoded: Dictionary=Text.encode(value)
	if not encoded.has("bytes") or encoded.bytes.size()>255:return false
	byte(bytes,encoded.bytes.size());bytes.append_array(encoded.bytes)
	return true
static func integer(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

static func connect_request(input: Dictionary)->Dictionary:
	var build: Variant=input.get("build")
	if not build is Dictionary:return {"error":"Native login build is unavailable"}
	for value in [input.get("port"),input.get("connectionType"),build.get("number"),input.get("language"),input.get("applicationId"),input.get("platformId"),build.get("revision"),build.get("postfix")]:
		if not integer(value):return {"error":"Native login numeric field is unavailable"}
	var bytes: PackedByteArray="BNCS".to_ascii_buffer()
	word(bytes,int(input.port));byte(bytes,int(input.connectionType));dword(bytes,int(build.number))
	word(bytes,3);byte(bytes,int(input.language));dword(bytes,int(input.applicationId))
	for field in ["name","publicKey","legacyPublicKey"]:
		if not string(bytes,input.get(field)):return {"error":"Native login "+field+" text is unavailable or exceeds its wire length"}
	byte(bytes,int(input.platformId))
	if not string(bytes,input.get("platformIdentifier")):return {"error":"Native login platform identity is unavailable"}
	dword(bytes,int(build.revision))
	if not string(bytes,build.get("commit")):return {"error":"Native login commit is unavailable"}
	dword(bytes,int(build.postfix))
	return {"bytes":bytes}

static func validation_response(input: Dictionary)->Dictionary:
	for field in ["keyResponse","communityResponse","passwordResponse"]:
		if not input.get(field) is String:return {"error":"Native validation response field is unavailable"}
	var bytes: PackedByteArray="BNVS".to_ascii_buffer()
	byte(bytes,80 if not input.passwordResponse.is_empty() else 86)
	byte(bytes,1 if not input.keyResponse.is_empty() else 0)
	if not input.keyResponse.is_empty() and not string(bytes,input.keyResponse):return {"error":"Invalid native key response"}
	if not string(bytes,input.communityResponse):return {"error":"Invalid native community response"}
	if not input.passwordResponse.is_empty() and not string(bytes,input.passwordResponse):return {"error":"Invalid native password response"}
	return {"bytes":bytes}

static func read_string(bytes: PackedByteArray,at: int)->Dictionary:
	if at>=bytes.size():return {"error":"Truncated native login packet"}
	var length: int=bytes[at]
	if at+1+length>bytes.size():return {"error":"Truncated native login packet"}
	var value:=bytes.slice(at+1,at+1+length)
	return {"text":"" if value.size()>0 and value[0]==0 else Text.decode(value),"at":at+1+length}

static func read_connect_response(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<8 or bytes.slice(0,4).get_string_from_ascii()!="BNCR":return {"error":"Truncated or unexpected native connection response"}
	var port: int=bytes.decode_u16(4);var status: int=bytes[6]
	if status==82:
		var reason: int=bytes[7]
		return {"kind":"rejected","port":port,"reason":reason,"connectionError":reason if reason in [2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19] else 1}
	if status!=80 and status!=86:return {"error":"Unsupported native connection response status"}
	var at:=7;var password_challenge:=""
	if status==80:
		var password: Dictionary=read_string(bytes,at)
		if password.has("error"):return password
		password_challenge=password.text;at=password.at
	var key: Dictionary=read_string(bytes,at)
	if key.has("error"):return key
	at=key.at
	var community: Dictionary=read_string(bytes,at)
	if community.has("error"):return community
	return {"kind":"challenge","port":port,"passwordRequired":status==80,"passwordChallenge":password_challenge,"keyChallenge":key.text,"communityChallenge":community.text,"trailingBytes":bytes.size()-int(community.at)}

static func read_validation_response(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<6 or bytes.slice(0,4).get_string_from_ascii()!="BNVR":return {"error":"Truncated or unexpected native validation response"}
	var status: int=bytes[4]
	if status==82:return {"kind":"rejected","connectionError":int(bytes[5])}
	if status!=65:return {"error":"Unsupported native validation response status"}
	if bytes.size()<9:return {"error":"Truncated native validation response"}
	var build: Dictionary={"number":0,"revision":0,"postfix":0}
	if bytes.size()>=17:build.number=int(bytes.decode_u32(9));build.revision=int(bytes.decode_u32(13))
	if bytes.size()>=21:build.postfix=int(bytes.decode_u32(17))
	return {"kind":"accepted","applicationId":int(bytes.decode_u32(5)),"build":build}

static func disconnect_request()->PackedByteArray:return "BNDM".to_ascii_buffer()

static func read_disconnect_response(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4 or bytes.slice(0,4).get_string_from_ascii()!="BNDP":return {"error":"Truncated or unexpected native disconnect response"}
	var result: Dictionary={"strRef":null,"text":""}
	var at:=4
	if bytes.size()>=8:result.strRef=int(bytes.decode_u32(4));at=8
	if at+2<=bytes.size():
		var length: int=bytes.decode_u16(at);at+=2
		if length<1024 and at+length<=bytes.size():result.text=Text.decode(bytes.slice(at,at+length))
	return result
