extends RefCounted
# The default, effects-free BIC preview path of the former
# network_character_preview.js -> characterStats. This is display data only;
# no creature, world object, item owner, script, or effect is instantiated.
const Rules=preload("res://systems/native_data/character_preview_rules.gd")
const Visual=preload("res://systems/native_data/bic_visual.gd")
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const SAVE_FEATS={"fortitude":[[14,"GREAT_FORTITUDE_SAVE_BONUS",2],[248,"LUCKY_SAVE_BONUS",1],[388,"STRONG_SOUL_SAVE_BONUS",1],[583,"EPIC_FORTITUDE_SAVE_BONUS",4]],"reflex":[[24,"LIGHTNING_REFLEXES_SAVE_BONUS",2],[248,"LUCKY_SAVE_BONUS",1],[386,"SNAKE_BLOOD_REFLEX_BONUS",1],[585,"EPIC_REFLEXES_REFLEX_BONUS",4]],"will":[[22,"IRON_WILL_SAVE_BONUS",2],[248,"LUCKY_SAVE_BONUS",1],[380,"BULLHEADED_WILL_SAVE_BONUS",1],[388,"STRONG_SOUL_SAVE_BONUS",1],[695,"EPIC_WILL_SAVE_BONUS",4]]}
const SAVE_COLUMNS={"fortitude":"FortSave","reflex":"RefSave","will":"WillSave"}

static func _i8(value: int)->int:return (value&255)-256 if (value&128)!=0 else value&255
static func _i16(value: int)->int:return (value&65535)-65536 if (value&32768)!=0 else value&65535
static func _field(row: Dictionary,name: String)->Variant:
	for key in row:
		if str(key).to_lower()==name.to_lower():return row[key]
	return null
static func _number(value: Variant,fallback: int=0)->int:
	if value==null or str(value) in ["","****"]:return fallback
	return int(value)
static func _row(table: Dictionary,index: int)->Dictionary:
	var ordered: Variant=table.get("orderedRows",[])
	if ordered is Array and index>=0 and index<ordered.size() and ordered[index] is Dictionary:return ordered[index]
	var rows: Variant=table.get("rows",{})
	return rows.get(index,{}) if rows is Dictionary else {}
static func _int_entry(table: Dictionary,index: int,column: String)->Dictionary:
	var row:=_row(table,index)
	var value: Variant=_field(row,column)
	if row.is_empty() or value==null:return {"found":false,"value":_number(table.get("defaultValue","0"))}
	if str(value) in ["","****"]:return {"found":false,"value":0}
	var text:=str(value)
	return {"found":true,"value":text.hex_to_int() if text.to_lower().begins_with("0x") else int(text)}
static func _rule(tables: Dictionary,label: String,fallback: int)->int:
	var ruleset: Dictionary=tables.get("ruleset",{})
	var found:=false;var value:=fallback
	for row in ruleset.get("orderedRows",[]):
		if not row is Dictionary:continue
		if str(_field(row,"Label"))==label and str(_field(row,"Value")) not in ["","****"]:
			found=true;value=_number(_field(row,"Value"))
	return value if found else fallback
static func _modifier(score: int,tables: Dictionary)->Dictionary:
	var neutral:=_rule(tables,"CHARGEN_ABILITY_NEUTRAL_VALUE",10)
	var increment:=_rule(tables,"CHARGEN_ABILITY_MODIFIER_INCREMENT",2)
	var difference:=(score&255)-neutral
	if (score&255)<neutral and neutral%2==0:difference-=1
	if increment==0 or difference==-2147483648 and increment==-1:return {"error":"Ability modifier rules cannot divide."}
	return {"value":_i8(int(float(difference)/float(increment)))}
static func _feats(root: Dictionary)->Dictionary:
	var result: Dictionary={}
	for item in root.get("FeatList",[]):
		if item is Dictionary:result[int(item.get("Feat",-1))]=true
	return result
