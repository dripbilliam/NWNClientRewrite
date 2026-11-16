extends RefCounted
# Original client7962f0 conversation stream. Offered server reply IDs remain
# authoritative; Godot only presents them and echoes an admitted selection.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<3 or packet[0]!=80 or packet[1]!=20 or int(packet[2]) not in [1,2,4,5]:return {"error":"Invalid native dialog envelope"}
	var minor:=int(packet[2])
	if minor==5:return {"kind":"dialog-close"} if packet.size()==3 else {"error":"Invalid native dialog-close length"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var message: Dictionary={}
	match minor:
		1:message={"kind":"dialog-entry","ownerId":reader.object_id(),"speakerId":reader.object_id(),"tokenObjectId":reader.object_id(),"text":Characters.localized(reader)}
		2:
			message={"kind":"dialog-replies","entryId":reader.dword(),"end":reader.boolean(),"flag1":reader.boolean(),"tokenObjectId":reader.object_id(),"firstCount":reader.dword(),"secondCount":reader.dword(),"replies":[]}
			var count:=int(message.firstCount)+int(message.secondCount)
			if count<0 or count>(reader.byte_size-reader.byte_cursor)/8:return {"error":"Invalid native dialog reply count"}
			for _index in range(count):message.replies.append({"text":Characters.localized(reader),"id":reader.dword()})
		4:message={"kind":"dialog-selected","end":reader.byte(),"field0":reader.dword(),"field1":reader.dword(),"tokenObjectId":reader.object_id(),"text":Characters.localized(reader)}
	if not reader.finished():return {"error":"Invalid native dialog fields: "+reader.error}
	return message
