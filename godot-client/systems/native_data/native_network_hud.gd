extends RefCounted
# Godot-owned original-server HUD message decoding. This is deliberately a
# packet decoder only; the network world/UI own journal and map-pin lifetimes.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const JOURNAL_MINORS=[1,2,3,4,5,6,7,8,9,12]
const MAP_PIN_MINORS=[1,4,6]
const INVALID:=0x7f000000

static func valid_id(value: int)->bool:return value>=0 and value<=0xffffffff

# Original HUD sender 6/13; rest admission and outcome belong to the server.
static func rest_request()->PackedByteArray:return PackedByteArray([112,6,13])

static func character_sheet_request(target_id: int,page: int)->Dictionary:
	if not valid_id(target_id) or page< -128 or page>127:return {"error":"Invalid native character-sheet request"}
	var bytes:=PackedByteArray([112,21,1,12,0,0,0]);bytes.resize(13)
	bytes[7]=page&255;bytes.encode_u32(8,target_id);bytes[12]=0x60
	return {"bytes":bytes}

static func journal_window_request(opened: bool)->PackedByteArray:
	return PackedByteArray([112,28,10 if opened else 11])

static func gui_request(event_id: int,selection_id: int,target_id: int,include_position: bool)->PackedByteArray:
	var size:=28 if include_position else 16
	var bytes:=PackedByteArray([112,53,1]);bytes.resize(size)
	bytes.encode_u32(3,size-1);bytes.encode_u16(7,event_id);bytes.encode_u16(9,selection_id);bytes.encode_u32(11,target_id)
	# The versioned XYZ values are all zero; the resized byte stream retains
	# their float32 representation without replacing them with other coordinates.
	bytes[size-1]=0x60
	return bytes

static func skill_description_request(skill_id: int,target_id: int,include_position: bool)->Dictionary:
	if skill_id<0 or skill_id>65535 or not valid_id(target_id):return {"error":"Invalid native skill-description GUI request"}
	return {"bytes":gui_request(3,skill_id,target_id,include_position)}

static func feat_description_request(feat_id: int,target_id: int,include_position: bool)->Dictionary:
	if feat_id<0 or feat_id>65535 or not valid_id(target_id):return {"error":"Invalid native feat-description GUI request"}
	return {"bytes":gui_request(4,feat_id,target_id,include_position)}

static func effect_icon_request(effect_id: int,include_position: bool)->Dictionary:
	if effect_id<0 or effect_id>65535:return {"error":"Invalid native effect-icon GUI request"}
	return {"bytes":gui_request(5,effect_id,INVALID,include_position)}

static func chat_focus_request(mode: int,focused: bool,include_position: bool)->Dictionary:
	if mode<0 or mode>=5:return {"error":"Invalid native chat-focus GUI request"}
	return {"bytes":gui_request(1 if focused else 2,mode,INVALID,include_position)}

static func chat_reply_request(target_id: int,include_position: bool)->Dictionary:
	if not valid_id(target_id):return {"error":"Invalid native chat-reply GUI request"}
	return {"bytes":gui_request(27,0,target_id,include_position)}

static func player_attitude_request(target_id: int,likes: bool)->Dictionary:
	if not valid_id(target_id):return {"error":"Invalid native player attitude request"}
	var bytes:=PackedByteArray([112,41,3,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,target_id);bytes[11]=0x90 if likes else 0x80
	return {"bytes":bytes}

static func accepted(major: int,minor: int)->bool:
	return major==28 and minor in JOURNAL_MINORS or major==48 and minor==1 or major==41 and minor==3 or major==32 and minor in MAP_PIN_MINORS

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):return {"error":"Invalid native HUD envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":"Invalid native HUD stream: "+reader.error}
	var message: Dictionary={"major":major,"minor":minor}
	match major:
		28:message=journal(reader,minor)
		48:
			message={"kind":"gui-timing","active":reader.boolean()}
			if message.active:
				message.duration=reader.dword()
				message.type=reader.byte()
		41:message={"kind":"player-attitude","sourcePlayerId":reader.dword(),"playerId":reader.dword(),"likes":reader.boolean(),"own":reader.boolean()}
		32:message=map_pin(reader,minor)
	message.major=major;message.minor=minor
	if message.has("error") or not reader.finished():return {"error":"Invalid native HUD fields: "+str(message.get("error",reader.error if not reader.error.is_empty() else "stream incomplete"))}
	return message

static func journal(reader: Requirements.Reader,minor: int)->Dictionary:
	var message: Dictionary={"kind":"journal","operation":minor}
	match minor:
		1:message.worldEntry={"id":reader.signed_dword(),"title":{"text":reader.string()},"description":{"text":reader.string()},"date":reader.dword(),"time":reader.dword()}
		2:message.worldEntry={"id":reader.dword(),"strRef":reader.dword(),"date":reader.dword(),"time":reader.dword()}
		3:message.worldId=reader.signed_dword()
		4:message.worldStrRef=reader.dword()
		5:message.clear=reader.byte()
		6:message.entry={"title":Characters.localized(reader),"description":Characters.localized(reader),"date":reader.dword(),"time":reader.dword(),"tag":reader.string(),"state":reader.signed_dword(),"priority":reader.dword(),"picture":reader.word(),"completed":reader.boolean(),"isQuest":true}
		7:message.tag=reader.string()
		8:message.tag=reader.string();message.picture=reader.signed_dword()
		9:
			message.present=reader.boolean()
			if message.present:
				message.full=reader.boolean()
				var count:=reader.signed_dword()
				if count<0 or count>int((reader.byte_size-reader.byte_cursor)/6):return {"error":"Invalid native journal entry count"}
				var entries: Array[Dictionary]=[]
				for _index in range(count):
					var mask:=reader.word()
					var entry: Dictionary={"mask":mask,"tag":reader.string()}
					if mask & 0x4000:
						entries.append(entry)
						continue
					if message.full or mask & (0x8000 | 1):entry.title=Characters.localized(reader)
					if message.full or mask & (0x8000 | 2):entry.description=Characters.localized(reader)
					if message.full or mask & (0x8000 | 4):entry.date=reader.dword()
					if message.full or mask & (0x8000 | 8):entry.time=reader.dword()
					if message.full or mask & (0x8000 | 16):entry.state=reader.signed_dword()
					if message.full or mask & (0x8000 | 32):entry.priority=reader.dword()
					if message.full or mask & (0x8000 | 64):entry.picture=reader.word()
					if message.full or mask & (0x8000 | 128):entry.completed=reader.boolean()
					entry.isQuest=(mask & 0x100)==0
					entries.append(entry)
				message.entries=entries
		12:message.title=Characters.localized(reader);message.quest=reader.boolean();message.changed=reader.boolean()
	return message

static func map_pin(reader: Requirements.Reader,minor: int)->Dictionary:
	if minor==4:return {"kind":"map-pin-added","position":[reader.float32(),reader.float32(),reader.float32()],"text":reader.string(),"index":reader.dword()}
	var id:=reader.object_id()
	if minor==1:return {"kind":"map-pin-enabled","id":id,"enabled":reader.boolean()}
	return {"kind":"map-pin-created","id":id,"position":[reader.float32(),reader.float32(),reader.float32()],"name":Characters.localized(reader),"enabled":reader.boolean()}