static func _class_level(classes: Array,id: int)->int:
	for row in classes:
		if row is Dictionary and int(row.get("Class",-1))==id:return int(row.get("ClassLevel",0))
	return 0
static func _equipment(document: Dictionary)->Dictionary:
	var items: Array=[]
	for at in document.get("root",{}).get("Equip_ItemList",[]).size():
		var item: Variant=document.root.Equip_ItemList[at]
		if not item is Dictionary:return {"error":"Invalid equipped character item."}
		var index:=Visual.index_of(document,item)
		if index<0 or index>=document.get("struct_types",[]).size():return {"error":"Equipped character item lacks physical GFF identity."}
		items.append({"data":item,"slot":int(document.struct_types[index]),"source":"equipped:"+str(at)})
	return {"items":items}
static func _ability_effect_bonus(items: Array,tables: Dictionary,ability: int)->Dictionary:
	var up_sum:=0;var down_sum:=0;var up_slots:=0;var down_slots:=0
	for item in items:
		var up:=0;var down:=0;var has_up:=false;var has_down:=false
		for prop in item.data.get("PropertiesList",[]):
			if not prop is Dictionary or int(prop.get("PropertyName",-1)) not in [0,27] or int(prop.get("Subtype",-1))!=ability:continue
			var increase:=int(prop.PropertyName)==0;var cost_id:=1 if increase else 21
			var cost: Dictionary=tables.itemCosts.get(cost_id,{})
			var row: Dictionary=cost.get("rows",{}).get(int(prop.get("CostValue",-1)),{})
			if row.is_empty() or _field(row,"Value")==null:return {"error":"Unknown equipment ability modifier cost value."}
			var amount:=maxi(0,_number(_field(row,"Value")))
			if increase:up=maxi(up,amount);has_up=true
			else:down=maxi(down,amount);has_down=true
		if has_up and up_slots<50:up_sum+=up;up_slots+=1
		if has_down and down_slots<50:down_sum+=down;down_slots+=1
	return {"value":mini(up_sum,12)-mini(down_sum,30)}
static func _abilities(root: Dictionary,tables: Dictionary,items: Array)->Dictionary:
	var race: Dictionary=tables.racialtypes.get("rows",{}).get(int(root.get("Race",-1)),{})
	if race.is_empty():return {"error":"Character race is missing from active rules."}
	var values: Dictionary={};var modifiers: Dictionary={}
	for at in ABILITIES.size():
		var name: String=ABILITIES[at];var gain:=0
		for cls in root.get("ClassList",[]):
			var class_row: Dictionary=tables.classes.get("rows",{}).get(int(cls.get("Class",-1)),{})
			if class_row.is_empty():return {"error":"Character class is missing from active rules."}
			var table_name:=str(class_row.get("StatGainTable","****")).to_lower()
			var table: Dictionary=tables.classTables.get(table_name,{})
			var class_gain:=0
			for level in maxi(0,int(cls.get("ClassLevel",0))):
				if not table.is_empty():class_gain+=_number(_field(_row(table,level),name.to_upper()))
			gain+=_i8(class_gain)
		var bonus: Dictionary=_ability_effect_bonus(items,tables,at)
		if bonus.has("error"):return bonus
		var total: int=(int(root.get(name,0))&255)+_i8(_number(_field(race,name+"Adjust")))+_i8(clampi(gain,-128,127))+_i8(int(bonus.value))
		values[name]=3 if total<3 else total&255
		var modifier: Dictionary=_modifier(int(values[name]),tables)
		if modifier.has("error"):return modifier
		modifiers[name]=modifier.value
	return {"values":values,"modifiers":modifiers}
