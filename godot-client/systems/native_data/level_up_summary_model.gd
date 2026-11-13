extends RefCounted
#838950 private Summary text/numeric projection. No actor write or server ACK.
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Levels=preload("res://systems/native_data/creation_spells_snapshot.gd")
const ABILITY_REFS=[135,133,132,134,136,131]
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func has_feat(values: Array,id: int) -> bool:
	# JSON preserves received WORD IDs as FLOATs; Array.has(INT) is type
	# sensitive. Compare validated numeric IDs without changing received data.
	for value in values:
		if Class.integer(value,0,65535) and int(value)==id:return true
	return false
static func gain(roll: int,effective: int,new_base: int,old_base: int,old_level: int,new_level: int,class_id: int,class_level: int,old_feats: Array,new_feats: Array,toughness: int,deathless: int,epic_deathless: int) -> int:
	var value: int=maxi(1,Values.signed8(roll)+Values.signed8(effective))&255
	if (old_base&255)<(new_base&255):value=(value+maxi(0,(old_level&255)*((new_base&255)-(old_base&255))))&255
	if has_feat(new_feats,40):value=(value+toughness*((new_level&255) if not has_feat(old_feats,40) else 1))&255
	if class_id==34 and has_feat(new_feats,891):
		if class_level<=10:value=(value+deathless)&255
		elif (class_level-10)%5==0:value=(value+epic_deathless)&255
	return Values.signed8(value)
static func known(received: Dictionary,index: int,class_id: int,tables: Dictionary) -> Dictionary:
	var result: Array=[]
	for _level in 10:result.append([])
	if index==received.get("classes",[]).size():return {"ready":true,"value":result}
	var books: Variant=received.get("spellbooks");var book: Variant=books.get(str(index),books.get(index)) if books is Dictionary else null
	if not book is Dictionary or not book.get("known") is Array or not tables.has("spells"):return pending("Copied original known-spell storage is unavailable.")
	var player:=Tables.integer(tables.classes,class_id,"PlayerClass");var column:=Tables.cell(tables.classes,class_id,"SpellTableColumn")
	if not player.ready or not player.ok or not column.found:return pending("Active spell class metadata is unavailable.")
	for id in book.known:
		if not Class.integer(id,0,4294967295) or int(id)>=tables.spells.get("orderedRows",[]).size():return pending("Copied spell lacks an active physical row.")
		var level:=Levels.level(tables.spells,int(id),str(column.text),true,int(player.value)!=0)
		if not level.ready or int(level.value)<0 or int(level.value)>=10:return pending("Copied spell class level is unavailable.")
		result[int(level.value)].append(int(id))
	if result.any(func(book):return book.size()>255):return pending("Original known-spell BYTE traversal is outside its safe range.")
	return {"ready":true,"value":result}
static func list_text(ids: Array,table: Dictionary,column: String,text) -> Dictionary:
	var value:=""
	for id in ids:
		if not Class.integer(id,0,4294967295):return pending("Private summary list ID is malformed.")
		# GetFeat/GetSpell returns null outside physical storage; source skips it.
		if int(id)>=table.get("orderedRows",[]).size():continue
		var ref:=Tables.integer(table,int(id),column)
		if not ref.ready:return pending("Active summary name conversion is unresolved.")
		value+=text.raw({"strRef":int(ref.value)&0xffffffff})+"\n"
	return {"ready":true,"value":value if not value.is_empty() else text.raw({"strRef":68687})+"\n"}
