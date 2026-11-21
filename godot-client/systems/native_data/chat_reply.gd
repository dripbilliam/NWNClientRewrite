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
	for pair in players:
		if not pair is Array or pair.size()!=2:continue
		var entry: Dictionary=pair[1]
		if int(entry.get("objectId",INVALID))==id or int(entry.get("character",{}).get("id",INVALID))==id:return int(pair[0])
	return NO_PLAYER
static func presentation(id: int,objects: Dictionary,players: Array,text) -> Dictionary:
	var rules:=Rules.new(); rules.text=text; var owner:=for_speaker(players,id)
	var object: Dictionary=objects.get(id,{})
	var state: Variant=object.get("replicated")
	if state==null and owner!=NO_PLAYER:state=player(players,owner).get("character")
	if not state is Dictionary:return {}
	var portrait:=rules.portrait({"replicated":state},1)
	if portrait.is_empty():return {}
	return {"player_id":owner,"portrait":portrait}