static func _hit_points(root: Dictionary,tables: Dictionary,constitution: int,feats: Dictionary)->Dictionary:
	var classes: Array=root.get("ClassList",[]);var level:=0
	for cls in classes:level+=int(cls.get("ClassLevel",0))
	level&=255
	var toughness:=_rule(tables,"FEAT_TOUGHNESS_HP_BONUS",1) if feats.has(40) else 0
	var epic:=0
	for tier in range(10,0,-1):
		if feats.has(753+tier):epic=_i16(_rule(tables,"FEAT_EPIC_TOUGHNESS_HP_BONUS_"+str(tier),tier*20));break
	var pale:=_class_level(classes,34)
	var vigor:=_rule(tables,"FEAT_DEATHLESS_VIGOR_HP_BONUS",3)
	var epic_vigor:=_rule(tables,"FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS",5)
	var maximum:=0
	if int(root.get("IsPC",0))==1:
		var history: Array=root.get("LvlStatList",[])
		for at in mini(level,history.size()):maximum+=maxi(1,(int(history[at].get("LvlStatHitDie",0))&255)+constitution)+toughness
		if feats.has(891) and pale>4:maximum=_i16(maximum+_i16(vigor)*(mini(10,pale)-4))
		if feats.has(891) and pale>10:maximum=_i16(maximum+_i16(epic_vigor)*int(float(pale-10)/5.0))
		maximum=_i16(maximum+epic)
	else:
		var deathless:=_i16(_i16(vigor)*maxi(pale,10)+(_i16(epic_vigor)*int(float(pale-10)/5.0) if pale>10 else 0)) if feats.has(891) else 0
		maximum=_i16(maxi(level,_i16(int(root.get("HitPoints",0)))+constitution*level)+level*_i16(toughness)+deathless+epic)
	var base:=_i16(int(root.get("HitPoints",0)));var current:=_i16(int(root.get("CurrentHitPoints",base)))
	if int(root.get("IsPC",0))!=0:current=_i16(current+maximum-base)
	elif current<base or base+constitution*level>level:current=_i16(maximum+current-base)
	else:current=maximum
	return {"maximum":maximum,"current":current}
static func _pre_epic(root: Dictionary)->Array:
	var classes: Array=root.get("ClassList",[]);var total:=0
	for cls in classes:total+=int(cls.get("ClassLevel",0))
	total&=255
	var history: Array=root.get("LvlStatList",[]);var result: Array=[]
	if history.size()==total:
		for cls in classes:
			var count:=0
			for row in history:
				if (int(row.get("LvlStatClass",0))&255)==int(cls.get("Class",-1)) and int(row.get("EpicLevel",0))==0:count+=1
			result.append(count)
		return result
	var allocated:=0
	for cls in classes:
		var count:=mini(int(cls.get("ClassLevel",0)),20-allocated);allocated+=count;result.append(count)
	return result
static func _table_bonus(table: Dictionary,levels: int,column: String,require_found: bool=false)->int:
	if table.is_empty() or levels<1 or levels>60:return 0
	var entry:=_int_entry(table,(levels&255)-1,column)
	return (0 if require_found and not entry.found else int(entry.value))&255
static func _base_combat(root: Dictionary,tables: Dictionary,feats: Dictionary,charisma: int)->Dictionary:
	var classes: Array=root.get("ClassList",[]);var pre_epic:=_pre_epic(root)
	var class_attack:=0;var class_saves: Dictionary={"fortitude":0,"reflex":0,"will":0};var level:=0
	for at in classes.size():
		var cls: Dictionary=classes[at];level+=int(cls.get("ClassLevel",0))
		var row:=_row(tables.classes,int(cls.get("Class",-1)))
		if row.is_empty():return {"error":"Combat class rules are unavailable."}
		var attack: Dictionary=tables.classTables.get(str(row.get("AttackBonusTable","")).to_lower(),{})
		var saves: Dictionary=tables.classTables.get(str(row.get("SavingThrowTable","")).to_lower(),{})
		if attack.is_empty() or saves.is_empty():return {"error":"Combat class bonus rules are unavailable."}
		class_attack+=_table_bonus(attack,int(pre_epic[at]),"BAB",true)
		for name in SAVE_COLUMNS:class_saves[name]+= _table_bonus(saves,int(pre_epic[at]),str(SAVE_COLUMNS[name]))
	var epic:=maxi(0,(level&255)-20)
	var base: Dictionary={}
	var divine_grace:=maxi(0,charisma) if feats.has(217) else 0
	for name in SAVE_COLUMNS:
		var bonus:=0
		for entry in SAVE_FEATS[name]:
			if feats.has(int(entry[0])):bonus+=_rule(tables,str(entry[1]),int(entry[2]))
		base[name]=_i8(_i8(int(class_saves[name]))+_table_bonus(tables.epicsaves,epic,str(SAVE_COLUMNS[name]))+divine_grace+bonus)
	return {"baseAttackBonus":class_attack+_table_bonus(tables.epicattacks,epic,"BAB"),"baseSaves":base}
