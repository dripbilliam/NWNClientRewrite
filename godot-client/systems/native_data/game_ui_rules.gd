extends RefCounted
const NativeObjectRules=preload("res://systems/native_data/native_object_rules.gd")
func effect_icons(state: Dictionary,context_id: int=-1) -> Array:
	var entries: Dictionary=state.get("effectIcons",{}); var serials: Dictionary=state.get("effectIconSerials",{}); var result: Array=[]
	for key in entries:
		var raw: String=str(key)
		var numeric: float=float(key) if key is int or key is float else float(raw) if raw.is_valid_float() else float(raw.hex_to_int()) if raw.begins_with("0x") and raw.is_valid_hex_number(true) else -1.0
		if not is_finite(numeric) or numeric<0.0 or numeric>65535.0 or numeric!=floorf(numeric):continue
		var id: int=int(numeric)
		var resource:=icon("effecticons",id)
		if resource=="****":resource=""
		var ref: int=number(cell(row("effecticons",id),"StrRef"),0)
		var label: String=text.resolve({"strRef":ref},context_id) if ref>0 else ""
		var description_failed:=ref>0 and not str(text.network_last_error).is_empty()
		if description_failed and effect_report.is_valid():effect_report.call("network.effect-icon-description-unavailable",str(text.network_last_error),{"iconId":id})
		if label.is_empty():label="Effect "+str(id)
		result.append({"id":id,"state":flag(entries[key]),"resource":"" if description_failed else resource.to_lower(),"sourceResource":resource,"label":label,"serial":int(serials.get(str(id),serials.get(id,-1)))})
	result.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return result
func queued_action_string(table: Dictionary,id: int,column: String) -> Dictionary:
	var columns: Array=table.get("columns",[]); var index:=-1
	for position in columns.size():
		if str(columns[position]).to_lower()==column.to_lower():index=position;break
	var rows: Array=table.get("orderedRows",[])
	var valid:=index>=0 and id>=0 and id<rows.size() and rows[id] is Dictionary
	var value: Variant=table.get("defaultValue","")
	if valid:
		var cells: Array=table.get("orderedCells",[])
		value=cells[id][index] if id<cells.size() and index<cells[id].size() else rows[id].get(columns[index])
	var result: String="" if value==null or str(value)=="****" else str(value)
	return {"found":valid and not result.is_empty(),"value":result}
func queued_action_int(table: Dictionary,id: int,column: String) -> Dictionary:
	var value: Dictionary=queued_action_string(table,id,column)
	var raw: String=str(value.value)
	if not value.found:return {"found":false,"value":raw.to_int()}
	return {"found":true,"value":number(raw,0) if raw.to_lower().begins_with("0x") else raw.to_int()}
func queued_actions(entries: Array,context_id: int=-1) -> Array:
	var result: Array=[]
	var actions: Dictionary=text.tables.get("actions",{}) if text!=null else {}
	var spells: Dictionary=text.tables.get("spells",{}) if text!=null else {}
	var feats: Dictionary=text.tables.get("feat",{}) if text!=null else {}
	if actions.is_empty():
		# networkQueuedAction throws only when an actual received entry needs the
		# absent table. The outer sync catch reports this code once for the pass.
		if not entries.is_empty() and text!=null and text.diagnostics.size()<100:text.diagnostics.append({"code":"network.action-queue-sync-failed","reason":"Native actions table is unavailable"})
		return result
	for source in entries:
		var id:=int(source.type); var special:=flag(source.get("special",false)); var spell_id:=int(source.get("spell",0))
		var name: Dictionary=queued_action_int(actions,id,"STRING_REF")
		var action_icon: Dictionary=queued_action_string(actions,id,"ICONRESREF")
		var spell_rows: Array=spells.get("orderedRows",[])
		var spell_exists:=spell_id>=0 and spell_id<spell_rows.size() and spell_rows[spell_id] is Dictionary
		var hidden:=false; var missing_spell:=false
		if not special and (id==4 or id==19):
			hidden=id==19 and not spell_exists; missing_spell=not spell_exists
			action_icon={"found":false,"value":""}
			if spell_exists:
				var associated:=int(queued_action_int(spells,spell_id,"FeatID").value)&65535
				action_icon=queued_action_string(feats,associated,"ICON") if id==4 and associated!=0 else queued_action_string(spells,spell_id,"IconResRef")
		elif not action_icon.found and not special:action_icon={"found":true,"value":"ir_use"}
		if missing_spell and text!=null and text.diagnostics.size()<100:
			text.diagnostics.append({"code":"network.action-queue-spell-unavailable","reason":"Native queued spell metadata is unavailable","spellId":spell_id,"actionId":id})
		if hidden:continue
		var entry: Dictionary=source.duplicate(true)
		entry.icon=str(action_icon.value).to_lower()
		entry.strRef=int(name.value)&0xffffffff if name.found else null
		entry.label=str(queued_action_string(actions,id,"LABEL").value)
		if entry.label.is_empty():entry.label="Action"
		if entry.strRef!=null:
			var resolved: String=text.resolve({"strRef":entry.strRef},context_id)
			if not resolved.is_empty():entry.label=resolved
			# A malformed TLK read is the synchronous Godot result corresponding
			# to an old rejected text promise for this particular queue row.
			var reference: Dictionary=text.fetch_reference(int(entry.strRef))
			if not reference.get("found",false):
				var custom:=bool(int(entry.strRef)&0x01000000)
				var table=text.custom if custom else text.base
				if not str(table.failure).is_empty() and text.diagnostics.size()<100:
					text.diagnostics.append({"code":"network.action-queue-presentation-failed","reason":str(table.failure),"actionId":id,"resource":entry.icon})
		if result.size()<10:result.append(entry)
	return result
