extends RefCounted
# Non-memorizing branch of original7ee690,299e70,299e40. Inputs are a decoded
# complete class/race/ability snapshot, not guessed spontaneous-use counters.
# Per-class abilityGain is the current class's signed cumulative stat gain.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func number(row: Dictionary,key: String,fallback: int=0) -> int:return Game.number(Game.cell(row,key),fallback)
static func signed8(value: int) -> int:return (value&255)-256 if value&128 else value&255
static func pending(reason: String) -> Dictionary:return {"ready":false,"allowed":false,"reason":reason}
static func nonmemorizing(source: Dictionary,required_level: int) -> Dictionary:
	var required:=required_level&255
	if required==0:return {"ready":true,"allowed":true}
	if not source.has("classes") or not source.classes is Array:return pending("Native class snapshot is unavailable.")
	var base: Array=source.get("baseAbilities",[]);var race: Array=source.get("raceAdjust",[])
	if base.size()!=6 or race.size()!=6:return pending("Native base/racial spell abilities are unavailable.")
	for cls in source.get("classes",[]).slice(0,8):
		var spell: Dictionary=cls.get("spell",{})
		if not spell.has("SpellCaster"):return pending("Native class spell metadata is unavailable.")
		if number(spell,"SpellCaster")==0:continue
		if number(spell,"MemorizesSpells")!=0:return pending("Memorizing spell capacity needs its separate original owner.")
		if not spell.has_all(["SpellbookRestricted","LearnScroll","ability","abilityGain","knownPresent","NumSpellLevels","known","gain"]):return pending("Native class spell storage is incomplete.")
		var level:=number(cls,"level")&255;var ability:=number(spell,"ability",255)&255
		if level<1 or level>40 or ability>=6:return pending("Native non-memorizing spell storage is outside the verified level/ability scope.")
		var gains: Array=spell.abilityGain;var known: Array=spell.known;var gain: Array=spell.gain;var count:=number(spell,"NumSpellLevels")&255
		if gains.size()!=6 or gain.size()<count or bool(spell.knownPresent) and known.size()<count:return pending("Native class spell rows/gains are unavailable.")
		var effective: int=((int(base[ability])&255)+signed8(int(race[ability]))+signed8(int(gains[ability])))&255
		var known_count:=0
		if bool(spell.knownPresent) and required<count:
			var ability_met:=true
			if number(spell,"SpellbookRestricted")!=0 and number(spell,"LearnScroll")==0 and required!=0 and (int(known[required-1])&255)==0:ability_met=effective>=required+10
			if ability_met:known_count=int(known[required])&255
		if known_count!=0:return {"ready":true,"allowed":true}
		if number(spell,"SpellbookRestricted")==0:
			# Original GetSpellGain returns255 for an unavailable level. This
			# caller tests !=0, so preserve that original sentinel behavior.
			var gained: int=int(gain[required])&255 if required<count else 255
			if gained!=0 and effective>=required+10:return {"ready":true,"allowed":true}
	return {"ready":true,"allowed":false}
