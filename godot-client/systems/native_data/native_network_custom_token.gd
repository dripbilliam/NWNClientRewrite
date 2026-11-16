extends RefCounted
# Original server 50/1 carries signed token ID followed by CExoString bytes.
# The receiver returns data only; script-side reserved ID guards and local token
# table ownership belong to separate consumers.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Western=preload("res://systems/native_data/native_gff_text.gd")
const MAX_TEXT:=64*1024*1024

static func accepted(major: int,minor: int)->bool:
	return major==50 and minor==1

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native custom-token envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native custom-token stream: "+reader.error}
	var id: int=reader.signed_dword()
	var length: int=reader.dword()
	if not reader.error.is_empty() or length>MAX_TEXT or length>reader.byte_size-reader.byte_cursor:
		return {"error":"Invalid native custom-token string length"}
	var token_bytes: PackedByteArray=reader.raw(length)
	if not reader.finished():
		return {"error":"Invalid native custom-token fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	# Godot Strings cannot retain U+0000: converting such a token replaces it
	# with U+FFFD. Keep its exact native byte payload and make the lossy text edge
	# explicit. The native table treats a leading NUL as an empty assignment.
	if not token_bytes.is_empty() and token_bytes[0]==0:token_bytes=PackedByteArray()
	var complete:=not token_bytes.has(0)
	return {"kind":"custom-token","major":50,"minor":1,"id":id,"textBytes":token_bytes,"text":Western.decode(token_bytes) if complete else null,"textComplete":complete}
