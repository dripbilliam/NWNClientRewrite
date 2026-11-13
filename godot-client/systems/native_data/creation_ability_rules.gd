extends RefCounted
# Original Abilities1408e05e0/0790 and twelve timer callbacks. Values/limits
# come from active tables; BYTE arithmetic and primary checks are source rules.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func cost(tables: Dictionary,raw: int) -> int:
	raw&=255
	if raw<Values.cfg(tables,"CHARGEN_ABILITY_COST_INCREMENT2",14):return 1
	if raw<Values.cfg(tables,"CHARGEN_ABILITY_COST_INCREMENT3",16):return 2
	return 3 if raw<Values.cfg(tables,"CHARGEN_ABILITY_COST_INCREMENT4",255) else 4
static func primary(data: Dictionary) -> int:return KEYS.map(func(key):return str(key).to_upper()).find(str(Game.cell(data,"SpellcastingAbil","")).to_upper())
static func can_down(tables: Dictionary,data: Dictionary,index: int,raw: int,effective: int) -> bool:
	return (effective&255)>Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN_PRIMARY",11) if primary(data)==index else (raw&255)>Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN",8)
static func move(tables: Dictionary,data: Dictionary,index: int,raw: int,effective: int,points: int,direction: int) -> Dictionary:
	var value:=raw&255;var remaining:=points&255;var changed:=false
	if direction==1:
		var price:=cost(tables,value)
		if value<Values.cfg(tables,"CHARGEN_BASE_ABILITY_MAX",18) and price<=remaining:remaining=(remaining-price)&255;value=(value+1)&255;changed=true
	elif direction==-1 and can_down(tables,data,index,value,effective):value=(value-1)&255;remaining=(remaining+cost(tables,value))&255;changed=true
	return {"value":value,"points":remaining,"changed":changed}
static func recommended(tables: Dictionary,data: Dictionary) -> Dictionary:
	var result: Dictionary={};var default_value: Variant=tables.get("classes",{}).get("defaultValue","****")
	for key in KEYS:result[key]=Game.number(Game.cell(data,key,default_value),0)&255
	return result
