extends RefCounted
const INVALID:=0x7f000000
const NO_PLAYER:=0xfffffffe
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
static func player(players: Array,id: int) -> Dictionary:
	for pair in players:
		if pair is Array and pair.size()==2 and int(pair[0])==id: return pair[1]
	return {}
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
	var source:=rules.presentation_object(objects,id,players.filter(func(pair):return pair is Array and pair.size()==2 and int(pair[0])==owner))
	var portrait:=rules.portrait(source,1)
	if not objects.has(id) and owner==NO_PLAYER: portrait="po_hu_m_99_t"
	return {"player_id":owner,"portrait":portrait}
