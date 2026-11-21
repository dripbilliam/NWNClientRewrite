extends RefCounted
# world_highlight_assets.js projects received creature condition and portrait.
const Highlight=preload("res://systems/native_data/world_highlight.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")

static func _condition_ref(table: Dictionary,level: int) -> int:
	var rows: Array=table.get("orderedRows",[])
	if level<0 or level>=rows.size() or not rows[level] is Dictionary:return -1
	var row: Dictionary=rows[level]
	var value: Variant=null
	for key in row:
		if str(key).to_lower()=="string_ref":value=row[key];break
	if value==null or str(value) in ["","****"]:return -1
	var source:=str(value)
	var matched:=RegEx.new()
	matched.compile("^0[xX][0-9a-fA-F]+")
	var result:=matched.search(source)
	if result!=null:return int(result.get_string().hex_to_int())&0xffffffff
	matched.compile("^\\s*[+-]?[0-9]+")
	result=matched.search(source)
	return (int(result.get_string())&0xffffffff) if result!=null else -1

static func creature_details(object: Dictionary,ui) -> Dictionary:
	if not is_instance_valid(ui) or not is_instance_valid(ui.assets):return {}
	var level:=Highlight.damage_level(object)
	var condition:=""
	if level>=0:
		var reference:=_condition_ref(ui.text.tables.get("damagelevels",{}),level)
		if reference>=0 and reference!=0xffffffff:condition=ui.text.resolve({"strRef":reference},int(object.get("id",-1)))
	var portrait_object:=object.duplicate()
	var state: Dictionary=object.get("replicated").duplicate() if object.get("replicated") is Dictionary else {}
	for player_row in ui.desktop.state.get("players",[]):
		var player: Dictionary=player_row[1] if player_row is Array else player_row
		var character: Dictionary=player.get("character",{})
		if int(player.get("objectId",-1))!=int(object.get("id",-1)) and int(character.get("id",-1))!=int(object.get("id",-1)):continue
		for field in ["portrait","portraitRef"]:
			if state.get(field)==null and character.has(field):state[field]=character[field]
		break
	portrait_object.replicated=state
	var rules:=Rules.new()
	rules.text=ui.text
	return {"condition":condition,"portrait":rules.portrait(portrait_object,1),"level":level}
