extends RefCounted
# Original CNWClass::GetIsAlignmentAllowed299900. Restriction flags are active
# classes.2da data; the enum/category definitions are original engine semantics.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func allowed(data: Dictionary,good: int,law: int) -> bool:
	var axes:=Game.number(Game.cell(data,"AlignRstrctType"),0)&255;var mask:=Game.number(Game.cell(data,"AlignRestrict"),0)&255
	var matches: bool=(axes&2)!=0 and (mask&({1:1,4:8,5:16}.get(good&255,0)))!=0 or (axes&1)!=0 and (mask&({1:1,2:2,3:4}.get(law&255,0)))!=0
	return matches if Game.number(Game.cell(data,"InvertRestrict"),0)!=0 else not matches
static func category(value: int) -> int:
	value&=65535
	if value>=32768:value-=65536
	return 0 if value>=70 else 2 if value<=30 else 1
static func allowed_scores(data: Dictionary,good: int,law: int) -> bool:return allowed(data,[4,1,5][category(good)],[2,1,3][category(law)])
