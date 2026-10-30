extends RefCounted
func queued_actions(entries: Array) -> Array:
	var result: Array=[]
	for source in entries:
		var id:=int(source.type); var special:=flag(source.get("special",false)); var data:=row("actions",id)
		var resource:=str(cell(data,"ICONRESREF","")); var spell:=int(source.get("spell",-1))
		if not special and id in [4,19]:
			var spell_data:=row("spells",spell)
			if id==19 and spell_data.is_empty(): continue
			var feat:=number(cell(spell_data,"FeatID"),0)&65535
			resource=icon("feat",feat) if id==4 and feat!=0 else icon("spells",spell)
		elif resource.is_empty() and not special: resource="ir_use"
		var entry: Dictionary=source.duplicate(true); entry.icon=resource.to_lower(); entry.label=text.raw({"strRef":number(cell(data,"STRING_REF"),-1)})
		if str(entry.label).is_empty(): entry.label=str(cell(data,"LABEL","Action"))
		result.append(entry)
	return result
# Presentation projections from received server fields and original native 2DAs.
# Never predicts a combat outcome, grants a feat or changes a spell's uses.
var text
var record_errors: Array=[]
const INVALID:=2130706432
const ABILITIES=["Strength","Dexterity","Constitution","Intelligence","Wisdom","Charisma"]
const RecordValues=preload("res://systems/native_data/character_record_values.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const RecordEntries=preload("res://systems/native_data/character_record_entries.gd")
const PartyHealth=preload("res://systems/native_data/party_health.gd")
const HUD_ACTIONS=[["map","Map","pb_but_map","m"],["inventory","Inventory","pb_but_inv","i"],["journal","Journal","pb_but_jour","j"],["character","Character Sheet","pb_but_char","c"],["rest","Rest","pb_but_rest","r"],["spells","Spellbook","pb_but_spell","b"],["options","Options","pb_but_opts","o"],["pvp","Player versus Player","pb_but_pvp",null]]
static func number(value: Variant,fallback: int=-1) -> int:
	if value is int or value is float: return int(value)
	var source:=str(value)
	if source.is_valid_int(): return int(source)
	if source.begins_with("0x") and source.is_valid_hex_number(true): return source.hex_to_int()
	return fallback
static func flag(value: Variant) -> bool:
	return value if value is bool else number(value,0)!=0
static func cell(row: Dictionary,column: String,fallback: Variant=null) -> Variant:
	if row.has(column): return row[column]
	var lower:=column.to_lower()
	for key in row:
		if str(key).to_lower()==lower: return row[key]
	return fallback
func row(table: String,id: int) -> Dictionary:
	var rows: Array=text.tables.get(table,{}).get("orderedRows",[])
	return rows[id] if id>=0 and id<rows.size() else {}
func title(table: String,id: int,column: String="Name") -> String:
	var data:=row(table,id); var value: Variant=cell(data,column)
	var result: String=text.raw({"strRef":number(value,4294967295)}) if value!=null else ""
	return result if not result.is_empty() else str(cell(data,"Label",table+" "+str(id)))
func description(table: String,id: int) -> Dictionary:
	return text.rich({"strRef":number(cell(row(table,id),"SpellDesc" if table=="spells" else "Description"),4294967295)},-1)
func icon(table: String,id: int) -> String: return str(cell(row(table,id),"IconResRef" if table=="spells" else "Icon",""))
func portrait(object: Dictionary,size: int=4) -> String:
	var state: Dictionary=object.get("replicated",{})
	var resource:=str(state.get("portraitRef",""))
	if resource.is_empty() or resource=="****":
		var id:=number(state.get("portrait"),-1)
		var base:=str(cell(row("portraits",id),"BaseResRef",""))
		resource="po_"+base if base!="****" and not base.is_empty() else ""
	if resource.is_empty() or resource=="****": return ""
	return resource+["","t","s","m","l","h"][clampi(size,0,5)]
func presentation_object(objects: Dictionary,id: int,players: Array=[]) -> Dictionary:
	var object: Dictionary=objects.get(id,{}).duplicate(); var state: Dictionary=object.get("replicated",{}).duplicate()
	for entry in players:
		var player: Dictionary=entry[1] if entry is Array else entry; var character: Dictionary=player.get("character",{})
		if int(player.get("objectId",-1))!=id and int(character.get("id",-1))!=id: continue
		for field in ["portrait","portraitRef"]:
			if not state.has(field) and character.has(field): state[field]=character[field]
		if not state.has("name"): state.name={"firstName":character.get("firstName",{}),"lastName":character.get("lastName",{})}
	object.replicated=state
	return object
func party(objects: Dictionary,controlled: int,members: Array,players: Array=[]) -> Array:
	var ids: Array=[controlled]; var result: Array=[]
	for member in members:
		var id:=number(member.get("id") if member is Dictionary else member)
		if id>=0 and not ids.has(id): ids.append(id)
	for id in ids:
		var object:=presentation_object(objects,int(id),players); var state: Dictionary=object.replicated
		var hp: Dictionary=state.get("hitPoints",{})
		var health: Variant=null
		if hp.has("current") and hp.has("maximum"): health={"current":int(hp.current)+int(hp.get("fieldE8",0)),"maximum":int(hp.maximum),"clip":PartyHealth.from_party(state.get("party",{}))}
		result.append({"entryId":result.size(),"id":id,"self":id==controlled,"available":int(object.get("objectType",0))==5 and not object.get("replicationRemoved",false),"label":text.name(state.get("name"),int(id)),"portraitKey":portrait(object,3 if id==controlled else 2),"health":health,"canLevelUp":object.get("playerState",{}).get("combat",{}).get("canLevelUp",false)})
	return result
func feats(actor: Dictionary) -> Array:
	var result: Array=[]; var player: Dictionary=actor.get("playerState",{}); var stats: Dictionary=actor.get("inventoryStats",{})
	for source in [player.get("feats",[]),player.get("bonusFeats",[]),stats.get("feats",[]),stats.get("fields118",[]),stats.get("fields128",[])]:
		for entry in source:
			var id:=number(entry.get("id") if entry is Dictionary else entry)
			if id>=0 and not result.has(id): result.append(id)
	return result
func feat_uses(actor: Dictionary,id: int) -> Variant:
	var uses: Dictionary=actor.get("playerState",{}).get("featUses",{})
	if not feats(actor).has(id): return 0
	return uses.get(str(id),uses.get(id,100 if number(cell(row("feat",id),"UsesPerDay"),0)==0 else 0))
func record(actor: Dictionary,identity: String) -> Dictionary:
	var replicated: Dictionary=actor.get("replicated",{}); var stats: Dictionary=replicated.get("stats",{}); var inv: Dictionary=actor.get("inventoryStats",{}); var player: Dictionary=actor.get("playerState",{}); var combat: Dictionary=inv.get("combatInformation",{})
	var base_values: Array=inv.get("fields76",[])
	var abilities:=RecordValues.abilities(inv.get("fields70",player.get("abilities",{}).get("current",[])),inv.get("fields7d",[]),int(base_values[6]) if base_values.size()>6 else 0,text.tables)
	for ability in abilities: ability.label=text.raw({"strRef":ability.labelRef})
	var classes: Array=[]; var level:=0
	for cls in stats.get("classes",[]): classes.append(title("classes",int(cls.id))+" ("+Numbers.text(cls.level)+")"); level+=int(cls.level)
	var alignment:=""; var law:=number(stats.get("fieldDE6")); var good:=number(stats.get("fieldDE4"))
	if law>=0 and good>=0: alignment=text.raw({"strRef":112+(2 if law<31 else 0 if law>69 else 1)*3+(2 if good<31 else 0 if good>69 else 1)})
	var hp: Dictionary=replicated.get("hitPoints",{}); var details: Array=[]
	for pair in [[317,inv.get("field98")],[318,inv.get("field9a")],[319,inv.get("field99")],[40424,inv.get("field9b") if inv.get("field9b")!=-1 else null],[58349,combat.get("field5")],[58350,Numbers.text(combat.field6)+"%" if combat.has("field6") else null],[58351,("0" if int(combat.field7)==0 else "-"+Numbers.text(combat.field7)) if combat.has("field7") else null]]: details.append({"label":text.raw({"strRef":pair[0]}),"value":pair[1]})
	return {"identity":identity,"name":text.name(null,int(actor.id)),"labels":{"experience":text.raw({"strRef":314}),"nextLevel":text.raw({"strRef":315})},"race":str(stats.get("fieldD28","")) if not str(stats.get("fieldD28","")).is_empty() else title("racialtypes",number(stats.get("racialType"))),"alignment":alignment,"classes":classes,"abilities":abilities,"armorClass":player.get("combat",{}).get("armorClass"),"currentHP":int(hp.current)+int(hp.get("fieldE8",0)) if hp.has("current") else null,"maximumHP":hp.get("maximum"),"experience":inv.get("field94"),"nextExperience":cell(row("exptable",level),"XP"),"details":details}
func record_entries(actor: Dictionary,page: int) -> Array:
	var result: Array=[]
	if page==1:
		for skill in actor.get("inventoryStats",{}).get("skills",[]):
			if skill.get("flag",false): result.append({"id":int(skill.index),"value":skill.value,"binding":{"type":3,"intParam":int(skill.index)}})
	else:
		var inv: Dictionary=actor.get("inventoryStats",{}); var player: Dictionary=actor.get("playerState",{})
		var fallback: Array=player.get("feats",inv.get("feats",[]).map(func(entry):return int(entry.id)))
		var primary: Array=inv.get("fields118",fallback); var bonus: Array=inv.get("fields128",player.get("bonusFeats",[]))
		var admitted:=RecordEntries.feat_admission(primary,bonus,func(id):
			var data:=row("feat",int(id)); var name: Variant=cell(data,"FEAT")
			return null if data.is_empty() or name==null or str(name) in ["","****"] else number(cell(data,"SUCCESSOR"),-1))
		record_errors=admitted.errors
		for id in admitted.ids: result.append({"id":id,"binding":{"type":4,"intParam":id}})
	var table:="skills" if page==1 else "feat"
	for index in result.size():
		var entry: Dictionary=result[index]; entry.entryId=index; entry.name=title(table,int(entry.id),"Name" if page==1 else "FEAT"); entry.description=description(table,int(entry.id)); entry.icon=icon(table,int(entry.id)); entry.canDrag=page==2 or int(entry.get("value",0))>0
	result=RecordEntries.ordered(result)
	for index in result.size(): result[index].entryId=index
	return result
func spell_children(id: int,ancestors: Array=[]) -> Array:
	var result: Array=[]; var data:=row("spells",id)
	for index in range(1,9):
		var child:=number(cell(data,"SubRadSpell"+str(index)))
		if child>=0 and child!=id and not ancestors.has(child) and not result.has(child) and not row("spells",child).is_empty(): result.append(child)
	return result
func spell_level(id: int,class_id: int) -> int:
	return number(cell(row("spells",id),str(cell(row("classes",class_id),"SpellTableColumn",""))),255)&255
func rule_value(label: String,fallback: int=0) -> int:
	var result:=fallback
	for data in text.tables.get("ruleset",{}).get("orderedRows",[]):
		if str(cell(data,"Label",""))==label: result=number(cell(data,"Value"),fallback)
	return result
func meta_cost(mask: int) -> int:
	var options:={1:["EMPOWER",2],2:["EXTEND",1],4:["MAXIMIZE",3],8:["QUICKEN",4],16:["SILENT",1],32:["STILL",1]}
	return rule_value("SPELL_METAMAGIC_"+str(options[mask][0])+"_COST",int(options[mask][1]))&255 if options.has(mask) else 0
func spell_uses(actor: Dictionary,id: int,class_index: int,meta: int=0,domain: int=0) -> int:
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[])
	if class_index<0 or class_index>=classes.size(): return 0
	var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{}); var level:=spell_level(id,int(classes[class_index].id))
	var master:=number(cell(row("spells",id),"Master"))
	if master>=0: id=master; level=spell_level(id,int(classes[class_index].id))
	if domain>0:
		if not classes[class_index].get("domains",[]).any(func(d):return number(cell(row("domains",int(d)),"Level_"+str(domain)))==id): return 0
		level=domain
	level+=meta_cost(meta)
	if level>=10: return 0
	if number(cell(row("classes",int(classes[class_index].id)),"MemorizesSpells"),0)==0: return number(book.get("usesLeft",{}).get(str(level)),0)
	var count:=0
	for slot in book.get("memorized",{}).get(str(level),[]):
		if slot is Dictionary and int(slot.spell)==id and (meta==0 or int(slot.get("metamagic",0))&meta!=0) and flag(slot.get("ready",false)): count+=1
	return count