# Presentation projections from received server fields and original native 2DAs.
# Never predicts a combat outcome, grants a feat or changes a spell's uses.
var text
var effect_report: Callable
var spellbook_failure:=""
var party_indicators=preload("res://systems/native_data/party_indicators.gd").new()
var record_errors: Array=[]
const INVALID:=2130706432
const ABILITIES=["Strength","Dexterity","Constitution","Intelligence","Wisdom","Charisma"]
const RecordValues=preload("res://systems/native_data/character_record_values.gd")
const SkillAdmission=preload("res://systems/native_data/skill_admission.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const RecordEntries=preload("res://systems/native_data/character_record_entries.gd")
const PartyHealth=preload("res://systems/native_data/party_health.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
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
	var source: Dictionary=text.tables.get(table,{})
	var ordered: Array=source.get("orderedRows",[])
	if id>=0 and id<ordered.size() and ordered[id] is Dictionary:return ordered[id]
	var labelled: Dictionary=source.get("rows",{})
	var fallback: Variant=labelled.get(id)
	return fallback if fallback is Dictionary else {}
func casting_spell(id: int) -> Variant:
	return SpellMetadata.casting_spell(text.tables.get("spells",{}),id)
func talent_spell(id: int) -> Variant:
	return SpellMetadata.talent_spell(text.tables.get("spells",{}),id)
func skill_admission(actor: Dictionary,id: Variant) -> Dictionary:
	var count:Dictionary=SkillAdmission.active_count(text.tables.get("skills") if text!=null else null)
	if not count.available:return SkillAdmission.unknown("active_skills_unavailable")
	if actor.get("objectType")!=5 or actor.get("replicationRemoved",false):return SkillAdmission.unknown("creature_unavailable")
	# Only31/22's received current-actor clear is bound; DM update remains separate.
	var view:Variant=actor.get("clientSkillAdmission")
	var result:Dictionary=SkillAdmission.query(view,id,count.count,SkillAdmission.override_value(view))
	result.rules={"source":count.source,"count":count.count,"physicalRows":count.physicalRows,"revision":int(text.revision)}
	return result
func title(table: String,id: int,column: String="Name") -> String:
	var data:=row(table,id); var value: Variant=cell(data,column)
	var result: String=text.raw({"strRef":number(value,4294967295)}) if value!=null else ""
	return result if not result.is_empty() else str(cell(data,"Label",table+" "+str(id)))
func description(table: String,id: int) -> Dictionary:
	return text.rich({"strRef":number(cell(row(table,id),"SpellDesc" if table=="spells" else "Description"),4294967295)},-1)
func icon(table: String,id: int) -> String:
	return str(SpellMetadata.native_string_entry(text.tables.get(table,{}),id,"IconResRef" if table=="spells" else "Icon").value)
func portrait(object: Dictionary,size: int=4) -> String:
	var state: Dictionary=object.get("replicated",{})
	var id:=number(state.get("portrait"),-1)
	var resource: String=""
	if id>0xfffd:
		resource=str(state.get("portraitRef",""))
	elif id>=0:
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
	var subjects: Array=[]; var result: Array=[]
	if int(objects.get(controlled,{}).get("objectType",0))==5:subjects.append({"id":controlled,"self":true})
	for member in members:
		var id:=number(member.get("id") if member is Dictionary else member)
		if id>=0:subjects.append({"id":id,"self":false})
	var ids: Array=subjects.map(func(subject):return int(subject.id))
	party_indicators.observe(controlled,ids,objects)
	for subject in subjects:
		var id: int=int(subject.id);var self_row: bool=bool(subject.self)
		var object: Dictionary=objects.get(id,{}).duplicate();var state: Dictionary=object.get("replicated",{}).duplicate()
		var player_character: Dictionary={}
		for entry in players:
			var player: Dictionary=entry[1] if entry is Array else entry
			var character: Dictionary=player.get("character",{})
			if int(player.get("objectId",-1))==id or int(character.get("id",-1))==id:player_character=character;break
		for field in ["portrait","portraitRef"]:
			if state.get(field)==null and player_character.has(field):state[field]=player_character[field]
		object.replicated=state
		var raw_hp: Variant=state.get("hitPoints")
		var hp: Dictionary=raw_hp if raw_hp is Dictionary else {}
		var health: Variant=null
		if hp.get("current") is int or hp.get("current") is float:
			if hp.get("fieldE8") is int or hp.get("fieldE8") is float:
				if hp.get("maximum") is int or hp.get("maximum") is float:
					if is_finite(float(hp.current)) and is_finite(float(hp.fieldE8)) and is_finite(float(hp.maximum)):
						health={"current":int(hp.current)+int(hp.fieldE8),"maximum":int(hp.maximum),"clip":PartyHealth.from_party(state.get("party",{}))}
		if health is Dictionary and self_row and object.get("playerState",{}).has("effectIcons"): health.clip=PartyHealth.from_player_icons(object.playerState.effectIcons)
		var source_name: Variant=state.get("name")
		if source_name==null:source_name=object.get("appearance",{}).get("name")
		if source_name==null and not player_character.is_empty():source_name={"firstName":player_character.get("firstName"),"lastName":player_character.get("lastName")}
		var name: String=text.name(source_name,int(id)) if source_name!=null else ""
		if name.is_empty():name="Object "+("%x" % id)
		result.append({"entryId":result.size(),"id":id,"self":self_row,"available":int(object.get("objectType",0))==5 and not object.get("replicationRemoved",false),"label":name,"portraitKey":portrait(object,3 if self_row else 2),"health":health,"canLevelUp":self_row and bool(object.get("playerState",{}).get("combat",{}).get("canLevelUp",false)),"indicators":party_indicators.for_member(id)})
	return result
func feats(actor: Dictionary) -> Array:
	return collect_feats(actor)
static func collect_feats(actor: Dictionary) -> Array:
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
static func record_signed_bonus(value: int) -> String:
	return ("+" if value>0 else "")+str(value)
static func record_integer(value: Variant) -> bool:
	return value is int or value is float and is_finite(value) and float(value)==floorf(float(value))
static func record_number(value: Variant) -> Variant:
	if value==null:return null
	if value is int or value is float:return value
	var source:=str(value).strip_edges()
	if source.is_empty():return 0
	if source.is_valid_int():return int(source)
	if source.is_valid_float():return float(source)
	if source.begins_with("0x") and source.is_valid_hex_number(true):return source.hex_to_int()
	return null
func record_rule_text(table: String,id: int,column: String) -> String:
	var value: Variant=cell(row(table,id),column)
	return text.raw({"strRef":number(value,0)&0xffffffff}) if value!=null and str(value)!="****" else ""
func record_labels() -> Dictionary:
	var refs: Dictionary={"experience":314,"nextLevel":315,"fortitude":317,"reflex":318,"will":319,"baseAttack":40424,"mainWeapon":58290,"unarmed":58291,"attack":58292,"damage":58313,"offhandWeapon":58328,"notApplicable":58329,"spellResistance":58349,"arcaneFailure":58350,"armorPenalty":58351,"critical":58312}
	var labels: Dictionary={}
	for key in refs:labels[key]=text.raw({"strRef":refs[key]})
	return labels
func record_attacks(info: Dictionary,bab: Variant,monk: bool,offhand: bool,feats: Array,has_main_weapon: bool) -> Variant:
	if info.is_empty() or not record_integer(bab) or int(bab)==-1:return null
	var count:=int(info.get("field0",0))
	if offhand:count=(2 if feats.has(20) else 1) if bool(info.get("field18",false)) else 0
	if count==0:return ""
	var bonus: Variant=info.get("field3" if offhand else "field1")
	if not record_integer(bonus):return null
	var universal:=0
	for node in info.get("group0",[]):
		var kind:=int(node.get("field2",-1))
		if kind not in [1,2,6,7] or kind==(1 if offhand else 2) or has_main_weapon and kind==7 or int(node.get("field5",-1))!=28 or int(node.get("field3",0))!=0 or int(node.get("field4",0))!=0:continue
		universal+=int(node.get("field0",0))
	var step:=RecordValues.cfg(text.tables,"MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER_MONK" if monk else "MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER",3 if monk else 5)
	var values: Array=[]
	for index in count:values.append(record_signed_bonus(int(bab)+RecordValues.signed8(int(bonus))+universal-step*index))
	return "/".join(values)
func record_damage_bonuses(nodes: Array,offhand: bool,has_main_weapon: bool) -> Array:
	var result: Array=[]
	var entries:=NativeObjectRules.new();entries.tables=text.tables
	for node in nodes:
		var kind:=int(node.get("field2",-1))
		if kind not in [1,2,6,7] or kind==(1 if offhand else 2) or has_main_weapon and kind==7:continue
		var amount:=int(node.get("field0",0))
		var amount_text:=record_signed_bonus(amount) if amount<6 else record_rule_text("iprp_damagecost",amount,"GameString")
		var type_text:=record_rule_text("damagetypes",int(node.get("field1",-1)),"CharsheetStrref")
		var group: Dictionary=entries.int_entry("damagetypes",int(node.get("field1",-1)),"DamageTypeGroup")
		var color: Variant=null
		if group.found and text.tables.has("damagetypegroups"):
			var rgb: Array=[]
			for column in ["ColorR","ColorG","ColorB"]:
				var channel: Dictionary=entries.int_entry("damagetypegroups",int(group.value),column)
				if not channel.found:break
				rgb.append(clampi(int(channel.value),1,255))
			if rgb.size()==3:color="#"+Color8(rgb[0],rgb[1],rgb[2]).to_html(false)
		var qualifiers: Array=[];var third:=int(node.get("field3",0));var fourth:=int(node.get("field4",0));var race:=int(node.get("field5",28))
		if third!=0:qualifiers.append(text.raw({"strRef":268 if third==2 else 267 if third==3 else 116 if fourth==1 else 264}))
		if fourth!=0:qualifiers.append(text.raw({"strRef":265 if fourth==4 else 266 if fourth==5 else 264}))
		if race!=28:qualifiers.append(record_rule_text("racialtypes",race,"NamePlural"))
		var nonempty: Array=[]
		for qualifier in qualifiers:
			if not str(qualifier).is_empty():nonempty.append(qualifier)
		var suffix: String=" "+str(text.raw({"strRef":7603}))+" "+" ".join(nonempty) if not qualifiers.is_empty() else ""
		var prefix:=amount_text if amount_text.contains("+") or amount_text.begins_with("-") else "+"+amount_text
		result.append({"value":prefix+" "+type_text+suffix,"tone":"damage","parts":[{"text":prefix+" "},{"text":type_text,"color":color},{"text":suffix}]})
	return result
func record_damage(info: Dictionary,item: Dictionary,offhand: bool,labels: Dictionary) -> Variant:
	if info.is_empty():return null
	if offhand and not bool(info.get("field18",false)):return labels.notApplicable
	var base:=row("baseitems",number(item.get("baseItem"),-1)) if not item.is_empty() else {}
	var dice: Variant=record_number(cell(base,"NumDice")) if not item.is_empty() else info.get("field8")
	var die: Variant=record_number(cell(base,"DieToRoll")) if not item.is_empty() else info.get("field9")
	var bonus: Variant=info.get("field4" if offhand else "field2")
	if not record_integer(dice) or not record_integer(die) or not record_integer(bonus):return null
	var threat:=int(info.get("field1c" if offhand else "field13",0));var multiplier:=int(info.get("field1d" if offhand else "field14",0));var modifier:=int(bonus)
	var bonus_text:=" "+("-" if modifier<0 else "+")+" "+str(absi(modifier)) if modifier!=0 else ""
	return str(int(dice))+"-"+str(int(dice)*int(die))+bonus_text+" ("+(str(labels.critical) if not str(labels.critical).is_empty() else "Critical:")+" "+("20" if threat<=1 else str(21-threat)+"-20")+" / x"+str(multiplier)+")"
func record(actor: Dictionary,identity: String,equipment: Dictionary={}) -> Dictionary:
	var replicated: Dictionary=actor.get("replicated",{}); var stats: Dictionary=replicated.get("stats",{}); var inv: Dictionary=actor.get("inventoryStats",{}); var player: Dictionary=actor.get("playerState",{}); var combat: Dictionary=inv.get("combatInformation",{})
	var abilities:=RecordValues.abilities(inv.get("fields70",player.get("abilities",{}).get("current",[])),inv.get("fields7d",[]),0,text.tables)
	for index in abilities.size():abilities[index].label=ABILITIES[index]
	var labels:=record_labels()
	var classes: Array=[]; var level:=0
	for cls in stats.get("classes",[]): classes.append(record_rule_text("classes",int(cls.id),"Name")+" ("+str(cls.level)+")"); level+=int(cls.level)
	var alignment:=""; var law:=number(stats.get("fieldDE6")); var good:=number(stats.get("fieldDE4"))
	if law>=0 and good>=0: alignment=text.raw({"strRef":112+(2 if law<31 else 0 if law>69 else 1)*3+(2 if good<31 else 0 if good>69 else 1)})
	var hp: Dictionary=replicated.get("hitPoints",{}); var details: Array=[]
	var right: Dictionary=equipment.get(16,{});var left: Dictionary=equipment.get(32,{})
	var feats: Array=record_feat_ids(actor)
	var right_name: Variant=text.resolve(right.get("name",{}),int(actor.id)) if not right.is_empty() else labels.unarmed
	details.append({"label":labels.mainWeapon,"value":right_name})
	details.append({"label":labels.attack,"value":record_attacks(combat,inv.get("field9b"),bool(inv.get("fielda0",false)),false,feats,not right.is_empty())})
	details.append({"label":labels.damage,"value":record_damage(combat,right,false,labels)})
	details.append_array(record_damage_bonuses(combat.get("group1",[]),false,not right.is_empty()))
	details.append({"label":labels.offhandWeapon,"value":text.resolve((left if not left.is_empty() else right).get("name",{}),int(actor.id)) if bool(combat.get("field18",false)) else labels.notApplicable})
	if bool(combat.get("field18",false)):
		details.append({"label":labels.attack,"value":record_attacks(combat,inv.get("field9b"),bool(inv.get("fielda0",false)),true,feats,not right.is_empty())})
		details.append({"label":labels.damage,"value":record_damage(combat,left if not left.is_empty() else right,true,labels)})
		details.append_array(record_damage_bonuses(combat.get("group1",[]),true,not right.is_empty()))
	for pair in [["fortitude",inv.get("field98")],["reflex",inv.get("field9a")],["will",inv.get("field99")],["baseAttack",null if inv.get("field9b")==-1 else inv.get("field9b")],["spellResistance",combat.get("field5")],["arcaneFailure",str(combat.field6)+"%" if combat.has("field6") else null],["armorPenalty",("0" if int(combat.field7)==0 else "-"+str(combat.field7)) if combat.has("field7") else null]]:details.append({"label":labels[pair[0]],"value":pair[1]})
	var experience: Variant=cell(row("exptable",level),"XP")
	var racial_name: Variant=stats.get("fieldD28")
	var race_name: String=racial_name if racial_name is String and not racial_name.is_empty() else record_rule_text("racialtypes",number(stats.get("racialType")),"Name")
	return {"identity":identity,"name":text.name(replicated.get("name",actor.get("appearance",{}).get("name")),int(actor.id)),"labels":labels,"race":race_name,"alignment":alignment,"classes":classes,"abilities":abilities,"portrait":portrait(actor),"armorClass":player.get("combat",{}).get("armorClass"),"currentHP":int(hp.current)+int(hp.get("fieldE8",0)) if hp.has("current") else null,"maximumHP":hp.get("maximum"),"experience":inv.get("field94"),"nextExperience":number(experience,0) if experience!=null and str(experience) not in ["","****"] else null,"details":details,"waiting":{"Skills":"Waiting for server skill details.","Feats":"Waiting for server feat details."}}
func record_feat_ids(actor: Dictionary) -> Array:
	var player: Dictionary=actor.get("playerState",{});var inv: Dictionary=actor.get("inventoryStats",{})
	var result: Array=[]
	for source in [player.get("feats",[]),player.get("bonusFeats",[]),inv.get("feats",[]),inv.get("fields118",[]),inv.get("fields128",[])]:
		for entry in source:
			var id:=int(entry.get("id",-1)) if entry is Dictionary else int(entry)
			if not result.has(id):result.append(id)
	return result
func record_entries(actor: Dictionary,page: int) -> Array:
	var result: Array=[]
	if page==1:
		for skill in actor.get("inventoryStats",{}).get("skills",[]):
			if skill.get("flag",false): result.append({"id":int(skill.index),"value":skill.value,"binding":{"type":3,"intParam":int(skill.index)} if int(skill.value)>0 else null})
	else:
		for id in record_feat_ids(actor):result.append({"id":id,"binding":{"type":4,"intParam":id}})
	return decorate_record_entries_js(result,"skills" if page==1 else "feat",page)
func decorate_record_entries_js(result: Array,table: String,page: int) -> Array:
	for entry in result:
		var id:=int(entry.id);var data:=row(table,id);var name:=record_rule_text(table,id,"Name" if page==1 else "FEAT")
		var label: Variant=cell(data,"Label")
		if name.is_empty() and label!=null and label!=0:name=str(label)
		if name.is_empty():name=table+" "+str(id)
		entry.name=name;entry.description=description(table,id);entry.icon=icon(table,id);entry.canDrag=entry.get("binding") is Dictionary
	# recordEntries sorts names with localeCompare, then numeric id; preserve
	# stable input order for identical keys (Array.sort in the old runtime).
	var ordered: Array=[]
	for entry in result:
		var position:=ordered.size()
		for index in ordered.size():
			var comparison:=str(entry.name).nocasecmp_to(str(ordered[index].name))
			if comparison<0 or comparison==0 and int(entry.id)<int(ordered[index].id):position=index;break
		ordered.insert(position,entry)
	for index in ordered.size():ordered[index].entryId=index
	return ordered
func record_feat_definition(id: int) -> Dictionary:
	var data:=row("feat",id); var name: Variant=cell(data,"FEAT")
	return {} if data.is_empty() or name==null or str(name) in ["","****"] else data
func record_feat_entries(primary: Array,bonus: Array=[]) -> Array:
	var admitted:=RecordEntries.feat_admission(primary,bonus,func(id):
		var data:=record_feat_definition(int(id))
		return null if data.is_empty() else number(cell(data,"SUCCESSOR"),-1))
	record_errors=admitted.errors
	var result: Array=[]
	for id in admitted.ids: result.append({"id":id,"binding":{"type":4,"intParam":id}})
	return decorate_record_entries(result,"feat",2)
func decorate_record_entries(result: Array,table: String,page: int) -> Array:
	for index in result.size():
		var entry: Dictionary=result[index]; entry.entryId=index; entry.name=title(table,int(entry.id),"Name" if page==1 else "FEAT"); entry.description=description(table,int(entry.id)); entry.icon=icon(table,int(entry.id)); entry.canDrag=page==2 or int(entry.get("value",0))>0
	result=RecordEntries.ordered(result)
	for index in result.size(): result[index].entryId=index
	return result
func spell_children(id: int,ancestors: Array=[]) -> Array:
	var result: Array=[]; var definition: Variant=talent_spell(id)
	if definition==null:return result
	for child in definition.children:
		if child>=0 and child!=id and not ancestors.has(child) and not result.has(child) and casting_spell(int(child))!=null: result.append(child)
	return result
func spell_family(id: int)->bool:
	var definition: Variant=talent_spell(id)
	return definition!=null and not definition.children.is_empty()
func spell_level(id: int,class_id: int) -> int:
	var spells: Array=text.tables.get("spells",{}).get("orderedRows",[])
	class_id&=255
	if id<0 or id>=spells.size() or class_id==255:return 255
	var entries:=NativeObjectRules.new();entries.tables=text.tables
	var cls: Dictionary=row("classes",class_id)
	if int(entries.int_entry("classes",class_id,"SpellCaster").value)==0 and int(entries.int_entry("classes",class_id,"PlayerClass").value)!=0:return 255
	var raw_column: Variant=cell(cls,"SpellTableColumn","")
	var column: String=str(raw_column) if raw_column!=null else ""
	var terminator:=column.find(char(0))
	if terminator>=0:column=column.substr(0,terminator)
	var entry: Dictionary=entries.int_entry("spells",id,column)
	return int(entry.value)&255 if entry.found else 255
func rule_value(label: String,fallback: int=0) -> int:
	return RecordValues.cfg(text.tables,label,fallback)
func meta_cost(mask: int) -> int:
	mask&=255
	var options:={1:["EMPOWER",2],2:["EXTEND",1],4:["MAXIMIZE",3],8:["QUICKEN",4],16:["SILENT",1],32:["STILL",1]}
	return rule_value("SPELL_METAMAGIC_"+str(options[mask][0])+"_COST",int(options[mask][1]))&255 if options.has(mask) else 0
func spell_uses(actor: Dictionary,id: int,class_index: int,meta: int=0,domain: int=0) -> int:
	class_index&=255; domain&=255; meta&=255
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[])
	if class_index<0 or class_index>=classes.size(): return 0
	var spells: Array=text.tables.get("spells",{}).get("orderedRows",[])
	if id<0 or id>=spells.size():return 0
	var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{}); var level:=spell_level(id,int(classes[class_index].id))
	var spell_definition: Variant=talent_spell(id)
	if spell_definition==null:return 0
	if spell_definition!=null and int(spell_definition.master)!=id:
		var master:=int(spell_definition.master)
		if master<0 or master>=spells.size():return 0
		id=master; level=spell_level(id,int(classes[class_index].id))
	if domain==0 and level==255:return 0
	if domain>0:
		var class_entries:=NativeObjectRules.new();class_entries.tables=text.tables
		if int(class_entries.int_entry("classes",int(classes[class_index].id),"PickDomains").value)==0: return 0
		var domain_rows: Dictionary=text.tables.get("domains",{})
		if domain_rows.is_empty():spellbook_failure="Native client domain table is unavailable";return 0
		var domain_entries:=NativeObjectRules.new();domain_entries.tables=text.tables
		var domains: Array=classes[class_index].get("domains",[])
		var confirmed:=false
		for domain_value in domains:
			var domain_id:=int(domain_value)&255
			var entry: Dictionary=domain_entries.int_entry("domains",domain_id,"Level_"+str(domain))
			if entry.get("found",false) and int(entry.value)!=-1 and (int(entry.value)&0xffffffff)==id:confirmed=true;break
		if not confirmed:return 0
		level=domain
	level=(level+meta_cost(meta))&255
	if level>=10:
		spellbook_failure="Native client spell level reads outside verified storage"
		text.diagnostics.append({"code":"network.spell-uses-invalid-level","spellId":id,"classIndex":class_index,"level":level})
		return 0
	var class_entries:=NativeObjectRules.new();class_entries.tables=text.tables
	if int(class_entries.int_entry("classes",int(classes[class_index].id),"MemorizesSpells").value)==0: return number(book.get("usesLeft",{}).get(str(level)),0)&255
	var count:=0
	var slots: Array=book.get("memorized",{}).get(str(level),[])
	if slots.size()>255:
		spellbook_failure="Native client prepared-spell scan wraps its BYTE cursor"
		text.diagnostics.append({"code":"network.spell-uses-slot-wrap","spellId":id,"classIndex":class_index,"level":level})
		return 0
	for slot in slots:
		if slot is Dictionary and int(slot.spell)==id and (meta==0 or int(slot.get("metamagic",0))&meta!=0) and slot.get("ready",null)!=0: count=(count+1)&255
	return count
