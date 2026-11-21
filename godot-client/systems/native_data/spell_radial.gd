extends RefCounted
# Original CClientSpellMenu9a10e0/9a2370/9a24b0/9a2b10. Received
# pools and the selected catalog own spell identity, availability and pages.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Pregame=preload("res://systems/native_data/pregame_spells.gd")
const NetworkSpellGain=preload("res://systems/native_data/native_network_spell_gain.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const NativeObjectRules=preload("res://systems/native_data/native_object_rules.gd")
const META=[[2,1,11,209,"IR_EMPOWER"],[6,2,12,293,"IR_EXTEND"],[0,4,25,413,"IR_MAXIMIZE"],[4,8,29,216,"IR_QUICKEN"],[7,16,33,218,"IR_SILENT"],[5,32,37,220,"IR_STILL"]]
const LEVEL_REFS=[691,690,725,687,684,1026,1014,720]
var rules
var abilities
var errors: Array=[]
var conversion_failure:=""
var uses_failure:=""
var always_subradial:=false
func note(message: String) -> void:
	if not errors.has(message): errors.append(message)
func classes(actor: Dictionary) -> Array: return abilities.classes(actor)
func class_row(actor: Dictionary,index: int) -> Dictionary: return abilities.class_row(actor,index)
func class_field(actor: Dictionary,index: int,column: String) -> Dictionary:
	var types: Array=classes(actor)
	if index<0 or index>=types.size():return {"found":false,"value":0}
	var entries:=NativeObjectRules.new();entries.tables=rules.text.tables
	return entries.int_entry("classes",int(types[index].id)&255,column)
func number(row: Dictionary,key: String,fallback: int=0) -> int: return Rules.number(Rules.cell(row,key),fallback)
func label(ref: int) -> String: return rules.text.raw({"strRef":ref})
func class_icon(id: int) -> String:return str(SpellMetadata.native_string_entry(rules.text.tables.get("classes",{}),id,"Icon").value)
func item(slot: int,title: String,icon: String,extra: Dictionary) -> Dictionary:
	return {"slot":slot,"label":title,"icon":icon,"action":"branch" if extra.has("menu") else "power","submenu":extra.has("menu"),"disabled":false,"canDrag":extra.has("binding"),"uses":null}.merged(extra,true)
func branch(slot: int,title: String,icon: String,menu: Dictionary) -> Dictionary:
	return item(slot,title,icon,{"menu":menu.merged({"title":title,"center":icon})})
func level_icon(level: int) -> String: return "IR_CANTRIPS" if level==0 else "IR_LEVEL789" if level>=7 else "IR_LEVEL"+str(level)
func dependencies(actor: Dictionary) -> Array:
	var names: Array=[]
	for index in classes(actor).size():
		for field in ["FeatsTable","SpellGainTable","StatGainTable"]:
			var name:=str(SpellMetadata.native_string_entry(rules.text.tables.get("classes",{}),int(classes(actor)[index].id),field).value).to_lower()
			if not name.is_empty() and not names.has(name): names.append(name)
	return names
func target_allowed(ctx: Dictionary,id: int) -> bool:
	var spell: Variant=rules.casting_spell(id)
	return spell!=null and (int(spell.targetType)&int(ctx.get("filter",65535))&int(ctx.get("targetBit",0)))!=0
func converted(actor: Dictionary,index: int,id: int,uses: int,assignment: bool) -> bool:
	var spell: Variant=rules.casting_spell(id)
	if assignment or uses!=0:return false
	if index<0 or index>=classes(actor).size() or (int(classes(actor)[index].id)&255)==255:return false
	var entry: Dictionary=class_field(actor,index,"CanCastSpontaneously")
	if not entry.found:
		conversion_failure="Native class CanCastSpontaneously reads uninitialized loader storage"
		note(conversion_failure)
		return false
	return int(entry.value)!=0 and spell!=null and int(spell.spontaneouslyCast)!=0
func ready_conversion(actor: Dictionary,index: int,level: int) -> bool:
	var slots: Array=actor.get("playerState",{}).get("spellbooks",{}).get(str(index),{}).get("memorized",{}).get(str(level),[])
	return slots.slice(0,slots.size()&255).any(func(slot):return slot is Dictionary and Rules.flag(slot.get("ready",false)) and not Rules.flag(slot.get("domain",false)))
func override_active(actor: Dictionary) -> bool:
	# Reader7b4f70 -> setter80a700. fields9E8 is the three signed spell IDs
	# read by the same message and installed by80abd0; no inferred spellbook.
	return (abilities.player_flags(actor)&1024)!=0
func shortcut(actor: Dictionary,binding: Dictionary) -> Dictionary:
	uses_failure=""
	# Original quickbar assignment/refresh868e70 recalculates the conversion bit;
	# it is not a separately serialized type2 quickbar field.
	var selected:=binding.duplicate(); var id:=int(binding.get("intParam",-1)); var index:=int(binding.get("classIndex",0)); var meta:=int(binding.get("metamagic",0)); var domain:=int(binding.get("domainLevel",0))
	var children: Array=rules.spell_children(id)
	if not children.is_empty(): id=int(children[0]); selected.intParam=id
	if override_active(actor):
		selected.spontaneous=0
		return {"binding":selected,"uses":"*","enabled":true}
	rules.spellbook_failure=""
	var uses: int=rules.spell_uses(actor,id,index,meta,domain)
	if not rules.spellbook_failure.is_empty():
		uses_failure=rules.spellbook_failure
		return {}
	var convert:=converted(actor,index,id,uses,false)
	selected.spontaneous=int(convert)
	var base_level: int=domain if domain else rules.spell_level(id,int(classes(actor)[index].id)) if index>=0 and index<classes(actor).size() else 255
	return {"binding":selected,"uses":"S" if convert else uses,"enabled":ready_conversion(actor,index,base_level+rules.meta_cost(meta)) if convert else uses>0}
func spell_gain(actor: Dictionary,index: int,level: int) -> int:
	var result: Dictionary=NetworkSpellGain.network_spell_gain(actor,rules,index,level)
	if result.has("error"):
		note(str(result.error))
		return 0
	return int(result.value)
func root(ctx: Dictionary) -> Array:
	var result: Array=[]; var actor: Dictionary=ctx.actor; var casters: Array=[]; var owned: Variant=ctx.owned
	if bool(ctx.get("assignment",false)):
		var player: Dictionary=actor.get("playerState",{}); owned=player.get("feats",[]).duplicate(); owned.append_array(player.get("bonusFeats",[]))
	var has_meta:=META.any(func(value):return owned.has(value[2]))
	for index in mini(8,classes(actor).size()):
		if int(class_field(actor,index,"SpellCaster").value)!=0: casters.append(index)
	if classes(actor).size()>=4 or always_subradial:
		result.append(branch(4,label(2295),"IR_CAST",{"kind":"spell-classes","metamagic":false}))
		if has_meta: result.append(branch(0,label(695),"IR_METAMAGIC",{"kind":"spell-classes","metamagic":true}))
	else:
		for index in casters:
			var icon:=class_icon(int(classes(actor)[index].id)); var name: String=rules.title("classes",int(classes(actor)[index].id))
			result.append(branch(5-index,name,icon,{"kind":"spell-levels","classIndex":index,"metamagic":0}))
			if has_meta: result.append(branch(int([7,0,1][index]),label(695),icon,{"kind":"spell-meta","classIndex":index}))
	if not casters.is_empty():
		if ctx.owned.has(1001): result.append(item(2,"Epic spells","IR_EPICSPELL",{"action":"spell.epic","system":"epic spell feat casting"}))
		result.append(branch(6,label(83625),"IR_SPELL_ABS",{"kind":"spell-options"}))
	return result
func menu(ctx: Dictionary,descriptor: Dictionary) -> Array:
	conversion_failure="";uses_failure=""
	var kind:=str(descriptor.get("kind","spell-root")); var index:=int(descriptor.get("classIndex",0)); var meta:=int(descriptor.get("metamagic",0)) if descriptor.get("metamagic",0) is not bool else 0; var result: Array=[]
	match kind:
		"spell-root": return root(ctx)
		"spell-classes":
			for at in mini(8,classes(ctx.actor).size()):
				if int(class_field(ctx.actor,at,"SpellCaster").value)!=0: result.append(branch(at,rules.title("classes",int(classes(ctx.actor)[at].id)),class_icon(int(classes(ctx.actor)[at].id)),{"kind":"spell-meta" if descriptor.get("metamagic",false) else "spell-levels","classIndex":at,"metamagic":0}))
		"spell-meta":
			var owned: Variant=ctx.owned
			if bool(ctx.get("assignment",false)):
				var player: Dictionary=ctx.actor.get("playerState",{}); owned=player.get("feats",[]).duplicate(); owned.append_array(player.get("bonusFeats",[]))
			for value in META:
				if owned.has(value[2]): result.append(branch(int(value[0]),label(int(value[3])),str(value[4]),{"kind":"spell-levels","classIndex":index,"metamagic":int(value[1])}))
		"spell-levels":
			for level in 8: result.append(branch(level,label(LEVEL_REFS[level]),level_icon(level),{"kind":"spell-page","classIndex":index,"metamagic":meta,"level":level,"cursor":0}))
		"spell-page": return page(ctx,index,meta,int(descriptor.get("level",0)),int(descriptor.get("cursor",0)),descriptor.get("seen",[]))
		"spell-family": return family(ctx,descriptor)
		"spell-options":
			result.append(item(0,"Counterspell","IR_CNTRSPELL",{"action":"spell.counterspell","system":"counterspell selection and resolution","disabled":int(ctx.get("targetBit",0))!=2}))
			result.append(item(1,"Defensive casting","ir_defcast",{"action":"spell.defensiveCasting","system":"defensive casting input"}))
	return result
func pool(actor: Dictionary,index: int,meta: int,level: int,assignment: bool=false) -> Array:
	if index<0 or index>=classes(actor).size() or level<0 or level>9: return []
	var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(index),{}); var result: Array=[]
	if assignment:
		var base: int=level-int(rules.meta_cost(meta))
		if base>=0:
			for entry in rules.preparation_entries(actor,index,base,meta):
				result.append({"cursor":result.size(),"spellId":int(entry.id),"metamagic":meta,"domainLevel":base&255 if bool(entry.domain) else 0})
			if not rules.spellbook_failure.is_empty():note(rules.spellbook_failure);return []
		for slot in book.get("memorized",{}).get(str(level),[]):
			if not slot is Dictionary or int(slot.get("spell",-1))<0 or int(slot.get("metamagic",0))!=meta:continue
			result.append({"cursor":result.size(),"spellId":int(slot.spell),"metamagic":meta,"domainLevel":(level-rules.meta_cost(meta))&255 if Rules.flag(slot.get("domain",false)) else 0,"prepared":true})
		return result
	if int(class_field(actor,index,"MemorizesSpells").value)!=0:
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
		if int(class_field(actor,index,"SpellbookRestricted").value)!=0:
			for id in book.get("known",[]):
				if rules.spell_level(int(id),int(classes(actor)[index].id))==base: ids.append(id)
			for cursor in ids.size()&65535: result.append({"cursor":cursor,"spellId":ids[cursor],"metamagic":meta,"domainLevel":0})
		else:
			for id in rules.text.tables.get("spells",{}).get("orderedRows",[]).size(): result.append({"cursor":id,"spellId":id if rules.spell_level(id,int(classes(actor)[index].id))==base else -1,"metamagic":meta,"domainLevel":0})
	return result
