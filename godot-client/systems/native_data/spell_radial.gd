extends RefCounted
# Original CClientSpellMenu9a10e0/9a2370/9a24b0/9a2b10. Received
# pools and the selected catalog own spell identity, availability and pages.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Pregame=preload("res://systems/native_data/pregame_spells.gd")
const META=[[2,1,11,209,"IR_EMPOWER"],[6,2,12,293,"IR_EXTEND"],[0,4,25,413,"IR_MAXIMIZE"],[4,8,29,216,"IR_QUICKEN"],[7,16,33,218,"IR_SILENT"],[5,32,37,220,"IR_STILL"]]
const LEVEL_REFS=[691,690,725,687,684,1026,1014,720]
var rules
var abilities
var errors: Array=[]
var always_subradial:=false
func note(message: String) -> void:
	if not errors.has(message): errors.append(message)
func classes(actor: Dictionary) -> Array: return abilities.classes(actor)
func class_row(actor: Dictionary,index: int) -> Dictionary: return abilities.class_row(actor,index)
func number(row: Dictionary,key: String,fallback: int=0) -> int: return Rules.number(Rules.cell(row,key),fallback)
func label(ref: int) -> String: return rules.text.raw({"strRef":ref})
func item(slot: int,title: String,icon: String,extra: Dictionary) -> Dictionary:
	return {"slot":slot,"label":title,"icon":icon,"action":"branch" if extra.has("menu") else "power","submenu":extra.has("menu"),"disabled":false,"canDrag":extra.has("binding"),"uses":null}.merged(extra,true)
func branch(slot: int,title: String,icon: String,menu: Dictionary) -> Dictionary:
	return item(slot,title,icon,{"menu":menu.merged({"title":title,"center":icon})})
func level_icon(level: int) -> String: return "IR_CANTRIPS" if level==0 else "IR_LEVEL789" if level>=7 else "IR_LEVEL"+str(level)
func dependencies(actor: Dictionary) -> Array:
	var names: Array=[]
	for index in classes(actor).size():
		for field in ["FeatsTable","SpellGainTable","StatGainTable"]:
			var name:=Skills.table_name(class_row(actor,index),field)
			if not name.is_empty() and not names.has(name): names.append(name)
	return names
func target_allowed(ctx: Dictionary,id: int) -> bool:
	var spell: Dictionary=rules.row("spells",id)
	return not spell.is_empty() and (number(spell,"TargetType")&int(ctx.get("filter",65535))&int(ctx.get("targetBit",0)))!=0
func converted(actor: Dictionary,index: int,id: int,uses: int,assignment: bool) -> bool:
	return not assignment and uses==0 and number(class_row(actor,index),"CanCastSpontaneously")!=0 and number(rules.row("spells",id),"SpontaneouslyCast")!=0
func ready_conversion(actor: Dictionary,index: int,level: int) -> bool:
	var slots: Array=actor.get("playerState",{}).get("spellbooks",{}).get(str(index),{}).get("memorized",{}).get(str(level),[])
	return slots.slice(0,slots.size()&255).any(func(slot):return slot is Dictionary and Rules.flag(slot.get("ready",false)) and not Rules.flag(slot.get("domain",false)))
func override_active(actor: Dictionary) -> bool:
	# Reader7b4f70 -> setter80a700. fields9E8 is the three signed spell IDs
	# read by the same message and installed by80abd0; no inferred spellbook.
	return (abilities.player_flags(actor)&1024)!=0
func shortcut(actor: Dictionary,binding: Dictionary) -> Dictionary:
	# Original quickbar assignment/refresh868e70 recalculates the conversion bit;
	# it is not a separately serialized type2 quickbar field.
	var selected:=binding.duplicate(); var id:=int(binding.get("intParam",-1)); var index:=int(binding.get("classIndex",0)); var meta:=int(binding.get("metamagic",0)); var domain:=int(binding.get("domainLevel",0))
	var children: Array=rules.spell_children(id)
	if not children.is_empty(): id=int(children[0]); selected.intParam=id
	if override_active(actor):
		selected.spontaneous=0
		return {"binding":selected,"uses":"*","enabled":true}
	var uses: int=rules.spell_uses(actor,id,index,meta,domain); var convert:=converted(actor,index,id,uses,false)
	selected.spontaneous=int(convert)
	var base_level: int=domain if domain else rules.spell_level(id,int(classes(actor)[index].id)) if index>=0 and index<classes(actor).size() else 255
	return {"binding":selected,"uses":"S" if convert else uses,"enabled":ready_conversion(actor,index,base_level+rules.meta_cost(meta)) if convert else uses>0}