static func compose(received: Dictionary,private: Dictionary,ranks: Array,primary_feats: Array,after_known: Variant,roll: int,hide_gain: Variant,tables: Dictionary,text) -> Dictionary:
	if not private.get("ready",false) or not hide_gain is bool or not Class.integer(roll,0,255) or not tables.has_all(["classes","skills","feat","ruleset"]) or text==null:return pending("Original final Summary context is unavailable.")
	var source: Dictionary=private.source;var vitals: Dictionary=private.vitals;var current: int=int(source.current);var cls: Dictionary=source.classes[current];var id: int=int(cls.id)
	if not received.get("baseAbilities") is Array or received.baseAbilities.size()!=6 or not received.get("feats") is Array or not received.get("skills") is Array or received.skills.size()!=ranks.size():return pending("Copied Summary comparison storage is unavailable.")
	var new_base: Variant=Values.modifier(int(vitals.raw[2]),tables);var old_base: Variant=Values.modifier(int(received.baseAbilities[2]),tables)
	if new_base==null or old_base==null:return pending("Original base Constitution modifier is unavailable.")
	var old_level:=0;var new_level:=0
	for entry in received.classes:old_level=(old_level+int(entry.level))&255
	for entry in source.classes:new_level=(new_level+int(entry.level))&255
	var hp:=gain(roll,int(vitals.modifiers[2]),int(new_base),int(old_base),old_level,new_level,id,int(cls.level),received.feats,primary_feats,Values.cfg(tables,"FEAT_TOUGHNESS_HP_BONUS",1),Values.cfg(tables,"FEAT_DEATHLESS_VIGOR_HP_BONUS",3),Values.cfg(tables,"FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS",5))
	var class_title_ref:=Tables.integer(tables.classes,id,"Name");var caster:=Tables.integer(tables.classes,id,"SpellCaster")
	if not class_title_ref.ready or not class_title_ref.ok or not caster.ready or not caster.ok:return pending("Active Summary class name/caster metadata is unavailable.")
	var feats:=list_text(primary_feats.filter(func(feat):return not has_feat(received.feats,int(feat))),tables.feat,"FEAT",text)
	if not feats.ready:return feats
	var skill_text:=""
	for at in ranks.size():
		if not Class.integer(ranks[at],0,255) or not Class.integer(received.skills[at],0,255):return pending("Private Summary skill BYTE is malformed.")
		if int(ranks[at])==int(received.skills[at]):continue
		var title:=Tables.integer(tables.skills,at,"Name")
		if not title.ready:return pending("Active Summary skill name is unavailable.")
		skill_text+=text.raw({"strRef":int(title.value)&0xffffffff})+"+"+str(Values.signed8(int(ranks[at]))-Values.signed8(int(received.skills[at])))+"\n"
	if skill_text.is_empty():skill_text=text.raw({"strRef":68687})+"\n"
	var ability_text:="\n\n"
	if new_level%4==0:
		var ability_name:=""
		for at in 6:
			if int(received.baseAbilities[at])<int(vitals.raw[at]):ability_name=text.raw({"strRef":ABILITY_REFS[at]});break
		ability_text="\n\n"+ability_name+": +1\n\n"
	var value: String=text.raw({"strRef":6388})+" : "+text.raw({"strRef":int(class_title_ref.value)&0xffffffff})+ability_text+text.raw({"strRef":6389})+" : "+("?" if hide_gain else "+"+str(hp))+"\n\n"+text.raw({"strRef":6390})+" :\n"+str(feats.value)+"\n"+text.raw({"strRef":10587})+" :\n"+skill_text
	if int(caster.value)!=0:
		var before:=known(received,current,id,tables)
		if not before.ready:return before
		if not after_known is Array or after_known.size()!=10 or after_known.any(func(book):return not book is Array or book.size()>255):return pending("Final private known-spell arrays are unavailable.")
		var added: Array=[];var removed: Array=[]
		for level in 10:
			for spell in after_known[level]:
				if not before.value[level].has(spell):added.append(spell)
			for spell in before.value[level]:
				if not after_known[level].has(spell):removed.append(spell)
		var added_text:=list_text(added,tables.spells,"Name",text);var removed_text:=list_text(removed,tables.spells,"Name",text)
		if not added_text.ready:return added_text
		if not removed_text.ready:return removed_text
		value+="\n"+text.raw({"strRef":6391})+" :\n"+str(added_text.value)+"\n"+text.raw({"strRef":6392})+" :\n"+str(removed_text.value)
	return {"ready":true,"summary":value,"hitDie":roll,"displayHitPointGain":hp,"hiddenHitPointGain":hide_gain,"serverAcknowledged":false}