func page(ctx: Dictionary,index: int,meta: int,first_level: int,cursor: int=0,previously_seen: Array=[]) -> Array:
	var result: Array=[]; var seen: Dictionary={}
	for identity in previously_seen:seen[str(identity)]=true
	for level in range(first_level,10 if first_level>=7 else first_level+1):
		for source in pool(ctx.actor,index,meta,level,bool(ctx.get("assignment",false))):
			if level==first_level and int(source.cursor)<cursor: continue
			var id:=int(source.spellId); var spell: Variant=rules.casting_spell(id)
			var identity:=str(id)+":"+str(int(source.metamagic))+":"+str(int(source.domainLevel)) if bool(ctx.get("assignment",false)) else str(id)
			if spell==null or meta!=0 and not (bool(ctx.get("assignment",false)) and bool(source.get("prepared",false))) and (int(spell.metamagic)&meta)==0 or seen.has(identity): continue
			if result.size()==7:
				result.append(branch(7,label(1499),level_icon(level),{"kind":"spell-page","classIndex":index,"metamagic":meta,"level":level,"cursor":int(source.cursor),"seen":seen.keys()})); return result
			seen[identity]=true
			var binding:={"type":2,"intParam":id,"classIndex":index,"metamagic":int(source.metamagic),"domainLevel":int(source.domainLevel)}
			rules.spellbook_failure=""
			var uses: int=rules.spell_uses(ctx.actor,id,index,int(source.metamagic),int(source.domainLevel))&255
			if not rules.spellbook_failure.is_empty():
				uses_failure=rules.spellbook_failure
				return []
			result.append(spell_entry(ctx,result.size(),id,binding,uses,level))
	return result
