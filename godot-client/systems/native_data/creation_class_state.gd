extends RefCounted
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var entries: Array=[]
var recommended: Dictionary={}
var selected:=-1
var help_title:=480
var help_description:=484
static func fold(value: String) -> String:
	var result:=""
	for at in value.length():
		var code:=value.unicode_at(at);result+=String.chr(code+32 if code>=65 and code<=90 else code)
	return result
static func detail(row: Dictionary,id: int,text) -> Dictionary:
	var name:=Game.number(Game.cell(row,"Name"),4294967295)
	return {"id":id,"name":text.raw({"strRef":name}),"title":name,"description":Game.number(Game.cell(row,"Description"),4294967295),"icon":str(Game.cell(row,"Icon",""))}
static func choices(rules,text,sorted: bool=true) -> Dictionary:
	# The live chooser uses the native available/unavailable name groups by
	# default. Keep physical IDs in every entry; a display index is not a class.
	var entries: Array=[];var ready:=0;var recommendation: Dictionary={}
	for id in range(rules.rows("classes").size()&255):
		var data: Dictionary=rules.row("classes",id);var entry:=detail(data,id,text)
		if id==4:recommendation=entry.duplicate()
		if rules.num(data,"PlayerClass")==0:continue
		entry.enabled=rules.class_requirement(id).is_empty()
		if sorted:
			var first:=0 if entry.enabled else ready;var end:=ready if entry.enabled else entries.size()
			while first<end:
				var middle: int=(first+end)/2
				if fold(str(entry.name))<=fold(str(entries[middle].name)):end=middle
				else:first=middle+1
			entries.insert(first,entry)
			if entry.enabled:ready=(ready+1)&255
		else:entries.append(entry)
	return {"entries":entries,"recommended":recommendation}
func reset(values: Dictionary) -> void:
	entries=values.get("entries",[]).duplicate(true);recommended=values.get("recommended",{}).duplicate();selected=-1;general_help();select_index(0)
func general_help() -> void:help_title=480;help_description=484
func select_index(index: int) -> void:
	selected=index if index>=0 and index<entries.size() else -1
	var entry: Dictionary=entries[selected] if selected>=0 else {}
	help_title=int(entry.get("title",-1));help_description=int(entry.get("description",-1))
func selected_class() -> int:return int(entries[selected].id) if selected>=0 and selected<entries.size() else -1
func can_accept() -> bool:return selected_class()>=0 and entries[selected].get("enabled",false)
func recommend() -> void:
	var index:=-1
	for at in entries.size():
		if int(entries[at].id)==4:index=at;break
	select_index(index)
	# The source queries physical class4 help even if that row is not listed.
	if not recommended.is_empty():help_title=int(recommended.title);help_description=int(recommended.description)