func spell_gain(actor: Dictionary,index: int,level: int) -> int:
	# Original7f6b20 uses the arrival-ordered client ability cache, not remaining
	# spontaneous uses (which can be zero while the menu must remain visible).
	var cls:=class_row(actor,index); var ability: int=["STR","DEX","CON","INT","WIS","CHA"].find(str(Rules.cell(cls,"SpellcastingAbil","")).to_upper())
	if ability<0: note("Spellcasting ability metadata is unavailable"); return 0
	var cache: Dictionary=actor.get("clientAbilityCache",{})
	var source: Dictionary=actor.get("playerState",{}).get("abilities",{})
	var base: Array=cache.get("base",source.get("base",[])) if cache.get("base",source.get("base",[])) is Array else []
	var current: Array=cache.get("current",source.get("current",[])) if cache.get("current",source.get("current",[])) is Array else []
	var bonus: Array=cache.get("bonuses",[0,0,0,0,0,0]); var gains:=Skills.class_gains({"classes":classes(actor)},rules.text.tables)
	var racial: Dictionary=actor.get("replicated",{}).get("stats",{}); var race: Dictionary=rules.row("racialtypes",int(racial.get("racialType",racial.get("fieldD20",-1))))
	if base.size()<6 or current.size()<6 or gains.size()<6 or race.is_empty(): note("Received spell-gain ability/race state is unavailable"); return 0
	var adjustment:=Values.signed8(int(bonus[ability])); var score:=Values.signed8(maxi(3,Values.signed8(int(base[ability]))+Values.signed8(number(race,str(Skills.KEYS[ability])+"Adjust"))+int(gains[ability])+adjustment))
	if ((score-adjustment)&255)<level-1+rules.rule_value("CHARGEN_BASE_ABILITY_MIN_PRIMARY",11): return 0
	var raw_modifier: Variant=Values.modifier(int(current[ability]),rules.text.tables)
	if raw_modifier==null: note("Spell-gain modifier rules are invalid"); return 0
	var modifier:=Values.signed8(int(raw_modifier)+(Values.signed8(int(cache.get("dex",0))) if ability==1 else 0)); var extra:=0
	if level!=0 and modifier>0 and modifier>=level: extra=int((modifier-level+4)/4)
	if level!=0 and number(cls,"PickSchool")!=0 and int(classes(actor)[index].get("school",0))!=0: extra+=1
	var effective: int=(int(classes(actor)[index].level)+Pregame.prestige_levels(classes(actor),rules.text.tables,index))&255
	if effective<1 or effective>40: return 0
	var gain: Dictionary=rules.row(Skills.table_name(cls,"SpellGainTable"),effective-1)
	if level>=(number(gain,"NumSpellLevels")&255): return 0
	var value:=number(gain,"SpellLevel"+str(level),255)&255
	return 0 if value==255 else (value+extra)&255
func root(ctx: Dictionary) -> Array:
	var result: Array=[]; var actor: Dictionary=ctx.actor; var casters: Array=[]; var has_meta:=META.any(func(value):return ctx.owned.has(value[2]))
	if override_active(actor):
		var ids: Array=actor.get("playerState",{}).get("fields9E8",[])
		for at in mini(3,ids.size()):
			var id:=int(ids[at])
			if id<0: continue
			if rules.row("spells",id).is_empty(): note("Received override spell is unavailable: "+str(id)); continue
			result.append(item(at+1,rules.title("spells",id),rules.icon("spells",id),{"binding":{"type":2,"intParam":id,"classIndex":0,"metamagic":0,"domainLevel":0,"spontaneous":0}}))
		return result
	for index in mini(8,classes(actor).size()):
		if number(class_row(actor,index),"SpellCaster")!=0: casters.append(index)
	if classes(actor).size()>=4 or always_subradial:
		result.append(branch(4,label(2295),"IR_CAST",{"kind":"spell-classes","metamagic":false}))
		if has_meta: result.append(branch(0,label(695),"IR_METAMAGIC",{"kind":"spell-classes","metamagic":true}))
	else:
		for index in casters:
			var icon:=str(Rules.cell(class_row(actor,index),"Icon","IR_CAST")); var name: String=rules.title("classes",int(classes(actor)[index].id))
			result.append(branch(5-index,name,icon,{"kind":"spell-levels","classIndex":index,"metamagic":0}))
			if has_meta: result.append(branch(int([7,0,1][index]),label(695),icon,{"kind":"spell-meta","classIndex":index}))
	if not casters.is_empty():
		if ctx.owned.has(1001): result.append(branch(2,label(83630),"IR_EPICSPELL",{"kind":"spell-epic","start":0}))
		result.append(branch(6,label(83625),"IR_SPELL_ABS",{"kind":"spell-options"}))
	return result
