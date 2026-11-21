extends RefCounted
# Original client77c140 speech reader. Server text, source IDs and names stay
# intact for the existing Godot chat/overhead text owner to resolve.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")
const CHANNELS=[1,2,3,4,5,6,7,8,9,10,11,12,14,15,17,18,19,20,22,30]

static func remote_name(channel: int)->bool:
	return channel>=0 and channel<31 and ((0x401e4054 >> channel)&1)!=0

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=9 or int(packet[2]) not in CHANNELS:return {"error":"Invalid native speech envelope"}
	var channel:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var message: Dictionary={"kind":"server-speech","channel":channel}
	if channel==7:
		message.kind="script-sound";message.objectId=reader.object_id()
		# readCExoString retains the source bytes for script sounds. A leading
		# NUL normalizes to an empty CExoString, including its byte view.
		reader.expect_type(14);reader.expect_type(8)
		var length_bytes:=reader.raw(4)
		var length:=int(length_bytes.decode_u32(0)) if length_bytes.size()==4 else 0
		if length>64*1024*1024:reader.error="Native message string exceeds bound"
		var raw_sound:=reader.raw(length) if reader.error.is_empty() else PackedByteArray()
		message.soundBytes=raw_sound if not raw_sound.is_empty() and raw_sound[0]!=0 else PackedByteArray()
		message.sound=GffText.decode(message.soundBytes)
	elif channel==5:message.text={"text":reader.string()}
	else:
		message.objectId=reader.object_id()
		if channel in [11,12]:
			message.contextId=reader.object_id()
			message.text=Characters.localized(reader)
			message.sound=reader.resref()
			message.soundFlag=reader.boolean()
			message.soundObjectId=reader.object_id()
		else:
			message.text={"strRef":reader.dword()} if channel in [8,9,10,15] else {"text":reader.string()}
			if remote_name(channel):
				message.position=[reader.float32(),reader.float32(),reader.float32()]
				message.speakerName={"firstName":Characters.localized(reader),"lastName":Characters.localized(reader)} if reader.boolean() else {"text":reader.string()}
	if not reader.finished():return {"error":"Invalid native speech fields: "+reader.error}
	return message