func spell_row(actor: Dictionary,id: int,class_index: int,level: int,meta: int,slot: int=-1,ready: bool=true,domain: bool=false) -> Dictionary:
	var family:=not spell_children(id).is_empty(); var uses:=spell_uses(actor,id,class_index,meta,level-meta_cost(meta) if domain else 0) if id>=0 else 0
	return {"entryId":0,"key":"%d:%d:%d:%d:%d"%[id,class_index,level,meta,slot],"spellId":id,"classIndex":class_index,"level":level,"metamagic":meta,"slot":slot,"label":title("spells",id) if id>=0 else "Empty spell slot","icon":icon("spells",id),"family":family,"canCast":id>=0 and uses>0,"canDrag":id>=0 and not family,"pending":false,"uses":uses,"ready":ready,"domain":domain,"binding":{"type":2,"intParam":id,"classIndex":class_index,"metamagic":meta,"domainLevel":level-meta_cost(meta) if domain else 0}}
func spellbook(actor: Dictionary,class_index: int,level: int,meta: int,family_path: Array=[],family_domain: bool=false) -> Dictionary:
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[]); var choices: Array=[]
	for index in classes.size():
		if number(cell(row("classes",int(classes[index].id)),"SpellCaster"),0)!=0: choices.append({"index":index,"classId":int(classes[index].id),"label":title("classes",int(classes[index].id)),"icon":icon("classes",int(classes[index].id))})
	if not choices.any(func(entry):return int(entry.index)==class_index): class_index=int(choices[0].index) if not choices.is_empty() else -1
	var metas: Array=[{"label":"Normal","value":0}]; var owned:=feats(actor)
	for option in [[1,11,"Empower"],[2,12,"Extend"],[4,25,"Maximize"],[8,29,"Quicken"],[16,33,"Silent"],[32,37,"Still"]]:
		if owned.has(option[1]): metas.append({"label":option[2],"value":option[0]})
	if not metas.any(func(option):return int(option.value)==meta): meta=0
	var base_level:=level-meta_cost(meta)
	var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{}); var known: Array=[]; var memory: Array=[]; var family: Array=[]; var prepared:=false
	if class_index>=0 and class_index<classes.size():
		var class_id:=int(classes[class_index].id); var rules:=row("classes",class_id); prepared=number(cell(rules,"MemorizesSpells"),0)!=0
		var ids: Array=book.get("known",[]).duplicate()
		if number(cell(rules,"SpellbookRestricted"),1)==0:
			ids.clear()
			for id in text.tables.get("spells",{}).get("orderedRows",[]).size():
				if spell_level(id,class_id)==base_level and number(cell(row("spells",id),"Master"),id)==id: ids.append(id)
		for id in ids:
			if spell_level(int(id),class_id)==base_level and (meta==0 or number(cell(row("spells",int(id)),"MetaMagic"),0)&meta!=0): known.append(spell_row(actor,int(id),class_index,level,meta))
		if base_level>0:
			for domain in classes[class_index].get("domains",[]):
				var id:=number(cell(row("domains",int(domain)),"Level_"+str(base_level)))
				if id>=0 and not known.any(func(entry):return entry.spellId==id) and (meta==0 or number(cell(row("spells",id),"MetaMagic"),0)&meta!=0): known.append(spell_row(actor,id,class_index,level,meta,-1,true,true))
		var slots: Array=book.get("memorized",{}).get(str(level),[])
		for index in slots.size():
			var slot: Variant=slots[index]; memory.append(spell_row(actor,int(slot.spell) if slot is Dictionary else -1,class_index,level,int(slot.get("metamagic",0)) if slot is Dictionary else 0,index,flag(slot.get("ready",false)) if slot is Dictionary else false,flag(slot.get("domain",false)) if slot is Dictionary else false))
		if not family_path.is_empty():
			for id in spell_children(int(family_path[-1]),family_path.slice(0,-1)):
				var child:=spell_row(actor,int(id),class_index,level,meta,-1,true,family_domain); child.preparationId=int(family_path[0]); family.append(child)
	var entry_id:=0
	for list in [known,memory,family]:
		for entry in list: entry.entryId=entry_id; entry_id+=1
	return {"classes":choices,"classIndex":class_index,"level":level,"metamagic":meta,"metas":metas,"prepared":prepared,"known":known,"memory":memory,"family":family,"familyTitle":title("spells",int(family_path[-1])) if not family_path.is_empty() else ""}
