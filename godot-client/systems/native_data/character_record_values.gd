extends RefCounted
const RulesetCache=preload("res://systems/native_data/ruleset_cache.gd")
# CCharPageChar1409b6380 and GetAbilityModifier1407ec3a0. Display only;
# authoritative ability values/adjustments are never changed by this projection.
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
const LABEL_REFS=[0x87,0x85,0x84,0x86,0x88,0x83]
const IMPROVED:=Color8(32,255,32)
const REDUCED:=Color8(255,1,1)
static func integer_text(value: Variant) -> String:
	# JSON carries protocol integer fields as floats. Original numeric GUI
	# fields use integer formatting; absent/malformed values stay unknown.
	if value is int: return str(value)
	if value is float and is_finite(value): return str(int(value))
	return ""
static func signed8(value: int) -> int:
	value&=255
	return value-256 if value>=128 else value
static func signed32(value: int) -> int:
	value&=0xffffffff
	return value-0x100000000 if value>=0x80000000 else value
static func field(row: Dictionary,name: String) -> Variant:
	for key in row:
		if str(key).to_lower()==name.to_lower(): return row[key]
	return null
static func cfg(tables: Dictionary,label: String,fallback: int) -> int:
	# Ruleset cache uses case-sensitive labels, skips empty values and lets the
	# last nonempty duplicate win. Its values use C atoi, not GetINTEntry hex.
	var owned:=RulesetCache.current(tables)
	if owned!=null: return owned.integer(label,fallback)
	# Explicit detached worker projections can supply the same native index.
	if tables.get("_native_resolved_ruleset") is Dictionary: return int(tables._native_resolved_ruleset.get(label,fallback))
	return RulesetCache.from_source(tables,label,fallback)
static func resolved_ruleset(tables: Dictionary) -> Dictionary:
	return RulesetCache.compile(tables.get("ruleset",{}))
static func modifier(score: int,tables: Dictionary) -> Variant:
	var neutral:=cfg(tables,"CHARGEN_ABILITY_NEUTRAL_VALUE",10); var increment:=cfg(tables,"CHARGEN_ABILITY_MODIFIER_INCREMENT",2)
	score&=255
	var difference:=signed32(score-neutral-int(score<neutral and neutral%2==0))
	# Original idiv faults for these malformed rules; leave display unknown.
	if increment==0 or difference==-2147483648 and increment==-1: return null
	return signed8(int(float(difference)/float(increment)))
static func abilities(values: Array,bonuses: Array,dexterity: int,tables: Dictionary) -> Array:
	var result: Array=[]
	for index in 6:
		var score: Variant=(int(values[index])&255) if index<values.size() and values[index]!=null else null
		var adjustment:=signed8(int(bonuses[index])) if index<bonuses.size() and bonuses[index]!=null else 0
		var effective: Variant=modifier(int(score),tables) if score!=null else null
		var baseline: Variant=modifier((int(score)-adjustment)&255,tables) if score!=null else null
		if index==1 and effective!=null: effective=signed8(int(effective)+signed8(dexterity))
		result.append({"key":KEYS[index],"labelRef":LABEL_REFS[index],"score":score,"adjustment":adjustment,"modifier":effective,"modifierAdjustment":int(effective)-int(baseline) if effective!=null and baseline!=null else 0})
	return result
static func tone(adjustment: int) -> Color:
	return IMPROVED if adjustment>0 else REDUCED if adjustment<0 else Color.WHITE
