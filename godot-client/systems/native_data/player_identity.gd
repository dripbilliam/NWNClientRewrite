extends RefCounted
# Typed current-header projections only; no world/player store or live Nodes.
const INVALID:=0x7f000000
const RECEIVED_PERMISSION:="received_game_master_permission_31_22"
const INITIAL_PERMISSION:="native_connection_start_16"
static func integer(value:Variant,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=maximum
static func boolean(value:Variant)->bool:return value is bool or integer(value,1)
static func localized(value:Variant)->bool:
	return value is Dictionary and (value.get("text") is String or integer(value.get("strRef"),4294967295) and boolean(value.get("gender")))
static func complete_entry(value:Variant)->bool:
	if not value is Dictionary or not integer(value.get("playerId"),4294967295) or not integer(value.get("objectId"),4294967295) or not boolean(value.get("isDM")) or not value.get("name") is String or not integer(value.get("peerD8"),255) or not value.get("peerC8") is String:return false
	if not value.has("character"):return true
	var c:Variant=value.character
	return c is Dictionary and integer(c.get("id"),4294967295) and localized(c.get("firstName")) and localized(c.get("lastName")) and integer(c.get("portrait"),65535) and (int(c.portrait)<65534 or c.get("portraitRef") is String)
static func selected_lookup(roster:Variant,complete:Variant,target:Variant)->Dictionary:
	var unknown:={"available":false,"isPlayer":null,"playerId":null,"selectedId":null,"controlledId":null,"source":"selected_player_character","reason":"roster_unavailable"}
	if not integer(target,4294967295) or int(target)==INVALID:unknown.reason="invalid_target";return unknown
	if not roster is Array:return unknown
	var schema_known:=true
	for entry in roster:
		var p:Variant=entry[1] if entry is Array and entry.size()==2 else entry
		if not p is Dictionary:schema_known=false;continue
		var c:Variant=p.get("character")
		if c is Dictionary and integer(c.get("id"),4294967295) and int(c.id)==int(target):
			return {"available":true,"isPlayer":true,"playerId":int(p.playerId) if integer(p.get("playerId"),4294967295) else null,"selectedId":int(c.id),"controlledId":int(p.objectId) if integer(p.get("objectId"),4294967295) else null,"source":"selected_player_character","reason":"received_selected_identity"}
		if not complete_entry(p):schema_known=false
	if not complete is bool or not complete or not schema_known:unknown.reason="complete_roster_unavailable";return unknown
	return {"available":true,"isPlayer":false,"playerId":null,"selectedId":null,"controlledId":null,"source":"complete_player_roster","reason":"not_in_received_complete_roster"}
static func permission(view:Variant)->Dictionary:
	var unknown:={"available":false,"permission":null,"source":null,"reason":"permission_unavailable"}
	if not view is Dictionary or not view.has("field114") or not view.has("parameter"):return unknown
	var source:Variant=view.get("source")
	if source==INITIAL_PERMISSION:
		if not integer(view.get("permission"),0) or view.field114!=null or view.parameter!=null:return unknown
	elif source==RECEIVED_PERMISSION:
		var parameter:Variant=view.parameter
		if not boolean(view.get("permission")) or not boolean(view.field114) or not (parameter is int or parameter is float) or not is_finite(float(parameter)) or floor(float(parameter))!=float(parameter) or parameter< -2147483648 or parameter>2147483647:return unknown
	else:return unknown
	return {"available":true,"permission":bool(view.permission),"source":source,"reason":"known_connection_permission"}
static func normal_context(header:Dictionary,target:Variant)->Dictionary:
	var role:=permission(header.get("gameMasterPermission"))
	var lookup:=selected_lookup(header.get("players"),header.get("playerRosterKnown"),target)
	var missing:Array=[]
	if not role.available:missing.append("connection.permission")
	elif role.permission:missing.append("dm-context-unbound")
	if not lookup.available:missing.append("selected-character-player-lookup")
	return {"available":missing.is_empty(),"dmPermission":role.permission if role.available else null,"playerLookup":lookup,"missing":missing,"source":"current_player_context_header"}