func spell_like_uses(actor: Dictionary,id: int,level: int) -> int:
	var count:=0
	for ability in actor.get("playerState",{}).get("specialAbilities",[]):
		if ability is Dictionary and int(ability.get("spell",-1))==id and (int(ability.get("level",0))&255)==(level&255) and ability.get("state",null)!=0:count=(count+1)&255
	return count
func spell_like_shortcut_uses(actor: Dictionary,id: int,level: int) -> int:
	var visited: Dictionary={}
	while id>=0 and not visited.has(id):
		visited[id]=true
		if actor.get("playerState",{}).get("specialAbilities",[]).any(func(ability):return ability is Dictionary and int(ability.get("spell",-1))==id and (int(ability.get("level",0))&255)==(level&255)):
			return spell_like_uses(actor,id,level)
		var spell: Variant=talent_spell(id)
		if spell==null:break
		var parent:=int(spell.master)
		if parent==id:break
		id=parent
	return 0
func spell_row(actor: Dictionary,id: int,class_index: int,level: int,meta: int,slot: int=-1,ready: bool=true,domain: bool=false) -> Dictionary:
	var family:=spell_family(id); var uses:=spell_uses(actor,id,class_index,meta,level-meta_cost(meta) if domain else 0) if id>=0 else 0
	return {"entryId":0,"key":"%d:%d:%d:%d:%d"%[id,class_index,level,meta,slot],"spellId":id,"classIndex":class_index,"level":level,"metamagic":meta,"slot":slot,"label":title("spells",id) if id>=0 else "Empty spell slot","icon":icon("spells",id),"family":family,"canCast":id>=0 and uses>0,"canDrag":id>=0 and not family,"pending":false,"uses":uses,"ready":ready,"domain":domain,"binding":{"type":2,"intParam":id,"classIndex":class_index,"metamagic":meta,"domainLevel":(level-meta_cost(meta))&255 if domain else 0}}
