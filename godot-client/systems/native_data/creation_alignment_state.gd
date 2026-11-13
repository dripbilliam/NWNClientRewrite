extends RefCounted
const Rules=preload("res://systems/native_data/alignment_rules.gd")
const TAGS=["lgbutton","lnbutton","lebutton","ngbutton","tnbutton","nebutton","cgbutton","cnbutton","cebutton"]
const HELP=[[468,452],[469,453],[467,451],[471,455],[472,456],[470,454],[465,449],[466,450],[464,448]]
var enabled: Array=[false,false,false,false,false,false,false,false,false]
var selected:=-1
var class_id:=-1
var help_title:=260
var help_description:=458
func reset(data: Dictionary,id: int,good: int,law: int) -> void:
	class_id=id&255;enabled=[]
	for index in 9:enabled.append(Rules.allowed(data,[4,1,5][index%3],[2,1,3][index/3]))
	select_index(Rules.category(law)*3+Rules.category(good))
func select_index(index: int) -> void:
	selected=index if index>=0 and index<9 else -1
	if selected<0:general_help()
	else:help_title=HELP[selected][0];help_description=HELP[selected][1]
func general_help() -> void:help_title=260;help_description=458
func recommend() -> void:select_index([7,6,1,4,6,1,0,6,4,7,1][class_id] if class_id<11 else 0)
func result(good: int,law: int,present: bool=true,cancel: bool=false) -> Dictionary:
	# Original OK still accepts its programmatic selection even when a custom
	# class disables that alignment. Final draft validation/server admission are
	# separate; do not silently substitute the first available button here.
	if not cancel and present and selected>=0 and selected<9:good=[85,50,15][selected%3];law=[85,50,15][selected/3]
	return {"goodEvil":good,"lawChaos":law,"code":2 if cancel else 0x8001}
