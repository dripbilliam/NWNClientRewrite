extends RefCounted
# network_system_notices.js: presentation-only notices from the received
# message and the roster as it existed before applying that message.
static func from_message(message: Dictionary,previous_players: Dictionary,ready: bool=true) -> Array[Dictionary]:
	var notices: Array[Dictionary]=[]
	var kind: String=str(message.get("kind",""))
	if kind=="journal" and int(message.get("operation",-1))==12:
		notices.append({"category":"journal","title":message.get("title"),"quest":message.get("quest"),"changed":message.get("changed"),"strRef":6395,"color":"#ffff01","sound":"gui_quest_done" if bool(message.get("changed",false)) else "gui_journaladd"})
	elif kind=="player-list-add":
		for player in message.get("players",[]):
			if not player is Dictionary or bool(player.get("isDM",false)) and not bool(message.get("server140",false)):continue
			notices.append({"category":"player","playerId":player.get("playerId"),"playerName":player.get("name"),"strRef":6611 if bool(player.get("isDM",false)) else 6610,"color":"#bfbfbf","suffix":"."})
	elif kind=="player-list-delete":
		var player: Variant=previous_players.get(int(message.get("playerId",-1)))
		if ready and player is Dictionary and (not bool(player.get("isDM",false)) or bool(message.get("server140",false))):
			notices.append({"category":"player","playerId":player.get("playerId"),"playerName":player.get("name"),"strRef":6613 if bool(player.get("isDM",false)) else 6612,"color":"#bfbfbf","suffix":"."})
	return notices
