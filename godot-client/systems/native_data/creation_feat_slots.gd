extends RefCounted
# Original CNWCLevelUpStats7ec290 and CNWClass::GetBonusFeats2997d0.
# This shared counter operates on the active connection's resolved physical rows.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func rows(tables: Dictionary,name: String) -> Array:return tables.get(name.to_lower(),{}).get("orderedRows",[])
static func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var values:=rows(tables,name);return values[index] if index>=0 and index<values.size() else {}
static func signed32(value: int) -> int:return (value&0xffffffff)-4294967296 if value&0x80000000 else value&0xffffffff
static func count(period: int,number: int,extra: int,total_level: int,class_level: int,class_bonus: Array) -> Dictionary:
	var level:=total_level&255;var every:=signed32(period);var normal:=0;var bonus:=0;var current:=class_level&255
	if level==1 or every!=0 and level%every==0:normal=number&255
	if level==1:normal=(normal+extra)&255
	if ((current-1)&255)<60 and current-1<class_bonus.size():bonus=int(class_bonus[current-1])&255
	return {"normal":normal,"bonus":bonus}
static func has_column(table: Dictionary,name: String) -> bool:
	if table.has("columns"):return table.columns.any(func(column):return str(column).to_lower()==name.to_lower())
	# Authored fixtures may omit the header; a present cell still identifies it.
	for entry in table.get("orderedRows",[]):
		if Game.cell(entry,name)!=null:return true
	return false
static func race_number(tables: Dictionary,race_id: int,name: String,legacy: int) -> int:
	var table: Dictionary=tables.get("racialtypes",{})
	return Game.number(Game.cell(row(tables,"racialtypes",race_id),name,table.get("defaultValue","****")),0) if has_column(table,name) else legacy
static func calculate(tables: Dictionary,race_id: int,class_id: int,total_level: int,class_level: int) -> Dictionary:
	var race:=race_id&65535
	var period:=race_number(tables,race,"NormalFeatEveryNthLevel",3)
	var number:=race_number(tables,race,"NumberNormalFeatsEveryNthLevel",1)
	# LoadRaceInfo2aa460's legacy-format fallback; a present server column owns it.
	var extra:=race_number(tables,race,"ExtraFeatsAtFirstLevel",1 if race==6 else 0)
	var name:=str(Game.cell(row(tables,"classes",class_id&255),"BonusFeatsTable","")).to_lower();var bonuses: Array=[]
	var table: Dictionary=tables.get(name,{})
	for index in 60:bonuses.append(Game.number(Game.cell(row(tables,name,index),"Bonus",table.get("defaultValue","****")),0))
	return count(period,number,extra,total_level,class_level,bonuses)
