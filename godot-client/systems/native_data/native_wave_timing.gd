extends RefCounted
# CResWave::GetWaveInfo timing. This reads RIFF fmt/data lengths independently
# of PCM/IMA decoding, including the authored compressed bit depth.
static func tag(bytes: PackedByteArray,at: int) -> String:
	return bytes.slice(at,at+4).get_string_from_ascii()
static func parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<12 or tag(bytes,0)!="RIFF" or tag(bytes,8)!="WAVE":return {"timing":null,"error":""}
	var end:=int(bytes.decode_u32(4))+8
	if end>bytes.size() or end<12:return {"timing":null,"error":"Truncated native WAV timing container"}
	var channels:=0;var sample_rate:=0;var bits:=0;var data_bytes: Variant=null
	var at:=12
	while at<end:
		if at+8>end:return {"timing":null,"error":"Truncated native WAV timing chunk"}
		var size:=int(bytes.decode_u32(at+4));var start:=at+8
		if start+size>end:return {"timing":null,"error":"Truncated native WAV timing data"}
		if tag(bytes,at)=="fmt ":
			if size<16:return {"timing":null,"error":"Native WAV timing format is unavailable"}
			channels=int(bytes.decode_u16(start+2));sample_rate=int(bytes.decode_u32(start+4));bits=int(bytes.decode_u16(start+14))
		elif tag(bytes,at)=="data":data_bytes=size
		at=start+size+(size&1)
	if channels==0 or sample_rate==0 or bits==0 or data_bytes==null:return {"timing":null,"error":"Native WAV timing fields are unavailable"}
	var divisor: int=(bits*sample_rate)&0xffffffff
	if divisor==0:return {"timing":null,"error":"Native WAV timing divides by zero"}
	return {"timing":{"channels":channels,"sampleRate":sample_rate,"bits":bits,"dataBytes":int(data_bytes),"duration":int((8.0/float(divisor))*floor(float(data_bytes)/float(channels))*1000.0)&0xffffffff},"error":""}
