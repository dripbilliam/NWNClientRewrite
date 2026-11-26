extends RefCounted
const INVALID:=0x7f000000
const NO_PLAYER:=0xfffffffe
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
static func player(players: Array,id: int) -> Dictionary:
	for pair in players:
		if pair is Array and pair.size()==2 and int(pair[0])==id: return pair[1]
	return {}
static func current_player(players: Array,reply: Dictionary) -> Dictionary:
	var account: Variant=reply.get("player_account")
	var id:=int(reply.get("player_id",NO_PLAYER))
	if id==NO_PLAYER or not account is String or account.is_empty(): return {}
	var candidate:=player(players,id)
	return candidate if candidate.get("name")==account else {}
static func account_id(players: Array,account: String) -> int:
	# Original6d8a20 compares account+10 length and bytes, case-sensitively.
	for pair in players:
		if pair is Array and pair.size()==2 and str(pair[1].get("name",""))==account: return int(pair[0])
	return -1
static func character_name(player: Dictionary,text=null) -> String:
	var character: Dictionary=player.get("character",{})
	var first: String=text.raw(character.get("firstName",{})) if text!=null else str(character.get("firstName",{}).get("text",""))
	var last: String=text.raw(character.get("lastName",{})) if text!=null else str(character.get("lastName",{}).get("text",""))
	# Player-list7a8c60 appends one space only when the last name is nonempty.
	return first+(" "+last if not last.is_empty() else "")
static func character_id(players: Array,name: String,text=null) -> int:
	for pair in players:
		if pair is Array and pair.size()==2 and character_name(pair[1],text)==name: return int(pair[0])
	return -1
static func for_speaker(players: Array,id: int) -> int:
	# Client player-list7a8c60 stores the first wire OBJECT_ID at+34:
	# player.objectId (current controlled object). The character ID is+38.
	for pair in players:
		if pair is Array and pair.size()==2 and int(pair[1].get("objectId",INVALID))==id: return int(pair[0])
	return NO_PLAYER
static func presentation(id: int,objects: Dictionary,players: Array,text) -> Dictionary:
	var rules:=Rules.new(); rules.text=text; var owner:=for_speaker(players,id)
	var matching:=players.filter(func(pair):return pair is Array and pair.size()==2 and int(pair[0])==owner)
	var source:=rules.presentation_object(objects,id,matching)
	var portrait:=rules.portrait(source,1)
	if not objects.has(id) and owner==NO_PLAYER: portrait="po_hu_m_99_t"
	var reply:={"player_id":owner,"portrait":portrait}
	if owner!=NO_PLAYER and not matching.is_empty():
		var account: Variant=matching[0][1].get("name")
		if account is String and not account.is_empty(): reply.player_account=account
	return reply