func menu(ctx: Dictionary,descriptor: Dictionary) -> Array:
	var kind:=str(descriptor.get("kind","spell-root")); var index:=int(descriptor.get("classIndex",0)); var meta:=int(descriptor.get("metamagic",0)) if descriptor.get("metamagic",0) is not bool else 0; var result: Array=[]
	match kind:
		"spell-root": return root(ctx)
		"spell-classes":
			for at in mini(8,classes(ctx.actor).size()):
				if number(class_row(ctx.actor,at),"SpellCaster")!=0: result.append(branch(at,rules.title("classes",int(classes(ctx.actor)[at].id)),str(Rules.cell(class_row(ctx.actor,at),"Icon","IR_CAST")),{"kind":"spell-meta" if descriptor.get("metamagic",false) else "spell-levels","classIndex":at,"metamagic":0}))
		"spell-meta":
			for value in META:
				if ctx.owned.has(value[2]): result.append(branch(int(value[0]),label(int(value[3])),str(value[4]),{"kind":"spell-levels","classIndex":index,"metamagic":int(value[1])}))
		"spell-levels":
			for level in 8: result.append(branch(level,label(LEVEL_REFS[level]),level_icon(level),{"kind":"spell-page","classIndex":index,"metamagic":meta,"level":level,"cursor":0}))
		"spell-page": return page(ctx,index,meta,int(descriptor.get("level",0)),int(descriptor.get("cursor",0)))
		"spell-family": return family(ctx,descriptor)
		"spell-epic": return epic(ctx,int(descriptor.get("start",0)))
		"spell-options":
			result.append(item(0,label(int(abilities.activity(ctx.actor,5).labelRef)),"IR_CNTRSPELL",{"action":"activity","activityId":5,"binding":{"type":10,"intParam":5},"disabled":not ctx.assignment and int(ctx.get("targetBit",0))!=2}))
			result.append(item(1,label(int(abilities.activity(ctx.actor,10).labelRef)),"ir_defcast",{"action":"activity","activityId":10,"binding":{"type":10,"intParam":10}}))
	return result
func pool(actor: Dictionary,index: int,meta: int,level: int) -> Array:
	if index<0 or index>=classes(actor).size() or level<0 or level>9: return []
	var cls:=class_row(actor,index); var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(index),{}); var result: Array=[]
	if number(cls,"MemorizesSpells")!=0:
		var memory: Array=book.get("memorized",{}).get(str(level),[])
		for cursor in memory.size()&255:
			var slot: Variant=memory[cursor]; var row:={"cursor":cursor,"spellId":-1}
			if slot is Dictionary and (meta==0 or (int(slot.get("metamagic",0))&255)==meta):
				var selected:=int(slot.get("metamagic",0))&255
				row.merge({"spellId":int(slot.spell),"metamagic":selected,"domainLevel":(level-rules.meta_cost(selected))&255 if Rules.flag(slot.get("domain",false)) else 0},true)
			result.append(row)
	else:
		if spell_gain(actor,index,level)==0: return []
		var base: int=level-rules.meta_cost(meta)
		if base<0: return []
		var ids: Array=[]
		if number(cls,"SpellbookRestricted")!=0:
			for id in book.get("known",[]):
				if rules.spell_level(int(id),int(classes(actor)[index].id))==base: ids.append(id)
			for cursor in mini(ids.size()&65535,rules.text.tables.get("spells",{}).get("orderedRows",[]).size()): result.append({"cursor":cursor,"spellId":ids[cursor&255],"metamagic":meta,"domainLevel":0})
		else:
			for id in rules.text.tables.get("spells",{}).get("orderedRows",[]).size(): result.append({"cursor":id,"spellId":id if rules.spell_level(id,int(classes(actor)[index].id))==base else -1,"metamagic":meta,"domainLevel":0})
	return result
