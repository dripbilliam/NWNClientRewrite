extends RefCounted
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var entries: Array=[]
var selected:=-1
var help_title:=481
var help_description:=485
static func choices(rows: Array,text) -> Array:
	var result: Array=[]
	# LoadRaceInfo2aa460 stores the physical row count in a BYTE; the
	# original chooser iterates that count and keeps ascending physical IDs.
	for id in range(rows.size()&255):
		var row: Dictionary=rows[id]
		if Game.number(Game.cell(row,"PlayerRace"),0)==0:continue
		var name:=Game.number(Game.cell(row,"Name"),4294967295);var title:=Game.number(Game.cell(row,"NamePlural"),4294967295);var description:=Game.number(Game.cell(row,"Description"),4294967295)
		result.append({"id":id,"name":text.raw({"strRef":name}),"title":title,"description":description,"icon":str(Game.cell(row,"Icon",""))})
	return result
func reset(values: Array,current: int,present: bool=true) -> void:
	entries=values.duplicate(true);selected=-1;help_title=481;help_description=485
	select_race(current&65535 if present else 6)
func select_race(id: int) -> void:
	selected=-1
	for index in entries.size():
		if int(entries[index].id)==id:selected=index;break
	describe(id)
func select_index(index: int) -> void:
	selected=index if index>=0 and index<entries.size() else -1;describe(selected)
func describe(value: int) -> void:
	if value==-1:help_title=-1;help_description=-1;return
	help_description=-1
	if selected>=0 and selected<entries.size():help_title=int(entries[selected].title);help_description=int(entries[selected].description)
func selected_race() -> int:return int(entries[selected].id) if selected>=0 and selected<entries.size() else -1
func recommend() -> void:select_race(6)
func general_help() -> void:help_title=481;help_description=485