static func _base_item(item: Dictionary,tables: Dictionary)->Dictionary:
	return _row(tables.baseitems,int(item.get("data",{}).get("BaseItem",-1))) if not item.is_empty() else {}
static func _item_armor(item: Dictionary,tables: Dictionary)->Dictionary:
	if item.is_empty():return {"value":0}
	var base:=_base_item(item,tables)
	if base.is_empty():return {"error":"Character base item rules are unavailable."}
	if _number(_field(base,"ModelType"))==3:
		var chest:=_row(tables.parts_chest,int(item.data.get("ArmorPart_Torso",0))&65535)
		var raw: Variant=_field(chest,"ACBonus")
		var amount:=float(raw) if raw!=null and str(raw)!="****" else float(tables.parts_chest.get("defaultValue",0))
		return {"value":int(floor(amount+0.5))}
	return {"value":_number(_field(base,"BaseAC"))&255 if int(item.data.get("BaseItem",-1)) in [14,56,57] else 0}
static func _effects(root: Dictionary,tables: Dictionary,items: Array)->Dictionary:
	var result: Array=[];var haste:=false
	for item in items:
		var base:=_base_item(item,tables)
		if base.is_empty():return {"error":"Character base item rules are unavailable."}
		for prop in item.data.get("PropertiesList",[]):
			if not prop is Dictionary:continue
			var kind:=int(prop.get("PropertyName",-1));var cost_id:=-1
			if kind==1:cost_id=2
			elif kind in [40,41]:cost_id=1
			elif kind in [49,50]:cost_id=20
			if cost_id>=0:
				var cost: Dictionary=tables.itemCosts.get(cost_id,{})
				if cost.is_empty():return {"error":"Character item property cost rules are unavailable."}
				var amount:=int(_int_entry(cost,int(prop.get("CostValue",0))&65535,"Value").value)
				if kind==1:
					if amount>0:result.append({"type":48,"integers":[_number(_field(base,"AC_Enchant"))&255,amount,28,0,0,4103],"source":item.source})
				else:
					if amount<0 and int(root.get("Plot",0))!=0:continue
					var save:=0;var save_type:=0
					var subtype:=int(prop.get("Subtype",0))
					if kind in [41,50]:save={1:1,2:3,3:2}.get(subtype,0)
					else:
						var mapped: Dictionary=_int_entry(tables.get("iprp_saveelement",{}),subtype&65535,"SavingThrowType")
						save_type=int(mapped.value) if mapped.found else int({0:0,1:6,3:12,4:11,5:3,6:13,7:8,8:4,9:7,11:1,12:10,13:2,14:9,15:5,16:14,17:15,18:18,19:19,20:16,21:17}.get(subtype,0))
					result.append({"type":27 if amount<0 else 26,"integers":[absi(amount),save,save_type,28,0,0],"source":item.source})
			elif kind==35 and not haste:
				var bonus:=_rule(tables,"HASTE_DODGE_AC_INCREASE_AMOUNT",4)
				if bonus>0:result.append({"type":48,"integers":[0,bonus,28,0,0,4103],"source":item.source})
				haste=true
	return {"effects":result}
static func _source_total(effects: Array)->int:
	var slots: Dictionary={};var count:=0
	for effect in effects:
		var key:=str(effect.source)
		if slots.has(key):slots[key]=maxi(int(slots[key]),int(effect.integers[0]))
		elif count<50:slots[key]=int(effect.integers[0]);count+=1
	var total:=0
	for amount in slots.values():total+=int(amount)
	return total