func page(ctx: Dictionary,index: int,meta: int,first_level: int,cursor: int=0) -> Array:
	var result: Array=[]; var seen: Dictionary={}
	for level in range(first_level,10 if first_level>=7 else first_level+1):
		for source in pool(ctx.actor,index,meta,level):
			if level==first_level and int(source.cursor)<cursor: continue
			var id:=int(source.spellId); var spell: Dictionary=rules.row("spells",id)
			if spell.is_empty() or meta!=0 and (number(spell,"MetaMagic")&meta)==0 or seen.has(id): continue
			seen[id]=true
			if result.size()==7:
				result.append(branch(7,label(1499),level_icon(level),{"kind":"spell-page","classIndex":index,"metamagic":meta,"level":level,"cursor":int(source.cursor)})); return result
			var binding:={"type":2,"intParam":id,"classIndex":index,"metamagic":int(source.metamagic),"domainLevel":int(source.domainLevel)}
			var uses: int=rules.spell_uses(ctx.actor,id,index,int(source.metamagic),int(source.domainLevel))&255
			result.append(spell_entry(ctx,result.size(),id,binding,uses,level))
	return result
func spell_entry(ctx: Dictionary,slot: int,id: int,binding: Dictionary,uses: int,level: int,path: Array=[]) -> Dictionary:
	var title: String=rules.title("spells",id); var icon: String=rules.icon("spells",id); var children: Array=rules.spell_children(id,path)
	if not children.is_empty():
		var value:=branch(slot,title,icon,{"kind":"spell-family","parent":id,"binding":binding,"uses":uses,"level":level,"path":path+[id]})
		value.disabled=not ctx.assignment and (uses==0 or not target_allowed(ctx,id)); return value
	var convert:=converted(ctx.actor,int(binding.classIndex),int(binding.intParam),uses,bool(ctx.assignment)); var selected:=binding.merged({"intParam":id,"spontaneous":int(convert)},true)
	var available:=ready_conversion(ctx.actor,int(binding.classIndex),level) if convert else uses>0
	return item(slot,title,icon,{"binding":selected,"uses":"S" if convert else uses,"disabled":not ctx.assignment and (not target_allowed(ctx,id) or not available)})
func family(ctx: Dictionary,descriptor: Dictionary) -> Array:
	var result: Array=[]; var parent:=int(descriptor.parent); var source: Dictionary=rules.row("spells",parent); var path: Array=descriptor.get("path",[])
	if path.size()>16: note("Spell family nesting exceeds verified storage"); return []
	# Keep the original physical SubRadSpell slot; a missing child leaves a hole.
	for slot in 8:
		var id:=number(source,"SubRadSpell"+str(slot+1),-1)
		if id<0 or path.has(id) or rules.row("spells",id).is_empty(): continue
		var value:=spell_entry(ctx,slot,id,descriptor.binding,int(descriptor.uses),int(descriptor.level),path)
		result.append(value)
	return result
func epic(ctx: Dictionary,start: int) -> Array:
	var ids: Array=[]; var result: Array=[]
	for index in mini(8,classes(ctx.actor).size()):
		var cls:=class_row(ctx.actor,index)
		if number(cls,"SpellCaster")!=1 and not (int(classes(ctx.actor)[index].id)==34 and int(classes(ctx.actor)[index].level)>14): continue
		for record in abilities.class_records(ctx.actor,index):
			if int(record.onMenu)!=2: continue
			var id:=int(record.id); var seen: Dictionary={}; var selected:=-1
			while id>0 and ctx.owned.has(id) and not seen.has(id):
				seen[id]=true; selected=id; id=int(abilities.feats.feat(id).get("successor",0))&65535
			if selected>=0 and not ids.has(selected): ids.append(selected)
	for at in range(start,mini(start+7,ids.size())): result.append({"slot":at-start,"epicFeat":ids[at]})
	if ids.size()>start+7: result.append(branch(7,label(8776),"IR_EPICSPELL",{"kind":"spell-epic","start":start+7}))
	return result
