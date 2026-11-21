extends RefCounted
# Original PlayerList_All/Add/Delete (10/1..3) and controlled-object (5/2).
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

static func uint(value: Variant)->bool:
	return (value is int or value is float and is_finite(value) and floor(value)==value) and value>=0 and value<=0xffffffff
static func wire_bool(value: Variant)->bool:
	return value is bool or (value is int or value is float) and (value==0 or value==1)
static func localized(value: Variant)->bool:
	return value is Dictionary and (value.get("text") is String or uint(value.get("strRef")) and wire_bool(value.get("gender")))
static func entry_complete(value: Variant)->bool:
	if not value is Dictionary or not uint(value.get("playerId")) or not uint(value.get("objectId")) or not wire_bool(value.get("isDM")) or not value.get("name") is String or not uint(value.get("peerD8")) or int(value.peerD8)>255 or not value.get("peerC8") is String:return false
	if not value.has("character"):return true
	var character: Variant=value.character
	return character is Dictionary and uint(character.get("id")) and localized(character.get("firstName")) and localized(character.get("lastName")) and uint(character.get("portrait")) and int(character.portrait)<=65535 and (int(character.portrait)<65534 or character.get("portraitRef") is String)
static func stage(message: Dictionary)->Dictionary:
	if str(message.get("kind","")) not in ["player-list-all","player-list-add"] or not message.get("players") is Array:return {"error":"Invalid native player roster"}
	var rows: Array=[];var seen: Dictionary={};var unique:=true
	for value in message.players:
		if not value is Dictionary or not uint(value.get("playerId")) or not uint(value.get("objectId")):return {"error":"Invalid native player identity"}
		var row: Dictionary=value.duplicate(true)
		rows.append(row)
		if seen.has(row.playerId):unique=false
		seen[row.playerId]=true
	var complete:=str(message.kind)=="player-list-all" and rows.size()<=255 and wire_bool(message.get("server140")) and unique
	if complete:
		for row in rows:
			if not entry_complete(row):complete=false;break
	return {"rows":rows,"complete":complete}

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80:return {"error":"Not a native roster message"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	if not (major==10 and minor in [1,2,3] or major==5 and minor==2):return {"error":"Not a native roster message"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var result: Dictionary={"major":major,"minor":minor}
	if major==5:
		result.kind="object-control"
		result.playerId=reader.dword()
		result.objectId=reader.dword()
	else:
		result.server140=reader.boolean()
		if minor==3:
			result.kind="player-list-delete"
			result.playerId=reader.dword()
		else:
			result.kind="player-list-all" if minor==1 else "player-list-add"
			var count:=reader.byte() if minor==1 else 1
			if count>int((reader.byte_size-reader.byte_cursor)/17):return {"error":"Invalid native player-list count"}
			var players: Array[Dictionary]=[]
			for _index in range(count):
				var row: Dictionary={"playerId":reader.dword(),"objectId":reader.dword(),"isDM":reader.boolean(),"name":reader.string()}
				var has_character:=reader.boolean()
				row.peerD8=reader.byte();row.peerC8=reader.string()
				if has_character:
					var character: Dictionary={"id":reader.dword(),"firstName":Characters.localized(reader),"lastName":Characters.localized(reader),"portrait":reader.word()}
					if int(character.portrait)>0xfffd:character.portraitRef=reader.resref()
					row.character=character
				players.append(row)
			result.players=players
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Native roster message stream is incomplete"}
	return result