func spellbook_tree(actor: Dictionary,class_index: int,level: int,meta: int,family_path: Array=[],family_domain: bool=false) -> Dictionary:
	# Each expanded group shares one private view but owns distinct entry handles.
	# Reuse the same active rules projection for every metamagic branch.
	var result:=spellbook(actor,class_index,level,meta,family_path,family_domain); class_index=int(result.classIndex)
	var groups: Array=[]; var known: Array=[]; var memory_groups: Array=[]; var memory: Array=[]
	for option in result.metas:
		var value:=int(option.value); var branch: Dictionary=result if value==int(result.metamagic) else spellbook(actor,class_index,level,value)
		var entries: Array=branch.known
		for entry in entries: entry.key="known:"+str(value)+":"+str(entry.key)
		groups.append({"metamagic":value,"label":option.label,"entries":entries}); known.append_array(entries)
	if result.prepared and class_index>=0:
		var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{})
		for spell_level_index in 10:
			var entries: Array=[]; var slots: Array=book.get("memorized",{}).get(str(spell_level_index),[])
			for index in slots.size():
				var slot: Variant=slots[index]; var entry:=spell_row(actor,int(slot.spell) if slot is Dictionary else -1,class_index,spell_level_index,int(slot.get("metamagic",0)) if slot is Dictionary else 0,index,flag(slot.get("ready",false)) if slot is Dictionary else false,flag(slot.get("domain",false)) if slot is Dictionary else false)
				entry.key="memory:"+str(entry.key); entries.append(entry)
			memory_groups.append({"level":spell_level_index,"entries":entries}); memory.append_array(entries)
	var id:=0
	for entries in [known,memory,result.family]:
		for entry in entries: entry.entryId=id; id+=1
	result.known=known; result.memory=memory; result.groups=groups; result.memoryGroups=memory_groups
	return result
