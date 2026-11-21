extends RefCounted
# Original87b590 dispatch; see executed native-chat-dispatch observations.
const Reply=preload("res://systems/native_data/chat_reply.gd")
const MODES=[{"ref":66751,"channel":2},{"ref":66752,"channel":3},{"ref":66754,"channel":1},{"ref":66755,"channel":6},{"ref":66756,"channel":14}]
static func dispatch(value: String,mode: int,players: Array=[],text=null) -> Dictionary:
	if mode<0 or mode>=MODES.size(): return {"error":"Invalid original chat mode"}
	var line:=value
	for separator in ["\n","\r"]:
		var at:=line.find(separator)
		if at>=0: line=line.left(at)
	if line.is_empty(): return {}
	if line.begins_with("##"): return {"error":"Local console commands are unavailable."}
	var result:={"kind":"chat","channel":int(MODES[mode].channel),"text":line}
	if not line.begins_with("/"): return result
	var space:=line.find(" "); var command:=line.substr(1,space-1 if space>=0 else -1).to_lower()
	# Native SubString(space+1) starts at0 when no space exists. Retain that
	# behavior, including empty payloads with an explicit trailing space.
	var rest:=line.substr(space+1)
	if command in ["s","w","p","dm","tk","talk"]:
		result.channel=int({"s":2,"w":3,"p":6,"dm":14,"tk":1,"talk":1}[command]); result.text=rest; return result
	if command=="d": return {"error":"Local console commands are unavailable."}
	if command=="accept": return {"kind":"native-chat-party","operation":"accept","targetId":Reply.INVALID}
	if command=="invite":
		var id:=Reply.character_id(players,rest,text)
		if id<0 or id==0xffffffff: return {"error_ref":61899} if space>=0 else {}
		var player:=Reply.player(players,id)
		return {"kind":"native-chat-party","operation":"invite","playerId":id,"playerAccount":str(player.get("name","")),"targetId":int(player.get("character",{}).get("id",Reply.INVALID))}
	if command not in ["t","tell","tp","tellplayer","o"]: return result
	var name:=""; var message:=""; var end:=rest.find('"',1) if rest.begins_with('"') else rest.find(" ")
	if end<0:
		if command=="o": result.channel=4; result.recipient=""; result.text=rest; return result
		return {}
	if rest.begins_with('"'):
		name=rest.substr(1,end-1); message=rest.substr(end+1)
		if message.begins_with(" "): message=message.substr(1)
	else: name=rest.left(end); message=rest.substr(end+1)
	result.channel=4; result.text=message
	if command=="o": result.recipient=name; return result
	var id:=Reply.account_id(players,name) if command in ["tp","tellplayer"] else Reply.character_id(players,name,text)
	if id<0 or id==0xffffffff: return {"error_ref":61899}
	if message.is_empty(): return {}
	result.playerId=id; result.playerAccount=str(Reply.player(players,id).get("name","")); return result
