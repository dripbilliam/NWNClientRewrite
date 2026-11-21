extends RefCounted
const Text=preload("res://systems/native_data/native_gff_text.gd")
static func byte(bytes: PackedByteArray,value: int)->void:bytes.append(value & 255)
static func word(bytes: PackedByteArray,value: int)->void:
	byte(bytes,value);byte(bytes,value >> 8)
static func dword(bytes: PackedByteArray,value: int)->void:
	for shift in [0,8,16,24]:byte(bytes,value >> shift)
static func string_error(bytes: PackedByteArray,value: Variant)->String:
	if not value is String:return "Native login string is unavailable"
	var encoded: Dictionary=Text.encode(value)
	if encoded.has("error"):return str(encoded.error)
	if encoded.bytes.size()>255:return "Native login string exceeds its wire length"
	byte(bytes,encoded.bytes.size());bytes.append_array(encoded.bytes)
	return ""
static func integer_error(value: Variant,label: String)->String:
	if (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)):return ""
	return "Native login "+label+" is unavailable"

static func connect_request(input: Dictionary)->Dictionary:
	var build: Variant=input.get("build")
	if not build is Dictionary:return {"error":"Native login build is unavailable"}
	var bytes: PackedByteArray="BNCS".to_ascii_buffer()
	for entry in [[input.get("port"),"port","word"],[input.get("connectionType"),"connection type","byte"],[build.get("number"),"build","dword"]]:
		var error:=integer_error(entry[0],entry[1]);if not error.is_empty():return {"error":error}
		match entry[2]:
			"word":word(bytes,int(entry[0]))
			"byte":byte(bytes,int(entry[0]))
			_:dword(bytes,int(entry[0]))
	word(bytes,3)
	for entry in [[input.get("language"),"language","byte"],[input.get("applicationId"),"application ID","dword"]]:
		var error:=integer_error(entry[0],entry[1]);if not error.is_empty():return {"error":error}
		if entry[2]=="byte":byte(bytes,int(entry[0]))
		else:dword(bytes,int(entry[0]))
	for field in ["name","publicKey","legacyPublicKey"]:
		var error:=string_error(bytes,input.get(field));if not error.is_empty():return {"error":error}
	var error:=integer_error(input.get("platformId"),"platform ID");if not error.is_empty():return {"error":error}
	byte(bytes,int(input.platformId))
	error=string_error(bytes,input.get("platformIdentifier"));if not error.is_empty():return {"error":error}
	error=integer_error(build.get("revision"),"revision");if not error.is_empty():return {"error":error}
	dword(bytes,int(build.revision))
	error=string_error(bytes,build.get("commit"));if not error.is_empty():return {"error":error}
	error=integer_error(build.get("postfix"),"postfix");if not error.is_empty():return {"error":error}
	dword(bytes,int(build.postfix))
	return {"bytes":bytes}

static func validation_response(input: Dictionary)->Dictionary:
	for field in ["keyResponse","communityResponse","passwordResponse"]:
		if not input.get(field) is String:return {"error":"Native validation response fields are unavailable"}
	var bytes: PackedByteArray="BNVS".to_ascii_buffer()
	byte(bytes,80 if not input.passwordResponse.is_empty() else 86)
	byte(bytes,1 if not input.keyResponse.is_empty() else 0)
	if not input.keyResponse.is_empty():
		var error:=string_error(bytes,input.keyResponse);if not error.is_empty():return {"error":error}
	var error:=string_error(bytes,input.communityResponse);if not error.is_empty():return {"error":error}
	if not input.passwordResponse.is_empty():
		error=string_error(bytes,input.passwordResponse);if not error.is_empty():return {"error":error}
	return {"bytes":bytes}

static func read_string(bytes: PackedByteArray,at: int)->Dictionary:
	if at>=bytes.size():return {"error":"Truncated native login packet"}
	var length: int=bytes[at]
	if at+1+length>bytes.size():return {"error":"Truncated native login packet"}
	var value:=bytes.slice(at+1,at+1+length)
	return {"text":"" if value.size()>0 and value[0]==0 else Text.decode(value),"at":at+1+length}

static func read_connect_response(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4:return {"error":"Truncated native login packet"}
	if bytes.slice(0,4).get_string_from_ascii()!="BNCR":return {"error":"Unexpected native login packet type"}
	if bytes.size()<8:return {"error":"Truncated native login packet"}
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
	if bytes.size()<4:return {"error":"Truncated native login packet"}
	if bytes.slice(0,4).get_string_from_ascii()!="BNVR":return {"error":"Unexpected native login packet type"}
	if bytes.size()<6:return {"error":"Truncated native login packet"}
	var status: int=bytes[4]
	if status==82:return {"kind":"rejected","connectionError":int(bytes[5])}
	if status!=65:return {"error":"Unsupported native validation response status"}
	if bytes.size()<9:return {"error":"Truncated native login packet"}
	var build: Dictionary={"number":0,"revision":0,"postfix":0}
	if bytes.size()>=17:build.number=int(bytes.decode_u32(9));build.revision=int(bytes.decode_u32(13))
	if bytes.size()>=21:build.postfix=int(bytes.decode_u32(17))
	return {"kind":"accepted","applicationId":int(bytes.decode_u32(5)),"build":build}

static func disconnect_request()->PackedByteArray:return "BNDM".to_ascii_buffer()

static func read_disconnect_response(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4:return {"error":"Truncated native login packet"}
	if bytes.slice(0,4).get_string_from_ascii()!="BNDP":return {"error":"Unexpected native login packet type"}
	var result: Dictionary={"strRef":null,"text":""}
	var at:=4
	if bytes.size()>=8:result.strRef=int(bytes.decode_u32(4));at=8
	if at+2<=bytes.size():
		var length: int=bytes.decode_u16(at);at+=2
		if length<1024 and at+length<=bytes.size():result.text=Text.decode(bytes.slice(at,at+length))
	return result
