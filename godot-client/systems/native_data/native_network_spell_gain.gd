extends RefCounted
# Direct source-order port of src/network_spell_gain.js. Spell gain controls
# client wheel display/admission; server packets own actual slot consumption.
const Values=preload("res://systems/native_data/character_record_values.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const NativeObjectRules=preload("res://systems/native_data/native_object_rules.gd")
const NAMES=["Str","Dex","Con","Int","Wis","Cha"]
static func _byte(value: Variant) -> int:return int(value)&255
static func _i8(value: Variant) -> int:return Values.signed8(int(value))
static func _field(row: Dictionary,column: String) -> Variant:
	for key in row:
		if str(key).to_lower()==column.to_lower():return row[key]
	return null
static func _string_entry(table: Dictionary,id: int,column: String) -> Dictionary:
	return SpellMetadata.native_string_entry(table,id,column)
static func _int_entry(table: Dictionary,id: int,column: String) -> Dictionary:
	var rows: Array=table.get("orderedRows",[])
	var row: Dictionary=rows[id] if id>=0 and id<rows.size() and rows[id] is Dictionary else {}
	var value: Variant=_field(row,column)
	if row.is_empty() or value==null:return {"found":false,"value":NativeObjectRules.atoi(table.get("defaultValue",""))}
	var source:=str(value)
	if source.is_empty() or source=="****":return {"found":false,"value":0}
	var hexadecimal:=RegEx.create_from_string("(?i)^0x[0-9a-f]+").search(source)
	var parsed:=hexadecimal.get_string().hex_to_int() if hexadecimal!=null else NativeObjectRules.atoi(source)
	return {"found":true,"value":Values.signed32(parsed)}
static func _table(rules,name: String) -> Dictionary:
	return rules.text.tables.get(name.to_lower(),{})
static func _class_info(rules,id: int) -> Variant:
	var table: Dictionary=_table(rules,"classes");var rows: Array=table.get("orderedRows",[])
	if id<0 or id>=rows.size() or not rows[id] is Dictionary:return null
	var ability_name:=str(_string_entry(table,id,"SpellcastingAbil").value).to_lower();var ability:=-1
	for index in NAMES.size():
		if NAMES[index].to_lower()==ability_name:ability=index;break
	return {"ability":ability,"spellCaster":int(_int_entry(table,id,"SpellCaster").value)!=0,"pickSchool":int(_int_entry(table,id,"PickSchool").value)!=0,"arcane":int(_int_entry(table,id,"Arcane").value),"arcaneModifier":_byte(_int_entry(table,id,"ArcSpellLvlMod").value),"divineModifier":_byte(_int_entry(table,id,"DivSpellLvlMod").value)}

static func client_spell_gain_with_bonus(index: int,level: int,p: Dictionary) -> Dictionary:
	index=_byte(index);level=_byte(level)
	var classes: Array=p.classes.call();var cls: Dictionary=classes[index] if index<classes.size() else {}
	var info: Variant=p.classInfo.call(int(cls.get("id",-1))) if not cls.is_empty() else null
	if info==null:return {"error":"Native client spell-gain class metadata is unavailable"}
	var ability:=int(info.ability)
	if ability<0 or ability>5:return {"error":"Native client spell-gain ability reads uninitialized metadata"}
	var bonus:=_i8(p.abilityBonus.call(ability))
	var base:=_i8(p.baseAbility.call(ability))
	var race: Dictionary=p.raceAbility.call(ability)
	if race.has("error"):return race
	var increase: Dictionary=p.abilityIncrease.call(ability)
	if increase.has("error"):return increase
	var sum:=base+_i8(race.value)+_i8(increase.value)+bonus
	var score:=_i8(maxi(3,sum))
	var modified: Dictionary=p.modifier.call(ability)
	if modified.has("error"):return modified
	var modifier:=_i8(modified.value)
	if ability==1:modifier=_i8(modifier+_i8(p.dexBonus.call()))
	if _byte(score-bonus)<level-1+int(p.minimum.call()):return {"value":0}
	var extra:=int(float(modifier-level+4)/4.0) if level!=0 and modifier>0 and modifier>=level else 0
	if level!=0 and bool(info.pickSchool) and int(cls.get("school",0))!=0:extra+=1
	var prestige:=0
	for other in classes.size():
		if other==index:continue
		var rival: Dictionary=classes[other];var definition: Variant=p.classInfo.call(int(rival.get("id",-1)))
		if definition==null or bool(definition.spellCaster):continue
		var divisor:=_byte(definition.arcaneModifier if int(info.arcane)!=0 else definition.divineModifier)
		if divisor==0:continue
		if classes.size()>2:
			for competing in classes.size():
				if competing==other or competing==index:continue
				var candidate: Dictionary=classes[competing];var candidate_info: Variant=p.classInfo.call(int(candidate.get("id",-1)))
				if candidate_info!=null and bool(candidate_info.spellCaster) and int(candidate_info.arcane)==int(info.arcane) and (_byte(candidate.get("level",0))>_byte(cls.get("level",0)) or _byte(candidate.get("level",0))==_byte(cls.get("level",0)) and index<competing):divisor=0
		if divisor!=0:prestige=_byte(prestige+int(float(_byte(rival.get("level",0))-1+divisor)/float(divisor)))
	var gained: Dictionary=p.classGain.call(int(cls.id),_byte(int(cls.get("level",0))+prestige),level)
	if gained.has("error"):return gained
	var value:=_byte(gained.value)
	return {"value":0 if value==255 else _byte(value+extra)}

static func merge_network_ability_cache(previous: Variant,state: Dictionary,source: String) -> Dictionary:
	var cache: Dictionary=previous.duplicate(true) if previous is Dictionary else {"base":null,"current":null,"bonuses":[0,0,0,0,0,0],"dex":0}
	if source=="player" and state.get("abilities") is Dictionary:
		cache.base=state.abilities.get("base",[]).duplicate()
		cache.current=state.abilities.get("current",[]).duplicate()
	if source=="stats":
		if state.get("fields70") is Array:cache.current=state.fields70.duplicate()
		if state.get("fields7d") is Array:cache.bonuses=state.fields7d.duplicate()
		if state.get("fields76") is Array:
			cache.base=state.fields76.slice(0,6)
			cache.dex=state.fields76[6] if state.fields76.size()>6 else null
	return cache

static func client_class_gain(rules,id: int,level: int,spell_level: int) -> Dictionary:
	if ((_byte(level)-1)&255)>=40:return {"value":255}
	var classes: Dictionary=_table(rules,"classes")
	if classes.is_empty():return {"error":"Native client class rules are unavailable"}
	var name:=str(_string_entry(classes,id,"SpellGainTable").value).to_lower()
	if name.is_empty():return {"value":255}
	var table: Dictionary=_table(rules,name)
	if table.is_empty():return {"error":"Native client spell gain table "+name+" is unavailable"}
	var count: Dictionary=_int_entry(table,_byte(level)-1,"NumSpellLevels")
	if not count.found:return {"error":"Native class spell-gain level count is unavailable"}
	if _byte(spell_level)>=(int(count.value)&255):return {"value":255}
	var cell: Dictionary=_int_entry(table,_byte(level)-1,"SpellLevel"+str(_byte(spell_level)))
	return {"value":_byte(cell.value) if cell.found else 255}

static func _race_ability(actor: Dictionary,rules,index: int) -> Dictionary:
	var stats: Dictionary=actor.get("replicated",{}).get("stats",{})
	var race: Variant=stats.get("racialType")
	if race==null:race=stats.get("fieldD20")
	var table: Dictionary=_table(rules,"racialtypes")
	var rows: Array=table.get("orderedRows",[])
	if not race is int or int(race)<0 or int(race)>=rows.size() or not rows[int(race)] is Dictionary:return {"error":"Native client racial ability metadata is unavailable"}
	return {"value":int(_int_entry(table,int(race),NAMES[index]+"Adjust").value)}
static func _ability_increase(classes: Array,rules,index: int) -> Dictionary:
	var total:=0;var class_table: Dictionary=_table(rules,"classes")
	for cls in classes:
		var name:=str(_string_entry(class_table,int(cls.get("id",-1)),"StatGainTable").value).to_lower()
		if name.is_empty():continue
		var table: Dictionary=_table(rules,name)
		if table.is_empty():return {"error":"Native client stat gain table "+name+" is unavailable"}
		var level:=_byte(cls.get("level",0))
		if level>60:return {"error":"Native class ability gain reads outside verified storage"}
		var sum:=0
		for at in level:sum+=int(_int_entry(table,at,NAMES[index].to_upper()).value)
		total+=_i8(sum)
	return {"value":clampi(total,-128,127)}

static func _modifier(current: Variant,index: int,rules) -> Dictionary:
	var score: Variant=current[index] if current is Array and index<current.size() and current[index]!=null else rules.rule_value("CHARGEN_BASE_ABILITY_MIN",8)
	var value: Variant=Values.modifier(int(score),rules.text.tables)
	return {"value":value} if value!=null else {"error":"Ability modifier rules cause a native integer division fault"}

static func network_spell_gain(actor: Dictionary,rules,index: int,level: int) -> Dictionary:
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[])
	var cache: Dictionary=actor.get("clientAbilityCache",{}) if actor.get("clientAbilityCache") is Dictionary else merge_network_ability_cache(null,actor.get("playerState",{}),"player")
	var bonuses: Array=cache.get("bonuses",[])
	var base: Variant=cache.get("base")
	var current: Variant=cache.get("current")
	var p: Dictionary={
		"classes":func():return classes,
		"classInfo":func(id):return _class_info(rules,id),
		"minimum":func():return rules.rule_value("CHARGEN_BASE_ABILITY_MIN_PRIMARY",11),
		"abilityBonus":func(n):return bonuses[n] if n<bonuses.size() else 0,
		"dexBonus":func():return cache.get("dex",0),
		"baseAbility":func(n):return base[n] if base is Array and n<base.size() and base[n]!=null else 0,
		"modifier":func(n):return _modifier(current,n,rules),
		"raceAbility":func(n):return _race_ability(actor,rules,n),
		"abilityIncrease":func(n):return _ability_increase(classes,rules,n),
		"classGain":func(id,class_level,spell_level):return client_class_gain(rules,id,class_level,spell_level)
	}
	return client_spell_gain_with_bonus(index,level,p)