static func _saving_effect(root: Dictionary,classes: Array,feats: Dictionary,effects: Array,save: int)->int:
	var up: Array=[];var down: Array=[]
	for effect in effects:
		if int(effect.type) not in [26,27]:continue
		var numbers: Array=effect.integers
		if int(numbers[1]) not in [0,save] or int(numbers[2])!=0 or int(numbers[3])!=28 or int(numbers[4])!=0 or int(numbers[5])!=0:continue
		if int(effect.type)==26:up.append(effect)
		else:down.append(effect)
	var sacred:=int(float(_class_level(classes,32))/2.0) if feats.has(904) and _class_level(classes,32)>1 else 0
	return mini(20,_source_total(up))+sacred-mini(20,_source_total(down))
static func _armor_cache(effects: Array)->Dictionary:
	var up: Array=[0,0,0,0,0];var down: Array=[0,0,0,0,0]
	for effect in effects:
		if int(effect.type) not in [48,49]:continue
		var numbers: Array=effect.integers;var category:=int(numbers[0]);var amount:=int(numbers[1])
		if int(numbers[2])!=28 or int(numbers[3])!=0 or int(numbers[4])!=0 or int(numbers[5])!=4103 or category<0 or category>4:continue
		var selected: Array=up if int(effect.type)==48 else down
		if category==0:selected[0]=_i8(int(selected[0])+amount)
		elif int(selected[category])<amount:selected[category]=_i8(amount)
	return {"up":up,"down":down}
static func _item_at(items: Array,slot: int)->Dictionary:
	for item in items:
		if int(item.slot)==slot:return item
	return {}
static func _natural(root: Dictionary,tables: Dictionary,modifiers: Dictionary,feats: Dictionary,armor: int,left: Dictionary)->Dictionary:
	var classes: Array=root.get("ClassList",[]);var monk:=_class_level(classes,5);var shou:=_class_level(classes,40)
	var left_base:=int(left.get("data",{}).get("BaseItem",-1))
	var monk_abilities: bool=(monk>0 or shou>0) and armor<4 and (armor<1 or shou>0) and left_base not in [14,56,57]
	var total:=_i8(int(root.get("NaturalAC",0)))
	var class_count: int=tables.classes.get("orderedRows",[]).size()
	for cls in classes:
		var id:=int(cls.get("Class",-1))&255
		if id>=class_count:continue
		var row:=_row(tables.classes,id)
		var table: Dictionary=tables.classTables.get(str(row.get("StatGainTable","")).to_lower(),{})
		if table.is_empty():continue
		var gain:=0
		for level in int(cls.get("ClassLevel",0))&255:gain+=int(_int_entry(table,level,"NaturalAC").value)
		total+=_i8(gain)
	total+=int(float(_class_level(classes,39))/3.0)
	if feats.has(490):total+=_rule(tables,"EPIC_ARMOR_SKIN_NATURAL_AC_BONUS",2)
	if monk_abilities:
		if feats.has(260) and int(modifiers.Wis)>0:total+=_i8(int(modifiers.Wis))
		total+=int(float(monk)/5.0)
	return {"value":_i8(total)}