func preparation_entries(actor: Dictionary,class_index: int,level: int,meta: int) -> Array:
	spellbook_failure=""
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[])
	if class_index<0 or class_index>=classes.size():return []
	var cls: Dictionary=classes[class_index]; var class_id:=int(cls.get("id",255))&255
	var spells: Array=text.tables.get("spells",{}).get("orderedRows",[])
	if spells.is_empty():spellbook_failure="Native spellbook SPELLS table is unavailable";return []
	var result: Array=[]; var class_rules: Dictionary=row("classes",class_id)
	if number(cell(class_rules,"SpellbookRestricted"),0)!=0:
		var known: Array=[]
		for id in actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{}).get("known",[]):
			if spell_level(int(id),class_id)==(level&255):known.append(id)
		for cursor in known.size():
			var id:=int(known[cursor&255]) if (cursor&255)<known.size() else 4294967295
			if id<0 or id>=spells.size():spellbook_failure="Native spellbook contains a missing spell";return []
			var spell: Variant=casting_spell(id)
			if spell==null:spellbook_failure="Native spellbook contains a missing spell";return []
			if meta==0 or (int(spell.metamagic)&meta)!=0:result.append({"id":id,"domain":false,"metamagic":meta})
		return result
	var minimum: Variant=cell(class_rules,"MinCastingLevel")
	if minimum==null or str(minimum)=="****":spellbook_failure="Native spellbook minimum casting level is unavailable";return []
	if (int(cls.get("level",0))&255 if class_index<8 else 0)<number(minimum,0):return []
	for id in spells.size():
		if spell_level(id,class_id)==level:
			var spell: Variant=casting_spell(id)
			if spell!=null and (meta==0 or (int(spell.metamagic)&meta)!=0):result.append({"id":id,"domain":false,"metamagic":meta})
	if number(cell(class_rules,"PickDomains"),0)==0:return result
	var domains: Array=cls.get("domains",[]); var first:=-1; var second:=-1
	for index in 2:
		var domain:=int(domains[index]) if index<domains.size() else index
		if row("domains",domain&255).is_empty():spellbook_failure="Native spellbook domain is unavailable";return []
		var id:=number(cell(row("domains",domain&255),"Level_"+str(level&255)),-1)
		if index==0:first=id
		else:second=id
	var first_spell: Variant=casting_spell(first) if first>=0 else null
	var second_spell: Variant=casting_spell(second) if second>=0 else null
	if first_spell!=null and (meta==0 or (int(first_spell.metamagic)&meta)!=0):result.append({"id":first,"domain":true,"metamagic":meta})
	if second!=first and second_spell!=null and (meta==0 or (int(second_spell.metamagic)&meta)!=0):result.append({"id":second,"domain":true,"metamagic":meta})
	return result
