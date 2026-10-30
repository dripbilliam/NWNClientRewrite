extends RefCounted
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
# Original6cb2e0 cases78..81,219..222,224; unchanged-code observations in
# native-scroll-feedback-observations-v1.json. Only formats received feedback.
const REFUSALS={78:53309,79:68611,80:68612,81:68613,219:68614,220:53310,221:53308,224:68661}
static func handles(code: int) -> bool: return code==222 or REFUSALS.has(code)
static func plan(code: int,spell_id: int,text) -> Dictionary:
	if REFUSALS.has(code): return {"ref":int(REFUSALS[code]),"parse":false,"tokens":{},"sound":"gui_failspell"}
	if code!=222: return {}
	var spells: Array=text.tables.get("spells",{}).get("orderedRows",[]); var name:=""
	if spell_id>=0 and spell_id<spells.size():
		name=text.raw({"strRef":Rules.number(Rules.cell(spells[spell_id],"Name"),-1)&0xffffffff})
	return {"ref":53307,"parse":true,"tokens":{0:name},"sound":"gui_learnspell"}
