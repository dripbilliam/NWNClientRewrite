extends RefCounted
# Private CNWCCreatureStats/CNWCLevelUpStats constructor state, NOT an estimate
# of undisclosed server health. The normal HP packet replaces these shorts.
const Query=preload("res://systems/native_data/visual_definition.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
static func signed8(value: int) -> int:
	value&=255
	return value-256 if value>=128 else value
static func signed32(value: int) -> int:
	value&=0xffffffff
	return value-0x100000000 if value>=0x80000000 else value
static func cfg(tables: Dictionary,name: String,fallback: int) -> int:
	return preload("res://systems/native_data/character_record_values.gd").cfg(tables,name,fallback)
static func gain_table(tables: Dictionary) -> String:
	# Original constructor starts with one level of class4 and race6, before
	# incoming creature fields. These are storage defaults, not gameplay choices.
	return str(Query.query(tables.get("classes",{}),4,"StatGainTable","string").value).to_lower()
static func constructor(tables: Dictionary) -> Dictionary:
	var base:=cfg(tables,"CHARGEN_BASE_ABILITY_MIN",8)&255
	var race:=int(Query.query(tables.get("racialtypes",{}),6,"ConAdjust","integer").value)&255
	var gain:=signed8(int(Query.query(tables.get(gain_table(tables),{}),0,"Con","integer").value))
	var constitution:=(base+race+gain)&255
	var neutral:=cfg(tables,"CHARGEN_ABILITY_NEUTRAL_VALUE",10)
	var increment:=cfg(tables,"CHARGEN_ABILITY_MODIFIER_INCREMENT",2)
	if increment==0: return {} # Original division is undefined; keep diagnostic.
	var delta:=signed32(constitution-neutral-int(constitution<neutral and neutral%2==0))
	var maximum:=maxi(1,signed8(int(float(delta)/float(increment))))
	return {"base":0,"temporary":0,"current":maximum,"maximum":maximum}
static func stored(object: Dictionary,field: String,defaults: Dictionary) -> int:
	var hp: Dictionary=object.get("replicated",{}).get("hitPoints",{})
	return int(hp[field]) if hp.has(field) else int(defaults[field])
