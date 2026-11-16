extends RefCounted
# Original server 24/5 changes a received item's caption fields only. Format1
# is the production stream; format0 is available for original sender evidence.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==24 and minor==5

static func decode_packet(packet: PackedByteArray,format_mode: int=1)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])) or format_mode not in [0,1]:
		return {"error":"Invalid native item caption envelope or format"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3),format_mode):
		return {"error":"Invalid native item caption stream: "+reader.error}
	var item_id:=reader.object_id()
	var mode:=reader.signed_dword()
	var caption:=reader.string()
	if not reader.finished():
		return {"error":"Invalid native item caption fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"item-text-bubble-override","major":24,"minor":5,"itemId":item_id,"mode":mode,"text":caption}