func spell_entry(ctx: Dictionary,slot: int,id: int,binding: Dictionary,uses: int,level: int,path: Array=[],family_conversion: Variant=null) -> Dictionary:
	var title: String=rules.title("spells",id); var icon: String=rules.icon("spells",id); var children: Array=rules.spell_children(id,path)
	if icon.is_empty():icon="IR_CAST"
	if rules.spell_family(id):
		var convert: bool=bool(family_conversion) if family_conversion!=null else converted(ctx.actor,int(binding.classIndex),id,uses,bool(ctx.assignment))
		var value:=branch(slot,title,icon,{"kind":"spell-family","parent":id,"binding":binding,"uses":uses,"level":level,"path":path+[id],"familyConversion":convert})
		value.disabled=not ctx.assignment and (uses==0 or not target_allowed(ctx,id)); return value
	var convert: bool=bool(family_conversion) if family_conversion!=null else converted(ctx.actor,int(binding.classIndex),int(binding.intParam),uses,bool(ctx.assignment)); var selected:=binding.merged({"intParam":id,"spontaneous":int(convert)},true)
	var available:=ready_conversion(ctx.actor,int(binding.classIndex),level) if convert else uses>0
	return item(slot,title,icon,{"binding":selected,"uses":"S" if convert else uses,"disabled":not ctx.assignment and (not target_allowed(ctx,id) or not available)})
func family(ctx: Dictionary,descriptor: Dictionary) -> Array:
	var result: Array=[]; var parent:=int(descriptor.parent); var path: Array=descriptor.get("path",[])
	# spell_radial.js:childEntries enumerates the filtered, unique children in
	# order, assigning consecutive wheel slots after invalid children vanish.
	for id in rules.spell_children(parent,path):
		var value:=spell_entry(ctx,result.size(),int(id),descriptor.binding,int(descriptor.uses),int(descriptor.level),path,descriptor.get("familyConversion"))
		result.append(value)
	return result
