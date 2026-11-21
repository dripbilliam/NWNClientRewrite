extends RefCounted
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var entries: Array=[]
var selected:=-1
var default_package:=-1
var help_title:=483
var help_description:=487
static func present(value: Variant) -> bool:return value!=null and str(value) not in ["","****"]
static func choices(rules,text) -> Dictionary:
	var values: Array=[]
	for id in rules.rows("packages").size():
		var row: Dictionary=rules.row("packages",id)
		if id==255 or not present(Game.cell(row,"ClassID")) or not present(Game.cell(row,"PlayerClass")) or rules.num(row,"ClassID")!=int(rules.draft.classId) or rules.num(row,"PlayerClass")==0:continue
		var title: int=rules.num(row,"Name",0);var description: int=rules.num(row,"Description",0)
		values.append({"id":id,"name":text.raw({"strRef":title&0xffffffff}),"title":title&0xffffffff,"description":description&0xffffffff,"icon":"","titleFound":text.fetch_reference(title&0xffffffff).found,"descriptionFound":text.fetch_reference(description&0xffffffff).found})
	return {"entries":values,"default":rules.num(rules.cls(),"Package",-1),"classId":int(rules.draft.classId)}
func reset(value: Dictionary) -> void:
	entries=value.get("entries",[]).duplicate(true);default_package=int(value.get("default",-1));selected=0 if not entries.is_empty() else -1;general_help()
func general_help() -> void:help_title=483;help_description=487
func select_index(index: int) -> void:
	if index<0 or index>=entries.size():return
	selected=index;var entry: Dictionary=entries[index]
	if entry.get("titleFound",true):help_title=int(entry.title)
	if entry.get("descriptionFound",true):help_description=int(entry.description)
func recommend() -> void:
	if not entries.is_empty():select_index(0)
func selected_package() -> int:return int(entries[selected].id) if selected>=0 and selected<entries.size() else -1
func configure_package() -> int:return selected_package() if selected>=0 else default_package
func can_accept() -> bool:return selected>=0 and selected<entries.size()