static func _armor(root: Dictionary,tables: Dictionary,modifiers: Dictionary,feats: Dictionary,items: Array,effects: Array)->Dictionary:
	var chest:=_item_at(items,2);var left:=_item_at(items,32)
	var chest_armor:=_item_armor(chest,tables);var shield_armor:=_item_armor(left,tables)
	if chest_armor.has("error"):return chest_armor
	if shield_armor.has("error"):return shield_armor
	var armor:=int(chest_armor.value);var shield:=int(shield_armor.value)
	var natural:=_natural(root,tables,modifiers,feats,armor,left)
	var dexterity:=int(modifiers.Dex)
	if armor>0:
		var cap:=int(_int_entry(tables.armor,armor,"dexbonus").value)
		if cap>0:dexterity=mini(dexterity,_i8(cap))
	var skills: Array=root.get("SkillList",[])
	var rank:=_i8(int(skills[21].get("Rank",0))) if skills.size()>21 and skills[21] is Dictionary else 0
	rank=clampi(rank,-127,127)
	var per_tumble:=_rule(tables,"TUMBLE_NUM_RANKS_PER_AC_BONUS",5)
	if rank>0 and per_tumble==0:return {"error":"Tumble AC rule cannot divide."}
	var tumble:=_i8(int(float(rank)/float(per_tumble))) if rank>0 else 0
	var cache:=_armor_cache(effects);var up: Array=cache.up;var down: Array=cache.down
	var dodge:=_i8(mini(int(up[0])-int(down[0]),_rule(tables,"MAX_AC_DODGE_MOD",20)))
	var total:=10+_i8(armor+int(up[2])-int(down[2]))+_i8(shield+int(up[3])-int(down[3]))+_i8(int(up[4])-int(down[4]))+_i8(int(natural.value)+int(up[1])-int(down[1]))+dodge+tumble+dexterity
	return {"value":_i16(total)}
static func _saves(root: Dictionary,tables: Dictionary,modifiers: Dictionary,feats: Dictionary,base: Dictionary,effects: Array)->Dictionary:
	var result: Dictionary={};var classes: Array=root.get("ClassList",[])
	var luck:=_rule(tables,"LUCKOFHEROES_SAVE_BONUS",1) if feats.has(382) else 0
	var dark:=int(modifiers.Cha) if feats.has(473) else 0
	for name in ["fortitude","reflex","will"]:
		var ability:= "Con" if name=="fortitude" else "Dex" if name=="reflex" else "Wis"
		var selector:=1 if name=="fortitude" else 2 if name=="reflex" else 3
		var field:= "fortbonus" if name=="fortitude" else "refbonus" if name=="reflex" else "willbonus"
		result[name]=_i8(int(base.baseSaves[name])+int(modifiers[ability])+_i8(int(root.get(field,0)))+luck+dark+_saving_effect(root,classes,feats,effects,selector))
	return result
static func project(document: Dictionary,snapshot: Dictionary)->Dictionary:
	if not document.get("root") is Dictionary or not document.root.get("ClassList") is Array:return {"error":"Character preview has no class record."}
	var parsed:=Rules.decode(snapshot)
	if not parsed.get("ready",false):return {"error":str(parsed.get("error","Character preview rules are unavailable."))}
	var tables: Dictionary=parsed.tables;var root: Dictionary=document.root
	var equipped:=_equipment(document)
	if equipped.has("error"):return equipped
	var items: Array=equipped.items;var feats:=_feats(root)
	var abilities:=_abilities(root,tables,items)
	if abilities.has("error"):return abilities
	var hp:=_hit_points(root,tables,int(abilities.modifiers.Con),feats)
	var base:=_base_combat(root,tables,feats,int(abilities.modifiers.Cha))
	if base.has("error"):return base
	var projected:=_effects(root,tables,items)
	if projected.has("error"):return projected
	var armor:=_armor(root,tables,abilities.modifiers,feats,items,projected.effects)
	if armor.has("error"):return armor
	var saves:=_saves(root,tables,abilities.modifiers,feats,base,projected.effects)
	var level:=0
	for cls in root.ClassList:level+=int(cls.get("ClassLevel",0))
	var xp_row: Dictionary=tables.exptable.get("rows",{}).get(level,{})
	var xp: Variant=_field(xp_row,"XP")
	return {"ready":true,"abilities":abilities.values,"abilityModifiers":abilities.modifiers,"hitPoints":hp.maximum,"currentHitPoints":hp.current,"nextExperience":_number(xp) if xp!=null and str(xp)!="****" else null,"armorClass":armor.value,"saves":saves,"baseAttackBonus":base.baseAttackBonus}