func spellbook(actor: Dictionary,class_index: int,level: int,meta: int,family_path: Array=[],family_domain: bool=false) -> Dictionary:
	spellbook_failure=""
	var classes: Array=actor.get("replicated",{}).get("stats",{}).get("classes",[]); var choices: Array=[]
	for index in classes.size():
		if number(cell(row("classes",int(classes[index].id)),"SpellCaster"),0)!=0: choices.append({"index":index,"classId":int(classes[index].id),"label":title("classes",int(classes[index].id)),"icon":icon("classes",int(classes[index].id))})
	if not choices.any(func(entry):return int(entry.index)==class_index): class_index=int(choices[0].index) if not choices.is_empty() else -1
	var metas: Array=[{"label":"Normal","value":0}]; var player: Dictionary=actor.get("playerState",{}); var owned: Array=player.get("feats",[]).duplicate(); owned.append_array(player.get("bonusFeats",[]))
	for option in [[1,11,"Empower"],[2,12,"Extend"],[4,25,"Maximize"],[8,29,"Quicken"],[16,33,"Silent"],[32,37,"Still"]]:
		if owned.has(option[1]): metas.append({"label":option[2],"value":option[0]})
	if not metas.any(func(option):return int(option.value)==meta): meta=0
	var base_level:=level-meta_cost(meta)
	var book: Dictionary=actor.get("playerState",{}).get("spellbooks",{}).get(str(class_index),{}); var known: Array=[]; var memory: Array=[]; var family: Array=[]; var prepared:=false
	if class_index>=0 and class_index<classes.size():
		var class_id:=int(classes[class_index].id); var rules:=row("classes",class_id); prepared=number(cell(rules,"MemorizesSpells"),0)!=0
		for entry in preparation_entries(actor,class_index,base_level,meta):
			var known_row:=spell_row(actor,int(entry.id),class_index,level,meta,-1,true,bool(entry.domain))
			known_row.key+=":known:"+str(known.size())
			known.append(known_row)
		for index in known.size(): known[index].sourceOrder=index
		known.sort_custom(func(a,b):
			var comparison: int=str(a.label).naturalnocasecmp_to(str(b.label))
			return comparison<0 if comparison!=0 else int(a.sourceOrder)<int(b.sourceOrder))
		for entry in known: entry.erase("sourceOrder")
		var slots: Array=book.get("memorized",{}).get(str(level),[])
		for index in slots.size():
			var slot: Variant=slots[index]; memory.append(spell_row(actor,int(slot.spell) if slot is Dictionary else -1,class_index,level,int(slot.get("metamagic",0)) if slot is Dictionary else 0,index,flag(slot.get("ready",false)) if slot is Dictionary else false,flag(slot.get("domain",false)) if slot is Dictionary else false))
		if not family_path.is_empty():
			for id in spell_children(int(family_path[-1]),family_path.slice(0,-1)):
				var child:=spell_row(actor,int(id),class_index,level,meta,-1,true,family_domain); child.preparationId=int(family_path[0]); family.append(child)
	var entry_id:=0
	for list in [known,memory,family]:
		for entry in list: entry.entryId=entry_id; entry_id+=1
	return {"classes":choices,"classIndex":class_index,"level":level,"metamagic":meta,"metas":metas,"prepared":prepared,"usesLeft":number(book.get("usesLeft",{}).get(str(level),0),0),"known":known,"memory":memory,"family":family,"familyTitle":title("spells",int(family_path[-1])) if not family_path.is_empty() else "","error":spellbook_failure}
func spellbook_tree(actor: Dictionary,class_index: int,level: int,meta: int,family_path: Array=[],family_domain: bool=false) -> Dictionary:
	# Each expanded group shares one private view but owns distinct entry handles.
	# Reuse the same active rules projection for every metamagic branch.
	var result:=spellbook(actor,class_index,level,meta,family_path,family_domain); class_index=int(result.classIndex)
	var groups: Array=[]; var known: Array=[]; var memory_groups: Array=[]; var memory: Array=[]
	for option in result.metas:
		var value:=int(option.value); var branch: Dictionary=result if value==int(result.metamagic) else spellbook(actor,class_index,level,value)
		if str(result.get("error","")).is_empty() and not str(branch.get("error","")).is_empty():result.error=branch.error
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
	if str(result.get("error","")).is_empty() and not spellbook_failure.is_empty():result.error=spellbook_failure
	result.known=known; result.memory=memory; result.groups=groups; result.memoryGroups=memory_groups
	return result
